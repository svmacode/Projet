--!strict
-- Détermine le rôle de ce serveur.
--   Lobby : serveur public (menu, groupes, file d'attente).
--   Match : serveur réservé créé par le matchmaking (un seul match).
-- En Studio les téléportations sont impossibles : le lobby héberge les matchs
-- lui-même (LocalMatches).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local isStudio = RunService:IsStudio()
local isReserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0

local ServerRole = {
	IsStudio = isStudio,
	Role = if isReserved then "Match" else "Lobby",
	LocalMatches = isStudio and Config.Server.LocalMatchesInStudio,
}

-- Le client lit le rôle pour savoir s'il doit afficher le menu de départ.
ReplicatedStorage:SetAttribute("ServerRole", ServerRole.Role)

return ServerRole
