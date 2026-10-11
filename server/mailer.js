// Envoi des e-mails (confirmation d'adresse, mot de passe oublié).
// - Avec un service SMTP configuré dans .env (Brevo conseillé, voir GUIDE.md) : vrais e-mails.
// - Sans configuration : le message est affiché dans la console du serveur (pratique en local).
import nodemailer from 'nodemailer';
import { config } from './config.js';

export const outbox = []; // derniers messages, pour les tests
const smtp = config.smtp;

const transport = smtp && !config.isTest
  ? nodemailer.createTransport({
    host: smtp.host,
    port: smtp.port,
    secure: smtp.port === 465, // 465 : TLS direct ; 587 : STARTTLS (exigé ci-dessous)
    requireTLS: smtp.port !== 465,
    auth: { user: smtp.user, pass: smtp.pass },
    tls: { minVersion: 'TLSv1.2' },
    disableFileAccess: true,
    disableUrlAccess: true,
  })
  : null;

export const mailEnabled = Boolean(transport);

// N'attend pas l'envoi : une panne du service d'e-mail ne bloque ni ne fait planter la requête.
export function sendMail({ to, subject, text }) {
  outbox.push({ to, subject, text });
  if (outbox.length > 50) outbox.shift();
  if (config.isTest) return Promise.resolve();
  if (!transport) {
    console.log(`\n[e-mail] À : ${to}\n[e-mail] Objet : ${subject}\n${text}\n`);
    return Promise.resolve();
  }
  return transport.sendMail({ from: smtp.from, to, subject, text })
    .catch((err) => console.error(`[e-mail] Échec de l'envoi à ${to} : ${err.message}`));
}

// Vérifie la connexion au service (commande `npm run mail:test`).
export async function checkMail() {
  if (!transport) return { ok: false, reason: 'Aucun service SMTP configuré dans .env (SMTP_HOST, SMTP_USER, SMTP_PASS, MAIL_FROM).' };
  try {
    await transport.verify();
    return { ok: true };
  } catch (err) {
    return { ok: false, reason: err.message };
  }
}

const signature = '\n\n— MyRapFr, le carnet d\'écoute du rap français';

export function verifyEmail(to, token) {
  return sendMail({
    to,
    subject: 'Confirme ton adresse MyRapFr',
    text: `Bienvenue sur MyRapFr.\n\nConfirme ton adresse en ouvrant ce lien (valable 48 h) :\n${config.publicUrl}/confirmer?token=${token}\n\nSi tu n'as pas créé de compte, ignore ce message.${signature}`,
  });
}

export function resetEmail(to, token) {
  return sendMail({
    to,
    subject: 'Réinitialise ton mot de passe MyRapFr',
    text: `Tu as demandé un nouveau mot de passe.\n\nOuvre ce lien (valable 1 h) :\n${config.publicUrl}/nouveau-mot-de-passe?token=${token}\n\nSi ce n'est pas toi, ignore ce message : ton mot de passe reste inchangé.${signature}`,
  });
}
