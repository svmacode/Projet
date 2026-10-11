// Récupère les vraies pochettes et photos d'artistes depuis l'API publique de Deezer,
// et (option --bios) les résumés de Wikipédia en français.
// Les fichiers vont dans data/sources/ ; lance ensuite `npm run images` pour les compresser.
//
// Usage :
//   npm run catalogue:fetch              pochettes + photos manquantes
//   npm run catalogue:fetch -- --force   tout re-télécharger
//   npm run catalogue:fetch -- --bios    remplacer les biographies par le résumé Wikipédia (licence CC BY-SA)
//
// Un rapport data/fetch-report.json liste les correspondances incertaines à vérifier à la main.
import fs from 'node:fs';
import path from 'node:path';
import { artists, albums, albumSlug } from '../data/catalogue.js';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const dir = (...p) => path.join(root, 'data', ...p);
fs.mkdirSync(dir('sources', 'covers'), { recursive: true });
fs.mkdirSync(dir('sources', 'artists'), { recursive: true });

const force = process.argv.includes('--force');
const withBios = process.argv.includes('--bios');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const norm = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();

const creditsFile = dir('credits.json');
const credits = fs.existsSync(creditsFile) ? JSON.parse(fs.readFileSync(creditsFile, 'utf8')) : { artists: {}, albums: {} };
const report = { uncertain: [], missing: [] };

async function getJson(url) {
  for (let attempt = 0; attempt < 3; attempt++) {
    const res = await fetch(url, { headers: { 'User-Agent': 'MyRapFr/0.1 (catalogue)' } });
    if (res.status === 429) { await sleep(2000 * (attempt + 1)); continue; }
    if (!res.ok) throw new Error(`${res.status} ${url}`);
    const data = await res.json();
    if (data?.error?.code === 4) { await sleep(2000); continue; } // quota Deezer dépassé
    return data;
  }
  throw new Error(`Trop de tentatives : ${url}`);
}

async function download(url, file) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${res.status} ${url}`);
  fs.writeFileSync(file, Buffer.from(await res.arrayBuffer()));
}

// Similarité grossière entre deux titres (mots en commun).
function score(a, b) {
  const wa = new Set(norm(a).split(' '));
  const wb = new Set(norm(b).split(' '));
  const common = [...wa].filter((w) => wb.has(w)).length;
  return common / Math.max(wa.size, wb.size, 1);
}

const artistName = Object.fromEntries(artists.map((a) => [a.slug, a.name]));
let done = 0;

console.log(`Pochettes : ${albums.length} albums…`);
for (const [artistSlug, title, year] of albums) {
  const slug = albumSlug(artistSlug, title);
  const file = dir('sources', 'covers', `${slug}.jpg`);
  if (fs.existsSync(file) && !force) continue;
  try {
    const q = encodeURIComponent(`artist:"${artistName[artistSlug]}" album:"${title.replace(/[…"]/g, '')}"`);
    let { data = [] } = await getJson(`https://api.deezer.com/search/album?q=${q}&limit=10`);
    if (!data.length) ({ data = [] } = await getJson(`https://api.deezer.com/search/album?q=${encodeURIComponent(`${artistName[artistSlug]} ${title}`)}&limit=10`));
    const ranked = data
      .map((d) => ({ d, s: score(d.title, title) + (norm(d.artist?.name || '') === norm(artistName[artistSlug]) ? 1 : 0) }))
      .sort((x, y) => y.s - x.s);
    const best = ranked[0];
    if (!best || !best.d.cover_xl) { report.missing.push({ slug, title }); continue; }
    if (best.s < 1.5) report.uncertain.push({ slug, wanted: `${artistName[artistSlug]} — ${title} (${year})`, found: `${best.d.artist?.name} — ${best.d.title}`, link: best.d.link });
    await download(best.d.cover_xl, file);
    credits.albums[slug] = { coverCredit: `Pochette : © ${best.d.artist?.name || artistName[artistSlug]} et ayants droit. Image fournie par Deezer.`, deezerId: best.d.id };
    done++;
  } catch (err) {
    report.missing.push({ slug, title, error: err.message });
  }
  await sleep(160); // Deezer limite à 50 requêtes toutes les 5 secondes
}

console.log(`Photos : ${artists.length} artistes…`);
for (const a of artists) {
  const file = dir('sources', 'artists', `${a.slug}.jpg`);
  if (!fs.existsSync(file) || force) {
    try {
      const { data = [] } = await getJson(`https://api.deezer.com/search/artist?q=${encodeURIComponent(a.name)}&limit=5`);
      const best = data.find((d) => norm(d.name) === norm(a.name)) || data[0];
      if (best?.picture_xl && !/\/artist\/\/|images\/artist\/\//.test(best.picture_xl)) {
        if (norm(best.name) !== norm(a.name)) report.uncertain.push({ slug: a.slug, wanted: a.name, found: best.name, link: best.link });
        await download(best.picture_xl, file);
        credits.artists[a.slug] = { ...credits.artists[a.slug], photoCredit: `© ${a.name}. Image fournie par Deezer.` };
        done++;
      } else report.missing.push({ slug: a.slug, title: a.name });
    } catch (err) {
      report.missing.push({ slug: a.slug, title: a.name, error: err.message });
    }
    await sleep(160);
  }

  if (withBios) {
    try {
      const page = encodeURIComponent((a.wiki || a.name).replace(/ /g, '_'));
      const s = await getJson(`https://fr.wikipedia.org/api/rest_v1/page/summary/${page}`);
      if (s.type === 'standard' && s.extract && s.extract.length > 80) {
        credits.artists[a.slug] = {
          ...credits.artists[a.slug],
          bio: s.extract,
          bioSource: `Wikipédia, « ${s.title} », licence CC BY-SA 4.0 — ${s.content_urls?.desktop?.page || ''}`,
        };
      } else report.uncertain.push({ slug: a.slug, wanted: `bio ${a.name}`, found: s.type });
    } catch (err) {
      report.missing.push({ slug: a.slug, title: `bio ${a.name}`, error: err.message });
    }
    await sleep(120);
  }
}

fs.writeFileSync(creditsFile, JSON.stringify(credits, null, 1));
fs.writeFileSync(dir('fetch-report.json'), JSON.stringify(report, null, 1));
console.log(`\n${done} images téléchargées dans data/sources/.`);
console.log(`${report.uncertain.length} correspondance(s) à vérifier, ${report.missing.length} introuvable(s) : voir data/fetch-report.json`);
console.log('Étape suivante : npm run images   puis redémarre le serveur.');
