// Titres, durée et liens d'écoute d'un album.
// Les titres viennent de l'API publique de Deezer, demandés à la première visite de la page puis
// gardés 30 jours en base ; en cas d'échec, nouvel essai le lendemain. Les liens Spotify, Apple Music
// et YouTube Music sont des recherches (aucune clé d'API nécessaire).
import { loadCatalog, normName } from './catalog.js';
import { pace } from './pacing.js';

const FRESH_DAYS = 30;
const RETRY_DAYS = 1;

async function deezer(path) {
  const url = `https://api.deezer.com${path}`;
  await pace(url);
  const res = await fetch(url, { headers: { Accept: 'application/json' }, signal: AbortSignal.timeout(6000) });
  if (!res.ok) return null;
  const data = await res.json().catch(() => null);
  return data?.error ? null : data;
}

// Retrouve l'album sur Deezer quand la discographie ne donne pas son identifiant.
async function findDeezerId(album) {
  const q = encodeURIComponent(`artist:"${album.artist.name}" album:"${album.title.replace(/["…]/g, '')}"`);
  const found = (await deezer(`/search/album?q=${q}&limit=10`))?.data || [];
  const want = normName(album.title);
  const artist = normName(album.artist.name);
  const best = found.find((d) => normName(d.title) === want && normName(d.artist?.name) === artist)
    || found.find((d) => normName(d.title).startsWith(want) && normName(d.artist?.name) === artist);
  return best?.id || null;
}

export function listenLinks(album, deezerId) {
  const q = encodeURIComponent(`${album.artist.name} ${album.title}`);
  return {
    deezer: deezerId ? `https://www.deezer.com/fr/album/${deezerId}` : `https://www.deezer.com/fr/search/${q}/album`,
    spotify: `https://open.spotify.com/search/${q}/albums`,
    apple: `https://music.apple.com/fr/search?term=${q}`,
    youtube: `https://music.youtube.com/search?q=${q}`,
  };
}

export function albumDetails(db) {
  const read = db.prepare(`SELECT deezer_id, data, fetched_at,
    fetched_at > datetime('now', ?) AS fresh, fetched_at > datetime('now', ?) AS recent FROM album_details WHERE album_id = ?`);
  const save = db.prepare(`INSERT INTO album_details (album_id, deezer_id, data, fetched_at) VALUES (?, ?, ?, datetime('now'))
    ON CONFLICT(album_id) DO UPDATE SET deezer_id = excluded.deezer_id, data = excluded.data, fetched_at = excluded.fetched_at`);
  const pending = new Map();

  async function fetchDetails(album) {
    const known = loadCatalog().albums.find((a) => a.slug === album.slug)?.deezerId;
    const id = known || await findDeezerId(album);
    if (!id) return { deezerId: null, data: null };
    const d = await deezer(`/album/${id}`);
    if (!d) return { deezerId: id, data: null };
    return {
      deezerId: id,
      data: {
        duration: d.duration || 0,
        label: d.label || '',
        releaseDate: d.release_date || '',
        tracks: (d.tracks?.data || []).map((t, i) => ({
          n: i + 1, title: t.title_short || t.title, version: t.title_version || '',
          duration: t.duration || 0, explicit: Boolean(t.explicit_lyrics),
          // Invités : seulement les artistes en plus de l'artiste principal.
          featuring: (t.contributors || []).map((c) => c.name).filter((n) => normName(n) !== normName(album.artist.name)),
        })),
      },
    };
  }

  // Renvoie les détails (depuis le cache, ou en les demandant à Deezer une seule fois à la fois).
  return async function get(album) {
    const row = read.get(`-${FRESH_DAYS} days`, `-${RETRY_DAYS} days`, album.id);
    if (row && (row.data ? row.fresh : row.recent)) {
      return { deezerId: row.deezer_id, ...(row.data ? JSON.parse(row.data) : { tracks: [] }), links: listenLinks(album, row.deezer_id) };
    }
    if (!pending.has(album.id)) {
      pending.set(album.id, fetchDetails(album)
        .catch(() => ({ deezerId: row?.deezer_id || null, data: null }))
        .then((r) => {
          // En cas d'échec, on garde les anciens titres s'il y en avait.
          const data = r.data || (row?.data ? JSON.parse(row.data) : null);
          save.run(album.id, r.deezerId, data ? JSON.stringify(data) : null);
          return { deezerId: r.deezerId, ...(data || { tracks: [] }) };
        })
        .finally(() => pending.delete(album.id)));
    }
    const r = await pending.get(album.id);
    return { ...r, links: listenLinks(album, r.deezerId) };
  };
}
