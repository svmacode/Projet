// Mise à jour automatique du catalogue, en arrière-plan, à chaque démarrage du serveur :
//  1. discographies sur Deezer, artiste par artiste : chaque discographie (et ses pochettes)
//     apparaît sur le site dès qu'elle est récupérée ; un arrêt du serveur ne fait rien perdre,
//     la récupération reprend là où elle s'était arrêtée. Chaque discographie est relue une fois
//     par semaine pour ajouter les nouvelles sorties.
//  2. pochettes et photos encore manquantes (autres sources), toutes les 6 h tant qu'il en manque.
import fs from 'node:fs';
import path from 'node:path';
import { config } from './config.js';
import { seedCatalogue } from './db.js';
import { loadCatalog, invalidateCatalog } from './catalog.js';
import { sourceFor } from './imaging.js';

const stateFile = path.join(config.root, 'data', 'fetch-state.json');
const IMAGES_RETRY = 6 * 3600_000;

// État visible sur le site (page Albums) pendant la mise à jour.
const status = { running: false, phase: '', done: 0, total: 0, projects: 0 };
export const catalogStatus = () => ({ ...status });

function missingImages() {
  const { albums, artists } = loadCatalog();
  return albums.filter((a) => !sourceFor('covers', a.slug)).length + artists.filter((a) => !sourceFor('artists', a.slug)).length;
}

export async function autoFetchImages(db) {
  if (process.env.AUTO_FETCH === '0' || config.isTest) return;
  let state = {};
  try { state = JSON.parse(fs.readFileSync(stateFile, 'utf8')); } catch { /* premier lancement */ }
  const log = (msg) => console.log(`[catalogue] ${msg}`);

  const { fetchCatalogue, downloadKnown, sourcesReachable } = await import('./catalogue-fetch.js');
  if (!(await sourcesReachable())) {
    log('Pas d’accès à Deezer ni à Apple Music : catalogue inchangé. Nouvel essai au prochain démarrage.');
    return;
  }

  Object.assign(status, { running: true, phase: 'discographies', done: 0, total: 0 });
  try {
    const { discover } = await import('./discover.js');
    await discover({
      log,
      onArtist: async ({ slug, name, picture, projects, index, total }) => {
        Object.assign(status, { done: index, total });
        seedCatalogue(db); // les albums de cet artiste sont visibles tout de suite
        const albums = loadCatalog().albums.filter((a) => a.artist === slug);
        await downloadKnown({ albums, artist: { slug, name, picture } });
        status.projects = loadCatalog().albums.length;
      },
    });
    invalidateCatalog();
    seedCatalogue(db);

    if (missingImages() && (!state.lastImages || Date.now() - state.lastImages > IMAGES_RETRY)) {
      Object.assign(status, { phase: 'images', done: 0, total: 0 });
      await fetchCatalogue({ log });
      seedCatalogue(db); // nouveaux crédits sous les pochettes
      state.lastImages = Date.now();
      fs.writeFileSync(stateFile, JSON.stringify(state));
    }
    log(`Catalogue à jour : ${loadCatalog().albums.length} projets.`);
  } catch (err) {
    log(`Mise à jour interrompue : ${err.message}. Elle reprendra au prochain démarrage.`);
  } finally {
    status.running = false;
  }
}
