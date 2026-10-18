--!strict
-- Réglages centraux de Handball Legends.
-- Toutes les valeurs d'équilibrage sont ici. Le client peut lire ce fichier :
-- le serveur reste la seule autorité, il ne fait jamais confiance au client.

local Config = {}

Config.GameName = "Handball Legends"
Config.Version = "0.4.0"

-- Modes de jeu -----------------------------------------------------------------

export type ModeId = string -- "2v2" | "3v3" | "4v4" | "5v5"

export type ModeInfo = {
	Id: ModeId,
	Label: string,
	TeamSize: number,
	RankedAllowed: boolean,
	HalfDuration: number, -- secondes par mi-temps
}

-- Tous les modes : 2 mi-temps de 2 min 30.
Config.Modes = {
	["2v2"] = { Id = "2v2", Label = "2 VS 2", TeamSize = 2, RankedAllowed = false, HalfDuration = 150 },
	["3v3"] = { Id = "3v3", Label = "3 VS 3", TeamSize = 3, RankedAllowed = true, HalfDuration = 150 },
	["4v4"] = { Id = "4v4", Label = "4 VS 4", TeamSize = 4, RankedAllowed = true, HalfDuration = 150 },
	["5v5"] = { Id = "5v5", Label = "5 VS 5", TeamSize = 5, RankedAllowed = true, HalfDuration = 150 },
} :: { [string]: ModeInfo }

Config.ModeOrder = { "2v2", "3v3", "4v4", "5v5" } :: { ModeId }

Config.RankedUnlockLevel = 10
Config.MaxPartySize = 5

-- Serveurs ---------------------------------------------------------------------

Config.Server = {
	-- En Studio les téléportations sont impossibles : les matchs se jouent
	-- dans le serveur du lobby, sur un terrain construit à l'écart.
	LocalMatchesInStudio = true,
	-- Délai max pour que tous les joueurs arrivent sur le serveur de match.
	MatchJoinTimeout = 35,
}

-- Déroulement d'un match -----------------------------------------------------------

Config.Match = {
	PositionSelectTime = 25,
	ThrowOffCountdown = 3,
	GoalCelebrationTime = 4.5,
	HalftimeDuration = 10,
	GoldenGoalDuration = 60, -- prolongation « but en or » en cas d'égalité, puis match nul
	EndScreenTime = 14,
	SetPieceSetupTime = 1.2,
}

-- Ballon (unités : studs, secondes) --------------------------------------------

Config.Ball = {
	Radius = 0.85,
	Gravity = 120, -- plus faible que la gravité réelle : trajectoires « animé »
	FloorRestitution = 0.55,
	WallRestitution = 0.6,
	RollingFriction = 0.9, -- perte de vitesse par seconde au sol (fraction)
	PassSpeed = 118,
	ShotMaxSpeed = 175, -- tir parfait ; voir ShotTiming.Effects pour les autres notes
	ShotLift = 0.035, -- léger relevé pour compenser la gravité « animé »
	ShotMaxHold = 6, -- au-delà, la charge est annulée
	PickupRadius = 3.6, -- ballon lent / au sol
	CatchRadius = 3.6, -- passe reçue par un coéquipier
	InterceptRadius = 2.1, -- adversaire sur la trajectoire
	InterceptStanceRadius = 6.5, -- posture d'interception active
	BlockRadius = 2.2, -- joueur de champ touché par un tir
	KeeperCatchRadius = 4.6,
	KeeperCatchMaxSpeed = 150, -- au-dessus, le gardien repousse au lieu de capter
	ReleaseImmunity = 0.35, -- le lanceur ne peut pas récupérer son propre lancer
	HoldHeight = 1.3,
}

-- Règles (simplifiées) ----------------------------------------------------------
--   • 3 secondes maximum avec le ballon ;
--   • zone réservée au gardien : attaquant qui y entre avec le ballon = perte
--     de balle, défenseur qui y défend = jet franc ;
--   • contact légal de face sur le porteur, faute par derrière ou sur un
--     joueur sans ballon = jet franc à l'endroit de la faute ;
--   • sorties : remise en jeu en touche, renvoi du gardien sur la ligne de but.

Config.Rules = {
	MaxHoldTime = 3, -- règle des 3 secondes
	SetPieceDefenderDistance = 8, -- distance imposée aux adversaires sur une remise en jeu
}

-- Déplacements & duels ---------------------------------------------------------------
-- Ressenti « Volleyball Legends » : course rapide, saut haut et vif, dash court.

Config.Movement = {
	WalkSpeed = 26,
	KeeperWalkSpeed = 24,
	JumpPower = 60,
	DashSpeed = 92,
	DashDuration = 0.16,
	DashCooldown = 2.2,
	-- Tolérance du contrôle serveur de la vitesse (studs/s au-dessus du max autorisé).
	SpeedTolerance = 14,
}

Config.Contact = {
	Range = 7,
	Cooldown = 3.2,
	StunTime = 0.7,
	StealChance = 0.5,
	BehindAngle = 70, -- en degrés : contact par derrière = faute
	SelfRecovery = 0.45,
}

Config.Intercept = {
	Duration = 0.55,
	Cooldown = 2.6,
}

-- Pouvoirs ---------------------------------------------------------------------

Config.Powers = {
	Power1Cooldown = 15,
	EnergyMax = 100,
	-- Gains d'énergie (pouvoir 2) : il faut vraiment toucher le ballon.
	EnergyGains = {
		Catch = 9,
		PassCompleted = 11,
		Interception = 24,
		Steal = 20,
		Save = 22,
		ShotOnTarget = 10,
		Goal = 20,
		Block = 14,
	} :: { [string]: number },
	-- Un même type de gain ne compte qu'une fois par fenêtre (anti-farm).
	EnergyGainCooldown = 2.5,
	MinPassDistanceForEnergy = 14,
	UltimateMax = 100,
	UltimatePassivePerSecond = 0.45,
	UltimateGains = {
		Goal = 16,
		Save = 12,
		Interception = 8,
		Power2Used = 6,
		Assist = 8,
	} :: { [string]: number },
}

-- Économie --------------------------------------------------------------------

Config.Economy = {
	FirstMatchBalls = 3, -- 3 balles offertes après la première partie
	FirstMatchBallId = "Classique",
	Rewards = {
		Win = 120,
		Loss = 55,
		Draw = 80,
		Goal = 12,
		Assist = 8,
		Save = 6,
		Interception = 5,
		MaxPerMatch = 320,
		TrainingMultiplier = 0, -- l'entraînement ne rapporte rien
		RankedMultiplier = 1.25,
	},
	XP = {
		Win = 160,
		Loss = 90,
		Draw = 120,
		Goal = 20,
		Assist = 12,
		Save = 12,
		Interception = 8,
		Training = 15,
	},
}

-- Classé ----------------------------------------------------------------------------

Config.Ranked = {
	WinRP = 25,
	LossRP = 18,
	DrawRP = 0,
	MvpBonusRP = 5,
	StartingRP = 0,
}

-- Produits Robux --------------------------------------------------------------------
-- À créer dans le Creator Hub (Monétisation > Produits pour développeurs),
-- puis remplacer les 0 par les identifiants. Un produit à 0 est masqué.

Config.Products = {
	CosmeticPack = 0, -- 1 Pack Cosmétique (prix conseillé : 99 R$)
	CosmeticPack5 = 0, -- 5 Packs Cosmétiques (prix conseillé : 399 R$)
	ClanCreation = 0, -- Création de clan (1000 R$)
	Coins1000 = 0, -- 1 000 Hand Coins (prix conseillé : 99 R$)
	Coins5000 = 0, -- 5 500 Hand Coins (prix conseillé : 449 R$)
}

Config.ProductRobuxPrice = {
	CosmeticPack = 99,
	CosmeticPack5 = 399,
	ClanCreation = 1000,
	Coins1000 = 99,
	Coins5000 = 449,
} :: { [string]: number }

-- Clans -----------------------------------------------------------------------------

Config.Clan = {
	MaxMembers = 30,
	NameMinLength = 3,
	NameMaxLength = 20,
	TagMinLength = 2,
	TagMaxLength = 4,
}

-- Données -----------------------------------------------------------------------

Config.Data = {
	ProfileStore = "HL_Profiles_v1",
	ClanStore = "HL_Clans_v1",
	ClanNameStore = "HL_ClanNames_v1",
	RankedBoard = "HL_RankedBoard_v1",
	AutosaveInterval = 60,
	LockStaleAfter = 180,
}

return Config
