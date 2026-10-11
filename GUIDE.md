# MyRapFr — tout ce que tu dois savoir

Ce guide explique ce qui est en place, ce qui reste à faire de ton côté, et comment mettre le site en ligne depuis ton PC sans rien dépenser.

---

## 1. Ce qui est fait

### Le site
- **Accueil** :
  - un héros plein écran avec un mur de pochettes qui dérive lentement ;
  - une section Albums avec une séquence de dézoom à la manière des pages iPhone ou Mac, une frise des décennies qui défile à l'horizontale et des titres dont la vitesse suit celle du scroll ;
  - une section Rappeurs avec des portraits dévoilés par masque et une liste où le portrait suit le curseur en WebGL ;
  - un À propos dont le texte s'allume mot à mot ;
  - un seul appel à l'action : « Créer mon compte ».
- **Catalogue** : les discographies complètes (albums, mixtapes, EP) d'environ 220 rappeurs et groupes, plus une sélection éditoriale de 148 classiques. Filtres par décennie, par type et par texte, tri, chargement continu. Chaque album a sa page : note moyenne, répartition des notes, chroniques, albums du même artiste.
- **Rappeurs** : une fiche par artiste avec biographie (rédigée, ou résumé Wikipédia avec sa source) et discographie séparée en albums et EP.
- **Fonctions sociales, comme Letterboxd** :
  - compte et profil public ;
  - « Écouté », « Coup de cœur », « À écouter » ;
  - note en demi-étoiles et journal d'écoute daté ;
  - chroniques, j'aime et signalements ;
  - listes et 4 albums favoris ;
  - suivre des membres : deux abonnements réciproques font des **amis** ;
  - fil d'actu.
- **Mouvement** :
  - défilement doux avec inertie (Lenis) ;
  - parallaxe, révélations par `clip-path` et masques (GSAP ScrollTrigger) ;
  - transition d'image entre une vignette et la page album (View Transitions) ;
  - légère distorsion WebGL au survol des vignettes (Three.js), uniquement sur ordinateur.
- Tout le mouvement est coupé si le système demande « réduire les animations ». Le site reste complet sans JavaScript.

### Confort et finitions
| Fonction | Où / comment |
|---|---|
| Mode sombre / clair | Bouton lune / soleil dans la barre du haut ; le choix est retenu sur l'appareil |
| Recherche sur tout le site | Loupe, touche `/` ou `Ctrl` + `K` sur n'importe quelle page : résultats instantanés (rappeurs, albums, membres), navigation au clavier |
| Retour en haut | Bouton rond en bas à droite, avec un anneau qui indique la progression dans la page |
| Menu mobile | Plein écran, animé, avec les liens de compte |
| Animation de chargement | Écran « disque » à la première page de la visite, puis squelettes animés sur les pochettes en cours de chargement |
| Copier | Sous chaque chronique, sur les biographies, « Copier le titre » sur les albums |
| Partager | Albums, rappeurs, listes, profils : copie le lien (ou ouvre le partage du téléphone) avec des paramètres UTM |
| Menu qui reste en haut | La barre de navigation est fixe sur toutes les pages |
| Œil sur les mots de passe | Sur tous les champs mot de passe (connexion, inscription, paramètres) |
| Suivi UTM | Compteurs anonymes par campagne côté serveur ; `npm run stats:utm` affiche visites et inscriptions par campagne (90 jours) |
| Date de mise à jour | En pied de page : « Catalogue mis à jour le … » |
| Effets | Corridor de pochettes en 3D dans le héros, titres lettre par lettre, apparitions floues, reflet et distorsion WebGL au survol des pochettes, inclinaison et reflet sur la pochette d'un album, boutons magnétiques, chiffres animés, barre de lecture, grain discret, transitions entre pages |

### Les pages et contrôles demandés
| Demande | Où |
|---|---|
| RGPD | `/confidentialite` ; export JSON et suppression du compte dans `/compte` |
| CGU | `/cgu` |
| Mentions légales | `/mentions-legales` (à compléter, voir §2) |
| Consentement cookies | Bandeau en bas de page, page `/cookies` avec « Modifier mon choix » |
| API front-end | `/api/v1/…`, documentée dans le README |
| HTTPS | `npm run cert` en local ; Cloudflare Tunnel en ligne (§4) |
| Meta title et description | Uniques sur chaque page, générés côté serveur |
| Image de partage réseaux sociaux | Une générale et une par album (`/img/og/…`), balises Open Graph et Twitter |
| Favicon | SVG, ICO, icône Apple, manifeste d'application |
| Sitemap et robots.txt | `/sitemap.xml` (tous les albums et rappeurs) et `/robots.txt` |
| Images compressées | WebP en 3 tailles (300, 600, 1200 px) avec `srcset` et chargement différé ; 4 Ko en moyenne par pochette provisoire en 600 px (compte plutôt 40 à 80 Ko pour une vraie photo) |
| Vitesse | Lighthouse : **100/100 en performance** sur toutes les pages testées |
| Contraste | Tous les couples de couleurs au niveau WCAG AA ; Lighthouse : **100/100 en accessibilité** |
| Page 404 | Personnalisée, avec 4 albums au hasard |
| Liens cassés | `npm run check:links` : 1 117 adresses vérifiées, aucun lien cassé |
| Validation des formulaires | Dans le navigateur, en français, champ par champ ; revérifiée côté serveur |
| Anti-spam | Champ piège invisible, jeton horodaté signé (refus si le formulaire est rempli en moins de 2,5 s), limitation des tentatives par adresse IP, refus des textes bourrés de liens, e-mail confirmé obligatoire pour publier |
| Un seul CTA | « Créer mon compte » (« Ouvrir mon carnet » une fois connecté) |

### Les tests
`npm test` lance 10 scénarios de bout en bout, tous verts :
- inscription et doublons ;
- connexion ;
- protection CSRF ;
- injection HTML ;
- amis ;
- listes ;
- export et suppression RGPD ;
- mot de passe oublié.

---

## 2. À faire de ton côté avant la mise en ligne

1. **Remplir les mentions légales.** Copie `.env.example` en `.env` et renseigne `OWNER_NAME`, `OWNER_ADDRESS`, `HOST_INFO` et `CONTACT_EMAIL`. C'est obligatoire en France (loi LCEN, article 6). Une personne physique peut demander à ne pas afficher son adresse, mais seulement si un hébergeur professionnel détient son identité. En auto-hébergement, tu es toi-même l'hébergeur.
2. **Créer l'adresse e-mail de contact**, par exemple `contact@ton-domaine.fr`.
3. **Brancher un service d'e-mail.** Aujourd'hui, les liens de confirmation et de mot de passe oublié s'affichent dans la console du serveur. Pour le site en ligne, il faut un service SMTP. Brevo est gratuit jusqu'à 300 e-mails par jour et basé en France. Le branchement se fait dans un seul fichier : `server/mailer.js`.
4. **Récupérer les vraies pochettes** (§3) et relire les biographies, qui sont courtes et rédigées pour le site.
5. **Compléter la liste des rappeurs si besoin.** Pour suivre un artiste de plus, ajoute son nom (tel qu'il apparaît sur Deezer) dans la liste `roster` de `catalogue.js`, à la racine du projet : toute sa discographie arrivera au prochain démarrage. Le fichier `data/discover-report.json` liste les artistes introuvables et l'identité Deezer retenue pour chacun, à vérifier en cas d'homonyme.
6. Lancer `npm run check:links`, `npm run check:perf` et `npm test` une dernière fois.

---

## 3. Les pochettes et photos

### Tout arrive tout seul
Au **premier `npm start`** sur un ordinateur relié à internet, le serveur travaille en arrière-plan. Le site reste utilisable pendant ce temps, et la console affiche la progression (lignes `[catalogue]`).

1. **Discographies** (environ 2 minutes la première fois, au rythme maximal autorisé par Deezer : 50 requêtes toutes les 5 secondes) : pour chacun des 220 rappeurs et groupes de la liste, Deezer fournit tous ses albums, mixtapes et EP.
   - Quatre artistes sont traités en même temps, et leurs pochettes se téléchargent pendant que les suivants sont cherchés.
   - Chaque artiste apparaît sur le site **dès que sa discographie est récupérée**, avec ses pochettes. La page Albums affiche l'avancement (« 85 / 218 artistes »).
   - Si tu arrêtes le serveur en cours de route, rien n'est perdu : au prochain démarrage, la récupération reprend là où elle s'était arrêtée.
   - Les singles, lives, compilations et versions instrumentales sont écartés.
   - Les rééditions (deluxe, collector…) sont fusionnées avec l'original.
   - En cas d'homonyme, l'artiste retenu est celui dont la discographie est surtout du rap.
   - Les artistes sans biographie rédigée reçoivent le résumé de leur page Wikipédia, avec la source citée, si elle parle bien de rap.
2. **Pochettes et photos** : elles viennent de Deezer, puis, si besoin, d'Apple Music, MusicBrainz, TheAudioDB ou Wikipédia. La photo d'un artiste vient de son profil Deezer vérifié (celui dont la discographie est du rap) ; les sources de secours doivent elles aussi confirmer qu'il s'agit d'un rappeur. Chaque image est contrôlée : bon titre, bon artiste, au moins 250 px.
3. **Images du site** : chaque pochette est compressée en WebP au moment où quelqu'un la regarde pour la première fois, puis gardée sur le disque. Rien à lancer.

Ensuite, les discographies sont revérifiées **chaque semaine** : les nouvelles sorties apparaissent seules. Les images manquantes sont recherchées à nouveau toutes les 6 heures.

Pour relancer à la main :

```bash
npm run catalogue:fetch             # discographies + images manquantes
npm run catalogue:fetch -- --images # images seulement
npm run catalogue:fetch -- --force  # re-télécharge toutes les images
```

Pour désactiver la mise à jour automatique, ajoute `AUTO_FETCH=0` dans `.env`.

Pour vérifier ou corriger le résultat :
- `data/discover-report.json` liste les artistes introuvables et l'identité Deezer retenue pour chacun (nombre de fans, part de rap) ;
- `data/fetch-report.json` liste les images introuvables ou incertaines ;
- **pour imposer une image précise** (une photo qui ne te plaît pas, une pochette incorrecte) : dépose-la dans `data/sources/manuel/artists/<identifiant>.jpg` ou `data/sources/manuel/covers/<identifiant-de-l-album>.jpg`, puis redémarre le serveur. Une image de ce dossier passe avant toutes les autres et n'est jamais remplacée automatiquement. L'identifiant est la fin de l'adresse de la page : `pnl` pour /rappeur/pnl, `booba-temps-mort` pour /album/booba-temps-mort.

### Le droit d'auteur : à lire
- Les pochettes et les photos sont **protégées par le droit d'auteur**. En France, il n'existe pas de « fair use » à l'américaine.
- Letterboxd utilise des images sous licence (base TMDB). Rate Your Music et Discogs hébergent des pochettes en tolérance, avec retrait sur demande. Le risque reste faible pour un site non commercial qui crédite et retire vite, mais **il n'est pas nul**.
- Ce qui est en place pour limiter ce risque :
  - un crédit sous chaque pochette ;
  - une mention en pied de page avec une adresse de retrait ;
  - un engagement de retrait sous 72 h dans les CGU ;
  - les images téléchargées ne sont pas publiées sur GitHub (`data/sources/` est ignoré).
- **L'API Deezer** impose de créditer Deezer et réserve un usage non commercial. Si tu monétises un jour, il faudra des licences ou une API qui l'autorise.
- **Les photos d'artistes** posent aussi la question du droit à l'image. Les plus sûres sont celles de Wikimedia Commons sous licence libre : il faut citer l'auteur et la licence.

---

## 3 bis. Dépannage

`npm start` vérifie d'abord ton installation et affiche ce qui bloque, en français :
- **« le port est déjà utilisé »** : le site tourne déjà dans une autre fenêtre de commande. Ouvre simplement https://localhost:8443, ou ferme l'autre fenêtre (Ctrl+C) et relance `npm start`.
- **« les dépendances ne sont pas installées »** : lance `npm install` dans le dossier du site.
- **« Node.js est trop ancien »** : installe la version LTS sur https://nodejs.org/, puis rouvre l'invite de commandes.
- **« Missing script: start » ou « ENOENT package.json »** : l'invite de commandes n'est pas dans le bon dossier. Après avoir décompressé le ZIP, entre dans le dossier qui contient `package.json` (`cd` puis glisse le dossier dans la fenêtre).
- **Le navigateur affiche une alerte de sécurité** : c'est normal en local avec le certificat auto-signé. Clique sur « Paramètres avancés », puis « Continuer vers localhost ».

---

## 4. Héberger depuis ton PC, gratuitement

### La méthode conseillée : Cloudflare Tunnel
Ton PC ouvre une connexion sortante vers Cloudflare, qui sert le site au public :
- **aucun port** de ta box n'est ouvert ;
- **ton adresse IP n'est pas exposée** ;
- **HTTPS est automatique** ;
- tu bénéficies d'une protection contre les attaques par saturation (DDoS).

1. **Tester sans rien payer :**
   ```bash
   npm start
   cloudflared tunnel --url http://localhost:8080
   ```
   Tu obtiens une adresse temporaire en `https://xxx.trycloudflare.com`. Pour l'installer, [télécharge cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/).
2. **Pour une vraie adresse :** achète un nom de domaine (environ 10 € par an pour un `.fr`, chez OVH, Gandi ou Cloudflare). Ajoute-le à un compte Cloudflare gratuit, puis crée un tunnel nommé ([documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/)).
3. Dans `.env` :
   ```
   NODE_ENV=production
   PUBLIC_URL=https://ton-domaine.fr
   TRUST_PROXY=1
   BEHIND_TLS_PROXY=1
   ```
   Retire alors le dossier `certs/`, puisque Cloudflare gère HTTPS.

### Les limites d'un PC personnel
- Le site est hors ligne dès que le PC est éteint, en veille, ou que la box redémarre. Désactive la mise en veille et lance le serveur au démarrage, par exemple avec [pm2](https://pm2.keymetrics.io/) : `npm i -g pm2 && pm2 start npm --name myrapfr -- start && pm2 save`.
- Tes données et celles des membres sont sur ce disque : **sauvegarde chaque jour** (§5).
- Quand le site grandit, la suite logique est un petit serveur loué en Europe, à partir de 4 € par mois chez Hetzner, OVH ou Scaleway. Le code est prêt à y être déplacé tel quel.

---

## 5. La sécurité

### Déjà en place
- **Mots de passe** :
  - hachés avec scrypt, jamais stockés en clair ;
  - 10 caractères minimum, mots de passe courants refusés ;
  - même message d'erreur que le compte existe ou non (impossible de deviner qui est inscrit).
- **Sessions** :
  - jeton aléatoire dans un cookie `HttpOnly`, `Secure` et `SameSite=Lax`, préfixe `__Host-` en HTTPS ;
  - le serveur ne garde qu'une empreinte du jeton ;
  - expiration à 30 jours ;
  - bouton « Déconnecter partout » ;
  - les autres appareils sont déconnectés quand le mot de passe change.
- **CSRF** : vérification de l'origine de chaque requête qui modifie des données, plus un jeton propre à la session.
- **XSS** :
  - tout texte de membre est échappé à l'affichage, ce qui est testé ;
  - une **Content Security Policy** stricte n'autorise que les scripts, styles et images du site lui-même, sans aucun script en ligne.
- **En-têtes** :
  - Helmet : `X-Content-Type-Options`, `Referrer-Policy`, `frame-ancestors 'none'` contre le clickjacking ;
  - `Permissions-Policy` ;
  - HSTS en production.
- **Limitation des tentatives** : 10 connexions par 15 minutes, 5 inscriptions par heure, 120 requêtes API par minute et par adresse IP.
- **Validation** : chaque donnée reçue est revérifiée côté serveur (zod), avec une taille de requête limitée à 20 Ko.
- **Erreurs** : messages neutres pour le public, détails uniquement dans la console.
- **Aucune ressource externe** : pas de Google Fonts ni de CDN. Rien ne fuit vers des tiers, ce qui compte aussi pour le RGPD.
- **Secrets** : `data/secret.key`, la base et les certificats sont exclus de Git.
- **Fichier de contact sécurité** : `/.well-known/security.txt`.

### À faire régulièrement
- **Mettre à jour** : `npm outdated` puis `npm update`, et `npm audit` chaque mois. Garde aussi Windows ou macOS à jour.
- **Sauvegarder** : `npm run backup` chaque jour, via le Planificateur de tâches Windows ou cron. Copie `data/backups/` hors du PC, sur un disque externe ou un cloud chiffré.
- **Modérer** : les signalements sont dans la table `reports`. Il n'y a pas encore d'interface d'administration ; c'est la prochaine brique à construire.
- Si l'inscription attire des robots, ajoute **Cloudflare Turnstile**, une alternative gratuite au captcha qui respecte la vie privée.
- **Ne publie jamais** `.env`, `data/secret.key` ni la base de données.

---

## 6. Le RGPD, en pratique

- **Ce qui est collecté** : un pseudo, un e-mail, un mot de passe haché et ce que le membre publie. Pas de pistage, pas d'outil de mesure d'audience, pas de publicité.
- **Les droits** :
  - l'**export** et la **suppression** du compte se font en un clic dans les paramètres ;
  - la rectification se fait en modifiant son profil.
- **Les adresses IP** restent en mémoire vive le temps de la limitation anti-abus. Elles ne sont jamais écrites sur le disque.
- **Les cookies** : seul le cookie de session existe, et il est exempté de consentement selon la CNIL. Le bandeau informe et garde le choix. Si tu ajoutes un jour une mesure d'audience, il faudra la conditionner à l'acceptation : l'événement `consent-change` et la fonction `readConsent()` sont prêts dans `public/js/app.js`.
- **À faire** :
  - tenir un petit **registre des traitements** : un tableau qui reprend celui de la page Confidentialité suffit ;
  - savoir qu'en cas de fuite de données, il faut **prévenir la CNIL sous 72 h**.
- **L'âge minimum** est de 15 ans (majorité numérique en France), comme l'indiquent les CGU.

---

## 7. Les skills et le MCP utilisés

- **ui-ux-pro-max** a fourni le système de design de départ et les recommandations GSAP (parallaxe, révélations) et Three.js (libérer la mémoire graphique, lissage du pointeur). Ces recommandations ont été suivies.
- **impeccable** a fourni le plancher de qualité : contraste, focus, états, surfaces du navigateur thémées, aucune icône en emoji, un seul geste de mouvement par section. Son lanceur télécharge un exécutable externe : je ne l'ai pas lancé et j'ai lu ses règles directement.
- **Magic UI (MCP)** : le serveur MCP démarre bien, mais son catalogue en ligne était bloqué depuis l'environnement. J'ai donc lu le code des composants sur le dépôt GitHub de Magic UI et adapté trois idées en JavaScript simple, sans React :
  - le texte qui s'allume mot à mot (`text-reveal`) ;
  - la bande de titres sensible à la vitesse du scroll (`scroll-based-velocity`) ;
  - le flou progressif (`progressive-blur`).
- **Pas d'autres skills téléchargées sur internet.** Une skill est un ensemble d'instructions exécutées avec tes droits : en installer depuis une source inconnue est un vrai risque, et celles du dépôt suffisaient.

---

## 8. Prochaines étapes possibles

- Interface d'administration : traiter les signalements, suspendre un compte.
- Photo de profil (envoi d'image, à sécuriser).
- Commentaires sous les chroniques, notifications, blocage d'un membre.
- Pistes et durée des albums, liens d'écoute vers les plateformes.
- Statistiques annuelles du membre, sur le modèle du « Year in Review » de Letterboxd.
