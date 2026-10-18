# HANDBALL LEGENDS

Jeu de handball façon animé de sport (Haikyuu / Volleyball Legends) pour Roblox, écrit en code (Luau + Rojo).

---

## 1. Le jeu

| Domaine | Contenu |
|---|---|
| **Lobby** | Cour d'un lycée japonais où l'on marche : lycée avec horloge, gymnase, cerisiers, abri à vélos, distributeurs. Les bâtiments, la rue et les collines ferment tout l'horizon. |
| **Lancer une partie** | Des **terrains physiques** dans la cour, comme Volleyball Legends : marche sur une case rouge ou bleue. Terrain plein → 5 s → match. Terrains Normal 2v2 à 5v5, Classé 3v3 à 5v5 (niveau 10 requis), Entraînement contre des bots. Le chef d'un groupe emmène ses membres dans son équipe. |
| **Match** | 2 × 2 min 30 pour tous les modes, but en or d'1 min en cas d'égalité, puis match nul. Terrains moyens (100×56 en 2v2 → 160×84 en 5v5). Gymnase de lycée façon Haikyuu. |
| **Règles** | 3 secondes de possession max, zone réservée au gardien, contact de face sur le porteur autorisé, contact par derrière ou sur un joueur sans ballon = jet franc. Touches, renvois, engagement après but. |
| **Contrôles** | Course rapide, saut haut, dash (même en l'air), caméra à l'épaule. **Tir au timing** : maintiens TIR, un curseur fait des allers-retours, relâche dans la zone dorée pour un tir parfait (tir de feu). |
| **Archétypes** | 18 archétypes, 6 raretés, 3 pouvoirs chacun (P1 toutes les 15 s, P2 chargé en touchant le ballon, P3 ultime). Obtenus dans des Balles en Hand Coins. 3 balles offertes après la 1re partie. Gardien humain choisi au début du match. |
| **Écrans** | Seulement 4 boutons dans le lobby : ARCHÉTYPES (balles, collection, cosmétiques, tenues, Hand Coins), CLAN, GROUPE, INFOS (tutoriel, nouveautés). |
| **Serveurs** | Lobby, puis serveur de match réservé (comme Rivals). Dans Studio, le match se joue sur place, avec des bots. |
| **Sécurité** | Le serveur décide de tout : vitesses contrôlées, note du tir calculée par le serveur, remotes limités en débit et validés, données sauvegardées avec verrouillage de session, achats Robux idempotents. |

---

## 2. Installer les outils (une seule fois)

1. **Roblox Studio** : https://create.roblox.com/
2. **Rokit** : https://github.com/rojo-rbx/rokit#installation, puis dans le dossier du projet :
   ```bash
   rokit install
   rojo plugin install
   ```

## 3. Ouvrir le jeu

```bash
rojo build -o HandballLegends.rbxl   # puis ouvre le fichier dans Studio
# ou, pendant le développement :
rojo serve                           # Studio : Plugins → Rojo → Connect
```

Dans **Accueil → Paramètres du jeu** :
1. **Avatar → R6** (obligatoire pour les animations).
2. **Sécurité → Activer l'accès Studio aux services API** (sinon un profil temporaire est utilisé).

## 4. Tester

- **Seul** : Play → marche sur n'importe quel terrain → au bout de 6 s le match part avec des bots.
- **À plusieurs** : onglet **Test → Clients et serveurs → 2 à 8 joueurs**.
- **Erreur** : **Affichage → Sortie (Output)**, copie-moi les lignes rouges.

| Action | PC | Manette | Mobile |
|---|---|---|---|
| Tir (maintenir, relâcher au bon moment) | Clic gauche | R2 | TIR |
| Passe vers le coéquipier visé | E | X | PASSE |
| Dash | Shift | B | DASH |
| Contact / interception | F | Y | CONTRE |
| Pouvoirs 1, 2, 3 | 1, 2, 3 | ◀ ▲ ▶ | Boutons ronds |
| Verrouiller la caméra | Ctrl | — | — |

## 5. Ressources à importer (pour la vraie qualité)

Le jeu marche sans rien importer (tout a une version faite en code), mais **les animations et les modèles importés font toute la différence**. Tout se déclare dans `src/shared/Assets.luau`.

### Animations (le plus important)

Roblox n'accepte que les animations publiées par **ton compte** (ou ton groupe). Deux façons :
- **Les créer** : Studio → onglet **Avatar → Éditeur d'animations**, sur un rig **R6** (Avatar → Constructeur de rig → R6). Ou avec le plugin **Moon Animator**.
- **Les reprendre** : prends une animation R6 libre du Creator Store, ouvre-la dans l'éditeur d'animations et **republie-la sur ton compte**.

Puis : clic droit sur l'animation publiée → copier l'ID → colle `rbxassetid://ID` dans `Assets.Animations` :

| Nom | Ce que c'est | Boucle |
|---|---|---|
| `Idle` | Attente sur place, appuis légers | Oui |
| `Run` | Course rapide (obligatoire avec `Idle` pour activer les animations importées) | Oui |
| `Sprint` | Course à pleine vitesse | Oui |
| `Jump` / `Fall` | Impulsion de saut / chute | Non / Oui |
| `Dash` | Élan court | Non |
| `ShootCharge` | Bras armé derrière la tête pendant la charge | Oui |
| `Shoot` | Tir en suspension | Non |
| `Pass` | Passe à une main | Non |
| `Catch` | Réception à deux mains | Non |
| `Dive` | Plongeon latéral du gardien | Non |
| `Block` | Bras levés (contre) | Non |
| `Contact` / `Stunned` | Contact d'épaule / déséquilibre | Non |
| `Celebrate` | Célébration de but | Non |
| `KeeperReady` | Posture du gardien, genoux fléchis | Oui |

### Sons (`Assets.Sounds`)

Creator Store → **Audio** → cherche puis copie l'ID : sifflet d'arbitre (`Whistle`), foule qui explose (`Goal`, `Crowd`), frappe de ballon (`Shot`, `PerfectShot`), rebond (`Bounce`), whoosh (`Dash`, `Power`, `Ultimate`), clics d'interface (`Click`, `Hover`), musique d'ambiance (`LobbyMusic`, `MatchMusic`). Prends des sons publiés par Roblox ou marqués libres d'utilisation.

### Modèles (facultatif)

Crée un dossier **ServerStorage → Assets** et mets-y, avec exactement ces noms :

| Nom | Ce que c'est |
|---|---|
| `LobbySchool` | Bâtiment de lycée (remplace la façade faite en code). |
| `Cerisier` | Un cerisier ; il est cloné dans la cour. |
| `Gymnase` | Intérieur de gymnase. Il doit contenir une Part nommée **`Centre`** au centre du sol : le terrain, les lignes et les buts sont posés dessus. |

Vérifie toujours qu'un modèle du Creator Store ne contient **aucun Script** (risque de virus) avant de l'utiliser.

## 6. Mettre en ligne

1. **Fichier → Publier sur Roblox**.
2. Paramètres du jeu : Avatar **R6**, accès Studio aux services API, puis **Public** quand tu es prêt.
3. Creator Hub : ajoute une icône et des miniatures (des captures du jeu font très bien l'affaire).
4. À chaque mise à jour : ajoute une note en haut de `src/shared/Data/PatchNotes.luau` (onglet Nouveautés, pastille rouge pour les joueurs).

Les téléportations vers les serveurs de match ne fonctionnent qu'en jeu publié.

## 7. Robux

Creator Hub → **Monétisation → Produits pour développeurs**, puis copie chaque ID dans `src/shared/Config.luau` → `Config.Products` :

| Clé | Produit | Prix conseillé |
|---|---|---|
| `CosmeticPack` | 1 Pack Cosmétique | 99 R$ |
| `CosmeticPack5` | 5 Packs Cosmétiques | 399 R$ |
| `ClanCreation` | Création de clan | 1 000 R$ |
| `Coins1000` | 1 000 Hand Coins | 99 R$ |
| `Coins5000` | 5 500 Hand Coins | 449 R$ |

Un produit à `0` reste affiché « Bientôt ». Les taux des balles sont affichés (obligation Roblox).

## 8. Organisation du code

```
src/
├── shared/            Config (équilibrage), Court (terrain), BallMath, ShotTiming (tir au timing),
│                      Assets (ressources importées), Net (remotes), Types, Data/ (archétypes, balles…)
├── server/
│   ├── init.server.luau   seul script serveur
│   ├── Lib/               remotes sécurisés, limiteur, validation
│   ├── Systems/           PlayerData, Shop, Locker, Clan, Party, Lobby, Pads (terrains du lobby),
│   │                      Matchmaking (lancement), Matches, Atmosphere
│   └── Match/             Match (règles), Ball, Abilities (pouvoirs), Bots, CourtBuilder (gymnase), Outfit
└── client/
    ├── init.client.luau   seul script client
    ├── Controllers/       LoadingScreen, LobbyHUD, PadClient, MatchInput, CameraController,
    │                      CharacterAnimator, Effects3D, MatchHUD, MatchFX…
    ├── Screens/           Archétypes, Clan, Tutoriel, Nouveautés
    └── UI/                Theme, Kit (composants), Page, Cards
```

Tout l'équilibrage (vitesses, durées, récompenses, prix, zone du tir parfait) est dans `Config.luau` et `ShotTiming.luau`.

## 9. État actuel

Le code passe la vérification de types et le build, mais **n'a pas encore été lancé dans Roblox Studio** : la première session de test servira à régler les sensations (vitesses, caméra, timing) et à corriger les détails.
