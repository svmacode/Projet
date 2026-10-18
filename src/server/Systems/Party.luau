--!strict
-- Groupes du lobby (comme Rivals) : inviter des joueurs du serveur, accepter,
-- quitter, exclure. Le chef choisit le mode et lance la recherche ou un
-- entraînement pour tout le groupe.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Guard = require(script.Parent.Parent.Lib.Guard)
local PlayerData = require(script.Parent.PlayerData)
local Remote = require(script.Parent.Parent.Lib.Remote)
local ServerRole = require(script.Parent.Parent.Lib.ServerRole)

export type Party = {
	Id: string,
	LeaderId: number,
	Members: { number }, -- UserIds, chef en premier
	Mode: string,
	Ranked: boolean,
}

local INVITE_TTL = 60

local Party = {}

-- Déclenché quand la composition d'un groupe change (le matchmaking annule
-- alors sa recherche).
Party.Changed = Signal.new() :: Signal.Signal<string>

local parties: { [string]: Party } = {}
local partyOf: { [number]: string } = {}
local invites: { [number]: { [string]: number } } = {} -- invité -> partyId -> expiration

local restoreMap: MemoryStoreHashMap? = nil

local function playerById(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

local function snapshot(party: Party): any
	local members = {}
	for _, userId in party.Members do
		local player = playerById(userId)
		local profile = player and PlayerData.get(player)
		table.insert(members, {
			UserId = userId,
			Name = if player then player.DisplayName else "?",
			Level = if profile then profile.Level else 1,
		})
	end
	return {
		Id = party.Id,
		LeaderId = party.LeaderId,
		Members = members,
		Mode = party.Mode,
		Ranked = party.Ranked,
	}
end

local function broadcast(party: Party)
	local data = snapshot(party)
	for _, userId in party.Members do
		local player = playerById(userId)
		if player then
			Remote.fire(player, "PartyUpdated", data)
		end
	end
	Party.Changed:Fire(party.Id)
end

local function createParty(leader: Player): Party
	local party: Party = {
		Id = HttpService:GenerateGUID(false),
		LeaderId = leader.UserId,
		Members = { leader.UserId },
		Mode = "3v3",
		Ranked = false,
	}
	parties[party.Id] = party
	partyOf[leader.UserId] = party.Id
	return party
end

local function removeMember(party: Party, userId: number)
	local index = table.find(party.Members, userId)
	if index then
		table.remove(party.Members, index)
	end
	partyOf[userId] = nil
	local player = playerById(userId)
	if player then
		Remote.fire(player, "PartyUpdated", nil)
	end
	if #party.Members <= 1 then
		-- Un groupe d'une seule personne n'a plus de raison d'exister.
		for _, remaining in party.Members do
			partyOf[remaining] = nil
			local remainingPlayer = playerById(remaining)
			if remainingPlayer then
				Remote.fire(remainingPlayer, "PartyUpdated", nil)
			end
		end
		parties[party.Id] = nil
		Party.Changed:Fire(party.Id)
		return
	end
	if party.LeaderId == userId then
		party.LeaderId = party.Members[1]
	end
	broadcast(party)
end

-- API ---------------------------------------------------------------------------

function Party.get(partyId: string): Party?
	return parties[partyId]
end

function Party.ofPlayer(player: Player): Party?
	local id = partyOf[player.UserId]
	return if id then parties[id] else nil
end

-- Joueurs connectés du groupe, ou le joueur seul.
function Party.membersOf(player: Player): { Player }
	local party = Party.ofPlayer(player)
	if not party then
		return { player }
	end
	local list = {}
	for _, userId in party.Members do
		local member = playerById(userId)
		if member then
			table.insert(list, member)
		end
	end
	return list
end

function Party.isLeaderOrSolo(player: Player): boolean
	local party = Party.ofPlayer(player)
	return party == nil or party.LeaderId == player.UserId
end

-- Mémorise le groupe pour le reformer après un match (autre serveur).
function Party.rememberForReturn(members: { Player })
	local map = restoreMap
	if not map or #members < 2 then
		return
	end
	local ids = {}
	for _, member in members do
		table.insert(ids, member.UserId)
	end
	local payload = HttpService:JSONEncode(ids)
	for _, member in members do
		pcall(function()
			map:SetAsync(tostring(member.UserId), payload, 600)
		end)
	end
end

-- Actions -------------------------------------------------------------------------

local ACTIONS: { [string]: (Player, any, any) -> Remote.Result } = {}

ACTIONS.Invite = function(player, userIdArg)
	local userId = Guard.integer(userIdArg, 1, 2 ^ 53)
	local target = userId and playerById(userId)
	if not target or target == player then
		return Remote.fail("Joueur introuvable.")
	end
	local party = Party.ofPlayer(player)
	if party and party.LeaderId ~= player.UserId then
		return Remote.fail("Seul le chef peut inviter.")
	end
	if party and #party.Members >= Config.MaxPartySize then
		return Remote.fail("Le groupe est complet.")
	end
	if partyOf[target.UserId] and partyOf[target.UserId] == (party and party.Id) then
		return Remote.fail("Déjà dans ton groupe.")
	end
	local ensured = party or createParty(player)
	invites[target.UserId] = invites[target.UserId] or {}
	invites[target.UserId][ensured.Id] = os.time() + INVITE_TTL
	Remote.fire(target, "PartyInvite", player.UserId, player.DisplayName, ensured.Id)
	if not party then
		broadcast(ensured)
	end
	return Remote.ok()
end

ACTIONS.Accept = function(player, partyIdArg)
	local partyId = Guard.string(partyIdArg, 64)
	local party = partyId and parties[partyId]
	local pending = invites[player.UserId]
	if not party or not partyId or not pending or not pending[partyId] or pending[partyId] < os.time() then
		return Remote.fail("Invitation expirée.")
	end
	if #party.Members >= Config.MaxPartySize then
		return Remote.fail("Le groupe est complet.")
	end
	pending[partyId] = nil
	local current = Party.ofPlayer(player)
	if current then
		removeMember(current, player.UserId)
	end
	table.insert(party.Members, player.UserId)
	partyOf[player.UserId] = party.Id
	broadcast(party)
	return Remote.ok()
end

ACTIONS.Decline = function(player, partyIdArg)
	local partyId = Guard.string(partyIdArg, 64)
	local pending = invites[player.UserId]
	if partyId and pending then
		pending[partyId] = nil
	end
	return Remote.ok()
end

ACTIONS.Leave = function(player)
	local party = Party.ofPlayer(player)
	if party then
		removeMember(party, player.UserId)
	end
	return Remote.ok()
end

ACTIONS.Kick = function(player, userIdArg)
	local userId = Guard.integer(userIdArg, 1, 2 ^ 53)
	local party = Party.ofPlayer(player)
	if not party or party.LeaderId ~= player.UserId or not userId or userId == player.UserId then
		return Remote.fail("Action impossible.")
	end
	if not table.find(party.Members, userId) then
		return Remote.fail("Ce joueur n'est pas dans le groupe.")
	end
	removeMember(party, userId)
	local kicked = playerById(userId)
	if kicked then
		Remote.notify(kicked, "Tu as été retiré du groupe.", "Danger")
	end
	return Remote.ok()
end

ACTIONS.Promote = function(player, userIdArg)
	local userId = Guard.integer(userIdArg, 1, 2 ^ 53)
	local party = Party.ofPlayer(player)
	if not party or party.LeaderId ~= player.UserId or not userId or not table.find(party.Members, userId) then
		return Remote.fail("Action impossible.")
	end
	party.LeaderId = userId
	local index = table.find(party.Members, userId) :: number
	table.remove(party.Members, index)
	table.insert(party.Members, 1, userId)
	broadcast(party)
	return Remote.ok()
end

ACTIONS.SetMode = function(player, modeArg, rankedArg)
	local mode = Guard.oneOf(modeArg, Config.ModeOrder)
	local ranked = Guard.boolean(rankedArg)
	if not mode or ranked == nil then
		return Remote.fail("Mode invalide.")
	end
	local party = Party.ofPlayer(player)
	if party then
		if party.LeaderId ~= player.UserId then
			return Remote.fail("Seul le chef choisit le mode.")
		end
		party.Mode = mode
		party.Ranked = ranked
		broadcast(party)
	end
	return Remote.ok()
end

ACTIONS.Get = function(player)
	local party = Party.ofPlayer(player)
	return Remote.ok({ Party = if party then snapshot(party) else nil })
end

local function onPlayerAdded(player: Player)
	local map = restoreMap
	if not map then
		return
	end
	-- Reformer le groupe après un retour de match.
	local ok, payload = pcall(function()
		return map:GetAsync(tostring(player.UserId))
	end)
	if not ok or typeof(payload) ~= "string" then
		return
	end
	pcall(function()
		map:RemoveAsync(tostring(player.UserId))
	end)
	local decoded, ids = pcall(HttpService.JSONDecode, HttpService, payload)
	if not decoded or type(ids) ~= "table" then
		return
	end
	for _, otherId in ids do
		if typeof(otherId) == "number" and otherId ~= player.UserId then
			local other = playerById(otherId)
			local otherParty = other and Party.ofPlayer(other)
			if other and otherParty and #otherParty.Members < Config.MaxPartySize then
				table.insert(otherParty.Members, player.UserId)
				partyOf[player.UserId] = otherParty.Id
				broadcast(otherParty)
				return
			elseif other and not otherParty then
				local party = createParty(other)
				table.insert(party.Members, player.UserId)
				partyOf[player.UserId] = party.Id
				broadcast(party)
				return
			end
		end
	end
end

function Party.init()
	-- Le serveur de match écrit dans cette table, le lobby la lit.
	local ok, map = pcall(function()
		return MemoryStoreService:GetHashMap("HL_PartyRestore")
	end)
	if ok then
		restoreMap = map
	end
	if ServerRole.Role ~= "Lobby" then
		return
	end
	Remote.onInvoke("PartyAction", 5, 10, function(player, action, a, b)
		local handler = if typeof(action) == "string" then ACTIONS[action] else nil
		if not handler then
			return Remote.fail("Action inconnue.")
		end
		return handler(player, a, b)
	end)
end

function Party.start()
	if ServerRole.Role ~= "Lobby" then
		return
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		local party = Party.ofPlayer(player)
		if party then
			removeMember(party, player.UserId)
		end
		invites[player.UserId] = nil
	end)
end

return Party
