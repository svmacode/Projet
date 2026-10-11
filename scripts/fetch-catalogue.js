// Met à jour le catalogue à la main (le serveur le fait aussi tout seul au démarrage) :
// discographies complètes sur Deezer, puis pochettes et photos manquantes.
//
//   npm run catalogue:fetch              discographies + images manquantes
//   npm run catalogue:fetch -- --force   re-télécharge aussi toutes les images
//   npm run catalogue:fetch -- --bios    remplace aussi les biographies par le résumé Wikipédia (CC BY-SA)
//   npm run catalogue:fetch -- --images  images seulement, sans relire les discographies
//
// Rapports : data/discover-report.json (artistes) et data/fetch-report.json (images).
import { fetchCatalogue, sourcesReachable } from '../server/catalogue-fetch.js';
import { discover } from '../server/discover.js';
import { openDb } from '../server/db.js';

if (!(await sourcesReachable())) {
  console.error('Impossible de joindre Deezer ou Apple Music. Vérifie ta connexion à internet (ou un pare-feu / proxy).');
  process.exit(1);
}
if (!process.argv.includes('--images')) await discover();
await fetchCatalogue({ force: process.argv.includes('--force'), bios: process.argv.includes('--bios') });
openDb().close(); // enregistre le nouveau catalogue dans la base
console.log('Terminé. Redémarre le serveur pour tout afficher.');
