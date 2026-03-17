#!/usr/bin/env node
/**
 * claude-cost — Calculate total API-equivalent cost of all Claude Code sessions.
 *
 * Reads the stats-cache.json for historical data, then scans session JSONL files
 * modified after the cache date for recent usage. Deduplicates by message ID
 * (keeps last entry per ID) and applies current API pricing.
 *
 * Usage:  node ~/.claude/scripts/claude-cost.mjs [--no-cache] [--after YYYY-MM-DD]
 *   --no-cache    Ignore stats-cache.json and parse all session files from scratch
 *   --after DATE  Only count usage after this date (inclusive)
 */

import { readFileSync, readdirSync, statSync, existsSync } from "fs";
import { join, resolve } from "path";
import { homedir } from "os";

// ── Pricing (USD per million tokens) ────────────────────────────────────────
const PRICING = {
  "claude-opus-4-6":            { input: 5,  output: 25, cacheRead: 0.50, cacheWrite: 6.25 },
  "claude-opus-4-5":            { input: 5,  output: 25, cacheRead: 0.50, cacheWrite: 6.25 },
  "claude-opus-4-1":            { input: 15, output: 75, cacheRead: 1.50, cacheWrite: 18.75 },
  "claude-opus-4":              { input: 15, output: 75, cacheRead: 1.50, cacheWrite: 18.75 },
  "claude-sonnet-4-6":          { input: 3,  output: 15, cacheRead: 0.30, cacheWrite: 3.75 },
  "claude-sonnet-4-5-20250929": { input: 3,  output: 15, cacheRead: 0.30, cacheWrite: 3.75 },
  "claude-sonnet-4":            { input: 3,  output: 15, cacheRead: 0.30, cacheWrite: 3.75 },
  "claude-haiku-4-5":           { input: 1,  output: 5,  cacheRead: 0.10, cacheWrite: 1.25 },
};

const CLAUDE_DIR = join(homedir(), ".claude");
const PROJECTS_DIR = join(CLAUDE_DIR, "projects");
const STATS_CACHE = join(CLAUDE_DIR, "stats-cache.json");

// ── CLI args ────────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const noCache = args.includes("--no-cache");
const afterIdx = args.indexOf("--after");
const afterDate = afterIdx !== -1 ? args[afterIdx + 1] : null;

// ── Helpers ─────────────────────────────────────────────────────────────────
function findJsonlFiles(dir) {
  const files = [];
  if (!existsSync(dir)) return files;
  for (const project of readdirSync(dir)) {
    const projectDir = join(dir, project);
    let stat;
    try { stat = statSync(projectDir); } catch { continue; }
    if (!stat.isDirectory()) continue;
    for (const f of readdirSync(projectDir)) {
      if (f.endsWith(".jsonl")) files.push(join(projectDir, f));
    }
  }
  return files;
}

function makeAccum() {
  return { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };
}

function addUsage(accum, model, usage) {
  if (!accum[model]) accum[model] = makeAccum();
  accum[model].input      += usage.input_tokens || 0;
  accum[model].output     += usage.output_tokens || 0;
  accum[model].cacheRead  += usage.cache_read_input_tokens || 0;
  accum[model].cacheWrite += usage.cache_creation_input_tokens || 0;
}

function cost(model, tokens) {
  const p = PRICING[model];
  if (!p) return 0;
  const m = 1_000_000;
  return (tokens.input / m * p.input)
       + (tokens.output / m * p.output)
       + (tokens.cacheRead / m * p.cacheRead)
       + (tokens.cacheWrite / m * p.cacheWrite);
}

function fmtNum(n) {
  if (n >= 1_000_000_000) return (n / 1_000_000_000).toFixed(1) + "B";
  if (n >= 1_000_000)     return (n / 1_000_000).toFixed(1) + "M";
  if (n >= 1_000)         return (n / 1_000).toFixed(1) + "K";
  return String(n);
}

function fmtUSD(n) { return "$" + n.toFixed(2); }

// ── Step 1: Load stats cache ────────────────────────────────────────────────
const usage = {};   // model -> { input, output, cacheRead, cacheWrite }
let cacheDate = null;
let totalSessions = 0;
let totalMessages = 0;

if (!noCache && existsSync(STATS_CACHE)) {
  const cache = JSON.parse(readFileSync(STATS_CACHE, "utf8"));
  cacheDate = cache.lastComputedDate; // "YYYY-MM-DD"
  totalSessions = cache.totalSessions || 0;
  totalMessages = cache.totalMessages || 0;

  if (cache.modelUsage) {
    for (const [model, u] of Object.entries(cache.modelUsage)) {
      if (!usage[model]) usage[model] = makeAccum();
      usage[model].input      += u.inputTokens || 0;
      usage[model].output     += u.outputTokens || 0;
      usage[model].cacheRead  += u.cacheReadInputTokens || 0;
      usage[model].cacheWrite += u.cacheCreationInputTokens || 0;
    }
  }

  if (afterDate && afterDate > cacheDate) {
    for (const m of Object.keys(usage)) delete usage[m];
    cacheDate = null;
    totalSessions = 0;
    totalMessages = 0;
  }
}

// ── Step 2: Parse session files newer than cache ────────────────────────────
const cutoffTime = cacheDate
  ? new Date(cacheDate + "T23:59:59Z").getTime()
  : 0;

const allFiles = findJsonlFiles(PROJECTS_DIR);
const filesToParse = noCache
  ? allFiles
  : allFiles.filter(f => {
      try { return statSync(f).mtimeMs > cutoffTime; } catch { return false; }
    });

console.log(`Stats cache: ${cacheDate || "not used"}`);
console.log(`Scanning ${filesToParse.length} session file(s) beyond cache...\n`);

let extraMessages = 0;
const globalSeen = new Set();

for (const file of filesToParse) {
  let content;
  try { content = readFileSync(file, "utf8"); } catch { continue; }

  const lastByMsg = new Map();

  for (const line of content.split("\n")) {
    if (!line.includes('"usage"') || !line.includes('"assistant"')) continue;
    let obj;
    try { obj = JSON.parse(line); } catch { continue; }
    if (obj.type !== "assistant" || !obj.message?.usage) continue;

    const ts = obj.timestamp || obj.message?.timestamp;
    if (afterDate && ts && ts < afterDate) continue;
    if (cacheDate && !noCache && ts && ts <= cacheDate + "T23:59:59Z") continue;

    const msgId = obj.message.id;
    if (!msgId) continue;
    lastByMsg.set(msgId, obj);
  }

  for (const [msgId, obj] of lastByMsg) {
    if (globalSeen.has(msgId)) continue;
    globalSeen.add(msgId);
    addUsage(usage, obj.message.model, obj.message.usage);
    extraMessages++;
  }
}

// ── Step 3: Display results ─────────────────────────────────────────────────
const models = Object.keys(usage).filter(m => m !== "<synthetic>").sort();

if (models.length === 0) {
  console.log("No usage data found.");
  process.exit(0);
}

const cols = ["Model", "Input", "Output", "Cache Read", "Cache Write", "Cost"];
const widths = [30, 10, 10, 12, 12, 10];
const header = cols.map((c, i) => c.padEnd(widths[i])).join(" ");
console.log(header);
console.log("─".repeat(header.length));

let grandTotal = 0;
const grandTokens = makeAccum();

for (const model of models) {
  const t = usage[model];
  const c = cost(model, t);
  grandTotal += c;
  grandTokens.input += t.input;
  grandTokens.output += t.output;
  grandTokens.cacheRead += t.cacheRead;
  grandTokens.cacheWrite += t.cacheWrite;

  const row = [
    model.padEnd(widths[0]),
    fmtNum(t.input).padStart(widths[1]),
    fmtNum(t.output).padStart(widths[2]),
    fmtNum(t.cacheRead).padStart(widths[3]),
    fmtNum(t.cacheWrite).padStart(widths[4]),
    fmtUSD(c).padStart(widths[5]),
  ];
  console.log(row.join(" "));
}

console.log("─".repeat(header.length));
const totalRow = [
  "TOTAL".padEnd(widths[0]),
  fmtNum(grandTokens.input).padStart(widths[1]),
  fmtNum(grandTokens.output).padStart(widths[2]),
  fmtNum(grandTokens.cacheRead).padStart(widths[3]),
  fmtNum(grandTokens.cacheWrite).padStart(widths[4]),
  fmtUSD(grandTotal).padStart(widths[5]),
];
console.log(totalRow.join(" "));

const totalTokens = grandTokens.input + grandTokens.output + grandTokens.cacheRead + grandTokens.cacheWrite;
console.log(`\nTotal tokens: ${fmtNum(totalTokens)}`);
console.log(`Sessions: ${totalSessions}+ | Messages: ${totalMessages}+ (plus ${extraMessages} recent)`);
console.log(`\nNote: This is the API-equivalent cost. Subscription plans are billed at a flat monthly rate.`);
