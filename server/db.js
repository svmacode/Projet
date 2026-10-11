import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';
import { config } from './config.js';
import { loadCatalog } from './catalog.js';

const SCHEMA = `
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 10000;

CREATE TABLE IF NOT EXISTS artists (
  id INTEGER PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  origin TEXT,
  bio TEXT,
  bio_source TEXT,
  photo_credit TEXT
);

CREATE TABLE IF NOT EXISTS albums (
  id INTEGER PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  artist_id INTEGER NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
  year INTEGER NOT NULL,
  cover_credit TEXT
);
CREATE INDEX IF NOT EXISTS albums_artist ON albums(artist_id);

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY,
  username TEXT NOT NULL UNIQUE COLLATE NOCASE,
  email TEXT NOT NULL UNIQUE COLLATE NOCASE,
  password_hash TEXT NOT NULL,
  display_name TEXT NOT NULL,
  bio TEXT NOT NULL DEFAULT '',
  email_verified_at TEXT,
  terms_accepted_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  csrf TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  expires_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS sessions_user ON sessions(user_id);

CREATE TABLE IF NOT EXISTS email_tokens (
  token_hash TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('verify', 'reset')),
  expires_at TEXT NOT NULL
);

-- État d'un album pour un membre : écouté, aimé, note, à écouter.
CREATE TABLE IF NOT EXISTS user_albums (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  album_id INTEGER NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
  rating INTEGER CHECK (rating BETWEEN 1 AND 10),
  liked INTEGER NOT NULL DEFAULT 0,
  listened INTEGER NOT NULL DEFAULT 0,
  wishlist INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, album_id)
);
CREATE INDEX IF NOT EXISTS user_albums_album ON user_albums(album_id);

-- Journal d'écoute : une entrée datée, avec ou sans chronique.
CREATE TABLE IF NOT EXISTS reviews (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  album_id INTEGER NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
  rating INTEGER CHECK (rating BETWEEN 1 AND 10),
  body TEXT NOT NULL DEFAULT '',
  listened_on TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS reviews_album ON reviews(album_id, created_at);
CREATE INDEX IF NOT EXISTS reviews_user ON reviews(user_id, created_at);

CREATE TABLE IF NOT EXISTS review_likes (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  review_id INTEGER NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, review_id)
);

CREATE TABLE IF NOT EXISTS reports (
  id INTEGER PRIMARY KEY,
  reporter_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  review_id INTEGER NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (reporter_id, review_id)
);

CREATE TABLE IF NOT EXISTS follows (
  follower_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followee_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (follower_id, followee_id),
  CHECK (follower_id <> followee_id)
);
CREATE INDEX IF NOT EXISTS follows_followee ON follows(followee_id);

CREATE TABLE IF NOT EXISTS favorites (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  album_id INTEGER NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK (position BETWEEN 1 AND 4),
  PRIMARY KEY (user_id, position)
);

CREATE TABLE IF NOT EXISTS lists (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS list_items (
  list_id INTEGER NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
  album_id INTEGER NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  PRIMARY KEY (list_id, album_id)
);
`;

export function openDb(file = config.dbFile) {
  if (file !== ':memory:') fs.mkdirSync(path.dirname(file), { recursive: true });
  const db = new DatabaseSync(file);
  db.exec(SCHEMA);
  migrate(db);
  seedCatalogue(db);
  return db;
}

// Colonnes ajoutées après la première version.
function migrate(db) {
  const cols = db.prepare('PRAGMA table_info(albums)').all().map((c) => c.name);
  if (!cols.includes('kind')) db.exec("ALTER TABLE albums ADD COLUMN kind TEXT NOT NULL DEFAULT 'album'");
  if (!cols.includes('curated')) db.exec('ALTER TABLE albums ADD COLUMN curated INTEGER NOT NULL DEFAULT 0');
  db.exec('CREATE INDEX IF NOT EXISTS albums_year ON albums(year)');
  // Suivi UTM : compteurs anonymes par jour et par campagne (aucune donnée personnelle).
  db.exec(`CREATE TABLE IF NOT EXISTS utm_stats (
    day TEXT NOT NULL, source TEXT NOT NULL, medium TEXT NOT NULL DEFAULT '', campaign TEXT NOT NULL DEFAULT '',
    path TEXT NOT NULL, visits INTEGER NOT NULL DEFAULT 0, signups INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (day, source, medium, campaign, path))`);
  db.exec("DELETE FROM utm_stats WHERE day < date('now', '-90 days')"); // conservation : 90 jours
  const userCols = db.prepare('PRAGMA table_info(users)').all().map((c) => c.name);
  if (!userCols.includes('avatar')) db.exec('ALTER TABLE users ADD COLUMN avatar TEXT'); // photo de profil (voir avatars.js)
  if (!userCols.includes('utm_source')) {
    db.exec('ALTER TABLE users ADD COLUMN utm_source TEXT');
    db.exec('ALTER TABLE users ADD COLUMN utm_medium TEXT');
    db.exec('ALTER TABLE users ADD COLUMN utm_campaign TEXT');
  }
}

// Insère ou met à jour le catalogue sans toucher aux données des membres.
export function seedCatalogue(db, { artist: onlyArtist } = {}) {
  const credits = readCredits();
  const upArtist = db.prepare(`
    INSERT INTO artists (slug, name, origin, bio, bio_source, photo_credit)
    VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(slug) DO UPDATE SET name = excluded.name, origin = excluded.origin,
      bio = excluded.bio, bio_source = excluded.bio_source, photo_credit = excluded.photo_credit`);
  const upAlbum = db.prepare(`
    INSERT INTO albums (slug, title, artist_id, year, cover_credit, kind, curated)
    VALUES (?, ?, (SELECT id FROM artists WHERE slug = ?), ?, ?, ?, ?)
    ON CONFLICT(slug) DO UPDATE SET title = excluded.title, artist_id = excluded.artist_id,
      year = excluded.year, cover_credit = excluded.cover_credit, kind = excluded.kind, curated = excluded.curated`);
  let { artists, albums } = loadCatalog();
  // Pendant la récupération : seulement l'artiste qui vient d'arriver (bien plus rapide).
  if (onlyArtist) {
    artists = artists.filter((a) => a.slug === onlyArtist);
    albums = albums.filter((a) => a.artist === onlyArtist);
  }
  db.exec('BEGIN');
  try {
    for (const a of artists) {
      const c = credits.artists[a.slug] || {};
      upArtist.run(a.slug, a.name, a.origin || '', c.bio || a.bio || '', c.bioSource || a.bioSource || null, c.photoCredit || null);
    }
    for (const a of albums) {
      upAlbum.run(a.slug, a.title, a.artist, a.year, credits.albums[a.slug]?.coverCredit || null, a.kind, a.curated ? 1 : 0);
    }
    db.exec('COMMIT');
  } catch (err) {
    db.exec('ROLLBACK');
    throw err;
  }
}

// Crédits produits par `npm run catalogue:fetch` (sources des images et des résumés).
function readCredits() {
  try {
    return JSON.parse(fs.readFileSync(new URL('../data/credits.json', import.meta.url), 'utf8'));
  } catch {
    return { artists: {}, albums: {} };
  }
}
