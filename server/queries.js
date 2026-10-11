import { config } from './config.js';
import { imageColor, hasRealImage } from './imaging.js';

export function albumView(row) {
  if (!row) return null;
  const real = hasRealImage('covers', row.slug);
  return {
    slug: row.slug,
    title: row.title,
    year: row.year,
    kind: row.kind || 'album',
    curated: Boolean(row.curated),
    artist: { slug: row.artist_slug, name: row.artist_name },
    color: imageColor('covers', row.slug),
    cover: `/img/covers/${row.slug}`,
    // Le paramètre change quand la vraie pochette arrive : le navigateur ne garde pas l'ancienne en cache.
    v: real ? '?r=1' : '',
    placeholder: !real,
    coverCredit: row.cover_credit || null,
    avg: row.avg_rating != null ? Math.round(row.avg_rating * 10) / 10 : null,
    ratings: row.ratings ?? 0,
  };
}

const artistView = (a) => ({
  ...a,
  color: imageColor('artists', a.slug),
  photo: `/img/artists/${a.slug}`,
  v: hasRealImage('artists', a.slug) ? '?r=1' : '',
});

const ALBUM_SELECT = `
  SELECT al.slug, al.title, al.year, al.kind, al.curated, al.cover_credit, ar.slug AS artist_slug, ar.name AS artist_name,
    st.avg_rating, COALESCE(st.ratings, 0) AS ratings
  FROM albums al JOIN artists ar ON ar.id = al.artist_id
  LEFT JOIN (SELECT album_id, AVG(rating) AS avg_rating, COUNT(rating) AS ratings FROM user_albums GROUP BY album_id) st
    ON st.album_id = al.id`;

const ORDERS = {
  year: 'al.year ASC, al.title COLLATE NOCASE ASC',
  recent: 'al.year DESC, al.title COLLATE NOCASE ASC',
  title: 'al.title COLLATE NOCASE ASC',
  rating: 'st.avg_rating IS NULL, st.avg_rating DESC, ratings DESC',
  popular: 'ratings DESC, al.curated DESC, al.year DESC',
};

export function makeQueries(db) {
  const q = {
    albums({ sort = 'year' } = {}) {
      return db.prepare(`${ALBUM_SELECT} ORDER BY ${ORDERS[sort] || ORDERS.year}`).all().map(albumView);
    },

    // Catalogue filtré et paginé (page /albums et API).
    albumPage({ q: text = '', decade = 0, kind = '', sort = 'year', page = 1, perPage = 60 } = {}) {
      let list = q.albums({ sort });
      const words = normalize(text).split(' ').filter(Boolean);
      if (words.length) list = list.filter((a) => { const h = normalize(`${a.title} ${a.artist.name}`); return words.every((w) => h.includes(w)); });
      if (decade) list = list.filter((a) => a.year >= decade && a.year < decade + 10);
      if (kind === 'album' || kind === 'ep') list = list.filter((a) => a.kind === kind);
      const total = list.length;
      const pages = Math.max(1, Math.ceil(total / perPage));
      const current = Math.min(Math.max(1, page), pages);
      return { albums: list.slice((current - 1) * perPage, current * perPage), total, page: current, pages };
    },

    // Mise en avant : la sélection éditoriale d'abord, puis le reste.
    featured(limit = 60) {
      return db.prepare(`${ALBUM_SELECT} ORDER BY al.curated DESC, ratings DESC, al.year ASC LIMIT ?`).all(limit).map(albumView);
    },

    count() {
      return db.prepare("SELECT COUNT(*) n, SUM(kind = 'ep') eps, COUNT(DISTINCT artist_id) artists FROM albums").get();
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
      return db.prepare(`${ALBUM_SELECT} WHERE ar.slug = ? ORDER BY al.year, al.title`).all(artistSlug).map(albumView);
    },

    artists() {
      return db.prepare(`
        SELECT ar.slug, ar.name, ar.origin, ar.bio,
          (SELECT COUNT(*) FROM albums WHERE artist_id = ar.id) AS albums,
          (SELECT MIN(year) FROM albums WHERE artist_id = ar.id) AS first_year
        FROM artists ar ORDER BY first_year, ar.name COLLATE NOCASE`).all()
        .filter((a) => a.albums > 0)
        .map(artistView);
    },

    artist(slug) {
      const a = db.prepare('SELECT slug, name, origin, bio, bio_source, photo_credit FROM artists WHERE slug = ?').get(slug);
      if (!a) return null;
      return { ...artistView(a), albums: q.albumsByArtist(slug) };
    },

    userState(userId, albumId) {
      return db.prepare('SELECT rating, liked, listened, wishlist FROM user_albums WHERE user_id = ? AND album_id = ?')
        .get(userId, albumId) || { rating: null, liked: 0, listened: 0, wishlist: 0 };
    },

    reviewsForAlbum(albumId, viewerId = 0, { limit = 30, friendsOnly = false } = {}) {
      return db.prepare(`
        SELECT r.id, r.rating, r.body, r.listened_on, r.created_at,
          u.username, u.display_name, u.avatar,
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
        SELECT r.id, r.rating, r.body, r.created_at, u.username, u.display_name, u.avatar, al.slug AS album_slug
        FROM reviews r JOIN users u ON u.id = r.user_id JOIN albums al ON al.id = r.album_id
        WHERE r.body <> '' ORDER BY r.created_at DESC LIMIT ?`).all(limit)
        .map((r) => ({ ...r, album: q.album(r.album_slug) }));
    },

    user(username) {
      return db.prepare('SELECT id, username, display_name, avatar, bio, created_at FROM users WHERE username = ?').get(username) || null;
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

    // Page Amis : les membres autour de toi, avec l'état de la relation pour chaque bouton « Suivre ».
    friendsHub(userId) {
      const person = `u.username, u.display_name, u.avatar, u.bio,
        (SELECT COUNT(*) FROM user_albums WHERE user_id = u.id AND listened = 1) AS listened`;
      const followsMe = 'EXISTS(SELECT 1 FROM follows WHERE follower_id = u.id AND followee_id = ?)';
      const iFollow = 'EXISTS(SELECT 1 FROM follows WHERE follower_id = ? AND followee_id = u.id)';
      // Ils te suivent, tu ne les suis pas encore : un clic et vous êtes amis.
      const requests = db.prepare(`SELECT ${person}, 0 AS isFollowing, 1 AS followsMe FROM follows f JOIN users u ON u.id = f.follower_id
        WHERE f.followee_id = ? AND NOT ${iFollow} ORDER BY f.created_at DESC`).all(userId, userId);
      const friends = db.prepare(`SELECT ${person}, 1 AS isFollowing, 1 AS followsMe FROM follows a
        JOIN follows b ON b.follower_id = a.followee_id AND b.followee_id = a.follower_id
        JOIN users u ON u.id = a.followee_id WHERE a.follower_id = ? ORDER BY u.display_name COLLATE NOCASE`).all(userId);
      const following = db.prepare(`SELECT ${person}, 1 AS isFollowing, 0 AS followsMe FROM follows f JOIN users u ON u.id = f.followee_id
        WHERE f.follower_id = ? AND NOT ${followsMe} ORDER BY f.created_at DESC`).all(userId, userId);
      // Suggestions : les membres suivis par ceux que tu suis, puis les plus actifs.
      const known = new Set([...requests, ...friends, ...following].map((p) => p.username));
      const suggestions = db.prepare(`SELECT ${person}, 0 AS isFollowing, ${followsMe} AS followsMe, COUNT(*) AS common
        FROM follows a JOIN follows b ON b.follower_id = a.followee_id JOIN users u ON u.id = b.followee_id
        WHERE a.follower_id = ? AND u.id <> ? AND NOT ${iFollow}
        GROUP BY u.id ORDER BY common DESC, listened DESC LIMIT 8`).all(userId, userId, userId, userId);
      if (suggestions.length < 8) {
        const active = db.prepare(`SELECT ${person}, 0 AS isFollowing, ${followsMe} AS followsMe, 0 AS common FROM users u
          WHERE u.id <> ? AND NOT ${iFollow} ORDER BY listened DESC, u.created_at DESC LIMIT 16`).all(userId, userId, userId);
        for (const p of active) {
          if (suggestions.length >= 8) break;
          if (!suggestions.some((s) => s.username === p.username) && !known.has(p.username)) suggestions.push(p);
        }
      }
      return { requests, friends, following, suggestions: suggestions.filter((p) => !known.has(p.username)) };
    },

    // Recherche de membres par pseudo ou nom affiché, avec l'état de la relation.
    searchMembers(text, viewerId) {
      const words = normalize(text).split(' ').filter(Boolean);
      if (!words.length) return [];
      return db.prepare(`SELECT u.username, u.display_name, u.avatar, u.bio,
          (SELECT COUNT(*) FROM user_albums WHERE user_id = u.id AND listened = 1) AS listened,
          EXISTS(SELECT 1 FROM follows WHERE follower_id = ? AND followee_id = u.id) AS isFollowing,
          EXISTS(SELECT 1 FROM follows WHERE follower_id = u.id AND followee_id = ?) AS followsMe
        FROM users u WHERE u.id <> ?`).all(viewerId, viewerId, viewerId)
        .filter((u) => { const h = normalize(`${u.username} ${u.display_name}`); return words.every((w) => h.includes(w)); })
        .sort((a, b) => b.listened - a.listened)
        .slice(0, 20);
    },

    // Pochettes proposées comme photo de profil : favoris et coups de cœur du membre, puis classiques.
    avatarPicks(userId, limit = 12) {
      const slugs = db.prepare(`
        SELECT al.slug FROM favorites f JOIN albums al ON al.id = f.album_id WHERE f.user_id = ?
        UNION ALL
        SELECT al.slug FROM user_albums s JOIN albums al ON al.id = s.album_id WHERE s.user_id = ? AND s.liked = 1`)
        .all(userId, userId).map((r) => r.slug);
      const picks = [...new Set(slugs)].map((s) => q.album(s)).filter(Boolean);
      for (const a of q.albums()) {
        if (picks.length >= limit) break;
        if (a.curated && !picks.some((p) => p.slug === a.slug)) picks.push(a);
      }
      return picks.slice(0, limit);
    },

    // Amis = abonnements réciproques.
    friends(userId) {
      return db.prepare(`
        SELECT u.username, u.display_name, u.avatar FROM follows a
        JOIN follows b ON b.follower_id = a.followee_id AND b.followee_id = a.follower_id
        JOIN users u ON u.id = a.followee_id
        WHERE a.follower_id = ? ORDER BY u.display_name COLLATE NOCASE`).all(userId);
    },

    followList(userId, direction) {
      const sql = direction === 'followers'
        ? 'SELECT u.username, u.display_name, u.avatar FROM follows f JOIN users u ON u.id = f.follower_id WHERE f.followee_id = ? ORDER BY f.created_at DESC'
        : 'SELECT u.username, u.display_name, u.avatar FROM follows f JOIN users u ON u.id = f.followee_id WHERE f.follower_id = ? ORDER BY f.created_at DESC';
      return db.prepare(sql).all(userId);
    },

    feed(userId, limit = 50) {
      return db.prepare(`
        SELECT r.id, r.rating, r.body, r.listened_on, r.created_at, u.username, u.display_name, u.avatar, al.slug
        FROM reviews r JOIN users u ON u.id = r.user_id JOIN albums al ON al.id = r.album_id
        WHERE r.user_id IN (SELECT followee_id FROM follows WHERE follower_id = ?)
        ORDER BY r.created_at DESC LIMIT ?`).all(userId, limit)
        .map((r) => ({ ...r, album: q.album(r.slug) }));
    },

    list(id) {
      const l = db.prepare(`
        SELECT l.id, l.title, l.description, l.created_at, u.username, u.display_name, u.avatar, u.id AS user_id
        FROM lists l JOIN users u ON u.id = l.user_id WHERE l.id = ?`).get(id);
      if (!l) return null;
      l.albums = db.prepare(`${ALBUM_SELECT} JOIN list_items li ON li.album_id = al.id WHERE li.list_id = ? ORDER BY li.position`)
        .all(id).map(albumView);
      return l;
    },

    myLists(userId) {
      return db.prepare('SELECT id, title FROM lists WHERE user_id = ? ORDER BY created_at DESC').all(userId);
    },

    // Recherche tolérante : sans accents, sans ponctuation, mots dans n'importe quel ordre.
    search(term) {
      const words = normalize(term).split(' ').filter(Boolean);
      if (!words.length) return { albums: [], artists: [], users: [] };
      const matches = (text) => {
        const hay = normalize(text);
        return words.every((w) => hay.includes(w));
      };
      // Les albums dont le titre correspond passent avant ceux trouvés par le nom de l'artiste.
      const albums = q.albums()
        .map((a) => ({ a, title: matches(a.title), all: matches(`${a.title} ${a.artist.name}`) }))
        .filter((x) => x.all)
        .sort((x, y) => Number(y.title) - Number(x.title) || x.a.year - y.a.year)
        .slice(0, 60)
        .map((x) => x.a);
      const artists = db.prepare('SELECT slug, name FROM artists ORDER BY name').all().filter((a) => matches(a.name)).slice(0, 20);
      const users = db.prepare('SELECT username, display_name, avatar FROM users').all()
        .filter((u) => matches(`${u.username} ${u.display_name}`)).slice(0, 20);
      return { albums, artists, users };
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

export function normalize(text) {
  return String(text).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
    .replace(/œ/g, 'oe').replace(/æ/g, 'ae').replace(/\$/g, 's')
    .replace(/[^a-z0-9]+/g, ' ').trim();
}

export const absoluteUrl = (p) => `${config.publicUrl}${p}`;
