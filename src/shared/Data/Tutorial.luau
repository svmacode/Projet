--!strict
-- Étapes du tutoriel (facultatif) affiché dans le lobby.

export type Step = {
	Title: string,
	Japanese: string,
	Body: string,
	Keys: { string },
}

local Tutorial: { Step } = {
	{
		Title = "BIENVENUE AU LYCÉE SEIRYŌ",
		Japanese = "ようこそ",
		Body = "Handball Legends reprend les vraies règles du handball, avec des pouvoirs d'animé. "
			.. "Marque plus de buts que l'équipe adverse en deux mi-temps.",
		Keys = {},
	},
	{
		Title = "SE DÉPLACER",
		Japanese = "移動",
		Body = "Déplace-toi et saute. Le DASH donne un élan explosif (recharge de 2 s). "
			.. "Le verrouillage caméra (Ctrl) oriente ton joueur vers ta visée.",
		Keys = { "ZQSD / WASD : courir", "Espace : sauter", "Shift : dash", "Ctrl : verrouiller la caméra" },
	},
	{
		Title = "PASSER ET TIRER",
		Japanese = "パスとシュート",
		Body = "La passe part vers le coéquipier le plus proche de ta visée. "
			.. "Maintiens le clic pour charger un tir : plus la jauge est pleine, plus il est puissant.",
		Keys = { "E : passe", "Clic gauche (maintenir) : tir" },
	},
	{
		Title = "LES 3 SECONDES ET LES 3 PAS",
		Japanese = "三秒ルール",
		Body = "Tu ne peux garder le ballon que 3 secondes et faire 3 pas. "
			.. "Pour avancer plus longtemps, DRIBBLE. Mais une fois le ballon repris en main, impossible de redribbler !",
		Keys = { "R : dribbler / reprendre le ballon" },
	},
	{
		Title = "DÉFENDRE",
		Japanese = "ディフェンス",
		Body = "La touche F intercepte une passe en vol, ou charge le porteur adverse pour lui prendre le ballon. "
			.. "Un contact par derrière ou sur un joueur sans ballon est une FAUTE : avertissement, exclusion, puis carton rouge.",
		Keys = { "F : intercepter / contact" },
	},
	{
		Title = "LA ZONE",
		Japanese = "ゴールエリア",
		Body = "Seul le gardien peut poser le pied dans la zone (6 m). Un attaquant peut sauter au-dessus "
			.. "et tirer avant de retomber. Un défenseur qui défend dans sa zone donne un jet de 7 mètres !",
		Keys = {},
	},
	{
		Title = "LES POUVOIRS",
		Japanese = "必殺技",
		Body = "Pouvoir 1 : mouvement, toutes les 15 s. Pouvoir 2 : se charge en touchant le ballon (passes, "
			.. "réceptions, interceptions, arrêts). Pouvoir 3 : l'ULTIME, qui peut renverser un match.",
		Keys = { "1 : pouvoir de mouvement", "2 : pouvoir technique", "3 : ultime" },
	},
	{
		Title = "PROGRESSER",
		Japanese = "成長",
		Body = "Chaque match rapporte des Hand Coins et de l'XP. Achète des Balles pour débloquer des archétypes. "
			.. "Au niveau 10, le mode CLASSÉ s'ouvre. Ta première partie t'offre 3 Balles !",
		Keys = {},
	},
}

return Tutorial
