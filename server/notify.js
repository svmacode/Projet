// Notifications internes au site : « X te suit », « vous êtes amis », « X a aimé ta chronique »,
// « X a commenté ta chronique ». Rien n'est envoyé par e-mail.
export function notifier(db) {
  const blocked = db.prepare(`SELECT 1 FROM blocks
    WHERE (blocker_id = ? AND blocked_id = ?) OR (blocker_id = ? AND blocked_id = ?)`);
  // Un même geste répété (aimer, ne plus aimer, aimer encore…) ne crée qu'une notification par jour.
  const recent = db.prepare(`SELECT 1 FROM notifications
    WHERE user_id = ? AND actor_id = ? AND type = ? AND IFNULL(review_id, 0) = ? AND created_at > datetime('now', '-1 day')`);
  const insert = db.prepare('INSERT INTO notifications (user_id, actor_id, type, review_id, comment_id) VALUES (?, ?, ?, ?, ?)');

  return function notify({ to, actor, type, reviewId = null, commentId = null }) {
    if (!to || !actor || to === actor) return;
    if (blocked.get(to, actor, actor, to)) return;
    if (type !== 'comment' && recent.get(to, actor, type, reviewId || 0)) return;
    insert.run(to, actor, type, reviewId, commentId);
  };
}
