--!strict
-- PHASE 1 DEVELOPMENT ENTRY POINT. Clearly marked as a test tool: lets a
-- player in the club room start a test match (mode + optional bots) until the
-- real main menu, lobby and matchmaking arrive in Phase 4.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Kit = require(script.Parent.Parent.UI.Kit)
local MatchClient = require(script.Parent.MatchClient)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local F = Theme.Fonts
local T = Theme.Text

local DevPanel = {}

local panel: Frame
local status: TextLabel
local launch: Kit.Button
local modeButtons: { [string]: Kit.Button } = {}
local botsButton: Kit.Button
local controlsList: Frame

local selectedMode = "2v2"
local fillBots = true
local busy = false

local function refreshButtons()
	for id, button in modeButtons do
		button.SetSelected(id == selectedMode)
	end
	botsButton.SetText(if fillBots then "BOTS : OUI" else "BOTS : NON")
	botsButton.SetSelected(fillBots)
end

-- Fallback list, used when InputController does not expose bindings().
local DEFAULT_CONTROLS = {
	{ "Se déplacer / Sprint", "ZQSD-WASD / Maj", "Stick G / L3" },
	{ "Sauter / Dash", "Espace / C", "A / B" },
	{ "Tirer (maintenir = tir chargé)", "Clic gauche", "R2" },
	{ "Passe rapide / lobée / visée", "E / R / T", "X / Y / ▲ croix" },
	{ "Dribble (avec ballon) / Contre", "F", "R1" },
	{ "Interception (gardien : plongeon)", "Clic droit", "L2" },
	{ "Posture défensive", "Ctrl", "L1" },
	{ "Contact d'épaule", "V", "▶ croix" },
}

local function fillControls()
	Kit.clear(controlsList)
	local rows: { { string } } = {}
	local inputModule = script.Parent:FindFirstChild("InputController")
	if inputModule and inputModule:IsA("ModuleScript") then
		local ok, module = pcall(require, inputModule)
		if ok and typeof(module) == "table" and typeof((module :: any).bindings) == "function" then
			local okList, list = pcall((module :: any).bindings)
			if okList and typeof(list) == "table" then
				for _, entry in list do
					if typeof(entry) == "table" then
						local e = entry :: any
						local name = e.Label or e.Name or e[1]
						local keyboard = e.Keyboard or e.Keys or e[2]
						local gamepad = e.Gamepad or e[3]
						if name then
							table.insert(rows, { tostring(name), tostring(keyboard or ""), tostring(gamepad or "") })
						end
					end
				end
			end
		end
	end
	if #rows == 0 then
		rows = DEFAULT_CONTROLS
	end
	for index, row in rows do
		local line = Kit.box({ Size = UDim2.new(1, 0, 0, 20), Order = index, ZIndex = 3, Parent = controlsList })
		Kit.label({
			Text = row[1],
			TextSize = T.Small,
			Color = C.TextDim,
			Size = UDim2.new(0.5, 0, 1, 0),
			ZIndex = 3,
			Parent = line,
		})
		Kit.label({
			Text = `{row[2]}   {row[3]}`,
			Font = F.Bold,
			TextSize = T.Small,
			AlignX = Enum.TextXAlignment.Right,
			Size = UDim2.new(0.5, 0, 1, 0),
			Position = UDim2.fromScale(0.5, 0),
			ZIndex = 3,
			Parent = line,
		})
	end
end

local function startMatch()
	if busy then
		return
	end
	busy = true
	launch.SetEnabled(false)
	status.Text = "Lancement du match…"
	status.TextColor3 = C.TextDim
	local ok, accepted, message = pcall(function()
		return Remotes.func("DevStartMatch"):InvokeServer(selectedMode, fillBots)
	end)
	if not ok then
		status.Text = "Le serveur ne répond pas."
		status.TextColor3 = C.Danger
	elseif accepted == false then
		status.Text = if typeof(message) == "string" then message else "Lancement refusé."
		status.TextColor3 = C.Danger
	else
		status.Text = "Match en préparation."
		status.TextColor3 = C.Success
	end
	busy = false
	launch.SetEnabled(true)
end

function DevPanel.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local _, root = Kit.screen("HL_DevPanel", 5, playerGui)
	panel = Kit.panel({
		Name = "DevPanel",
		Color = C.Surface,
		Size = UDim2.fromOffset(440, 640),
		Position = UDim2.new(0, 32, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 2,
		Parent = root,
	})
	-- Hazard-stripe header: this is a test tool, not the final menu.
	local header =
		Kit.panel({ Color = C.Accent, Size = UDim2.new(1, 0, 0, 34), Radius = 0, ZIndex = 3, Parent = panel })
	Kit.label({
		Text = "MODE TEST — PHASE 1",
		Font = F.Display,
		TextSize = T.Body,
		Color = C.TextOnAccent,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = header,
	})
	Kit.label({
		Text = "HANDBALL LEGENDS",
		Font = F.Display,
		TextSize = T.Heading,
		Size = UDim2.new(1, -40, 0, 32),
		Position = UDim2.fromOffset(20, 48),
		ZIndex = 3,
		Parent = panel,
	})
	Kit.label({
		Text = "Outil de test : le vrai menu, le lobby et le matchmaking arrivent en phase 4.",
		TextSize = T.Small,
		Color = C.TextDim,
		Wrap = true,
		Size = UDim2.new(1, -40, 0, 36),
		Position = UDim2.fromOffset(20, 82),
		ZIndex = 3,
		Parent = panel,
	})

	local modeRow =
		Kit.box({ Size = UDim2.new(1, -40, 0, 46), Position = UDim2.fromOffset(20, 128), ZIndex = 3, Parent = panel })
	Kit.list(modeRow, 8, true)
	for index, id in Config.ModeOrder do
		modeButtons[id] = Kit.button({
			Text = Config.Modes[id].Label,
			Variant = "Secondary",
			TextSize = T.Body,
			Size = UDim2.new(0.25, -6, 1, 0),
			Order = index,
			ZIndex = 3,
			Parent = modeRow,
			OnClick = function()
				selectedMode = id
				refreshButtons()
			end,
		})
	end
	botsButton = Kit.button({
		Text = "",
		Variant = "Secondary",
		TextSize = T.Body,
		Size = UDim2.new(1, -40, 0, 44),
		Position = UDim2.fromOffset(20, 184),
		ZIndex = 3,
		Parent = panel,
		OnClick = function()
			fillBots = not fillBots
			refreshButtons()
		end,
	})
	launch = Kit.button({
		Text = "LANCER UN MATCH TEST",
		Variant = "Primary",
		Font = F.Display,
		TextSize = T.Large,
		Size = UDim2.new(1, -40, 0, 58),
		Position = UDim2.fromOffset(20, 240),
		ZIndex = 3,
		Parent = panel,
		OnClick = startMatch,
	})
	status = Kit.label({
		Text = "Tous les joueurs de la salle sont répartis dans les deux équipes.",
		TextSize = T.Small,
		Color = C.TextDim,
		Wrap = true,
		Size = UDim2.new(1, -40, 0, 36),
		Position = UDim2.fromOffset(20, 304),
		ZIndex = 3,
		Parent = panel,
	})
	Kit.label({
		Text = "COMMANDES",
		Font = F.Heavy,
		TextSize = T.Small,
		Color = C.Accent,
		Size = UDim2.new(1, -40, 0, 20),
		Position = UDim2.fromOffset(20, 350),
		ZIndex = 3,
		Parent = panel,
	})
	controlsList =
		Kit.box({ Size = UDim2.new(1, -40, 0, 250), Position = UDim2.fromOffset(20, 376), ZIndex = 3, Parent = panel })
	Kit.list(controlsList, 4)
	refreshButtons()
end

function DevPanel.start()
	fillControls()
	local function refresh(match: any)
		panel.Visible = match == nil
	end
	refresh(MatchClient.Match)
	MatchClient.MatchChanged:Connect(refresh)
end

return DevPanel
