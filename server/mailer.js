import { config } from './config.js';

// Pas encore de serveur d'e-mail : les liens sont affichés dans la console du serveur.
// Pour la mise en ligne, brancher ici un service SMTP (Brevo, Mailjet, Scaleway TEM…).
export const outbox = [];

export function sendMail({ to, subject, text }) {
  outbox.push({ to, subject, text });
  if (outbox.length > 50) outbox.shift();
  if (!config.isTest) {
    console.log(`\n[e-mail] À : ${to}\n[e-mail] Objet : ${subject}\n${text}\n`);
  }
}

export function verifyEmail(to, token) {
  sendMail({
    to,
    subject: 'Confirme ton adresse MyRapFr',
    text: `Bienvenue sur MyRapFr.\nConfirme ton adresse en ouvrant ce lien (valable 48 h) :\n${config.publicUrl}/confirmer?token=${token}`,
  });
}

export function resetEmail(to, token) {
  sendMail({
    to,
    subject: 'Réinitialise ton mot de passe MyRapFr',
    text: `Tu as demandé un nouveau mot de passe.\nOuvre ce lien (valable 1 h) :\n${config.publicUrl}/nouveau-mot-de-passe?token=${token}\nSi ce n'est pas toi, ignore ce message.`,
  });
}
