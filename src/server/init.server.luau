--!strict
-- Point d'entrée UNIQUE du serveur.
-- Démarrage en deux phases : init() de tous les systèmes (remotes,
-- dépendances), puis start() (boucles, connexions aux joueurs).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Crée les remotes avant tout le reste.
require(ReplicatedStorage.Shared.Net)

local ServerRole = require(script.Lib.ServerRole)

local ORDER = {
	"PlayerData",
	"Shop",
	"Locker",
	"Clan",
	"Party",
	"Matches",
	"Matchmaking",
	"Lobby",
}

local systems: { [string]: any } = {}
for _, name in ORDER do
	local module = script.Systems:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), `Système manquant : {name}`)
	systems[name] = require(module) :: any
end

for _, name in ORDER do
	local system = systems[name]
	if typeof(system.init) == "function" then
		system.init()
	end
end

for _, name in ORDER do
	local system = systems[name]
	if typeof(system.start) == "function" then
		task.spawn(system.start)
	end
end

print(
	`[Handball Legends] serveur démarré ({ServerRole.Role}{if ServerRole.LocalMatches then ", matchs locaux" else ""})`
)
