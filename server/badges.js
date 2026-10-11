// Badges : récompenses débloquées par l'activité d'un membre. La progression est recalculée après chaque
// action utile (écoute, chronique, commentaire, abonnement…) ; un badge obtenu est gardé (avec sa date)
// et annoncé par une notification.
import { chartsQueries } from './charts.js';

export const BADGES = [
  { id: 'pionnier', emoji: '🚩', name: 'Pionnier', text: 'Faire partie des 100 premiers membres.', goal: 1, stat: 'pioneer' },
  { id: 'ecoute-1', emoji: '🎧', name: 'Première écoute', text: 'Marquer un premier album comme écouté.', goal: 1, stat: 'listened' },
  { id: 'ecoute-10', emoji: '👂', name: 'Oreille curieuse', text: 'Écouter 10 albums.', goal: 10, stat: 'listened' },
  { id: 'ecoute-50', emoji: '💿', name: 'Mélomane', text: 'Écouter 50 albums.', goal: 50, stat: 'listened' },
  { id: 'ecoute-100', emoji: '📚', name: 'Encyclopédie', text: 'Écouter 100 albums.', goal: 100, stat: 'listened' },
  { id: 'ecoute-250', emoji: '👑', name: 'Légende', text: 'Écouter 250 albums.', goal: 250, stat: 'listened' },
  { id: 'chronique-1', emoji: '✍️', name: 'Première plume', text: 'Publier une première chronique.', goal: 1, stat: 'reviews' },
  { id: 'chronique-10', emoji: '📝', name: 'Chroniqueur', text: 'Publier 10 chroniques.', goal: 10, stat: 'reviews' },
  { id: 'chronique-50', emoji: '🖋️', name: 'Critique', text: 'Publier 50 chroniques.', goal: 50, stat: 'reviews' },
  { id: 'decennies', emoji: '⏳', name: 'Voyageur du temps', text: 'Écouter des albums de 4 décennies différentes.', goal: 4, stat: 'decades' },
  { id: 'fidele', emoji: '🔁', name: 'Fidèle', text: "Écouter 5 albums d'un même artiste.", goal: 5, stat: 'sameArtist' },
  { id: 'coeur-10', emoji: '❤️', name: "Cœur d'artichaut", text: 'Donner 10 coups de cœur.', goal: 10, stat: 'liked' },
  { id: 'amis-5', emoji: '🤝', name: 'Bien entouré', text: 'Avoir 5 amis (abonnements réciproques).', goal: 5, stat: 'friends' },
  { id: 'aime-10', emoji: '⭐', name: 'Plume appréciée', text: "Recevoir 10 j'aime sur ses chroniques.", goal: 10, stat: 'likesReceived' },
  { id: 'bavard', emoji: '💬', name: 'Bavard', text: 'Écrire 10 commentaires.', goal: 10, stat: 'comments' },
  { id: 'curateur', emoji: '📋', name: 'Curateur', text: 'Créer 3 listes.', goal: 3, stat: 'lists' },
  { id: 'defi', emoji: '🏆', name: 'Défi relevé', text: 'Réussir un défi du mois.', goal: 1, stat: 'challenge' },
];
export const BADGE_NAMES = Object.fromEntries(BADGES.map((b) => [b.id, `${b.emoji} ${b.name}`]));

export function badgeEngine(db, notify) {
  const charts = chartsQueries(db);
  const one = (sql, ...args) => Object.values(db.prepare(sql).get(...args))[0];

  function stats(userId) {
    const c = charts.challenge(userId);
    return {
      pioneer: one('SELECT COUNT(*) FROM users WHERE id <= ?', userId) <= 100 ? 1 : 0,
      listened: one('SELECT COUNT(*) FROM user_albums WHERE user_id = ? AND listened = 1', userId),
      reviews: one("SELECT COUNT(*) FROM reviews WHERE user_id = ? AND body <> '' AND hidden_at IS NULL", userId),
      decades: one(`SELECT COUNT(DISTINCT al.year / 10) FROM user_albums s JOIN albums al ON al.id = s.album_id
        WHERE s.user_id = ? AND s.listened = 1`, userId),
      sameArtist: one(`SELECT IFNULL(MAX(n), 0) FROM (SELECT COUNT(*) AS n FROM user_albums s JOIN albums al ON al.id = s.album_id
        WHERE s.user_id = ? AND s.listened = 1 GROUP BY al.artist_id)`, userId),
      liked: one('SELECT COUNT(*) FROM user_albums WHERE user_id = ? AND liked = 1', userId),
      friends: one(`SELECT COUNT(*) FROM follows a JOIN follows b ON b.follower_id = a.followee_id AND b.followee_id = a.follower_id
        WHERE a.follower_id = ?`, userId),
      likesReceived: one('SELECT COUNT(*) FROM review_likes l JOIN reviews r ON r.id = l.review_id WHERE r.user_id = ?', userId),
      comments: one('SELECT COUNT(*) FROM comments WHERE user_id = ? AND hidden_at IS NULL', userId),
      lists: one('SELECT COUNT(*) FROM lists WHERE user_id = ?', userId),
      challenge: c.total && c.progress === c.total ? 1 : 0,
    };
  }

  const earnedOf = (userId) => new Map(db.prepare('SELECT badge, earned_at FROM user_badges WHERE user_id = ?').all(userId).map((r) => [r.badge, r.earned_at]));

  return {
    // Décerne les nouveaux badges et renvoie leur liste (pour un message « Nouveau badge ! »).
    check(userId) {
      if (!userId) return [];
      const s = stats(userId);
      const earned = earnedOf(userId);
      const fresh = BADGES.filter((b) => !earned.has(b.id) && s[b.stat] >= b.goal);
      const insert = db.prepare('INSERT OR IGNORE INTO user_badges (user_id, badge) VALUES (?, ?)');
      for (const b of fresh) {
        if (insert.run(userId, b.id).changes) notify?.({ to: userId, actor: userId, type: 'badge', extra: b.id });
      }
      return fresh.map((b) => ({ id: b.id, name: b.name, emoji: b.emoji }));
    },

    // Tous les badges, avec l'état et la progression du membre.
    all(userId) {
      const s = stats(userId);
      const earned = earnedOf(userId);
      return BADGES.map((b) => ({
        ...b, earnedAt: earned.get(b.id) || null,
        progress: Math.min(b.goal, earned.has(b.id) ? b.goal : s[b.stat]),
      }));
    },

    // Badges obtenus, du plus récent au plus ancien (vitrine du profil).
    earned(userId) {
      const earned = earnedOf(userId);
      return BADGES.filter((b) => earned.has(b.id))
        .map((b) => ({ ...b, earnedAt: earned.get(b.id) }))
        .sort((a, b) => b.earnedAt.localeCompare(a.earnedAt));
    },
  };
}
