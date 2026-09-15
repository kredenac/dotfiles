from __future__ import annotations

import argparse
import html
import json
import math
import re
import subprocess
import sys
import time
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import date, datetime, time as dt_time, timedelta, timezone
from pathlib import Path
from typing import Any

CLUSTER = "https://1es.westus2.kusto.windows.net"
UTC = timezone.utc


@dataclass(frozen=True)
class Person:
    alias: str
    name: str
    area: str
    note: str = ""


def normalize_manager(value: str) -> str:
    alias = value.strip().lower()
    if "@" in alias:
        alias = alias.split("@", 1)[0]
    if not re.fullmatch(r"[a-z0-9._-]+", alias):
        raise ValueError(f"invalid manager alias: {value!r}")
    return alias


def kql_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def kql_dynamic(values: list[str]) -> str:
    return "dynamic([" + ",".join(kql_string(value) for value in values) + "])"


def week_windows(now: datetime, count: int = 5) -> list[dict[str, Any]]:
    local_now = now.astimezone()
    current_start = local_now.date() - timedelta(days=local_now.weekday())
    starts = [current_start - timedelta(weeks=offset) for offset in range(count - 1, -1, -1)]
    windows = []
    for start in starts:
        end = start + timedelta(days=6)
        windows.append({
            "start": start,
            "end": end,
            "label": f"{start.isoformat()} to {end.isoformat()}",
            "current": start == current_start,
        })
    return windows


def utc_bounds(windows: list[dict[str, Any]], now: datetime) -> tuple[datetime, datetime]:
    start = datetime.combine(windows[0]["start"], dt_time.min, tzinfo=UTC)
    return start, now.astimezone(UTC)


def import_engpulse(engpulse: Path):
    repo_metrics = engpulse / "scripts" / "repo-metrics"
    shared = engpulse / "scripts" / "shared"
    for path in (repo_metrics, shared):
        if not path.is_dir():
            raise FileNotFoundError(f"EngPulse path missing: {path}")
        sys.path.insert(0, str(path))
    from _ado_helpers import KustoPartialResultError, get_kusto_access_token, kusto_query
    from chore_filter import chore_rule_kind
    from pr_aggregates import business_hours_between
    from trunk_refs import is_trunk, load_trunk_map

    return (
        KustoPartialResultError,
        get_kusto_access_token,
        kusto_query,
        chore_rule_kind,
        business_hours_between,
        is_trunk,
        load_trunk_map,
    )


def query_roster(kusto_query, token: str, manager: str) -> tuple[str, list[Person]]:
    query = f"""
let managerAlias = {kql_string(manager)};
let latestRows = materialize(
    AADUser
    | where isnotempty(MailNickname)
    | where MailNickname !contains "#ext#"
    | summarize arg_max(EtlIngestDate, DisplayName, Mail, ReportsToEmailName, JobTitle, AccountEnabled)
        by Alias = tolower(MailNickname)
);
let managerName = toscalar(latestRows | where Alias == managerAlias | project DisplayName | take 1);
latestRows
| where tolower(ReportsToEmailName) == managerAlias
| where AccountEnabled != false
| project RecordType = "report", ManagerName = managerName, Alias,
          DisplayName, Mail, JobTitle
| union (
    print RecordType = "manager", ManagerName = managerName, Alias = managerAlias,
          DisplayName = managerName, Mail = strcat(managerAlias, "@microsoft.com"),
          JobTitle = "Management"
)
| order by RecordType asc, DisplayName asc
"""
    rows = kusto_query(
        CLUSTER,
        "AzureActiveDirectory",
        query,
        token=token,
        timeout=120,
        server_timeout="00:02:00",
        raise_on_partial=True,
        label="direct-reports-pulse-fast :: roster",
    )
    manager_name = next(
        (str(row.get("ManagerName") or "") for row in rows if row.get("RecordType") == "manager"),
        manager,
    )
    people = [
        Person(
            alias=str(row["Alias"]).lower(),
            name=str(row.get("DisplayName") or row["Alias"]),
            area=str(row.get("JobTitle") or "Unknown"),
        )
        for row in rows
        if row.get("RecordType") == "report"
    ]
    if not people:
        raise RuntimeError(f"AAD returned no current direct reports for manager {manager!r}")
    return manager_name or manager, people


def parse_team_file(path: Path | None) -> dict[str, Person]:
    if path is None:
        return {}
    text = path.read_text(encoding="utf-8")
    direct = text.split("## Direct Reports", 1)
    if len(direct) != 2:
        return {}
    section = direct[1].split("\n## ", 1)[0]
    people: dict[str, Person] = {}
    for line in section.splitlines():
        if not line.startswith("|") or "`" not in line:
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) < 4 or cells[0] in {"Person", "---"}:
            continue
        alias_match = re.search(r"`([^`]+)`", cells[1])
        if not alias_match:
            continue
        alias = alias_match.group(1).lower()
        people[alias] = Person(alias, cells[0], cells[2], cells[3])
    return people


def ado_query(aliases: list[str], start: datetime, end: datetime) -> str:
    alias_values = kql_dynamic(aliases)
    return f"""
let aliases = {alias_values};
let startDate = datetime({start.isoformat().replace("+00:00", "Z")});
let endDate = datetime({end.isoformat().replace("+00:00", "Z")});
let prs = materialize(
    PullRequest
    | where CreationDate between (startDate .. endDate)
        or ClosedDate between (startDate .. endDate)
    | where EtlProcessDate <= endDate
    | extend AuthorAlias = tolower(tostring(split(CreatedByUniqueName, "@")[0]))
    | where AuthorAlias in (aliases)
    | project OrganizationName, ProjectId, RepositoryId, PullRequestId,
              EtlProcessDate, Title, Description, Status, TargetRefName,
              RepositoryName, RepositoryProjectName, CreatedByDisplayName,
              CreatedByUniqueName, AuthorAlias, CreationDate, ClosedDate
    | summarize arg_max(
        EtlProcessDate, Title, Description, Status, TargetRefName,
        RepositoryName, RepositoryProjectName, CreatedByDisplayName,
        CreatedByUniqueName, AuthorAlias, CreationDate, ClosedDate, ProjectId)
        by OrganizationName, RepositoryId, PullRequestId
);
prs
| project Source = "ADO",
          StableKey = strcat("ado:", OrganizationName, ":", RepositoryId, ":", PullRequestId),
          AuthorAlias,
          AuthorName = CreatedByDisplayName,
          RepositoryHost = "",
          Organization = OrganizationName,
          Project = RepositoryProjectName,
          Repository = RepositoryName,
          PullRequestId,
          Number = PullRequestId,
          Title,
          Description,
          Url = strcat("https://dev.azure.com/", OrganizationName, "/", RepositoryProjectName,
                       "/_git/", RepositoryName, "/pullrequest/", tostring(PullRequestId)),
          Created = CreationDate,
          Closed = ClosedDate,
          Status = tolower(Status),
          TargetRef = TargetRefName,
          DefaultBranch = iff(
              TargetRefName in ("refs/heads/main", "refs/heads/master"),
              TargetRefName,
              ""
          )
"""


def github_query(aliases: list[str], start: datetime, end: datetime) -> str:
    alias_values = kql_dynamic(aliases)
    login_rows = ",".join(
        f"{kql_string(login)},{kql_string(alias)}"
        for alias in aliases
        for login in (alias, f"{alias}_microsoft")
    )
    return f"""
let aliases = {alias_values};
let loginAliases = datatable(Login:string, LoginAlias:string)[{login_rows}];
let startDate = datetime({start.isoformat().replace("+00:00", "Z")});
let endDate = datetime({end.isoformat().replace("+00:00", "Z")});
let users = materialize(
    User
    | where isnotempty(Login)
    | summarize arg_max(EtlProcessStartDate, Login, Email, Name) by Hostname, UserId
    | extend Hostname = tolower(iff(isempty(Hostname), "github.com", Hostname)),
             Login = tolower(Login),
             EmailAlias = tolower(tostring(split(tostring(split(Email, "@")[0]), "+")[0]))
    | join kind=leftouter loginAliases on Login
    | extend AuthorAlias = coalesce(LoginAlias, EmailAlias)
    | where Email endswith "@microsoft.com"
        or isnotempty(LoginAlias)
    | where AuthorAlias in (aliases)
    | project Hostname, UserId = tolong(UserId), Login, Email, Name, AuthorAlias
);
let prs = materialize(
    PullRequest
    | where CreatedAt between (startDate .. endDate)
        or ClosedAt between (startDate .. endDate)
    | where EtlProcessStartDate <= endDate
    | extend Hostname = tolower(iff(isempty(Hostname), "github.com", Hostname))
    | join kind=inner users on Hostname, UserId
    | extend Payload = parse_json(Data)
    | project Hostname, OrganizationId = tolong(OrganizationId),
              RepositoryId = tolong(RepositoryId), PullRequestId = tolong(PullRequestId),
              Number = tolong(Number), HtmlUrl, Body, ClosedAt, CreatedAt, State,
              Title, MergedAt, OrganizationLogin, RepositoryName,
              EtlProcessStartDate, UserLogin, AuthorAlias, AuthorName = Name,
              TargetRef = strcat("refs/heads/", tostring(Payload.base.ref)),
              DefaultBranch = strcat("refs/heads/", tostring(Payload.base.repo.default_branch))
    | summarize arg_max(
        EtlProcessStartDate, Number, HtmlUrl, Body, ClosedAt, CreatedAt, State,
        Title, MergedAt, OrganizationLogin, RepositoryName, UserLogin,
        AuthorAlias, AuthorName, TargetRef, DefaultBranch)
        by Hostname, OrganizationId, RepositoryId, PullRequestId
);
prs
| project Source = "GH",
          StableKey = strcat("gh:", Hostname, ":", OrganizationId, ":", RepositoryId, ":", PullRequestId),
          AuthorAlias,
          AuthorName,
          RepositoryHost = Hostname,
          Organization = OrganizationLogin,
          Project = "",
          Repository = RepositoryName,
          PullRequestId,
          Number,
          Title,
          Description = Body,
          Url = HtmlUrl,
          Created = CreatedAt,
          Closed = coalesce(MergedAt, ClosedAt),
          Status = case(isnotnull(MergedAt), "completed", State == "closed", "abandoned", "active"),
          TargetRef,
          DefaultBranch
"""


def query_prs(
    kusto_query,
    partial_result_error,
    token: str,
    aliases: list[str],
    start: datetime,
    end: datetime,
) -> list[dict[str, Any]]:
    def run(database: str, query: str, name: str) -> list[dict[str, Any]]:
        for attempt in range(3):
            try:
                return kusto_query(
                    CLUSTER,
                    database,
                    query,
                    token=token,
                    timeout=180,
                    server_timeout="00:03:00",
                    raise_on_partial=True,
                    label=f"direct-reports-pulse-fast :: {name}",
                )
            except partial_result_error:
                if attempt == 2:
                    raise
                time.sleep(2 ** attempt)
        raise AssertionError("unreachable")

    jobs = [
        ("AzureDevOps", ado_query(aliases, start, end), "ado"),
        ("GitHub.EMU", github_query(aliases, start, end), "github"),
    ]
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = {
            name: pool.submit(run, database, query, name)
            for database, query, name in jobs
        }
        rows: list[dict[str, Any]] = []
        for name, future in futures.items():
            result = future.result()
            for row in result:
                row["_query"] = name
            rows.extend(result)
    return rows


def parse_dt(value: Any) -> datetime | None:
    if value in (None, ""):
        return None
    if isinstance(value, datetime):
        parsed = value
    else:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def normalize_rows(
    rows: list[dict[str, Any]],
    chore_rule_kind,
    business_hours_between,
    is_trunk,
    trunk_map,
) -> list[dict[str, Any]]:
    normalized = []
    seen: set[str] = set()
    for row in rows:
        key = str(row["StableKey"])
        if key in seen:
            continue
        seen.add(key)
        created = parse_dt(row.get("Created"))
        closed = parse_dt(row.get("Closed"))
        status = str(row.get("Status") or "").lower()
        target = str(row.get("TargetRef") or "")
        pr_for_trunk = {
            "targetRefName": target,
            "repositoryHost": row.get("RepositoryHost") or "",
            "organization": row.get("Organization") or "",
            "repositoryName": row.get("Repository") or "",
            "defaultBranch": row.get("DefaultBranch") or "",
        }
        chore_kind = chore_rule_kind(str(row.get("Title") or ""))
        record = {
            "source": row["Source"],
            "key": key,
            "author": str(row.get("AuthorAlias") or "").lower(),
            "authorName": str(row.get("AuthorName") or row.get("AuthorAlias") or ""),
            "repository": f"{row.get('Organization')}/{row.get('Repository')}",
            "title": str(row.get("Title") or ""),
            "description": str(row.get("Description") or ""),
            "url": str(row.get("Url") or ""),
            "created": created.isoformat().replace("+00:00", "Z") if created else None,
            "closed": closed.isoformat().replace("+00:00", "Z") if closed else None,
            "status": status,
            "targetRef": target,
            "isTrunk": is_trunk(pr_for_trunk, trunk_map),
            "isChore": chore_kind is not None,
            "choreRuleKind": chore_kind,
            "mergeHours": (
                round(business_hours_between(created, closed), 3)
                if status == "completed" and created and closed
                else None
            ),
        }
        normalized.append(record)
    return sorted(normalized, key=lambda row: (row["created"] or "", row["key"]))


def nearest_rank(values: list[float], percentile: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    return ordered[max(0, math.ceil(percentile * len(ordered)) - 1)]


def in_window(value: str | None, start: date, end: date, now: datetime) -> bool:
    parsed = parse_dt(value)
    if parsed is None:
        return False
    lower = datetime.combine(start, dt_time.min, tzinfo=UTC)
    upper = min(
        datetime.combine(end + timedelta(days=1), dt_time.min, tzinfo=UTC),
        now.astimezone(UTC) + timedelta(microseconds=1),
    )
    return lower <= parsed < upper


def period_metrics(rows: list[dict[str, Any]], start: date, end: date, now: datetime) -> dict[str, Any]:
    usable = [row for row in rows if row["isTrunk"] and not row["isChore"]]
    opened_rows = [row for row in usable if in_window(row["created"], start, end, now)]
    merged_rows = [
        row for row in usable
        if row["status"] == "completed" and in_window(row["closed"], start, end, now)
    ]
    hours = [float(row["mergeHours"]) for row in merged_rows if row["mergeHours"] is not None]
    contributors = {row["author"] for row in opened_rows + merged_rows}
    return {
        "opened": len(opened_rows),
        "merged": len(merged_rows),
        "mergeRate": (100.0 * len(merged_rows) / len(opened_rows)) if opened_rows else None,
        "contributors": len(contributors),
        "mergedPerContributor": (len(merged_rows) / len(contributors)) if contributors else None,
        "median": nearest_rank(hours, 0.5),
        "p80": nearest_rank(hours, 0.8),
        "n": len(hours),
    }


def person_metrics(rows: list[dict[str, Any]], alias: str, start: date, end: date, now: datetime) -> dict[str, Any]:
    own = [row for row in rows if row["author"] == alias and row["isTrunk"] and not row["isChore"]]
    opened = [row for row in own if in_window(row["created"], start, end, now)]
    merged = [row for row in own if row["status"] == "completed" and in_window(row["closed"], start, end, now)]
    active = [row for row in own if row["status"] == "active"]
    hours = [float(row["mergeHours"]) for row in merged if row["mergeHours"] is not None]
    repos = Counter(row["repository"] for row in opened + merged)
    return {
        "opened": len(opened),
        "merged": len(merged),
        "active": len(active),
        "median": nearest_rank(hours, 0.5),
        "n": len(hours),
        "repos": [name for name, _ in repos.most_common(3)],
    }


def fmt_num(value: float | None, digits: int = 1) -> str:
    return "n/a" if value is None else f"{value:.{digits}f}"


def notable_work(rows: list[dict[str, Any]], start: date, end: date, now: datetime) -> list[dict[str, Any]]:
    merged = [
        row for row in rows
        if row["isTrunk"] and not row["isChore"] and row["status"] == "completed"
        and in_window(row["closed"], start, end, now)
    ]
    groups: dict[str, list[dict[str, Any]]] = {}
    for row in merged:
        groups.setdefault(row["repository"], []).append(row)
    themes = []
    for repository, group in sorted(groups.items(), key=lambda item: (-len(item[1]), item[0]))[:7]:
        evidence = sorted(group, key=lambda row: row["closed"] or "", reverse=True)[:3]
        authors = Counter(row["authorName"] for row in group)
        themes.append({
            "repository": repository,
            "count": len(group),
            "authors": [name for name, _ in authors.most_common(3)],
            "evidence": evidence,
        })
    return themes


def enrich_people(roster: list[Person], team: dict[str, Person], manager: str, manager_name: str) -> list[Person]:
    enriched = []
    for person in roster:
        known = team.get(person.alias)
        if known:
            note = known.note if known.area.casefold() == "leave" else ""
            enriched.append(Person(known.alias, known.name, known.area, note))
        else:
            enriched.append(person)
    enriched.append(Person(manager, f"{manager_name} (manager)", "Management"))
    return sorted(enriched, key=lambda person: (person.alias == manager, person.name.casefold()))


def render_markdown(
    manager_name: str,
    manager: str,
    people: list[Person],
    rows: list[dict[str, Any]],
    windows: list[dict[str, Any]],
    now: datetime,
    commit: str,
    elapsed: float,
) -> str:
    title = f"{manager_name}'s Direct Reports Pulse"
    lines = [f"# {title}", ""]
    lines.append(
        f"Window: **{windows[-1]['label']} (current week-to-date)** plus four preceding complete weeks. "
        f"Generated {now.astimezone().isoformat(timespec='seconds')}."
    )
    lines.extend(["", "## Team snapshot", ""])
    headers = [window["label"] + (" (WTD)" if window["current"] else "") for window in windows]
    lines.append("| Metric | " + " | ".join(headers) + " |")
    lines.append("|---|" + "|".join("---" for _ in headers) + "|")
    metrics = [period_metrics(rows, window["start"], window["end"], now) for window in windows]
    metric_rows = [
        ("Opened PRs", [str(item["opened"]) for item in metrics]),
        ("Merged PRs", [str(item["merged"]) for item in metrics]),
        ("Merge rate", [fmt_num(item["mergeRate"]) + "%" if item["mergeRate"] is not None else "n/a" for item in metrics]),
        ("Active contributors", [str(item["contributors"]) for item in metrics]),
        ("Merged PRs / active contributor", [fmt_num(item["mergedPerContributor"], 2) for item in metrics]),
        ("Median creation-to-merge (business hrs)", [fmt_num(item["median"]) for item in metrics]),
        ("P80 creation-to-merge (business hrs, n)", [f"{fmt_num(item['p80'])} (n={item['n']})" for item in metrics]),
    ]
    for label, values in metric_rows:
        lines.append("| " + label + " | " + " | ".join(values) + " |")

    overall_start, overall_end = windows[0]["start"], windows[-1]["end"]
    lines.extend(["", "## By direct report", ""])
    lines.append("| Person | Area | Opened | Merged | Active PRs | Median creation-to-merge (hrs) | Top repositories |")
    lines.append("|---|---|---:|---:|---:|---|---|")
    for person in people:
        item = person_metrics(rows, person.alias, overall_start, overall_end, now)
        display = person.name + (f" ({person.note})" if person.note else "")
        lines.append(
            f"| {display} | {person.area} | {item['opened']} | {item['merged']} | {item['active']} | "
            f"{fmt_num(item['median'])} (n={item['n']}) | {', '.join(item['repos']) or 'n/a'} |"
        )

    lines.extend(["", "## Weekly trends", "", "| Week | Opened | Merged | Merge rate | Median creation-to-merge (hrs) |", "|---|---:|---:|---:|---|"])
    for window, item in zip(windows, metrics):
        label = window["label"] + (" (WTD) _(incomplete)_" if window["current"] else "")
        rate = fmt_num(item["mergeRate"]) + "%" if item["mergeRate"] is not None else "n/a"
        lines.append(f"| {label} | {item['opened']} | {item['merged']} | {rate} | {fmt_num(item['median'])} (n={item['n']}) |")

    lines.extend(["", "## Notable work", ""])
    for theme in notable_work(rows, overall_start, overall_end, now):
        evidence = "; ".join(f"[{row['title']}]({row['url']})" for row in theme["evidence"])
        authors = ", ".join(theme["authors"])
        lines.append(f"- **{theme['repository']}** - {theme['count']} merged non-chore PRs. Main contributors: {authors}. Evidence: {evidence}")
    if not notable_work(rows, overall_start, overall_end, now):
        lines.append("- No merged non-chore PRs in the selected period.")

    chore_count = sum(1 for row in rows if row["isChore"])
    ado_count = sum(1 for row in rows if row["source"] == "ADO")
    gh_count = sum(1 for row in rows if row["source"] == "GH")
    lines.extend([
        "",
        "## Data notes",
        "",
        f"- Manager input: `{manager}`. AAD supplied {len(people) - 1} current direct reports; the manager is included as an additional row.",
        f"- EngPulse source commit: `{commit}`.",
        "- Included databases: `AzureActiveDirectory`, `AzureDevOps`, and `GitHub.EMU`. `GitHub.Proxima` is explicitly excluded.",
        f"- Source rows: {len(rows)} deduplicated PRs ({ado_count} ADO, {gh_count} GitHub); {chore_count} classified as chores.",
        "- ADX performs date pruning, identity resolution, and snapshot deduplication. Python reuses EngPulse's chore, trunk, and weekend-hour rules.",
        f"- Runtime: {elapsed:.1f} seconds.",
        "",
    ])
    return "\n".join(lines)


def json_for_script(value: Any) -> str:
    return json.dumps(value, separators=(",", ":"), default=str).replace("</", "<\\/")


def render_html(
    manager_name: str,
    people: list[Person],
    rows: list[dict[str, Any]],
    windows: list[dict[str, Any]],
    now: datetime,
) -> str:
    payload = {
        "manager": manager_name,
        "generated": now.astimezone().isoformat(timespec="seconds"),
        "people": [person.__dict__ for person in people],
        "rows": rows,
        "windows": [
            {
                "start": window["start"].isoformat(),
                "end": window["end"].isoformat(),
                "label": window["label"],
                "current": window["current"],
            }
            for window in windows
        ],
    }
    title = html.escape(f"{manager_name}'s Direct Reports Pulse")
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title}</title>
<style>
:root{{--bg:#f5f6f8;--card:#fff;--text:#182230;--muted:#657083;--line:#d9dee7;--accent:#2563eb}}
*{{box-sizing:border-box}} body{{margin:0;background:var(--bg);color:var(--text);font:14px/1.45 Segoe UI,Arial,sans-serif}}
main{{max-width:1180px;margin:0 auto;padding:28px}} h1{{margin:0 0 4px}} h2{{margin-top:28px}}
.muted{{color:var(--muted)}} .controls{{display:flex;gap:12px;align-items:center;margin:20px 0}}
select{{padding:8px 10px;border:1px solid var(--line);border-radius:6px;background:white}}
.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}}
.card{{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:14px}}
.value{{font-size:24px;font-weight:650}} table{{width:100%;border-collapse:collapse;background:white}}
th,td{{padding:9px 10px;border:1px solid var(--line);text-align:left;vertical-align:top}} th{{background:#eef1f5}}
button.person{{border:0;background:none;color:var(--accent);cursor:pointer;padding:0;font:inherit}}
.bars{{display:grid;gap:8px}} .bar{{display:grid;grid-template-columns:210px 1fr 52px;gap:8px;align-items:center}}
.track{{height:12px;background:#e5e9ef;border-radius:8px;overflow:hidden}} .fill{{height:100%;background:#7b8797}}
.bar.selected .fill{{background:var(--accent)}} a{{color:var(--accent)}} .hidden{{display:none}}
</style></head><body><main>
<h1>{title}</h1><div id="subtitle" class="muted"></div>
<div class="controls"><label for="period">Period</label><select id="period"></select></div>
<section><h2>Team snapshot</h2><div id="snapshot" class="grid"></div></section>
<section><h2>By direct report</h2><div id="people"></div></section>
<section><h2>Weekly trends</h2><div id="trends" class="bars"></div></section>
<section><h2 id="drillTitle">PR details</h2><div id="details"></div></section>
<section><h2>Notable work</h2><div id="notable"></div></section>
</main><script id="pulse-data" type="application/json">{json_for_script(payload)}</script>
<script>
const data=JSON.parse(document.getElementById("pulse-data").textContent);
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({{"&":"&amp;","<":"&lt;",">":"&gt;","\\"":"&quot;","'":"&#39;"}}[c]));
const dt=s=>s?new Date(s):null;
const inPeriod=(s,p)=>{{const d=dt(s);return d&&d>=new Date(p.start+"T00:00:00Z")&&d<new Date(new Date(p.end+"T00:00:00Z").getTime()+86400000)}};
const usable=r=>r.isTrunk&&!r.isChore;
const nearest=(a,p)=>a.length?[...a].sort((x,y)=>x-y)[Math.max(0,Math.ceil(p*a.length)-1)]:null;
const fmt=(v,d=1)=>v==null?"n/a":Number(v).toFixed(d);
function metrics(rows,p){{const opened=rows.filter(r=>usable(r)&&inPeriod(r.created,p));const merged=rows.filter(r=>usable(r)&&r.status==="completed"&&inPeriod(r.closed,p));const h=merged.map(r=>r.mergeHours).filter(v=>v!=null);const c=new Set([...opened,...merged].map(r=>r.author));return{{opened:opened.length,merged:merged.length,rate:opened.length?100*merged.length/opened.length:null,contributors:c.size,median:nearest(h,.5),p80:nearest(h,.8),n:h.length}}}}
const selector=document.getElementById("period");
data.windows.forEach((p,i)=>selector.add(new Option(p.label+(p.current?" (WTD)":""),String(i))));
selector.add(new Option("All five weeks","all")); selector.value=String(data.windows.length-1);
let selectedPerson=data.people[0]?.alias||"";
function selectedPeriod(){{if(selector.value==="all")return{{start:data.windows[0].start,end:data.windows.at(-1).end,label:"All five weeks"}};return data.windows[Number(selector.value)]}}
function render(){{
 const p=selectedPeriod(),m=metrics(data.rows,p);
 document.getElementById("subtitle").textContent=p.label+" · generated "+data.generated;
 document.getElementById("snapshot").innerHTML=[
 ["Opened PRs",m.opened],["Merged PRs",m.merged],["Merge rate",m.rate==null?"n/a":fmt(m.rate)+"%"],
 ["Active contributors",m.contributors],["Median merge hours",fmt(m.median)],["P80 merge hours",fmt(m.p80)+" (n="+m.n+")"]
 ].map(x=>`<div class="card"><div class="muted">${{x[0]}}</div><div class="value">${{x[1]}}</div></div>`).join("");
 const people=data.people.map(person=>{{const own=data.rows.filter(r=>r.author===person.alias);const pm=metrics(own,p);const active=own.filter(r=>usable(r)&&r.status==="active"&&inPeriod(r.created,p)).length;return{{person,pm,active}}}});
 document.getElementById("people").innerHTML=`<table><thead><tr><th>Person</th><th>Area</th><th>Opened</th><th>Merged</th><th>Active</th><th>Median hours</th></tr></thead><tbody>${{people.map(x=>`<tr><td><button class="person" data-alias="${{esc(x.person.alias)}}">${{esc(x.person.name)}}</button>${{x.person.note?`<div class="muted">${{esc(x.person.note)}}</div>`:""}}</td><td>${{esc(x.person.area)}}</td><td>${{x.pm.opened}}</td><td>${{x.pm.merged}}</td><td>${{x.active}}</td><td>${{fmt(x.pm.median)}} (n=${{x.pm.n}})</td></tr>`).join("")}}</tbody></table>`;
 document.querySelectorAll("button.person").forEach(b=>b.onclick=()=>{{selectedPerson=b.dataset.alias;renderDetails(p)}});
 const weekly=data.windows.map(w=>({{w,m:metrics(data.rows,w)}}));const max=Math.max(1,...weekly.map(x=>Math.max(x.m.opened,x.m.merged)));
 document.getElementById("trends").innerHTML=weekly.map((x,i)=>`<div class="bar ${{selector.value===String(i)?"selected":""}}"><div>${{esc(x.w.label)}}${{x.w.current?" (WTD)":""}}</div><div><div class="track"><div class="fill" style="width:${{100*x.m.merged/max}}%"></div></div></div><div>${{x.m.merged}}</div></div>`).join("");
 renderDetails(p); renderNotable(p);
}}
function renderDetails(p){{const person=data.people.find(x=>x.alias===selectedPerson);document.getElementById("drillTitle").textContent=(person?person.name:"Selected person")+" - PR details";const rows=data.rows.filter(r=>r.author===selectedPerson&&usable(r)&&(inPeriod(r.created,p)||inPeriod(r.closed,p)));document.getElementById("details").innerHTML=rows.length?`<table><thead><tr><th>Repository</th><th>PR</th><th>Status</th><th>Opened</th><th>Merged</th><th>Hours</th></tr></thead><tbody>${{rows.map(r=>`<tr><td>${{esc(r.repository)}}</td><td><a href="${{esc(r.url)}}" target="_blank" rel="noreferrer">${{esc(r.title)}}</a></td><td>${{esc(r.status)}}</td><td>${{esc((r.created||"").slice(0,10))}}</td><td>${{esc((r.closed||"").slice(0,10))}}</td><td>${{fmt(r.mergeHours)}}</td></tr>`).join("")}}</tbody></table>`:`<div class="card muted">No qualifying PRs in this period.</div>`}}
function renderNotable(p){{const merged=data.rows.filter(r=>usable(r)&&r.status==="completed"&&inPeriod(r.closed,p));const groups={{}};merged.forEach(r=>(groups[r.repository]??=[]).push(r));const entries=Object.entries(groups).sort((a,b)=>b[1].length-a[1].length).slice(0,7);document.getElementById("notable").innerHTML=entries.length?entries.map(([repo,rows])=>`<div class="card"><strong>${{esc(repo)}}</strong> - ${{rows.length}} merged PRs<br>${{rows.slice(0,3).map(r=>`<a href="${{esc(r.url)}}" target="_blank" rel="noreferrer">${{esc(r.title)}}</a>`).join("; ")}}</div>`).join(""):`<div class="card muted">No merged non-chore PRs in this period.</div>`}}
selector.onchange=render;render();
</script></body></html>"""


def git_commit(repo: Path) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def summary(rows: list[dict[str, Any]], windows: list[dict[str, Any]], now: datetime, manager_name: str) -> str:
    current = period_metrics(rows, windows[-1]["start"], windows[-1]["end"], now)
    overall = period_metrics(rows, windows[0]["start"], windows[-1]["end"], now)
    return (
        f"{manager_name}'s team opened {current['opened']} and merged {current['merged']} qualifying PRs "
        f"in the current week-to-date. Across all five weeks, it opened {overall['opened']} and merged "
        f"{overall['merged']}; median creation-to-merge was {fmt_num(overall['median'])} business hours."
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate a fast direct-reports engineering pulse.")
    parser.add_argument("--manager", required=True, help="Manager alias or Microsoft email.")
    parser.add_argument("--engpulse", type=Path, default=Path(r"C:\repos\engpulse"))
    parser.add_argument("--team-file", type=Path)
    parser.add_argument(
        "--as-of",
        help="Reproduce a report at an ISO timestamp instead of using the current time.",
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path.home() / "AppData" / "Local" / "engpulse" / "direct-reports-pulse-fast",
    )
    parser.add_argument("--no-open", action="store_true")
    return parser.parse_args()


def main() -> int:
    started = time.perf_counter()
    args = parse_args()
    manager = normalize_manager(args.manager)
    now = (
        datetime.fromisoformat(args.as_of.replace("Z", "+00:00")).astimezone()
        if args.as_of
        else datetime.now().astimezone()
    )
    windows = week_windows(now)
    source_start, source_end = utc_bounds(windows, now)
    (
        KustoPartialResultError,
        get_kusto_access_token,
        kusto_query,
        chore_rule_kind,
        business_hours_between,
        is_trunk,
        load_trunk_map,
    ) = import_engpulse(args.engpulse)
    token = get_kusto_access_token().token
    manager_name, roster = query_roster(kusto_query, token, manager)
    team = parse_team_file(args.team_file)
    people = enrich_people(roster, team, manager, manager_name)
    aliases = sorted({person.alias for person in people})
    raw_rows = query_prs(
        kusto_query,
        KustoPartialResultError,
        token,
        aliases,
        source_start,
        source_end,
    )
    rows = normalize_rows(
        raw_rows,
        chore_rule_kind,
        business_hours_between,
        is_trunk,
        load_trunk_map(),
    )
    window_name = f"{windows[-1]['start'].isoformat()}_{windows[-1]['end'].isoformat()}"
    output_dir = args.output_root / manager / window_name
    output_dir.mkdir(parents=True, exist_ok=True)
    elapsed = time.perf_counter() - started
    markdown = render_markdown(
        manager_name,
        manager,
        people,
        rows,
        windows,
        now,
        git_commit(args.engpulse),
        elapsed,
    )
    html_text = render_html(manager_name, people, rows, windows, now)
    md_path = output_dir / "direct-reports-pulse.md"
    html_path = output_dir / "direct-reports-pulse.html"
    data_path = output_dir / "normalized-prs.json"
    md_path.write_text(markdown, encoding="utf-8")
    html_path.write_text(html_text, encoding="utf-8")
    data_path.write_text(json.dumps(rows, indent=2, default=str), encoding="utf-8")
    if not args.no_open:
        subprocess.run(["powershell", "-NoProfile", "-Command", "Start-Process", str(html_path)], check=True)
    result = {
        "manager": manager,
        "elapsedSeconds": round(time.perf_counter() - started, 1),
        "markdown": str(md_path),
        "html": str(html_path),
        "data": str(data_path),
        "rows": len(rows),
        "summary": summary(rows, windows, now, manager_name),
    }
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
