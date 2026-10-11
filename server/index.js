import http from 'node:http';
import https from 'node:https';
import fs from 'node:fs';
import { config } from './config.js';
import { createApp } from './app.js';
import { autoFetchImages } from './auto-images.js';

const app = createApp();

// Port déjà pris ou interdit : message clair plutôt qu'une erreur technique.
function onListenError(err) {
  if (err.code === 'EADDRINUSE') {
    console.error(`\nLe port ${err.port} est déjà utilisé : le site tourne sans doute déjà dans une autre fenêtre de commande.`
      + '\nFerme-la (ou appuie sur Ctrl+C dedans), puis relance npm start. Sinon, choisis un autre port dans le fichier .env.\n');
  } else if (err.code === 'EACCES') {
    console.error(`\nWindows refuse l'accès au port ${err.port}. Choisis un autre port dans le fichier .env (par exemple PORT=8081).\n`);
  } else {
    console.error(err);
  }
  process.exit(1);
}

if (config.hasCert) {
  const tls = { cert: fs.readFileSync(config.certFile), key: fs.readFileSync(config.keyFile), minVersion: 'TLSv1.2' };
  https.createServer(tls, app).on('error', onListenError).listen(config.httpsPort, () => {
    console.log(`MyRapFr en HTTPS : https://localhost:${config.httpsPort}`);
  });
  // Le port HTTP ne fait que rediriger vers HTTPS.
  http.createServer((req, res) => {
    const host = (req.headers.host || 'localhost').replace(/:\d+$/, '');
    res.writeHead(301, { Location: `https://${host}:${config.httpsPort}${req.url}` });
    res.end();
  }).on('error', onListenError).listen(config.port, () => console.log(`Redirection HTTP → HTTPS sur le port ${config.port}`));
} else {
  http.createServer(app).on('error', onListenError).listen(config.port, () => {
    console.log(`MyRapFr en HTTP : http://localhost:${config.port}`);
    if (!config.behindTlsProxy) console.log('Astuce : lance `npm run cert` pour activer HTTPS en local.');
  });
}

// Au premier démarrage (puis toutes les 6 h tant qu'il en manque), récupère les vraies pochettes
// et photos en arrière-plan. Le site reste utilisable pendant ce temps.
autoFetchImages(app.locals.db);

// Arrêt propre : la base SQLite est refermée correctement.
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    try { app.locals.db.close(); } catch { /* déjà fermée */ }
    process.exit(0);
  });
}
