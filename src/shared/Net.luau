--!strict
-- Liste unique de tous les remotes. Le serveur les crée au démarrage,
-- le client attend le dossier. Ajouter un remote = une ligne ici.
--
-- Côté serveur, toujours passer par Server/Lib/Remote.luau qui ajoute la
-- limitation de débit et la protection contre les erreurs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- RemoteEvent : messages sans réponse.
Net.Events = {
	-- serveur -> client
	"ProfileUpdated", -- (profile snapshot)
	"Notify", -- (text, style)
	"PartyUpdated", -- (party snapshot | nil)
	"PartyInvite", -- (fromUserId, fromName, partyId)
	"QueueUpdated", -- (queue status)
	"ClanUpdated", -- (clan snapshot | nil)
	"ClanInvite", -- (clanId, clanName, fromName)
	"MatchSetup", -- (setup snapshot : choix de poste)
	"MatchState", -- (état complet du match)
	"MatchEvent", -- (kind, data) : effets, annonces
	"BallState", -- (ball snapshot)
	"PackOpened", -- (result)
	"PadState", -- (pad snapshot | nil) : terrain du lobby sur lequel se trouve le joueur
	-- client -> serveur
	"MatchAction", -- (action, ...)
} :: { string }

-- RemoteFunction : requêtes avec réponse (jamais InvokeClient côté serveur).
Net.Functions = {
	"GetProfile",
	"ShopAction",
	"LockerAction",
	"PartyAction",
	"QueueAction",
	"ClanAction",
	"ProfileAction",
	"MatchSetupAction",
	"PadAction", -- ("Leave")
} :: { string }

local FOLDER_NAME = "Net"

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in Net.Events do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in Net.Functions do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Net.event(name: string): RemoteEvent
	assert(table.find(Net.Events, name), `RemoteEvent inconnu : {name}`)
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	assert(table.find(Net.Functions, name), `RemoteFunction inconnue : {name}`)
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
