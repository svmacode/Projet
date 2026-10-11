// Sauvegarde à chaud de la base de données (cohérente même si le serveur tourne) et des photos de profil.
// Garde les 14 dernières copies dans data/backups/. À lancer chaque jour (planificateur de tâches / cron).
import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';
import { config } from '../server/config.js';

const dir = path.join(config.root, 'data', 'backups');
fs.mkdirSync(dir, { recursive: true });
const stamp = new Date().toISOString().replace(/[:T]/g, '-').slice(0, 19);
const target = path.join(dir, `myrapfr-${stamp}.db`);

const db = new DatabaseSync(config.dbFile, { readOnly: true });
db.prepare('VACUUM INTO ?').run(target);
db.close();

const old = fs.readdirSync(dir).filter((f) => f.endsWith('.db')).sort().slice(0, -14);
for (const f of old) fs.unlinkSync(path.join(dir, f));
// Photos de profil : copie miroir (les noms sont uniques, une photo n'est jamais modifiée).
const avatars = path.join(config.root, 'data', 'avatars');
const avatarsCopy = path.join(dir, 'avatars');
if (fs.existsSync(avatars)) {
  fs.mkdirSync(avatarsCopy, { recursive: true });
  const live = new Set(fs.readdirSync(avatars));
  for (const f of live) if (!fs.existsSync(path.join(avatarsCopy, f))) fs.copyFileSync(path.join(avatars, f), path.join(avatarsCopy, f));
  for (const f of fs.readdirSync(avatarsCopy)) if (!live.has(f)) fs.unlinkSync(path.join(avatarsCopy, f));
}

console.log(`Sauvegarde : ${target}${fs.existsSync(avatars) ? ' (et photos de profil dans data/backups/avatars)' : ''}`);
console.log('Pense à copier régulièrement ce dossier ailleurs (disque externe, cloud chiffré).');
