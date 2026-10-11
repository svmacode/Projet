# MyRapFr

Le carnet d'écoute du rap français, sur le modèle de Letterboxd : noter les albums, tenir son journal d'écoute, écrire des chroniques, faire des listes et suivre ses amis.

- **Catalogue** : 148 albums et 86 artistes, de 1991 à 2023 (`data/catalogue.js`).
- **Design** : la charte d'Apple (noir, gris `#f5f5f7`, un seul bleu d'action), centré sur l'image, avec GSAP, Lenis et Three.js.
- **Serveur** : Node.js, Express et SQLite. Pas de base à installer, pas de service payant.

Le guide complet est dans [GUIDE.md](GUIDE.md) : hébergement depuis ton PC, sécurité, RGPD, droits d'auteur et mise en ligne.

## Démarrer en local

Prérequis : [Node.js 22.13 ou plus récent](https://nodejs.org/) (version LTS).

```bash
npm install          # installe les dépendances et copie GSAP, Lenis, Three.js et la police
npm run setup        # génère les images (pochettes provisoires, partage, icônes) et le certificat HTTPS
npm start            # https://localhost:8443
```

Pour voir le site avec quelques membres, notes et chroniques : `npm run demo` (mot de passe affiché à la fin).

## Commandes

| Commande | Rôle |
|---|---|
| `npm start` | Lance le site (HTTPS si un certificat existe, sinon HTTP sur le port 8080) |
| `npm run dev` | Pareil, avec redémarrage automatique quand tu modifies le code |
| `npm run catalogue:fetch` | Télécharge les vraies pochettes et photos (Deezer) dans `data/sources/` |
| `npm run images` | Compresse toutes les images en WebP, crée les images de partage et les icônes |
| `npm run backup` | Sauvegarde la base de données dans `data/backups/` |
| `npm test` | Tests automatiques de l'API (comptes, sécurité, amis, RGPD) |
| `npm run check:links` | Cherche les liens cassés sur tout le site (serveur lancé) |
| `npm run check:contrast` | Vérifie les contrastes de couleurs (WCAG AA) |
| `npm run check:perf` | Mesure vitesse, accessibilité et SEO avec Lighthouse (serveur lancé) |

## Organisation

```
server/          serveur Express : sécurité, API, rendu des pages
  views/         gabarits HTML (échappement automatique)
public/          CSS, JavaScript, images, icônes
  js/gl/         effets WebGL (Three.js) : distorsion au survol, portraits
data/            catalogue, base SQLite (non publiée), images sources (non publiées)
scripts/         images, certificat, récupération du catalogue, contrôles qualité
test/            tests de l'API
```

## API

Toutes les routes sont sous `/api/v1`. Elles répondent en JSON. Celles qui modifient des données demandent le jeton CSRF de la session, dans l'en-tête `X-CSRF-Token`.

| Méthode | Route | Rôle |
|---|---|---|
| POST | `/auth/register`, `/auth/login`, `/auth/logout` | Inscription, connexion, déconnexion |
| POST | `/auth/verify`, `/auth/forgot`, `/auth/reset` | Confirmation d'e-mail, mot de passe oublié |
| GET | `/albums`, `/albums/:slug` | Catalogue, détail d'un album avec ses chroniques |
| PUT | `/albums/:slug/state` | Écouté, coup de cœur, à écouter, note |
| POST | `/albums/:slug/reviews` | Publier une chronique |
| POST | `/reviews/:id/like`, `/reviews/:id/report` | Aimer, signaler |
| GET | `/artists`, `/artists/:slug`, `/search?q=` | Rappeurs, recherche |
| GET | `/users/:username` | Profil public |
| POST/DELETE | `/users/:username/follow` | Suivre ; deux abonnements réciproques font des amis |
| GET | `/feed` | Fil d'actu des membres suivis |
| POST | `/lists`, `/lists/:id/items` | Listes d'albums |
| GET/PUT/DELETE | `/me`, `/me/export` | Profil, export RGPD, suppression du compte |
