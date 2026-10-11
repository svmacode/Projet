import express from 'express';
import helmet from 'helmet';
import compression from 'compression';
import path from 'node:path';
import { config } from './config.js';
import { openDb } from './db.js';
import { makeQueries } from './queries.js';
import { sessionMiddleware, csrfProtection } from './security.js';
import { apiRouter } from './api.js';
import { pagesRouter } from './pages.js';
import { imagesOnDemand } from './imaging.js';
import { avatarDir, AVATAR_FILE } from './avatars.js';

export function createApp({ dbFile } = {}) {
  const db = openDb(dbFile);
  const q = makeQueries(db);
  const app = express();

  app.disable('x-powered-by');
  app.set('trust proxy', config.trustProxy);

  // En-têtes de sécurité. Aucune ressource externe : tout est servi par MyRapFr.
  app.use(helmet({
    contentSecurityPolicy: {
      useDefaults: false,
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'"],
        styleSrc: ["'self'"],
        imgSrc: ["'self'", 'data:', 'blob:'],
        fontSrc: ["'self'"],
        connectSrc: ["'self'"],
        mediaSrc: ["'self'"],
        objectSrc: ["'none'"],
        frameSrc: ["'none'"],
        frameAncestors: ["'none'"],
        baseUri: ["'self'"],
        formAction: ["'self'"],
        manifestSrc: ["'self'"],
        workerSrc: ["'self'", 'blob:'],
        ...(config.secureCookies ? { upgradeInsecureRequests: [] } : {}),
      },
    },
    // HSTS seulement quand le site est servi en HTTPS avec un vrai certificat.
    strictTransportSecurity: config.isProd && config.secureCookies ? { maxAge: 31536000, includeSubDomains: true } : false,
    crossOriginEmbedderPolicy: false,
    referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  }));
  app.use((req, res, next) => {
    res.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()');
    next();
  });

  app.use(compression());

  // Fichiers statiques : longue mise en cache pour les images, polices et bibliothèques.
  const pub = path.join(config.root, 'public');
  const longCache = { maxAge: '30d', immutable: false, index: false };
  app.use('/img', express.static(path.join(pub, 'img'), longCache));
  app.use('/fonts', express.static(path.join(pub, 'fonts'), { ...longCache, maxAge: '365d', immutable: true }));
  app.use('/vendor', express.static(path.join(pub, 'vendor'), longCache));
  app.use(express.static(pub, { maxAge: config.isProd ? '1h' : 0, index: false }));
  // Pochettes, portraits et images de partage absents du disque : fabriqués à la première demande.
  app.use(imagesOnDemand());
  // Photos de profil importées : servies depuis data/avatars/, noms aléatoires vérifiés.
  app.get('/img/avatars/:file', (req, res, next) => {
    if (!AVATAR_FILE.test(req.params.file)) return next();
    res.sendFile(path.join(avatarDir, req.params.file), { maxAge: '30d', immutable: true }, (err) => err && next());
  });

  // Suivi UTM : chaque arrivée par un lien de campagne incrémente un compteur anonyme.
  const utmHit = db.prepare(`INSERT INTO utm_stats (day, source, medium, campaign, path, visits) VALUES (date('now'), ?, ?, ?, ?, 1)
    ON CONFLICT(day, source, medium, campaign, path) DO UPDATE SET visits = visits + 1`);
  const clean = (v) => String(v || '').toLowerCase().replace(/[^a-z0-9_.-]/g, '').slice(0, 40);
  app.use((req, res, next) => {
    if (req.method === 'GET' && req.query.utm_source && !req.path.startsWith('/api/') && !req.path.includes('.')) {
      try { utmHit.run(clean(req.query.utm_source), clean(req.query.utm_medium), clean(req.query.utm_campaign), req.path.slice(0, 120)); } catch { /* sans gravité */ }
    }
    next();
  });

  app.use(sessionMiddleware(db));
  app.use(csrfProtection);

  app.use('/api/v1', apiRouter(db, q));
  const pages = pagesRouter(db, q);
  app.use(pages);
  app.use(pages.notFound);

  // Erreur inattendue : message neutre, détail uniquement dans les journaux du serveur.
  app.use((err, req, res, next) => {
    if (err.type === 'entity.too.large' && req.path === '/api/v1/me/avatar') {
      return res.status(413).json({ error: 'Image trop lourde : 5 Mo maximum.' });
    }
    if (err.type === 'entity.parse.failed' || err.type === 'entity.too.large') {
      return res.status(400).json({ error: 'Requête invalide.' });
    }
    console.error(err);
    if (res.headersSent) return next(err);
    if (req.path.startsWith('/api/')) return res.status(500).json({ error: 'Erreur du serveur, réessaie.' });
    res.status(500).type('text/plain').send('Erreur du serveur. Réessaie dans un instant.');
  });

  app.locals.db = db;
  return app;
}
