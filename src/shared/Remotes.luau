--!strict
-- The single list of every remote. The server creates them at startup; the
-- client waits for the folder. Adding a remote = one line here.
--
-- Server code must go through Server/Lib/Remote.luau, which adds rate limiting
-- and error isolation. Payload shapes are documented in Types.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Events = {
	-- server → client
	"MatchState", -- (MatchSnapshot | nil)
	"MatchEvent", -- (kind: string, data: table)
	"BallState", -- (BallSnapshot | nil)
	"Notify", -- (text: string, style: string)
	-- client → server
	"Action", -- (name: string, payload: table?)
} :: { string }

-- RemoteFunctions: requests with a reply. The server never calls InvokeClient.
Remotes.Functions = {
	"SelectRole", -- (role) -> (ok, message?)
	"DevStartMatch", -- (mode, fillWithBots) -> (ok, message?)  DEVELOPMENT ONLY (Phase 1 entry point)
} :: { string }

local FOLDER = "Remotes"

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER
		folder.Parent = ReplicatedStorage
	end
	for _, name in Remotes.Events do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in Remotes.Functions do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER) :: Folder
end

function Remotes.event(name: string): RemoteEvent
	assert(table.find(Remotes.Events, name), `Unknown RemoteEvent: {name}`)
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	assert(table.find(Remotes.Functions, name), `Unknown RemoteFunction: {name}`)
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
