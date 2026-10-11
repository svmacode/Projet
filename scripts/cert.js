// Crée un certificat HTTPS pour le développement local (localhost).
// Si mkcert est installé, le certificat sera reconnu par le navigateur sans alerte.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import selfsigned from 'selfsigned';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const dir = path.join(root, 'certs');
const cert = path.join(dir, 'localhost.crt');
const key = path.join(dir, 'localhost.key');
fs.mkdirSync(dir, { recursive: true });

function hasMkcert() {
  try { execFileSync('mkcert', ['-help'], { stdio: 'ignore' }); return true; } catch { return false; }
}

if (hasMkcert()) {
  execFileSync('mkcert', ['-install'], { stdio: 'inherit' });
  execFileSync('mkcert', ['-cert-file', cert, '-key-file', key, 'localhost', '127.0.0.1', '::1'], { stdio: 'inherit' });
  console.log('Certificat mkcert créé : aucune alerte dans le navigateur.');
} else {
  const pems = await selfsigned.generate([{ name: 'commonName', value: 'localhost' }], {
    keyType: 'ec', curve: 'P-256', algorithm: 'sha256',
    notAfterDate: new Date(Date.now() + 365 * 86400_000),
    extensions: [
      { name: 'basicConstraints', cA: false },
      { name: 'keyUsage', digitalSignature: true, keyEncipherment: true },
      { name: 'extKeyUsage', serverAuth: true },
      { name: 'subjectAltName', altNames: [{ type: 2, value: 'localhost' }, { type: 7, ip: '127.0.0.1' }] },
    ],
  });
  fs.writeFileSync(cert, pems.cert);
  fs.writeFileSync(key, pems.private, { mode: 0o600 });
  console.log('Certificat auto-signé créé. Ton navigateur affichera une alerte la première fois : c’est normal en local.');
  console.log('Pour éviter l’alerte, installe mkcert (https://github.com/FiloSottile/mkcert) puis relance `npm run cert`.');
}
console.log('Relance le serveur : https://localhost:8443');
