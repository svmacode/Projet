// Récupère les vraies pochettes et photos (plusieurs sources publiques), puis compresse les images.
// Le serveur le fait aussi tout seul au démarrage ; cette commande sert à le forcer.
//
//   npm run catalogue:fetch              ce qui manque encore
//   npm run catalogue:fetch -- --force   tout re-télécharger
//   npm run catalogue:fetch -- --bios    remplacer aussi les biographies par le résumé Wikipédia (CC BY-SA)
//
// Les correspondances incertaines sont listées dans data/fetch-report.json.
import { fetchCatalogue, sourcesReachable } from '../server/catalogue-fetch.js';
import { buildImages } from './images.js';

if (!(await sourcesReachable())) {
  console.error("Impossible de joindre Deezer ou Apple Music. Vérifie ta connexion à internet (ou un pare-feu / proxy).");
  process.exit(1);
}
await fetchCatalogue({ force: process.argv.includes('--force'), bios: process.argv.includes('--bios') });
await buildImages({ onlyChanged: true });
console.log('Terminé. Redémarre le serveur si besoin pour afficher les nouveaux crédits.');
