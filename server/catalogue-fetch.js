// Récupère les vraies pochettes et photos d'artistes, en essayant plusieurs sources publiques :
//   pochettes : Deezer → Apple Music (iTunes) → MusicBrainz / Cover Art Archive
//   photos    : Deezer → TheAudioDB → Wikipédia
// Les fichiers vont dans data/sources/ ; ils sont ensuite compressés par scripts/images.js.
import fs from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';
import { artists, albums, albumSlug } from '../data/catalogue.js';
import { config } from './config.js';

const dir = (...p) => path.join(config.root, 'data', ...p);
const UA = 'MyRapFr/0.1 (catalogue de rap francais ; contact via le site)';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const norm = (s) => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
  .replace(/œ/g, 'oe').replace(/&/g, ' et ').replace(/[^a-z0-9]+/g, ' ').trim();

// Proportion de mots du titre recherché retrouvés dans le titre trouvé.
function titleScore(wanted, found) {
  const w = norm(wanted).split(' ').filter(Boolean);
  const f = new Set(norm(found).split(' '));
  if (!w.length) return 0;
  return w.filter((x) => f.has(x)).length / w.length;
}
const sameArtist = (a, b) => {
  const x = norm(a); const y = norm(b);
  return Boolean(x && y && (x === y || x.includes(y) || y.includes(x)));
};

async function getJson(url) {
  for (let attempt = 0; attempt < 3; attempt++) {
    const res = await fetch(url, { headers: { 'User-Agent': UA, Accept: 'application/json' }, signal: AbortSignal.timeout(15000) });
    if (res.status === 429 || res.status === 503) { await sleep(1500 * (attempt + 1)); continue; }
    if (!res.ok) return null;
    const data = await res.json();
    if (data?.error?.code === 4) { await sleep(2000); continue; } // quota Deezer
    return data;
  }
  return null;
}

// Télécharge une image et vérifie que c'en est vraiment une, assez grande.
async function saveImage(url, file, minSize = 250) {
  const res = await fetch(url, { headers: { 'User-Agent': UA }, redirect: 'follow', signal: AbortSignal.timeout(20000) });
  if (!res.ok) return false;
  const buf = Buffer.from(await res.arrayBuffer());
  try {
    const meta = await sharp(buf).metadata();
    if (!meta.width || meta.width < minSize || meta.height < minSize) return false;
  } catch {
    return false;
  }
  fs.writeFileSync(file, buf);
  return true;
}

// ---------- Sources pour les pochettes ----------
const coverSources = [
  {
    name: 'Deezer',
    async find(artist, title) {
      const q = encodeURIComponent(`artist:"${artist}" album:"${title.replace(/[…"]/g, '')}"`);
      let data = (await getJson(`https://api.deezer.com/search/album?q=${q}&limit=10`))?.data || [];
      if (!data.length) data = (await getJson(`https://api.deezer.com/search/album?q=${encodeURIComponent(`${artist} ${title}`)}&limit=10`))?.data || [];
      return data.map((d) => ({ title: d.title, artist: d.artist?.name, url: d.cover_xl, credit: 'Deezer' }));
    },
    delay: 150,
  },
  {
    name: 'Apple Music',
    async find(artist, title) {
      const data = await getJson(`https://itunes.apple.com/search?term=${encodeURIComponent(`${artist} ${title}`)}&entity=album&country=fr&limit=10`);
      return (data?.results || []).map((d) => ({
        title: d.collectionName,
        artist: d.artistName,
        url: d.artworkUrl100?.replace(/\/\d+x\d+bb\./, '/1200x1200bb.'),
        credit: 'Apple Music',
      }));
    },
    delay: 400,
  },
  {
    name: 'MusicBrainz',
    async find(artist, title) {
      const q = encodeURIComponent(`releasegroup:"${title.replace(/[…"]/g, '')}" AND artist:"${artist}"`);
      const data = await getJson(`https://musicbrainz.org/ws/2/release-group/?query=${q}&fmt=json&limit=5`);
      return (data?.['release-groups'] || []).map((g) => ({
        title: g.title,
        artist: g['artist-credit']?.[0]?.name,
        url: `https://coverartarchive.org/release-group/${g.id}/front-1200`,
        credit: 'Cover Art Archive',
      }));
    },
    delay: 1100, // MusicBrainz : une requête par seconde maximum
  },
];

// ---------- Sources pour les photos ----------
const photoSources = [
  {
    name: 'Deezer',
    async find(name) {
      const data = (await getJson(`https://api.deezer.com/search/artist?q=${encodeURIComponent(name)}&limit=5`))?.data || [];
      // Deezer renvoie une silhouette générique quand il n'a pas de photo : l'adresse contient « /artist// ».
      return data.filter((d) => d.picture_xl && !d.picture_xl.includes('/artist//'))
        .map((d) => ({ artist: d.name, url: d.picture_xl, credit: 'Deezer' }));
    },
    delay: 150,
  },
  {
    name: 'TheAudioDB',
    async find(name) {
      const data = await getJson(`https://www.theaudiodb.com/api/v1/json/2/search.php?s=${encodeURIComponent(name)}`);
      return (data?.artists || []).filter((a) => a.strArtistThumb)
        .map((a) => ({ artist: a.strArtist, url: a.strArtistThumb, credit: 'TheAudioDB' }));
    },
    delay: 600,
  },
  {
    name: 'Wikipédia',
    async find(name, wiki) {
      const s = await getJson(`https://fr.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent((wiki || name).replace(/ /g, '_'))}`);
      const src = s?.originalimage?.source || s?.thumbnail?.source;
      if (!src || s.type !== 'standard' || /\.svg/i.test(src)) return [];
      return [{ artist: name, url: src, credit: `Wikimedia Commons (voir ${s.content_urls?.desktop?.page || 'Wikipédia'})` }];
    },
    delay: 200,
  },
];

function readCredits() {
  try { return JSON.parse(fs.readFileSync(dir('credits.json'), 'utf8')); } catch { return { artists: {}, albums: {} }; }
}

// Vérifie qu'au moins une source répond (sinon inutile d'insister : pas d'accès à internet).
export async function sourcesReachable() {
  for (const url of ['https://api.deezer.com/infos', 'https://itunes.apple.com/search?term=iam&limit=1']) {
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
      if (res.ok) return true;
    } catch { /* source suivante */ }
  }
  return false;
}

export async function fetchCatalogue({ force = false, bios = false, log = console.log } = {}) {
  fs.mkdirSync(dir('sources', 'covers'), { recursive: true });
  fs.mkdirSync(dir('sources', 'artists'), { recursive: true });
  const credits = readCredits();
  const report = { uncertain: [], missing: [] };
  const artistName = Object.fromEntries(artists.map((a) => [a.slug, a.name]));
  let covers = 0;
  let photos = 0;

  // Pochettes
  const todo = albums.filter(([a, t]) => force || !fs.existsSync(dir('sources', 'covers', `${albumSlug(a, t)}.jpg`)));
  if (todo.length) log(`Recherche de ${todo.length} pochette(s)…`);
  for (const [artistSlug, title, year] of todo) {
    const slug = albumSlug(artistSlug, title);
    const artist = artistName[artistSlug];
    let fallback = null;
    let saved = false;
    for (const source of coverSources) {
      let candidates = [];
      try { candidates = await source.find(artist, title); } catch { /* source injoignable */ }
      await sleep(source.delay);
      const ranked = candidates
        .filter((c) => c.url)
        .map((c) => ({ ...c, score: titleScore(title, c.title) + (sameArtist(artist, c.artist) ? 1 : 0) }))
        .sort((x, y) => y.score - x.score);
      const best = ranked[0];
      if (!best) continue;
      if (best.score >= 1.6) {
        if (await saveImage(best.url, dir('sources', 'covers', `${slug}.jpg`))) {
          credits.albums[slug] = { coverCredit: `Pochette © ${artist} et ayants droit. Image : ${best.credit}.` };
          saved = true;
          break;
        }
      } else if (!fallback || best.score > fallback.score) fallback = best;
    }
    // Aucune correspondance sûre : on prend la meilleure trouvée si elle est plausible, et on la signale.
    if (!saved && fallback && fallback.score >= 1.3
      && await saveImage(fallback.url, dir('sources', 'covers', `${slug}.jpg`)).catch(() => false)) {
      credits.albums[slug] = { coverCredit: `Pochette © ${artist} et ayants droit. Image : ${fallback.credit}.` };
      report.uncertain.push({ slug, wanted: `${artist} — ${title} (${year})`, found: `${fallback.artist} — ${fallback.title}` });
      saved = true;
    }
    if (saved) covers++;
    else report.missing.push({ slug, wanted: `${artist} — ${title}` });
  }

  // Photos des artistes (et, sur demande, les résumés Wikipédia)
  const todoArtists = artists.filter((a) => force || !fs.existsSync(dir('sources', 'artists', `${a.slug}.jpg`)));
  if (todoArtists.length) log(`Recherche de ${todoArtists.length} photo(s) d'artiste…`);
  for (const a of todoArtists) {
    let saved = false;
    for (const source of photoSources) {
      let candidates = [];
      try { candidates = await source.find(a.name, a.wiki); } catch { /* source injoignable */ }
      await sleep(source.delay);
      const best = candidates.find((c) => norm(c.artist) === norm(a.name)) || candidates.find((c) => sameArtist(a.name, c.artist));
      if (best && await saveImage(best.url, dir('sources', 'artists', `${a.slug}.jpg`), 300).catch(() => false)) {
        credits.artists[a.slug] = { ...credits.artists[a.slug], photoCredit: `${a.name}. Image : ${best.credit}.` };
        saved = true;
        break;
      }
    }
    if (saved) photos++;
    else report.missing.push({ slug: a.slug, wanted: `photo de ${a.name}` });
  }

  if (bios) {
    log('Récupération des résumés Wikipédia…');
    for (const a of artists) {
      const s = await getJson(`https://fr.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent((a.wiki || a.name).replace(/ /g, '_'))}`).catch(() => null);
      if (s?.type === 'standard' && s.extract?.length > 80) {
        credits.artists[a.slug] = {
          ...credits.artists[a.slug],
          bio: s.extract,
          bioSource: `Wikipédia, « ${s.title} », licence CC BY-SA 4.0`,
        };
      }
      await sleep(150);
    }
  }

  fs.writeFileSync(dir('credits.json'), JSON.stringify(credits, null, 1));
  fs.writeFileSync(dir('fetch-report.json'), JSON.stringify(report, null, 1));
  log(`${covers} pochette(s) et ${photos} photo(s) récupérée(s). ${report.uncertain.length} à vérifier, ${report.missing.length} introuvable(s) (détail : data/fetch-report.json).`);
  return { covers, photos, report };
}
