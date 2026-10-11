// Résumé hebdomadaire par e-mail : seulement pour les membres qui l'ont demandé (paramètres),
// seulement si un service d'e-mail est configuré, le lundi. Lien de désabonnement en un clic, signé.
import crypto from 'node:crypto';
import { config } from './config.js';
import { sendMail, mailEnabled } from './mailer.js';
import { chartsQueries } from './charts.js';
import { recommender } from './recommend.js';

const sign = (userId) => crypto.createHmac('sha256', config.secret).update(`digest:${userId}`).digest('base64url').slice(0, 24);

export function unsubscribeUrl(userId) {
  return `${config.publicUrl}/desabonnement?u=${userId}&t=${sign(userId)}`;
}

export function checkUnsubscribe(userId, token) {
  const expected = sign(userId);
  return typeof token === 'string' && token.length === expected.length
    && crypto.timingSafeEqual(Buffer.from(token), Buffer.from(expected));
}

export function digestText(db, user) {
  const charts = chartsQueries(db);
  const unread = db.prepare('SELECT COUNT(*) AS n FROM notifications WHERE user_id = ? AND read_at IS NULL').get(user.id).n;
  const reviews = db.prepare(`SELECT u.display_name, al.title, r.rating FROM reviews r
    JOIN users u ON u.id = r.user_id JOIN albums al ON al.id = r.album_id
    WHERE r.user_id IN (SELECT followee_id FROM follows WHERE follower_id = ?) AND r.created_at >= datetime('now', '-7 days')
      AND r.hidden_at IS NULL AND u.suspended_at IS NULL ORDER BY r.created_at DESC LIMIT 5`).all(user.id);
  const c = charts.challenge(user.id);
  const picks = recommender(db).forYou(user.id, 3);
  const lines = [`Salut ${user.display_name},`, '', 'Ta semaine sur MyRapFr :', ''];
  if (unread) lines.push(`• ${unread} notification${unread > 1 ? 's' : ''} non lue${unread > 1 ? 's' : ''} : ${config.publicUrl}/notifications`);
  if (reviews.length) {
    lines.push('• Tes amis ont écouté :');
    for (const r of reviews) lines.push(`   – ${r.display_name} : ${r.title}${r.rating ? ` (${r.rating / 2}/5)` : ''}`);
  }
  lines.push(`• Défi du mois « ${c.title} » : ${c.progress}/${c.total} albums écoutés — ${config.publicUrl}/defi`);
  if (picks.length) {
    lines.push('• À écouter cette semaine :');
    for (const a of picks) lines.push(`   – ${a.title} de ${a.artist.name} (${a.reason}) : ${config.publicUrl}/album/${a.slug}`);
  }
  lines.push('', `Ton fil d'actu : ${config.publicUrl}/fil`, '', `Ne plus recevoir ce résumé : ${unsubscribeUrl(user.id)}`);
  return lines.join('\n');
}

// Vérifie toutes les heures ; envoie le lundi, au plus une fois tous les 6 jours par membre.
export function startDigest(db) {
  if (!mailEnabled || config.isTest) return;
  const run = async () => {
    if (new Date().getDay() !== 1) return;
    const users = db.prepare(`SELECT id, email, display_name FROM users
      WHERE digest = 1 AND email_verified_at IS NOT NULL AND suspended_at IS NULL
        AND (digest_sent_at IS NULL OR digest_sent_at < datetime('now', '-6 days')) LIMIT 200`).all();
    for (const user of users) {
      await sendMail({ to: user.email, subject: 'Ta semaine sur MyRapFr', text: digestText(db, user) });
      db.prepare("UPDATE users SET digest_sent_at = datetime('now') WHERE id = ?").run(user.id);
    }
    if (users.length) console.log(`[e-mail] Résumé hebdomadaire envoyé à ${users.length} membre(s).`);
  };
  setTimeout(run, 60_000).unref();
  setInterval(run, 3600_000).unref();
}
