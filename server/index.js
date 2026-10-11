import http from 'node:http';
import https from 'node:https';
import fs from 'node:fs';
import { config } from './config.js';
import { createApp } from './app.js';

const app = createApp();

if (config.hasCert) {
  const tls = { cert: fs.readFileSync(config.certFile), key: fs.readFileSync(config.keyFile), minVersion: 'TLSv1.2' };
  https.createServer(tls, app).listen(config.httpsPort, () => {
    console.log(`MyRapFr en HTTPS : https://localhost:${config.httpsPort}`);
  });
  // Le port HTTP ne fait que rediriger vers HTTPS.
  http.createServer((req, res) => {
    const host = (req.headers.host || 'localhost').replace(/:\d+$/, '');
    res.writeHead(301, { Location: `https://${host}:${config.httpsPort}${req.url}` });
    res.end();
  }).listen(config.port, () => console.log(`Redirection HTTP → HTTPS sur le port ${config.port}`));
} else {
  http.createServer(app).listen(config.port, () => {
    console.log(`MyRapFr en HTTP : http://localhost:${config.port}`);
    if (!config.behindTlsProxy) console.log('Astuce : lance `npm run cert` pour activer HTTPS en local.');
  });
}

// Arrêt propre : la base SQLite est refermée correctement.
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    try { app.locals.db.close(); } catch { /* déjà fermée */ }
    process.exit(0);
  });
}
