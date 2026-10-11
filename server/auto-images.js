import fs from 'node:fs';
import path from 'node:path';
import { config } from './config.js';
import { artists, albums, albumSlug } from '../data/catalogue.js';
import { seedCatalogue } from './db.js';
import { loadImageManifest } from './queries.js';

const stateFile = path.join(config.root, 'data', 'fetch-state.json');
const RETRY_MS = 6 * 3600_000;

function missingCount() {
  const has = (kind, slug) => fs.existsSync(path.join(config.root, 'data', 'sources', kind, `${slug}.jpg`));
  return albums.filter(([a, t]) => !has('covers', albumSlug(a, t))).length
    + artists.filter((a) => !has('artists', a.slug)).length;
}

export async function autoFetchImages(db) {
  if (process.env.AUTO_FETCH === '0' || config.isTest) return;
  let state = {};
  try { state = JSON.parse(fs.readFileSync(stateFile, 'utf8')); } catch { /* premier lancement */ }
  const missing = missingCount();
  if (!missing || (state.lastRun && Date.now() - state.lastRun < RETRY_MS)) return;

  const log = (msg) => console.log(`[images] ${msg}`);
  // Import différé : ces modules (sharp, catalogue) ne sont chargés que si nécessaire.
  const { fetchCatalogue, sourcesReachable } = await import('./catalogue-fetch.js');
  if (!(await sourcesReachable())) {
    log('Pas d’accès à Deezer ni à Apple Music : les visuels provisoires restent affichés. Nouvel essai au prochain démarrage.');
    return;
  }
  try {
    log(`${missing} pochette(s) ou photo(s) à récupérer, en arrière-plan (quelques minutes)…`);
    await fetchCatalogue({ log });
    const { buildImages } = await import('../scripts/images.js');
    await buildImages({ onlyChanged: true, log });
    loadImageManifest();
    seedCatalogue(db);
    log('Les vraies images sont en ligne. Recharge la page.');
  } catch (err) {
    log(`Récupération interrompue : ${err.message}`);
  } finally {
    fs.writeFileSync(stateFile, JSON.stringify({ lastRun: Date.now() }));
  }
}
