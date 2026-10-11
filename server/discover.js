// Récupère sur Deezer la discographie complète (albums, mixtapes, EP) de chaque artiste suivi,
// ainsi que sa photo, et sur Wikipédia un résumé pour les artistes sans biographie éditoriale.
// Résultat dans data/discovered.json, lu par server/catalog.js.
import fs from 'node:fs';
import { allArtistNames, readDiscovered, discoveredFile, normName, baseTitle, invalidateCatalog } from './catalog.js';
import { artists as curatedArtists } from '../catalogue.js';

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
  // Deux recherches (avancée et simple), fusionnées : l'une rattrape les ratés de l'autre.
  const byId = new Map();
  for (const q of [`artist:"${name}"`, name]) {
    for (const a of (await getJson(`https://api.deezer.com/search/artist?q=${encodeURIComponent(q)}&limit=10`))?.data || []) byId.set(a.id, a);
    await sleep(120);
  }
  const list = [...byId.values()].sort((a, b) => (b.nb_fan || 0) - (a.nb_fan || 0));
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

const RECHECK = 7 * 24 * 3600_000; // une discographie est relue chaque semaine (nouvelles sorties)

function save(found) {
  const tmp = `${discoveredFile}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(found));
  fs.renameSync(tmp, discoveredFile);
}

// Parcourt les artistes un par un et enregistre chaque discographie dès qu'elle est connue :
// le site se remplit au fur et à mesure, et un arrêt du serveur ne fait rien perdre.
// `onArtist` est appelé après chaque artiste (mise à jour de la base, téléchargement des pochettes).
export async function discover({ log = console.log, force = false, onArtist = async () => {} } = {}) {
  const found = readDiscovered();
  found.artists ||= {};
  found.projects ||= {};
  // Ancien format : une seule liste pour tous les artistes.
  if (Array.isArray(found.albums)) {
    for (const a of found.albums) (found.projects[a.artist] ||= []).push(a);
    delete found.albums;
  }
  const names = allArtistNames();
  const curatedBio = new Set(curatedArtists.filter((a) => a.bio).map((a) => a.slug));
  const todo = names.filter(({ slug }) => force || !found.artists[slug]?.checkedAt || Date.now() - found.artists[slug].checkedAt > RECHECK);
  if (!todo.length) return { done: 0, total: names.length, projects: Object.values(found.projects).flat().length };
  log(`Discographies : ${todo.length} artiste(s) à parcourir sur Deezer (les albums apparaissent au fur et à mesure)…`);

  const report = { notFound: [], chosen: [] };
  let i = 0;
  for (const { slug, name } of todo) {
    i++;
    const known = found.artists[slug];
    let projects = null;
    let artist = null;
    try {
      if (known?.deezerId) {
        // Artiste déjà identifié : on relit simplement sa discographie.
        const list = await artistAlbums(known.deezerId);
        if (list.length) {
          projects = pickProjects(slug, list);
          artist = { id: known.deezerId, name: known.name, picture_xl: known.picture };
        }
      }
      if (!projects) {
        const best = await findArtist(name);
        if (best) {
          artist = best.artist;
          projects = pickProjects(slug, best.albums);
          report.chosen.push({ name, deezer: artist.name, id: artist.id, fans: artist.nb_fan, rap: Math.round(best.rapShare * 100) });
        }
      }
    } catch (err) {
      log(`${name} : erreur (${err.message}), nouvel essai au prochain démarrage.`);
      continue;
    }
    if (!projects) {
      report.notFound.push(name);
      found.artists[slug] = { ...known, checkedAt: Date.now(), notFound: true };
      log(`${i}/${todo.length} ${name} : introuvable sur Deezer`);
      save(found);
      continue;
    }
    const picture = artist.picture_xl && !artist.picture_xl.includes('/artist//') ? artist.picture_xl : null;
    found.artists[slug] = { ...known, deezerId: artist.id, name: known?.name || name, picture, checkedAt: Date.now(), notFound: false };
    if (!curatedBio.has(slug) && !found.artists[slug].bioChecked) {
      const bio = await wikiBio(name).catch(() => null);
      Object.assign(found.artists[slug], bio || {}, { bioChecked: true });
    }
    found.projects[slug] = projects;
    found.updatedAt = new Date().toISOString();
    save(found);
    invalidateCatalog();
    log(`${i}/${todo.length} ${name} : ${projects.length} projet(s)`);
    await onArtist({ slug, name, picture, deezerId: artist.id, projects, index: i, total: todo.length });
    await sleep(150);
  }

  fs.writeFileSync(discoveredFile.replace('discovered.json', 'discover-report.json'), JSON.stringify(report, null, 1));
  const total = Object.values(found.projects).flat().length;
  log(`Discographies terminées : ${total} projets au total (${report.notFound.length} artiste(s) introuvable(s) : data/discover-report.json).`);
  return { done: todo.length, total: names.length, projects: total, notFound: report.notFound };
}
