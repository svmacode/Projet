// Vérifie le service d'e-mail configuré dans .env et envoie un message d'essai.
// Usage : npm run mail:test -- ton-adresse@exemple.fr
import { checkMail, sendMail } from '../server/mailer.js';

const to = process.argv[2];
const check = await checkMail();
if (!check.ok) {
  console.error(`\nLe service d'e-mail ne répond pas : ${check.reason}\nVérifie SMTP_HOST, SMTP_PORT, SMTP_USER et SMTP_PASS dans le fichier .env.\n`);
  process.exit(1);
}
console.log('Connexion au service d\'e-mail : OK.');
if (!to || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(to)) {
  console.log('Pour envoyer un message d\'essai : npm run mail:test -- ton-adresse@exemple.fr');
  process.exit(0);
}
await sendMail({ to, subject: 'Test MyRapFr', text: 'Si tu lis ce message, les e-mails de MyRapFr fonctionnent.' });
console.log(`Message d'essai envoyé à ${to}. Pense à regarder dans les indésirables.`);
