--!strict
-- Owns the running match(es) and routes the gameplay remotes to them.
-- Phase 1 runs one match at a time; the API already takes a full config so
-- matchmaking (Phase 4) can call it unchanged.

local Players = game:GetService("Players")

local Guard = require(script.Parent.Parent.Lib.Guard)
local MapService = require(script.Parent.MapService)
local Match = require(script.Parent.Parent.Match.Match)
local MatchTypes = require(script.Parent.Parent.Match.MatchTypes)
local Remote = require(script.Parent.Parent.Lib.Remote)

local MatchService = {}

-- Where courts are built (the waiting room is elsewhere, see MapService).
MatchService.CourtOrigin = CFrame.new(0, 0, 0)

local current: any = nil
local busy: { [Player]: boolean } = {}

function MatchService.current(): any
	return current
end

function MatchService.isBusy(player: Player): boolean
	return busy[player] == true
end

-- Starts a match in its own thread. Returns false + reason if impossible.
function MatchService.startMatch(config: MatchTypes.MatchConfig): (boolean, string?)
	if current then
		return false, "Un match est déjà en cours sur ce serveur."
	end
	local match = Match.new(config, MapService)
	current = match
	for _, list in config.Teams do
		for _, player in list do
			busy[player] = true
		end
	end
	task.spawn(function()
		local ok, err = pcall(match.run, match)
		if not ok then
			warn(`[MatchService] match error: {err}`)
		end
		local cleaned, cleanupError = pcall(match.destroy, match, MapService.waitingSpawn())
		if not cleaned then
			warn(`[MatchService] cleanup error: {cleanupError}`)
		end
		for _, list in config.Teams do
			for _, player in list do
				busy[player] = nil
			end
		end
		if current == match then
			current = nil
		end
	end)
	return true, nil
end

function MatchService.init()
	local actionLimit = { Rate = 12, Burst = 20 }
	Remote.onEvent("Action", actionLimit, function(player: Player, name: unknown, payload: unknown)
		local match = current
		if match then
			match:onAction(player, name, payload)
		end
	end)
	Remote.onInvoke("SelectRole", { Rate = 4, Burst = 6 }, function(player: Player, role: unknown)
		local match = current
		if not match then
			return false, "Aucun match en cours."
		end
		local chosen = Guard.string(role, 16)
		return match:selectRole(player, chosen)
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return MatchService
