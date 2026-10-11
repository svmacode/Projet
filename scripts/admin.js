// Donne (ou retire) le rôle d'administrateur à un membre : accès à la page /admin (modération).
// Usage : npm run admin -- pseudo            → nomme administrateur
//         npm run admin -- pseudo --retirer  → redevient membre
//         npm run admin                      → liste les administrateurs
import { openDb } from '../server/db.js';

const db = openDb();
const [username, flag] = process.argv.slice(2);
if (!username) {
  const admins = db.prepare("SELECT username FROM users WHERE role = 'admin' ORDER BY username").all();
  console.log(admins.length ? `Administrateurs : ${admins.map((a) => `@${a.username}`).join(', ')}` : 'Aucun administrateur pour l\'instant.');
  console.log('Pour en nommer un : npm run admin -- pseudo');
} else {
  const role = flag === '--retirer' ? 'member' : 'admin';
  const { changes } = db.prepare('UPDATE users SET role = ? WHERE username = ?').run(role, username.replace(/^@/, ''));
  if (!changes) {
    console.error(`Aucun membre @${username.replace(/^@/, '')}. Crée d'abord le compte sur le site.`);
    process.exitCode = 1;
  } else {
    console.log(role === 'admin'
      ? `@${username.replace(/^@/, '')} est administrateur. La page « Modération » apparaît dans son menu (reconnecte-toi si besoin).`
      : `@${username.replace(/^@/, '')} n'est plus administrateur.`);
  }
}
db.close();
