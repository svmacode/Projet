--!strict
-- In-match interface (prompt §33: position selection, HUD, scoreboard, meters,
-- results). Every value shown comes from MatchClient snapshots and events, or
-- from the local control modules (ActionController, MovementController).
-- Rule feedback is explicit: every whistle explains WHY it was blown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Kit = require(script.Parent.Parent.UI.Kit)
local MatchClient = require(script.Parent.MatchClient)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local F = Theme.Fonts
local T = Theme.Text

local HUDController = {}

local localPlayer = Players.LocalPlayer

-- Control modules written by another part of the team: required lazily and
-- defensively so the HUD keeps working if one is missing.
local actionController: any = nil
local movementController: any = nil

local function optionalModule(name: string): any
	local moduleScript = script.Parent:FindFirstChild(name)
	if moduleScript and moduleScript:IsA("ModuleScript") then
		local ok, result = pcall(require, moduleScript)
		if ok then
			return result
		end
		warn(`[HUD] cannot load {name}: {result}`)
	end
	return nil
end

local function call(module: any, name: string, ...: any): any
	if module and typeof(module[name]) == "function" then
		local ok, result = pcall(module[name], ...)
		if ok then
			return result
		end
	end
	return nil
end

local function now(): number
	return MatchClient.now()
end

local function formatClock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function clockValue(match: Types.MatchSnapshot): number
	if match.ClockRunning then
		return match.Clock - (now() - match.ServerTime)
	end
	return match.Clock
end

local function periodName(match: Types.MatchSnapshot): string
	if match.Phase == "Overtime" or match.Half >= 3 then
		return "PROLONGATION"
	end
	return if match.Half == 2 then "2e MI-TEMPS" else "1re MI-TEMPS"
end

local function teamLabel(teamId: string?): string
	local team = Theme.team(teamId)
	return `{team.Symbol} {team.Name}`
end

-- Layout ----------------------------------------------------------------------------------------------

local root: Frame

-- Scoreboard
local scoreFrame: Frame
local redScore: TextLabel
local blueScore: TextLabel
local clockLabel: TextLabel
local periodLabel: TextLabel
local redPossession: Frame
local bluePossession: Frame
local passiveIcon: Frame

-- Centre
local crosshair: Frame
local passTargetLabel: TextLabel
local chargeBack: Frame
local setCharge: (number, Color3?) -> ()

-- Carrier widget
local carrier: Frame
local holdLabel: TextLabel
local setHold: (number, Color3?) -> ()
local stepPips: { Frame } = {}
local dribbleLabel: TextLabel

-- Dash chip
local dashChip: Frame
local setDash: (number, Color3?) -> ()
local dashLabel: TextLabel

-- Messages
local banner: Frame
local bannerTitle: TextLabel
local bannerText: TextLabel
local bannerAward: TextLabel
local bannerToken = 0
local restartInfo: TextLabel
local toastList: Frame

-- Overlays
local goalOverlay: Frame
local goalLabel: TextLabel
local phaseOverlay: Frame
local phaseTitle: TextLabel
local phaseSub: TextLabel
local selection: Frame
local selectionTimer: TextLabel
local selectionTeam: Frame
local selectionWarning: TextLabel
local selectionStatus: TextLabel
local roleButtons: { [string]: Kit.Button } = {}
local results: Frame

-- Nameplates
local plates: { [Model]: BillboardGui } = {}

local function buildScoreboard()
	scoreFrame = Kit.box({
		Name = "Scoreboard",
		Size = UDim2.fromOffset(560, 74),
		Position = UDim2.new(0.5, 0, 0, 16),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 5,
		Parent = root,
	})
	local function teamBlock(teamId: string, left: boolean): (TextLabel, Frame)
		local team = Theme.team(teamId)
		local block = Kit.panel({
			Color = team.Main,
			Size = UDim2.fromOffset(200, 64),
			Position = if left then UDim2.fromOffset(0, 0) else UDim2.new(1, -200, 0, 0),
			Radius = 4,
			ZIndex = 5,
			Parent = scoreFrame,
		})
		Kit.label({
			Text = if left then `{team.Symbol} {team.Name}` else `{team.Name} {team.Symbol}`,
			Font = F.Heavy,
			TextSize = T.Large,
			AlignX = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -90, 1, 0),
			Position = if left then UDim2.fromOffset(14, 0) else UDim2.fromOffset(76, 0),
			ZIndex = 6,
			Parent = block,
		})
		local score = Kit.label({
			Text = "0",
			Font = F.Display,
			TextSize = 46,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(72, 64),
			Position = if left then UDim2.new(1, -72, 0, 0) else UDim2.fromOffset(0, 0),
			ZIndex = 7,
			Parent = block,
		})
		-- Darker score cell for contrast.
		local cell = Kit.panel({
			Color = team.Dark,
			Size = UDim2.fromOffset(72, 64),
			Position = if left then UDim2.new(1, -72, 0, 0) else UDim2.fromOffset(0, 0),
			Radius = 4,
			ZIndex = 6,
			Parent = block,
		})
		cell.Name = "ScoreCell"
		local possession = Kit.panel({
			Color = C.Accent,
			Size = UDim2.new(1, 0, 0, 5),
			Position = UDim2.new(0, 0, 1, 4),
			Radius = 2,
			Visible = false,
			ZIndex = 6,
			Parent = block,
		})
		return score, possession
	end
	redScore, redPossession = teamBlock("Red", true)
	blueScore, bluePossession = teamBlock("Blue", false)
	local middle = Kit.panel({
		Color = C.Ink,
		Size = UDim2.fromOffset(150, 64),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Radius = 4,
		ZIndex = 5,
		Parent = scoreFrame,
	})
	clockLabel = Kit.label({
		Text = "0:00",
		Font = F.Mono,
		TextSize = 32,
		Color = C.Accent,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 4),
		ZIndex = 6,
		Parent = middle,
	})
	periodLabel = Kit.label({
		Text = "",
		Font = F.Bold,
		TextSize = T.Tiny,
		Color = C.TextDim,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 44),
		ZIndex = 6,
		Parent = middle,
	})
	-- Passive play: the referee's raised arm, drawn as an arm + hand shape.
	passiveIcon = Kit.panel({
		Color = C.Warning,
		Size = UDim2.fromOffset(150, 26),
		Position = UDim2.new(0.5, 0, 1, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		Radius = 4,
		Visible = false,
		ZIndex = 6,
		Parent = scoreFrame,
	})
	Kit.label({
		Text = "✋ JEU PASSIF",
		Font = F.Heavy,
		TextSize = T.Small,
		Color = C.TextOnAccent,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
		Parent = passiveIcon,
	})
end

local function buildCentre()
	crosshair = Kit.box({
		Name = "Crosshair",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 4,
		Parent = root,
	})
	for _, spec in
		{
			{ UDim2.fromOffset(2, 9), UDim2.new(0.5, -1, 0, 0) },
			{ UDim2.fromOffset(2, 9), UDim2.new(0.5, -1, 1, -9) },
			{ UDim2.fromOffset(9, 2), UDim2.new(0, 0, 0.5, -1) },
			{ UDim2.fromOffset(9, 2), UDim2.new(1, -9, 0.5, -1) },
		}
	do
		local tick = Kit.panel({
			Color = C.White,
			Size = spec[1],
			Position = spec[2],
			Radius = 0,
			ZIndex = 4,
			Parent = crosshair,
		})
		Kit.stroke(tick, C.Ink, 1)
	end
	passTargetLabel = Kit.label({
		Text = "",
		Font = F.Heavy,
		TextSize = T.Small,
		Color = C.Accent,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(300, 20),
		Position = UDim2.new(0.5, 0, 0.5, 30),
		AnchorPoint = Vector2.new(0.5, 0),
		Outline = 1.5,
		ZIndex = 4,
		Parent = root,
	})
	chargeBack, setCharge = Kit.bar({
		Name = "Charge",
		Size = UDim2.fromOffset(140, 8),
		Position = UDim2.new(0.5, 0, 0.5, 56),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = C.Accent,
		ZIndex = 4,
		Parent = root,
	})
	chargeBack.Visible = false
end

local function buildCarrier()
	carrier = Kit.panel({
		Name = "Carrier",
		Color = C.Surface,
		Size = UDim2.fromOffset(300, 74),
		Position = UDim2.new(0.5, 0, 1, -150),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	Kit.slash(carrier, C.Accent, UDim2.fromOffset(6, 82), UDim2.fromOffset(-2, -4), 6)
	holdLabel = Kit.label({
		Text = "BALLON EN MAIN",
		Font = F.Heavy,
		TextSize = T.Small,
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(16, 8),
		ZIndex = 6,
		Parent = carrier,
	})
	local _, setter = Kit.bar({
		Size = UDim2.new(1, -32, 0, 8),
		Position = UDim2.fromOffset(16, 30),
		Color = C.White,
		ZIndex = 6,
		Parent = carrier,
	})
	setHold = setter
	local pipRow =
		Kit.box({ Size = UDim2.fromOffset(120, 18), Position = UDim2.fromOffset(16, 46), ZIndex = 6, Parent = carrier })
	Kit.list(pipRow, 6, true)
	for i = 1, Config.Rules.MaxSteps do
		local pip = Kit.panel({
			Color = C.Raised,
			Size = UDim2.fromOffset(30, 14),
			Radius = 3,
			Order = i,
			ZIndex = 6,
			Parent = pipRow,
		})
		table.insert(stepPips, pip)
	end
	Kit.label({
		Text = "PAS",
		Font = F.Bold,
		TextSize = T.Tiny,
		Color = C.TextDim,
		Size = UDim2.fromOffset(40, 18),
		Position = UDim2.fromOffset(130, 46),
		ZIndex = 6,
		Parent = carrier,
	})
	dribbleLabel = Kit.label({
		Text = "",
		Font = F.Heavy,
		TextSize = T.Tiny,
		Color = C.Info,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(140, 18),
		Position = UDim2.new(1, -156, 0, 46),
		ZIndex = 6,
		Parent = carrier,
	})
end

local function buildDash()
	dashChip = Kit.panel({
		Name = "Dash",
		Color = C.Surface,
		Size = UDim2.fromOffset(120, 44),
		Position = UDim2.new(1, -24, 1, -24),
		AnchorPoint = Vector2.new(1, 1),
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	dashLabel = Kit.label({
		Text = "DASH",
		Font = F.Heavy,
		TextSize = T.Small,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 4),
		ZIndex = 6,
		Parent = dashChip,
	})
	local _, setter = Kit.bar({
		Size = UDim2.new(1, -20, 0, 6),
		Position = UDim2.fromOffset(10, 30),
		Color = C.Accent,
		ZIndex = 6,
		Parent = dashChip,
	})
	setDash = setter
end

local function buildMessages()
	banner = Kit.panel({
		Name = "Whistle",
		Color = C.Ink,
		Size = UDim2.fromOffset(620, 104),
		Position = UDim2.new(0.5, 0, 0, 132),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		ZIndex = 20,
		Parent = root,
	})
	Kit.panel({ Color = C.Accent, Size = UDim2.new(0, 8, 1, 0), Radius = 0, ZIndex = 21, Parent = banner })
	bannerTitle = Kit.label({
		Text = "",
		Font = F.Display,
		TextSize = T.Heading,
		Color = C.Accent,
		Size = UDim2.new(1, -40, 0, 32),
		Position = UDim2.fromOffset(24, 10),
		ZIndex = 21,
		Parent = banner,
	})
	bannerText = Kit.label({
		Text = "",
		Font = F.Body,
		TextSize = T.Body,
		Wrap = true,
		AlignY = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.fromOffset(24, 44),
		ZIndex = 21,
		Parent = banner,
	})
	bannerAward = Kit.label({
		Text = "",
		Font = F.Heavy,
		TextSize = T.Small,
		Color = C.TextDim,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -40, 0, 18),
		Position = UDim2.new(0, 24, 1, -24),
		ZIndex = 21,
		Parent = banner,
	})
	restartInfo = Kit.label({
		Text = "",
		Font = F.Heavy,
		TextSize = T.Large,
		Color = C.Text,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(700, 28),
		Position = UDim2.new(0.5, 0, 1, -210),
		AnchorPoint = Vector2.new(0.5, 0),
		Outline = 2,
		Visible = false,
		ZIndex = 8,
		Parent = root,
	})
	toastList = Kit.box({
		Name = "Toasts",
		Size = UDim2.fromOffset(340, 300),
		Position = UDim2.new(1, -24, 0, 110),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 15,
		Parent = root,
	})
	Kit.list(toastList, 8, false, Enum.HorizontalAlignment.Right)
end

local toastOrder = 0
local function toast(text: string, color: Color3?)
	toastOrder += 1
	local item = Kit.panel({
		Color = C.Ink,
		Size = UDim2.fromOffset(0, 40),
		AutoSize = Enum.AutomaticSize.X,
		Order = toastOrder,
		ZIndex = 15,
		Parent = toastList,
	})
	Kit.padding(item, 14, 0)
	Kit.panel({ Color = color or C.Accent, Size = UDim2.new(0, 4, 1, 0), Radius = 0, ZIndex = 16, Parent = item })
	Kit.label({
		Text = text,
		Font = F.Bold,
		TextSize = T.Body,
		Size = UDim2.fromOffset(0, 40),
		AutoSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(10, 0),
		ZIndex = 16,
		Parent = item,
	})
	Kit.pop(item, 0.85)
	task.delay(4, function()
		item:Destroy()
	end)
end

local function showBanner(title: string, text: string, award: string?, accent: Color3?)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = title
	bannerTitle.TextColor3 = accent or C.Accent
	bannerText.Text = text
	bannerAward.Text = award or ""
	banner.Visible = true
	Kit.pop(banner, 0.92)
	task.delay(4, function()
		if bannerToken == token then
			banner.Visible = false
		end
	end)
end

local function buildOverlays()
	goalOverlay = Kit.box({ Name = "Goal", Visible = false, ZIndex = 30, Parent = root })
	goalLabel = Kit.label({
		Text = "GOAL",
		Font = F.Display,
		TextSize = T.Giant,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(900, 170),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Outline = 4,
		ZIndex = 32,
		Parent = goalOverlay,
	})

	phaseOverlay = Kit.box({ Name = "Phase", Visible = false, ZIndex = 25, Parent = root })
	phaseTitle = Kit.label({
		Text = "",
		Font = F.Display,
		TextSize = T.Hero,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(1000, 90),
		Position = UDim2.fromScale(0.5, 0.38),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Outline = 3,
		ZIndex = 26,
		Parent = phaseOverlay,
	})
	phaseSub = Kit.label({
		Text = "",
		Font = F.Heavy,
		TextSize = T.Large,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(1000, 30),
		Position = UDim2.new(0.5, 0, 0.38, 56),
		AnchorPoint = Vector2.new(0.5, 0),
		Outline = 2,
		ZIndex = 26,
		Parent = phaseOverlay,
	})

	-- Role selection --------------------------------------------------------------------
	selection = Kit.panel({
		Name = "Selection",
		Color = C.Ink,
		Size = UDim2.fromScale(1, 1),
		Radius = 0,
		Visible = false,
		ZIndex = 40,
		Parent = root,
	})
	Kit.slash(selection, C.Accent, UDim2.fromOffset(14, 120), UDim2.fromOffset(70, 54), 41)
	Kit.label({
		Text = "CHOISIS TON RÔLE",
		Font = F.Display,
		TextSize = T.Title,
		Size = UDim2.fromOffset(700, 50),
		Position = UDim2.fromOffset(100, 70),
		ZIndex = 41,
		Parent = selection,
	})
	selectionTimer = Kit.label({
		Text = "",
		Font = F.Mono,
		TextSize = T.Title,
		Color = C.Accent,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(200, 50),
		Position = UDim2.new(1, -100, 0, 70),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 41,
		Parent = selection,
	})
	local roles = {
		{
			Id = "Goalkeeper",
			Title = "GARDIEN",
			Text = "Défends ta zone de 6 m. Clic droit / L2 : plongeon vers le viseur. Tu peux te déplacer avec le ballon dans ta zone.",
			Tip = "Style : réflexes et placement",
		},
		{
			Id = "Field",
			Title = "JOUEUR DE CHAMP",
			Text = "Passe, dribble, tire, intercepte et défends. Respecte les 3 secondes, les 3 pas et la zone adverse.",
			Tip = "Style : vitesse et lecture du jeu",
		},
	}
	for index, role in roles do
		local card = Kit.panel({
			Color = C.Surface,
			Size = UDim2.fromOffset(420, 300),
			Position = UDim2.fromOffset(100 + (index - 1) * 450, 170),
			ZIndex = 41,
			Parent = selection,
		})
		Kit.panel({ Color = C.Accent, Size = UDim2.new(1, 0, 0, 6), Radius = 0, ZIndex = 42, Parent = card })
		Kit.label({
			Text = role.Title,
			Font = F.Display,
			TextSize = T.Heading + 4,
			Size = UDim2.new(1, -40, 0, 40),
			Position = UDim2.fromOffset(24, 26),
			ZIndex = 42,
			Parent = card,
		})
		Kit.label({
			Text = role.Tip,
			Font = F.Bold,
			TextSize = T.Small,
			Color = C.Accent,
			Size = UDim2.new(1, -40, 0, 20),
			Position = UDim2.fromOffset(24, 70),
			ZIndex = 42,
			Parent = card,
		})
		Kit.label({
			Text = role.Text,
			TextSize = T.Body,
			Color = C.TextDim,
			Wrap = true,
			AlignY = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -48, 0, 100),
			Position = UDim2.fromOffset(24, 100),
			ZIndex = 42,
			Parent = card,
		})
		roleButtons[role.Id] = Kit.button({
			Text = "CHOISIR",
			Variant = "Primary",
			Size = UDim2.new(1, -48, 0, 50),
			Position = UDim2.new(0, 24, 1, -74),
			ZIndex = 42,
			Parent = card,
			OnClick = function()
				selectionStatus.Text = "…"
				local ok, a, b = pcall(function()
					return Remotes.func("SelectRole"):InvokeServer(role.Id)
				end)
				if not ok then
					selectionStatus.Text = "Impossible de contacter le serveur."
					selectionStatus.TextColor3 = C.Danger
				elseif a == false then
					selectionStatus.Text = if typeof(b) == "string" then b else "Choix refusé."
					selectionStatus.TextColor3 = C.Danger
				else
					selectionStatus.Text = `Rôle choisi : {role.Title}`
					selectionStatus.TextColor3 = C.Success
				end
			end,
		})
	end
	selectionStatus = Kit.label({
		Text = "",
		Font = F.Bold,
		TextSize = T.Body,
		Size = UDim2.fromOffset(870, 24),
		Position = UDim2.fromOffset(100, 486),
		ZIndex = 41,
		Parent = selection,
	})
	local teamPanel = Kit.panel({
		Color = C.Surface,
		Size = UDim2.fromOffset(420, 520),
		Position = UDim2.new(1, -100, 0, 170),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 41,
		Parent = selection,
	})
	Kit.label({
		Text = "TON ÉQUIPE",
		Font = F.Display,
		TextSize = T.Large,
		Size = UDim2.new(1, -40, 0, 30),
		Position = UDim2.fromOffset(24, 20),
		ZIndex = 42,
		Parent = teamPanel,
	})
	selectionTeam = Kit.box({
		Size = UDim2.new(1, -48, 1, -140),
		Position = UDim2.fromOffset(24, 62),
		ZIndex = 42,
		Parent = teamPanel,
	})
	Kit.list(selectionTeam, 8)
	selectionWarning = Kit.label({
		Text = "",
		Font = F.Bold,
		TextSize = T.Small,
		Color = C.Warning,
		Wrap = true,
		Size = UDim2.new(1, -48, 0, 44),
		Position = UDim2.new(0, 24, 1, -64),
		ZIndex = 42,
		Parent = teamPanel,
	})

	results = Kit.panel({
		Name = "Results",
		Color = C.Ink,
		Size = UDim2.fromScale(1, 1),
		Radius = 0,
		Visible = false,
		ZIndex = 50,
		Parent = root,
	})
end

-- Nameplates ------------------------------------------------------------------------------------------

local function plateFor(participant: Types.ParticipantSnapshot, model: Model)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local plate = plates[model]
	if not plate then
		plate = Kit.new("BillboardGui", {
			Name = "HL_Nameplate",
			Size = UDim2.fromOffset(170, 44),
			StudsOffset = Vector3.new(0, 2.6, 0),
			MaxDistance = 140,
			AlwaysOnTop = true,
			LightInfluence = 0,
			ResetOnSpawn = false,
			Adornee = head,
			-- BillboardGuis do not render inside a ScreenGui: parent to PlayerGui.
			Parent = localPlayer:FindFirstChildOfClass("PlayerGui"),
		})
		local back = Kit.panel({
			Name = "Back",
			Color = C.Ink,
			Size = UDim2.fromOffset(0, 24),
			AutoSize = Enum.AutomaticSize.X,
			Position = UDim2.fromScale(0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			Radius = 4,
			Parent = plate,
		})
		Kit.padding(back, 8, 0)
		Kit.list(back, 6, true)
		Kit.label({
			Name = "Symbol",
			Font = F.Heavy,
			TextSize = T.Small,
			Size = UDim2.fromOffset(0, 24),
			AutoSize = Enum.AutomaticSize.X,
			Order = 1,
			Parent = back,
		})
		Kit.label({
			Name = "Number",
			Font = F.Display,
			TextSize = T.Small,
			Size = UDim2.fromOffset(0, 24),
			AutoSize = Enum.AutomaticSize.X,
			Order = 2,
			Parent = back,
		})
		Kit.label({
			Name = "PlayerName",
			Font = F.Bold,
			TextSize = T.Small,
			Size = UDim2.fromOffset(0, 24),
			AutoSize = Enum.AutomaticSize.X,
			Order = 3,
			Parent = back,
		})
		Kit.label({
			Name = "Tags",
			Font = F.Heavy,
			TextSize = T.Tiny,
			Size = UDim2.fromOffset(0, 24),
			AutoSize = Enum.AutomaticSize.X,
			Order = 4,
			Parent = back,
		})
		local target = Kit.label({
			Name = "Target",
			Text = "▼ PASSE",
			Font = F.Heavy,
			TextSize = T.Tiny,
			Color = C.Accent,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.fromOffset(0, 26),
			Outline = 1,
			Visible = false,
			Parent = plate,
		})
		target.Name = "Target"
		plates[model] = plate
	end
	local back = plate:FindFirstChild("Back") :: Frame
	local team = Theme.team(participant.Team)
	local symbol = back:FindFirstChild("Symbol") :: TextLabel
	symbol.Text = team.Symbol
	symbol.TextColor3 = team.Main
	local number = back:FindFirstChild("Number") :: TextLabel
	number.Text = tostring(participant.Number)
	number.TextColor3 = team.Main
	local name = back:FindFirstChild("PlayerName") :: TextLabel
	name.Text = participant.Name
	name.TextColor3 = if participant.UserId == localPlayer.UserId then C.Accent else C.Text
	local tags = back:FindFirstChild("Tags") :: TextLabel
	local parts = {}
	if participant.Role == "Goalkeeper" then
		table.insert(parts, "GK")
	end
	if participant.SuspendedUntil > now() then
		table.insert(parts, "2'")
	elseif participant.Warned then
		table.insert(parts, "■")
	end
	tags.Text = table.concat(parts, " ")
	tags.TextColor3 = if participant.Warned then C.Warning else C.Info
end

local function refreshPlates(match: Types.MatchSnapshot?)
	local seen: { [Model]: boolean } = {}
	if match then
		for _, participant in match.Participants do
			local model = participant.Model
			if model and model.Parent then
				seen[model] = true
				plateFor(participant, model)
			end
		end
	end
	for model, plate in plates do
		if not seen[model] then
			plate:Destroy()
			plates[model] = nil
		end
	end
end

local currentTarget: string? = nil
local function setPassTarget(id: string?)
	currentTarget = id
	for model, plate in plates do
		local target = plate:FindFirstChild("Target")
		if target and target:IsA("TextLabel") then
			local participant = MatchClient.participantOfModel(model)
			target.Visible = id ~= nil and participant ~= nil and participant.Id == id
		end
	end
	local participant = MatchClient.participant(id)
	passTargetLabel.Text = if participant then `PASSE ▸ {participant.Name}` else ""
end

-- Selection screen --------------------------------------------------------------------------------------------

local function refreshSelection(match: Types.MatchSnapshot)
	local me = MatchClient.me()
	Kit.clear(selectionTeam)
	local hasKeeper = false
	if me then
		for index, participant in match.Participants do
			if participant.Team == me.Team then
				if participant.Role == "Goalkeeper" then
					hasKeeper = true
				end
				local team = Theme.team(participant.Team)
				local row = Kit.panel({
					Color = C.Raised,
					Size = UDim2.new(1, 0, 0, 44),
					Order = index,
					ZIndex = 42,
					Parent = selectionTeam,
				})
				Kit.label({
					Text = `{team.Symbol} {participant.Number}  {participant.Name}`,
					Font = F.Bold,
					TextSize = T.Body,
					Color = if participant.Id == me.Id then C.Accent else C.Text,
					Size = UDim2.new(0.62, 0, 1, 0),
					Position = UDim2.fromOffset(14, 0),
					ZIndex = 43,
					Parent = row,
				})
				Kit.label({
					Text = if participant.Role == "Goalkeeper" then "GARDIEN" else "CHAMP",
					Font = F.Heavy,
					TextSize = T.Small,
					Color = if participant.Role == "Goalkeeper" then C.Info else C.TextDim,
					AlignX = Enum.TextXAlignment.Right,
					Size = UDim2.new(0.38, -14, 1, 0),
					Position = UDim2.new(0.62, 0, 0, 0),
					ZIndex = 43,
					Parent = row,
				})
			end
		end
		for id, button in roleButtons do
			button.SetSelected(me.Role == id)
		end
	end
	selectionWarning.Text = if hasKeeper
		then ""
		else "Ton équipe n'a pas encore de gardien. Le match peut commencer quand même, mais ta cage sera vide."
end

-- Results -------------------------------------------------------------------------------------------------

local function showResults(data: Types.ResultsSnapshot)
	Kit.clear(results)
	results.Visible = true
	local winner = data.Winner
	local title = if winner then `VICTOIRE {teamLabel(winner)}` else "MATCH NUL"
	local me = MatchClient.me()
	local subtitle = if not winner
		then "Égalité après la prolongation."
		elseif me and me.Team == winner then "Bien joué !"
		elseif me then "Défaite — la revanche t'attend."
		else ""
	Kit.slash(
		results,
		if winner then Theme.team(winner).Main else C.Accent,
		UDim2.fromOffset(16, 130),
		UDim2.fromOffset(80, 46),
		51
	)
	Kit.label({
		Text = title,
		Font = F.Display,
		TextSize = T.Hero,
		Color = if winner then Theme.team(winner).Main else C.Text,
		Size = UDim2.fromOffset(1000, 80),
		Position = UDim2.fromOffset(116, 50),
		ZIndex = 51,
		Parent = results,
	})
	Kit.label({
		Text = `{data.Score.Red or 0}  —  {data.Score.Blue or 0}     {subtitle}`,
		Font = F.Heavy,
		TextSize = T.Heading,
		Color = C.TextDim,
		Size = UDim2.fromOffset(1000, 34),
		Position = UDim2.fromOffset(120, 134),
		ZIndex = 51,
		Parent = results,
	})
	local tableFrame = Kit.box({
		Size = UDim2.new(1, -240, 1, -260),
		Position = UDim2.fromOffset(120, 200),
		ZIndex = 51,
		Parent = results,
	})
	Kit.list(tableFrame, 6)
	local columns = { "JOUEUR", "B", "PD", "ARR", "INT", "CTR", "FAUTES" }
	local widths = { 0.4, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1 }
	local function row(values: { string }, order: number, color: Color3, back: Color3?, bold: boolean?)
		local frame = Kit.panel({
			Color = back or C.Surface,
			Size = UDim2.new(1, 0, 0, 40),
			Order = order,
			Radius = 4,
			ZIndex = 52,
			Parent = tableFrame,
		})
		local x = 0
		for i, value in values do
			Kit.label({
				Text = value,
				Font = if bold or i == 1 then F.Heavy else F.Bold,
				TextSize = T.Body,
				Color = color,
				AlignX = if i == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
				Size = UDim2.new(widths[i], if i == 1 then -16 else 0, 1, 0),
				Position = UDim2.new(x, if i == 1 then 16 else 0, 0, 0),
				ZIndex = 53,
				Parent = frame,
			})
			x += widths[i]
		end
	end
	row(columns, 0, C.TextDim, C.Ink, true)
	local players = table.clone(data.Players)
	table.sort(players, function(a, b)
		if a.Team ~= b.Team then
			return a.Team < b.Team
		end
		return a.Number < b.Number
	end)
	for index, participant in players do
		local team = Theme.team(participant.Team)
		local name = `{team.Symbol} {participant.Number}  {participant.Name}`
		if data.Mvp == participant.Id then
			name ..= "  ★ MVP"
		end
		row(
			{
				name,
				tostring(participant.Goals),
				tostring(participant.Assists),
				tostring(participant.Saves),
				tostring(participant.Interceptions),
				tostring(participant.Blocks),
				tostring(participant.Fouls),
			},
			index,
			if me and participant.Id == me.Id then C.Accent else team.Main,
			if me and participant.Id == me.Id then C.Raised else nil
		)
	end
end

-- Event handling --------------------------------------------------------------------------------------------

local RESTART_NAMES: { [string]: string } = {
	ThrowOff = "ENGAGEMENT",
	ThrowIn = "RENTRÉE DE TOUCHE",
	GoalkeeperThrow = "RENVOI DU GARDIEN",
	FreeThrow = "JET FRANC",
	Penalty = "JET DE 7 M",
}

local REASON_TITLES: { [string]: string } = {
	ThreeSeconds = "3 SECONDES",
	Steps = "MARCHER",
	DoubleDribble = "REPRISE DE DRIBBLE",
	AttackerInArea = "ZONE DU GARDIEN",
	DefenderInArea = "DÉFENSE DANS LA ZONE",
	IllegalContact = "CONTACT IRRÉGULIER",
	ContactFromBehind = "CONTACT PAR DERRIÈRE",
	PassivePlay = "JEU PASSIF",
	OutOfBounds = "SORTIE",
	GoalkeeperThrow = "RENVOI DU GARDIEN",
	Corner = "CORNER",
	AttackerInAreaNoBall = "ZONE DU GARDIEN",
	OwnArea = "RETOUR DANS SA ZONE",
	Delay = "REMISE EN JEU TROP LENTE",
	Penalty = "JET DE 7 M",
	KeeperLeftArea = "GARDIEN HORS ZONE",
	ThrowOff = "ENGAGEMENT",
}

local function onEvent(kind: string, data: any)
	if kind == "Whistle" then
		local reason = tostring(data.Reason or "")
		local title = REASON_TITLES[reason] or RESTART_NAMES[tostring(data.Kind or "")] or "COUP DE SIFFLET"
		local text = if typeof(data.Text) == "string" then data.Text else ""
		local award = ""
		if data.Kind and data.Team then
			award = `{RESTART_NAMES[data.Kind] or data.Kind} pour {teamLabel(data.Team)}`
		end
		if reason ~= "ThrowOff" then
			showBanner(title, text, award, if data.Kind == "Penalty" then C.Danger else C.Accent)
		end
	elseif kind == "Goal" then
		local team = Theme.team(data.Team)
		goalLabel.TextColor3 = team.Main
		goalOverlay.Visible = true
		Kit.pop(goalLabel, 1.6)
		local scorer = MatchClient.participant(data.ScorerId)
		local assist = MatchClient.participant(data.AssistId)
		if scorer then
			toast(
				if assist then `{team.Symbol} {scorer.Name}  (passe : {assist.Name})` else `{team.Symbol} {scorer.Name}`,
				team.Main
			)
		end
		task.delay(Config.Match.GoalCelebrationTime - 0.5, function()
			goalOverlay.Visible = false
		end)
	elseif kind == "PassiveWarning" then
		showBanner(
			"JEU PASSIF",
			`L'arbitre lève le bras : {teamLabel(data.Team)} doit tirer dans les {Config.Rules.PassivePlayGrace} secondes, sinon le ballon change de camp.`,
			nil,
			C.Warning
		)
	elseif kind == "Warning" then
		local participant = MatchClient.participant(data.Id)
		if participant then
			toast(`■ Avertissement : {participant.Name} (fautes répétées)`, C.Warning)
		end
	elseif kind == "Suspension" then
		local participant = MatchClient.participant(data.Id)
		if participant then
			toast(`2' Exclusion temporaire : {participant.Name}`, C.Danger)
		end
	elseif kind == "Halftime" then
		phaseTitle.Text = "MI-TEMPS"
		phaseSub.Text = "Changement de côté"
		phaseOverlay.Visible = true
		task.delay(3, function()
			phaseOverlay.Visible = false
		end)
	elseif kind == "Overtime" then
		phaseTitle.Text = "PROLONGATION"
		phaseSub.Text = "But en or : la prochaine équipe qui marque gagne"
		phaseOverlay.Visible = true
		task.delay(3, function()
			phaseOverlay.Visible = false
		end)
	elseif kind == "Results" then
		showResults(data :: Types.ResultsSnapshot)
	elseif kind == "ShotIncoming" then
		local me = MatchClient.me()
		local point: Vector3? = data.Point
		if me and data.KeeperId == me.Id and point then
			-- Local marker on the goal plane where the shot will arrive.
			local marker = Instance.new("Part")
			marker.Name = "HL_ShotMarker"
			marker.Anchored = true
			marker.CanCollide = false
			marker.CanQuery = false
			marker.CanTouch = false
			marker.Shape = Enum.PartType.Ball
			marker.Material = Enum.Material.Neon
			marker.Color = C.Danger
			marker.Transparency = 0.35
			marker.Size = Vector3.new(1.4, 1.4, 1.4)
			marker.Position = point
			marker.Parent = Workspace
			local arrival = tonumber(data.ArrivalTime) or (now() + 0.5)
			task.delay(math.clamp(arrival - now() + 0.15, 0.1, 2), function()
				marker:Destroy()
			end)
		end
	end
end

-- Per-frame refresh ------------------------------------------------------------------------------------------

local function updateCourtScoreboard(match: Types.MatchSnapshot)
	local maps = Workspace:FindFirstChild("HL_Maps")
	if not maps then
		return
	end
	local court = maps:FindFirstChild(`Court_{match.Mode}`)
	local board = court and court:FindFirstChild("Scoreboard", true)
	local display = board and board:FindFirstChild("Display")
	if not display then
		return
	end
	local function set(name: string, text: string)
		local label = display:FindFirstChild(name)
		if label and label:IsA("TextLabel") and label.Text ~= text then
			label.Text = text
		end
	end
	set("RedScore", tostring(match.Score.Red or 0))
	set("BlueScore", tostring(match.Score.Blue or 0))
	set("Clock", formatClock(clockValue(match)))
	set("Period", periodName(match))
end

local function update()
	local match = MatchClient.Match
	local playing = MatchClient.isPlaying()
	local inMatch = match ~= nil and match.Phase ~= "Results"

	scoreFrame.Visible = inMatch and match ~= nil and match.Phase ~= "Selection"
	crosshair.Visible = playing
	dashChip.Visible = playing
	passTargetLabel.Visible = playing

	if match and inMatch then
		redScore.Text = tostring(match.Score.Red or 0)
		blueScore.Text = tostring(match.Score.Blue or 0)
		clockLabel.Text = formatClock(clockValue(match))
		local remaining = clockValue(match)
		clockLabel.TextColor3 = if remaining <= 10 and match.ClockRunning then C.Danger else C.Accent
		periodLabel.Text = periodName(match)
		redPossession.Visible = match.Possession == "Red"
		bluePossession.Visible = match.Possession == "Blue"
		passiveIcon.Visible = match.PassiveWarning ~= nil
		updateCourtScoreboard(match)

		-- Selection screen
		if match.Phase == "Selection" then
			selection.Visible = true
			if match.PhaseEndsAt then
				selectionTimer.Text = formatClock(match.PhaseEndsAt - now())
			end
		else
			selection.Visible = false
		end

		-- Countdown / team assignment overlays
		if match.Phase == "Countdown" and match.PhaseEndsAt then
			phaseOverlay.Visible = true
			local left = math.ceil(match.PhaseEndsAt - now())
			phaseTitle.Text = if left > 0 then tostring(left) else "GO !"
			phaseSub.Text = `{match.Mode} · {periodName(match)}`
		elseif match.Phase == "TeamAssignment" or match.Phase == "Waiting" then
			phaseOverlay.Visible = true
			phaseTitle.Text = "FORMATION DES ÉQUIPES"
			phaseSub.Text = match.Mode
		elseif match.Phase == "Halftime" then
			phaseOverlay.Visible = true
			phaseTitle.Text = "MI-TEMPS"
			phaseSub.Text = if match.PhaseEndsAt
				then `Reprise dans {math.max(0, math.ceil(match.PhaseEndsAt - now()))} s`
				else ""
		elseif
			phaseOverlay.Visible
			and (match.Phase == "Playing" or match.Phase == "Overtime")
			and phaseTitle.Text ~= "PROLONGATION"
		then
			phaseOverlay.Visible = false
		end

		-- Restart instruction
		local restart = match.Restart
		if restart and match.PlayState == "Restart" then
			local me = MatchClient.me()
			local name = RESTART_NAMES[restart.Kind] or restart.Kind
			local left = math.max(0, math.ceil(restart.Deadline - now()))
			restartInfo.Visible = true
			if me and restart.ThrowerId == me.Id then
				restartInfo.Text = `{name} — À TOI DE LANCER ({left} s)`
				restartInfo.TextColor3 = C.Accent
			else
				restartInfo.Text = `{name} · {teamLabel(restart.Team)}`
				restartInfo.TextColor3 = C.Text
			end
		else
			restartInfo.Visible = false
		end
	else
		selection.Visible = false
		if not match then
			phaseOverlay.Visible = false
		end
		restartInfo.Visible = false
	end
	if not match then
		results.Visible = false
	end

	-- Carrier rule timers (only for the local holder).
	local ball = MatchClient.Ball
	if playing and ball and MatchClient.iHoldBall() then
		carrier.Visible = true
		if ball.Dribbling then
			holdLabel.Text = "DRIBBLE — pas de limite de pas"
			setHold(1, C.Info)
		else
			local held = now() - ball.HoldStart
			local left = math.max(0, Config.Rules.MaxHoldTime - held)
			holdLabel.Text = string.format("BALLON EN MAIN  %.1f s", left)
			local color = if held >= Config.Rules.HoldWarningTime then C.Danger else C.White
			setHold(left / Config.Rules.MaxHoldTime, color)
		end
		for i, pip in stepPips do
			local used = not ball.Dribbling and ball.Steps >= i
			pip.BackgroundColor3 = if used
				then (if i >= Config.Rules.MaxSteps then C.Danger else C.Accent)
				else C.Raised
		end
		dribbleLabel.Text = if ball.Dribbling
			then "● DRIBBLE"
			elseif ball.HasDribbled then "DRIBBLE UTILISÉ"
			else "DRIBBLE DISPO"
		dribbleLabel.TextColor3 = if ball.HasDribbled and not ball.Dribbling then C.Warning else C.Info
	else
		carrier.Visible = false
	end

	-- Shot charge
	local charging = call(actionController, "isCharging") == true
	chargeBack.Visible = playing and charging
	if charging then
		local progress = tonumber(call(actionController, "chargeProgress")) or 0
		setCharge(progress, if progress >= 1 then C.Danger else C.Accent)
	end

	-- Pass target (polled as a fallback if no signal is exposed)
	if playing then
		local target = call(actionController, "passTarget")
		if typeof(target) ~= "string" then
			target = nil
		end
		if target ~= currentTarget then
			setPassTarget(target)
		end
	elseif currentTarget then
		setPassTarget(nil)
	end

	-- Dash cooldown
	if playing then
		local readyAt = tonumber(call(movementController, "dashReadyAt"))
		if not readyAt then
			local me = MatchClient.me()
			readyAt = if me then me.DashReadyAt else 0
		end
		local left = (readyAt or 0) - now()
		if left > 0 then
			dashLabel.Text = string.format("DASH  %.1f", left)
			setDash(1 - left / Config.Movement.DashCooldown, C.TextDim)
		else
			dashLabel.Text = "DASH  PRÊT"
			setDash(1, C.Accent)
		end
	end
end

function HUDController.init()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local _gui
	_gui, root = Kit.screen("HL_HUD", 10, playerGui)
	buildScoreboard()
	buildCentre()
	buildCarrier()
	buildDash()
	buildMessages()
	buildOverlays()
end

function HUDController.start()
	actionController = optionalModule("ActionController")
	movementController = optionalModule("MovementController")
	if actionController and typeof(actionController.PassTargetChanged) == "table" then
		pcall(function()
			actionController.PassTargetChanged:Connect(function(id)
				setPassTarget(if typeof(id) == "string" then id else nil)
			end)
		end)
	end

	if actionController and typeof(actionController.ActionFeedback) == "table" then
		local messages: { [string]: string } = {
			NoTarget = "Aucun coéquipier dans la direction visée",
			Cooldown = "Action en recharge",
			NoBall = "Tu n'as pas le ballon",
			Frozen = "Attends la reprise du jeu",
			DribbleUsed = "Reprise de dribble interdite : passe ou tire",
		}
		local lastShown: { [string]: number } = {}
		pcall(function()
			actionController.ActionFeedback:Connect(function(kind)
				local text = messages[tostring(kind)]
				local t = os.clock()
				if text and (lastShown[kind] or 0) + 1.2 < t then
					lastShown[kind] = t
					toast(text, if kind == "DribbleUsed" then C.Warning else C.TextDim)
				end
			end)
		end)
	end

	MatchClient.MatchChanged:Connect(function(match)
		refreshPlates(match)
		if match and match.Phase == "Selection" then
			refreshSelection(match)
		end
	end)
	MatchClient.Event:Connect(onEvent)
	MatchClient.Notified:Connect(function(text, style)
		local color = if style == "Danger" then C.Danger elseif style == "Success" then C.Success else C.Accent
		toast(text, color)
	end)
	RunService.RenderStepped:Connect(update)
end

return HUDController
