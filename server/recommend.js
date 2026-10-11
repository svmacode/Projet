// Recommandations « Pour toi », album du jour et album au hasard.
// Tout est calculé à partir de l'activité sur le site : les albums aimés par les membres que tu suis,
// tes rappeurs préférés et ta décennie favorite. Chaque suggestion dit pourquoi elle est là.
import { ALBUM_SELECT, albumView } from './queries.js';

// Même graine → même album pour tout le monde ce jour-là.
function dayIndex(date = new Date(), modulo = 1) {
  const key = Number(date.toISOString().slice(0, 10).replace(/-/g, ''));
  let h = key;
  h = Math.imul(h ^ (h >>> 16), 2246822507);
  h = Math.imul(h ^ (h >>> 13), 3266489909);
  return ((h ^ (h >>> 16)) >>> 0) % modulo;
}

export function recommender(db) {
  const notHeard = 'NOT EXISTS (SELECT 1 FROM user_albums x WHERE x.user_id = ? AND x.album_id = al.id AND x.listened = 1)';

  return {
    forYou(userId, limit = 12) {
      const picks = new Map(); // slug → { album, score, reason }
      const add = (rows, score, reason) => {
        for (const row of rows) {
          const cur = picks.get(row.slug);
          if (cur) { cur.score += score; continue; }
          picks.set(row.slug, { album: albumView(row), score, reason: reason(row) });
        }
      };
      // 1. Ce que tes abonnements ont adoré (note ≥ 4/5 ou coup de cœur).
      add(db.prepare(`${ALBUM_SELECT.replace('SELECT al.slug', 'SELECT u.display_name AS fan, al.slug')}
        JOIN user_albums s ON s.album_id = al.id JOIN users u ON u.id = s.user_id
        WHERE s.user_id IN (SELECT followee_id FROM follows WHERE follower_id = ?) AND (s.rating >= 8 OR s.liked = 1)
          AND u.suspended_at IS NULL AND ${notHeard}
        ORDER BY s.rating DESC, s.updated_at DESC LIMIT 40`).all(userId, userId), 2, (r) => `Adoré par ${r.fan}`);
      // 2. D'autres albums de tes rappeurs les plus écoutés.
      add(db.prepare(`${ALBUM_SELECT} WHERE al.artist_id IN (
          SELECT a2.artist_id FROM user_albums s2 JOIN albums a2 ON a2.id = s2.album_id
          WHERE s2.user_id = ? AND s2.listened = 1 GROUP BY a2.artist_id ORDER BY COUNT(*) DESC LIMIT 5)
        AND ${notHeard} ORDER BY al.curated DESC, ratings DESC LIMIT 30`).all(userId, userId), 1.5, (r) => `Tu écoutes ${r.artist_name}`);
      // 3. Des classiques de ta décennie préférée.
      const fav = db.prepare(`SELECT al.year / 10 * 10 AS d FROM user_albums s JOIN albums al ON al.id = s.album_id
        WHERE s.user_id = ? AND s.listened = 1 GROUP BY d ORDER BY COUNT(*) DESC LIMIT 1`).get(userId);
      if (fav) {
        add(db.prepare(`${ALBUM_SELECT} WHERE al.curated = 1 AND al.year BETWEEN ? AND ? AND ${notHeard}
          ORDER BY ratings DESC, al.year LIMIT 20`).all(fav.d, fav.d + 9, userId), 0.8, () => `Un classique des années ${fav.d}`);
      }
      // 4. À défaut : les classiques les mieux notés que tu n'as pas encore écoutés.
      if (picks.size < limit) {
        add(db.prepare(`${ALBUM_SELECT} WHERE al.curated = 1 AND ${notHeard} ORDER BY ratings DESC, al.year LIMIT ?`)
          .all(userId, limit * 2), 0.3, () => 'Un incontournable');
      }
      return [...picks.values()].sort((a, b) => b.score - a.score).slice(0, limit)
        .map((p) => ({ ...p.album, reason: p.reason }));
    },

    // Album du jour : un classique de la sélection éditoriale, le même pour tous.
    albumOfDay(date = new Date()) {
      const rows = db.prepare(`${ALBUM_SELECT} WHERE al.curated = 1 ORDER BY al.id`).all();
      if (!rows.length) return null;
      return albumView(rows[dayIndex(date, rows.length)]);
    },

    // Album au hasard : dans « À écouter » du membre s'il le demande, sinon dans tout le catalogue.
    random(userId = 0, { wishlist = false } = {}) {
      const row = wishlist && userId
        ? db.prepare('SELECT al.slug FROM user_albums s JOIN albums al ON al.id = s.album_id WHERE s.user_id = ? AND s.wishlist = 1 ORDER BY RANDOM() LIMIT 1').get(userId)
        : db.prepare('SELECT slug FROM albums ORDER BY RANDOM() LIMIT 1').get();
      return row?.slug || null;
    },
  };
}
