import { html } from '../html.js';
import { config } from '../config.js';
import { tile, icon } from './components.js';

const UPDATED = '11 octobre 2026';
const owner = {
  name: process.env.OWNER_NAME || '[Nom et prénom de l’éditeur — à compléter]',
  address: process.env.OWNER_ADDRESS || '[Adresse postale — à compléter]',
  host: process.env.HOST_INFO || "[Hébergeur — à compléter avant la mise en ligne : nom, adresse et téléphone]",
};

const doc = (title, intro, body) => html`
  <article class="legal">
    <header class="page-head">
      <h1 class="display">${title}</h1>
      <p class="lede">${intro}</p>
      <p class="legal-date">Dernière mise à jour : ${UPDATED}</p>
    </header>
    <div class="legal-body">${body}</div>
  </article>`;

export function privacyPage() {
  return doc('Confidentialité.', 'Comment MyRapFr collecte, utilise et protège tes données personnelles, conformément au RGPD et à la loi Informatique et Libertés.', html`
    <h2>En bref</h2>
    <ul>
      <li>On collecte le strict minimum : un pseudo, une adresse e-mail, un mot de passe chiffré et ce que tu publies.</li>
      <li>Aucune publicité, aucune revente de données, aucun outil de mesure d'audience tiers. Seuls des compteurs anonymes de campagnes sont tenus sur notre serveur.</li>
      <li>Tu peux exporter ou supprimer toutes tes données à tout moment depuis <a href="/compte">tes paramètres</a>.</li>
    </ul>

    <h2>Responsable du traitement</h2>
    <p>${owner.name}, ${owner.address}. Contact : <a href="mailto:${config.contactEmail}">${config.contactEmail}</a>.</p>

    <h2>Données collectées et finalités</h2>
    <table>
      <thead><tr><th scope="col">Données</th><th scope="col">Pourquoi</th><th scope="col">Base légale</th><th scope="col">Durée</th></tr></thead>
      <tbody>
        <tr><td>Pseudo, adresse e-mail, mot de passe (stocké sous forme de hachage scrypt, jamais en clair)</td><td>Créer et sécuriser ton compte</td><td>Exécution du contrat (CGU)</td><td>Tant que le compte existe</td></tr>
        <tr><td>Nom affiché, bio, albums favoris, photo de profil (facultative)</td><td>Ton profil public</td><td>Exécution du contrat</td><td>Tant que le compte existe ; une photo remplacée ou retirée est effacée aussitôt</td></tr>
        <tr><td>Notes, écoutes, chroniques, commentaires, listes, j'aime, abonnements</td><td>Le service MyRapFr lui-même</td><td>Exécution du contrat</td><td>Tant que le compte existe, ou jusqu'à suppression par toi</td></tr>
        <tr><td>Cookie de session (identifiant aléatoire)</td><td>Te garder connecté</td><td>Intérêt légitime, cookie strictement nécessaire</td><td>30 jours maximum</td></tr>
        <tr><td>Adresse IP (en mémoire vive uniquement)</td><td>Limiter les abus (anti-spam, tentatives de connexion)</td><td>Intérêt légitime</td><td>15 minutes à 1 heure, jamais écrite sur disque</td></tr>
        <tr><td>Signalements (chroniques et profils) et journal des décisions de modération</td><td>Modérer les contenus et pouvoir justifier les décisions</td><td>Intérêt légitime et obligation légale (LCEN, DSA)</td><td>Jusqu'au traitement, puis 1 an</td></tr>
        <tr><td>Adresse e-mail pour le résumé hebdomadaire (seulement si tu l'as demandé)</td><td>T'envoyer chaque lundi l'activité de tes amis et des suggestions</td><td>Consentement (case à cocher dans tes paramètres, révocable à tout moment)</td><td>Jusqu'à ton désabonnement</td></tr>
        <tr><td>Notifications (nouvel abonné, j'aime, commentaire, badge, invitation à une liste)</td><td>Te prévenir de l'activité qui te concerne</td><td>Exécution du contrat</td><td>6 mois</td></tr>
        <tr><td>Membres que tu as bloqués</td><td>Te protéger des interactions non souhaitées</td><td>Exécution du contrat</td><td>Jusqu'au déblocage ou à la suppression du compte</td></tr>
        <tr><td>Compteurs de campagnes (UTM), sans aucun identifiant</td><td>Savoir quels liens partagés amènent des visiteurs</td><td>Intérêt légitime (statistique anonyme)</td><td>90 jours</td></tr>
        <tr><td>Campagne d'arrivée associée à ton compte</td><td>Savoir quels partages amènent des inscriptions</td><td>Consentement (bandeau cookies)</td><td>Tant que le compte existe</td></tr>
      </tbody>
    </table>

    <h2>Ce qui est public</h2>
    <p>Ton pseudo, ton nom affiché, ta photo de profil, ta bio, tes favoris, ton journal d'écoute, tes notes, chroniques, listes, abonnés et abonnements sont visibles par tous. Ton adresse e-mail n'est jamais affichée.</p>

    <h2>Destinataires</h2>
    <p>Tes données ne sont ni vendues ni louées. Elles sont uniquement accessibles à l'éditeur du site. Si un prestataire technique est ajouté (hébergement, envoi d'e-mails), il sera listé ici et lié par un contrat conforme à l'article 28 du RGPD.</p>

    <h2>Hébergement et transferts</h2>
    <p>Les données sont stockées en France, sur le serveur de l'éditeur. Aucun transfert hors de l'Union européenne.</p>

    <h2>Sécurité</h2>
    <p>Connexion chiffrée (HTTPS), mots de passe hachés avec scrypt, cookies de session HttpOnly et Secure, protection contre la falsification de requêtes (CSRF), limitation des tentatives, politique de sécurité du contenu (CSP) et sauvegardes régulières.</p>

    <h2>Tes droits</h2>
    <p>Tu disposes des droits d'accès, de rectification, d'effacement, de limitation, d'opposition et de portabilité. La plupart s'exercent directement :</p>
    <ul>
      <li><strong>Accès et portabilité</strong> : « Exporter mes données » dans <a href="/compte">tes paramètres</a> (fichier JSON).</li>
      <li><strong>Rectification</strong> : modifie ton profil ou tes chroniques à tout moment.</li>
      <li><strong>Effacement</strong> : « Supprimer mon compte » efface immédiatement toutes tes données.</li>
    </ul>
    <p>Pour toute autre demande : <a href="mailto:${config.contactEmail}">${config.contactEmail}</a>. Réponse sous un mois. Tu peux aussi saisir la <a href="https://www.cnil.fr/fr/plaintes" rel="noopener">CNIL</a>.</p>

    <h2>Mineurs</h2>
    <p>L'inscription est ouverte à partir de 15 ans, âge du consentement numérique en France. En dessous, l'accord d'un parent est nécessaire.</p>

    <h2>Cookies</h2>
    <p>Voir la page <a href="/cookies">Cookies</a>.</p>`);
}

export function cookiesPage() {
  return doc('Cookies.', "MyRapFr n'utilise que ce qui est indispensable au fonctionnement du site.", html`
    <table>
      <thead><tr><th scope="col">Nom</th><th scope="col">Type</th><th scope="col">Rôle</th><th scope="col">Durée</th></tr></thead>
      <tbody>
        <tr><td><code>__Host-mrf_sid</code></td><td>Cookie strictement nécessaire</td><td>Garder ta session ouverte une fois connecté</td><td>30 jours</td></tr>
        <tr><td><code>mrf-consent</code></td><td>Stockage local du navigateur</td><td>Retenir ton choix sur ce bandeau</td><td>6 mois</td></tr>
        <tr><td><code>mrf-theme</code></td><td>Stockage local du navigateur</td><td>Retenir le mode clair ou sombre choisi</td><td>Jusqu'à ce que tu le changes</td></tr>
        <tr><td>Cache de l'application</td><td>Stockage du navigateur (service worker)</td><td>Garder les fichiers du site (styles, scripts, icônes, pochettes) pour aller plus vite et afficher une page « hors ligne ». Aucune page personnelle ni donnée de compte n'y est gardée.</td><td>Jusqu'à la prochaine mise à jour du site</td></tr>
        <tr><td><code>mrf-visited</code></td><td>Stockage de session</td><td>N'afficher l'écran de chargement qu'une fois par visite</td><td>Fermeture de l'onglet</td></tr>
        <tr><td><code>mrf-utm</code></td><td>Stockage local, <strong>seulement si tu acceptes</strong></td><td>Retenir la campagne (lien partagé) par laquelle tu es arrivé, pour l'associer à ton inscription</td><td>6 mois</td></tr>
      </tbody>
    </table>
    <p>Les quatre premiers éléments sont exemptés de consentement selon les lignes directrices de la CNIL. Le dernier (<code>mrf-utm</code>) n'est enregistré que si tu cliques sur « Accepter ». Aucun cookie publicitaire ni de réseau social n'est déposé.</p>
    <p>Par ailleurs, quand tu arrives par un lien de campagne (paramètres <code>utm_source</code>, <code>utm_medium</code>, <code>utm_campaign</code>), le serveur ajoute 1 à un compteur anonyme par jour et par campagne. Aucune donnée ne t'identifie et rien n'est stocké sur ton appareil pour cela.</p>
    <p>Polices, scripts et images sont servis par MyRapFr lui-même : aucun appel à des services tiers (Google Fonts, CDN…) ne transmet ton adresse IP.</p>
    <h2>Ton choix</h2>
    <p class="consent-status" data-consent-status>Choix actuel : non défini.</p>
    <p><button type="button" class="btn btn-quiet" data-consent-reset>Modifier mon choix</button></p>`);
}

export function termsPage() {
  return doc("Conditions d'utilisation.", "Les règles du jeu sur MyRapFr. En créant un compte, tu les acceptes.", html`
    <h2>1. Le service</h2>
    <p>MyRapFr est un site gratuit qui permet de noter des albums de rap français, de tenir un journal d'écoute, d'écrire des chroniques, de créer des listes et de suivre d'autres membres.</p>
    <h2>2. Ton compte</h2>
    <p>Tu dois avoir au moins 15 ans, ou l'accord d'un parent. Tu es responsable de la confidentialité de ton mot de passe. Un compte par personne ; les comptes automatisés sont interdits.</p>
    <h2>3. Ce que tu publies</h2>
    <p>Tu restes propriétaire de tes chroniques. Tu accordes à MyRapFr le droit de les afficher sur le site tant qu'elles sont en ligne. Tu peux les supprimer à tout moment.</p>
    <p>Sont interdits : les propos haineux, discriminatoires, harcelants ou diffamatoires, les contenus illicites, la publicité et le spam, l'usurpation d'identité, et la publication de données personnelles d'autrui.</p>
    <h2>4. Modération</h2>
    <p>Chaque chronique et chaque profil peuvent être signalés. MyRapFr examine les signalements et peut masquer une chronique, effacer une photo de profil, un nom affiché ou une bio, ou suspendre un compte en cas d'abus, conformément à la loi pour la confiance dans l'économie numérique (LCEN) et au règlement européen sur les services numériques (DSA). Chaque décision est notée dans un journal conservé un an. Pour contester une décision, écris à l'adresse de contact.</p>
    <p>Tu peux aussi bloquer un membre depuis son profil : il ne peut plus te suivre ni voir ton profil, et vous ne voyez plus vos chroniques respectives.</p>
    <h2>5. Contenus du catalogue</h2>
    <p>Les pochettes, photos et noms d'albums appartiennent à leurs auteurs et ayants droit. Ils sont présentés à des fins d'information et de critique. Toute demande de retrait est traitée sous 72 heures : <a href="mailto:${config.contactEmail}">${config.contactEmail}</a>.</p>
    <h2>6. Disponibilité</h2>
    <p>Le service est fourni tel quel, sans garantie de disponibilité permanente. MyRapFr peut évoluer ou s'arrêter ; dans ce cas, tu seras prévenu et pourras exporter tes données.</p>
    <h2>7. Résiliation</h2>
    <p>Tu peux supprimer ton compte à tout moment depuis tes paramètres.</p>
    <h2>8. Droit applicable</h2>
    <p>Ces conditions sont régies par le droit français. En cas de litige, une solution amiable sera recherchée avant toute action.</p>`);
}

export function legalNoticePage() {
  return doc('Mentions légales.', 'Informations exigées par la loi pour la confiance dans l’économie numérique (article 6).', html`
    <h2>Éditeur</h2>
    <p>${owner.name}<br>${owner.address}<br>Contact : <a href="mailto:${config.contactEmail}">${config.contactEmail}</a></p>
    <p>Directeur de la publication : ${owner.name}.</p>
    <h2>Hébergement</h2>
    <p>${owner.host}</p>
    <h2>Propriété intellectuelle</h2>
    <p>Le code, le design et les textes éditoriaux de MyRapFr sont protégés. Les pochettes, photos et marques citées appartiennent à leurs ayants droit respectifs.</p>
    <h2>Signaler un contenu</h2>
    <p>Utilise le bouton « Signaler » sous chaque chronique, ou écris à <a href="mailto:${config.contactEmail}">${config.contactEmail}</a>.</p>`);
}

export function sitemapPage({ albums, artists }) {
  return html`
  <section class="page-head"><h1 class="display">Plan du site.</h1></section>
  <section class="legal-body sitemap-cols">
    <div><h2>Pages</h2><ul>
      <li><a href="/">Accueil</a></li><li><a href="/albums">Albums</a></li><li><a href="/rappeurs">Rappeurs</a></li>
      <li><a href="/recherche">Recherche</a></li><li><a href="/inscription">Créer un compte</a></li><li><a href="/connexion">Connexion</a></li>
      <li><a href="/confidentialite">Confidentialité</a></li><li><a href="/cgu">Conditions d'utilisation</a></li>
      <li><a href="/mentions-legales">Mentions légales</a></li><li><a href="/cookies">Cookies</a></li>
    </ul></div>
    <div><h2>Rappeurs</h2><ul>${artists.map((a) => html`<li><a href="/rappeur/${a.slug}">${a.name}</a></li>`)}</ul></div>
    <div><h2>Albums</h2><ul>${albums.map((a) => html`<li><a href="/album/${a.slug}">${a.title}</a> <span>${a.artist.name}</span></li>`)}</ul></div>
  </section>`;
}

export function notFoundPage({ albums }) {
  return html`
  <section class="lost">
    <p class="lost-code" aria-hidden="true">404</p>
    <h1 class="display">Ce son n'existe pas.</h1>
    <p class="lede">La page a peut-être changé d'adresse, ou le lien est rayé. Voici de quoi te rattraper.</p>
    <div class="lost-covers">${albums.map((a) => tile(a))}</div>
    <p><a class="link-more link-more-lg" href="/albums">Tous les albums ${icon('chevron-right')}</a></p>
  </section>`;
}

export function offlinePage() {
  return html`
  <section class="page-head page-head-dark offline">
    <h1 class="display">Hors ligne.</h1>
    <p class="lede">Pas de connexion pour l'instant. Tes notes et chroniques t'attendent : réessaie dès que le réseau revient.</p>
    <p><a class="btn btn-primary" href="/">Réessayer</a></p>
  </section>`;
}
