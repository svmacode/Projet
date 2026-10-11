// Messages privés : seulement entre amis (abonnements réciproques), jamais entre membres qui se
// bloquent. Les administrateurs ne voient un message que s'il leur est signalé par son destinataire.
export function messaging(db) {
  const friends = db.prepare(`SELECT 1 FROM follows a JOIN follows b ON b.follower_id = a.followee_id AND b.followee_id = a.follower_id
    WHERE a.follower_id = ? AND a.followee_id = ?`);
  const blocked = db.prepare('SELECT 1 FROM blocks WHERE (blocker_id = ? AND blocked_id = ?) OR (blocker_id = ? AND blocked_id = ?)');
  // Messages visibles par `me` (sa copie n'est pas effacée).
  const MINE = '((m.sender_id = :me AND m.sender_deleted = 0) OR (m.recipient_id = :me AND m.recipient_deleted = 0))';

  return {
    canMessage(a, b) {
      return Boolean(a !== b && friends.get(a, b) && !blocked.get(a, b, b, a));
    },

    // Une ligne par conversation : dernier message, nombre de non lus.
    conversations(me) {
      return db.prepare(`
        SELECT u.username, u.display_name, u.avatar, m.body AS last, m.created_at AS at, m.sender_id = :me AS mine,
          (SELECT COUNT(*) FROM messages x WHERE x.sender_id = u.id AND x.recipient_id = :me AND x.read_at IS NULL AND x.recipient_deleted = 0) AS unread
        FROM messages m
        JOIN users u ON u.id = CASE WHEN m.sender_id = :me THEN m.recipient_id ELSE m.sender_id END
        WHERE m.id IN (
          SELECT MAX(m.id) FROM messages m WHERE ${MINE}
          GROUP BY CASE WHEN m.sender_id = :me THEN m.recipient_id ELSE m.sender_id END)
          AND u.suspended_at IS NULL
        ORDER BY m.id DESC`).all({ me });
    },

    // Fil d'une conversation (les 200 derniers messages, ou ceux après `after`).
    thread(me, peer, after = 0) {
      return db.prepare(`
        SELECT m.id, m.body, m.created_at, m.read_at, m.sender_id = :me AS mine FROM messages m
        WHERE ((m.sender_id = :me AND m.recipient_id = :peer) OR (m.sender_id = :peer AND m.recipient_id = :me))
          AND ${MINE} AND m.id > :after
        ORDER BY m.id DESC LIMIT 200`).all({ me, peer, after }).reverse();
    },

    markRead(me, peer) {
      db.prepare("UPDATE messages SET read_at = datetime('now') WHERE sender_id = ? AND recipient_id = ? AND read_at IS NULL").run(peer, me);
    },

    unread(me) {
      return db.prepare(`SELECT COUNT(*) AS n FROM messages m JOIN users u ON u.id = m.sender_id
        WHERE m.recipient_id = ? AND m.read_at IS NULL AND m.recipient_deleted = 0 AND u.suspended_at IS NULL`).get(me).n;
    },

    send(from, to, body) {
      const { lastInsertRowid } = db.prepare('INSERT INTO messages (sender_id, recipient_id, body) VALUES (?, ?, ?)').run(from, to, body);
      return db.prepare('SELECT id, body, created_at, 1 AS mine FROM messages WHERE id = ?').get(lastInsertRowid);
    },

    // Efface la copie de `me` ; le message disparaît de la base quand les deux copies sont effacées.
    remove(me, id) {
      const m = db.prepare('SELECT sender_id, recipient_id FROM messages WHERE id = ?').get(id);
      if (!m || (m.sender_id !== me && m.recipient_id !== me)) return false;
      db.prepare(`UPDATE messages SET ${m.sender_id === me ? 'sender_deleted' : 'recipient_deleted'} = 1 WHERE id = ?`).run(id);
      db.prepare('DELETE FROM messages WHERE id = ? AND sender_deleted = 1 AND recipient_deleted = 1').run(id);
      return true;
    },

    // Seul le destinataire peut signaler un message reçu.
    report(me, id, reason) {
      const m = db.prepare('SELECT recipient_id FROM messages WHERE id = ?').get(id);
      if (!m || m.recipient_id !== me) return false;
      db.prepare(`INSERT INTO message_reports (reporter_id, message_id, reason) VALUES (?, ?, ?)
        ON CONFLICT(reporter_id, message_id) DO UPDATE SET reason = excluded.reason, created_at = datetime('now'), resolved_at = NULL, resolution = NULL`)
        .run(me, id, reason);
      return true;
    },
  };
}
