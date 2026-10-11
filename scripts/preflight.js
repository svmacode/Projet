// Vérifications lancées automatiquement avant `npm start`, `npm run demo` et `npm run dev`
// (scripts « prestart », « predemo » et « predev »). Sans dépendance : elles doivent marcher même
// si `npm install` n'a pas été fait.
// En cas de problème, un message clair en français remplace l'erreur technique de Node.
import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const problems = [];

// 1. Version de Node (node:sqlite, --env-file-if-exists…).
const [major, minor] = process.versions.node.split('.').map(Number);
if (major < 22 || (major === 22 && minor < 13)) {
  problems.push(`Node.js ${process.versions.node} est trop ancien. Installe la version LTS sur https://nodejs.org/ (22.13 ou plus récente), puis ferme et rouvre l'invite de commandes.`);
}

// 2. Dépendances installées.
const missing = ['express', 'sharp', 'helmet'].filter((m) => !fs.existsSync(path.join(root, 'node_modules', m)));
if (missing.length || !fs.existsSync(path.join(root, 'public', 'vendor', 'gsap.min.js'))) {
  problems.push('Les dépendances ne sont pas installées. Lance d\'abord : npm install');
}

// 3. Ports libres (un autre serveur MyRapFr est souvent encore ouvert dans une autre fenêtre).
try { process.loadEnvFile(path.join(root, '.env')); } catch { /* pas de fichier .env */ }
const hasCert = fs.existsSync(process.env.TLS_CERT || path.join(root, 'certs', 'localhost.crt'));
const ports = [Number(process.env.PORT || 8080)];
if (hasCert) ports.push(Number(process.env.HTTPS_PORT || 8443));

// Un serveur répond-il déjà sur ce port ? (connexion, fiable aussi sous Windows, IPv4 comme IPv6)
const answers = (port, host) => new Promise((resolve) => {
  const sock = net.connect({ port, host });
  sock.setTimeout(800);
  sock.once('connect', () => { sock.destroy(); resolve(true); });
  sock.once('timeout', () => { sock.destroy(); resolve(false); });
  sock.once('error', () => resolve(false));
});
// Le port peut-il être ouvert ? (refus de Windows, autre programme…)
const bindable = (port) => new Promise((resolve) => {
  const srv = net.createServer();
  srv.once('error', (err) => resolve(err.code));
  srv.once('listening', () => srv.close(() => resolve(null)));
  srv.listen(port);
});

const command = process.env.npm_lifecycle_event === 'predemo' ? 'npm run demo' : process.env.npm_lifecycle_event === 'predev' ? 'npm run dev' : 'npm start';
const busy = [];
for (const port of ports) {
  if (await answers(port, '127.0.0.1') || await answers(port, '::1')) { busy.push(port); continue; }
  const code = await bindable(port);
  if (code === 'EADDRINUSE') busy.push(port);
  else if (code === 'EACCES') problems.push(`Windows refuse l'accès au port ${port}. Choisis un autre port dans le fichier .env (par exemple PORT=8081).`);
}
if (busy.length) {
  problems.push(`${busy.length > 1 ? `Les ports ${busy.join(' et ')} sont déjà utilisés` : `Le port ${busy[0]} est déjà utilisé`} : le site tourne sans doute déjà dans une autre fenêtre de commande.\n`
    + '   → Va dans cette autre fenêtre et appuie sur Ctrl+C (ou ferme-la),\n'
    + `   → puis relance ${command} ici.\n`
    + `   → Si aucune autre fenêtre n'est ouverte, redémarre le PC, ou choisis d'autres ports dans le fichier .env (PORT=8081${hasCert ? ', HTTPS_PORT=8444' : ''}).`);
}

if (problems.length) {
  console.error('\nMyRapFr ne peut pas démarrer :\n');
  for (const p of problems) console.error(` • ${p}\n`);
  process.exit(1);
}
