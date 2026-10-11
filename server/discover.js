// Récupère sur Deezer la discographie complète (albums, mixtapes, EP) de chaque artiste suivi,
// ainsi que sa photo, et sur Wikipédia un résumé pour les artistes sans biographie éditoriale.
// Résultat dans data/discovered.json, lu par server/catalog.js.
import fs from 'node:fs';
import { allArtistNames, readDiscovered, discoveredFile, normName, baseTitle, invalidateCatalog } from './catalog.js';
import { artists as curatedArtists } from '../data/catalogue.js';

const UA = 'MyRapFr/0.1 (catalogue de rap francais)';
const RAP = 116; // genre « Rap/Hip Hop » chez Deezer
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Ce qui n'est pas un projet à part entière.
const EXCLUDE = /\b(live|en concert|instrumental(e|s)?|a cappella|acapella|karaok[eé]|remix(es)?|best of|greatest hits|the best|l'essentiel|anthologie|compilation|playlist|bande originale)\b/i;

async function getJson(url) {
  for (let attempt = 0; attempt < 4; attempt++) {
    let res;
    try {
      res = await fetch(url, { headers: { 'User-Agent': UA, Accept: 'application/json' }, signal: AbortSignal.timeout(15000) });
    } catch {
      await sleep(1000);
      continue;
    }
    if (res.status === 429 || res.status >= 500) { await sleep(1500 * (attempt + 1)); continue; }
    if (!res.ok) return null;
    const data = await res.json().catch(() => null);
    if (data?.error?.code === 4) { await sleep(2500); continue; } // quota Deezer : 50 requêtes / 5 s
    return data;
  }
  return null;
}

async function artistAlbums(id) {
  const out = [];
  let url = `https://api.deezer.com/artist/${id}/albums?limit=100`;
  while (url && out.length < 500) {
    const page = await getJson(url);
    if (!page?.data) break;
    out.push(...page.data);
    url = page.next || null;
    await sleep(120);
  }
  return out;
}

// Parmi les homonymes, garde l'artiste dont la discographie est surtout du rap, et le plus suivi.
async function findArtist(name) {
  const q = encodeURIComponent(`artist:"${name}"`);
  let list = (await getJson(`https://api.deezer.com/search/artist?q=${q}&limit=10`))?.data || [];
  if (!list.length) list = (await getJson(`https://api.deezer.com/search/artist?q=${encodeURIComponent(name)}&limit=10`))?.data || [];
  const exact = list.filter((a) => normName(a.name) === normName(name));
  const candidates = (exact.length ? exact : list.slice(0, 1)).sort((a, b) => (b.nb_fan || 0) - (a.nb_fan || 0)).slice(0, 3);
  let best = null;
  for (const c of candidates) {
    await sleep(120);
    const albums = await artistAlbums(c.id);
    const typed = albums.filter((a) => a.genre_id && a.genre_id > 0);
    const rapShare = typed.length ? typed.filter((a) => a.genre_id === RAP).length / typed.length : 0.5;
    const score = rapShare * 10 + Math.log10((c.nb_fan || 0) + 1);
    if (rapShare >= 0.3 && (!best || score > best.score)) best = { artist: c, albums, score, rapShare };
  }
  return best;
}

export function pickProjects(slug, albums) {
  const keep = new Map();
  for (const a of albums) {
    if (!['album', 'ep'].includes(a.record_type)) continue; // pas de singles ni de compilations
    if (EXCLUDE.test(a.title)) continue;
    const key = baseTitle(a.title);
    if (!key) continue;
    const year = Number(String(a.release_date || '').slice(0, 4)) || null;
    if (!year) continue;
    const prev = keep.get(key);
    // Entre deux éditions du même projet : la plus ancienne date, le titre le plus court (sans « Deluxe »).
    if (!prev || year < prev.year || (year === prev.year && a.title.length < prev.title.length)) {
      keep.set(key, { artist: slug, title: a.title.replace(/\s*\((Explicit|Deluxe|Edition Deluxe|Version Deluxe)\)\s*$/i, '').trim(), year, kind: a.record_type, deezerId: a.id, cover: a.cover_xl });
    }
  }
  return [...keep.values()];
}

// Résumé Wikipédia (licence CC BY-SA) pour les artistes sans biographie, si la page parle bien de rap.
async function wikiBio(name) {
  for (const title of [`${name} (rappeur)`, `${name} (rappeuse)`, `${name} (groupe)`, name]) {
    const s = await getJson(`https://fr.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(title.replace(/ /g, '_'))}`);
    await sleep(120);
    if (s?.type === 'standard' && s.extract && /\b(rap|rappeu|hip-hop|hip hop|drill|trap)/i.test(s.extract)) {
      return { bio: s.extract, bioSource: `Wikipédia, « ${s.title} », licence CC BY-SA 4.0` };
    }
  }
  return null;
}

export async function discover({ log = console.log } = {}) {
  const found = readDiscovered();
  found.artists ||= {};
  const albums = [];
  const report = { notFound: [], chosen: [] };
  const names = allArtistNames();
  const curatedBio = new Set(curatedArtists.filter((a) => a.bio).map((a) => a.slug));
  log(`Discographies : ${names.length} artistes à parcourir sur Deezer…`);

  let i = 0;
  for (const { slug, name } of names) {
    i++;
    if (i % 25 === 0) log(`… ${i}/${names.length} artistes`);
    const known = found.artists[slug];
    let projects;
    let artist;
    if (known?.deezerId) {
      // Artiste déjà identifié : on relit simplement sa discographie (nouveaux projets).
      const list = await artistAlbums(known.deezerId);
      if (list.length) {
        projects = pickProjects(slug, list);
        artist = { id: known.deezerId, name: known.name, picture_xl: known.picture };
      }
    }
    if (!projects) {
      const best = await findArtist(name);
      if (!best) { report.notFound.push(name); continue; }
      artist = best.artist;
      projects = pickProjects(slug, best.albums);
      report.chosen.push({ name, deezer: artist.name, id: artist.id, fans: artist.nb_fan, rap: Math.round(best.rapShare * 100) });
    }
    const picture = artist.picture_xl && !artist.picture_xl.includes('/artist//') ? artist.picture_xl : null;
    found.artists[slug] = { ...found.artists[slug], deezerId: artist.id, name: found.artists[slug]?.name || name, picture };
    if (!curatedBio.has(slug) && !found.artists[slug].bio) {
      const bio = await wikiBio(name);
      if (bio) Object.assign(found.artists[slug], bio);
    }
    albums.push(...projects);
    await sleep(150);
  }

  if (albums.length) found.albums = albums; // en cas de panne réseau totale, on garde l'ancienne liste
  found.updatedAt = new Date().toISOString();
  fs.writeFileSync(discoveredFile, JSON.stringify(found));
  fs.writeFileSync(discoveredFile.replace('discovered.json', 'discover-report.json'), JSON.stringify(report, null, 1));
  invalidateCatalog();
  log(`${albums.length} projets trouvés pour ${names.length - report.notFound.length} artistes (${report.notFound.length} introuvable(s) : data/discover-report.json).`);
  return { albums: albums.length, notFound: report.notFound };
}
