# HANDBALL LEGENDS ハンドボール・レジェンズ

Jeu de handball **style animé / manga** pour Roblox, écrit entièrement en code (Luau + Rojo).
Les vraies règles du handball, avec des pouvoirs d'animé, des archétypes à collectionner, du classé, des groupes, des clans et des cosmétiques.

---

## 1. Ce qui est déjà dans le jeu

| Domaine | Contenu |
|---|---|
| **Modes** | 2v2, 3v3, 4v4, 5v5. Le terrain grandit avec le mode (66×38 → 104×56 studs), aux proportions officielles. |
| **Terrain** | Gymnase du lycée Seiryō : parquet, zones de 6 m, ligne pointillée des 9 m, point des 7 m, buts rayés rouge/blanc avec filets, gradins, bancs, banderoles, tableau d'affichage. |
| **Règles** | 3 secondes, 3 pas, dribble et reprise de dribble interdite, zone réservée au gardien, gardien hors zone, engagement après chaque but, jets francs repoussés aux 9 m, touches, corners, renvois, jets de 7 m, contacts (légal de face sur le porteur, faute par derrière ou sans ballon), avertissement → exclusion temporaire → carton rouge, jeu passif, mi-temps avec changement de côté, but en or en cas d'égalité. |
| **Mécaniques** | Dash, passe vers le coéquipier visé, tir chargé avec aperçu de trajectoire, saut et tir en suspension, interception de passe, contre, plongeon du gardien, contact physique. |
| **Archétypes** | 18 archétypes (3 par rareté : un Gardien, un Défenseur, un Attaquant), 54 pouvoirs hiérarchisés du Commun au Mythique. |
| **Pouvoirs** | 1 = mouvement (toutes les 15 s) · 2 = se charge en touchant le ballon (passes réussies, réceptions, interceptions, arrêts… avec anti-farm) · 3 = ultime (mur de glace, arrêt du temps, aveuglement, ralentissement général, super vitesse d'équipe, tir divin guidé…). |
| **Économie** | Hand Coins gagnés en match, 3 types de Balles (Classique, Dorée, Céleste) avec taux affichés et garantie Légendaire à 40 balles, doublons remboursés, **3 Balles offertes après la 1re partie**. |
| **Cosmétiques** | 24 objets (8 masques, 8 paires de gants, 8 paires de chaussures) en 3D, 6 raretés, Pack Cosmétique en Hand Coins ou en Robux. 100 % esthétique. |
| **Progression** | XP et niveaux (niveau 10 ≈ 15 matchs), une tenue débloquée tous les 10 niveaux (toujours rouge ou bleue selon l'équipe), classé à partir du niveau 10 (3v3 et plus) avec 7 rangs et des divisions. |
| **Social** | Groupes jusqu'à 5 (inviter, exclure, chef), recherche en groupe, entraînement entre amis (avec ou sans bots), clans à 1 000 Robux (emblème, bannière, couleurs, accent de tenue, rôles Chef/Officier/Membre, 30 membres). |
| **Menus** | Écran titre animé, puis lobby façon Rivals : JOUER (Normal, Classé, Entraînement), CASIER, BOUTIQUE, CLAN, Tutoriel, Nouveautés. Panneau de groupe, profil (niveau, XP, rang), Hand Coins. |
| **Visuel** | Interface sobre façon gros jeux (police Builder Sans, surfaces sombres, un seul accent orange), quartier japonais au coucher du soleil, animations procédurales des personnages, effets 3D (ondes, poussière, auras, explosion au but), « GOAL » à chaque but. |
| **Serveurs** | Lobby, puis téléportation vers un serveur de match réservé, comme Rivals. File d'attente partagée entre tous les serveurs. En Studio, le match se joue sur place, avec des bots si tu es seul. |
| **Sécurité** | Le serveur décide de tout. Chaque remote est limitée en débit et valide ses arguments. Les données sont sauvegardées avec verrouillage de session (pas de duplication), en sauvegarde automatique et à la fermeture. Les achats Robux sont idempotents. |

---

## 2. Installer les outils (une seule fois)

1. **Roblox Studio** : https://create.roblox.com/ → *Commencer à créer*.
2. **Rokit** (gestionnaire d'outils) : https://github.com/rojo-rbx/rokit#installation
   - Windows : télécharge `rokit-...-windows-x86_64.zip`, lance `rokit.exe self-install`, puis redémarre ton terminal.
3. Dans le dossier du projet :
   ```bash
   rokit install
   ```
   Cela installe **Rojo**, **Selene** et **StyLua** aux versions du fichier `rokit.toml`.
4. **Plugin Rojo pour Studio** :
   ```bash
   rojo plugin install
   ```

## 3. Ouvrir le jeu dans Studio

**Option A : générer un fichier.**
```bash
rojo build -o HandballLegends.rbxl
```
Ouvre ensuite `HandballLegends.rbxl` dans Studio.

**Option B : synchroniser en direct** (recommandé pendant le développement).
```bash
rojo serve
```
Dans Studio, ouvre l'onglet **Plugins → Rojo → Connect**. Chaque modification du code apparaît dans Studio.

## 4. Réglages obligatoires dans Studio

Dans **Accueil → Paramètres du jeu** (Game Settings) :

1. **Avatar → Type d'avatar : R6**. Le jeu est pensé pour R6, comme Blue Lock Rivals.
2. **Sécurité → Activer l'accès Studio aux services API**. Sans ce réglage, la sauvegarde est désactivée en Studio et un profil temporaire est utilisé.

> Le réglage Avatar est stocké sur l'expérience. Il doit être fait une fois que le jeu est publié (voir § 6).

## 5. Tester

- **Seul** : bouton **Play** → JOUER → Normal → 3v3 → Rechercher. Au bout de 6 secondes, des **bots** complètent les équipes. Tu peux aussi choisir Entraînement avec les bots activés.
- **À plusieurs** : onglet **Test → Clients et serveurs → 2 à 8 joueurs → Démarrer**. Invite les autres fenêtres dans ton groupe et lance une recherche.
- **En cas d'erreur** : ouvre **Affichage → Sortie (Output)** et copie-moi les lignes rouges.

### Commandes
| Action | PC | Manette | Mobile |
|---|---|---|---|
| Tir (maintenir pour charger) | Clic gauche | R2 | TIR |
| Passe vers le coéquipier visé | E | X | PASSE |
| Dash | Shift | B | DASH |
| Dribble / reprendre le ballon | R | L1 | DRIB. |
| Interception / contact | F | Y | CONTRE |
| Pouvoirs 1, 2, 3 | 1, 2, 3 | ◀ ▲ ▶ | Touches de la barre |
| Verrouiller la caméra | Ctrl | — | — |

## 6. Mettre en ligne

1. Dans Studio : **Fichier → Publier sur Roblox**. Choisis un nom (*Handball Legends*) et une description.
2. **Paramètres du jeu** :
   - Avatar → **R6** ;
   - Sécurité → **Activer l'accès Studio aux services API** ;
   - Autorisations → **Public** quand tu es prêt.
3. Sur le **Creator Hub** (create.roblox.com → ton expérience) :
   - **Icône** et **Miniatures** : à fournir toi-même (captures du jeu en Studio, ou visuels faits par un graphiste). Le projet n'en contient pas.
4. Pour chaque mise à jour : republie depuis Studio, puis ajoute une note en haut de `src/shared/Data/PatchNotes.luau`. Elle s'affiche dans le menu Nouveautés, avec une pastille rouge pour les joueurs qui ne l'ont pas encore lue.

> **Important :** les matchs en ligne utilisent des serveurs réservés du *même* lieu. Il n'y a rien d'autre à configurer, mais les téléportations ne fonctionnent qu'en jeu publié, pas dans Studio.

## 7. Robux (produits pour développeurs)

Creator Hub → ton expérience → **Monétisation → Produits pour développeurs** → crée :

| Clé dans `Config.Products` | Produit | Prix conseillé |
|---|---|---|
| `CosmeticPack` | 1 Pack Cosmétique | 99 R$ |
| `CosmeticPack5` | 5 Packs Cosmétiques | 399 R$ |
| `ClanCreation` | Création de clan | 1 000 R$ |
| `Coins1000` | 1 000 Hand Coins | 99 R$ |
| `Coins5000` | 5 500 Hand Coins | 449 R$ |

Copie chaque **ID** dans `src/shared/Config.luau` → `Config.Products`. Un produit à `0` reste affiché « Bientôt ». En Studio, la création de clan est gratuite tant que le produit n'est pas configuré, pour pouvoir tester.

> Roblox impose d'afficher les taux des objets aléatoires payants : la boutique les montre (bouton TAUX).

## 8. Sons

Le jeu n'utilise aucune image importée : toute l'interface est construite en code. Les sons sont facultatifs : importe tes fichiers audio (Creator Hub → Audio), puis colle leurs identifiants dans `src/client/UI/Theme.luau` → `Theme.Sounds`. Sans identifiant, le jeu reste silencieux, sans erreur.

## 9. Organisation du code

```
src/
├── shared/                 (ReplicatedStorage.Shared — lisible par le client)
│   ├── Config.luau          réglages : modes, règles, pouvoirs, économie, Robux
│   ├── Court.luau           géométrie du terrain (zones, 9 m, 7 m, formations)
│   ├── BallMath.luau        physique du ballon (serveur ET client)
│   ├── Net.luau             liste de tous les remotes
│   ├── Types.luau
│   ├── Data/                archétypes, raretés, packs, cosmétiques, niveaux,
│   │                        clans, tutoriel, notes de mise à jour
│   └── Util/                Signal, mise en forme
├── server/                 (ServerScriptService — invisible pour le client)
│   ├── init.server.luau     SEUL script serveur : init() puis start()
│   ├── Lib/                 remotes sécurisés, limiteur, validation, rôle du serveur
│   ├── Systems/             PlayerData, Shop, Locker, Clan, Party, Matchmaking,
│   │                        Matches, Progression, Lobby
│   └── Match/               Match (règles), Ball, Abilities (pouvoirs), Bots,
│                            CourtBuilder (gymnase), Outfit (tenues, cosmétiques)
└── client/                 (StarterPlayerScripts)
    ├── init.client.luau     SEUL script client
    ├── Controllers/         État, écran titre, lobby, HUD, contrôles, ballon,
    │                        animations des personnages, effets 3D
    ├── Screens/             pages du lobby (Casier, Boutique, Clan, Tutoriel…)
    └── UI/                  thème, composants, pages, cartes
```

## 10. Équilibrer et ajouter du contenu

- **Tout l'équilibrage** est dans `src/shared/Config.luau` : durée des mi-temps, vitesse des tirs, rayon d'arrêt du gardien, gains d'énergie, récompenses, prix…
- **Ajouter un archétype** : une entrée dans `Data/Archetypes.luau` (3 pouvoirs composés d'effets existants). Il apparaît automatiquement dans les balles, le casier et le choix du poste.
- **Ajouter un cosmétique** : une entrée dans `Data/Cosmetics.luau` (pièces 3D décrites en données).
- **Taux des balles** : `Data/Packs.luau`.

## 11. Vérifier le code

```bash
stylua --check src        # mise en forme
selene src                # linter (la 1re fois : selene generate-roblox-std)
rojo build -o test.rbxl   # le projet se construit
```

## 12. Ce qui reste à faire

- Le code passe la vérification de types (luau-lsp avec les définitions Roblox), le formatage et le build Rojo. Il **n'a pas encore été lancé dans Roblox Studio** : la première session de test servira à corriger les détails (sensations, vitesses, placements).
- **Animations** : elles sont procédurales (calculées en code). Elles ne fonctionnent qu'avec des avatars **R6** : pense au réglage du § 4.
- **Sons** : à importer, voir § 8.
- **Matchmaking classé** : la tolérance de niveau s'élargit avec l'attente. À ajuster selon le nombre de joueurs.
