import crypto from 'node:crypto';
import { promisify } from 'node:util';
import { config } from './config.js';

const scrypt = promisify(crypto.scrypt);

// ---------- Mots de passe (scrypt, paramètres OWASP) ----------
const SCRYPT = { N: 2 ** 15, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };

export async function hashPassword(password) {
  const salt = crypto.randomBytes(16);
  const hash = await scrypt(password.normalize('NFKC'), salt, 32, SCRYPT);
  return `scrypt$${SCRYPT.N}$${SCRYPT.r}$${SCRYPT.p}$${salt.toString('base64')}$${hash.toString('base64')}`;
}

export async function verifyPassword(password, stored) {
  const [algo, N, r, p, salt, hash] = String(stored).split('$');
  if (algo !== 'scrypt' || !salt || !hash) return false;
  try {
    const expected = Buffer.from(hash, 'base64');
    const actual = await scrypt(password.normalize('NFKC'), Buffer.from(salt, 'base64'), expected.length, {
      N: Number(N), r: Number(r), p: Number(p), maxmem: SCRYPT.maxmem,
    });
    return crypto.timingSafeEqual(actual, expected);
  } catch {
    return false; // empreinte enregistrée illisible : traitée comme un mauvais mot de passe
  }
}

// Hash factice : le temps de réponse est le même que le compte existe ou non.
let dummyHash;
export async function burnPasswordCheck(password) {
  dummyHash ??= await hashPassword('mot-de-passe-factice');
  await verifyPassword(password, dummyHash);
  return false;
}

// ---------- Jetons ----------
export const randomToken = (bytes = 32) => crypto.randomBytes(bytes).toString('base64url');
export const sha256 = (value) => crypto.createHash('sha256').update(value).digest('hex');

function safeEqual(a, b) {
  const ba = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  return ba.length === bb.length && crypto.timingSafeEqual(ba, bb);
}

// ---------- Cookies ----------
export const SESSION_COOKIE = config.secureCookies ? '__Host-mrf_sid' : 'mrf_sid';

export function parseCookies(header = '') {
  const out = {};
  for (const part of header.split(';')) {
    const i = part.indexOf('=');
    if (i < 0) continue;
    const key = part.slice(0, i).trim();
    if (key) out[key] = decodeURIComponent(part.slice(i + 1).trim());
  }
  return out;
}

function sessionCookie(value, maxAgeSeconds) {
  return [
    `${SESSION_COOKIE}=${value}`,
    'Path=/',
    'HttpOnly',
    'SameSite=Lax',
    config.secureCookies ? 'Secure' : '',
    `Max-Age=${maxAgeSeconds}`,
  ].filter(Boolean).join('; ');
}

// ---------- Sessions ----------
export function createSession(db, res, userId) {
  const token = randomToken();
  const csrf = randomToken(24);
  db.prepare(`INSERT INTO sessions (token_hash, user_id, csrf, expires_at)
              VALUES (?, ?, ?, datetime('now', ?))`)
    .run(sha256(token), userId, csrf, `+${config.sessionDays} days`);
  res.append('Set-Cookie', sessionCookie(token, config.sessionDays * 86400));
  return csrf;
}

export function destroySession(db, req, res) {
  const token = parseCookies(req.headers.cookie)[SESSION_COOKIE];
  if (token) db.prepare('DELETE FROM sessions WHERE token_hash = ?').run(sha256(token));
  res.append('Set-Cookie', sessionCookie('', 0));
}

export function sessionMiddleware(db) {
  const find = db.prepare(`
    SELECT s.token_hash, s.csrf, u.id, u.username, u.display_name, u.avatar, u.role, u.email, u.email_verified_at
    FROM sessions s JOIN users u ON u.id = s.user_id
    WHERE s.token_hash = ? AND s.expires_at > datetime('now') AND u.suspended_at IS NULL`);
  let lastCleanup = 0;
  return (req, res, next) => {
    if (Date.now() - lastCleanup > 3600_000) {
      lastCleanup = Date.now();
      db.prepare("DELETE FROM sessions WHERE expires_at <= datetime('now')").run();
      db.prepare("DELETE FROM email_tokens WHERE expires_at <= datetime('now')").run();
    }
    const token = parseCookies(req.headers.cookie)[SESSION_COOKIE];
    const row = token ? find.get(sha256(token)) : null;
    if (row) {
      req.user = {
        id: row.id,
        username: row.username,
        displayName: row.display_name,
        avatar: row.avatar,
        admin: row.role === 'admin',
        email: row.email,
        verified: Boolean(row.email_verified_at),
      };
      req.csrfToken = row.csrf;
      req.sessionHash = row.token_hash;
    }
    next();
  };
}

export function requireAuth(req, res, next) {
  if (!req.user) return res.status(401).json({ error: 'Connecte-toi pour continuer.' });
  next();
}

export function requireAdmin(req, res, next) {
  if (!req.user) return res.status(401).json({ error: 'Connecte-toi pour continuer.' });
  if (!req.user.admin) return res.status(403).json({ error: 'Réservé aux administrateurs.' });
  next();
}

export function requireVerified(req, res, next) {
  if (!req.user) return res.status(401).json({ error: 'Connecte-toi pour continuer.' });
  if (!req.user.verified) return res.status(403).json({ error: 'Confirme ton adresse e-mail pour publier.' });
  next();
}

// ---------- Protection CSRF ----------
// 1. Toute requête qui modifie des données doit venir du même site (Origin / Sec-Fetch-Site).
// 2. Une requête authentifiée doit aussi porter le jeton CSRF de sa session.
const SAFE = new Set(['GET', 'HEAD', 'OPTIONS']);

export function csrfProtection(req, res, next) {
  if (SAFE.has(req.method)) return next();
  const site = req.get('sec-fetch-site');
  if (site && site !== 'same-origin' && site !== 'none') {
    return res.status(403).json({ error: 'Requête refusée.' });
  }
  const origin = req.get('origin');
  if (origin) {
    const host = req.get('host');
    let ok = false;
    try {
      const o = new URL(origin);
      ok = o.host === host || o.origin === new URL(config.publicUrl).origin;
    } catch { /* origine invalide */ }
    if (!ok) return res.status(403).json({ error: 'Requête refusée.' });
  }
  if (req.user && !safeEqual(req.get('x-csrf-token') || '', req.csrfToken)) {
    return res.status(403).json({ error: 'Session expirée, recharge la page.' });
  }
  next();
}

// ---------- Anti-spam : jeton horodaté signé + champ piège ----------
const MIN_FILL_MS = 2500;
const MAX_FILL_MS = 2 * 3600_000;

export function issueFormToken() {
  const ts = Date.now().toString(36);
  const sig = crypto.createHmac('sha256', config.secret).update(ts).digest('base64url').slice(0, 22);
  return `${ts}.${sig}`;
}

export function checkAntiSpam(body) {
  if (config.isTest) return null;
  if (body?.website) return 'spam'; // champ invisible rempli : robot
  const [ts, sig] = String(body?.formToken || '').split('.');
  if (!ts || !sig) return 'Formulaire expiré, recharge la page.';
  const expected = crypto.createHmac('sha256', config.secret).update(ts).digest('base64url').slice(0, 22);
  if (!safeEqual(sig, expected)) return 'Formulaire expiré, recharge la page.';
  const age = Date.now() - parseInt(ts, 36);
  if (age < MIN_FILL_MS) return 'Doucement : réessaie dans un instant.';
  if (age > MAX_FILL_MS) return 'Formulaire expiré, recharge la page.';
  return null;
}

// Trop de liens dans un texte : signe de spam publicitaire.
export function looksLikeSpam(text) {
  const links = (String(text).match(/https?:\/\/|www\./gi) || []).length;
  return links > 2;
}
