--!strict
-- Ressources importées par le créateur (Creator Store / Toolbox / éditeur
-- d'animations). Tout est FACULTATIF : un identifiant vide ("") ou un modèle
-- absent fait basculer le jeu sur sa version dessinée en code.
--
-- Animations : rbxassetid://… d'animations R6 publiées sur TON compte ou ton
-- groupe (Roblox refuse les animations d'autres créateurs).
-- Modèles : place-les dans ServerStorage > Assets avec le nom indiqué.

local Assets = {}

Assets.Animations = {
	Idle = "",
	Run = "",
	Sprint = "",
	Jump = "",
	Fall = "",
	Dash = "",
	ShootCharge = "", -- boucle pendant la charge du tir
	Shoot = "",
	Pass = "",
	Catch = "",
	Dive = "", -- plongeon du gardien
	Block = "", -- contre / bras levés
	Contact = "",
	Stunned = "",
	Celebrate = "",
	KeeperReady = "", -- posture d'attente du gardien
} :: { [string]: string }

Assets.Sounds = {
	Whistle = "",
	Goal = "",
	Crowd = "",
	Shot = "",
	PerfectShot = "",
	Pass = "",
	Bounce = "",
	Dash = "",
	Power = "",
	Ultimate = "",
	Click = "",
	Hover = "",
	Reveal = "",
	LobbyMusic = "",
	MatchMusic = "",
} :: { [string]: string }

-- Noms des modèles attendus dans ServerStorage > Assets.
Assets.Models = {
	LobbySchool = "LobbySchool", -- bâtiment principal du lycée
	LobbyTrees = "Cerisier", -- un arbre, cloné dans la cour
	Gym = "Gymnase", -- intérieur de gymnase pour les matchs (doit contenir une Part « Centre »)
} :: { [string]: string }

function Assets.animation(name: string): string?
	local id = Assets.Animations[name]
	return if id and id ~= "" then id else nil
end

function Assets.sound(name: string): string?
	local id = Assets.Sounds[name]
	return if id and id ~= "" then id else nil
end

return Assets
