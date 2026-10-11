import fs from 'node:fs';
import { config } from './config.js';

// Couleur dominante de chaque image, calculée par `npm run images`.
let manifest = { covers: {}, artists: {} };
export function loadImageManifest() {
  try {
    manifest = JSON.parse(fs.readFileSync(new URL('../data/images.json', import.meta.url), 'utf8'));
  } catch { /* images pas encore générées */ }
}
loadImageManifest();

export const coverColor = (slug) => manifest.covers[slug]?.color || '#1d1d1f';
export const artistColor = (slug) => manifest.artists[slug]?.color || '#1d1d1f';
export const coverIsPlaceholder = (slug) => manifest.covers[slug]?.placeholder !== false;

export function albumView(row) {
  if (!row) return null;
  return {
    slug: row.slug,
    title: row.title,
    year: row.year,
    artist: { slug: row.artist_slug, name: row.artist_name },
    color: coverColor(row.slug),
    cover: `/img/covers/${row.slug}`,
    placeholder: coverIsPlaceholder(row.slug),
    coverCredit: row.cover_credit || null,
    avg: row.avg_rating != null ? Math.round(row.avg_rating * 10) / 10 : null,
    ratings: row.ratings ?? 0,
  };
}

const ALBUM_SELECT = `
  SELECT al.slug, al.title, al.year, al.cover_credit, ar.slug AS artist_slug, ar.name AS artist_name,
    (SELECT AVG(rating) FROM user_albums ua WHERE ua.album_id = al.id AND ua.rating IS NOT NULL) AS avg_rating,
    (SELECT COUNT(rating) FROM user_albums ua WHERE ua.album_id = al.id) AS ratings
  FROM albums al JOIN artists ar ON ar.id = al.artist_id`;

export function makeQueries(db) {
  const q = {
    albums({ sort = 'year' } = {}) {
      const order = {
        year: 'al.year ASC, al.title ASC',
        recent: 'al.year DESC, al.title ASC',
        title: 'al.title COLLATE NOCASE ASC',
        rating: 'avg_rating IS NULL, avg_rating DESC, ratings DESC',
        popular: 'ratings DESC, al.year DESC',
      }[sort] || 'al.year ASC';
      return db.prepare(`${ALBUM_SELECT} ORDER BY ${order}`).all().map(albumView);
    },

    album(slug) {
      const row = db.prepare(`${ALBUM_SELECT} WHERE al.slug = ?`).get(slug);
      if (!row) return null;
      const album = albumView(row);
      const id = db.prepare('SELECT id FROM albums WHERE slug = ?').get(slug).id;
      album.id = id;
      album.stats = db.prepare(`
        SELECT SUM(listened) AS listened, SUM(liked) AS likes,
          (SELECT COUNT(*) FROM reviews WHERE album_id = ? AND body <> '') AS reviews
        FROM user_albums WHERE album_id = ?`).get(id, id);
      const hist = Array(10).fill(0);
      for (const r of db.prepare('SELECT rating, COUNT(*) n FROM user_albums WHERE album_id = ? AND rating IS NOT NULL GROUP BY rating').all(id)) {
        hist[r.rating - 1] = r.n;
      }
      album.histogram = hist;
      return album;
    },

    albumId(slug) {
      return db.prepare('SELECT id FROM albums WHERE slug = ?').get(slug)?.id ?? null;
    },

    albumsByArtist(artistSlug) {
      return db.prepare(`${ALBUM_SELECT} WHERE ar.slug = ? ORDER BY al.year`).all(artistSlug).map(albumView);
    },

    artists() {
      return db.prepare(`
        SELECT ar.slug, ar.name, ar.origin, ar.bio,
          (SELECT COUNT(*) FROM albums WHERE artist_id = ar.id) AS albums,
          (SELECT MIN(year) FROM albums WHERE artist_id = ar.id) AS first_year
        FROM artists ar ORDER BY first_year, ar.name`).all()
        .map((a) => ({ ...a, color: artistColor(a.slug), photo: `/img/artists/${a.slug}` }));
    },

    artist(slug) {
      const a = db.prepare('SELECT slug, name, origin, bio, bio_source, photo_credit FROM artists WHERE slug = ?').get(slug);
      if (!a) return null;
      return { ...a, color: artistColor(a.slug), photo: `/img/artists/${a.slug}`, albums: q.albumsByArtist(slug) };
    },

    userState(userId, albumId) {
      return db.prepare('SELECT rating, liked, listened, wishlist FROM user_albums WHERE user_id = ? AND album_id = ?')
        .get(userId, albumId) || { rating: null, liked: 0, listened: 0, wishlist: 0 };
    },

    reviewsForAlbum(albumId, viewerId = 0, { limit = 30, friendsOnly = false } = {}) {
      return db.prepare(`
        SELECT r.id, r.rating, r.body, r.listened_on, r.created_at,
          u.username, u.display_name,
          (SELECT COUNT(*) FROM review_likes WHERE review_id = r.id) AS likes,
          EXISTS(SELECT 1 FROM review_likes WHERE review_id = r.id AND user_id = ?) AS liked_by_me,
          (SELECT liked FROM user_albums WHERE user_id = r.user_id AND album_id = r.album_id) AS loved
        FROM reviews r JOIN users u ON u.id = r.user_id
        WHERE r.album_id = ? AND r.body <> ''
          ${friendsOnly ? 'AND r.user_id IN (SELECT followee_id FROM follows WHERE follower_id = ?)' : ''}
        ORDER BY likes DESC, r.created_at DESC LIMIT ?`)
        .all(...(friendsOnly ? [viewerId, albumId, viewerId, limit] : [viewerId, albumId, limit]));
    },

    recentReviews(limit = 12) {
      return db.prepare(`
        SELECT r.id, r.rating, r.body, r.created_at, u.username, u.display_name, al.slug AS album_slug
        FROM reviews r JOIN users u ON u.id = r.user_id JOIN albums al ON al.id = r.album_id
        WHERE r.body <> '' ORDER BY r.created_at DESC LIMIT ?`).all(limit)
        .map((r) => ({ ...r, album: q.album(r.album_slug) }));
    },

    user(username) {
      return db.prepare('SELECT id, username, display_name, bio, created_at FROM users WHERE username = ?').get(username) || null;
    },

    profile(username, viewerId = 0) {
      const u = q.user(username);
      if (!u) return null;
      const one = (sql, ...args) => Object.values(db.prepare(sql).get(...args))[0];
      const year = new Date().getFullYear().toString();
      u.stats = {
        listened: one('SELECT COUNT(*) FROM user_albums WHERE user_id = ? AND listened = 1', u.id),
        thisYear: one("SELECT COUNT(DISTINCT album_id) FROM reviews WHERE user_id = ? AND substr(listened_on, 1, 4) = ?", u.id, year),
        reviews: one("SELECT COUNT(*) FROM reviews WHERE user_id = ? AND body <> ''", u.id),
        lists: one('SELECT COUNT(*) FROM lists WHERE user_id = ?', u.id),
        followers: one('SELECT COUNT(*) FROM follows WHERE followee_id = ?', u.id),
        following: one('SELECT COUNT(*) FROM follows WHERE follower_id = ?', u.id),
      };
      u.isMe = viewerId === u.id;
      u.isFollowing = Boolean(viewerId && one('SELECT COUNT(*) FROM follows WHERE follower_id = ? AND followee_id = ?', viewerId, u.id));
      u.followsMe = Boolean(viewerId && one('SELECT COUNT(*) FROM follows WHERE follower_id = ? AND followee_id = ?', u.id, viewerId));
      u.favorites = db.prepare(`${ALBUM_SELECT} JOIN favorites f ON f.album_id = al.id WHERE f.user_id = ? ORDER BY f.position`)
        .all(u.id).map(albumView);
      u.diary = db.prepare(`
        SELECT r.id, r.rating, r.body, r.listened_on, al.slug FROM reviews r JOIN albums al ON al.id = r.album_id
        WHERE r.user_id = ? ORDER BY r.listened_on DESC, r.created_at DESC LIMIT 40`).all(u.id)
        .map((r) => ({ ...r, album: q.album(r.slug) }));
      u.liked = db.prepare(`${ALBUM_SELECT} JOIN user_albums s ON s.album_id = al.id WHERE s.user_id = ? AND s.liked = 1 ORDER BY s.updated_at DESC LIMIT 24`)
        .all(u.id).map(albumView);
      u.wishlist = db.prepare(`${ALBUM_SELECT} JOIN user_albums s ON s.album_id = al.id WHERE s.user_id = ? AND s.wishlist = 1 ORDER BY s.updated_at DESC LIMIT 24`)
        .all(u.id).map(albumView);
      u.lists = db.prepare(`
        SELECT l.id, l.title, l.description, (SELECT COUNT(*) FROM list_items WHERE list_id = l.id) AS count
        FROM lists l WHERE l.user_id = ? ORDER BY l.created_at DESC`).all(u.id);
      u.friends = q.friends(u.id);
      return u;
    },

    // Amis = abonnements réciproques.
    friends(userId) {
      return db.prepare(`
        SELECT u.username, u.display_name FROM follows a
        JOIN follows b ON b.follower_id = a.followee_id AND b.followee_id = a.follower_id
        JOIN users u ON u.id = a.followee_id
        WHERE a.follower_id = ? ORDER BY u.display_name COLLATE NOCASE`).all(userId);
    },

    followList(userId, direction) {
      const sql = direction === 'followers'
        ? 'SELECT u.username, u.display_name FROM follows f JOIN users u ON u.id = f.follower_id WHERE f.followee_id = ? ORDER BY f.created_at DESC'
        : 'SELECT u.username, u.display_name FROM follows f JOIN users u ON u.id = f.followee_id WHERE f.follower_id = ? ORDER BY f.created_at DESC';
      return db.prepare(sql).all(userId);
    },

    feed(userId, limit = 50) {
      return db.prepare(`
        SELECT r.id, r.rating, r.body, r.listened_on, r.created_at, u.username, u.display_name, al.slug
        FROM reviews r JOIN users u ON u.id = r.user_id JOIN albums al ON al.id = r.album_id
        WHERE r.user_id IN (SELECT followee_id FROM follows WHERE follower_id = ?)
        ORDER BY r.created_at DESC LIMIT ?`).all(userId, limit)
        .map((r) => ({ ...r, album: q.album(r.slug) }));
    },

    list(id) {
      const l = db.prepare(`
        SELECT l.id, l.title, l.description, l.created_at, u.username, u.display_name, u.id AS user_id
        FROM lists l JOIN users u ON u.id = l.user_id WHERE l.id = ?`).get(id);
      if (!l) return null;
      l.albums = db.prepare(`${ALBUM_SELECT} JOIN list_items li ON li.album_id = al.id WHERE li.list_id = ? ORDER BY li.position`)
        .all(id).map(albumView);
      return l;
    },

    myLists(userId) {
      return db.prepare('SELECT id, title FROM lists WHERE user_id = ? ORDER BY created_at DESC').all(userId);
    },

    search(term) {
      const like = `%${term.replace(/[%_]/g, '')}%`;
      return {
        albums: db.prepare(`${ALBUM_SELECT} WHERE al.title LIKE ? OR ar.name LIKE ? ORDER BY al.year LIMIT 20`).all(like, like).map(albumView),
        artists: db.prepare('SELECT slug, name FROM artists WHERE name LIKE ? ORDER BY name LIMIT 10').all(like),
        users: db.prepare('SELECT username, display_name FROM users WHERE username LIKE ? OR display_name LIKE ? LIMIT 10').all(like, like),
      };
    },

    sitemapEntries() {
      return {
        albums: db.prepare('SELECT slug FROM albums').all().map((r) => r.slug),
        artists: db.prepare('SELECT slug FROM artists').all().map((r) => r.slug),
      };
    },
  };
  return q;
}

export const absoluteUrl = (p) => `${config.publicUrl}${p}`;
