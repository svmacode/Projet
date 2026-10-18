--!strict
-- Notes de mise à jour affichées dans le menu « Mises à jour ».
-- Ajouter les nouvelles versions EN HAUT de la liste.

export type PatchNote = {
	Version: string,
	Date: string,
	Title: string,
	Sections: { { Heading: string, Lines: { string } } },
}

local PatchNotes: { PatchNote } = {
	{
		Version = "0.3.0",
		Date = "18/10/2026",
		Title = "Style anime",
		Sections = {
			{
				Heading = "Visuel",
				Lines = {
					"Nouvelle direction artistique anime : couleurs vives, contours d'encre, plaques inclinées.",
					"Chaque section a sa couleur : Jouer, Casier, Boutique, Clan, Tutoriel, Nouveautés.",
					"Contours façon dessin animé sur les personnages et le ballon.",
					"Quartier, ciel et gymnase entièrement recolorés.",
				},
			},
			{
				Heading = "Match",
				Lines = {
					"Nouveau GOAL, nouveau tableau de score, nouveaux pouvoirs et bandeaux d'arbitrage.",
					"Nouvelle ouverture des Balles avec rayons et révélation de la rareté.",
				},
			},
		},
	},
	{
		Version = "0.2.0",
		Date = "18/10/2026",
		Title = "Refonte complète",
		Sections = {
			{
				Heading = "Visuel",
				Lines = {
					"Nouvelle interface, plus lisible et plus rapide.",
					"Nouveau quartier au coucher du soleil autour du lycée.",
					"Nouvelle lumière, brume d'horizon et effets de caméra.",
				},
			},
			{
				Heading = "Jeu",
				Lines = {
					"Nouvelles animations : course, défense, tir, passe, plongeon, célébration.",
					"Effets 3D sur les tirs, les dashs, les contacts, les pouvoirs et les buts.",
				},
			},
		},
	},
	{
		Version = "0.1.0",
		Date = "18/10/2026",
		Title = "LE COUP D'ENVOI !",
		Sections = {
			{
				Heading = "Nouveautés",
				Lines = {
					"Modes 2v2, 3v3, 4v4 et 5v5 sur le terrain du lycée Seiryō.",
					"18 archétypes, 54 pouvoirs, 6 raretés.",
					"Balles Classique, Dorée et Céleste. Garantie Légendaire à 40 balles.",
					"Pack Cosmétique : masques, gants et chaussures.",
					"Mode classé à partir du niveau 10 (3v3 et plus).",
					"Groupes, entraînement entre amis et clans.",
				},
			},
			{
				Heading = "Règles",
				Lines = {
					"3 secondes maximum avec le ballon, 3 pas, reprise de dribble interdite.",
					"Zone réservée au gardien, jets francs, jets de 7 mètres.",
					"Avertissements, exclusions temporaires et cartons rouges.",
					"Jeu passif signalé par l'arbitre.",
				},
			},
		},
	},
}

return PatchNotes
