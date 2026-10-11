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
  // Modération : rôle (member / admin) et suspension d'un compte.
  if (!userCols.includes('role')) db.exec("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'member'");
  if (!userCols.includes('suspended_at')) {
    db.exec('ALTER TABLE users ADD COLUMN suspended_at TEXT');
    db.exec('ALTER TABLE users ADD COLUMN suspended_reason TEXT');
  }
  const reviewCols = db.prepare('PRAGMA table_info(reviews)').all().map((c) => c.name);
  if (!reviewCols.includes('hidden_at')) {
    db.exec('ALTER TABLE reviews ADD COLUMN hidden_at TEXT'); // chronique masquée par la modération
    db.exec('ALTER TABLE reviews ADD COLUMN hidden_reason TEXT');
  }
  const reportCols = db.prepare('PRAGMA table_info(reports)').all().map((c) => c.name);
  if (!reportCols.includes('resolved_at')) {
    db.exec('ALTER TABLE reports ADD COLUMN resolved_at TEXT');
    db.exec('ALTER TABLE reports ADD COLUMN resolution TEXT');
  }
  db.exec(`
    -- Signalement d'un profil (photo, nom, bio).
    CREATE TABLE IF NOT EXISTS user_reports (
      id INTEGER PRIMARY KEY,
      reporter_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      reason TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      resolved_at TEXT,
      resolution TEXT,
      UNIQUE (reporter_id, user_id)
    );
    -- Membres bloqués.
    CREATE TABLE IF NOT EXISTS blocks (
      blocker_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      blocked_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      PRIMARY KEY (blocker_id, blocked_id),
      CHECK (blocker_id <> blocked_id)
    );
    -- Commentaires sous les chroniques.
    CREATE TABLE IF NOT EXISTS comments (
      id INTEGER PRIMARY KEY,
      review_id INTEGER NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      body TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      hidden_at TEXT
    );
    CREATE INDEX IF NOT EXISTS comments_review ON comments(review_id, created_at);
    CREATE TABLE IF NOT EXISTS comment_reports (
      id INTEGER PRIMARY KEY,
      reporter_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      comment_id INTEGER NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
      reason TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      resolved_at TEXT,
      resolution TEXT,
      UNIQUE (reporter_id, comment_id)
    );
    -- Notifications : nouvel abonné, nouvel ami, j'aime, commentaire. Conservées 6 mois.
    CREATE TABLE IF NOT EXISTS notifications (
      id INTEGER PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      actor_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      type TEXT NOT NULL,
      review_id INTEGER REFERENCES reviews(id) ON DELETE CASCADE,
      comment_id INTEGER REFERENCES comments(id) ON DELETE CASCADE,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      read_at TEXT
    );
    CREATE INDEX IF NOT EXISTS notifications_user ON notifications(user_id, created_at);
    -- Titres, durée et lien Deezer de chaque album (récupérés à la première visite, gardés 30 jours).
    CREATE TABLE IF NOT EXISTS album_details (
      album_id INTEGER PRIMARY KEY REFERENCES albums(id) ON DELETE CASCADE,
      deezer_id INTEGER,
      data TEXT,
      fetched_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
    -- Journal de modération (qui a fait quoi, quand) : conservé 1 an.
    CREATE TABLE IF NOT EXISTS mod_log (
      id INTEGER PRIMARY KEY,
      admin_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      action TEXT NOT NULL,
      target TEXT NOT NULL,
      detail TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );`);
  // Listes collaboratives : note par album et auteur de l'ajout.
  const itemCols = db.prepare('PRAGMA table_info(list_items)').all().map((c) => c.name);
  if (!itemCols.includes('note')) {
    db.exec("ALTER TABLE list_items ADD COLUMN note TEXT NOT NULL DEFAULT ''");
    db.exec('ALTER TABLE list_items ADD COLUMN added_by INTEGER REFERENCES users(id) ON DELETE SET NULL');
  }
  db.exec(`
    CREATE TABLE IF NOT EXISTS list_collaborators (
      list_id INTEGER NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      added_at TEXT NOT NULL DEFAULT (datetime('now')),
      PRIMARY KEY (list_id, user_id)
    );
    -- Badges obtenus (la date sert à l'ordre d'affichage et à la notification).
    CREATE TABLE IF NOT EXISTS user_badges (
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      badge TEXT NOT NULL,
      earned_at TEXT NOT NULL DEFAULT (datetime('now')),
      PRIMARY KEY (user_id, badge)
    );`);
  const notifCols = db.prepare('PRAGMA table_info(notifications)').all().map((c) => c.name);
  if (!notifCols.includes('list_id')) {
    db.exec('ALTER TABLE notifications ADD COLUMN list_id INTEGER REFERENCES lists(id) ON DELETE CASCADE');
    db.exec('ALTER TABLE notifications ADD COLUMN extra TEXT');
  }

  // Conservation (voir la politique de confidentialité) : signalements traités et journal, 1 an.
  db.exec("DELETE FROM reports WHERE resolved_at < datetime('now', '-1 year')");
  db.exec("DELETE FROM user_reports WHERE resolved_at < datetime('now', '-1 year')");
  db.exec("DELETE FROM mod_log WHERE created_at < datetime('now', '-1 year')");
  db.exec("DELETE FROM comment_reports WHERE resolved_at < datetime('now', '-1 year')");
  db.exec("DELETE FROM notifications WHERE created_at < datetime('now', '-6 months')");
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
