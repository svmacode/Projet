--!strict
-- Orchestration des matchs.
--   * Lobby en Studio : le match se joue sur un terrain construit à l'écart,
--     puis les joueurs reviennent au lobby.
--   * Serveur réservé (en ligne) : lit la configuration déposée par le
--     matchmaking, attend les joueurs, joue le match, distribue les
--     récompenses et renvoie tout le monde au lobby.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Clan = require(script.Parent.Clan)
local Match = require(script.Parent.Parent.Match.Match)
local Party = require(script.Parent.Party)
local PlayerData = require(script.Parent.PlayerData)
local ProgressionSystem = require(script.Parent.Progression)
local Remote = require(script.Parent.Parent.Lib.Remote)
local ServerRole = require(script.Parent.Parent.Lib.ServerRole)

export type MatchConfig = Match.MatchConfig & { Parties: { { number } }? }

local Matches = {}

local busy: { [Player]: any } = {}
local usedSlots: { [number]: boolean } = {}

function Matches.isBusy(player: Player): boolean
	return busy[player] ~= nil
end

local function playerInfo(player: Player): Match.PlayerInfo
	local profile = PlayerData.get(player)
	if not profile then
		return { KitId = "Lycee", Equipped = {}, SelectedArchetype = {}, OwnedArchetypes = {} }
	end
	local kitId = if Progression.isKitUnlocked(profile.Kit, profile.Level) then profile.Kit else "Lycee"
	return {
		KitId = kitId,
		Equipped = table.clone(profile.Equipped),
		SelectedArchetype = table.clone(profile.SelectedArchetype),
		OwnedArchetypes = table.clone(profile.Archetypes),
		ClanTag = Clan.tagOf(player),
	}
end

local function folder(): Folder
	local existing = Workspace:FindFirstChild("Matchs")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "Matchs"
	created.Parent = Workspace
	return created
end

local function grantRewards(match: any, results: any)
	for player, result in results.PerPlayer do
		local summary = ProgressionSystem.grantMatchRewards(player, result)
		Remote.fire(player, "MatchEvent", "End", {
			Winner = results.Winner,
			Score = results.Score,
			MVP = results.MVP,
			Table = results.Table,
			Rewards = summary,
			Outcome = result.Outcome,
			Forfeit = results.Forfeit,
			Ranked = match.Config.Ranked,
			Training = match.Config.Training,
		})
		if result.Outcome == "Win" and not result.Training then
			Clan.recordWin(player)
		end
	end
end

local function runMatch(config: MatchConfig, players: { Player }, origin: CFrame, onCreated: (() -> ())?): any
	local infos: { [Player]: Match.PlayerInfo } = {}
	for _, player in players do
		infos[player] = playerInfo(player)
	end
	local match = Match.new(config, players, infos, origin, folder())
	if onCreated then
		onCreated()
	end
	for _, player in players do
		busy[player] = match
	end
	local ok, results = pcall(match.run, match)
	if not ok then
		warn(`[Matches] erreur pendant le match : {results}`)
		results = nil
	end
	if results then
		grantRewards(match, results)
	end
	task.wait(Config.Match.EndScreenTime)
	match:destroy()
	for _, player in players do
		if busy[player] == match then
			busy[player] = nil
		end
	end
	return results
end

-- En Studio : le match a lieu dans le serveur du lobby.
function Matches.startLocal(config: MatchConfig, players: { Player })
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	task.spawn(function()
		runMatch(config, players, CFrame.new(3000 + slot * 700, 0, 0))
		usedSlots[slot] = nil
		for _, player in players do
			if player.Parent == Players then
				Remote.fire(player, "QueueUpdated", { State = "Idle" })
				Remote.fire(player, "MatchEvent", "Leave", {})
				player:LoadCharacterAsync()
			end
		end
	end)
end

-- Serveur de match réservé ----------------------------------------------------------------

local function returnToLobby(players: { Player }, parties: { { number } }?)
	if #players == 0 then
		return
	end
	-- Reformer les groupes d'origine au retour.
	if parties then
		for _, ids in parties do
			local group = {}
			for _, userId in ids do
				local player = Players:GetPlayerByUserId(userId)
				if player then
					table.insert(group, player)
				end
			end
			Party.rememberForReturn(group)
		end
	end
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, players)
	end)
	if not ok then
		warn(`[Matches] retour au lobby impossible : {err}`)
		for _, player in players do
			player:Kick("Match terminé ! Relance le jeu pour retourner au lobby.")
		end
	end
end

-- Plateforme provisoire : les joueurs arrivent avant la construction du terrain.
local function buildWaitingArea(): Model
	local area = Instance.new("Model")
	area.Name = "SalleAttente"
	local floor = Instance.new("Part")
	floor.Name = "Sol"
	floor.Anchored = true
	floor.Size = Vector3.new(120, 2, 120)
	floor.CFrame = CFrame.new(0, -1, 0)
	floor.Color = Color3.fromRGB(214, 150, 84)
	floor.Material = Enum.Material.WoodPlanks
	floor.Parent = area
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 0.4, 12)
	spawn.CFrame = CFrame.new(0, 0.2, 0)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = area
	area.Parent = Workspace
	return area
end

local function hostReservedMatch()
	local waitingArea = buildWaitingArea()
	local map = MemoryStoreService:GetHashMap("HL_Matches")
	local config: MatchConfig? = nil
	for _ = 1, 25 do
		local ok, raw = pcall(function()
			return map:GetAsync(game.PrivateServerId)
		end)
		if ok and typeof(raw) == "string" then
			local decoded, data = pcall(HttpService.JSONDecode, HttpService, raw)
			if decoded and type(data) == "table" then
				config = data :: any
				break
			end
		end
		task.wait(1)
	end
	if not config then
		warn("[Matches] configuration de match introuvable")
		task.wait(3)
		returnToLobby(Players:GetPlayers(), nil)
		return
	end
	local expected: { [number]: boolean } = {}
	local expectedCount = 0
	for _, team in { config.Teams.Rouge, config.Teams.Bleu } do
		for _, userId in team do
			expected[userId] = true
			expectedCount += 1
		end
	end

	-- Les joueurs qui ne font pas partie du match sont renvoyés au lobby.
	local function screen(player: Player)
		if not expected[player.UserId] then
			returnToLobby({ player }, nil)
		end
	end
	Players.PlayerAdded:Connect(screen)
	for _, player in Players:GetPlayers() do
		screen(player)
	end

	local deadline = os.clock() + Config.Server.MatchJoinTimeout
	local function present(): { Player }
		local list = {}
		for _, player in Players:GetPlayers() do
			if expected[player.UserId] and PlayerData.get(player) then
				table.insert(list, player)
			end
		end
		return list
	end
	while os.clock() < deadline and #present() < expectedCount do
		task.wait(0.5)
	end
	local players = present()
	if #players == 0 then
		return
	end
	runMatch(config, players, CFrame.new(0, 0, 0), function()
		-- Le terrain est construit : la plateforme provisoire disparaît
		-- (le point d'apparition reste pour les réapparitions).
		local floor = waitingArea:FindFirstChild("Sol")
		if floor then
			floor:Destroy()
		end
	end)
	returnToLobby(Players:GetPlayers(), config.Parties)
end

function Matches.init()
	Remote.onEvent("MatchAction", 30, 45, function(player, action, a, b)
		local match = busy[player]
		if match and typeof(action) == "string" then
			match:handleAction(player, action, a, b)
		end
	end)
	Remote.onInvoke("MatchSetupAction", 6, 12, function(player, action, arg)
		local match = busy[player]
		if not match or typeof(action) ~= "string" then
			return Remote.fail("Aucun match en cours.")
		end
		local ok, err = match:handleSetup(player, action, arg)
		return if ok then Remote.ok() else Remote.fail(err or "Impossible.")
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

function Matches.start()
	if ServerRole.Role == "Match" then
		task.spawn(hostReservedMatch)
	end
end

return Matches
