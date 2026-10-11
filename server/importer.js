// Import d'un historique d'écoute : fichier CSV (tableur, export d'une autre appli) ou compte Last.fm.
// Chaque ligne est rapprochée d'un album du catalogue (artiste + titre, sans tenir compte des accents,
// de la ponctuation ni des mentions « Deluxe »…). Rien n'est enregistré avant la confirmation.
import { config } from './config.js';
import { normName, baseTitle } from './catalog.js';

const MAX_ROWS = 5000;
const HEADERS = {
  artist: ['artist', 'artiste', 'artist name', 'artistname', 'rappeur', 'interprete', 'interprète', 'album artist'],
  album: ['album', 'album name', 'albumname', 'titre', 'title', 'name', 'projet'],
  rating: ['rating', 'note', 'stars', 'etoiles', 'étoiles', 'score'],
  date: ['date', 'listened', 'listened on', 'ecoute le', 'écouté le', 'watched date', 'date ecoute', 'date d ecoute'],
};

// Découpe une ligne CSV en tenant compte des guillemets.
function splitLine(line, sep) {
  const out = [];
  let cur = '';
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (quoted) {
      if (ch === '"' && line[i + 1] === '"') { cur += '"'; i++; } else if (ch === '"') quoted = false; else cur += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === sep) { out.push(cur); cur = ''; } else cur += ch;
  }
  out.push(cur);
  return out.map((s) => s.trim());
}

// Note lue en /5 (demi-étoiles acceptées) ou en /10, ramenée à l'échelle du site (1 à 10).
function readRating(raw) {
  const n = Number(String(raw || '').replace(',', '.').replace(/[^\d.]/g, ''));
  if (!n || n < 0) return null;
  const ten = n <= 5 ? Math.round(n * 2) : Math.round(n);
  return Math.min(10, Math.max(1, ten));
}

function readDate(raw) {
  const s = String(raw || '').trim();
  let m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (m) return `${m[1]}-${m[2]}-${m[3]}`;
  m = s.match(/^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})/); // format français JJ/MM/AAAA
  if (m) return `${m[3]}-${m[2].padStart(2, '0')}-${m[1].padStart(2, '0')}`;
  return null;
}

export function parseCsv(text) {
  const lines = String(text).replace(/^﻿/, '').split(/\r?\n/).filter((l) => l.trim());
  if (!lines.length) return { rows: [], error: 'Fichier vide.' };
  const sep = (lines[0].match(/;/g) || []).length > (lines[0].match(/,/g) || []).length ? ';' : ',';
  const head = splitLine(lines[0], sep).map((h) => normName(h));
  const col = (key) => head.findIndex((h) => HEADERS[key].map(normName).includes(h));
  let idx = { artist: col('artist'), album: col('album'), rating: col('rating'), date: col('date') };
  let start = 1;
  if (idx.artist < 0 || idx.album < 0) {
    // Pas d'en-tête reconnu : on suppose « artiste, album, note, date ».
    idx = { artist: 0, album: 1, rating: 2, date: 3 };
    start = 0;
  }
  const rows = [];
  for (const line of lines.slice(start, start + MAX_ROWS)) {
    const cells = splitLine(line, sep);
    const artist = cells[idx.artist] || '';
    const album = cells[idx.album] || '';
    if (!artist || !album) continue;
    rows.push({ artist, album, rating: idx.rating >= 0 ? readRating(cells[idx.rating]) : null, date: idx.date >= 0 ? readDate(cells[idx.date]) : null });
  }
  return { rows, truncated: lines.length - start > MAX_ROWS };
}

// Albums les plus écoutés d'un compte Last.fm (clé d'API gratuite à mettre dans .env).
export async function lastfmRows(username) {
  if (!config.lastfmKey) throw Object.assign(new Error("L'import Last.fm n'est pas activé sur ce site."), { status: 400 });
  const rows = [];
  for (let page = 1; page <= 2; page++) {
    const url = `https://ws.audioscrobbler.com/2.0/?method=user.gettopalbums&user=${encodeURIComponent(username)}&period=overall&limit=500&page=${page}&api_key=${config.lastfmKey}&format=json`;
    const res = await fetch(url, { signal: AbortSignal.timeout(10_000) });
    const data = await res.json().catch(() => null);
    if (data?.error) throw Object.assign(new Error(data.error === 6 ? 'Compte Last.fm introuvable.' : 'Last.fm ne répond pas, réessaie plus tard.'), { status: 400 });
    const list = data?.topalbums?.album || [];
    // Un album écouté au moins 3 fois en entier ou presque compte comme « écouté ».
    for (const a of list) if (Number(a.playcount) >= 3) rows.push({ artist: a.artist?.name || '', album: a.name || '', rating: null, date: null });
    if (list.length < 500) break;
  }
  return { rows };
}

export function importer(db) {
  return {
    // Rapproche les lignes du catalogue.
    match(rows) {
      const albums = db.prepare('SELECT al.slug, al.title, ar.name AS artist FROM albums al JOIN artists ar ON ar.id = al.artist_id').all();
      const index = new Map();
      for (const a of albums) {
        const key = `${normName(a.artist)}|${baseTitle(a.title)}`;
        if (!index.has(key)) index.set(key, a);
      }
      const matched = [];
      const unmatched = [];
      const seen = new Set();
      for (const r of rows) {
        const a = index.get(`${normName(r.artist)}|${baseTitle(r.album)}`);
        if (!a) { unmatched.push({ artist: r.artist, album: r.album }); continue; }
        if (seen.has(a.slug)) continue;
        seen.add(a.slug);
        matched.push({ slug: a.slug, title: a.title, artist: a.artist, rating: r.rating, date: r.date });
      }
      return { matched, unmatched };
    },

    // Enregistre : écouté, note si donnée (sans écraser une note existante), écoute datée dans le journal.
    apply(userId, matched) {
      const today = new Date().toISOString().slice(0, 10);
      const albumId = db.prepare('SELECT id FROM albums WHERE slug = ?');
      const upsert = db.prepare(`INSERT INTO user_albums (user_id, album_id, rating, listened) VALUES (?, ?, ?, 1)
        ON CONFLICT(user_id, album_id) DO UPDATE SET listened = 1, rating = COALESCE(user_albums.rating, excluded.rating), updated_at = datetime('now')`);
      const diaryExists = db.prepare('SELECT 1 FROM reviews WHERE user_id = ? AND album_id = ? AND listened_on = ?');
      const diary = db.prepare("INSERT INTO reviews (user_id, album_id, rating, body, listened_on) VALUES (?, ?, ?, '', ?)");
      let added = 0;
      db.exec('BEGIN');
      try {
        for (const m of matched) {
          const id = albumId.get(m.slug)?.id;
          if (!id) continue;
          upsert.run(userId, id, m.rating);
          if (m.date && m.date <= today && !diaryExists.get(userId, id, m.date)) diary.run(userId, id, m.rating, m.date);
          added++;
        }
        db.exec('COMMIT');
      } catch (err) {
        db.exec('ROLLBACK');
        throw err;
      }
      return added;
    },
  };
}
