--!strict
-- Casier : équipement des cosmétiques, choix de la tenue, archétype favori
-- par poste, tutoriel, notes de mise à jour lues et réglages.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Guard = require(script.Parent.Parent.Lib.Guard)
local PlayerData = require(script.Parent.PlayerData)
local Remote = require(script.Parent.Parent.Lib.Remote)

local Locker = {}

local SETTINGS = { "CameraLock", "Music" }

local LOCKER: { [string]: (Player, any, any) -> Remote.Result } = {}

LOCKER.EquipCosmetic = function(player, slotArg, idArg)
	if not Cosmetics.isSlot(slotArg) then
		return Remote.fail("Emplacement invalide.")
	end
	local slot = slotArg :: string
	if idArg == nil then
		PlayerData.update(player, function(profile)
			profile.Equipped[slot] = nil
		end)
		return Remote.ok()
	end
	local item = Cosmetics.get(idArg)
	if not item or item.Slot ~= slot then
		return Remote.fail("Objet invalide.")
	end
	local done = false
	PlayerData.update(player, function(profile)
		if (profile.Cosmetics[item.Id] or 0) > 0 then
			profile.Equipped[slot] = item.Id
			done = true
		end
	end)
	return if done then Remote.ok() else Remote.fail("Tu ne possèdes pas cet objet.")
end

LOCKER.SetKit = function(player, kitArg)
	local kit = Progression.getKit(kitArg)
	if not kit then
		return Remote.fail("Tenue inconnue.")
	end
	local done = false
	PlayerData.update(player, function(profile)
		if profile.Level >= kit.Level then
			profile.Kit = kit.Id
			done = true
		end
	end)
	return if done then Remote.ok() else Remote.fail(`Tenue débloquée au niveau {kit.Level}.`)
end

LOCKER.SelectArchetype = function(player, posteArg, idArg)
	local archetype = Archetypes.get(idArg)
	if not Archetypes.isPoste(posteArg) or not archetype or archetype.Poste ~= posteArg then
		return Remote.fail("Archétype invalide.")
	end
	local done = false
	PlayerData.update(player, function(profile)
		if profile.Archetypes[archetype.Id] then
			profile.SelectedArchetype[archetype.Poste] = archetype.Id
			done = true
		end
	end)
	return if done then Remote.ok() else Remote.fail("Archétype non débloqué.")
end

local PROFILE: { [string]: (Player, any, any) -> Remote.Result } = {}

PROFILE.CompleteTutorial = function(player)
	PlayerData.update(player, function(profile)
		profile.TutorialDone = true
	end)
	return Remote.ok()
end

PROFILE.SeenPatch = function(player, versionArg)
	local version = Guard.string(versionArg, 16)
	if not version then
		return Remote.fail("Version invalide.")
	end
	PlayerData.update(player, function(profile)
		profile.SeenPatch = version
	end)
	return Remote.ok()
end

PROFILE.SetSetting = function(player, keyArg, valueArg)
	local key = Guard.oneOf(keyArg, SETTINGS)
	local value = Guard.boolean(valueArg)
	if not key or value == nil then
		return Remote.fail("Réglage invalide.")
	end
	PlayerData.update(player, function(profile)
		profile.Settings[key] = value
	end)
	return Remote.ok()
end

local function route(handlers: { [string]: (Player, any, any) -> Remote.Result })
	return function(player: Player, action: any, a: any, b: any): Remote.Result
		local handler = if typeof(action) == "string" then handlers[action] else nil
		if not handler then
			return Remote.fail("Action inconnue.")
		end
		if not PlayerData.get(player) then
			return Remote.fail("Profil en cours de chargement…")
		end
		return handler(player, a, b)
	end
end

function Locker.init()
	Remote.onInvoke("LockerAction", 6, 12, route(LOCKER))
	Remote.onInvoke("ProfileAction", 4, 8, route(PROFILE))
end

return Locker
