import { html, raw, jsonForScript } from '../html.js';
import { config } from '../config.js';
import { icon } from './components.js';

export const SITE = {
  name: 'MyRapFr',
  description: "Note, chronique et partage les albums qui ont fait le rap français. Le carnet d'écoute du rap FR, avec tes amis.",
};

function nav(user, path) {
  const link = (href, label) => html`<a href="${href}" ${raw(path === href ? 'aria-current="page"' : '')}>${label}</a>`;
  return html`<header class="gnav" data-nav>
    <nav class="gnav-inner" aria-label="Navigation principale">
      <a class="gnav-logo" href="/" aria-label="MyRapFr, accueil">MyRapFr</a>
      <div class="gnav-links" id="gnav-links">
        ${link('/albums', 'Albums')}
        ${link('/rappeurs', 'Rappeurs')}
        ${link('/#apropos', 'À propos')}
        ${user ? link('/fil', 'Fil d’actu') : ''}
      </div>
      <div class="gnav-actions">
        <a class="gnav-icon" href="/recherche" aria-label="Rechercher">${icon('search')}</a>
        ${user
          ? html`<a class="gnav-me" href="/membre/${user.username}" aria-label="Mon profil">${user.displayName.slice(0, 1).toUpperCase()}</a>`
          : html`<a class="gnav-login" href="/connexion">Connexion</a>`}
        <button class="gnav-burger" type="button" aria-expanded="false" aria-controls="gnav-links" aria-label="Ouvrir le menu" data-burger>
          <span></span><span></span>
        </button>
      </div>
    </nav>
  </header>`;
}

function footer() {
  const year = new Date().getFullYear();
  return html`<footer class="gfoot">
    <div class="gfoot-inner">
      <p class="gfoot-note">Les pochettes et photos restent la propriété de leurs auteurs et ayants droit. Elles sont reproduites à des fins d'information et de critique. Pour toute demande de retrait, écris à <a href="mailto:${config.contactEmail}">${config.contactEmail}</a>.</p>
      <nav class="gfoot-cols" aria-label="Pied de page">
        <div><h2>Explorer</h2><a href="/albums">Albums</a><a href="/rappeurs">Rappeurs</a><a href="/recherche">Recherche</a></div>
        <div><h2>Compte</h2><a href="/inscription">Créer un compte</a><a href="/connexion">Connexion</a><a href="/compte">Paramètres</a></div>
        <div><h2>MyRapFr</h2><a href="/#apropos">À propos</a><a href="/plan-du-site">Plan du site</a></div>
        <div><h2>Légal</h2><a href="/confidentialite">Confidentialité</a><a href="/cgu">Conditions d'utilisation</a><a href="/mentions-legales">Mentions légales</a><a href="/cookies">Cookies</a></div>
      </nav>
      <p class="gfoot-legal">© ${year} MyRapFr. Fait avec amour pour le rap français.</p>
    </div>
  </footer>`;
}

function cookieBanner() {
  return html`<div class="consent" role="region" aria-label="Cookies" data-consent hidden>
    <p>MyRapFr n'utilise que des cookies nécessaires (garder ta session ouverte). Aucune publicité, aucun pistage. <a href="/cookies">En savoir plus</a></p>
    <div class="consent-actions">
      <button type="button" class="btn btn-quiet" data-consent-choice="refuse">Refuser</button>
      <button type="button" class="btn btn-quiet" data-consent-choice="accept">Accepter</button>
    </div>
  </div>`;
}

export function layout({
  title, description = SITE.description, path = '/', image = '/img/og/default.jpg', imageAlt = 'MyRapFr',
  theme = 'dark', body, scripts = [], user = null, csrf = null, noindex = false, jsonLd = null, bodyClass = '',
  status,
}) {
  const fullTitle = title ? `${title} · MyRapFr` : 'MyRapFr · Le rap français, album par album';
  const canonical = `${config.publicUrl}${path}`;
  const ogImage = image.startsWith('http') ? image : `${config.publicUrl}${image}`;
  return '<!doctype html>' + html`
<html lang="fr" class="no-js theme-${theme}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>${fullTitle}</title>
  <meta name="description" content="${description}">
  ${noindex ? html`<meta name="robots" content="noindex, nofollow">` : html`<link rel="canonical" href="${canonical}">`}
  <meta name="theme-color" content="${theme === 'dark' ? '#000000' : '#f5f5f7'}">
  <meta name="color-scheme" content="${theme === 'dark' ? 'dark' : 'light'}">
  ${csrf ? html`<meta name="csrf-token" content="${csrf}">` : ''}
  <meta property="og:site_name" content="MyRapFr">
  <meta property="og:locale" content="fr_FR">
  <meta property="og:type" content="website">
  <meta property="og:title" content="${fullTitle}">
  <meta property="og:description" content="${description}">
  <meta property="og:url" content="${canonical}">
  <meta property="og:image" content="${ogImage}">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="${imageAlt}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${fullTitle}">
  <meta name="twitter:description" content="${description}">
  <meta name="twitter:image" content="${ogImage}">
  <link rel="icon" href="/favicon.ico" sizes="32x32">
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="apple-touch-icon" href="/apple-touch-icon.png">
  <link rel="manifest" href="/site.webmanifest">
  <link rel="preload" href="/fonts/inter-var.woff2" as="font" type="font/woff2" crossorigin>
  <link rel="stylesheet" href="/css/main.css">
  <script src="/js/boot.js"></script>
  ${jsonLd ? html`<script type="application/ld+json">${jsonForScript(jsonLd)}</script>` : ''}
</head>
<body class="${bodyClass}" ${raw(status ? `data-status="${status}"` : '')}>
  <a class="skip" href="#contenu">Aller au contenu</a>
  ${nav(user, path)}
  <main id="contenu">${body}</main>
  ${footer()}
  ${cookieBanner()}
  <div class="toast" role="status" aria-live="polite" data-toast></div>
  <script src="/vendor/gsap.min.js" defer></script>
  <script src="/vendor/ScrollTrigger.min.js" defer></script>
  <script src="/vendor/lenis.min.js" defer></script>
  <script type="module" src="/js/app.js"></script>
  ${scripts.map((s) => html`<script type="module" src="${s}"></script>`)}
</body>
</html>`;
}
