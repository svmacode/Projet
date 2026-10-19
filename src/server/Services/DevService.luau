--!strict
-- DEVELOPMENT ENTRY POINT (Phase 1 only).
-- Until the lobby and matchmaking exist (Phase 4), the DevStartMatch remote
-- lets testers launch a match with everyone in the waiting room, optionally
-- completed with development bots. Remove or gate this service before release.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Guard = require(script.Parent.Parent.Lib.Guard)
local MatchService = require(script.Parent.MatchService)
local Remote = require(script.Parent.Parent.Lib.Remote)

local DevService = {}

local function startMatch(player: Player, mode: unknown, fillWithBots: unknown): (boolean, string?)
	local modeId = Guard.oneOf(mode, Config.ModeOrder)
	if not modeId then
		return false, "Mode inconnu."
	end
	local fill = Guard.boolean(fillWithBots) == true
	if MatchService.current() then
		return false, "Un match est déjà en cours : attends la fin."
	end
	local info = Config.Modes[modeId]
	local available = {}
	for _, other in Players:GetPlayers() do
		if not MatchService.isBusy(other) then
			table.insert(available, other)
		end
	end
	-- The requester always plays.
	local index = table.find(available, player)
	if index then
		table.remove(available, index)
	end
	table.insert(available, 1, player)
	local teams: { [string]: { Player } } = { Red = {}, Blue = {} }
	for i, member in available do
		if i > info.TeamSize * 2 then
			break
		end
		local team = if i % 2 == 1 then "Red" else "Blue"
		table.insert(teams[team], member)
	end
	if not fill and (#teams.Red == 0 or #teams.Blue == 0) then
		return false, "Il faut au moins un joueur dans chaque équipe, ou active les bots."
	end
	return MatchService.startMatch({
		Mode = modeId,
		Teams = teams,
		FillWithBots = fill,
		Origin = MatchService.CourtOrigin,
	})
end

function DevService.init()
	Remote.onInvoke("DevStartMatch", { Rate = 0.5, Burst = 2 }, startMatch)
end

return DevService
