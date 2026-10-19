--!strict
-- Server-side wrapper around the shared remotes: rate limiting, error isolation
-- and a single place to fire events.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RateLimit = require(script.Parent.RateLimit)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Remote = {}

export type Limit = { Rate: number, Burst: number }

function Remote.onEvent(name: string, limit: Limit, handler: (Player, ...any) -> ())
	Remotes.event(name).OnServerEvent:Connect(function(player, ...)
		if not RateLimit.allow(player, name, limit.Rate, limit.Burst) then
			return
		end
		local result = table.pack(pcall(handler, player, ...))
		if not result[1] then
			warn(`[Remote:{name}] {result[2]}`)
		end
	end)
end

function Remote.onInvoke(name: string, limit: Limit, handler: (Player, ...any) -> ...any)
	Remotes.func(name).OnServerInvoke = function(player, ...)
		if not RateLimit.allow(player, name, limit.Rate, limit.Burst) then
			return false, "Trop de requêtes, patiente un instant."
		end
		local results = table.pack(pcall(handler, player, ...))
		if not results[1] then
			warn(`[Remote:{name}] {results[2]}`)
			return false, "Erreur du serveur."
		end
		return table.unpack(results, 2, results.n)
	end
end

function Remote.fire(player: Player, name: string, ...: any)
	if player.Parent == Players then
		Remotes.event(name):FireClient(player, ...)
	end
end

function Remote.fireList(players: { Player }, name: string, ...: any)
	local remote = Remotes.event(name)
	for _, player in players do
		if player.Parent == Players then
			remote:FireClient(player, ...)
		end
	end
end

function Remote.fireAll(name: string, ...: any)
	Remotes.event(name):FireAllClients(...)
end

function Remote.notify(player: Player, text: string, style: string?)
	Remote.fire(player, "Notify", text, style or "Info")
end

return Remote
