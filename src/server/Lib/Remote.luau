--!strict
-- Point d'entrée unique des remotes côté serveur : limitation de débit et
-- protection contre les erreurs pour chaque handler.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(script.Parent.RateLimit)

export type Result = { Ok: boolean, Error: string?, [string]: any }

local Remote = {}

function Remote.onEvent(name: string, ratePerSecond: number, burst: number, handler: (Player, ...any) -> ())
	Net.event(name).OnServerEvent:Connect(function(player, ...)
		if not RateLimit.allow(player, name, ratePerSecond, burst) then
			return
		end
		local result = table.pack(pcall(handler, player, ...))
		if not result[1] then
			warn(`[Remote] {name} ({player.Name}) : {result[2]}`)
		end
	end)
end

-- Handler de RemoteFunction : renvoie toujours une table { Ok, Error, ... }.
function Remote.onInvoke(name: string, ratePerSecond: number, burst: number, handler: (Player, ...any) -> Result)
	Net.func(name).OnServerInvoke = function(player, ...)
		if not RateLimit.allow(player, name, ratePerSecond, burst) then
			return { Ok = false, Error = "Doucement ! Réessaie dans un instant." }
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(`[Remote] {name} ({player.Name}) : {result}`)
			return { Ok = false, Error = "Une erreur est survenue." }
		end
		return result
	end
end

function Remote.fire(player: Player, name: string, ...: any)
	if player.Parent == Players then
		Net.event(name):FireClient(player, ...)
	end
end

function Remote.fireAll(name: string, ...: any)
	Net.event(name):FireAllClients(...)
end

function Remote.fireList(players: { Player }, name: string, ...: any)
	local remote = Net.event(name)
	for _, player in players do
		if player.Parent == Players then
			remote:FireClient(player, ...)
		end
	end
end

function Remote.notify(player: Player, text: string, style: string?)
	Remote.fire(player, "Notify", text, style or "Info")
end

function Remote.fail(message: string): Result
	return { Ok = false, Error = message }
end

function Remote.ok(extra: { [string]: any }?): Result
	local result: Result = { Ok = true }
	if extra then
		for key, value in extra do
			result[key] = value
		end
	end
	return result
end

return Remote
