#!/usr/bin/env node
/**
 * lanz-health.js — one-line health signal for the Markus Lanz guest lookup.
 *
 * Why this exists: lanz-guests.js exits 0 and prints nothing when it finds no
 * guests, so "job ran fine but the parser silently matched nothing" looks
 * identical to "page not published yet" in the run history. This script closes
 * that gap by checking the DATABASE for the previous show day instead of the
 * job status.
 *
 * Reads the DB read-only. Never writes. Silent on non-show days so the morning
 * digest stays quiet when there is nothing to say.
 *
 * Output (one line, only when the previous day was a show day):
 *   Lanz: gestern OK — Mi 07.10., 4 Gäste
 *   Lanz: FEHLT für Mi 07.10. — Gästeliste prüfen
 */
const path = require('path');

const DB_PATH = path.join(__dirname, 'lanz-guests.db');

// Suppress only Node's experimental SQLite warning, nothing else.
const origEmit = process.emitWarning;
process.emitWarning = function (warning, ...args) {
  const isSqliteWarn =
    (typeof warning === 'string' && warning.includes('SQLite is an experimental feature')) ||
    (warning && warning.name === 'ExperimentalWarning' &&
     typeof warning.message === 'string' &&
     warning.message.includes('SQLite is an experimental feature'));
  if (isSqliteWarn) return;
  return origEmit.call(process, warning, ...args);
};

const WEEKDAY_DE = { Mon: 'Mo', Tue: 'Di', Wed: 'Mi', Thu: 'Do', Fri: 'Fr', Sat: 'Sa', Sun: 'So' };

function berlinParts(dt) {
  const p = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Berlin', year: 'numeric', month: '2-digit', day: '2-digit'
  }).formatToParts(dt);
  const g = (t) => p.find((x) => x.type === t).value;
  return { key: `${g('year')}-${g('month')}-${g('day')}`, y: +g('year'), m: +g('month'), d: +g('day') };
}

function weekdayEn(dt) {
  return new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/Berlin', weekday: 'short' }).format(dt);
}

// IMPORTANT: never use new Date(toLocaleString(...)) here — that misreads the
// German string as US format (8.10. -> August 10) and is exactly the bug this
// health check is meant to catch elsewhere.
const today = berlinParts(new Date());
// Anchor at 12:00 UTC on today's Berlin date, then step back one day. Noon keeps
// the arithmetic inside the correct calendar day across DST changes.
const anchor = Date.UTC(today.y, today.m - 1, today.d, 12, 0, 0);
const yDate = new Date(anchor - 86400000);
const y = berlinParts(yDate);
const yWd = weekdayEn(yDate);

// Lanz airs Tuesday to Thursday.
if (!['Tue', 'Wed', 'Thu'].includes(yWd)) {
  process.exit(0);
}

const label = `${WEEKDAY_DE[yWd] ?? yWd} ${String(y.d).padStart(2, '0')}.${String(y.m).padStart(2, '0')}.`;

let guests = null;
let dbError = null;
try {
  const { DatabaseSync } = require('node:sqlite');
  const db = new DatabaseSync(DB_PATH, { readOnly: true });
  try {
    const row = db.prepare('SELECT COUNT(*) AS n FROM guests WHERE show_date = ?').get(y.key);
    const show = db.prepare('SELECT date FROM shows WHERE date = ?').get(y.key);
    guests = show ? (row?.n ?? 0) : null;
  } finally {
    db.close();
  }
} catch (err) {
  dbError = err.message;
}

if (dbError) {
  console.log(`Lanz: Prüfung fehlgeschlagen (${dbError})`);
} else if (guests === null) {
  console.log(`Lanz: FEHLT für ${label} — Gästeliste prüfen`);
} else if (guests === 0) {
  console.log(`Lanz: ${label} gespeichert, aber 0 Gäste — Parser prüfen`);
} else {
  console.log(`Lanz: gestern OK — ${label}, ${guests} Gäste`);
}
