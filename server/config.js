import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import crypto from 'node:crypto';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const env = process.env;

// Clé secrète du serveur (signature des jetons de formulaire). Générée au premier lancement.
function loadSecret() {
  if (env.APP_SECRET && env.APP_SECRET.length >= 32) return env.APP_SECRET;
  const file = path.join(root, 'data', 'secret.key');
  try {
    return fs.readFileSync(file, 'utf8').trim();
  } catch {
    const secret = crypto.randomBytes(48).toString('base64url');
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, secret, { mode: 0o600 });
    return secret;
  }
}

const isProd = env.NODE_ENV === 'production';
const httpsPort = Number(env.HTTPS_PORT || 8443);
const certFile = env.TLS_CERT || path.join(root, 'certs', 'localhost.crt');
const keyFile = env.TLS_KEY || path.join(root, 'certs', 'localhost.key');
const hasCert = fs.existsSync(certFile) && fs.existsSync(keyFile);

export const config = {
  root,
  isProd,
  isTest: env.NODE_ENV === 'test',
  port: Number(env.PORT || 8080),
  httpsPort,
  certFile,
  keyFile,
  hasCert,
  // Derrière un tunnel (Cloudflare Tunnel, reverse proxy), mettre TRUST_PROXY=1 et BEHIND_TLS_PROXY=1.
  trustProxy: env.TRUST_PROXY === '1' ? 1 : false,
  behindTlsProxy: env.BEHIND_TLS_PROXY === '1',
  publicUrl: (env.PUBLIC_URL || (hasCert ? `https://localhost:${httpsPort}` : `http://localhost:${env.PORT || 8080}`)).replace(/\/$/, ''),
  dbFile: env.DB_FILE || path.join(root, 'data', 'myrapfr.db'),
  secret: loadSecret(),
  contactEmail: env.CONTACT_EMAIL || 'contact@myrapfr.fr',
  // Service d'e-mail (SMTP). Sans SMTP_HOST, les e-mails sont affichés dans la console.
  smtp: env.SMTP_HOST && env.SMTP_USER && env.SMTP_PASS ? {
    host: env.SMTP_HOST,
    port: Number(env.SMTP_PORT || 587),
    user: env.SMTP_USER,
    pass: env.SMTP_PASS,
    from: env.MAIL_FROM || `MyRapFr <${env.CONTACT_EMAIL || 'contact@myrapfr.fr'}>`,
  } : null,
  sessionDays: 30,
};

// Les cookies `Secure` ne sont possibles qu'en HTTPS.
config.secureCookies = config.hasCert || config.behindTlsProxy;
