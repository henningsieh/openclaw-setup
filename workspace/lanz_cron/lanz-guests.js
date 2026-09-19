#!/usr/bin/env node

// If Temporal is missing, respawn this exact script with the correct V8 flag
if (typeof Temporal === 'undefined') {
  const { spawnSync } = require('child_process');
  
  const result = spawnSync(process.argv[0], ['--harmony-temporal', ...process.argv.slice(1)], {
    stdio: 'inherit' // Passes terminal input/output straight through
  });
  
  process.exit(result.status ?? 0);
}

/**
 * Markus Lanz Guest Fetcher
 * Fetches today's guest list from fernsehmacher.de, validates the date,
 * stores in SQLite, and outputs a formatted message.
 */
const { LanzDatabase } = require('./lanz-db');

const SOURCE_URL = 'https://www.fernsehmacher.de/markus-lanz-aktuell/';

function formatGermanWeekday({ year, month, day }) {
  // This will now always run cleanly on Node v22!
  return Temporal.PlainDate.from({ year, month, day }).toLocaleString('de-DE', { weekday: 'long' });
}
async function fetchPage(url) {
  const response = await fetch(url, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
  return response.text();
}

function parseDateFromTitle(html) {
  const titleMatch = html.match(/<title[^>]*>(.*?)<\/title>/is);
  if (!titleMatch) return null;

  const title = titleMatch[1];

  // Match: am Do., 14.05.26 um 23:00 Uhr
  let match = title.match(/am\s+([A-Za-zäöüÄÖÜ]+\.?),?\s+(\d{1,2})\.(\d{1,2})\.(\d{2,4})/i);
  if (!match) {
    // Fallback: just find a date pattern
    match = title.match(/(\d{1,2})\.(\d{1,2})\.(\d{2,4})/);
    if (!match) return null;
    const [, day, month, yearStr] = match;
    const year = yearStr.length === 2 ? 2000 + parseInt(yearStr, 10) : parseInt(yearStr, 10);
    return { day: parseInt(day, 10), month: parseInt(month, 10), year, weekday: null };
  }

  const [, weekdayStr, day, month, yearStr] = match;
  const year = yearStr.length === 2 ? 2000 + parseInt(yearStr, 10) : parseInt(yearStr, 10);

  return {
    day: parseInt(day, 10),
    month: parseInt(month, 10),
    year,
    weekday: weekdayStr.trim()
  };
}

function parseGuests(html) {
  const guests = [];

  // Try the old "mit:" based format first
  const mitIndex = html.search(/mit:\s*<\/p>/i);
  if (mitIndex !== -1) {
    const afterMit = html.slice(mitIndex);
    const paraRegex = /<p[^>]*>(.*?)<\/p>/gis;
    let match;

    while ((match = paraRegex.exec(afterMit)) !== null) {
      const paraContent = match[1].trim();

      if (!paraContent || paraContent === '&nbsp;' || paraContent.length < 5) {
        continue;
      }

      const cleanLine = paraContent
        .replace(/<[^>]+>/g, '')
        .replace(/&nbsp;/g, ' ')
        .trim();

      if (!cleanLine) continue;

      const commaIdx = cleanLine.indexOf(',');
      if (commaIdx !== -1) {
        const name = cleanLine.substring(0, commaIdx).trim();
        const title = cleanLine.substring(commaIdx + 1).trim();

        const nameWords = name.split(/\s+/).filter(w => w.length > 0);
        const looksLikeName = nameWords.length >= 2 && nameWords.length <= 6 &&
                              nameWords.every(w => /^[A-ZÄÖÜ][A-Za-zäöüßÄÖÜ.-]*$/.test(w) || w === 'v.') &&
                              name.length < 60 && title.length < 150;

        if (looksLikeName) {
          guests.push({ name, title, rawEntry: cleanLine });
          continue;
        }
      }

      if (guests.length > 0 && (cleanLine.length > 80 || !cleanLine.includes(','))) {
        continue;
      }
    }
  }

  // If old format didn't find anything, try the new format (since ~July 2026)
  if (guests.length === 0) {
    // New format: <p><strong>Name, Title</strong></p> directly in the content
    // without a preceding "mit:" paragraph.
    // Find the post content area and look for <strong>...</strong> patterns
    // that look like guest names followed by comma + job
    const contentMatch = html.match(/<div\s+class="entry-content">([\s\S]*?)(?:<\/div>)/i);
    if (contentMatch) {
      const entryContent = contentMatch[1];

      // Find all <strong>...</strong> inside <p> tags in the entry content
      const strongRegex = /<p[^>]*>\s*<strong>([^<]+)<\/strong>\s*(?:<strong>([^<]+)<\/strong>)?\s*<\/p>/gis;
      let strongMatch;

      while ((strongMatch = strongRegex.exec(entryContent)) !== null) {
        // Check if first strong looks like a name (has a name+comma pattern)
        let fullText;
        if (strongMatch[2]) {
          // Two consecutive <strong> elements — join them
          fullText = (strongMatch[1] + strongMatch[2]).trim();
        } else {
          fullText = strongMatch[1].trim();
        }

        const cleanLine = fullText.replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ').trim();
        if (!cleanLine || cleanLine.length < 5) continue;

        // Must contain a comma (name, title pattern)
        const commaIdx = cleanLine.indexOf(',');
        if (commaIdx === -1) continue;

        const name = cleanLine.substring(0, commaIdx).trim();
        const title = cleanLine.substring(commaIdx + 1).trim();
        if (!name || !title) continue;

        const nameWords = name.split(/\s+/).filter(w => w.length > 0);
        const looksLikeName = nameWords.length >= 1 && nameWords.length <= 6 &&
                              nameWords.every(w => /^[A-ZÄÖÜ][A-Za-zäöüßÄÖÜ.-]*$/.test(w) || w === 'v.' || w === 'von' || w === 'zu' || w === 'der') &&
                              name.length < 60 && title.length < 150;

        if (looksLikeName) {
          guests.push({ name, title, rawEntry: `${name}, ${title}` });
        }
      }
    }
  }

  return guests;
}

function getTodayBerlin() {
  if (typeof Temporal !== 'undefined' && Temporal.Now && Temporal.Now.plainDateISO) {
    const today = Temporal.Now.plainDateISO('Europe/Berlin');
    return { year: today.year, month: today.month, day: today.day };
  }

  const now = new Date();
  const berlinFormatter = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Europe/Berlin',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
  const parts = berlinFormatter.formatToParts(now);
  const year = parseInt(parts.find(p => p.type === 'year').value, 10);
  const month = parseInt(parts.find(p => p.type === 'month').value, 10);
  const day = parseInt(parts.find(p => p.type === 'day').value, 10);

  return { year, month, day };
}

function formatDateKey({ year, month, day }) {
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function formatTelegramMessage(dateKey, guests, sourceUrl) {
  const [year, month, day] = dateKey.split('-').map(Number);
  const weekday = formatGermanWeekday({ year, month, day });
  const formattedDate = `${day}.${month}.${year}`;

  const guestList = guests.map(g => `• ${g.rawEntry}`).join('\n');

  return `📺 Markus Lanz heute — ${weekday}, ${formattedDate}

Gäste:
${guestList}

Quelle: ${sourceUrl}`;
}

async function main() {
  const isTest = process.argv.includes('--test');
  const testFile = process.argv[process.argv.indexOf('--test') + 1];

  const db = new LanzDatabase();

  try {
    const today = getTodayBerlin();
    const todayKey = formatDateKey(today);

    // Check if already recorded today
    const existing = db.findByDate(todayKey);
    if (existing) {
      db.close();
      process.exit(0);
    }

    // Fetch page
    let html;
    if (isTest && testFile) {
      const fs = require('fs').promises;
      html = await fs.readFile(testFile, 'utf-8');
    } else {
      html = await fetchPage(SOURCE_URL);
    }

    // Parse date from title
    const parsedDate = parseDateFromTitle(html);
    if (!parsedDate) {
      // Page not updated for today yet (e.g. still shows Sommerpause title) —
      // perfectly normal. Exit cleanly with NO output so the cron stays silent.
      db.close();
      process.exit(0);
    }

    // Validate date matches today (skip in test mode)
    if (!isTest) {
      if (parsedDate.year !== today.year ||
          parsedDate.month !== today.month ||
          parsedDate.day !== today.day) {
        // Page hasn't been updated for today yet — perfectly normal.
        // Exit cleanly with no output so the cron doesn't send noise.
        db.close();
        process.exit(0);
      }
    }

    // Parse guests
    const guests = parseGuests(html);
    if (guests.length === 0) {
      // No guests published yet — this is normal, not an error.
      // Exit cleanly so the cron doesn't fire a failure alert.
      db.close();
      process.exit(0);
    }

    // In test mode, just print parsed data
    if (isTest) {
      console.log('Parsed date:', parsedDate);
      console.log('Guests found:', guests.length);
      guests.forEach((g, i) => console.log(`  ${i + 1}. ${g.rawEntry}`));
      db.close();
      process.exit(0);
    }

    // Save to database
    const guestsWithNulls = guests.map(g => ({
      ...g,
      party: null,
      profession: null
    }));

    db.addShow(todayKey, SOURCE_URL, guestsWithNulls, new Date().toISOString());

    // Output formatted message for cron delivery
    const message = formatTelegramMessage(todayKey, guests, SOURCE_URL);
    console.log(message);

    db.close();
    process.exit(0);
  } catch (err) {
    console.error(`Error: ${err.message}`);
    db.close();
    process.exit(1);
  }
}

main();
