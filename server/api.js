import express from 'express';
import rateLimit from 'express-rate-limit';
import { config } from './config.js';
import { schemas, validate } from './validation.js';
import {
  hashPassword, verifyPassword, burnPasswordCheck, createSession, destroySession,
  requireAuth, requireVerified, requireAdmin, randomToken, sha256, checkAntiSpam, looksLikeSpam,
} from './security.js';
import { verifyEmail, resetEmail } from './mailer.js';
import { readFilters } from './pages.js';
import { catalogStatus } from './auto-images.js';
import { saveUpload, removeAvatarFile, avatarUrl } from './avatars.js';
import { moderation } from './moderation.js';
import { notifier } from './notify.js';
import { badgeEngine } from './badges.js';
import { messaging } from './messages.js';
import { albumDetails, listenLinks } from './album-details.js';

const limiter = (windowMinutes, limit, message) => rateLimit({
  windowMs: windowMinutes * 60_000,
  limit: config.isTest ? 10_000 : limit,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: message },
});

// Express 4 ne rattrape pas les erreurs des fonctions async : sans ce relais, une erreur imprévue
// dans une route (base occupée, disque plein…) arrêtait tout le serveur.
function catchAsync(router) {
  for (const method of ['get', 'post', 'put', 'patch', 'delete']) {
    const original = router[method].bind(router);
    router[method] = (path, ...handlers) => original(path, ...handlers.map((fn) => (typeof fn === 'function' && fn.length < 4
      ? (req, res, next) => { try { Promise.resolve(fn(req, res, next)).catch(next); } catch (err) { next(err); } }
      : fn)));
  }
  return router;
}

export function apiRouter(db, q) {
  const api = catchAsync(express.Router());
  const notify = notifier(db);
  const badges = badgeEngine(db, notify);

  // Après chaque action réussie d'un membre (POST, PUT, DELETE), ses badges sont recalculés ; les nouveaux
  // sont ajoutés à la réponse (« newBadges ») pour que le navigateur les annonce.
  api.use((req, res, next) => {
    if (req.method === 'GET' || !req.user || req.path.startsWith('/admin/')) return next();
    const json = res.json.bind(res);
    res.json = (body) => {
      if (res.statusCode < 400 && body && typeof body === 'object' && !Array.isArray(body)) {
        try {
          const fresh = badges.check(req.user.id);
          if (fresh.length) body = { ...body, newBadges: fresh };
        } catch { /* un badge ne doit jamais faire échouer l'action */ }
      }
      return json(body);
    };
    next();
  });
  const blocked = (a, b) => Boolean(db.prepare('SELECT 1 FROM blocks WHERE (blocker_id = ? AND blocked_id = ?) OR (blocker_id = ? AND blocked_id = ?)').get(a, b, b, a));
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
    const user = db.prepare('SELECT id, username, display_name, password_hash, email_verified_at, suspended_at FROM users WHERE username = ? OR email = ?')
      .get(data.login, data.login.toLowerCase());
    const ok = user ? await verifyPassword(data.password, user.password_hash) : await burnPasswordCheck(data.password);
    if (!ok) return res.status(401).json({ error: 'Identifiants incorrects.' });
    if (user.suspended_at) {
      return res.status(403).json({ error: `Ce compte est suspendu pour non-respect des conditions d'utilisation. Pour en parler : ${config.contactEmail}` });
    }
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

  // Titres, durée et liens d'écoute (Deezer, avec cache ; pas d'appel réseau pendant les tests).
  const details = albumDetails(db);
  api.get('/albums/:slug/details', async (req, res) => {
    const album = q.album(req.params.slug);
    if (!album) return res.status(404).json({ error: 'Album introuvable.' });
    res.set('Cache-Control', 'private, max-age=3600');
    if (config.isTest) return res.json({ tracks: [], links: listenLinks(album, null) });
    res.json(await details(album));
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
    const review = db.prepare('SELECT id, user_id FROM reviews WHERE id = ?').get(id);
    if (!review) return res.status(404).json({ error: 'Chronique introuvable.' });
    if (blocked(req.user.id, review.user_id)) return res.status(403).json({ error: 'Action impossible.' });
    const liked = db.prepare('SELECT 1 FROM review_likes WHERE user_id = ? AND review_id = ?').get(req.user.id, id);
    if (liked) db.prepare('DELETE FROM review_likes WHERE user_id = ? AND review_id = ?').run(req.user.id, id);
    else {
      db.prepare('INSERT INTO review_likes (user_id, review_id) VALUES (?, ?)').run(req.user.id, id);
      notify({ to: review.user_id, actor: req.user.id, type: 'like', reviewId: id });
      badges.check(review.user_id);
    }
    const { n } = db.prepare('SELECT COUNT(*) n FROM review_likes WHERE review_id = ?').get(id);
    res.json({ liked: !liked, likes: n });
  });

  api.post('/reviews/:id/report', requireAuth, limiter(60, 10, 'Trop de signalements.'), (req, res) => {
    const data = validate(schemas.report, req, res);
    if (!data) return;
    const id = Number(req.params.id);
    if (!db.prepare('SELECT 1 FROM reviews WHERE id = ?').get(id)) return res.status(404).json({ error: 'Chronique introuvable.' });
    db.prepare(`INSERT INTO reports (reporter_id, review_id, reason) VALUES (?, ?, ?)
      ON CONFLICT(reporter_id, review_id) DO UPDATE SET reason = excluded.reason, created_at = datetime('now'), resolved_at = NULL, resolution = NULL`)
      .run(req.user.id, id, data.reason);
    res.json({ ok: true });
  });

  // ---------- Commentaires ----------
  api.post('/reviews/:id/comments', requireVerified, writeLimiter, (req, res) => {
    const data = validate(schemas.comment, req, res);
    if (!data) return;
    if (looksLikeSpam(data.body)) return res.status(400).json({ error: 'Trop de liens dans ton commentaire.', fields: { body: 'Deux liens maximum.' } });
    const review = db.prepare(`SELECT r.id, r.user_id FROM reviews r JOIN users u ON u.id = r.user_id
      WHERE r.id = ? AND r.hidden_at IS NULL AND u.suspended_at IS NULL`).get(Number(req.params.id));
    if (!review) return res.status(404).json({ error: 'Chronique introuvable.' });
    if (blocked(req.user.id, review.user_id)) return res.status(403).json({ error: 'Tu ne peux pas commenter cette chronique.' });
    const { lastInsertRowid } = db.prepare('INSERT INTO comments (review_id, user_id, body) VALUES (?, ?, ?)').run(review.id, req.user.id, data.body);
    const commentId = Number(lastInsertRowid);
    notify({ to: review.user_id, actor: req.user.id, type: 'comment', reviewId: review.id, commentId });
    res.status(201).json({
      comment: { id: commentId, body: data.body, username: req.user.username, displayName: req.user.displayName, avatar: avatarUrl(req.user.avatar) },
    });
  });

  // Supprimer : l'auteur du commentaire, l'auteur de la chronique ou un administrateur.
  api.delete('/comments/:id', requireAuth, (req, res) => {
    const c = db.prepare(`SELECT c.id, c.user_id, r.user_id AS review_author, u.username FROM comments c
      JOIN reviews r ON r.id = c.review_id JOIN users u ON u.id = c.user_id WHERE c.id = ?`).get(Number(req.params.id));
    if (!c) return res.status(404).json({ error: 'Commentaire introuvable.' });
    if (![c.user_id, c.review_author].includes(req.user.id) && !req.user.admin) return res.status(403).json({ error: 'Action impossible.' });
    db.prepare('DELETE FROM comments WHERE id = ?').run(c.id);
    if (req.user.admin && ![c.user_id, c.review_author].includes(req.user.id)) {
      db.prepare('INSERT INTO mod_log (admin_id, action, target) VALUES (?, ?, ?)').run(req.user.id, 'commentaire supprimé', `commentaire ${c.id} de @${c.username}`);
    }
    res.json({ ok: true });
  });

  api.post('/comments/:id/report', requireAuth, limiter(60, 10, 'Trop de signalements.'), (req, res) => {
    const data = validate(schemas.report, req, res);
    if (!data) return;
    const id = Number(req.params.id);
    if (!db.prepare('SELECT 1 FROM comments WHERE id = ?').get(id)) return res.status(404).json({ error: 'Commentaire introuvable.' });
    db.prepare(`INSERT INTO comment_reports (reporter_id, comment_id, reason) VALUES (?, ?, ?)
      ON CONFLICT(reporter_id, comment_id) DO UPDATE SET reason = excluded.reason, created_at = datetime('now'), resolved_at = NULL, resolution = NULL`)
      .run(req.user.id, id, data.reason);
    res.json({ ok: true });
  });

  // ---------- Messages privés (entre amis) ----------
  const dm = messaging(db);
  const msgLimiter = limiter(60, 120, 'Tu envoies beaucoup de messages : fais une pause.');
  const peerOf = (req, res) => {
    const u = q.user(req.params.username);
    if (!u || u.suspended_at || u.id === req.user.id) { res.status(404).json({ error: 'Membre introuvable.' }); return null; }
    return u;
  };

  api.get('/messages', requireAuth, (req, res) => {
    res.set('Cache-Control', 'no-store');
    res.json({ unread: dm.unread(req.user.id), conversations: dm.conversations(req.user.id) });
  });

  // Nouveaux messages d'une conversation (après l'identifiant `after`) ; les marque comme lus.
  api.get('/messages/:username', requireAuth, (req, res) => {
    const peer = peerOf(req, res);
    if (!peer) return;
    res.set('Cache-Control', 'no-store');
    const messages = dm.thread(req.user.id, peer.id, Number.parseInt(req.query.after, 10) || 0);
    dm.markRead(req.user.id, peer.id);
    res.json({ messages, canMessage: dm.canMessage(req.user.id, peer.id) });
  });

  api.post('/messages/:username', requireVerified, msgLimiter, (req, res) => {
    const data = validate(schemas.message, req, res);
    if (!data) return;
    const peer = peerOf(req, res);
    if (!peer) return;
    if (!dm.canMessage(req.user.id, peer.id)) {
      return res.status(403).json({ error: 'Tu ne peux écrire qu\'à tes amis (vous vous suivez tous les deux).' });
    }
    if (looksLikeSpam(data.body)) return res.status(400).json({ error: 'Trop de liens dans ton message.', fields: { body: 'Deux liens maximum.' } });
    res.status(201).json({ message: dm.send(req.user.id, peer.id, data.body) });
  });

  api.delete('/message/:id', requireAuth, (req, res) => {
    if (!dm.remove(req.user.id, Number(req.params.id))) return res.status(404).json({ error: 'Message introuvable.' });
    res.json({ ok: true });
  });

  api.post('/message/:id/report', requireAuth, limiter(60, 10, 'Trop de signalements.'), (req, res) => {
    const data = validate(schemas.report, req, res);
    if (!data) return;
    if (!dm.report(req.user.id, Number(req.params.id), data.reason)) return res.status(404).json({ error: 'Message introuvable.' });
    res.json({ ok: true });
  });

  // ---------- Notifications ----------
  api.get('/notifications', requireAuth, (req, res) => {
    res.set('Cache-Control', 'no-store');
    res.json({ unread: q.unreadNotifications(req.user.id), notifications: q.notifications(req.user.id, 30) });
  });
  api.post('/notifications/read', requireAuth, (req, res) => {
    db.prepare("UPDATE notifications SET read_at = datetime('now') WHERE user_id = ? AND read_at IS NULL").run(req.user.id);
    res.json({ ok: true });
  });

  // ---------- Membres et amis ----------
  // Recherche de membres (page Amis) : réservée aux membres connectés.
  api.get('/users', requireAuth, (req, res) => {
    const text = String(req.query.q || '').trim().slice(0, 40);
    if (text.length < 2) return res.json({ users: [] });
    res.json({
      users: q.searchMembers(text, req.user.id).map((u) => ({
        username: u.username, displayName: u.display_name, avatar: avatarUrl(u.avatar), listened: u.listened,
        isFollowing: Boolean(u.isFollowing), followsMe: Boolean(u.followsMe),
      })),
    });
  });

  api.get('/users/:username', (req, res) => {
    const profile = q.profile(req.params.username, req.user?.id || 0);
    if (!profile) return res.status(404).json({ error: 'Membre introuvable.' });
    for (const key of ['id', 'role', 'suspended_at']) delete profile[key];
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
    if (u.suspended_at || blocked(req.user.id, u.id)) return res.status(403).json({ error: 'Impossible de suivre ce membre.' });
    const { changes } = db.prepare('INSERT OR IGNORE INTO follows (follower_id, followee_id) VALUES (?, ?)').run(req.user.id, u.id);
    const friends = Boolean(db.prepare('SELECT 1 FROM follows WHERE follower_id = ? AND followee_id = ?').get(u.id, req.user.id));
    if (changes) notify({ to: u.id, actor: req.user.id, type: friends ? 'friend' : 'follow' });
    if (friends) badges.check(u.id);
    res.json({ following: true, friends });
  });

  api.delete('/users/:username/follow', requireAuth, (req, res) => {
    const u = q.user(req.params.username);
    if (!u) return res.status(404).json({ error: 'Membre introuvable.' });
    db.prepare('DELETE FROM follows WHERE follower_id = ? AND followee_id = ?').run(req.user.id, u.id);
    res.json({ following: false, friends: false });
  });

  // ---------- Bloquer un membre ----------
  // Bloquer retire les abonnements dans les deux sens ; ensuite, aucun des deux ne voit les chroniques
  // de l'autre ni ne peut le suivre, et le membre bloqué ne peut plus ouvrir le profil.
  api.post('/users/:username/block', requireAuth, writeLimiter, (req, res) => {
    const u = q.user(req.params.username);
    if (!u) return res.status(404).json({ error: 'Membre introuvable.' });
    if (u.id === req.user.id) return res.status(400).json({ error: 'Tu ne peux pas te bloquer toi-même.' });
    db.exec('BEGIN');
    try {
      db.prepare('INSERT OR IGNORE INTO blocks (blocker_id, blocked_id) VALUES (?, ?)').run(req.user.id, u.id);
      db.prepare('DELETE FROM follows WHERE (follower_id = ? AND followee_id = ?) OR (follower_id = ? AND followee_id = ?)')
        .run(req.user.id, u.id, u.id, req.user.id);
      db.exec('COMMIT');
    } catch (err) {
      db.exec('ROLLBACK');
      throw err;
    }
    res.json({ blocked: true });
  });

  api.delete('/users/:username/block', requireAuth, (req, res) => {
    const u = q.user(req.params.username);
    if (!u) return res.status(404).json({ error: 'Membre introuvable.' });
    db.prepare('DELETE FROM blocks WHERE blocker_id = ? AND blocked_id = ?').run(req.user.id, u.id);
    res.json({ blocked: false });
  });

  // Signaler un profil (photo, nom ou bio inappropriés).
  api.post('/users/:username/report', requireAuth, limiter(60, 10, 'Trop de signalements.'), (req, res) => {
    const data = validate(schemas.report, req, res);
    if (!data) return;
    const u = q.user(req.params.username);
    if (!u || u.id === req.user.id) return res.status(404).json({ error: 'Membre introuvable.' });
    db.prepare(`INSERT INTO user_reports (reporter_id, user_id, reason) VALUES (?, ?, ?)
      ON CONFLICT(reporter_id, user_id) DO UPDATE SET reason = excluded.reason, created_at = datetime('now'), resolved_at = NULL, resolution = NULL`)
      .run(req.user.id, u.id, data.reason);
    res.json({ ok: true });
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
    const list = db.prepare('SELECT id, user_id, title FROM lists WHERE id = ?').get(Number(req.params.id));
    if (!list) { res.status(404).json({ error: 'Liste introuvable.' }); return null; }
    if (list.user_id !== req.user.id) { res.status(403).json({ error: "Ce n'est pas ta liste." }); return null; }
    return list;
  };
  // Liste modifiable : par son auteur ou par un membre invité à la compléter.
  const editableList = (req, res) => {
    const list = db.prepare('SELECT id, user_id, title FROM lists WHERE id = ?').get(Number(req.params.id));
    if (!list) { res.status(404).json({ error: 'Liste introuvable.' }); return null; }
    const collab = db.prepare('SELECT 1 FROM list_collaborators WHERE list_id = ? AND user_id = ?').get(list.id, req.user.id);
    if (list.user_id !== req.user.id && !collab) { res.status(403).json({ error: "Tu ne peux pas modifier cette liste." }); return null; }
    return list;
  };
  // Positions 1, 2, 3… sans trou (après un retrait).
  const compact = (listId) => {
    const ids = db.prepare('SELECT album_id FROM list_items WHERE list_id = ? ORDER BY position, rowid').all(listId);
    const set = db.prepare('UPDATE list_items SET position = ? WHERE list_id = ? AND album_id = ?');
    ids.forEach((r, i) => set.run(i + 1, listId, r.album_id));
  };

  api.get('/lists/:id', (req, res) => {
    const list = q.list(Number(req.params.id));
    if (!list) return res.status(404).json({ error: 'Liste introuvable.' });
    delete list.user_id;
    res.json({ list });
  });

  api.post('/lists/:id/items', requireAuth, writeLimiter, (req, res) => {
    const list = editableList(req, res);
    if (!list) return;
    const data = validate(schemas.listItem, req, res);
    if (!data) return;
    const albumId = q.albumId(data.album);
    if (!albumId) return res.status(404).json({ error: 'Album introuvable.' });
    const { n } = db.prepare('SELECT COUNT(*) n FROM list_items WHERE list_id = ?').get(list.id);
    if (n >= 200) return res.status(400).json({ error: 'Une liste contient 200 albums maximum.' });
    db.prepare('INSERT OR IGNORE INTO list_items (list_id, album_id, position, added_by) VALUES (?, ?, ?, ?)').run(list.id, albumId, n + 1, req.user.id);
    res.json({ ok: true });
  });

  api.delete('/lists/:id/items/:album', requireAuth, (req, res) => {
    const list = editableList(req, res);
    if (!list) return;
    const albumId = q.albumId(req.params.album);
    db.prepare('DELETE FROM list_items WHERE list_id = ? AND album_id = ?').run(list.id, albumId);
    compact(list.id);
    res.json({ ok: true });
  });

  // Note sur un album de la liste (« pourquoi il est là »).
  api.put('/lists/:id/items/:album', requireAuth, writeLimiter, (req, res) => {
    const list = editableList(req, res);
    if (!list) return;
    const note = typeof req.body?.note === 'string' ? req.body.note.trim().slice(0, 280) : '';
    if (looksLikeSpam(note)) return res.status(400).json({ error: 'Trop de liens dans la note.' });
    const { changes } = db.prepare('UPDATE list_items SET note = ? WHERE list_id = ? AND album_id = ?').run(note, list.id, q.albumId(req.params.album));
    if (!changes) return res.status(404).json({ error: "Cet album n'est pas dans la liste." });
    res.json({ ok: true, note });
  });

  // Monter ou descendre un album dans le classement.
  api.post('/lists/:id/items/:album/move', requireAuth, (req, res) => {
    const list = editableList(req, res);
    if (!list) return;
    compact(list.id);
    const albumId = q.albumId(req.params.album);
    const item = db.prepare('SELECT position FROM list_items WHERE list_id = ? AND album_id = ?').get(list.id, albumId);
    if (!item) return res.status(404).json({ error: "Cet album n'est pas dans la liste." });
    const target = item.position + (req.body?.direction === 'up' ? -1 : 1);
    const other = db.prepare('SELECT album_id FROM list_items WHERE list_id = ? AND position = ?').get(list.id, target);
    if (!other) return res.json({ ok: true, position: item.position });
    db.prepare('UPDATE list_items SET position = ? WHERE list_id = ? AND album_id = ?').run(item.position, list.id, other.album_id);
    db.prepare('UPDATE list_items SET position = ? WHERE list_id = ? AND album_id = ?').run(target, list.id, albumId);
    res.json({ ok: true, position: target });
  });

  // Inviter un ami à compléter la liste (amis seulement : abonnements réciproques).
  api.post('/lists/:id/collaborators', requireAuth, writeLimiter, (req, res) => {
    const list = ownList(req, res);
    if (!list) return;
    const u = q.user(String(req.body?.username || '').replace(/^@/, '').slice(0, 40));
    if (!u || u.suspended_at) return res.status(404).json({ error: 'Membre introuvable.' });
    if (u.id === req.user.id) return res.status(400).json({ error: "C'est déjà ta liste." });
    const friends = db.prepare(`SELECT 1 FROM follows a JOIN follows b ON b.follower_id = a.followee_id AND b.followee_id = a.follower_id
      WHERE a.follower_id = ? AND a.followee_id = ?`).get(req.user.id, u.id);
    if (!friends || blocked(req.user.id, u.id)) return res.status(403).json({ error: 'Tu ne peux inviter que tes amis (abonnements réciproques).' });
    const { n } = db.prepare('SELECT COUNT(*) n FROM list_collaborators WHERE list_id = ?').get(list.id);
    if (n >= 10) return res.status(400).json({ error: '10 invités maximum par liste.' });
    const { changes } = db.prepare('INSERT OR IGNORE INTO list_collaborators (list_id, user_id) VALUES (?, ?)').run(list.id, u.id);
    if (changes) notify({ to: u.id, actor: req.user.id, type: 'list_invite', listId: list.id, extra: list.title });
    res.json({ ok: true, collaborator: { username: u.username, displayName: u.display_name, avatar: avatarUrl(u.avatar) } });
  });

  // Retirer un invité (l'auteur), ou quitter la liste (l'invité lui-même).
  api.delete('/lists/:id/collaborators/:username', requireAuth, (req, res) => {
    const list = db.prepare('SELECT id, user_id FROM lists WHERE id = ?').get(Number(req.params.id));
    const u = q.user(req.params.username);
    if (!list || !u) return res.status(404).json({ error: 'Introuvable.' });
    if (list.user_id !== req.user.id && u.id !== req.user.id) return res.status(403).json({ error: 'Action impossible.' });
    db.prepare('DELETE FROM list_collaborators WHERE list_id = ? AND user_id = ?').run(list.id, u.id);
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
    const u = db.prepare('SELECT username, email, display_name, avatar, bio, email_verified_at, created_at FROM users WHERE id = ?').get(req.user.id);
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

  // ---------- Photo de profil ----------
  const avatarLimiter = limiter(60, 20, 'Trop de changements de photo : réessaie dans une heure.');
  const setAvatar = (userId, value) => {
    const { avatar: old } = db.prepare('SELECT avatar FROM users WHERE id = ?').get(userId);
    db.prepare('UPDATE users SET avatar = ? WHERE id = ?').run(value, userId);
    if (old !== value) removeAvatarFile(old);
  };

  // Photo importée : le corps de la requête est l'image elle-même (5 Mo au plus).
  api.post('/me/avatar', requireAuth, avatarLimiter,
    express.raw({ type: ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif', 'image/avif'], limit: '5mb' }),
    async (req, res) => {
      if (!Buffer.isBuffer(req.body) || !req.body.length) return res.status(400).json({ error: 'Choisis une image JPEG, PNG, WebP ou GIF.' });
      try {
        const value = await saveUpload(req.body);
        setAvatar(req.user.id, value);
        res.json({ avatar: avatarUrl(value) });
      } catch (err) {
        if (err.status === 400) return res.status(400).json({ error: err.message });
        throw err;
      }
    });

  // Pochette d'album choisie comme photo.
  api.put('/me/avatar', requireAuth, avatarLimiter, (req, res) => {
    const slug = typeof req.body?.album === 'string' ? req.body.album.slice(0, 200) : '';
    if (!q.albumId(slug)) return res.status(400).json({ error: 'Album introuvable.' });
    setAvatar(req.user.id, `c:${slug}`);
    res.json({ avatar: avatarUrl(`c:${slug}`) });
  });

  api.delete('/me/avatar', requireAuth, (req, res) => {
    setAvatar(req.user.id, null);
    res.json({ avatar: null });
  });

  // Résumé hebdomadaire par e-mail (consentement explicite, révocable à tout moment).
  api.put('/me/digest', requireAuth, (req, res) => {
    const enabled = req.body?.enabled === true;
    db.prepare('UPDATE users SET digest = ? WHERE id = ?').run(enabled ? 1 : 0, req.user.id);
    res.json({ enabled });
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
      account: db.prepare('SELECT username, email, display_name, avatar, bio, digest, email_verified_at, terms_accepted_at, created_at, utm_source, utm_medium, utm_campaign FROM users WHERE id = ?').get(id),
      albums: all('SELECT al.slug, al.title, s.rating, s.liked, s.listened, s.wishlist, s.updated_at FROM user_albums s JOIN albums al ON al.id = s.album_id WHERE s.user_id = ?'),
      diary: all('SELECT al.slug, al.title, r.rating, r.body, r.listened_on, r.created_at FROM reviews r JOIN albums al ON al.id = r.album_id WHERE r.user_id = ?'),
      favorites: all('SELECT al.slug, f.position FROM favorites f JOIN albums al ON al.id = f.album_id WHERE f.user_id = ?'),
      following: all('SELECT u.username FROM follows f JOIN users u ON u.id = f.followee_id WHERE f.follower_id = ?'),
      followers: all('SELECT u.username FROM follows f JOIN users u ON u.id = f.follower_id WHERE f.followee_id = ?'),
      lists: all('SELECT id, title, description, created_at FROM lists WHERE user_id = ?'),
      listsJoined: all('SELECT l.id, l.title, c.added_at FROM list_collaborators c JOIN lists l ON l.id = c.list_id WHERE c.user_id = ?'),
      badges: all('SELECT badge, earned_at FROM user_badges WHERE user_id = ?'),
      reviewLikes: all('SELECT review_id, created_at FROM review_likes WHERE user_id = ?'),
      blocked: all('SELECT u.username, b.created_at FROM blocks b JOIN users u ON u.id = b.blocked_id WHERE b.blocker_id = ?'),
      comments: all('SELECT review_id, body, created_at FROM comments WHERE user_id = ?'),
      messagesSent: all('SELECT u.username AS to_user, m.body, m.created_at FROM messages m JOIN users u ON u.id = m.recipient_id WHERE m.sender_id = ? AND m.sender_deleted = 0'),
      messagesReceived: all('SELECT u.username AS from_user, m.body, m.created_at, m.read_at FROM messages m JOIN users u ON u.id = m.sender_id WHERE m.recipient_id = ? AND m.recipient_deleted = 0'),
      notifications: all('SELECT type, created_at, read_at FROM notifications WHERE user_id = ?'),
      reportsMade: [
        ...all('SELECT review_id, reason, created_at FROM reports WHERE reporter_id = ?'),
        ...all('SELECT u.username AS profile, r.reason, r.created_at FROM user_reports r JOIN users u ON u.id = r.user_id WHERE r.reporter_id = ?'),
      ],
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
    // Les clés étrangères en cascade suppriment toutes les données liées ; la photo est effacée du disque.
    const { avatar } = db.prepare('SELECT avatar FROM users WHERE id = ?').get(req.user.id);
    db.prepare('DELETE FROM users WHERE id = ?').run(req.user.id);
    removeAvatarFile(avatar);
    destroySession(db, req, res);
    res.json({ ok: true });
  });

  // ---------- Administration (modération) ----------
  const mod = moderation(db);
  const reasonOf = (req, res) => validate(schemas.report, req, res)?.reason;
  const done = (res, ok) => (ok ? res.json({ ok: true }) : res.status(404).json({ error: 'Élément introuvable.' }));

  api.post('/admin/reviews/:id/hide', requireAdmin, (req, res) => {
    const reason = reasonOf(req, res);
    if (reason) done(res, mod.hideReview(req.user.id, Number(req.params.id), reason));
  });
  api.post('/admin/comments/:id/hide', requireAdmin, (req, res) => {
    const reason = reasonOf(req, res);
    if (reason) done(res, mod.hideComment(req.user.id, Number(req.params.id), reason));
  });
  api.post('/admin/messages/:id/delete', requireAdmin, (req, res) => {
    const reason = reasonOf(req, res);
    if (reason) done(res, mod.deleteMessage(req.user.id, Number(req.params.id), reason));
  });
  api.post('/admin/messages/:id/dismiss', requireAdmin, (req, res) => done(res, mod.dismissMessageReports(req.user.id, Number(req.params.id))));
  api.post('/admin/comments/:id/dismiss', requireAdmin, (req, res) => done(res, mod.dismissCommentReports(req.user.id, Number(req.params.id))));
  api.post('/admin/reviews/:id/restore', requireAdmin, (req, res) => done(res, mod.restoreReview(req.user.id, Number(req.params.id))));
  api.post('/admin/reviews/:id/dismiss', requireAdmin, (req, res) => done(res, mod.dismissReviewReports(req.user.id, Number(req.params.id))));
  api.post('/admin/users/:username/dismiss', requireAdmin, (req, res) => done(res, mod.dismissUserReports(req.user.id, req.params.username)));
  api.post('/admin/users/:username/clear', requireAdmin, (req, res) => done(res, mod.clearProfile(req.user.id, req.params.username)));
  api.post('/admin/users/:username/suspend', requireAdmin, (req, res) => {
    const reason = reasonOf(req, res);
    if (!reason) return;
    const result = mod.suspend(req.user.id, req.params.username, reason);
    if (result.error) return res.status(result.status).json({ error: result.error });
    res.json({ ok: true });
  });
  api.post('/admin/users/:username/unsuspend', requireAdmin, (req, res) => done(res, mod.unsuspend(req.user.id, req.params.username)));

  api.use((req, res) => res.status(404).json({ error: 'Route inconnue.' }));
  return api;
}
