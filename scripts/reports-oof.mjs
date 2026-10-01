import process from "node:process";

function getArgument(name, fallback) {
  const index = process.argv.indexOf(name);
  return index === -1 ? fallback : process.argv[index + 1];
}

const port = Number(getArgument("--port"));
const startDate = getArgument("--start-date");
const monthCount = Number(getArgument("--months", "2"));
const outputJson = process.argv.includes("--json");

if (!port || !/^\d{4}-\d{2}-\d{2}$/.test(startDate) || !Number.isInteger(monthCount)) {
  throw new Error("Expected --port, --start-date YYYY-MM-DD, and --months.");
}

const delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
const dateKey = date => date.toISOString().slice(0, 10);
const parseDate = value => new Date(`${value}T00:00:00Z`);
const addDays = (date, days) => new Date(date.getTime() + days * 86400000);
const addMonths = (date, months) => new Date(Date.UTC(
  date.getUTCFullYear(),
  date.getUTCMonth() + months,
  date.getUTCDate()
));

async function waitForTarget(timeoutMilliseconds = 30000) {
  const deadline = Date.now() + timeoutMilliseconds;
  while (Date.now() < deadline) {
    const targets = await fetch(`http://127.0.0.1:${port}/json/list`).then(response => response.json());
    const target = targets.find(item => item.type === "page");
    if (target) {
      return target;
    }
    await delay(300);
  }
  throw new Error("MS Vacation browser tab was not created.");
}

const target = await waitForTarget();
const socket = new WebSocket(target.webSocketDebuggerUrl);
const pending = new Map();
let nextId = 1;

socket.addEventListener("message", event => {
  const message = JSON.parse(event.data);
  if (!message.id || !pending.has(message.id)) {
    return;
  }

  const { resolve, reject } = pending.get(message.id);
  pending.delete(message.id);
  if (message.error) {
    reject(new Error(message.error.message));
  } else {
    resolve(message.result);
  }
});

await new Promise((resolve, reject) => {
  socket.addEventListener("open", resolve, { once: true });
  socket.addEventListener("error", reject, { once: true });
});

function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = nextId++;
    pending.set(id, { resolve, reject });
    socket.send(JSON.stringify({ id, method, params }));
  });
}

async function evaluate(expression) {
  const response = await send("Runtime.evaluate", {
    expression,
    awaitPromise: true,
    returnByValue: true
  });
  if (response.exceptionDetails) {
    const description = response.exceptionDetails.exception?.description
      ?? response.exceptionDetails.text
      ?? "Browser evaluation failed.";
    throw new Error(description);
  }
  return response.result.value;
}

async function waitFor(expression, message, timeoutMilliseconds = 60000) {
  const deadline = Date.now() + timeoutMilliseconds;
  while (Date.now() < deadline) {
    if (await evaluate(expression)) {
      return;
    }
    await delay(400);
  }
  throw new Error(message);
}

await send("Runtime.enable");
await waitFor(
  "location.hostname === 'msvacation.microsoft.com' && frames.length >= 3",
  "MS Vacation did not authenticate. Sign in with the default Edge profile and retry."
);

await evaluate("frames[2].location.href = '/ManagerCalenderView/'; true");
await waitFor(
  "Boolean(frames[2].document.getElementById('tblvacationInfo'))",
  "The MS Vacation manager calendar did not load."
);

const start = parseDate(startDate);
const firstMonth = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), 1));
const endExclusive = addMonths(firstMonth, monthCount);
const end = addDays(endExclusive, -1);
const monthlyCalendars = [];

for (let offset = 0; offset < monthCount; offset++) {
  const targetMonth = addMonths(firstMonth, offset);
  const year = targetMonth.getUTCFullYear();
  const month = targetMonth.getUTCMonth() + 1;

  await evaluate(`(() => {
    const document = frames[2].document;
    document.getElementById("DlMonths").value = "${month}";
    document.getElementById("DlYears").value = "${year}";
    document.getElementById("BtnRetrieve").click();
    return true;
  })()`);

  await waitFor(
    `(() => {
      const document = frames[2].document;
      const table = document.getElementById("tblvacationInfo");
      const expected = "${targetMonth.toLocaleString("en-US", { month: "long", timeZone: "UTC" })} ${year}";
      return Boolean(table && document.body.innerText.includes(expected));
    })()`,
    `The calendar for ${month}/${year} did not load.`
  );

  const calendar = await evaluate(`(() => {
    const document = frames[2].document;
    const personLines = document.body.innerText
      .split("\\n")
      .filter(line => /\\(\\d+-[^)]+\\)\\s*$/.test(line));
    const people = personLines.map((line, index) => {
      const leadingWhitespace = line.match(/^\\s*/)?.[0] ?? "";
      const tabDepth = (leadingWhitespace.match(/\\t/g) ?? []).length;
      return {
        name: line.replace(/^\\s*/, "").replace(/\\s+\\(\\d+-[^)]+\\)\\s*$/, ""),
        depth: tabDepth || (index === 0 ? 1 : 2)
      };
    });
    const rows = Array.from(document.getElementById("tblvacationInfo").rows)
      .map(row => Array.from(row.cells).map(cell => ({
        value: cell.textContent.trim().replace(/\\s+/g, " "),
        background: getComputedStyle(cell).backgroundColor
      })))
      .filter(cells => cells.some(cell => ["W", "W E", "V", "PH"].includes(cell.value)));
    return { people, rows };
  })()`);

  if (calendar.people.length !== calendar.rows.length) {
    throw new Error(`Calendar hierarchy and status rows did not align for ${month}/${year}.`);
  }

  monthlyCalendars.push({ year, month, ...calendar });
}

socket.close();

const manager = monthlyCalendars[0].people[0];
const managerDepth = manager.depth;
const directReportNames = monthlyCalendars[0].people
  .filter((person, index) => index > 0 && person.depth === managerDepth + 1)
  .map(person => person.name);
const reportDays = new Map(directReportNames.map(name => [name, new Map()]));

for (const calendar of monthlyCalendars) {
  calendar.people.forEach((person, personIndex) => {
    if (!reportDays.has(person.name)) {
      return;
    }

    calendar.rows[personIndex].forEach((cell, dayIndex) => {
      const date = new Date(Date.UTC(calendar.year, calendar.month - 1, dayIndex + 1));
      if (date < start || date > end) {
        return;
      }

      let kind = "work";
      if (cell.value === "V") {
        kind = cell.background === "rgb(255, 255, 0)" ? "pending" : "approved";
      } else if (cell.value === "PH") {
        kind = "holiday";
      } else if (cell.value === "W E") {
        kind = "weekend";
      }
      reportDays.get(person.name).set(dateKey(date), kind);
    });
  });
}

function buildRanges(days) {
  const oofDates = [...days.entries()]
    .filter(([, kind]) => kind === "approved" || kind === "pending")
    .map(([date]) => date)
    .sort();
  if (oofDates.length === 0) {
    return [];
  }

  const ranges = [];
  let current = {
    start: oofDates[0],
    end: oofDates[0],
    statuses: new Set([days.get(oofDates[0])])
  };

  for (const currentDate of oofDates.slice(1)) {
    let cursor = addDays(parseDate(current.end), 1);
    const targetDate = parseDate(currentDate);
    let bridgeable = true;

    while (cursor < targetDate) {
      const kind = days.get(dateKey(cursor));
      if (kind !== "weekend" && kind !== "holiday") {
        bridgeable = false;
        break;
      }
      cursor = addDays(cursor, 1);
    }

    if (bridgeable) {
      current.end = currentDate;
      current.statuses.add(days.get(currentDate));
    } else {
      ranges.push(current);
      current = {
        start: currentDate,
        end: currentDate,
        statuses: new Set([days.get(currentDate)])
      };
    }
  }
  ranges.push(current);

  return ranges.map(range => ({
    start: range.start,
    end: range.end,
    status: range.statuses.size > 1 ? "mixed" : [...range.statuses][0]
  }));
}

const reports = directReportNames.map(name => ({
  name,
  ranges: buildRanges(reportDays.get(name))
}));
const result = {
  manager: manager.name,
  window: {
    start: dateKey(start),
    end: dateKey(end)
  },
  reports
};

if (outputJson) {
  console.log(JSON.stringify(result, null, 2));
  process.exit(0);
}

const formatDate = value => parseDate(value).toLocaleDateString("en-US", {
  month: "short",
  day: "numeric",
  year: "numeric",
  timeZone: "UTC"
});
const formatRange = range => {
  const dates = range.start === range.end
    ? formatDate(range.start)
    : `${formatDate(range.start)} - ${formatDate(range.end)}`;
  return range.status === "approved" ? dates : `${dates} (${range.status})`;
};

console.log(`OOF window: ${formatDate(result.window.start)} - ${formatDate(result.window.end)}`);
for (const report of reports) {
  const ranges = report.ranges.length === 0
    ? "None"
    : report.ranges.map(formatRange).join(", ");
  console.log(`- ${report.name}: ${ranges}`);
}
