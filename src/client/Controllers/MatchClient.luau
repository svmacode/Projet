--!strict
-- Client-side mirror of the server's match. Receives MatchState, BallState and
-- MatchEvent, keeps the latest snapshots and exposes signals. Every other
-- controller reads match data from here (never from the remotes directly).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local MatchClient = {}

MatchClient.Match = nil :: Types.MatchSnapshot?
MatchClient.Ball = nil :: Types.BallSnapshot?

MatchClient.MatchChanged = Signal.new() :: Signal.Signal<Types.MatchSnapshot?>
MatchClient.BallChanged = Signal.new() :: Signal.Signal<Types.BallSnapshot?>
MatchClient.Event = Signal.new() :: Signal.Signal<string, any>
MatchClient.Notified = Signal.new() :: Signal.Signal<string, string>

local localPlayer = Players.LocalPlayer

function MatchClient.now(): number
	return Workspace:GetServerTimeNow()
end

-- Participant controlled by this client, if any.
function MatchClient.me(): Types.ParticipantSnapshot?
	local match = MatchClient.Match
	if not match then
		return nil
	end
	for _, participant in match.Participants do
		if participant.UserId == localPlayer.UserId then
			return participant
		end
	end
	return nil
end

function MatchClient.participant(id: string?): Types.ParticipantSnapshot?
	local match = MatchClient.Match
	if not match or not id then
		return nil
	end
	for _, participant in match.Participants do
		if participant.Id == id then
			return participant
		end
	end
	return nil
end

function MatchClient.participantOfModel(model: Instance?): Types.ParticipantSnapshot?
	local match = MatchClient.Match
	if not match or not model then
		return nil
	end
	for _, participant in match.Participants do
		if participant.Model == model then
			return participant
		end
	end
	return nil
end

-- True while the ball is held by the local player.
function MatchClient.iHoldBall(): boolean
	local me = MatchClient.me()
	local ball = MatchClient.Ball
	return me ~= nil and ball ~= nil and ball.State == "Held" and ball.HolderId == me.Id
end

-- True while the match is in a phase where gameplay input is accepted.
function MatchClient.isPlaying(): boolean
	local match = MatchClient.Match
	return match ~= nil and (match.Phase == "Playing" or match.Phase == "Overtime")
end

function MatchClient.init()
	Remotes.event("MatchState").OnClientEvent:Connect(function(snapshot)
		MatchClient.Match = snapshot
		MatchClient.MatchChanged:Fire(snapshot)
	end)
	Remotes.event("BallState").OnClientEvent:Connect(function(snapshot)
		MatchClient.Ball = snapshot
		MatchClient.BallChanged:Fire(snapshot)
	end)
	Remotes.event("MatchEvent").OnClientEvent:Connect(function(kind, data)
		if typeof(kind) == "string" then
			MatchClient.Event:Fire(kind, data or {})
		end
	end)
	Remotes.event("Notify").OnClientEvent:Connect(function(text, style)
		if typeof(text) == "string" then
			MatchClient.Notified:Fire(text, if typeof(style) == "string" then style else "Info")
		end
	end)
end

-- Sends a gameplay action to the server (see Types.luau and MatchService).
function MatchClient.send(name: string, payload: { [string]: any }?)
	Remotes.event("Action"):FireServer(name, payload or {})
end

return MatchClient
