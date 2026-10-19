# HANDBALL LEGENDS

Jeu de handball compétitif façon animé pour Roblox (Luau + Rojo), construit phase par phase selon le cahier des charges du projet.

## État : Phase 1 — Fondation jouable

| Fait (code écrit, vérifié par typage et relecture) | Pas encore |
|---|---|
| Match complet : équipes → rôle → compte à rebours → 2 mi-temps → but en or → résultats | Archétypes, pouvoirs, XP, monnaies (phase 3) |
| Ballon autoritaire côté serveur : passes rapide / longue / haute / visée, tir rapide / chargé / en suspension | Menu principal, lobby, groupes, matchmaking (phase 4) |
| Défense : interceptions (fenêtre de timing), contres, contacts d'épaule | Classé (phase 5), cosmétiques et Robux (phase 6), clans (phase 7) |
| Gardien : arrêts selon placement et plongeon, captés ou repoussés | Postes détaillés (ailiers, arrières, pivot…) (phase 2) |
| Règles : 3 s, 3 pas, dribble et reprise, zone des 6 m, jets francs, 7 m, jeu passif, engagement, touches, corners, avertissement puis exclusion | Sons et animations originaux (à importer, voir plus bas) |
| Gymnase de lycée adapté à 2v2 / 3v3 / 4v4 / 5v5 | |
| HUD : score, chrono, 3 s, 3 pas, dribble, viseur, cible de passe, charge, dash, coups de sifflet expliqués, résultats | |
| Contrôles PC / manette / mobile, caméra à l'épaule | |
| Anti-triche : vitesses, dash, téléportation, remotes limités et validés | |

**Le jeu n'a pas encore été lancé dans Roblox Studio** : la phase 1 se termine quand tu l'as testé et que les retours sont corrigés.

## Lancer le jeu

1. Installe [Roblox Studio](https://create.roblox.com/) et [Rokit](https://github.com/rojo-rbx/rokit#installation), puis dans ce dossier : `rokit install`.
2. `rojo build -o HandballLegends.rbxl` et ouvre le fichier dans Studio (ou `rojo serve` + plugin Rojo).
3. **Paramètres du jeu → Avatar → R6** (obligatoire pour les animations).
4. **Play** : tu apparais dans la salle du club. Le panneau **MODE TEST — PHASE 1** lance un match (choisis le mode, coche « compléter avec des bots » pour jouer seul).
5. À plusieurs : **Test → Clients et serveurs → 4 joueurs**.
6. En cas d'erreur : **Affichage → Sortie (Output)**, copie les lignes rouges.

## Commandes

| Action | PC | Manette | Mobile |
|---|---|---|---|
| Tir (appui = rapide, maintien = chargé) | Clic gauche | R2 | TIR |
| Passe au coéquipier visé | E | X | PASSE |
| Passe haute (lob) | R | Y | LOB |
| Passe visée (dans l'espace) | T | Croix haut | VISÉE |
| Dash | C | B | DASH |
| Sprint | Shift (maintenir) | L3 | SPRINT |
| Dribble (avec ballon) / Contre (sans) | F | R1 | DRIB. |
| Interception / Plongeon (gardien) | Clic droit | L2 | INTER. |
| Contact d'épaule | V | Croix droite | CONTACT |
| Posture défensive | Ctrl gauche (maintenir) | L1 | GARDE |
| Saut | Espace | A | Saut |

## Ressources externes (facultatives)

Le code ne peut pas créer d'animations, de sons ni de modèles 3D de qualité. Tout se branche dans `src/shared/Assets.luau` ; un identifiant vide garde la version faite en code.

- **Animations R6** : à créer dans l'Éditeur d'animations de Studio (ou Moon Animator) et à publier sur **ton** compte ou ton groupe (Roblox refuse les animations d'autres créateurs). Colle `rbxassetid://ID` sur la bonne ligne.
- **Sons** : Creator Store → Audio (sons publiés par Roblox ou libres d'utilisation).

## Réglages

Tout l'équilibrage est dans `src/shared/Config.luau` : tailles de terrain par mode, durées, vitesses, puissance des tirs, portées d'interception, de contre et d'arrêt, règles. Ce sont des valeurs de départ à ajuster après les tests.

## Organisation

```
src/shared/   Config, Types (contrats réseau), Remotes, CourtGeometry, BallPhysics, Assets
src/server/   Services/ (MatchService, MapService, AntiExploitService, DevService), Match/ (Match, Rules, Goalkeeper, Bots, Appearance), Lib/ (Remote, Guard, RateLimit)
src/client/   Controllers/ (MatchClient, Input, Camera, Movement, Action, BallRenderer, Animation, Effects, HUD, DevPanel), UI/ (Theme, Kit)
```
