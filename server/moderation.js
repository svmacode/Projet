// Modération : signalements à traiter et actions des administrateurs.
// Chaque action est inscrite au journal (mod_log), conservé un an : la loi (LCEN) demande de pouvoir
// montrer qu'un contenu signalé a été examiné et, si besoin, retiré promptement.
import { removeAvatarFile } from './avatars.js';
import { normalize } from './queries.js';

export function moderation(db) {
  const log = (adminId, action, target, detail = '') =>
    db.prepare('INSERT INTO mod_log (admin_id, action, target, detail) VALUES (?, ?, ?, ?)').run(adminId, action, target, detail);
  const member = (username) => db.prepare('SELECT id, username, display_name, avatar, bio, role, suspended_at FROM users WHERE username = ?').get(username);

  return {
    // Chroniques signalées, regroupées : une ligne par chronique, avec toutes les raisons.
    reviewReports() {
      return db.prepare(`
        SELECT r.id AS review_id, r.body, r.rating, r.hidden_at, r.created_at AS review_at,
          u.username AS author, u.display_name AS author_name, u.suspended_at AS author_suspended,
          al.slug AS album_slug, al.title AS album_title,
          COUNT(rep.id) AS count, MIN(rep.created_at) AS first_at,
          json_group_array(json_object('by', ru.username, 'reason', rep.reason, 'at', rep.created_at)) AS reasons
        FROM reports rep
        JOIN reviews r ON r.id = rep.review_id
        JOIN users u ON u.id = r.user_id
        JOIN albums al ON al.id = r.album_id
        JOIN users ru ON ru.id = rep.reporter_id
        WHERE rep.resolved_at IS NULL
        GROUP BY r.id ORDER BY count DESC, first_at ASC`).all()
        .map((row) => ({ ...row, reasons: JSON.parse(row.reasons) }));
    },

    // Profils signalés (photo, nom, bio).
    userReports() {
      return db.prepare(`
        SELECT u.username, u.display_name, u.avatar, u.bio, u.suspended_at,
          COUNT(rep.id) AS count, MIN(rep.created_at) AS first_at,
          json_group_array(json_object('by', ru.username, 'reason', rep.reason, 'at', rep.created_at)) AS reasons
        FROM user_reports rep
        JOIN users u ON u.id = rep.user_id
        JOIN users ru ON ru.id = rep.reporter_id
        WHERE rep.resolved_at IS NULL
        GROUP BY u.id ORDER BY count DESC, first_at ASC`).all()
        .map((row) => ({ ...row, reasons: JSON.parse(row.reasons) }));
    },

    // Commentaires signalés.
    commentReports() {
      return db.prepare(`
        SELECT c.id AS comment_id, c.body, c.created_at AS comment_at, c.review_id,
          u.username AS author, u.suspended_at AS author_suspended,
          COUNT(rep.id) AS count, MIN(rep.created_at) AS first_at,
          json_group_array(json_object('by', ru.username, 'reason', rep.reason, 'at', rep.created_at)) AS reasons
        FROM comment_reports rep
        JOIN comments c ON c.id = rep.comment_id
        JOIN users u ON u.id = c.user_id
        JOIN users ru ON ru.id = rep.reporter_id
        WHERE rep.resolved_at IS NULL
        GROUP BY c.id ORDER BY count DESC, first_at ASC`).all()
        .map((row) => ({ ...row, reasons: JSON.parse(row.reasons) }));
    },

    hideComment(adminId, commentId, reason) {
      const c = db.prepare('SELECT c.id, u.username FROM comments c JOIN users u ON u.id = c.user_id WHERE c.id = ?').get(commentId);
      if (!c) return false;
      db.prepare("UPDATE comments SET hidden_at = datetime('now') WHERE id = ?").run(commentId);
      db.prepare("UPDATE comment_reports SET resolved_at = datetime('now'), resolution = 'commentaire masqué' WHERE comment_id = ? AND resolved_at IS NULL").run(commentId);
      log(adminId, 'commentaire masqué', `commentaire ${commentId} de @${c.username}`, reason);
      return true;
    },

    dismissCommentReports(adminId, commentId) {
      const { changes } = db.prepare("UPDATE comment_reports SET resolved_at = datetime('now'), resolution = 'rejeté' WHERE comment_id = ? AND resolved_at IS NULL").run(commentId);
      if (changes) log(adminId, 'signalement rejeté', `commentaire ${commentId}`);
      return changes > 0;
    },

    journal(limit = 30) {
      return db.prepare(`
        SELECT l.action, l.target, l.detail, l.created_at, a.username AS admin
        FROM mod_log l LEFT JOIN users a ON a.id = l.admin_id ORDER BY l.id DESC LIMIT ?`).all(limit);
    },

    stats() {
      const one = (sql) => Object.values(db.prepare(sql).get())[0];
      return {
        members: one('SELECT COUNT(*) FROM users'),
        newThisWeek: one("SELECT COUNT(*) FROM users WHERE created_at > datetime('now', '-7 days')"),
        reviews: one("SELECT COUNT(*) FROM reviews WHERE body <> ''"),
        suspended: one('SELECT COUNT(*) FROM users WHERE suspended_at IS NOT NULL'),
        hidden: one('SELECT COUNT(*) FROM reviews WHERE hidden_at IS NOT NULL'),
      };
    },

    // Recherche de membres (y compris suspendus), avec leurs signalements passés.
    findMembers(text) {
      const words = normalize(text).split(' ').filter(Boolean);
      const rows = db.prepare(`
        SELECT u.username, u.display_name, u.avatar, u.bio, u.role, u.suspended_at, u.suspended_reason, u.created_at,
          (SELECT COUNT(*) FROM reviews WHERE user_id = u.id AND body <> '') AS reviews,
          (SELECT COUNT(*) FROM reports rep JOIN reviews r ON r.id = rep.review_id WHERE r.user_id = u.id) AS reported
        FROM users u ORDER BY u.created_at DESC`).all();
      const list = words.length ? rows.filter((u) => { const h = normalize(`${u.username} ${u.display_name}`); return words.every((w) => h.includes(w)); }) : rows;
      return list.slice(0, 30);
    },

    hideReview(adminId, reviewId, reason) {
      const r = db.prepare('SELECT r.id, u.username FROM reviews r JOIN users u ON u.id = r.user_id WHERE r.id = ?').get(reviewId);
      if (!r) return false;
      db.prepare("UPDATE reviews SET hidden_at = datetime('now'), hidden_reason = ? WHERE id = ?").run(reason, reviewId);
      db.prepare("UPDATE reports SET resolved_at = datetime('now'), resolution = 'chronique masquée' WHERE review_id = ? AND resolved_at IS NULL").run(reviewId);
      log(adminId, 'chronique masquée', `chronique ${reviewId} de @${r.username}`, reason);
      return true;
    },

    restoreReview(adminId, reviewId) {
      const r = db.prepare('SELECT r.id, u.username FROM reviews r JOIN users u ON u.id = r.user_id WHERE r.id = ?').get(reviewId);
      if (!r) return false;
      db.prepare('UPDATE reviews SET hidden_at = NULL, hidden_reason = NULL WHERE id = ?').run(reviewId);
      log(adminId, 'chronique rétablie', `chronique ${reviewId} de @${r.username}`);
      return true;
    },

    // Signalements jugés infondés : la chronique reste en ligne.
    dismissReviewReports(adminId, reviewId) {
      const { changes } = db.prepare("UPDATE reports SET resolved_at = datetime('now'), resolution = 'rejeté' WHERE review_id = ? AND resolved_at IS NULL").run(reviewId);
      if (changes) log(adminId, 'signalement rejeté', `chronique ${reviewId}`);
      return changes > 0;
    },

    dismissUserReports(adminId, username) {
      const u = member(username);
      if (!u) return false;
      db.prepare("UPDATE user_reports SET resolved_at = datetime('now'), resolution = 'rejeté' WHERE user_id = ? AND resolved_at IS NULL").run(u.id);
      log(adminId, 'signalement rejeté', `profil @${u.username}`);
      return true;
    },

    // Efface photo et bio, et remet le pseudo comme nom affiché.
    clearProfile(adminId, username) {
      const u = member(username);
      if (!u) return false;
      db.prepare('UPDATE users SET avatar = NULL, bio = \'\', display_name = username WHERE id = ?').run(u.id);
      removeAvatarFile(u.avatar);
      db.prepare("UPDATE user_reports SET resolved_at = datetime('now'), resolution = 'profil effacé' WHERE user_id = ? AND resolved_at IS NULL").run(u.id);
      log(adminId, 'profil effacé', `@${u.username}`, 'photo, nom affiché et bio');
      return true;
    },

    // Suspendre : connexion impossible, sessions fermées, profil et chroniques invisibles.
    suspend(adminId, username, reason) {
      const u = member(username);
      if (!u) return { error: 'Membre introuvable.', status: 404 };
      if (u.id === adminId) return { error: 'Tu ne peux pas suspendre ton propre compte.', status: 400 };
      if (u.role === 'admin') return { error: 'Retire d\'abord son rôle d\'administrateur (npm run admin).', status: 400 };
      db.prepare("UPDATE users SET suspended_at = datetime('now'), suspended_reason = ? WHERE id = ?").run(reason, u.id);
      db.prepare('DELETE FROM sessions WHERE user_id = ?').run(u.id);
      db.prepare("UPDATE user_reports SET resolved_at = datetime('now'), resolution = 'compte suspendu' WHERE user_id = ? AND resolved_at IS NULL").run(u.id);
      db.prepare(`UPDATE reports SET resolved_at = datetime('now'), resolution = 'compte suspendu'
        WHERE resolved_at IS NULL AND review_id IN (SELECT id FROM reviews WHERE user_id = ?)`).run(u.id);
      db.prepare(`UPDATE comment_reports SET resolved_at = datetime('now'), resolution = 'compte suspendu'
        WHERE resolved_at IS NULL AND comment_id IN (SELECT id FROM comments WHERE user_id = ?)`).run(u.id);
      log(adminId, 'compte suspendu', `@${u.username}`, reason);
      return { ok: true };
    },

    unsuspend(adminId, username) {
      const u = member(username);
      if (!u) return false;
      db.prepare('UPDATE users SET suspended_at = NULL, suspended_reason = NULL WHERE id = ?').run(u.id);
      log(adminId, 'compte réactivé', `@${u.username}`);
      return true;
    },

    counts() {
      const one = (sql) => Object.values(db.prepare(sql).get())[0];
      return one('SELECT COUNT(DISTINCT review_id) FROM reports WHERE resolved_at IS NULL')
        + one('SELECT COUNT(DISTINCT user_id) FROM user_reports WHERE resolved_at IS NULL')
        + one('SELECT COUNT(DISTINCT comment_id) FROM comment_reports WHERE resolved_at IS NULL');
    },
  };
}
