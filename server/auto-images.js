// Mise à jour automatique du catalogue, en arrière-plan, au démarrage du serveur :
//  1. discographies complètes sur Deezer (au premier lancement, puis chaque semaine : nouveaux projets) ;
//  2. pochettes et photos manquantes (puis toutes les 6 h tant qu'il en manque).
// Le site reste utilisable pendant ce temps.
import fs from 'node:fs';
import path from 'node:path';
import { config } from './config.js';
import { seedCatalogue } from './db.js';
import { loadCatalog, invalidateCatalog } from './catalog.js';
import { sourceFor } from './imaging.js';

const stateFile = path.join(config.root, 'data', 'fetch-state.json');
const DISCOVER_EVERY = 7 * 24 * 3600_000;
const IMAGES_RETRY = 6 * 3600_000;

function missingImages() {
  const { albums, artists } = loadCatalog();
  return albums.filter((a) => !sourceFor('covers', a.slug)).length + artists.filter((a) => !sourceFor('artists', a.slug)).length;
}

export async function autoFetchImages(db) {
  if (process.env.AUTO_FETCH === '0' || config.isTest) return;
  let state = {};
  try { state = JSON.parse(fs.readFileSync(stateFile, 'utf8')); } catch { /* premier lancement */ }
  const save = () => fs.writeFileSync(stateFile, JSON.stringify(state));
  const log = (msg) => console.log(`[catalogue] ${msg}`);
  const now = Date.now();
  const needDiscover = !state.lastDiscover || now - state.lastDiscover > DISCOVER_EVERY;
  const needImages = !state.lastImages || now - state.lastImages > IMAGES_RETRY || needDiscover;
  if (!needDiscover && !(needImages && missingImages())) return;

  const { fetchCatalogue, sourcesReachable } = await import('./catalogue-fetch.js');
  if (!(await sourcesReachable())) {
    log('Pas d’accès à Deezer ni à Apple Music : catalogue et images inchangés. Nouvel essai au prochain démarrage.');
    return;
  }

  try {
    if (needDiscover) {
      log('Récupération des discographies complètes (première fois : 5 à 10 minutes)…');
      const { discover } = await import('./discover.js');
      const result = await discover({ log });
      if (result.albums) {
        invalidateCatalog();
        seedCatalogue(db);
        state.lastDiscover = Date.now();
        save();
        log(`Catalogue à jour : ${loadCatalog().albums.length} projets. Recharge la page.`);
      }
    }
    if (missingImages()) {
      await fetchCatalogue({ log });
      seedCatalogue(db); // nouveaux crédits sous les pochettes
      log('Pochettes et photos à jour. Recharge la page.');
    }
    state.lastImages = Date.now();
    save();
  } catch (err) {
    log(`Mise à jour interrompue : ${err.message}`);
  }
}
