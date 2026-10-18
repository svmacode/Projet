--!strict
-- Point d'entrée UNIQUE du client. Chaque contrôleur ne fait qu'afficher et
-- envoyer des demandes : le serveur garde l'autorité sur tout.

local StarterGui = game:GetService("StarterGui")

local Controllers = script.Controllers

-- Interface Roblox par défaut : on garde le chat et la liste des joueurs.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local ORDER = {
	"State",
	"Notifications",
	"BallRenderer",
	"MatchInput",
	"MatchHUD",
	"MatchFX",
	"MatchSetup",
	"LobbyMenu",
	"StartMenu",
}

local modules: { [string]: any } = {}
for _, name in ORDER do
	modules[name] = require(Controllers:WaitForChild(name)) :: any
end
for _, name in ORDER do
	local controller = modules[name]
	if typeof(controller.start) == "function" then
		local ok, err = pcall(controller.start)
		if not ok then
			warn(`[Handball Legends] {name} : {err}`)
		end
	end
end
