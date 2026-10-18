--!strict
-- Point d'entrée UNIQUE du client. Les contrôleurs affichent et envoient des
-- demandes ; le serveur garde l'autorité sur tout.

local StarterGui = game:GetService("StarterGui")

local Controllers = script.Controllers

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local ORDER = {
	"State",
	"Notifications",
	"BallRenderer",
	"MatchInput",
	"CharacterAnimator",
	"Effects3D",
	"Toon",
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
		local result = table.pack(pcall(controller.start))
		if not result[1] then
			warn(`[Handball Legends] {name} : {result[2]}`)
		end
	end
end
