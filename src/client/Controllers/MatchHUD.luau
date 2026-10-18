--!strict
-- Interface de match : tableau de score, pouvoirs, chrono des 3 secondes,
-- jauge de tir, viseur, boutons tactiles et étiquettes des joueurs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Kit = require(script.Parent.Parent.UI.Kit)
local MatchInput = require(script.Parent.MatchInput)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local LocalPlayer = Players.LocalPlayer

local MatchHUD = {}

local gui: ScreenGui
local root: Frame

type Slot = {
	Container: Frame,
	Face: Frame,
	Fill: Frame,
	Name: TextLabel,
	State: TextLabel,
	Key: TextLabel,
}

local scoreRouge: TextLabel
local scoreBleu: TextLabel
local clockText: TextLabel
local periodText: TextLabel
local possessionBar: Frame
local passiveIcon: Frame
local slots: { Slot } = {}
local holdPanel: Frame
local holdFill: Frame
local holdText: TextLabel
local chargePanel: Frame
local chargeFill: Frame
local crosshair: Frame
local dashChip: TextLabel
local contactChip: TextLabel
local touchPanel: Frame
local nameplates: { [Model]: BillboardGui } = {}
local lastPowerArchetype: string? = nil

local POSTE_SHORT = { Gardien = "GB", Defenseur = "DEF", Attaquant = "ATT" }

-- Tableau de score ---------------------------------------------------------------------------------

local function buildScoreboard()
	local holder = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(640, 96),
		Position = UDim2.new(0.5, 0, 0, 16),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 5,
		Parent = root,
	})
	local function teamBlock(team: string, x: number, anchor: number): TextLabel
		local face, _ = Kit.panel({
			Size = UDim2.fromOffset(200, 80),
			Position = UDim2.new(x, 0, 0, 0),
			AnchorPoint = Vector2.new(anchor, 0),
			Color = Theme.Team[team].Main,
			Rotation = if anchor == 0 then -2 else 2,
			ZIndex = 6,
			Parent = holder,
		})
		Kit.text({
			Text = string.upper(team),
			Color = C.Paper,
			Stroke = C.Ink,
			Size = UDim2.new(0.55, 0, 0.5, 0),
			Position = UDim2.fromScale(if anchor == 0 then 0.05 else 0.4, 0.25),
			ZIndex = 7,
			Parent = face,
		})
		return Kit.text({
			Text = "0",
			Color = C.Paper,
			Stroke = C.Ink,
			StrokeThickness = 4,
			Size = UDim2.new(0.38, 0, 0.95, 0),
			Position = UDim2.fromScale(if anchor == 0 then 0.6 else 0.02, 0.02),
			ZIndex = 7,
			Parent = face,
		})
	end
	scoreRouge = teamBlock("Rouge", 0, 0)
	scoreBleu = teamBlock("Bleu", 1, 1)
	local center, _ = Kit.panel({
		Size = UDim2.fromOffset(210, 96),
		Position = UDim2.new(0.5, 0, 0, -6),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = C.Ink,
		ZIndex = 8,
		Parent = holder,
	})
	clockText = Kit.text({
		Text = "0:00",
		Color = C.Paper,
		Size = UDim2.new(1, -20, 0.62, 0),
		Position = UDim2.fromOffset(10, 4),
		ZIndex = 9,
		Parent = center,
	})
	periodText = Kit.text({
		Text = "",
		Color = C.Yellow,
		Font = Theme.Fonts.Title,
		Size = UDim2.new(1, -20, 0.3, 0),
		Position = UDim2.new(0, 10, 0.64, 0),
		ZIndex = 9,
		Parent = center,
	})
	possessionBar = Kit.new("Frame", {
		BackgroundColor3 = C.Yellow,
		Size = UDim2.new(0, 200, 0, 10),
		Position = UDim2.new(0.5, 0, 1, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 6,
		Parent = holder,
	})
	Kit.stroke(possessionBar, 2)
	passiveIcon = Kit.new("Frame", {
		BackgroundColor3 = C.Yellow,
		Size = UDim2.fromOffset(190, 40),
		Position = UDim2.new(0.5, 0, 1, 26),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		Rotation = -3,
		ZIndex = 6,
		Parent = holder,
	})
	Kit.stroke(passiveIcon, 3)
	Kit.text({ Text = "✋ JEU PASSIF", ZIndex = 7, Parent = passiveIcon })
end

-- Pouvoirs ------------------------------------------------------------------------------------------------

local function buildPowers()
	local bar = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(660, 130),
		Position = UDim2.new(0.5, 0, 1, -20),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 5,
		Parent = root,
	})
	Kit.list(bar, 18, true, Enum.HorizontalAlignment.Center)
	for slot = 1, 3 do
		local face, container = Kit.panel({
			Size = UDim2.fromOffset(if slot == 3 then 240 else 200, 120),
			Color = C.InkSoft,
			Order = slot,
			Clip = true,
			ZIndex = 6,
			Parent = bar,
		})
		local fill = Kit.new("Frame", {
			BackgroundColor3 = C.Yellow,
			Size = UDim2.fromScale(1, 0),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = face,
		})
		local key = Kit.text({
			Text = tostring(slot),
			Color = C.Ink,
			Size = UDim2.fromOffset(34, 34),
			Position = UDim2.fromOffset(8, 8),
			ZIndex = 9,
			Parent = face,
		})
		local keyBack = Kit.new("Frame", {
			BackgroundColor3 = C.Paper,
			Size = UDim2.fromOffset(34, 34),
			Position = UDim2.fromOffset(8, 8),
			ZIndex = 8,
			Parent = face,
		})
		Kit.stroke(keyBack, 2)
		local name = Kit.text({
			Text = "",
			Color = C.Paper,
			Stroke = C.Ink,
			StrokeThickness = 2,
			Size = UDim2.new(1, -16, 0, 40),
			Position = UDim2.fromOffset(8, 46),
			ZIndex = 9,
			Parent = face,
		})
		local stateLabel = Kit.text({
			Text = "",
			Font = Theme.Fonts.Heavy,
			Color = C.Yellow,
			Size = UDim2.new(1, -16, 0, 22),
			Position = UDim2.fromOffset(8, 90),
			ZIndex = 9,
			Parent = face,
		})
		local hit = Kit.new(
			"TextButton",
			{ BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 12, Parent = container }
		)
		hit.Activated:Connect(function()
			MatchInput.perform(`Power{slot}`)
		end)
		slots[slot] = { Container = container, Face = face, Fill = fill, Name = name, State = stateLabel, Key = key }
	end
	-- Rappels de commandes à gauche.
	local hints = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, 200),
		Position = UDim2.new(0, 24, 1, -24),
		AnchorPoint = Vector2.new(0, 1),
		ZIndex = 5,
		Parent = root,
	})
	Kit.list(hints, 6)
	local function chip(text: string, order: number): TextLabel
		local back = Kit.new("Frame", {
			BackgroundColor3 = C.Ink,
			Size = UDim2.fromOffset(280, 30),
			LayoutOrder = order,
			ZIndex = 6,
			Parent = hints,
		})
		return Kit.text({
			Text = text,
			Font = Theme.Fonts.Body,
			Color = C.Paper,
			Size = UDim2.new(1, -16, 1, -6),
			Position = UDim2.fromOffset(8, 3),
			AlignX = Enum.TextXAlignment.Left,
			ZIndex = 7,
			Parent = back,
		})
	end
	chip("CLIC : tir chargé  ·  E : passe", 1)
	chip("R : dribble  ·  CTRL : caméra", 2)
	dashChip = chip("SHIFT : dash", 3)
	contactChip = chip("F : interception / contact", 4)
	hints.Visible = not (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
end

-- Ballon en main : chrono + jauge de tir + viseur ---------------------------------------------------------

local function buildCenter()
	crosshair = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 5,
		Parent = root,
	})
	for _, rotation in { 0, 90 } do
		local line = Kit.new("Frame", {
			BackgroundColor3 = C.Paper,
			Size = UDim2.fromOffset(26, 4),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rotation,
			ZIndex = 6,
			Parent = crosshair,
		})
		Kit.stroke(line, 2)
	end
	holdPanel = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		Size = UDim2.fromOffset(240, 46),
		Position = UDim2.new(0.5, 0, 0.5, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	Kit.stroke(holdPanel, 3)
	holdFill = Kit.new("Frame", {
		BackgroundColor3 = C.Green,
		Size = UDim2.fromScale(1, 0.35),
		Position = UDim2.fromScale(0, 0.65),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = holdPanel,
	})
	holdText = Kit.text({
		Text = "",
		Color = C.Paper,
		Size = UDim2.new(1, -10, 0.6, 0),
		Position = UDim2.fromOffset(5, 2),
		ZIndex = 7,
		Parent = holdPanel,
	})
	chargePanel = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		Size = UDim2.fromOffset(26, 160),
		Position = UDim2.new(0.5, 90, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	Kit.stroke(chargePanel, 3)
	chargeFill = Kit.new("Frame", {
		BackgroundColor3 = C.Yellow,
		Size = UDim2.fromScale(1, 0),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = chargePanel,
	})
end

-- Boutons tactiles (mobile) -------------------------------------------------------------------------

local function buildTouch()
	touchPanel = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(420, 420),
		Position = UDim2.new(1, -20, 1, -170),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 10,
		Parent = root,
	})
	touchPanel.Visible = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local function round(
		text: string,
		size: number,
		position: UDim2,
		color: Color3,
		onDown: () -> (),
		onUp: (() -> ())?
	)
		local button = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = color,
			Text = text,
			Font = Theme.Fonts.Title,
			TextScaled = true,
			TextColor3 = C.Paper,
			Size = UDim2.fromOffset(size, size),
			Position = position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 11,
			Parent = touchPanel,
		})
		Kit.corner(button, size)
		Kit.stroke(button, 5)
		Kit.textStroke(button, 2)
		Kit.padding(button, math.floor(size * 0.18))
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				Kit.pop(button, 0.85)
				onDown()
			end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch and onUp then
				onUp()
			end
		end)
	end
	round("TIR", 150, UDim2.fromOffset(320, 300), C.Red, function()
		MatchInput.perform("ShootBegin")
	end, function()
		MatchInput.perform("ShootEnd")
	end)
	round("PASSE", 110, UDim2.fromOffset(170, 330), C.Blue, function()
		MatchInput.perform("Pass")
	end)
	round("DASH", 100, UDim2.fromOffset(300, 140), C.Yellow, function()
		MatchInput.perform("Dash")
	end)
	round("CONTRE", 96, UDim2.fromOffset(170, 200), C.Purple, function()
		MatchInput.perform("Contact")
	end)
	round("DRIB.", 84, UDim2.fromOffset(60, 290), C.Green, function()
		MatchInput.perform("Dribble")
	end)
end

-- Étiquettes au-dessus des joueurs ---------------------------------------------------------------------

local function nameplateFor(participant: any): BillboardGui?
	local model = participant.Model
	if not model or not model.Parent then
		return nil
	end
	local plate = nameplates[model]
	if plate and plate.Parent then
		return plate
	end
	local head = model:FindFirstChild("Head")
	if not head then
		return nil
	end
	local billboard = Kit.new("BillboardGui", {
		Name = "PlaqueMatch",
		Size = UDim2.fromOffset(160, 56),
		StudsOffset = Vector3.new(0, 2.9, 0),
		MaxDistance = 140,
		AlwaysOnTop = true,
		ResetOnSpawn = false,
		Adornee = head,
		-- Un BillboardGui doit être directement dans PlayerGui pour s'afficher.
		Parent = LocalPlayer:WaitForChild("PlayerGui"),
	})
	local team = Theme.Team[participant.Team] or Theme.Team.Rouge
	local tag = Kit.new(
		"Frame",
		{ Name = "Nom", BackgroundColor3 = team.Main, Size = UDim2.new(1, 0, 0, 30), ZIndex = 2, Parent = billboard }
	)
	Kit.stroke(tag, 3)
	Kit.text({
		Name = "Texte",
		Text = "",
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 2,
		Size = UDim2.new(1, -8, 1, -4),
		Position = UDim2.fromOffset(4, 2),
		ZIndex = 3,
		Parent = tag,
	})
	local status = Kit.text({
		Name = "Statut",
		Text = "",
		Color = C.Yellow,
		Stroke = C.Ink,
		StrokeThickness = 2,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 32),
		ZIndex = 3,
		Parent = billboard,
	})
	local _ = status
	nameplates[model] = billboard
	return billboard
end

local function updateNameplates(match: any)
	local seen: { [Model]: boolean } = {}
	local now = Workspace:GetServerTimeNow()
	for _, participant in match.Participants do
		local plate = nameplateFor(participant)
		if plate and participant.Model then
			seen[participant.Model] = true
			local tag = plate:FindFirstChild("Nom") :: Frame
			local label = tag:FindFirstChild("Texte") :: TextLabel
			local short = POSTE_SHORT[participant.Poste or ""] or ""
			label.Text = `#{participant.Number} {participant.Name} {short}`
			local status = plate:FindFirstChild("Statut") :: TextLabel
			local cards = ""
			if participant.RedCard then
				cards = "🟥 "
			elseif participant.YellowCard then
				cards = "🟨 "
			end
			if participant.SuspendedUntil > now then
				status.Text = `{cards}EXCLU {Format.clock(participant.SuspendedUntil - now)}`
				status.TextColor3 = C.Red
			else
				status.Text = cards
				status.TextColor3 = C.Yellow
			end
			-- Pas d'étiquette au-dessus de soi-même.
			plate.Enabled = participant.UserId ~= LocalPlayer.UserId
		end
	end
	for model, plate in nameplates do
		if not seen[model] or not model.Parent then
			plate:Destroy()
			nameplates[model] = nil
		end
	end
end

-- Mise à jour -------------------------------------------------------------------------------------------

local function update()
	local match = State.Match
	local mine = MatchInput.me()
	gui.Enabled = match ~= nil and match.Phase ~= "Ended" and mine ~= nil and State.Setup ~= nil and State.Setup.Closed
	if not gui.Enabled or not match then
		return
	end
	local now = Workspace:GetServerTimeNow()
	scoreRouge.Text = tostring(match.Score.Rouge)
	scoreBleu.Text = tostring(match.Score.Bleu)
	local clock = match.Clock
	if match.ClockRunning then
		clock = math.max(0, clock - (now - match.ServerTime))
	end
	clockText.Text = Format.clock(clock)
	periodText.Text = if match.Half == 3 then "BUT EN OR" elseif match.Half == 2 then "2e MI-TEMPS" else "1re MI-TEMPS"
	possessionBar.BackgroundColor3 = if match.Possession then Theme.Team[match.Possession].Main else C.Paper
	passiveIcon.Visible = match.PassiveWarning == true

	-- Pouvoirs.
	local archetype = Archetypes.get(mine.Archetype)
	if archetype then
		if lastPowerArchetype ~= archetype.Id then
			lastPowerArchetype = archetype.Id
			for index, slot in slots do
				local power = archetype.Powers[index]
				slot.Name.Text = string.upper(power.Name)
				slot.Fill.BackgroundColor3 = power.Color
			end
		end
		local p1 = math.max(0, mine.Power1ReadyAt - now)
		local values = {
			{
				Ratio = 1 - p1 / Config.Powers.Power1Cooldown,
				Ready = p1 <= 0,
				Text = if p1 > 0 then `{math.ceil(p1)} s` else "PRÊT !",
			},
			{
				Ratio = mine.Energy / Config.Powers.EnergyMax,
				Ready = mine.Energy >= Config.Powers.EnergyMax,
				Text = if mine.Energy >= Config.Powers.EnergyMax then "PRÊT !" else `{math.floor(mine.Energy)} %`,
			},
			{
				Ratio = mine.Ultimate / Config.Powers.UltimateMax,
				Ready = mine.Ultimate >= Config.Powers.UltimateMax and not mine.RedCard,
				Text = if mine.RedCard
					then "BLOQUÉ"
					elseif mine.Ultimate >= Config.Powers.UltimateMax then "ULTIME PRÊT !"
					else `{math.floor(mine.Ultimate)} %`,
			},
		}
		for index, slot in slots do
			local value = values[index]
			slot.Fill.Size = UDim2.fromScale(1, math.clamp(value.Ratio, 0, 1))
			slot.State.Text = value.Text
			local stroke = slot.Face:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if value.Ready then C.Yellow else C.Ink
				stroke.Thickness = if value.Ready then 6 + math.sin(os.clock() * 8) * 1.5 else 4
			end
		end
	end
	local dashLeft = MatchInput.DashReadyAt - os.clock()
	dashChip.Text = if dashLeft > 0 then `SHIFT : dash ({string.format("%.1f", dashLeft)} s)` else "SHIFT : dash"
	local contactLeft = (mine.NextContactAt or 0) - now
	contactChip.Text = if contactLeft > 0
		then `F : contact ({string.format("%.1f", contactLeft)} s)`
		else "F : interception / contact"

	-- Ballon en main.
	local ball = State.Ball
	local holding = MatchInput.isHolding()
	holdPanel.Visible = holding
	if holding and ball then
		if ball.Locked then
			holdText.Text = "ATTENDS LE COUP DE SIFFLET"
			holdFill.Size = UDim2.fromScale(1, 0.35)
			holdFill.BackgroundColor3 = C.Yellow
		elseif ball.Dribbling then
			holdText.Text = "DRIBBLE · R pour reprendre"
			holdFill.Size = UDim2.fromScale(1, 0.35)
			holdFill.BackgroundColor3 = C.Blue
		else
			local held = now - ball.HoldStart
			local left = math.max(0, Config.Rules.MaxHoldTime - held)
			holdText.Text = `{string.format("%.1f", left)} s · PASSE OU TIRE !`
			holdFill.Size = UDim2.fromScale(left / Config.Rules.MaxHoldTime, 0.35)
			holdFill.BackgroundColor3 = if left < 1 then C.Red elseif left < 2 then C.Yellow else C.Green
		end
	end
	local charge = MatchInput.Charge
	chargePanel.Visible = charge ~= nil
	if charge then
		chargeFill.Size = UDim2.fromScale(1, charge)
		chargeFill.BackgroundColor3 = if charge >= 1 then C.Red elseif charge > 0.6 then C.Yellow else C.Paper
	end
	crosshair.Visible = MatchInput.CameraLocked
		or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	updateNameplates(match)
end

function MatchHUD.start()
	gui = Kit.screen("HUDMatch", 20, LocalPlayer:WaitForChild("PlayerGui"))
	gui.Enabled = false
	root = Kit.root(gui)
	buildScoreboard()
	buildPowers()
	buildCenter()
	buildTouch()
	RunService.RenderStepped:Connect(update)
	State.MatchEvent:Connect(function(kind)
		if kind == "Leave" then
			for model, plate in nameplates do
				plate:Destroy()
				nameplates[model] = nil
			end
			lastPowerArchetype = nil
		end
	end)
end

return MatchHUD
