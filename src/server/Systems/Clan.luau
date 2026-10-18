--!strict
-- Clans : création (1000 Robux), invitations, rôles (Chef, Officier, Membre),
-- emblème, bannière et couleur d'accent de tenue, victoires cumulées.
--
-- Stockage : un DataStore par clan (clé = identifiant) et un DataStore qui
-- réserve les noms (clé = nom en minuscules). Les modifications passent par
-- UpdateAsync ; les autres serveurs sont prévenus par MessagingService.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local ClanStyle = require(ReplicatedStorage.Shared.Data.ClanStyle)
local Config = require(ReplicatedStorage.Shared.Config)
local Guard = require(script.Parent.Parent.Lib.Guard)
local PlayerData = require(script.Parent.PlayerData)
local Remote = require(script.Parent.Parent.Lib.Remote)
local ServerRole = require(script.Parent.Parent.Lib.ServerRole)
local Shop = require(script.Parent.Shop)

type Member = { Role: string, Name: string, Joined: number }

type ClanRecord = {
	Id: string,
	Name: string,
	Tag: string,
	OwnerId: number,
	Members: { [string]: Member },
	Emblem: string,
	EmblemColor: number,
	BannerPattern: string,
	BannerColor: number,
	KitAccent: number,
	Wins: number,
	Created: number,
}

local CHANGED_TOPIC = "HL_ClanChanged"
local CACHE_TTL = 60
local INVITE_TTL = 120

local Clan = {}

local clanStore: DataStore? = nil
local nameStore: DataStore? = nil
local cache: { [string]: { Record: ClanRecord?, At: number } } = {}
local invites: { [number]: { [string]: number } } = {}
local pendingCreation: { [Player]: { Name: string, Tag: string } } = {}

-- Accès aux données ------------------------------------------------------------------

local function fetch(clanId: string, force: boolean?): ClanRecord?
	local cached = cache[clanId]
	if cached and not force and os.clock() - cached.At < CACHE_TTL then
		return cached.Record
	end
	local store = clanStore
	if not store then
		return if cached then cached.Record else nil
	end
	local ok, record = pcall(function()
		return store:GetAsync(clanId)
	end)
	if not ok then
		return if cached then cached.Record else nil
	end
	local value = if type(record) == "table" then record :: ClanRecord else nil
	cache[clanId] = { Record = value, At = os.clock() }
	return value
end

local function mutate(clanId: string, transform: (ClanRecord) -> boolean): (boolean, ClanRecord?)
	local store = clanStore
	if not store then
		return false, nil
	end
	local changed = false
	local ok, result = pcall(function()
		return store:UpdateAsync(clanId, function(old: any)
			changed = false
			if type(old) ~= "table" then
				return nil
			end
			if transform(old) then
				changed = true
				return old
			end
			return nil
		end)
	end)
	if not ok then
		warn(`[Clan] mise à jour {clanId} : {result}`)
		return false, nil
	end
	if changed and type(result) == "table" then
		cache[clanId] = { Record = result, At = os.clock() }
		return true, result
	end
	return false, fetch(clanId)
end

local function snapshot(record: ClanRecord): any
	local members = {}
	for userId, member in record.Members do
		table.insert(members, { UserId = tonumber(userId), Name = member.Name, Role = member.Role })
	end
	table.sort(members, function(a, b)
		local order = { Chef = 1, Officier = 2, Membre = 3 }
		if order[a.Role] ~= order[b.Role] then
			return (order[a.Role] or 4) < (order[b.Role] or 4)
		end
		return a.Name < b.Name
	end)
	return {
		Id = record.Id,
		Name = record.Name,
		Tag = record.Tag,
		OwnerId = record.OwnerId,
		Members = members,
		MaxMembers = Config.Clan.MaxMembers,
		Emblem = record.Emblem,
		EmblemColor = record.EmblemColor,
		BannerPattern = record.BannerPattern,
		BannerColor = record.BannerColor,
		KitAccent = record.KitAccent,
		Wins = record.Wins,
		Created = record.Created,
	}
end

local function countMembers(record: ClanRecord): number
	local count = 0
	for _ in record.Members do
		count += 1
	end
	return count
end

local function pushToOnlineMembers(record: ClanRecord?, clanId: string)
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.get(player)
		if profile and profile.ClanId == clanId then
			if record and record.Members[tostring(player.UserId)] then
				Remote.fire(player, "ClanUpdated", snapshot(record))
			else
				-- Exclu ou clan dissous.
				PlayerData.update(player, function(p)
					p.ClanId = nil
				end)
				Remote.fire(player, "ClanUpdated", nil)
			end
		end
	end
end

local function announce(clanId: string, record: ClanRecord?)
	pushToOnlineMembers(record, clanId)
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(CHANGED_TOPIC, clanId)
		end)
	end)
end

local function roleOf(record: ClanRecord, player: Player): string?
	local member = record.Members[tostring(player.UserId)]
	return if member then member.Role else nil
end

-- API utilisée par les autres systèmes ------------------------------------------------------

function Clan.tagOf(player: Player): string?
	local profile = PlayerData.get(player)
	local clanId = profile and profile.ClanId
	if not clanId then
		return nil
	end
	local record = fetch(clanId)
	return if record then record.Tag else nil
end

function Clan.recordWin(player: Player)
	local profile = PlayerData.get(player)
	local clanId = profile and profile.ClanId
	if not clanId then
		return
	end
	task.spawn(mutate, clanId, function(record: ClanRecord)
		record.Wins += 1
		return true
	end)
end

-- Validation du texte -------------------------------------------------------------------------

local function filterText(text: string, player: Player): string?
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or result ~= text then
		return nil
	end
	return result
end

local function validName(name: string): boolean
	local length = utf8.len(name) or 0
	if length < Config.Clan.NameMinLength or length > Config.Clan.NameMaxLength then
		return false
	end
	return name:match("^[%w%s%-_]+$") ~= nil and name:match("^%s") == nil and name:match("%s$") == nil
end

local function validTag(tag: string): boolean
	local length = #tag
	return length >= Config.Clan.TagMinLength and length <= Config.Clan.TagMaxLength and tag:match("^[%u%d]+$") ~= nil
end

-- Création ------------------------------------------------------------------------------------------

local function createClan(player: Player, name: string, tag: string): (boolean, string?)
	local store, names = clanStore, nameStore
	if not store or not names then
		return false, "Les clans sont indisponibles pour le moment."
	end
	local profile = PlayerData.get(player)
	if not profile or profile.ClanId then
		return false, "Tu es déjà dans un clan."
	end
	local clanId = HttpService:GenerateGUID(false)
	-- Réserver le nom (unique).
	local claimed = false
	local ok = pcall(function()
		names:UpdateAsync(string.lower(name), function(old: any)
			if old ~= nil then
				claimed = false
				return nil
			end
			claimed = true
			return clanId
		end)
	end)
	if not ok then
		return false, "Erreur réseau, réessaie."
	end
	if not claimed then
		return false, "Ce nom de clan est déjà pris."
	end
	local record: ClanRecord = {
		Id = clanId,
		Name = name,
		Tag = tag,
		OwnerId = player.UserId,
		Members = { [tostring(player.UserId)] = { Role = "Chef", Name = player.DisplayName, Joined = os.time() } },
		Emblem = ClanStyle.Emblems[1].Id,
		EmblemColor = 1,
		BannerPattern = ClanStyle.Patterns[1].Id,
		BannerColor = 10,
		KitAccent = 3,
		Wins = 0,
		Created = os.time(),
	}
	local saved = pcall(function()
		store:SetAsync(clanId, record)
	end)
	if not saved then
		pcall(function()
			names:RemoveAsync(string.lower(name))
		end)
		return false, "Erreur réseau, réessaie."
	end
	cache[clanId] = { Record = record, At = os.clock() }
	PlayerData.update(player, function(p)
		p.ClanId = clanId
		if p.ClanCredits > 0 then
			p.ClanCredits -= 1
		end
	end)
	Remote.fire(player, "ClanUpdated", snapshot(record))
	Remote.notify(player, `Le clan [{tag}] {name} est né !`, "Gold")
	return true, nil
end

local function tryPendingCreation(player: Player)
	local pending = pendingCreation[player]
	local profile = PlayerData.get(player)
	if not pending or not profile or profile.ClanCredits < 1 then
		return
	end
	pendingCreation[player] = nil
	local ok, err = createClan(player, pending.Name, pending.Tag)
	if not ok then
		Remote.notify(player, `{err} Ton crédit de création est conservé.`, "Danger")
	end
end

-- Actions ---------------------------------------------------------------------------------------------

local ACTIONS: { [string]: (Player, any, any) -> Remote.Result } = {}

ACTIONS.Get = function(player)
	local profile = PlayerData.get(player)
	local record = if profile and profile.ClanId then fetch(profile.ClanId, true) else nil
	if profile and profile.ClanId and record and not record.Members[tostring(player.UserId)] then
		PlayerData.update(player, function(p)
			p.ClanId = nil
		end)
		record = nil
	end
	return Remote.ok({
		Clan = if record then snapshot(record) else nil,
		Credits = if profile then profile.ClanCredits else 0,
		ProductEnabled = Shop.isProductEnabled("ClanCreation") or ServerRole.IsStudio,
		Price = Config.ProductRobuxPrice.ClanCreation,
	})
end

ACTIONS.Create = function(player, nameArg, tagArg)
	local name = Guard.string(nameArg, 40)
	local tag = Guard.string(tagArg, 8)
	if not name or not tag then
		return Remote.fail("Nom ou tag invalide.")
	end
	tag = string.upper(tag)
	if not validName(name) then
		return Remote.fail(
			`Le nom doit faire {Config.Clan.NameMinLength} à {Config.Clan.NameMaxLength} caractères (lettres, chiffres, espaces).`
		)
	end
	if not validTag(tag) then
		return Remote.fail(
			`Le tag doit faire {Config.Clan.TagMinLength} à {Config.Clan.TagMaxLength} lettres majuscules ou chiffres.`
		)
	end
	local profile = PlayerData.get(player)
	if not profile then
		return Remote.fail("Profil indisponible.")
	end
	if profile.ClanId then
		return Remote.fail("Tu es déjà dans un clan.")
	end
	if not filterText(name, player) or not filterText(tag, player) then
		return Remote.fail("Ce nom n'est pas autorisé.")
	end
	if profile.ClanCredits > 0 then
		local ok, err = createClan(player, name, tag)
		return if ok then Remote.ok() else Remote.fail(err or "Impossible.")
	end
	if Shop.isProductEnabled("ClanCreation") then
		pendingCreation[player] = { Name = name, Tag = tag }
		Shop.promptProduct(player, "ClanCreation")
		return Remote.ok({ Pending = true })
	end
	if ServerRole.IsStudio then
		-- En Studio, sans produit configuré : création gratuite pour tester.
		local ok, err = createClan(player, name, tag)
		return if ok then Remote.ok() else Remote.fail(err or "Impossible.")
	end
	return Remote.fail("La création de clan arrive bientôt !")
end

ACTIONS.Invite = function(player, userIdArg)
	local userId = Guard.integer(userIdArg, 1, 2 ^ 53)
	local target = userId and Players:GetPlayerByUserId(userId)
	local profile = PlayerData.get(player)
	if not target or not profile or not profile.ClanId then
		return Remote.fail("Joueur introuvable.")
	end
	local record = fetch(profile.ClanId, true)
	if not record then
		return Remote.fail("Clan introuvable.")
	end
	local role = roleOf(record, player)
	if role ~= "Chef" and role ~= "Officier" then
		return Remote.fail("Seuls le chef et les officiers peuvent inviter.")
	end
	if countMembers(record) >= Config.Clan.MaxMembers then
		return Remote.fail("Le clan est complet.")
	end
	local targetProfile = PlayerData.get(target)
	if not targetProfile or targetProfile.ClanId then
		return Remote.fail("Ce joueur est déjà dans un clan.")
	end
	invites[target.UserId] = invites[target.UserId] or {}
	invites[target.UserId][record.Id] = os.time() + INVITE_TTL
	Remote.fire(target, "ClanInvite", record.Id, `[{record.Tag}] {record.Name}`, player.DisplayName)
	return Remote.ok()
end

ACTIONS.Accept = function(player, clanIdArg)
	local clanId = Guard.string(clanIdArg, 64)
	local pending = invites[player.UserId]
	if not clanId or not pending or not pending[clanId] or pending[clanId] < os.time() then
		return Remote.fail("Invitation expirée.")
	end
	local profile = PlayerData.get(player)
	if not profile or profile.ClanId then
		return Remote.fail("Tu es déjà dans un clan.")
	end
	pending[clanId] = nil
	local joined, record = mutate(clanId, function(r)
		if countMembers(r) >= Config.Clan.MaxMembers then
			return false
		end
		r.Members[tostring(player.UserId)] = { Role = "Membre", Name = player.DisplayName, Joined = os.time() }
		return true
	end)
	if not joined or not record then
		return Remote.fail("Impossible de rejoindre ce clan.")
	end
	PlayerData.update(player, function(p)
		p.ClanId = clanId
	end)
	announce(clanId, record)
	return Remote.ok()
end

ACTIONS.Decline = function(player, clanIdArg)
	local clanId = Guard.string(clanIdArg, 64)
	local pending = invites[player.UserId]
	if clanId and pending then
		pending[clanId] = nil
	end
	return Remote.ok()
end

ACTIONS.Leave = function(player)
	local profile = PlayerData.get(player)
	local clanId = profile and profile.ClanId
	if not clanId then
		return Remote.fail("Tu n'es dans aucun clan.")
	end
	local key = tostring(player.UserId)
	local _, record = mutate(clanId, function(r)
		if not r.Members[key] then
			return false
		end
		r.Members[key] = nil
		if r.OwnerId == player.UserId then
			-- Le plus ancien officier (sinon membre) devient chef.
			local heir: string? = nil
			local heirScore = math.huge
			for userId, member in r.Members do
				local score = member.Joined - (if member.Role == "Officier" then 1e10 else 0)
				if score < heirScore then
					heir = userId
					heirScore = score
				end
			end
			if heir then
				r.Members[heir].Role = "Chef"
				r.OwnerId = tonumber(heir) or 0
			end
		end
		return true
	end)
	PlayerData.update(player, function(p)
		p.ClanId = nil
	end)
	Remote.fire(player, "ClanUpdated", nil)
	if record and countMembers(record) == 0 then
		-- Dernier membre parti : le clan est dissous et le nom libéré.
		local store, names = clanStore, nameStore
		if store and names then
			pcall(function()
				store:RemoveAsync(clanId)
				names:RemoveAsync(string.lower(record.Name))
			end)
		end
		cache[clanId] = nil
	else
		announce(clanId, record)
	end
	return Remote.ok()
end

ACTIONS.Kick = function(player, userIdArg)
	local userId = Guard.integer(userIdArg, 1, 2 ^ 53)
	local profile = PlayerData.get(player)
	local clanId = profile and profile.ClanId
	if not userId or not clanId or userId == player.UserId then
		return Remote.fail("Action impossible.")
	end
	local kicked, record = mutate(clanId, function(r)
		local myRole = roleOf(r, player)
		local target = r.Members[tostring(userId)]
		if not target then
			return false
		end
		local allowed = myRole == "Chef" or (myRole == "Officier" and target.Role == "Membre")
		if not allowed then
			return false
		end
		r.Members[tostring(userId)] = nil
		return true
	end)
	if not kicked then
		return Remote.fail("Tu n'as pas les droits pour exclure ce membre.")
	end
	announce(clanId, record)
	return Remote.ok()
end

ACTIONS.SetRole = function(player, userIdArg, roleArg)
	local userId = Guard.integer(userIdArg, 1, 2 ^ 53)
	local role = Guard.oneOf(roleArg, { "Officier", "Membre", "Chef" })
	local profile = PlayerData.get(player)
	local clanId = profile and profile.ClanId
	if not userId or not role or not clanId or userId == player.UserId then
		return Remote.fail("Action impossible.")
	end
	local changed, record = mutate(clanId, function(r)
		if roleOf(r, player) ~= "Chef" then
			return false
		end
		local target = r.Members[tostring(userId)]
		if not target then
			return false
		end
		if role == "Chef" then
			-- Transmission du rôle de chef.
			r.Members[tostring(player.UserId)].Role = "Officier"
			r.OwnerId = userId
		end
		target.Role = role
		return true
	end)
	if not changed then
		return Remote.fail("Seul le chef peut changer les rôles.")
	end
	announce(clanId, record)
	return Remote.ok()
end

ACTIONS.Customize = function(player, fieldArg, valueArg)
	local field = Guard.oneOf(fieldArg, { "Emblem", "EmblemColor", "BannerPattern", "BannerColor", "KitAccent" })
	local profile = PlayerData.get(player)
	local clanId = profile and profile.ClanId
	if not field or not clanId then
		return Remote.fail("Action impossible.")
	end
	local value: any = nil
	if field == "Emblem" then
		for _, emblem in ClanStyle.Emblems do
			if emblem.Id == valueArg then
				value = emblem.Id
			end
		end
	elseif field == "BannerPattern" then
		for _, pattern in ClanStyle.Patterns do
			if pattern.Id == valueArg then
				value = pattern.Id
			end
		end
	else
		value = Guard.integer(valueArg, 1, #ClanStyle.Palette)
	end
	if value == nil then
		return Remote.fail("Valeur invalide.")
	end
	local changed, record = mutate(clanId, function(r)
		local role = roleOf(r, player)
		if role ~= "Chef" and role ~= "Officier" then
			return false
		end
		(r :: any)[field] = value
		return true
	end)
	if not changed then
		return Remote.fail("Seuls le chef et les officiers peuvent personnaliser le clan.")
	end
	announce(clanId, record)
	return Remote.ok()
end

function Clan.init()
	local ok1, store = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.ClanStore)
	end)
	local ok2, names = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.ClanNameStore)
	end)
	if ok1 then
		clanStore = store
	end
	if ok2 then
		nameStore = names
	end
	Shop.registerProduct("ClanCreation", {
		Grant = function(profile)
			profile.ClanCredits += 1
		end,
		After = function(player)
			Remote.notify(player, "Achat confirmé : création de clan débloquée !", "Gold")
			tryPendingCreation(player)
		end,
	})
	Remote.onInvoke("ClanAction", 4, 8, function(player, action, a, b)
		local handler = if typeof(action) == "string" then ACTIONS[action] else nil
		if not handler then
			return Remote.fail("Action inconnue.")
		end
		if not PlayerData.get(player) then
			return Remote.fail("Profil en cours de chargement…")
		end
		return handler(player, a, b)
	end)
end

function Clan.start()
	Players.PlayerRemoving:Connect(function(player)
		pendingCreation[player] = nil
		invites[player.UserId] = nil
	end)
	-- Vérifie l'appartenance au clan à la connexion (exclusion hors ligne…).
	PlayerData.Loaded:Connect(function(player, profile)
		local clanId = profile.ClanId
		if not clanId then
			return
		end
		local record = fetch(clanId, true)
		if record and record.Members[tostring(player.UserId)] then
			Remote.fire(player, "ClanUpdated", snapshot(record))
		elseif record == nil and clanStore then
			PlayerData.update(player, function(p)
				p.ClanId = nil
			end)
		end
	end)
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(CHANGED_TOPIC, function(message)
				local clanId = message.Data
				if typeof(clanId) == "string" then
					local record = fetch(clanId, true)
					pushToOnlineMembers(record, clanId)
				end
			end)
		end)
	end)
end

return Clan
