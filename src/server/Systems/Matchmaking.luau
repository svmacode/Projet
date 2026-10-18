--!strict
-- Recherche de partie (« Recherche ») et entraînement entre amis.
--
-- En ligne (comme Rivals) :
--   1. Le groupe entre dans une file partagée entre tous les serveurs lobby
--      (MemoryStore SortedMap, une file par mode et par type).
--   2. Un seul serveur à la fois (verrou MemoryStore) forme les équipes.
--   3. Il réserve un serveur privé, y dépose la configuration du match
--      (MemoryStore HashMap) et prévient les autres lobbies (MessagingService).
--   4. Chaque lobby téléporte ses propres joueurs vers le serveur réservé.
--
-- En Studio : la file est locale et le match se joue dans ce serveur.
-- Si personne ne rejoint, des bots complètent les équipes (pour tester seul).

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Matches = require(script.Parent.Matches)
local Party = require(script.Parent.Party)
local PlayerData = require(script.Parent.PlayerData)
local Remote = require(script.Parent.Parent.Lib.Remote)
local ServerRole = require(script.Parent.Parent.Lib.ServerRole)

export type MatchConfig = Matches.MatchConfig

type Entry = {
	Key: string,
	UserIds: { number },
	Size: number,
	Rating: number,
	Joined: number,
	Job: string,
}

type LocalSearch = {
	Entry: Entry,
	Mode: string,
	Ranked: boolean,
}

local MATCH_FOUND_TOPIC = "HL_MatchFound"
local STUDIO_BOT_FILL_DELAY = 6

local Matchmaking = {}

local searches: { [string]: LocalSearch } = {} -- clé d'entrée -> recherche de ce serveur
local searchOf: { [number]: string } = {} -- UserId -> clé d'entrée
local matchesMap: MemoryStoreHashMap? = nil
local lockMap: MemoryStoreSortedMap? = nil

local function queueName(mode: string, ranked: boolean): string
	return `HL_Q_{mode}_{if ranked then "R" else "N"}`
end

local function playersOf(entry: Entry): { Player }
	local list = {}
	for _, userId in entry.UserIds do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			table.insert(list, player)
		end
	end
	return list
end

local function setStatus(players: { Player }, status: any)
	Remote.fireList(players, "QueueUpdated", status)
end

-- Formation des équipes (fonction pure) -----------------------------------------------

type Formed = { Rouge: { Entry }, Bleu: { Entry } }

local function formMatches(
	entries: { Entry },
	teamSize: number,
	ranked: boolean,
	now: number
): ({ Formed }, { [string]: boolean })
	table.sort(entries, function(a, b)
		return a.Joined < b.Joined
	end)
	local used: { [string]: boolean } = {}
	local formed: { Formed } = {}
	for i, anchor in entries do
		if used[anchor.Key] then
			continue
		end
		-- La tolérance de niveau s'élargit avec l'attente (classé).
		local window = 150 + (now - anchor.Joined) * 20
		local teams = { { list = {} :: { Entry }, count = 0 }, { list = {} :: { Entry }, count = 0 } }
		local function tryAdd(entry: Entry): boolean
			for _, team in teams do
				if team.count + entry.Size <= teamSize then
					table.insert(team.list, entry)
					team.count += entry.Size
					return true
				end
			end
			return false
		end
		tryAdd(anchor)
		for j = i + 1, #entries do
			local candidate = entries[j]
			if not used[candidate.Key] and (not ranked or math.abs(candidate.Rating - anchor.Rating) <= window) then
				tryAdd(candidate)
				if teams[1].count == teamSize and teams[2].count == teamSize then
					break
				end
			end
		end
		if teams[1].count == teamSize and teams[2].count == teamSize then
			for _, team in teams do
				for _, entry in team.list do
					used[entry.Key] = true
				end
			end
			table.insert(formed, { Rouge = teams[1].list, Bleu = teams[2].list })
		end
	end
	return formed, used
end

local function idsOf(list: { Entry }): { number }
	local ids = {}
	for _, entry in list do
		for _, userId in entry.UserIds do
			table.insert(ids, userId)
		end
	end
	return ids
end

-- Lancement d'un match --------------------------------------------------------------------

local function newConfig(
	mode: string,
	ranked: boolean,
	training: boolean,
	fillBots: boolean,
	rouge: { number },
	bleu: { number },
	parties: { { number } }?
): MatchConfig
	return {
		Id = HttpService:GenerateGUID(false),
		Mode = mode,
		Ranked = ranked,
		Training = training,
		FillBots = fillBots,
		Teams = { Rouge = rouge, Bleu = bleu },
		Parties = parties,
	}
end

-- Groupes d'origine (pour les reformer au retour au lobby).
local function partiesOf(formed: Formed): { { number } }
	local parties = {}
	for _, team in { formed.Rouge, formed.Bleu } do
		for _, entry in team do
			if #entry.UserIds > 1 then
				table.insert(parties, entry.UserIds)
			end
		end
	end
	return parties
end

local function clearSearchFor(userIds: { number })
	for _, userId in userIds do
		local key = searchOf[userId]
		if key then
			searches[key] = nil
		end
		searchOf[userId] = nil
	end
end

local function teleportPlayers(players: { Player }, accessCode: string)
	if #players == 0 then
		return
	end
	setStatus(players, { State = "Teleporting", Message = "Téléportation vers le terrain…" })
	Party.rememberForReturn(players)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, players, options)
	end)
	if not ok then
		warn(`[Matchmaking] téléportation échouée : {err}`)
		setStatus(players, { State = "Idle", Message = "La téléportation a échoué, réessaie." })
	end
end

-- Démarre un match : sur place en Studio, sur un serveur réservé en ligne.
local function launch(config: MatchConfig)
	local all = {}
	for _, userId in config.Teams.Rouge do
		table.insert(all, userId)
	end
	for _, userId in config.Teams.Bleu do
		table.insert(all, userId)
	end
	clearSearchFor(all)

	if ServerRole.LocalMatches then
		local players = {}
		for _, userId in all do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				table.insert(players, player)
			end
		end
		setStatus(players, { State = "Found", Message = "Match trouvé !" })
		Matches.startLocal(config, players)
		return
	end

	local map = matchesMap
	if not map then
		return
	end
	local ok, accessCode, privateServerId = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not ok or typeof(accessCode) ~= "string" or typeof(privateServerId) ~= "string" then
		warn(`[Matchmaking] ReserveServer a échoué : {accessCode}`)
		return
	end
	local stored = pcall(function()
		map:SetAsync(privateServerId, HttpService:JSONEncode(config), 900)
	end)
	if not stored then
		warn("[Matchmaking] impossible d'enregistrer la configuration du match")
		return
	end
	local message = { Code = accessCode, Ids = all }
	local published = pcall(function()
		MessagingService:PublishAsync(MATCH_FOUND_TOPIC, HttpService:JSONEncode(message))
	end)
	if not published then
		-- Au moins les joueurs de ce serveur partent.
		local localPlayers = {}
		for _, userId in all do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				table.insert(localPlayers, player)
			end
		end
		teleportPlayers(localPlayers, accessCode)
	end
end

local function onMatchFound(raw: any)
	local ok, message = pcall(HttpService.JSONDecode, HttpService, raw.Data)
	if not ok or type(message) ~= "table" or typeof(message.Code) ~= "string" or type(message.Ids) ~= "table" then
		return
	end
	local localPlayers = {}
	for _, userId in message.Ids do
		local player = typeof(userId) == "number" and Players:GetPlayerByUserId(userId)
		if player then
			table.insert(localPlayers, player)
		end
	end
	if #localPlayers > 0 then
		local ids = {}
		for _, player in localPlayers do
			table.insert(ids, player.UserId)
		end
		clearSearchFor(ids)
		teleportPlayers(localPlayers, message.Code)
	end
end

-- File locale (Studio) ----------------------------------------------------------------

local function tickLocal()
	local now = os.time()
	local byQueue: { [string]: { entries: { Entry }, mode: string, ranked: boolean } } = {}
	for _, search in searches do
		local name = queueName(search.Mode, search.Ranked)
		local bucket = byQueue[name]
		if not bucket then
			bucket = { entries = {}, mode = search.Mode, ranked = search.Ranked }
			byQueue[name] = bucket
		end
		table.insert(bucket.entries, search.Entry)
	end
	for _, bucket in byQueue do
		local teamSize = Config.Modes[bucket.mode].TeamSize
		local formed, used = formMatches(bucket.entries, teamSize, bucket.ranked, now)
		for _, match in formed do
			launch(
				newConfig(
					bucket.mode,
					bucket.ranked,
					false,
					false,
					idsOf(match.Rouge),
					idsOf(match.Bleu),
					partiesOf(match)
				)
			)
		end
		if ServerRole.IsStudio then
			-- Tests en solo : au-delà d'un court délai, des bots complètent.
			for _, entry in bucket.entries do
				if not used[entry.Key] and searches[entry.Key] and now - entry.Joined >= STUDIO_BOT_FILL_DELAY then
					launch(newConfig(bucket.mode, false, false, true, entry.UserIds, {}))
				end
			end
		end
	end
end

-- File partagée (en ligne) -----------------------------------------------------------------

local function decodeEntry(value: any): Entry?
	local ok, data = pcall(HttpService.JSONDecode, HttpService, value)
	if not ok or type(data) ~= "table" or type(data.UserIds) ~= "table" then
		return nil
	end
	return data :: Entry
end

local function tryLeadQueue(name: string): boolean
	local map = lockMap
	if not map then
		return false
	end
	local isLeader = false
	pcall(function()
		map:UpdateAsync(name, function(old: any)
			local now = os.time()
			if type(old) == "table" and old.Job ~= game.JobId and (old.Expires or 0) > now then
				isLeader = false
				return nil
			end
			isLeader = true
			return { Job = game.JobId, Expires = now + 8 }
		end, 15)
	end)
	return isLeader
end

local function tickShared()
	local now = os.time()
	for _, mode in Config.ModeOrder do
		for _, ranked in { false, true } do
			if ranked and not Config.Modes[mode].RankedAllowed then
				continue
			end
			local name = queueName(mode, ranked)
			if not tryLeadQueue(name) then
				continue
			end
			local queue = MemoryStoreService:GetSortedMap(name)
			local ok, items = pcall(function()
				return queue:GetRangeAsync(Enum.SortDirection.Ascending, 100)
			end)
			if not ok or type(items) ~= "table" or #items == 0 then
				continue
			end
			local entries = {}
			for _, item in items do
				local entry = decodeEntry(item.value)
				if entry then
					table.insert(entries, entry)
				end
			end
			local formed = formMatches(entries, Config.Modes[mode].TeamSize, ranked, now)
			for _, match in formed do
				for _, team in { match.Rouge, match.Bleu } do
					for _, entry in team do
						pcall(function()
							queue:RemoveAsync(entry.Key)
						end)
					end
				end
				task.spawn(
					launch,
					newConfig(mode, ranked, false, false, idsOf(match.Rouge), idsOf(match.Bleu), partiesOf(match))
				)
			end
		end
	end
end

local function publishEntry(search: LocalSearch)
	local queue = MemoryStoreService:GetSortedMap(queueName(search.Mode, search.Ranked))
	pcall(function()
		queue:SetAsync(
			search.Entry.Key,
			HttpService:JSONEncode(search.Entry),
			Config.Server.QueueEntryTtl,
			search.Entry.Joined
		)
	end)
end

local function withdrawEntry(search: LocalSearch)
	if ServerRole.LocalMatches then
		return
	end
	local queue = MemoryStoreService:GetSortedMap(queueName(search.Mode, search.Ranked))
	pcall(function()
		queue:RemoveAsync(search.Entry.Key)
	end)
end

-- Actions -------------------------------------------------------------------------------

local function cancelSearch(key: string, message: string?)
	local search = searches[key]
	if not search then
		return
	end
	searches[key] = nil
	for _, userId in search.Entry.UserIds do
		searchOf[userId] = nil
	end
	task.spawn(withdrawEntry, search)
	setStatus(playersOf(search.Entry), { State = "Idle", Message = message })
end

local function validateGroup(player: Player): ({ Player }?, string?)
	if not Party.isLeaderOrSolo(player) then
		return nil, "Seul le chef du groupe peut lancer une partie."
	end
	local members = Party.membersOf(player)
	for _, member in members do
		if not PlayerData.get(member) then
			return nil, `{member.DisplayName} n'est pas encore prêt.`
		end
		if searchOf[member.UserId] then
			return nil, "Une recherche est déjà en cours."
		end
		if Matches.isBusy(member) then
			return nil, `{member.DisplayName} est déjà en match.`
		end
	end
	return members, nil
end

local ACTIONS: { [string]: (Player, any, any) -> Remote.Result } = {}

ACTIONS.Search = function(player, modeArg, rankedArg)
	local mode = Guard.oneOf(modeArg, Config.ModeOrder)
	local ranked = Guard.boolean(rankedArg)
	if not mode or ranked == nil then
		return Remote.fail("Mode invalide.")
	end
	local modeInfo = Config.Modes[mode]
	if ranked and not modeInfo.RankedAllowed then
		return Remote.fail("Le classé se joue à partir du 3v3.")
	end
	local members, err = validateGroup(player)
	if not members then
		return Remote.fail(err or "Impossible.")
	end
	if #members > modeInfo.TeamSize then
		return Remote.fail(`Ton groupe est trop grand pour le {modeInfo.Label}.`)
	end
	local ratingTotal = 0
	local ids = {}
	for _, member in members do
		local profile = PlayerData.get(member)
		if not profile then
			return Remote.fail("Profil indisponible.")
		end
		if ranked and profile.Level < Config.RankedUnlockLevel then
			return Remote.fail(`{member.DisplayName} doit être niveau {Config.RankedUnlockLevel} pour le classé.`)
		end
		ratingTotal += profile.RP
		table.insert(ids, member.UserId)
	end
	local party = Party.ofPlayer(player)
	local entry: Entry = {
		Key = if party then party.Id else `solo_{player.UserId}`,
		UserIds = ids,
		Size = #ids,
		Rating = ratingTotal / #ids,
		Joined = os.time(),
		Job = game.JobId,
	}
	local search: LocalSearch = { Entry = entry, Mode = mode, Ranked = ranked }
	searches[entry.Key] = search
	for _, userId in ids do
		searchOf[userId] = entry.Key
	end
	if not ServerRole.LocalMatches then
		task.spawn(publishEntry, search)
	end
	setStatus(members, { State = "Searching", Mode = mode, Ranked = ranked, Since = entry.Joined })
	return Remote.ok()
end

ACTIONS.Cancel = function(player)
	local key = searchOf[player.UserId]
	if key then
		cancelSearch(key, "Recherche annulée.")
	end
	return Remote.ok()
end

ACTIONS.Training = function(player, modeArg, fillBotsArg)
	local mode = Guard.oneOf(modeArg, Config.ModeOrder)
	local fillBots = Guard.boolean(fillBotsArg)
	if not mode or fillBots == nil then
		return Remote.fail("Mode invalide.")
	end
	local members, err = validateGroup(player)
	if not members then
		return Remote.fail(err or "Impossible.")
	end
	local teamSize = Config.Modes[mode].TeamSize
	if #members > teamSize * 2 then
		return Remote.fail("Trop de joueurs pour ce mode.")
	end
	if #members < 2 and not fillBots then
		return Remote.fail("Invite un ami ou active les bots pour t'entraîner.")
	end
	local rouge, bleu = {}, {}
	for index, member in members do
		if index % 2 == 1 then
			table.insert(rouge, member.UserId)
		else
			table.insert(bleu, member.UserId)
		end
	end
	local everyone = {}
	for _, member in members do
		table.insert(everyone, member.UserId)
	end
	setStatus(members, { State = "Found", Training = true, Message = "Entraînement en préparation…" })
	task.spawn(launch, newConfig(mode, false, true, fillBots, rouge, bleu, { everyone }))
	return Remote.ok()
end

function Matchmaking.init()
	if ServerRole.Role ~= "Lobby" then
		return
	end
	if not ServerRole.LocalMatches then
		local ok1, map = pcall(function()
			return MemoryStoreService:GetHashMap("HL_Matches")
		end)
		if ok1 then
			matchesMap = map
		end
		local ok2, lock = pcall(function()
			return MemoryStoreService:GetSortedMap("HL_MatchmakingLock")
		end)
		if ok2 then
			lockMap = lock
		end
	end
	Remote.onInvoke("QueueAction", 3, 6, function(player, action, a, b)
		local handler = if typeof(action) == "string" then ACTIONS[action] else nil
		if not handler then
			return Remote.fail("Action inconnue.")
		end
		return handler(player, a, b)
	end)
	-- Toute modification du groupe annule sa recherche.
	Party.Changed:Connect(function(partyId)
		if searches[partyId] then
			cancelSearch(partyId, "Le groupe a changé : recherche annulée.")
		end
	end)
end

function Matchmaking.start()
	if ServerRole.Role ~= "Lobby" then
		return
	end
	Players.PlayerRemoving:Connect(function(player)
		local key = searchOf[player.UserId]
		if key then
			cancelSearch(key, "Un membre a quitté : recherche annulée.")
		end
	end)

	if ServerRole.LocalMatches then
		task.spawn(function()
			while true do
				task.wait(Config.Server.MatchmakingTick)
				tickLocal()
			end
		end)
		return
	end

	pcall(function()
		MessagingService:SubscribeAsync(MATCH_FOUND_TOPIC, onMatchFound)
	end)
	task.spawn(function()
		local lastRefresh = 0
		while true do
			task.wait(Config.Server.MatchmakingTick)
			-- Rafraîchit nos entrées pour qu'elles n'expirent pas.
			if os.clock() - lastRefresh > 30 then
				lastRefresh = os.clock()
				for _, search in searches do
					task.spawn(publishEntry, search)
				end
			end
			local result = table.pack(pcall(tickShared))
			if not result[1] then
				warn(`[Matchmaking] {result[2]}`)
			end
		end
	end)
end

return Matchmaking
