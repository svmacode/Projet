// Classements (albums les mieux notés, les plus écoutés, chroniques les plus aimées, membres actifs)
// et défi d'écoute du mois.
import { ALBUM_SELECT, albumView } from './queries.js';

// Thèmes du défi, un par mois, dans cet ordre (puis on recommence).
const THEMES = [
  { id: 'fondations', title: 'Les fondations', text: 'Six albums des années 1990, quand tout a commencé.', where: 'al.year BETWEEN 1990 AND 1999' },
  { id: 'marseille', title: 'Marseille', text: 'Six disques de la ville qui a donné IAM, la Fonky Family et Jul.', where: "ar.origin LIKE '%Marseille%'" },
  { id: 'annees-2000', title: 'Les années 2000', text: 'Rue, mixtapes et premiers disques d\'or : six albums de la décennie.', where: 'al.year BETWEEN 2000 AND 2009' },
  { id: 'belgique', title: 'La vague belge', text: 'Six projets venus de Bruxelles et d\'ailleurs en Belgique.', where: "ar.origin LIKE '%Bruxelles%' OR ar.origin LIKE '%Belgique%' OR ar.origin LIKE '%Liège%'" },
  { id: 'annees-2010', title: 'La décennie streaming', text: 'Trap, mélodies et indépendance : six albums des années 2010.', where: 'al.year BETWEEN 2010 AND 2019' },
  { id: 'banlieue-nord', title: 'Le 93 et le 95', text: 'Six albums de Seine-Saint-Denis et du Val-d\'Oise.', where: "ar.origin IN ('Saint-Denis', 'Sevran', 'Sarcelles', 'Villiers-le-Bel', 'Aulnay-sous-Bois', 'Garges-lès-Gonesse', 'Montreuil', 'Bobigny', 'Épinay-sur-Seine')" },
  { id: 'aujourdhui', title: 'Le rap d\'aujourd\'hui', text: 'Six albums sortis depuis 2020.', where: 'al.year >= 2020' },
  { id: 'premiers', title: 'Premiers pas', text: 'Six premiers albums devenus des références.', where: 'al.id IN (SELECT MIN(a2.id) FROM albums a2 WHERE a2.curated = 1 GROUP BY a2.artist_id)' },
];

// Petit générateur pseudo-aléatoire stable : même mois → mêmes albums pour tout le monde.
function seeded(seed) {
  let s = seed >>> 0;
  return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 2 ** 32; };
}

export function chartsQueries(db) {
  const visible = 'r.hidden_at IS NULL AND u.suspended_at IS NULL';

  return {
    // Classement « mieux notés » : moyenne bayésienne (un album noté 10 par une seule personne ne passe
    // pas devant un album noté 9 par cinquante).
    topRated(limit = 30) {
      const { c } = db.prepare('SELECT AVG(rating) AS c FROM user_albums WHERE rating IS NOT NULL').get();
      const prior = c || 6;
      const m = 3;
      return db.prepare(`${ALBUM_SELECT} WHERE st.ratings > 0
        ORDER BY (st.ratings * st.avg_rating + ? * ?) / (st.ratings + ?) DESC, st.ratings DESC LIMIT ?`)
        .all(m, prior, m, limit).map(albumView);
    },

    // Les plus écoutés sur une période (journal d'écoute), avec le nombre de membres.
    trending(days = 7, limit = 12) {
      return db.prepare(`${ALBUM_SELECT} JOIN (
          SELECT r.album_id, COUNT(DISTINCT r.user_id) AS listeners FROM reviews r JOIN users u ON u.id = r.user_id
          WHERE r.listened_on >= date('now', ?) AND u.suspended_at IS NULL GROUP BY r.album_id) t ON t.album_id = al.id
        ORDER BY t.listeners DESC, ratings DESC LIMIT ?`).all(`-${days} days`, limit)
        .map((row) => ({ ...albumView(row), listeners: row.listeners }));
    },

    // Chroniques les plus aimées des 30 derniers jours.
    topReviews(viewerId = 0, limit = 6) {
      return db.prepare(`
        SELECT r.id, r.rating, r.body, r.listened_on, r.created_at, u.username, u.display_name, u.avatar, al.slug,
          (SELECT COUNT(*) FROM review_likes WHERE review_id = r.id) AS likes,
          EXISTS(SELECT 1 FROM review_likes WHERE review_id = r.id AND user_id = ?) AS liked_by_me,
          (SELECT COUNT(*) FROM comments c WHERE c.review_id = r.id AND c.hidden_at IS NULL) AS comments
        FROM reviews r JOIN users u ON u.id = r.user_id JOIN albums al ON al.id = r.album_id
        WHERE r.body <> '' AND ${visible} AND r.created_at >= datetime('now', '-30 days')
          AND NOT EXISTS (SELECT 1 FROM blocks WHERE (blocker_id = ? AND blocked_id = u.id) OR (blocker_id = u.id AND blocked_id = ?))
        ORDER BY likes DESC, r.created_at DESC LIMIT ?`).all(viewerId, viewerId, viewerId, limit);
    },

    // Membres les plus actifs du mois (nombre d'écoutes datées dans le journal).
    activeMembers(limit = 10) {
      return db.prepare(`
        SELECT u.username, u.display_name, u.avatar, COUNT(*) AS n,
          SUM(r.body <> '') AS reviews
        FROM reviews r JOIN users u ON u.id = r.user_id
        WHERE r.listened_on >= date('now', '-30 days') AND u.suspended_at IS NULL
        GROUP BY u.id ORDER BY n DESC, reviews DESC LIMIT ?`).all(limit);
    },

    // Défi du mois : thème et six albums, identiques pour tous les membres pendant le mois.
    challenge(viewerId = 0, date = new Date()) {
      const month = date.getUTCFullYear() * 12 + date.getUTCMonth();
      let theme = THEMES[month % THEMES.length];
      let pool = db.prepare(`${ALBUM_SELECT} WHERE (${theme.where}) AND al.curated = 1 ORDER BY al.id`).all().map(albumView);
      if (pool.length < 6) { // catalogue trop petit pour ce thème : on prend le premier thème qui convient
        theme = THEMES.find((t) => db.prepare(`SELECT COUNT(*) n FROM albums al JOIN artists ar ON ar.id = al.artist_id WHERE (${t.where}) AND al.curated = 1`).get().n >= 6) || THEMES[0];
        pool = db.prepare(`${ALBUM_SELECT} WHERE (${theme.where}) AND al.curated = 1 ORDER BY al.id`).all().map(albumView);
      }
      const random = seeded(month * 7919);
      const albums = [];
      while (albums.length < Math.min(6, pool.length)) {
        const pick = pool[Math.floor(random() * pool.length)];
        if (!albums.includes(pick)) albums.push(pick);
      }
      const slugs = albums.map((a) => a.slug);
      const marks = slugs.map(() => '?').join(',');
      const done = viewerId ? new Set(db.prepare(`SELECT al.slug FROM user_albums s JOIN albums al ON al.id = s.album_id
        WHERE s.user_id = ? AND s.listened = 1 AND al.slug IN (${marks})`).all(viewerId, ...slugs).map((r) => r.slug)) : new Set();
      const finishers = db.prepare(`SELECT COUNT(*) AS n FROM (SELECT s.user_id FROM user_albums s JOIN albums al ON al.id = s.album_id
        WHERE s.listened = 1 AND al.slug IN (${marks}) GROUP BY s.user_id HAVING COUNT(*) = ?)`).get(...slugs, slugs.length).n;
      const end = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 1));
      return {
        id: theme.id, title: theme.title, text: theme.text,
        month: date.toLocaleDateString('fr-FR', { month: 'long', year: 'numeric', timeZone: 'UTC' }),
        daysLeft: Math.max(1, Math.ceil((end - date) / 86_400_000)),
        albums: albums.map((a) => ({ ...a, done: done.has(a.slug) })),
        progress: done.size, total: albums.length, finishers,
      };
    },
  };
}
