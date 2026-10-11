// Statistiques d'un membre et bilan de l'année (sur le modèle du « Year in Review » de Letterboxd).
// Tout est calculé à la volée depuis son journal d'écoute : rien de plus n'est stocké.
import { ALBUM_SELECT, albumView } from './queries.js';

export function statsQueries(db) {
  const all = (sql, ...args) => db.prepare(sql).all(...args);
  const one = (sql, ...args) => db.prepare(sql).get(...args);

  return {
    // Statistiques de toujours.
    overview(userId) {
      const totals = one(`SELECT
          (SELECT COUNT(*) FROM user_albums WHERE user_id = ? AND listened = 1) AS listened,
          (SELECT COUNT(*) FROM user_albums WHERE user_id = ? AND liked = 1) AS liked,
          (SELECT COUNT(*) FROM reviews WHERE user_id = ? AND body <> '' AND hidden_at IS NULL) AS reviews,
          (SELECT ROUND(AVG(rating), 1) FROM user_albums WHERE user_id = ? AND rating IS NOT NULL) AS avg,
          (SELECT COUNT(*) FROM user_albums WHERE user_id = ? AND rating IS NOT NULL) AS rated`, userId, userId, userId, userId, userId);
      const ratings = Array(10).fill(0);
      for (const r of all('SELECT rating, COUNT(*) n FROM user_albums WHERE user_id = ? AND rating IS NOT NULL GROUP BY rating', userId)) ratings[r.rating - 1] = r.n;
      return {
        totals,
        ratings,
        // Par année d'écoute (journal).
        byYear: all(`SELECT substr(listened_on, 1, 4) AS year, COUNT(DISTINCT album_id) AS n FROM reviews
          WHERE user_id = ? GROUP BY year ORDER BY year`, userId),
        // Par décennie de sortie des albums écoutés.
        byDecade: all(`SELECT (al.year / 10) * 10 AS decade, COUNT(*) AS n FROM user_albums s JOIN albums al ON al.id = s.album_id
          WHERE s.user_id = ? AND s.listened = 1 GROUP BY decade ORDER BY decade`, userId),
        topArtists: all(`SELECT ar.slug, ar.name, COUNT(*) AS n, ROUND(AVG(s.rating), 1) AS avg FROM user_albums s
          JOIN albums al ON al.id = s.album_id JOIN artists ar ON ar.id = al.artist_id
          WHERE s.user_id = ? AND s.listened = 1 GROUP BY ar.id ORDER BY n DESC, avg DESC LIMIT 10`, userId),
        topRated: all(`${ALBUM_SELECT} JOIN user_albums s ON s.album_id = al.id
          WHERE s.user_id = ? AND s.rating IS NOT NULL ORDER BY s.rating DESC, s.updated_at DESC LIMIT 8`, userId).map(albumView),
      };
    },

    // Années pour lesquelles un bilan existe.
    years(userId) {
      return all("SELECT DISTINCT substr(listened_on, 1, 4) AS year FROM reviews WHERE user_id = ? ORDER BY year DESC", userId).map((r) => r.year);
    },

    // Bilan d'une année : écoutes datées de cette année dans le journal.
    year(userId, year) {
      const y = String(year);
      const entries = all(`SELECT r.id, r.rating, r.body, r.listened_on, al.slug, al.year AS album_year, ar.slug AS artist_slug, ar.name AS artist_name
        FROM reviews r JOIN albums al ON al.id = r.album_id JOIN artists ar ON ar.id = al.artist_id
        WHERE r.user_id = ? AND substr(r.listened_on, 1, 4) = ? AND r.hidden_at IS NULL ORDER BY r.listened_on`, userId, y);
      if (!entries.length) return null;
      const albums = new Set(entries.map((e) => e.slug));
      const rated = entries.filter((e) => e.rating);
      const count = (key) => Object.entries(entries.reduce((m, e) => ({ ...m, [key(e)]: (m[key(e)] || 0) + 1 }), {})).sort((a, b) => b[1] - a[1]);
      const months = Array(12).fill(0);
      for (const e of entries) months[Number(e.listened_on.slice(5, 7)) - 1] += 1;
      const byArtist = count((e) => `${e.artist_slug}|${e.artist_name}`).slice(0, 5).map(([k, n]) => ({ slug: k.split('|')[0], name: k.split('|')[1], n }));
      const decade = count((e) => Math.floor(e.album_year / 10) * 10)[0];
      const best = [...rated].sort((a, b) => b.rating - a.rating || a.listened_on.localeCompare(b.listened_on))
        .filter((e, i, list) => list.findIndex((x) => x.slug === e.slug) === i).slice(0, 5);
      const album = (slug) => albumView(db.prepare(`${ALBUM_SELECT} WHERE al.slug = ?`).get(slug));
      const longest = entries.filter((e) => e.body).sort((a, b) => b.body.length - a.body.length)[0];
      return {
        year: y,
        albums: albums.size,
        reviews: entries.filter((e) => e.body).length,
        avg: rated.length ? Math.round((rated.reduce((s, e) => s + e.rating, 0) / rated.length) * 10) / 10 : null,
        months,
        topMonth: months.indexOf(Math.max(...months)),
        artists: byArtist,
        decade: decade ? { decade: Number(decade[0]), n: decade[1] } : null,
        best: best.map((e) => ({ album: album(e.slug), rating: e.rating })),
        longest: longest ? { id: longest.id, words: longest.body.trim().split(/\s+/).length, album: album(longest.slug) } : null,
        first: { album: album(entries[0].slug), date: entries[0].listened_on },
        last: { album: album(entries.at(-1).slug), date: entries.at(-1).listened_on },
        oldest: album([...entries].sort((a, b) => a.album_year - b.album_year)[0].slug),
      };
    },
  };
}
