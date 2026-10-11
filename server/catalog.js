// Catalogue complet = sélection éditoriale (catalogue.js, à la racine)
//                   + discographies récupérées sur Deezer (data/discovered.json).
import fs from 'node:fs';
import path from 'node:path';
import { config } from './config.js';
import { artists as curatedArtists, albums as curatedAlbums, roster, slugify, albumSlug } from '../catalogue.js';

export const discoveredFile = path.join(config.root, 'data', 'discovered.json');

export const normName = (s) => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
  .replace(/œ/g, 'oe').replace(/&/g, ' et ').replace(/[^a-z0-9]+/g, ' ').trim();

// Titre ramené à l'essentiel pour repérer les doublons (rééditions, versions deluxe…).
export function baseTitle(title) {
  return normName(String(title)
    .replace(/\s*[([].*?[)\]]\s*/g, ' ')
    .replace(/\s[-–—:]\s.*\b(deluxe|r[ée]+dition|[ée]dition|collector|version|bonus|explicit|remaster(ed)?|int[ée]grale)\b.*$/i, '')
    .replace(/\s(deluxe|collector)\s*$/i, ''));
}

// Liste de tous les artistes suivis : la sélection, puis la liste étendue (sans doublon).
export function allArtistNames() {
  const seen = new Set(curatedArtists.map((a) => normName(a.name)));
  const extra = [];
  for (const name of roster) {
    const key = normName(name);
    if (seen.has(key)) continue;
    seen.add(key);
    extra.push({ slug: slugify(name), name });
  }
  return [...curatedArtists.map((a) => ({ slug: a.slug, name: a.name })), ...extra];
}

export function readDiscovered() {
  try { return JSON.parse(fs.readFileSync(discoveredFile, 'utf8')); } catch { return { artists: {}, projects: {} }; }
}

let cache = null;
export function invalidateCatalog() { cache = null; }

export function loadCatalog() {
  if (cache) return cache;
  const found = readDiscovered();
  const artists = [];
  const bySlug = new Map();
  for (const a of curatedArtists) {
    const d = found.artists[a.slug] || {};
    const entry = { ...a, curated: true, deezerId: d.deezerId, picture: d.picture };
    artists.push(entry);
    bySlug.set(a.slug, entry);
  }
  for (const { slug, name } of allArtistNames()) {
    if (bySlug.has(slug)) continue;
    const d = found.artists[slug] || {};
    const entry = { slug, name: d.name || name, origin: d.origin || '', bio: d.bio || '', bioSource: d.bioSource, curated: false, deezerId: d.deezerId, picture: d.picture };
    artists.push(entry);
    bySlug.set(slug, entry);
  }

  const albums = [];
  const taken = new Set();
  for (const [artist, title, year] of curatedAlbums) {
    const slug = albumSlug(artist, title);
    albums.push({ slug, artist, title, year, kind: 'album', curated: true });
    taken.add(`${artist}|${baseTitle(title)}`);
    taken.add(slug);
  }
  const discovered = found.projects ? Object.values(found.projects).flat() : (found.albums || []);
  for (const a of discovered) {
    if (!bySlug.has(a.artist)) continue;
    const key = `${a.artist}|${baseTitle(a.title)}`;
    const slug = albumSlug(a.artist, a.title);
    if (taken.has(key) || taken.has(slug)) {
      // Album déjà dans la sélection : on garde la date éditoriale mais on récupère la pochette Deezer.
      const curated = albums.find((x) => x.curated && x.artist === a.artist && baseTitle(x.title) === baseTitle(a.title));
      if (curated && !curated.cover) curated.cover = a.cover;
      continue;
    }
    taken.add(key);
    taken.add(slug);
    albums.push({ slug, artist: a.artist, title: a.title, year: a.year, kind: a.kind === 'ep' ? 'ep' : 'album', curated: false, cover: a.cover, deezerId: a.deezerId });
  }
  cache = { artists, albums, bySlug };
  return cache;
}

// Date de la dernière mise à jour du catalogue (discographies, ou à défaut sélection éditoriale).
// Lecture de la date du fichier seulement (rapide) : appelée à chaque page.
export function lastCatalogUpdate() {
  for (const file of [discoveredFile, new URL('../catalogue.js', import.meta.url)]) {
    try { return fs.statSync(file).mtime; } catch { /* fichier suivant */ }
  }
  return new Date();
}
