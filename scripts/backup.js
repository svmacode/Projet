// Sauvegarde à chaud de la base de données (cohérente même si le serveur tourne).
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
console.log(`Sauvegarde : ${target}`);
console.log('Pense à copier régulièrement ce dossier ailleurs (disque externe, cloud chiffré).');
