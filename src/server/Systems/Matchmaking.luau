--!strict
-- Lancement des matchs à partir d'équipes déjà formées (terrains du lobby,
-- voir Pads.luau). Tous les joueurs d'un match sont sur le même serveur
-- lobby : aucune file partagée n'est nécessaire.
--
-- En ligne :
--   1. On réserve un serveur privé (ReserveServer).
--   2. On y dépose la configuration du match (MemoryStore HashMap, lue par
--      Matches.hostReservedMatch sur le serveur réservé).
--   3. On téléporte les joueurs (TeleportAsync).
-- En Studio : le match se joue dans ce serveur (Matches.startLocal).

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")

local Matches = require(script.Parent.Matches)
local Party = require(script.Parent.Party)
local Remote = require(script.Parent.Parent.Lib.Remote)
local Retry = require(script.Parent.Parent.Lib.Retry)
local ServerRole = require(script.Parent.Parent.Lib.ServerRole)

export type MatchConfig = Matches.MatchConfig

export type LaunchSpec = {
	Mode: string,
	Ranked: boolean,
	Training: boolean,
	FillBots: boolean,
	Rouge: { Player },
	Bleu: { Player },
	Parties: { { number } }?,
}

local CONFIG_TTL = 900 -- secondes de vie de la configuration déposée

local Matchmaking = {}

local matchesMap: MemoryStoreHashMap? = nil

local function idsOf(players: { Player }): { number }
	local ids = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	return ids
end

-- Démarre un match. Peut céder (réservation, MemoryStore, téléportation) :
-- à appeler dans un thread dédié. Renvoie false + message en cas d'échec.
function Matchmaking.launch(spec: LaunchSpec): (boolean, string?)
	local everyone: { Player } = {}
	for _, team in { spec.Rouge, spec.Bleu } do
		for _, player in team do
			table.insert(everyone, player)
		end
	end
	if #everyone == 0 then
		return false, "Aucun joueur."
	end
	local config: MatchConfig = {
		Id = HttpService:GenerateGUID(false),
		Mode = spec.Mode,
		Ranked = spec.Ranked,
		Training = spec.Training,
		FillBots = spec.FillBots,
		Teams = { Rouge = idsOf(spec.Rouge), Bleu = idsOf(spec.Bleu) },
		Parties = spec.Parties,
	}

	if ServerRole.LocalMatches then
		Matches.startLocal(config, everyone)
		return true, nil
	end

	local map = matchesMap
	if not map then
		return false, "Service de match indisponible, réessaie."
	end
	local reserved, server = Retry.call("ReserveServer", 3, function()
		local code, id = TeleportService:ReserveServer(game.PlaceId)
		return { Code = code, Id = id }
	end)
	local accessCode = server and server.Code
	local privateServerId = server and server.Id
	if not reserved or typeof(accessCode) ~= "string" or typeof(privateServerId) ~= "string" then
		return false, "Impossible de créer le terrain, réessaie."
	end
	local encoded = HttpService:JSONEncode(config)
	local stored = Retry.call("ConfigMatch", 3, function()
		return map:SetAsync(privateServerId, encoded, CONFIG_TTL)
	end)
	if not stored then
		return false, "Impossible de créer le terrain, réessaie."
	end

	-- Groupes d'origine : reformés au retour au lobby.
	if spec.Parties then
		for _, ids in spec.Parties do
			local group = {}
			for _, player in everyone do
				if table.find(ids, player.UserId) then
					table.insert(group, player)
				end
			end
			Party.rememberForReturn(group)
		end
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	local teleported, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, everyone, options)
	end)
	if not teleported then
		warn(`[Matchmaking] téléportation échouée : {err}`)
		return false, "La téléportation a échoué, réessaie."
	end
	return true, nil
end

function Matchmaking.init()
	if ServerRole.Role ~= "Lobby" or ServerRole.LocalMatches then
		return
	end
	-- Une téléportation peut échouer après coup : on libère le bandeau du terrain.
	TeleportService.TeleportInitFailed:Connect(function(player)
		Remote.fire(player, "PadState", nil)
		Remote.notify(player, "La téléportation a échoué, réessaie.", "Danger")
	end)
	local ok, map = pcall(function()
		return MemoryStoreService:GetHashMap("HL_Matches")
	end)
	if ok then
		matchesMap = map
	end
end

return Matchmaking
