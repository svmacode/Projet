--!strict
-- État côté client : profil, groupe, file d'attente, clan, match.
-- Le client ne fait qu'afficher : toutes les décisions sont prises par le
-- serveur, qui pousse ses mises à jour via les remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local State = {}

State.Profile = nil :: any
State.Party = nil :: any
State.Queue = { State = "Idle" } :: any
State.Clan = nil :: any
State.Match = nil :: any
State.Setup = nil :: any
State.Ball = nil :: any
State.Started = false -- le joueur a passé le menu de départ
State.ActiveScreen = nil :: string?

State.ProfileChanged = Signal.new() :: Signal.Signal<any>
State.PartyChanged = Signal.new() :: Signal.Signal<any>
State.QueueChanged = Signal.new() :: Signal.Signal<any>
State.ClanChanged = Signal.new() :: Signal.Signal<any>
State.MatchChanged = Signal.new() :: Signal.Signal<any>
State.SetupChanged = Signal.new() :: Signal.Signal<any>
State.BallChanged = Signal.new() :: Signal.Signal<any>
State.MatchEvent = Signal.new() :: Signal.Signal<string, any>
State.ScreenChanged = Signal.new() :: Signal.Signal<string?>
State.Notify = Signal.new() :: Signal.Signal<string, string>
State.PartyInvite = Signal.new() :: Signal.Signal<number, string, string>
State.ClanInvite = Signal.new() :: Signal.Signal<string, string, string>
State.Began = Signal.new() :: Signal.Signal<()>

-- Appel serveur : renvoie (ok, résultat). Affiche l'erreur en toast.
function State.request(remoteName: string, action: string, ...: any): (boolean, any)
	local ok, result = pcall(function(...)
		return Net.func(remoteName):InvokeServer(action, ...)
	end, ...)
	if not ok or type(result) ~= "table" then
		State.Notify:Fire("Connexion au serveur impossible.", "Danger")
		return false, nil
	end
	if not result.Ok then
		State.Notify:Fire(result.Error or "Action impossible.", "Danger")
		return false, result
	end
	return true, result
end

-- Serveur lobby (menus, groupes) ou serveur de match réservé ?
function State.isLobby(): boolean
	local role = ReplicatedStorage:GetAttribute("ServerRole")
	if role == nil then
		ReplicatedStorage:GetAttributeChangedSignal("ServerRole"):Wait()
		role = ReplicatedStorage:GetAttribute("ServerRole")
	end
	return role ~= "Match"
end

function State.inMatch(): boolean
	local match = State.Match
	return match ~= nil and match.Phase ~= "Ended"
end

function State.setScreen(name: string?)
	if State.ActiveScreen == name then
		return
	end
	State.ActiveScreen = name
	State.ScreenChanged:Fire(name)
end

function State.start()
	Net.event("ProfileUpdated").OnClientEvent:Connect(function(profile)
		State.Profile = profile
		State.ProfileChanged:Fire(profile)
	end)
	Net.event("PartyUpdated").OnClientEvent:Connect(function(party)
		State.Party = party
		State.PartyChanged:Fire(party)
	end)
	Net.event("QueueUpdated").OnClientEvent:Connect(function(status)
		State.Queue = status or { State = "Idle" }
		State.QueueChanged:Fire(State.Queue)
		if status and status.Message then
			State.Notify:Fire(status.Message, "Info")
		end
	end)
	Net.event("ClanUpdated").OnClientEvent:Connect(function(clan)
		State.Clan = clan
		State.ClanChanged:Fire(clan)
	end)
	Net.event("MatchSetup").OnClientEvent:Connect(function(setup)
		State.Setup = setup
		State.SetupChanged:Fire(setup)
	end)
	Net.event("MatchState").OnClientEvent:Connect(function(match)
		State.Match = match
		State.MatchChanged:Fire(match)
	end)
	Net.event("BallState").OnClientEvent:Connect(function(ball)
		State.Ball = ball
		State.BallChanged:Fire(ball)
	end)
	Net.event("MatchEvent").OnClientEvent:Connect(function(kind, data)
		if kind == "Leave" then
			State.Match = nil
			State.Setup = nil
			State.Ball = nil
			State.MatchChanged:Fire(nil)
		end
		State.MatchEvent:Fire(kind, data)
	end)
	Net.event("Notify").OnClientEvent:Connect(function(text, style)
		State.Notify:Fire(text, style or "Info")
	end)
	Net.event("PartyInvite").OnClientEvent:Connect(function(fromUserId, fromName, partyId)
		State.PartyInvite:Fire(fromUserId, fromName, partyId)
	end)
	Net.event("ClanInvite").OnClientEvent:Connect(function(clanId, clanName, fromName)
		State.ClanInvite:Fire(clanId, clanName, fromName)
	end)

	task.spawn(function()
		local ok, result = State.request("GetProfile", "Get")
		if ok and result.Profile then
			State.Profile = result.Profile
			State.ProfileChanged:Fire(result.Profile)
		end
		if not State.isLobby() then
			return
		end
		local okParty, party = State.request("PartyAction", "Get")
		if okParty and party then
			State.Party = party.Party
			State.PartyChanged:Fire(party.Party)
		end
	end)
end

return State
