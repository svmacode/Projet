--!strict
-- Données joueur : chargement avec verrouillage de session, sauvegarde
-- automatique, sauvegarde à la sortie et à l'arrêt du serveur.
--
-- Format stocké : { Data = Profile, Lock = { JobId, Time }? }
-- Un seul serveur possède le profil à la fois. C'est indispensable pour les
-- téléportations lobby <-> match, et cela empêche la duplication d'objets.
--
-- Le reste du jeu ne touche JAMAIS au DataStore : il passe par
-- PlayerData.get / PlayerData.update.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local Remote = require(script.Parent.Parent.Lib.Remote)

type Profile = Types.Profile

local CURRENT_VERSION = 1
local MAX_RECEIPTS = 60

local PlayerData = {}

PlayerData.Loaded = Signal.new() :: Signal.Signal<Player, Profile>
PlayerData.Changed = Signal.new() :: Signal.Signal<Player, Profile>

local profiles: { [Player]: Profile } = {}
local canSave: { [Player]: boolean } = {}
local dirtyReplication: { [Player]: boolean } = {}
local store: DataStore? = nil
local offlineMode = false

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[key] = deepCopy(child)
	end
	return copy :: any
end

local function defaultProfile(): Profile
	local owned: { [string]: boolean } = {}
	for _, id in Archetypes.Starters do
		owned[id] = true
	end
	return {
		Version = CURRENT_VERSION,
		Coins = 0,
		XP = 0,
		Level = 1,
		Balls = {},
		CosmeticPacks = 0,
		Archetypes = owned,
		SelectedArchetype = { Gardien = "Mamoru", Defenseur = "Tetsuo", Attaquant = "Hayato" },
		Cosmetics = {},
		Equipped = {},
		Kit = "Lycee",
		Stats = {
			Matches = 0,
			Wins = 0,
			Losses = 0,
			Draws = 0,
			Goals = 0,
			Assists = 0,
			Saves = 0,
			Interceptions = 0,
			MVPs = 0,
		},
		RP = Config.Ranked.StartingRP,
		PeakRP = Config.Ranked.StartingRP,
		RankedMatches = 0,
		FirstMatchRewarded = false,
		Pity = 0,
		TutorialDone = false,
		ClanId = nil,
		ClanCredits = 0,
		Receipts = {},
		SeenPatch = "",
		Settings = { CameraLock = true, Music = true },
	}
end

-- Complète les champs manquants (nouveaux champs ajoutés après coup).
local function reconcile(target: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			reconcile(target[key], value)
		end
	end
end

-- Migrations de schéma : MIGRATIONS[v] transforme un profil v en v + 1.
local MIGRATIONS: { [number]: (any) -> any } = {}

local function migrate(data: any): Profile
	if type(data.Version) ~= "number" then
		data.Version = CURRENT_VERSION
	end
	while data.Version < CURRENT_VERSION do
		local step = MIGRATIONS[data.Version]
		if not step then
			error(`migration manquante depuis v{data.Version}`)
		end
		data = step(data)
		data.Version += 1
	end
	reconcile(data, defaultProfile() :: any)
	-- Les archétypes de départ sont toujours possédés.
	for _, id in Archetypes.Starters do
		data.Archetypes[id] = true
	end
	return data
end

local function keyFor(userId: number): string
	return `Player_{userId}`
end

local function now(): number
	return os.time()
end

-- Chargement -------------------------------------------------------------------

type LoadOutcome = "Loaded" | "Locked" | "Failed"

local function tryClaim(userId: number, steal: boolean): (LoadOutcome, any)
	assert(store, "store")
	local lockedByOther = false
	local ok, result = pcall(function()
		return store:UpdateAsync(keyFor(userId), function(old: any)
			lockedByOther = false
			local record = if type(old) == "table" then old else {}
			local lock = record.Lock
			if
				not steal
				and type(lock) == "table"
				and lock.JobId ~= game.JobId
				and now() - (tonumber(lock.Time) or 0) < Config.Data.LockStaleAfter
			then
				lockedByOther = true
				return nil -- on n'écrit rien : un autre serveur possède le profil
			end
			record.Lock = { JobId = game.JobId, Time = now() }
			return record
		end)
	end)
	if not ok then
		return "Failed", result
	end
	if lockedByOther then
		return "Locked", nil
	end
	return "Loaded", result
end

local function loadRecord(userId: number): (boolean, any)
	for attempt = 1, 8 do
		-- Après plusieurs essais, on considère que l'ancien serveur a planté.
		local steal = attempt >= 7
		local outcome, record = tryClaim(userId, steal)
		if outcome == "Loaded" then
			return true, record
		end
		if outcome == "Failed" then
			warn(`[PlayerData] chargement {userId} tentative {attempt} : {record}`)
			if RunService:IsStudio() then
				-- Accès API probablement désactivé en Studio : inutile d'insister.
				return false, nil
			end
		end
		task.wait(math.min(2 ^ (attempt - 1), 6))
	end
	return false, nil
end

local function snapshotFor(profile: Profile): any
	local snapshot = deepCopy(profile) :: any
	snapshot.Receipts = nil
	return snapshot
end

local function replicate(player: Player)
	dirtyReplication[player] = true
end

local function onPlayerAdded(player: Player)
	local profile: Profile
	if offlineMode or not store then
		profile = defaultProfile()
		canSave[player] = false
	else
		local ok, record = loadRecord(player.UserId)
		if not ok then
			if RunService:IsStudio() then
				warn("[PlayerData] DataStore indisponible en Studio : profil temporaire (non sauvegardé).")
				profile = defaultProfile()
				canSave[player] = false
			else
				player:Kick("Tes données n'ont pas pu être chargées. Reviens dans un instant !")
				return
			end
		else
			local data = if type(record) == "table" and type(record.Data) == "table"
				then record.Data
				else defaultProfile()
			local migrated, result = pcall(migrate, data)
			if not migrated then
				warn(`[PlayerData] migration impossible pour {player.UserId} : {result}`)
				player:Kick("Erreur de données. Contacte le support du jeu.")
				return
			end
			profile = result
			canSave[player] = true
		end
	end
	if player.Parent ~= Players then
		-- Parti pendant le chargement : on libère le verrou.
		if canSave[player] then
			task.spawn(PlayerData.save, player, true, profile)
		end
		canSave[player] = nil
		return
	end
	profiles[player] = profile
	player:SetAttribute("Level", profile.Level)
	player:SetAttribute("ClanId", profile.ClanId or "")
	PlayerData.Loaded:Fire(player, profile)
	replicate(player)
end

-- Sauvegarde ----------------------------------------------------------------------

function PlayerData.save(player: Player, release: boolean, overrideProfile: Profile?): boolean
	local profile = overrideProfile or profiles[player]
	if not profile or not canSave[player] or not store then
		return false
	end
	local snapshot = deepCopy(profile)
	local userId = player.UserId
	local lostLock = false
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(userId), function(old: any)
			lostLock = false
			local record = if type(old) == "table" then old else {}
			local lock = record.Lock
			if type(lock) == "table" and lock.JobId ~= game.JobId then
				-- Un autre serveur a pris le profil : ne surtout pas l'écraser.
				lostLock = true
				return nil
			end
			record.Data = snapshot
			record.Lock = if release then nil else { JobId = game.JobId, Time = now() }
			return record
		end)
	end)
	if not ok then
		warn(`[PlayerData] sauvegarde {userId} : {err}`)
		return false
	end
	if lostLock then
		warn(`[PlayerData] verrou perdu pour {userId}, sauvegarde ignorée`)
		canSave[player] = false
		return false
	end
	return true
end

-- API publique -----------------------------------------------------------------

function PlayerData.get(player: Player): Profile?
	return profiles[player]
end

function PlayerData.waitFor(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 30)
	while not profiles[player] and player.Parent == Players and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

-- Modifie le profil en mémoire. Le callback ne doit pas yield.
function PlayerData.update(player: Player, callback: (Profile) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	callback(profile)
	player:SetAttribute("Level", profile.Level)
	player:SetAttribute("ClanId", profile.ClanId or "")
	replicate(player)
	PlayerData.Changed:Fire(player, profile)
	return true
end

function PlayerData.hasReceipt(player: Player, receiptId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and table.find(profile.Receipts, receiptId) ~= nil
end

function PlayerData.recordReceipt(profile: Profile, receiptId: string)
	table.insert(profile.Receipts, receiptId)
	while #profile.Receipts > MAX_RECEIPTS do
		table.remove(profile.Receipts, 1)
	end
end

function PlayerData.isPersistent(player: Player): boolean
	return canSave[player] == true
end

function PlayerData.snapshot(player: Player): any
	local profile = profiles[player]
	return if profile then snapshotFor(profile) else nil
end

-- Cycle de vie -----------------------------------------------------------------------

function PlayerData.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.ProfileStore)
	end)
	if ok then
		store = result
	else
		offlineMode = true
		warn(`[PlayerData] DataStore indisponible : {result}`)
	end

	Remote.onInvoke("GetProfile", 4, 8, function(player)
		local profile = PlayerData.waitFor(player, 20)
		if not profile then
			return Remote.fail("Profil indisponible.")
		end
		return Remote.ok({ Profile = snapshotFor(profile) })
	end)
end

function PlayerData.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		if profiles[player] then
			PlayerData.save(player, true)
		end
		profiles[player] = nil
		canSave[player] = nil
		dirtyReplication[player] = nil
	end)

	-- Réplication groupée vers le client (au plus 10 fois par seconde).
	task.spawn(function()
		while true do
			task.wait(0.1)
			for player in dirtyReplication do
				dirtyReplication[player] = nil
				local profile = profiles[player]
				if profile then
					Remote.fire(player, "ProfileUpdated", snapshotFor(profile))
				end
			end
		end
	end)

	-- Sauvegarde automatique étalée : chaque joueur a son propre décalage.
	task.spawn(function()
		local interval = Config.Data.AutosaveInterval
		while true do
			task.wait(1)
			local tick = os.time()
			for player in profiles do
				if (tick + player.UserId) % interval == 0 then
					task.spawn(PlayerData.save, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				PlayerData.save(player, true)
				pending -= 1
			end)
		end
		if RunService:IsStudio() then
			return
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

-- Identifiant unique utilisable par d'autres systèmes.
function PlayerData.newId(): string
	return HttpService:GenerateGUID(false)
end

return PlayerData
