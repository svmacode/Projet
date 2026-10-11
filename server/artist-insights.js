// Fiche rappeur enrichie : chiffres des membres, fans, artistes que les fans écoutent aussi,
// et (depuis Deezer, gardés 30 jours) artistes similaires et featurings fréquents.
import { ALBUM_SELECT, albumView } from './queries.js';
import { loadCatalog, normName } from './catalog.js';
import { pace } from './pacing.js';

async function deezer(path) {
  const url = `https://api.deezer.com${path}`;
  await pace(url);
  const res = await fetch(url, { headers: { Accept: 'application/json' }, signal: AbortSignal.timeout(6000) });
  if (!res.ok) return null;
  const data = await res.json().catch(() => null);
  return data?.error ? null : data;
}

export function artistInsights(db) {
  return {
    community(slug) {
      const base = db.prepare('SELECT id FROM artists WHERE slug = ?').get(slug);
      if (!base) return null;
      const one = (sql) => db.prepare(sql).get(base.id);
      const totals = one(`SELECT COUNT(DISTINCT s.user_id) AS fanCount, ROUND(AVG(s.rating), 1) AS avg, COUNT(s.rating) AS ratings
        FROM user_albums s JOIN albums al ON al.id = s.album_id JOIN users u ON u.id = s.user_id
        WHERE al.artist_id = ? AND (s.listened = 1 OR s.rating IS NOT NULL) AND u.suspended_at IS NULL`);
      const best = db.prepare(`${ALBUM_SELECT} WHERE al.artist_id = ? AND st.ratings > 0 ORDER BY st.avg_rating DESC, st.ratings DESC LIMIT 1`).get(base.id);
      const most = db.prepare(`${ALBUM_SELECT.replace('SELECT al.slug', 'SELECT (SELECT COUNT(*) FROM user_albums x WHERE x.album_id = al.id AND x.listened = 1) AS listens, al.slug')}
        WHERE al.artist_id = ? ORDER BY listens DESC LIMIT 1`).get(base.id);
      const fans = db.prepare(`SELECT u.username, u.display_name, u.avatar, COUNT(*) AS n FROM user_albums s
        JOIN albums al ON al.id = s.album_id JOIN users u ON u.id = s.user_id
        WHERE al.artist_id = ? AND s.listened = 1 AND u.suspended_at IS NULL
        GROUP BY u.id ORDER BY n DESC, MAX(s.updated_at) DESC LIMIT 8`).all(base.id);
      // Les autres artistes les plus écoutés par les fans de celui-ci.
      const also = db.prepare(`SELECT ar.slug, ar.name, COUNT(DISTINCT s2.user_id) AS n FROM user_albums s2
        JOIN albums a2 ON a2.id = s2.album_id JOIN artists ar ON ar.id = a2.artist_id
        WHERE s2.listened = 1 AND a2.artist_id <> ? AND s2.user_id IN (
          SELECT s.user_id FROM user_albums s JOIN albums al ON al.id = s.album_id WHERE al.artist_id = ? AND s.listened = 1)
        GROUP BY ar.id ORDER BY n DESC, ar.name LIMIT 8`).all(base.id, base.id);
      return {
        ...totals,
        best: best ? albumView(best) : null,
        most: most?.listens ? { ...albumView(most), listens: most.listens } : null,
        fans, also,
      };
    },

    // Artistes similaires (seulement ceux présents sur le site, pour que les liens marchent) et featurings.
    async extra(slug) {
      const base = db.prepare('SELECT id, name FROM artists WHERE slug = ?').get(slug);
      if (!base) return null;
      const row = db.prepare("SELECT data, fetched_at > datetime('now', '-30 days') AS fresh FROM artist_extra WHERE artist_id = ?").get(base.id);
      if (row?.fresh && row.data) return JSON.parse(row.data);
      const catalog = loadCatalog();
      const deezerId = catalog.artists.find((a) => a.slug === slug)?.deezerId;
      if (!deezerId) return { similar: [], featurings: [] };
      const known = new Map(catalog.artists.map((a) => [normName(a.name), a]));
      const related = (await deezer(`/artist/${deezerId}/related?limit=40`))?.data || [];
      const top = (await deezer(`/artist/${deezerId}/top?limit=50`))?.data || [];
      const similar = related.map((r) => known.get(normName(r.name))).filter(Boolean).slice(0, 10).map((a) => ({ slug: a.slug, name: a.name }));
      const counts = new Map();
      for (const t of top) {
        for (const c of t.contributors || []) {
          if (normName(c.name) === normName(base.name)) continue;
          counts.set(c.name, (counts.get(c.name) || 0) + 1);
        }
      }
      const featurings = [...counts].sort((a, b) => b[1] - a[1]).slice(0, 10).map(([name, n]) => {
        const a = known.get(normName(name));
        return { name, n, slug: a?.slug || null };
      });
      const data = { similar, featurings };
      if (related.length || top.length) {
        db.prepare(`INSERT INTO artist_extra (artist_id, data, fetched_at) VALUES (?, ?, datetime('now'))
          ON CONFLICT(artist_id) DO UPDATE SET data = excluded.data, fetched_at = excluded.fetched_at`).run(base.id, JSON.stringify(data));
      }
      return data;
    },
  };
}
