const path = require('path');

const DB_PATH = path.join(__dirname, 'lanz-guests.db');

// Suppress Node's experimental SQLite warning for this script only.
// This is intentionally narrow so it does not hide unrelated warnings.
const originalEmitWarning = process.emitWarning;
process.emitWarning = function (warning, ...args) {
  if (
    warning &&
    typeof warning === 'string' &&
    warning.includes('SQLite is an experimental feature')
  ) {
    return;
  }

  if (
    warning &&
    warning.name === 'ExperimentalWarning' &&
    typeof warning.message === 'string' &&
    warning.message.includes('SQLite is an experimental feature')
  ) {
    return;
  }

  return originalEmitWarning.call(process, warning, ...args);
};

const { DatabaseSync } = require('node:sqlite');
process.emitWarning = originalEmitWarning;

class LanzDatabase {
  constructor() {
    this.db = new DatabaseSync(DB_PATH);
    this.init();
  }

  init() {
    // Shows table: one row per episode
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS shows (
        date TEXT PRIMARY KEY,
        source_url TEXT NOT NULL,
        retrieved_at TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Guests table: one row per guest per show
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS guests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        show_date TEXT NOT NULL REFERENCES shows(date) ON DELETE CASCADE,
        name TEXT NOT NULL,
        title TEXT,
        raw_entry TEXT NOT NULL,
        party TEXT,
        profession TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Index for fast date lookups
    this.db.exec(`
      CREATE INDEX IF NOT EXISTS idx_guests_show_date ON guests(show_date)
    `);
  }

  findByDate(date) {
    const showStmt = this.db.prepare('SELECT * FROM shows WHERE date = ?');
    const show = showStmt.get(date);
    if (!show) return null;

    const guestsStmt = this.db.prepare(
      'SELECT name, title, raw_entry, party, profession FROM guests WHERE show_date = ? ORDER BY id'
    );
    const guests = guestsStmt.all(date);

    return { ...show, guests };
  }

  addShow(date, sourceUrl, guests, retrievedAt) {
    const insertShow = this.db.prepare(
      'INSERT INTO shows (date, source_url, retrieved_at) VALUES (?, ?, ?)'
    );
    const insertGuest = this.db.prepare(
      'INSERT INTO guests (show_date, name, title, raw_entry, party, profession) VALUES (?, ?, ?, ?, ?, ?)'
    );

    try {
      this.db.exec('BEGIN TRANSACTION');
      insertShow.run(date, sourceUrl, retrievedAt);
      for (const guest of guests) {
        const { name, title, rawEntry, party, profession } = guest;
        insertGuest.run(date, name, title, rawEntry, party, profession);
      }
      this.db.exec('COMMIT');
    } catch (err) {
      this.db.exec('ROLLBACK');
      throw err;
    }
  }

  getAllShows() {
    const stmt = this.db.prepare(
      'SELECT date, retrieved_at FROM shows ORDER BY date ASC'
    );
    return stmt.all();
  }

  close() {
    this.db.close();
  }
}

module.exports = { LanzDatabase };
