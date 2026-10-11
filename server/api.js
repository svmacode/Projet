import express from 'express';
import rateLimit from 'express-rate-limit';
import { config } from './config.js';
import { schemas, validate } from './validation.js';
import {
  hashPassword, verifyPassword, burnPasswordCheck, createSession, destroySession,
  requireAuth, requireVerified, randomToken, sha256, checkAntiSpam, looksLikeSpam,
} from './security.js';
import { verifyEmail, resetEmail } from './mailer.js';
import { readFilters } from './pages.js';
import { catalogStatus } from './auto-images.js';

const limiter = (windowMinutes, limit, message) => rateLimit({
  windowMs: windowMinutes * 60_000,
  limit: config.isTest ? 10_000 : limit,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: message },
});

export function apiRouter(db, q) {
  const api = express.Router();
  api.use(express.json({ limit: '20kb' }));
  api.use(limiter(1, 120, 'Trop de requêtes, réessaie dans une minute.'));

  const authLimiter = limiter(15, 10, 'Trop de tentatives. Réessaie dans 15 minutes.');
  const signupLimiter = limiter(60, 5, 'Trop de créations de compte depuis cette connexion.');
  const writeLimiter = limiter(60, 60, 'Tu publies beaucoup : fais une pause et réessaie plus tard.');

  const spamGuard = (req, res) => {
    const problem = checkAntiSpam(req.body);
    if (!problem) return false;
    // Un robot démasqué reçoit une réponse neutre, sans indice.
    if (problem === 'spam') res.status(202).json({ ok: true });
    else res.status(400).json({ error: problem });
    return true;
  };

  const createEmailToken = (userId, kind, hours) => {
    const token = randomToken();
    db.prepare("INSERT INTO email_tokens (token_hash, user_id, kind, expires_at) VALUES (?, ?, ?, datetime('now', ?))")
      .run(sha256(token), userId, kind, `+${hours} hours`);
    return token;
  };

  const consumeEmailToken = (token, kind) => {
    const row = db.prepare("SELECT user_id FROM email_tokens WHERE token_hash = ? AND kind = ? AND expires_at > datetime('now')")
      .get(sha256(token), kind);
    if (row) db.prepare('DELETE FROM email_tokens WHERE token_hash = ?').run(sha256(token));
    return row?.user_id ?? null;
  };

  const me = (req) => req.user && {
    username: req.user.username,
    displayName: req.user.displayName,
    verified: req.user.verified,
  };

  // ---------- Compte ----------
  api.get('/auth/me', (req, res) => {
    res.json({ user: me(req) || null, csrf: req.csrfToken || null });
  });

  api.post('/auth/register', signupLimiter, async (req, res) => {
    if (spamGuard(req, res)) return;
    const data = validate(schemas.register, req, res);
    if (!data) return;
    const taken = db.prepare('SELECT username, email FROM users WHERE username = ? OR email = ?').get(data.username, data.email);
    if (taken) {
      const fields = {};
      if (taken.username.toLowerCase() === data.username.toLowerCase()) fields.username = 'Ce pseudo est déjà pris.';
      // On ne confirme pas qu'un e-mail existe : message générique.
      if (taken.email === data.email) fields.email = 'Impossible de créer un compte avec cette adresse.';
      return res.status(409).json({ error: 'Certains champs sont à corriger.', fields });
    }
    const hash = await hashPassword(data.password);
    // Campagne d'origine (seulement si le visiteur a accepté la mesure d'audience, voir public/js/lib/extras.js).
    const utm = (v) => (v ? String(v).toLowerCase().replace(/[^a-z0-9_.-]/g, '').slice(0, 40) : null);
    const { lastInsertRowid } = db.prepare(`
      INSERT INTO users (username, email, password_hash, display_name, terms_accepted_at, utm_source, utm_medium, utm_campaign)
      VALUES (?, ?, ?, ?, datetime('now'), ?, ?, ?)`).run(data.username, data.email, hash, data.username,
      utm(data.utm?.source), utm(data.utm?.medium), utm(data.utm?.campaign));
    const userId = Number(lastInsertRowid);
    verifyEmail(data.email, createEmailToken(userId, 'verify', 48));
    const csrf = createSession(db, res, userId);
    res.status(201).json({ user: { username: data.username, displayName: data.username, verified: false }, csrf });
  });

  api.post('/auth/login', authLimiter, async (req, res) => {
    if (spamGuard(req, res)) return;
    const data = validate(schemas.login, req, res);
    if (!data) return;
    const user = db.prepare('SELECT id, username, display_name, password_hash, email_verified_at FROM users WHERE username = ? OR email = ?')
      .get(data.login, data.login.toLowerCase());
    const ok = user ? await verifyPassword(data.password, user.password_hash) : await burnPasswordCheck(data.password);
    if (!ok) return res.status(401).json({ error: 'Identifiants incorrects.' });
    const csrf = createSession(db, res, user.id);
    res.json({ user: { username: user.username, displayName: user.display_name, verified: Boolean(user.email_verified_at) }, csrf });
  });

  api.post('/auth/logout', (req, res) => {
    destroySession(db, req, res);
    res.json({ ok: true });
  });

  api.post('/auth/logout-all', requireAuth, (req, res) => {
    db.prepare('DELETE FROM sessions WHERE user_id = ?').run(req.user.id);
    destroySession(db, req, res);
    res.json({ ok: true });
  });

  api.post('/auth/verify', authLimiter, (req, res) => {
    const data = validate(schemas.verify, req, res);
    if (!data) return;
    const userId = consumeEmailToken(data.token, 'verify');
    if (!userId) return res.status(400).json({ error: 'Lien invalide ou expiré.' });
    db.prepare("UPDATE users SET email_verified_at = datetime('now') WHERE id = ?").run(userId);
    res.json({ ok: true });
  });

  api.post('/auth/resend', requireAuth, limiter(60, 3, 'Patiente avant de redemander un e-mail.'), (req, res) => {
    if (req.user.verified) return res.json({ ok: true });
    db.prepare("DELETE FROM email_tokens WHERE user_id = ? AND kind = 'verify'").run(req.user.id);
    verifyEmail(req.user.email, createEmailToken(req.user.id, 'verify', 48));
    res.json({ ok: true });
  });

  api.post('/auth/forgot', authLimiter, (req, res) => {
    if (spamGuard(req, res)) return;
    const data = validate(schemas.forgot, req, res);
    if (!data) return;
    const user = db.prepare('SELECT id, email FROM users WHERE email = ?').get(data.email);
    if (user) {
      db.prepare("DELETE FROM email_tokens WHERE user_id = ? AND kind = 'reset'").run(user.id);
      resetEmail(user.email, createEmailToken(user.id, 'reset', 1));
    }
    // Même réponse dans tous les cas : on ne révèle pas quels e-mails sont inscrits.
    res.json({ ok: true });
  });

  api.post('/auth/reset', authLimiter, async (req, res) => {
    const data = validate(schemas.reset, req, res);
    if (!data) return;
    const userId = consumeEmailToken(data.token, 'reset');
    if (!userId) return res.status(400).json({ error: 'Lien invalide ou expiré.' });
    db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(await hashPassword(data.password), userId);
    db.prepare('DELETE FROM sessions WHERE user_id = ?').run(userId);
    res.json({ ok: true });
  });

  // ---------- Catalogue ----------
  // Catalogue filtré et paginé (mêmes paramètres que la page /albums).
  api.get('/albums', (req, res) => {
    const filters = readFilters(req.query);
    const perPage = Math.min(200, Math.max(1, Number.parseInt(req.query.par, 10) || 60));
    res.json(q.albumPage({ ...filters, perPage }));
  });

  // Avancement de la mise à jour automatique du catalogue.
  api.get('/catalogue/etat', (req, res) => {
    res.set('Cache-Control', 'no-store');
    res.json({ ...catalogStatus(), albums: q.count().n });
  });

  api.get('/albums/:slug', (req, res) => {
    const album = q.album(req.params.slug);
    if (!album) return res.status(404).json({ error: 'Album introuvable.' });
    const viewer = req.user?.id || 0;
    res.json({
      album,
      reviews: q.reviewsForAlbum(album.id, viewer),
      friendsReviews: viewer ? q.reviewsForAlbum(album.id, viewer, { friendsOnly: true }) : [],
      state: viewer ? q.userState(viewer, album.id) : null,
      lists: viewer ? q.myLists(viewer) : [],
    });
  });

  api.get('/artists', (req, res) => res.json({ artists: q.artists() }));

  api.get('/artists/:slug', (req, res) => {
    const artist = q.artist(req.params.slug);
    if (!artist) return res.status(404).json({ error: 'Rappeur introuvable.' });
    res.json({ artist });
  });

  api.get('/search', (req, res) => {
    const term = String(req.query.q || '').trim().slice(0, 60);
    if (term.length < 2) return res.json({ albums: [], artists: [], users: [] });
    res.json(q.search(term));
  });

  // ---------- Activité sur un album ----------
  api.put('/albums/:slug/state', requireAuth, writeLimiter, (req, res) => {
    const albumId = q.albumId(req.params.slug);
    if (!albumId) return res.status(404).json({ error: 'Album introuvable.' });
    const data = validate(schemas.albumState, req, res);
    if (!data) return;
    const current = q.userState(req.user.id, albumId);
    const next = {
      rating: data.rating !== undefined ? data.rating : current.rating,
      liked: data.liked !== undefined ? Number(data.liked) : current.liked,
      listened: data.listened !== undefined ? Number(data.listened) : current.listened,
      wishlist: data.wishlist !== undefined ? Number(data.wishlist) : current.wishlist,
    };
    // Noter ou aimer un album vaut écoute, et le retire de « À écouter ».
    if (data.rating || data.liked || data.listened) {
      next.listened = 1;
      next.wishlist = 0;
    }
    db.prepare(`
      INSERT INTO user_albums (user_id, album_id, rating, liked, listened, wishlist, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
      ON CONFLICT(user_id, album_id) DO UPDATE SET rating = excluded.rating, liked = excluded.liked,
        listened = excluded.listened, wishlist = excluded.wishlist, updated_at = excluded.updated_at`)
      .run(req.user.id, albumId, next.rating, next.liked, next.listened, next.wishlist);
    res.json({ state: q.userState(req.user.id, albumId), album: q.album(req.params.slug) });
  });

  api.post('/albums/:slug/reviews', requireVerified, writeLimiter, (req, res) => {
    if (spamGuard(req, res)) return;
    const albumId = q.albumId(req.params.slug);
    if (!albumId) return res.status(404).json({ error: 'Album introuvable.' });
    const data = validate(schemas.review, req, res);
    if (!data) return;
    if (looksLikeSpam(data.body)) return res.status(400).json({ error: 'Trop de liens dans ta chronique.', fields: { body: 'Deux liens maximum.' } });
    const today = new Date().toISOString().slice(0, 10);
    const listenedOn = data.listenedOn && data.listenedOn <= today ? data.listenedOn : today;
    const { lastInsertRowid } = db.prepare('INSERT INTO reviews (user_id, album_id, rating, body, listened_on) VALUES (?, ?, ?, ?, ?)')
      .run(req.user.id, albumId, data.rating ?? null, data.body, listenedOn);
    db.prepare(`
      INSERT INTO user_albums (user_id, album_id, rating, listened, wishlist) VALUES (?, ?, ?, 1, 0)
      ON CONFLICT(user_id, album_id) DO UPDATE SET listened = 1, wishlist = 0,
        rating = COALESCE(excluded.rating, rating), updated_at = datetime('now')`)
      .run(req.user.id, albumId, data.rating ?? null);
    res.status(201).json({ id: Number(lastInsertRowid) });
  });

  const ownReview = (req, res) => {
    const review = db.prepare('SELECT id, user_id FROM reviews WHERE id = ?').get(Number(req.params.id));
    if (!review) { res.status(404).json({ error: 'Chronique introuvable.' }); return null; }
    if (review.user_id !== req.user.id) { res.status(403).json({ error: "Ce n'est pas ta chronique." }); return null; }
    return review;
  };

  api.patch('/reviews/:id', requireVerified, writeLimiter, (req, res) => {
    const review = ownReview(req, res);
    if (!review) return;
    const data = validate(schemas.review, req, res);
    if (!data) return;
    if (looksLikeSpam(data.body)) return res.status(400).json({ error: 'Trop de liens dans ta chronique.' });
    db.prepare("UPDATE reviews SET body = ?, rating = ?, updated_at = datetime('now') WHERE id = ?")
      .run(data.body, data.rating ?? null, review.id);
    res.json({ ok: true });
  });

  api.delete('/reviews/:id', requireAuth, (req, res) => {
    const review = ownReview(req, res);
    if (!review) return;
    db.prepare('DELETE FROM reviews WHERE id = ?').run(review.id);
    res.json({ ok: true });
  });

  api.post('/reviews/:id/like', requireAuth, writeLimiter, (req, res) => {
    const id = Number(req.params.id);
    if (!db.prepare('SELECT 1 FROM reviews WHERE id = ?').get(id)) return res.status(404).json({ error: 'Chronique introuvable.' });
    const liked = db.prepare('SELECT 1 FROM review_likes WHERE user_id = ? AND review_id = ?').get(req.user.id, id);
    if (liked) db.prepare('DELETE FROM review_likes WHERE user_id = ? AND review_id = ?').run(req.user.id, id);
    else db.prepare('INSERT INTO review_likes (user_id, review_id) VALUES (?, ?)').run(req.user.id, id);
    const { n } = db.prepare('SELECT COUNT(*) n FROM review_likes WHERE review_id = ?').get(id);
    res.json({ liked: !liked, likes: n });
  });

  api.post('/reviews/:id/report', requireAuth, limiter(60, 10, 'Trop de signalements.'), (req, res) => {
    const data = validate(schemas.report, req, res);
    if (!data) return;
    const id = Number(req.params.id);
    if (!db.prepare('SELECT 1 FROM reviews WHERE id = ?').get(id)) return res.status(404).json({ error: 'Chronique introuvable.' });
    db.prepare('INSERT OR IGNORE INTO reports (reporter_id, review_id, reason) VALUES (?, ?, ?)').run(req.user.id, id, data.reason);
    res.json({ ok: true });
  });

  // ---------- Membres et amis ----------
  api.get('/users/:username', (req, res) => {
    const profile = q.profile(req.params.username, req.user?.id || 0);
    if (!profile) return res.status(404).json({ error: 'Membre introuvable.' });
    delete profile.id;
    res.json({ profile });
  });

  api.get('/users/:username/:direction(followers|following)', (req, res) => {
    const u = q.user(req.params.username);
    if (!u) return res.status(404).json({ error: 'Membre introuvable.' });
    res.json({ users: q.followList(u.id, req.params.direction) });
  });

  api.post('/users/:username/follow', requireAuth, writeLimiter, (req, res) => {
    const u = q.user(req.params.username);
    if (!u) return res.status(404).json({ error: 'Membre introuvable.' });
    if (u.id === req.user.id) return res.status(400).json({ error: 'Tu ne peux pas te suivre toi-même.' });
    db.prepare('INSERT OR IGNORE INTO follows (follower_id, followee_id) VALUES (?, ?)').run(req.user.id, u.id);
    res.json({ following: true, friends: Boolean(db.prepare('SELECT 1 FROM follows WHERE follower_id = ? AND followee_id = ?').get(u.id, req.user.id)) });
  });

  api.delete('/users/:username/follow', requireAuth, (req, res) => {
    const u = q.user(req.params.username);
    if (!u) return res.status(404).json({ error: 'Membre introuvable.' });
    db.prepare('DELETE FROM follows WHERE follower_id = ? AND followee_id = ?').run(req.user.id, u.id);
    res.json({ following: false, friends: false });
  });

  api.get('/feed', requireAuth, (req, res) => res.json({ feed: q.feed(req.user.id) }));

  // ---------- Listes ----------
  api.post('/lists', requireVerified, writeLimiter, (req, res) => {
    const data = validate(schemas.list, req, res);
    if (!data) return;
    if (looksLikeSpam(data.description)) return res.status(400).json({ error: 'Trop de liens dans la description.' });
    const { lastInsertRowid } = db.prepare('INSERT INTO lists (user_id, title, description) VALUES (?, ?, ?)')
      .run(req.user.id, data.title, data.description);
    res.status(201).json({ id: Number(lastInsertRowid) });
  });

  const ownList = (req, res) => {
    const list = db.prepare('SELECT id, user_id FROM lists WHERE id = ?').get(Number(req.params.id));
    if (!list) { res.status(404).json({ error: 'Liste introuvable.' }); return null; }
    if (list.user_id !== req.user.id) { res.status(403).json({ error: "Ce n'est pas ta liste." }); return null; }
    return list;
  };

  api.get('/lists/:id', (req, res) => {
    const list = q.list(Number(req.params.id));
    if (!list) return res.status(404).json({ error: 'Liste introuvable.' });
    delete list.user_id;
    res.json({ list });
  });

  api.post('/lists/:id/items', requireAuth, writeLimiter, (req, res) => {
    const list = ownList(req, res);
    if (!list) return;
    const data = validate(schemas.listItem, req, res);
    if (!data) return;
    const albumId = q.albumId(data.album);
    if (!albumId) return res.status(404).json({ error: 'Album introuvable.' });
    const { n } = db.prepare('SELECT COUNT(*) n FROM list_items WHERE list_id = ?').get(list.id);
    if (n >= 200) return res.status(400).json({ error: 'Une liste contient 200 albums maximum.' });
    db.prepare('INSERT OR IGNORE INTO list_items (list_id, album_id, position) VALUES (?, ?, ?)').run(list.id, albumId, n + 1);
    res.json({ ok: true });
  });

  api.delete('/lists/:id/items/:album', requireAuth, (req, res) => {
    const list = ownList(req, res);
    if (!list) return;
    const albumId = q.albumId(req.params.album);
    db.prepare('DELETE FROM list_items WHERE list_id = ? AND album_id = ?').run(list.id, albumId);
    res.json({ ok: true });
  });

  api.delete('/lists/:id', requireAuth, (req, res) => {
    const list = ownList(req, res);
    if (!list) return;
    db.prepare('DELETE FROM lists WHERE id = ?').run(list.id);
    res.json({ ok: true });
  });

  // ---------- Mon compte (RGPD : accès, rectification, portabilité, effacement) ----------
  api.get('/me', requireAuth, (req, res) => {
    const u = db.prepare('SELECT username, email, display_name, bio, email_verified_at, created_at FROM users WHERE id = ?').get(req.user.id);
    const favorites = db.prepare('SELECT al.slug FROM favorites f JOIN albums al ON al.id = f.album_id WHERE f.user_id = ? ORDER BY position')
      .all(req.user.id).map((r) => r.slug);
    res.json({ me: { ...u, favorites } });
  });

  api.put('/me', requireAuth, writeLimiter, (req, res) => {
    const data = validate(schemas.profile, req, res);
    if (!data) return;
    if (looksLikeSpam(data.bio)) return res.status(400).json({ error: 'Trop de liens dans ta bio.', fields: { bio: 'Deux liens maximum.' } });
    db.exec('BEGIN');
    try {
      db.prepare('UPDATE users SET display_name = ?, bio = ? WHERE id = ?').run(data.displayName, data.bio, req.user.id);
      db.prepare('DELETE FROM favorites WHERE user_id = ?').run(req.user.id);
      const unique = [...new Set(data.favorites)];
      unique.forEach((slug, i) => {
        const albumId = q.albumId(slug);
        if (albumId) db.prepare('INSERT INTO favorites (user_id, album_id, position) VALUES (?, ?, ?)').run(req.user.id, albumId, i + 1);
      });
      db.exec('COMMIT');
    } catch (err) {
      db.exec('ROLLBACK');
      throw err;
    }
    res.json({ ok: true });
  });

  api.put('/me/password', requireAuth, authLimiter, async (req, res) => {
    const data = validate(schemas.changePassword, req, res);
    if (!data) return;
    const { password_hash } = db.prepare('SELECT password_hash FROM users WHERE id = ?').get(req.user.id);
    if (!(await verifyPassword(data.current, password_hash))) {
      return res.status(400).json({ error: 'Mot de passe actuel incorrect.', fields: { current: 'Mot de passe incorrect.' } });
    }
    db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(await hashPassword(data.password), req.user.id);
    // Déconnecte les autres appareils.
    db.prepare('DELETE FROM sessions WHERE user_id = ? AND token_hash <> ?').run(req.user.id, req.sessionHash);
    res.json({ ok: true });
  });

  api.get('/me/export', requireAuth, limiter(60, 10, "Trop d'exports, réessaie plus tard."), (req, res) => {
    const id = req.user.id;
    const all = (sql) => db.prepare(sql).all(id);
    const data = {
      exportedAt: new Date().toISOString(),
      account: db.prepare('SELECT username, email, display_name, bio, email_verified_at, terms_accepted_at, created_at, utm_source, utm_medium, utm_campaign FROM users WHERE id = ?').get(id),
      albums: all('SELECT al.slug, al.title, s.rating, s.liked, s.listened, s.wishlist, s.updated_at FROM user_albums s JOIN albums al ON al.id = s.album_id WHERE s.user_id = ?'),
      diary: all('SELECT al.slug, al.title, r.rating, r.body, r.listened_on, r.created_at FROM reviews r JOIN albums al ON al.id = r.album_id WHERE r.user_id = ?'),
      favorites: all('SELECT al.slug, f.position FROM favorites f JOIN albums al ON al.id = f.album_id WHERE f.user_id = ?'),
      following: all('SELECT u.username FROM follows f JOIN users u ON u.id = f.followee_id WHERE f.follower_id = ?'),
      followers: all('SELECT u.username FROM follows f JOIN users u ON u.id = f.follower_id WHERE f.followee_id = ?'),
      lists: all('SELECT id, title, description, created_at FROM lists WHERE user_id = ?'),
      reviewLikes: all('SELECT review_id, created_at FROM review_likes WHERE user_id = ?'),
    };
    res.set('Content-Disposition', `attachment; filename="myrapfr-${req.user.username}.json"`);
    res.json(data);
  });

  api.delete('/me', requireAuth, authLimiter, async (req, res) => {
    const data = validate(schemas.deleteAccount, req, res);
    if (!data) return;
    const { password_hash } = db.prepare('SELECT password_hash FROM users WHERE id = ?').get(req.user.id);
    if (!(await verifyPassword(data.password, password_hash))) {
      return res.status(400).json({ error: 'Mot de passe incorrect.', fields: { password: 'Mot de passe incorrect.' } });
    }
    // Les clés étrangères en cascade suppriment toutes les données liées.
    db.prepare('DELETE FROM users WHERE id = ?').run(req.user.id);
    destroySession(db, req, res);
    res.json({ ok: true });
  });

  api.use((req, res) => res.status(404).json({ error: 'Route inconnue.' }));
  return api;
}
