import { html, raw, jsonForScript } from '../html.js';
import { config } from '../config.js';
import { icon } from './components.js';
import { lastCatalogUpdate } from '../catalog.js';
import { avatarUrl } from '../avatars.js';

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
        ${link('/classements', 'Classements')}
        ${link('/#apropos', 'À propos')}
        ${user ? link('/fil', 'Fil d’actu') : ''}
        ${user ? link('/amis', 'Amis') : ''}
        ${user?.admin ? link('/admin', user.pendingReports ? `Modération (${user.pendingReports})` : 'Modération') : ''}
        <div class="gnav-mobile-extra">
          ${user
            ? html`<a href="/membre/${user.username}">Mon profil</a><a href="/compte">Paramètres</a>`
            : html`<a href="/connexion">Connexion</a><a href="/inscription">Créer un compte</a>`}
        </div>
      </div>
      <div class="gnav-actions">
        <a class="gnav-icon" href="/recherche" aria-label="Rechercher (raccourci : /)" data-search-open aria-haspopup="dialog">${icon('search')}</a>
        <button class="gnav-icon" type="button" data-theme-toggle aria-label="Changer de thème">
          <span class="theme-icon-dark">${icon('moon')}</span><span class="theme-icon-light">${icon('sun')}</span>
        </button>
        ${user ? html`<a class="gnav-icon gnav-bell" href="/notifications" aria-label="${user.unread ? `Notifications : ${user.unread} non lue${user.unread > 1 ? 's' : ''}` : 'Notifications'}">${icon('bell')}${user.unread ? html`<span class="badge" aria-hidden="true">${user.unread > 9 ? '9+' : user.unread}</span>` : ''}</a>` : ''}
        ${user
          ? html`<a class="gnav-me" href="/membre/${user.username}" aria-label="Mon profil">${avatarUrl(user.avatar) ? html`<img src="${avatarUrl(user.avatar)}" alt="" width="64" height="64">` : user.displayName.slice(0, 1).toUpperCase()}</a>`
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
        <div><h2>Explorer</h2><a href="/albums">Albums</a><a href="/rappeurs">Rappeurs</a><a href="/classements">Classements</a><a href="/defi">Défi du mois</a><a href="/recherche">Recherche</a><button type="button" class="footer-install" data-install hidden>Installer l’application</button></div>
        <div><h2>Compte</h2><a href="/inscription">Créer un compte</a><a href="/connexion">Connexion</a><a href="/compte">Paramètres</a></div>
        <div><h2>MyRapFr</h2><a href="/#apropos">À propos</a><a href="/plan-du-site">Plan du site</a></div>
        <div><h2>Légal</h2><a href="/confidentialite">Confidentialité</a><a href="/cgu">Conditions d'utilisation</a><a href="/mentions-legales">Mentions légales</a><a href="/cookies">Cookies</a></div>
      </nav>
      <p class="gfoot-legal">© ${year} MyRapFr. Fait avec amour pour le rap français.
        <span class="gfoot-updated">Catalogue mis à jour le <time datetime="${lastCatalogUpdate().toISOString()}">${lastCatalogUpdate().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })}</time>.</span></p>
    </div>
  </footer>`;
}

function cookieBanner() {
  return html`<div class="consent" role="region" aria-label="Cookies" data-consent hidden>
    <p>MyRapFr n'utilise que le nécessaire (garder ta session ouverte). Avec ton accord, on retient aussi d'où tu viens (lien partagé, campagne) pour savoir quels partages fonctionnent. Aucune publicité. <a href="/cookies">En savoir plus</a></p>
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
  ${bodyClass.includes('page-home') ? html`<link rel="stylesheet" href="/css/stream.css">` : ''}
  <script src="/js/boot.js"></script>
  <!-- Scripts annoncés avant les images : sinon, au premier affichage, ils attendent derrière les
       pochettes en cours de fabrication et les animations démarrent en retard. -->
  <link rel="preload" href="/vendor/gsap.min.js" as="script">
  <link rel="preload" href="/vendor/ScrollTrigger.min.js" as="script">
  <link rel="preload" href="/vendor/lenis.min.js" as="script">
  <link rel="modulepreload" href="/js/app.js">
  <link rel="modulepreload" href="/js/lib/api.js">
  <link rel="modulepreload" href="/js/lib/ui.js">
  <link rel="modulepreload" href="/js/lib/extras.js">
  <link rel="modulepreload" href="/js/lib/search.js">
  ${scripts.map((s) => html`<link rel="modulepreload" href="${s}">`)}
  ${jsonLd ? html`<script type="application/ld+json">${jsonForScript(jsonLd)}</script>` : ''}
</head>
<body class="${bodyClass}" ${raw(status ? `data-status="${status}"` : '')}>
  <div class="loader" aria-hidden="true" data-loader>
    <div class="loader-disc"><span></span></div>
    <p class="loader-word">MyRapFr</p>
    <div class="loader-bar"><span></span></div>
  </div>
  <div class="scroll-progress" aria-hidden="true"><span data-scroll-progress></span></div>
  <a class="skip" href="#contenu">Aller au contenu</a>
  ${nav(user, path)}
  <main id="contenu">${body}</main>
  ${footer()}
  ${cookieBanner()}
  <div class="toast" role="status" aria-live="polite" data-toast></div>
  <button class="to-top" type="button" aria-label="Revenir en haut de la page" data-to-top hidden>
    <svg class="to-top-ring" viewBox="0 0 48 48" aria-hidden="true"><circle cx="24" cy="24" r="22" data-to-top-ring></circle></svg>
    ${icon('arrow-up')}
  </button>
  <div class="search-dialog" role="dialog" aria-modal="true" aria-label="Rechercher sur MyRapFr" data-search hidden>
    <div class="search-backdrop" data-search-close></div>
    <div class="search-panel">
      <form class="search-field" action="/recherche" method="get" role="search" data-search-form>
        ${icon('search')}
        <label class="visually-hidden" for="search-q">Rechercher un album, un rappeur ou un membre</label>
        <input id="search-q" name="q" type="search" placeholder="Album, rappeur, membre…" autocomplete="off" spellcheck="false"
          role="combobox" aria-expanded="false" aria-controls="search-results" aria-autocomplete="list" data-search-input>
        <kbd class="search-kbd">Échap</kbd>
      </form>
      <div class="search-results" id="search-results" role="listbox" aria-label="Résultats" data-search-results>
        <p class="search-hint">Tape au moins deux lettres. Raccourci : <kbd>/</kbd> ou <kbd>Ctrl</kbd> + <kbd>K</kbd> sur toutes les pages.</p>
      </div>
    </div>
  </div>
  <script src="/vendor/gsap.min.js" defer></script>
  <script src="/vendor/ScrollTrigger.min.js" defer></script>
  <script src="/vendor/lenis.min.js" defer></script>
  <script type="module" src="/js/app.js"></script>
  ${scripts.map((s) => html`<script type="module" src="${s}"></script>`)}
</body>
</html>`;
}
