--!strict
-- Les 18 archétypes : 3 par rareté, un par poste (Gardien, Défenseur, Attaquant).
--
-- Chaque archétype possède 3 pouvoirs :
--   [1] Mouvement — recharge fixe (Config.Powers.Power1Cooldown)
--   [2] Technique — se charge en touchant le ballon (passes, réceptions, arrêts…)
--   [3] Ultime    — se charge lentement + actions décisives
--
-- Un pouvoir est une liste d'effets. Le serveur applique chaque effet
-- (Match/Abilities.luau) et les clients jouent les effets visuels.

local Rarities = require(script.Parent.Rarities)

export type PosteId = "Gardien" | "Defenseur" | "Attaquant"

export type EffectKind =
	"Dash" -- élan vers l'avant (Speed, Duration, Ram?)
	| "Leap" -- saut puissant (Up, Forward)
	| "Blink" -- téléportation courte vers l'avant (Distance)
	| "BlinkToCarrier" -- téléportation devant le porteur adverse (Range)
	| "BlinkToGoal" -- retour instantané au centre de son but
	| "Dive" -- plongeon du gardien (Speed, Duration)
	| "SelfBuff" -- (Duration, Haste?, Unstoppable?, InterceptMult?, CatchMult?)
	| "ShotBuff" -- prochain tir (Window, SpeedMult, Curve?, Fire?, Homing?, StunKeeper?, KeeperRadiusMult?)
	| "Steal" -- arrache le ballon au porteur adverse proche (Range)
	| "TeamHaste" -- (Mult, Duration, ResetPower1?)
	| "EnemySlow" -- (Mult, Duration, Radius?) sans Radius = tous les adversaires
	| "EnemyStun" -- (Duration, Radius?)
	| "EnemyBlind" -- (Duration, Radius?)
	| "GoalWall" -- mur sur son propre but (Duration, Coverage 0-1, Style)
	| "TimeStop" -- fige tous les adversaires (Duration)

export type Effect = {
	Kind: EffectKind,
	Speed: number?,
	Duration: number?,
	Ram: boolean?,
	Up: number?,
	Forward: number?,
	Distance: number?,
	Range: number?,
	Haste: number?,
	Unstoppable: boolean?,
	InterceptMult: number?,
	CatchMult: number?,
	Window: number?,
	SpeedMult: number?,
	Curve: number?,
	Fire: boolean?,
	Homing: boolean?,
	StunKeeper: number?,
	KeeperRadiusMult: number?,
	Mult: number?,
	ResetPower1: boolean?,
	Radius: number?,
	Coverage: number?,
	Style: string?,
}

export type Power = {
	Id: string,
	Slot: number,
	Name: string,
	Japanese: string,
	Description: string,
	Effects: { Effect },
	Color: Color3,
}

export type Archetype = {
	Id: string,
	Name: string,
	Title: string,
	Kanji: string,
	Rarity: Rarities.RarityId,
	Poste: PosteId,
	Color: Color3,
	Accent: Color3,
	Description: string,
	Powers: { Power },
}

local Archetypes = {}

Archetypes.Postes = {
	Gardien = {
		Id = "Gardien",
		Name = "Gardien",
		Short = "GB",
		Description = "Seul joueur autorisé dans la zone. Arrête les tirs et relance le jeu.",
	},
	Defenseur = {
		Id = "Defenseur",
		Name = "Défenseur",
		Short = "DEF",
		Description = "Coupe les passes, encaisse les contacts et récupère le ballon.",
	},
	Attaquant = {
		Id = "Attaquant",
		Name = "Attaquant",
		Short = "ATT",
		Description = "Crée le danger : vitesse, feintes et tirs dévastateurs.",
	},
}

Archetypes.PosteOrder = { "Gardien", "Defenseur", "Attaquant" } :: { PosteId }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local LIST: { Archetype } = {
	---------------------------------------------------------------- COMMUN
	{
		Id = "Hayato",
		Name = "Hayato Kazemaru",
		Title = "Le Vent du Lycée",
		Kanji = "風",
		Rarity = "Commun",
		Poste = "Attaquant",
		Color = rgb(96, 200, 255),
		Accent = rgb(230, 250, 255),
		Description = "Ailier rapide qui vit pour la contre-attaque.",
		Powers = {
			{
				Id = "Hayato_1",
				Slot = 1,
				Name = "Kaze Step",
				Japanese = "風ステップ",
				Description = "Un élan vif vers l'avant.",
				Effects = { { Kind = "Dash", Speed = 86, Duration = 0.24 } },
				Color = rgb(96, 200, 255),
			},
			{
				Id = "Hayato_2",
				Slot = 2,
				Name = "Tir Tendu",
				Japanese = "直線シュート",
				Description = "Ton prochain tir part 20 % plus vite.",
				Effects = { { Kind = "ShotBuff", Window = 8, SpeedMult = 1.2 } },
				Color = rgb(96, 200, 255),
			},
			{
				Id = "Hayato_3",
				Slot = 3,
				Name = "Souffle d'Équipe",
				Japanese = "追い風",
				Description = "Toute ton équipe court 20 % plus vite pendant 5 s.",
				Effects = { { Kind = "TeamHaste", Mult = 1.2, Duration = 5 } },
				Color = rgb(150, 230, 255),
			},
		},
	},
	{
		Id = "Tetsuo",
		Name = "Tetsuo Kabeyama",
		Title = "Le Rempart",
		Kanji = "壁",
		Rarity = "Commun",
		Poste = "Defenseur",
		Color = rgb(150, 160, 175),
		Accent = rgb(255, 210, 90),
		Description = "Défenseur solide qui ne lâche rien.",
		Powers = {
			{
				Id = "Tetsuo_1",
				Slot = 1,
				Name = "Pas Chassé",
				Japanese = "サイドステップ",
				Description = "Un déplacement défensif explosif.",
				Effects = { { Kind = "Dash", Speed = 76, Duration = 0.22 } },
				Color = rgb(255, 210, 90),
			},
			{
				Id = "Tetsuo_2",
				Slot = 2,
				Name = "Mains de Fer",
				Japanese = "鉄の手",
				Description = "Zone d'interception +50 % pendant 6 s.",
				Effects = { { Kind = "SelfBuff", Duration = 6, InterceptMult = 1.5 } },
				Color = rgb(255, 210, 90),
			},
			{
				Id = "Tetsuo_3",
				Slot = 3,
				Name = "Grondement",
				Japanese = "轟き",
				Description = "Ralentit de 20 % les adversaires proches pendant 4 s.",
				Effects = { { Kind = "EnemySlow", Mult = 0.8, Duration = 4, Radius = 25 } },
				Color = rgb(255, 170, 60),
			},
		},
	},
	{
		Id = "Mamoru",
		Name = "Mamoru Tatenaka",
		Title = "Le Portier",
		Kanji = "守",
		Rarity = "Commun",
		Poste = "Gardien",
		Color = rgb(120, 200, 110),
		Accent = rgb(250, 250, 240),
		Description = "Gardien fiable aux réflexes travaillés.",
		Powers = {
			{
				Id = "Mamoru_1",
				Slot = 1,
				Name = "Plongeon",
				Japanese = "ダイブ",
				Description = "Un plongeon latéral pour couvrir le but.",
				Effects = { { Kind = "Dive", Speed = 70, Duration = 0.3 } },
				Color = rgb(120, 200, 110),
			},
			{
				Id = "Mamoru_2",
				Slot = 2,
				Name = "Gants Collants",
				Japanese = "粘着グローブ",
				Description = "Zone d'arrêt +35 % pendant 6 s.",
				Effects = { { Kind = "SelfBuff", Duration = 6, CatchMult = 1.35 } },
				Color = rgb(120, 200, 110),
			},
			{
				Id = "Mamoru_3",
				Slot = 3,
				Name = "Palissade",
				Japanese = "木の柵",
				Description = "Une palissade en bois couvre 45 % du but pendant 4 s.",
				Effects = { { Kind = "GoalWall", Duration = 4, Coverage = 0.45, Style = "Wood" } },
				Color = rgb(180, 120, 60),
			},
		},
	},
	---------------------------------------------------------------- PEU COMMUN
	{
		Id = "Ren",
		Name = "Ren Hibana",
		Title = "L'Étincelle",
		Kanji = "火花",
		Rarity = "PeuCommun",
		Poste = "Attaquant",
		Color = rgb(255, 122, 40),
		Accent = rgb(255, 230, 120),
		Description = "Arrière explosif, imprévisible et flamboyant.",
		Powers = {
			{
				Id = "Ren_1",
				Slot = 1,
				Name = "Étincelle",
				Japanese = "火花ダッシュ",
				Description = "Élan + 20 % de vitesse pendant 2 s.",
				Effects = {
					{ Kind = "Dash", Speed = 90, Duration = 0.24 },
					{ Kind = "SelfBuff", Duration = 2, Haste = 1.2 },
				},
				Color = rgb(255, 122, 40),
			},
			{
				Id = "Ren_2",
				Slot = 2,
				Name = "Tir Brûlant",
				Japanese = "灼熱シュート",
				Description = "Prochain tir +35 % de vitesse, plus dur à capter.",
				Effects = { { Kind = "ShotBuff", Window = 8, SpeedMult = 1.35, KeeperRadiusMult = 0.85 } },
				Color = rgb(255, 90, 30),
			},
			{
				Id = "Ren_3",
				Slot = 3,
				Name = "Feu d'Artifice",
				Japanese = "花火",
				Description = "Aveugle les adversaires proches pendant 2 s.",
				Effects = { { Kind = "EnemyBlind", Duration = 2, Radius = 30 } },
				Color = rgb(255, 200, 60),
			},
		},
	},
	{
		Id = "Daichi",
		Name = "Daichi Iwao",
		Title = "Le Roc",
		Kanji = "岩",
		Rarity = "PeuCommun",
		Poste = "Defenseur",
		Color = rgb(170, 120, 80),
		Accent = rgb(255, 200, 120),
		Description = "Un mur vivant qui saute plus haut que tout le monde.",
		Powers = {
			{
				Id = "Daichi_1",
				Slot = 1,
				Name = "Bond du Roc",
				Japanese = "岩跳び",
				Description = "Un saut immense pour contrer les tirs en suspension.",
				Effects = { { Kind = "Leap", Up = 72, Forward = 20 } },
				Color = rgb(200, 150, 90),
			},
			{
				Id = "Daichi_2",
				Slot = 2,
				Name = "Peau de Pierre",
				Japanese = "石の肌",
				Description = "Insensible aux contacts, interception +60 % pendant 6 s.",
				Effects = { { Kind = "SelfBuff", Duration = 6, Unstoppable = true, InterceptMult = 1.6 } },
				Color = rgb(200, 150, 90),
			},
			{
				Id = "Daichi_3",
				Slot = 3,
				Name = "Séisme",
				Japanese = "地震",
				Description = "Étourdit les adversaires proches pendant 1 s.",
				Effects = { { Kind = "EnemyStun", Duration = 1, Radius = 20 } },
				Color = rgb(150, 100, 60),
			},
		},
	},
	{
		Id = "Kaito",
		Name = "Kaito Amimura",
		Title = "Le Filet",
		Kanji = "網",
		Rarity = "PeuCommun",
		Poste = "Gardien",
		Color = rgb(40, 190, 170),
		Accent = rgb(220, 255, 250),
		Description = "Gardien agile qui ferme les angles.",
		Powers = {
			{
				Id = "Kaito_1",
				Slot = 1,
				Name = "Plongeon Éclair",
				Japanese = "電光ダイブ",
				Description = "Plongeon rapide et long.",
				Effects = { { Kind = "Dive", Speed = 86, Duration = 0.3 } },
				Color = rgb(40, 190, 170),
			},
			{
				Id = "Kaito_2",
				Slot = 2,
				Name = "Grand Filet",
				Japanese = "大網",
				Description = "Zone d'arrêt +50 % pendant 6 s.",
				Effects = { { Kind = "SelfBuff", Duration = 6, CatchMult = 1.5 } },
				Color = rgb(40, 190, 170),
			},
			{
				Id = "Kaito_3",
				Slot = 3,
				Name = "Filet Géant",
				Japanese = "巨大網",
				Description = "Un filet couvre 60 % du but pendant 5 s.",
				Effects = { { Kind = "GoalWall", Duration = 5, Coverage = 0.6, Style = "Net" } },
				Color = rgb(40, 190, 170),
			},
		},
	},
	---------------------------------------------------------------- RARE
	{
		Id = "Sora",
		Name = "Sora Tsubasa",
		Title = "Les Ailes",
		Kanji = "翼",
		Rarity = "Rare",
		Poste = "Attaquant",
		Color = rgb(120, 170, 255),
		Accent = rgb(255, 255, 255),
		Description = "Spécialiste des tirs en suspension, il plane au-dessus de la zone.",
		Powers = {
			{
				Id = "Sora_1",
				Slot = 1,
				Name = "Envol",
				Japanese = "飛翔",
				Description = "Bondit haut et loin vers l'avant.",
				Effects = { { Kind = "Leap", Up = 82, Forward = 48 } },
				Color = rgb(170, 210, 255),
			},
			{
				Id = "Sora_2",
				Slot = 2,
				Name = "Tir Courbe",
				Japanese = "カーブシュート",
				Description = "Prochain tir +40 %, avec un effet courbé.",
				Effects = { { Kind = "ShotBuff", Window = 8, SpeedMult = 1.4, Curve = 1, KeeperRadiusMult = 0.8 } },
				Color = rgb(120, 170, 255),
			},
			{
				Id = "Sora_3",
				Slot = 3,
				Name = "Ciel Ouvert",
				Japanese = "青空",
				Description = "Toute ton équipe court 35 % plus vite pendant 6 s.",
				Effects = { { Kind = "TeamHaste", Mult = 1.35, Duration = 6 } },
				Color = rgb(170, 220, 255),
			},
		},
	},
	{
		Id = "Kenji",
		Name = "Kenji Kagemaru",
		Title = "L'Ombre",
		Kanji = "影",
		Rarity = "Rare",
		Poste = "Defenseur",
		Color = rgb(70, 60, 110),
		Accent = rgb(190, 140, 255),
		Description = "On ne le voit jamais venir. Le ballon, si.",
		Powers = {
			{
				Id = "Kenji_1",
				Slot = 1,
				Name = "Pas de l'Ombre",
				Japanese = "影歩き",
				Description = "Téléportation de 24 studs vers l'avant.",
				Effects = { { Kind = "Blink", Distance = 24 } },
				Color = rgb(150, 110, 230),
			},
			{
				Id = "Kenji_2",
				Slot = 2,
				Name = "Vol à la Tire",
				Japanese = "掏摸",
				Description = "Arrache le ballon au porteur adverse à moins de 14 studs.",
				Effects = { { Kind = "Steal", Range = 14 } },
				Color = rgb(150, 110, 230),
			},
			{
				Id = "Kenji_3",
				Slot = 3,
				Name = "Nuit Noire",
				Japanese = "闇夜",
				Description = "Aveugle tous les adversaires pendant 3 s.",
				Effects = { { Kind = "EnemyBlind", Duration = 3 } },
				Color = rgb(60, 40, 110),
			},
		},
	},
	{
		Id = "Yuki",
		Name = "Yuki Shirogane",
		Title = "La Reine des Glaces",
		Kanji = "氷",
		Rarity = "Rare",
		Poste = "Gardien",
		Color = rgb(150, 230, 255),
		Accent = rgb(255, 255, 255),
		Description = "Son regard gèle les attaquants, sa glace gèle les buts.",
		Powers = {
			{
				Id = "Yuki_1",
				Slot = 1,
				Name = "Glissade de Givre",
				Japanese = "霜滑り",
				Description = "Plongeon + zone d'arrêt +20 % pendant 2 s.",
				Effects = {
					{ Kind = "Dive", Speed = 86, Duration = 0.3 },
					{ Kind = "SelfBuff", Duration = 2, CatchMult = 1.2 },
				},
				Color = rgb(150, 230, 255),
			},
			{
				Id = "Yuki_2",
				Slot = 2,
				Name = "Main Gelée",
				Japanese = "凍てつく手",
				Description = "Zone d'arrêt +70 % pendant 6 s.",
				Effects = { { Kind = "SelfBuff", Duration = 6, CatchMult = 1.7 } },
				Color = rgb(150, 230, 255),
			},
			{
				Id = "Yuki_3",
				Slot = 3,
				Name = "Mur de Glace",
				Japanese = "氷壁",
				Description = "Un mur de glace ferme entièrement le but pendant 5 s.",
				Effects = { { Kind = "GoalWall", Duration = 5, Coverage = 1, Style = "Ice" } },
				Color = rgb(170, 240, 255),
			},
		},
	},
	---------------------------------------------------------------- EPIQUE
	{
		Id = "Raiden",
		Name = "Raiden Ikazuchi",
		Title = "Le Dieu Foudre",
		Kanji = "雷",
		Rarity = "Epique",
		Poste = "Attaquant",
		Color = rgb(255, 222, 40),
		Accent = rgb(60, 40, 140),
		Description = "Plus rapide que l'éclair, et deux fois plus bruyant.",
		Powers = {
			{
				Id = "Raiden_1",
				Slot = 1,
				Name = "Éclair",
				Japanese = "稲妻",
				Description = "Téléportation de 34 studs + 25 % de vitesse pendant 2 s.",
				Effects = { { Kind = "Blink", Distance = 34 }, { Kind = "SelfBuff", Duration = 2, Haste = 1.25 } },
				Color = rgb(255, 230, 60),
			},
			{
				Id = "Raiden_2",
				Slot = 2,
				Name = "Tir Foudroyant",
				Japanese = "雷撃シュート",
				Description = "Prochain tir +60 %. Le gardien touché est étourdi.",
				Effects = {
					{ Kind = "ShotBuff", Window = 8, SpeedMult = 1.6, StunKeeper = 1.2, KeeperRadiusMult = 0.75 },
				},
				Color = rgb(255, 230, 60),
			},
			{
				Id = "Raiden_3",
				Slot = 3,
				Name = "Tempête",
				Japanese = "嵐",
				Description = "Étourdit les adversaires dans un large rayon et te rend plus rapide.",
				Effects = {
					{ Kind = "EnemyStun", Duration = 1.5, Radius = 40 },
					{ Kind = "SelfBuff", Duration = 4, Haste = 1.3 },
				},
				Color = rgb(255, 240, 120),
			},
		},
	},
	{
		Id = "Ryuji",
		Name = "Ryuji Kurogane",
		Title = "Le Dragon d'Acier",
		Kanji = "龍",
		Rarity = "Epique",
		Poste = "Defenseur",
		Color = rgb(40, 150, 90),
		Accent = rgb(230, 200, 80),
		Description = "Ses charges renversent les attaquants les plus lourds.",
		Powers = {
			{
				Id = "Ryuji_1",
				Slot = 1,
				Name = "Charge du Dragon",
				Japanese = "龍の突進",
				Description = "Charge puissante qui étourdit les adversaires percutés.",
				Effects = { { Kind = "Dash", Speed = 96, Duration = 0.3, Ram = true } },
				Color = rgb(60, 200, 110),
			},
			{
				Id = "Ryuji_2",
				Slot = 2,
				Name = "Écailles",
				Japanese = "龍鱗",
				Description = "Insensible aux contacts, interception ×2 pendant 7 s.",
				Effects = { { Kind = "SelfBuff", Duration = 7, Unstoppable = true, InterceptMult = 2 } },
				Color = rgb(60, 200, 110),
			},
			{
				Id = "Ryuji_3",
				Slot = 3,
				Name = "Rugissement du Dragon",
				Japanese = "龍の咆哮",
				Description = "Ralentit tous les adversaires de 40 % pendant 5 s.",
				Effects = { { Kind = "EnemySlow", Mult = 0.6, Duration = 5 } },
				Color = rgb(230, 200, 80),
			},
		},
	},
	{
		Id = "Hikari",
		Name = "Hikari Kagami",
		Title = "Le Miroir",
		Kanji = "鏡",
		Rarity = "Epique",
		Poste = "Gardien",
		Color = rgb(255, 245, 190),
		Accent = rgb(255, 170, 60),
		Description = "Chaque tir se reflète contre sa lumière.",
		Powers = {
			{
				Id = "Hikari_1",
				Slot = 1,
				Name = "Reflet",
				Japanese = "反射",
				Description = "Retour instantané au centre du but + zone d'arrêt +30 %.",
				Effects = { { Kind = "BlinkToGoal" }, { Kind = "SelfBuff", Duration = 2.5, CatchMult = 1.3 } },
				Color = rgb(255, 245, 190),
			},
			{
				Id = "Hikari_2",
				Slot = 2,
				Name = "Miroir",
				Japanese = "鏡面",
				Description = "Zone d'arrêt +90 % pendant 6 s.",
				Effects = { { Kind = "SelfBuff", Duration = 6, CatchMult = 1.9 } },
				Color = rgb(255, 245, 190),
			},
			{
				Id = "Hikari_3",
				Slot = 3,
				Name = "Dôme de Lumière",
				Japanese = "光のドーム",
				Description = "Ferme le but 6 s et aveugle les attaquants proches.",
				Effects = {
					{ Kind = "GoalWall", Duration = 6, Coverage = 1, Style = "Light" },
					{ Kind = "EnemyBlind", Duration = 1.5, Radius = 35 },
				},
				Color = rgb(255, 230, 140),
			},
		},
	},
	---------------------------------------------------------------- LEGENDAIRE
	{
		Id = "Akira",
		Name = "Akira Homura",
		Title = "Le Phénix",
		Kanji = "焔",
		Rarity = "Legendaire",
		Poste = "Attaquant",
		Color = rgb(255, 80, 30),
		Accent = rgb(255, 220, 80),
		Description = "Chaque défaite le fait renaître plus fort.",
		Powers = {
			{
				Id = "Akira_1",
				Slot = 1,
				Name = "Pas du Phénix",
				Japanese = "鳳凰の歩み",
				Description = "Élan enflammé + 35 % de vitesse pendant 3 s.",
				Effects = {
					{ Kind = "Dash", Speed = 100, Duration = 0.26 },
					{ Kind = "SelfBuff", Duration = 3, Haste = 1.35 },
				},
				Color = rgb(255, 120, 40),
			},
			{
				Id = "Akira_2",
				Slot = 2,
				Name = "Tir du Phénix",
				Japanese = "鳳凰シュート",
				Description = "Prochain tir +80 %, en feu : impossible à capter, seulement à repousser.",
				Effects = { { Kind = "ShotBuff", Window = 9, SpeedMult = 1.8, Fire = true, KeeperRadiusMult = 0.6 } },
				Color = rgb(255, 80, 30),
			},
			{
				Id = "Akira_3",
				Slot = 3,
				Name = "Renaissance",
				Japanese = "転生",
				Description = "Équipe +50 % de vitesse pendant 7 s et pouvoirs 1 rechargés.",
				Effects = { { Kind = "TeamHaste", Mult = 1.5, Duration = 7, ResetPower1 = true } },
				Color = rgb(255, 200, 60),
			},
		},
	},
	{
		Id = "Jin",
		Name = "Jin Mugen",
		Title = "L'Infini",
		Kanji = "無限",
		Rarity = "Legendaire",
		Poste = "Defenseur",
		Color = rgb(110, 90, 255),
		Accent = rgb(120, 255, 240),
		Description = "Il est partout à la fois. Le ballon n'a nulle part où aller.",
		Powers = {
			{
				Id = "Jin_1",
				Slot = 1,
				Name = "Pas Fantôme",
				Japanese = "幻影歩",
				Description = "Téléportation devant le porteur adverse (45 studs).",
				Effects = { { Kind = "BlinkToCarrier", Range = 45 } },
				Color = rgb(120, 255, 240),
			},
			{
				Id = "Jin_2",
				Slot = 2,
				Name = "Main Invisible",
				Japanese = "見えざる手",
				Description = "Arrache le ballon au porteur adverse à moins de 22 studs.",
				Effects = { { Kind = "Steal", Range = 22 } },
				Color = rgb(120, 255, 240),
			},
			{
				Id = "Jin_3",
				Slot = 3,
				Name = "Gravité Zéro",
				Japanese = "無重力",
				Description = "Tous les adversaires ralentis de 55 % pendant 5 s et brièvement étourdis.",
				Effects = { { Kind = "EnemySlow", Mult = 0.45, Duration = 5 }, { Kind = "EnemyStun", Duration = 0.6 } },
				Color = rgb(110, 90, 255),
			},
		},
	},
	{
		Id = "Tenshi",
		Name = "Tenshi Hanemiya",
		Title = "L'Ange Gardien",
		Kanji = "天使",
		Rarity = "Legendaire",
		Poste = "Gardien",
		Color = rgb(255, 255, 255),
		Accent = rgb(255, 210, 90),
		Description = "Ses ailes couvrent le but tout entier.",
		Powers = {
			{
				Id = "Tenshi_1",
				Slot = 1,
				Name = "Ailes Célestes",
				Japanese = "天の翼",
				Description = "Plongeon très long et zone d'arrêt +30 %.",
				Effects = {
					{ Kind = "Dive", Speed = 104, Duration = 0.32 },
					{ Kind = "SelfBuff", Duration = 2, CatchMult = 1.3 },
				},
				Color = rgb(255, 240, 200),
			},
			{
				Id = "Tenshi_2",
				Slot = 2,
				Name = "Plume Sacrée",
				Japanese = "聖なる羽",
				Description = "Zone d'arrêt ×2,2 pendant 7 s.",
				Effects = { { Kind = "SelfBuff", Duration = 7, CatchMult = 2.2 } },
				Color = rgb(255, 240, 200),
			},
			{
				Id = "Tenshi_3",
				Slot = 3,
				Name = "Sanctuaire",
				Japanese = "聖域",
				Description = "Une barrière sacrée ferme le but pendant 8 s.",
				Effects = { { Kind = "GoalWall", Duration = 8, Coverage = 1, Style = "Holy" } },
				Color = rgb(255, 220, 120),
			},
		},
	},
	---------------------------------------------------------------- MYTHIQUE
	{
		Id = "Susanoo",
		Name = "Susanoo Arashi",
		Title = "Le Dieu des Tempêtes",
		Kanji = "須佐",
		Rarity = "Mythique",
		Poste = "Attaquant",
		Color = rgb(40, 220, 255),
		Accent = rgb(255, 40, 120),
		Description = "Une légende du lycée. Ses tirs fendent le ciel.",
		Powers = {
			{
				Id = "Susanoo_1",
				Slot = 1,
				Name = "Kamikaze",
				Japanese = "神風",
				Description = "Téléportation de 45 studs + 50 % de vitesse pendant 3 s.",
				Effects = { { Kind = "Blink", Distance = 45 }, { Kind = "SelfBuff", Duration = 3, Haste = 1.5 } },
				Color = rgb(40, 220, 255),
			},
			{
				Id = "Susanoo_2",
				Slot = 2,
				Name = "Tir Divin",
				Japanese = "神の一撃",
				Description = "Tir ×2,2 en feu, guidé vers le but, qui étourdit le gardien.",
				Effects = {
					{
						Kind = "ShotBuff",
						Window = 10,
						SpeedMult = 2.2,
						Fire = true,
						Homing = true,
						StunKeeper = 1.5,
						KeeperRadiusMult = 0.4,
					},
				},
				Color = rgb(255, 40, 120),
			},
			{
				Id = "Susanoo_3",
				Slot = 3,
				Name = "Typhon Divin",
				Japanese = "神嵐",
				Description = "Tous les adversaires étourdis 2,5 s et équipe +40 % de vitesse.",
				Effects = { { Kind = "EnemyStun", Duration = 2.5 }, { Kind = "TeamHaste", Mult = 1.4, Duration = 5 } },
				Color = rgb(40, 220, 255),
			},
		},
	},
	{
		Id = "Kuro",
		Name = "Kuro Yamikage",
		Title = "L'Éclipse",
		Kanji = "闇",
		Rarity = "Mythique",
		Poste = "Defenseur",
		Color = rgb(30, 10, 50),
		Accent = rgb(255, 40, 200),
		Description = "Quand il entre sur le terrain, la lumière s'éteint.",
		Powers = {
			{
				Id = "Kuro_1",
				Slot = 1,
				Name = "Déchirure",
				Japanese = "裂け目",
				Description = "Téléportation devant le porteur adverse (60 studs).",
				Effects = {
					{ Kind = "BlinkToCarrier", Range = 60 },
					{ Kind = "SelfBuff", Duration = 1.5, Haste = 1.3 },
				},
				Color = rgb(255, 40, 200),
			},
			{
				Id = "Kuro_2",
				Slot = 2,
				Name = "Vol Absolu",
				Japanese = "絶対強奪",
				Description = "Arrache le ballon au porteur adverse à moins de 32 studs.",
				Effects = { { Kind = "Steal", Range = 32 }, { Kind = "SelfBuff", Duration = 2, Haste = 1.3 } },
				Color = rgb(255, 40, 200),
			},
			{
				Id = "Kuro_3",
				Slot = 3,
				Name = "Éclipse Totale",
				Japanese = "皆既日食",
				Description = "Tous les adversaires aveuglés 4 s et ralentis de 40 %.",
				Effects = { { Kind = "EnemyBlind", Duration = 4 }, { Kind = "EnemySlow", Mult = 0.6, Duration = 4 } },
				Color = rgb(120, 0, 140),
			},
		},
	},
	{
		Id = "Amaterasu",
		Name = "Kamui Amaterasu",
		Title = "La Déesse Soleil",
		Kanji = "天照",
		Rarity = "Mythique",
		Poste = "Gardien",
		Color = rgb(255, 170, 30),
		Accent = rgb(255, 255, 220),
		Description = "Le temps lui-même s'arrête devant son but.",
		Powers = {
			{
				Id = "Amaterasu_1",
				Slot = 1,
				Name = "Pas Céleste",
				Japanese = "天歩",
				Description = "Retour instantané au but + zone d'arrêt +50 % pendant 3 s.",
				Effects = { { Kind = "BlinkToGoal" }, { Kind = "SelfBuff", Duration = 3, CatchMult = 1.5 } },
				Color = rgb(255, 200, 80),
			},
			{
				Id = "Amaterasu_2",
				Slot = 2,
				Name = "Main du Soleil",
				Japanese = "太陽の手",
				Description = "Zone d'arrêt ×2,6 et insensible aux contacts pendant 7 s.",
				Effects = { { Kind = "SelfBuff", Duration = 7, CatchMult = 2.6, Unstoppable = true } },
				Color = rgb(255, 200, 80),
			},
			{
				Id = "Amaterasu_3",
				Slot = 3,
				Name = "Arrêt du Temps",
				Japanese = "時よ止まれ",
				Description = "Fige tous les adversaires pendant 3 s.",
				Effects = { { Kind = "TimeStop", Duration = 3 } },
				Color = rgb(255, 230, 150),
			},
		},
	},
}

local BY_ID: { [string]: Archetype } = {}
local POWER_BY_ID: { [string]: Power } = {}
for _, archetype in LIST do
	BY_ID[archetype.Id] = archetype
	for _, power in archetype.Powers do
		POWER_BY_ID[power.Id] = power
	end
end

Archetypes.List = LIST

-- Archétypes possédés par tous les joueurs dès le départ (un par poste).
Archetypes.Starters = { "Hayato", "Tetsuo", "Mamoru" }

function Archetypes.get(id: unknown): Archetype?
	if typeof(id) ~= "string" then
		return nil
	end
	return BY_ID[id]
end

function Archetypes.getPower(id: string): Power?
	return POWER_BY_ID[id]
end

function Archetypes.byRarity(rarity: string): { Archetype }
	local result = {}
	for _, archetype in LIST do
		if archetype.Rarity == rarity then
			table.insert(result, archetype)
		end
	end
	return result
end

function Archetypes.byPoste(poste: string): { Archetype }
	local result = {}
	for _, archetype in LIST do
		if archetype.Poste == poste then
			table.insert(result, archetype)
		end
	end
	return result
end

function Archetypes.isPoste(value: unknown): boolean
	return typeof(value) == "string" and (Archetypes.Postes :: any)[value] ~= nil
end

return Archetypes
