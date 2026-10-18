--!strict
-- HUD du match : score et temps, pouvoirs, recharges, chrono des 3 secondes,
-- jauge de tir, viseur, boutons tactiles, étiquettes des joueurs.
-- Style « anime sport » : plaques inclinées, encre épaisse, couleurs vives.

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

-- Couleur de chaque emplacement de pouvoir.
local SLOT_COLORS = { C.Cyan, C.Pink, C.Accent }

type Slot = {
	Holder: Frame,
	Face: Frame,
	Fill: Frame,
	Name: TextLabel,
	Value: TextLabel,
	Stroke: UIStroke,
	Glow: Frame,
	Color: Color3,
	WasReady: boolean,
}
type Chip = { Face: Frame, Fill: Frame, Value: TextLabel, Color: Color3 }

local gui: ScreenGui
local root: Frame
local scoreRouge: TextLabel
local scoreBleu: TextLabel
local clockLabel: TextLabel
local periodLabel: TextLabel
local possessionRouge: Frame
local possessionBleu: Frame
local passive: Frame
local slots: { Slot } = {}
local dashChip: Chip
local contactChip: Chip
local holdBar: Frame
local holdFill: Frame
local holdLabel: TextLabel
local chargeBar: Frame
local chargeFill: Frame
local chargeFlash: Frame
local crosshair: Frame
local touchLayer: Frame
local plates: { [Model]: BillboardGui } = {}
local lastArchetype: string? = nil
local lastScore = { Rouge = -1, Bleu = -1 }

local HOLD_POSITION = UDim2.new(0.5, 0, 0.5, 64)

local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Badge à ombre dure, utilisable dans un UIListLayout (l'ombre est interne).
local function badge(parent: Instance, size: Vector2, order: number, z: number): (Frame, Frame, UIStroke)
	local holder = Kit.box({
		Size = UDim2.fromOffset(size.X + 5, size.Y + 5),
		Order = order,
		ZIndex = z,
		Parent = parent,
	})
	local shadow = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(5, 5),
		Rotation = Theme.Tilt,
		ZIndex = z,
		Parent = holder,
	})
	Kit.corner(shadow, 8)
	local face = Kit.surface({
		Color = C.Surface,
		Size = UDim2.fromOffset(size.X, size.Y),
		Rotation = Theme.Tilt,
		Clip = true,
		Radius = 8,
		ZIndex = z,
		Parent = holder,
	})
	local stroke = face:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Thickness = 3
	return holder, face, stroke
end

-- Tableau de score ------------------------------------------------------------------------------

local function buildScoreboard()
	local board = Kit.box({
		Size = UDim2.fromOffset(560, 96),
		Position = UDim2.new(0.5, 0, 0, 16),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 5,
		Parent = root,
	})
	local function team(teamId: string, left: boolean): (TextLabel, Frame)
		local info = Theme.Team[teamId]
		local plate = Kit.plate({
			Color = info.Main,
			Size = UDim2.fromOffset(196, 62),
			Position = if left then UDim2.new(0.5, -82, 0, 4) else UDim2.new(0.5, 82, 0, 4),
			AnchorPoint = Vector2.new(if left then 1 else 0, 0),
			Rotation = if left then -4 else 4,
			BorderThickness = 3,
			ZIndex = 6,
			Parent = board,
		})
		Kit.gradient(plate, Theme.lighten(info.Main, 0.15), info.Dark, 90)
		Kit.halftone({
			Parent = plate,
			Color = C.White,
			Columns = 9,
			Rows = 4,
			Spacing = 14,
			Transparency = 0.86,
			Flip = left,
			Position = if left then UDim2.fromScale(0, 0) else UDim2.fromScale(1, 0),
			AnchorPoint = if left then Vector2.zero else Vector2.new(1, 0),
			ZIndex = 6,
		})
		Kit.label({
			Text = info.Name,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H3,
			Color = C.White,
			Stroke = 2,
			AlignX = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -28, 1, 0),
			Position = UDim2.fromOffset(14, 0),
			ZIndex = 7,
			Parent = plate,
		})
		local score = Kit.label({
			Text = "0",
			Font = Theme.Fonts.Number,
			TextSize = 54,
			Color = C.White,
			Stroke = 3,
			AlignX = if left then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -28, 1, 4),
			Position = UDim2.fromOffset(14, -4),
			ZIndex = 8,
			Parent = plate,
		})
		-- Indicateur de possession : bande jaune sous la plaque.
		local possession = Kit.new("Frame", {
			BackgroundColor3 = C.Accent,
			BorderSizePixel = 0,
			Size = UDim2.new(0.7, 0, 0, 7),
			Position = UDim2.new(if left then 1 else 0, if left then -6 else 6, 1, 6),
			AnchorPoint = Vector2.new(if left then 1 else 0, 0),
			Visible = false,
			ZIndex = 7,
			Parent = plate,
		})
		Kit.border(possession, C.Ink, 2)
		return score, possession
	end
	scoreRouge, possessionRouge = team("Rouge", true)
	scoreBleu, possessionBleu = team("Bleu", false)

	local center = Kit.surface({
		Color = C.Ink,
		Gradient = false,
		BorderColor = C.Accent,
		BorderThickness = 3,
		Size = UDim2.fromOffset(150, 74),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Radius = 6,
		ZIndex = 9,
		Parent = board,
	})
	clockLabel = Kit.label({
		Text = "0:00",
		Font = Theme.Fonts.Number,
		TextSize = 40,
		Color = C.White,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 46),
		Position = UDim2.fromOffset(0, 2),
		ZIndex = 10,
		Parent = center,
	})
	periodLabel = Kit.label({
		Text = "",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Tiny + 1,
		Color = C.Accent,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 48),
		ZIndex = 10,
		Parent = center,
	})

	passive = Kit.plate({
		Color = C.Orange,
		Size = UDim2.fromOffset(170, 32),
		Position = UDim2.new(0.5, 0, 0, 116),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	Kit.label({
		Text = "JEU PASSIF",
		Font = Theme.Fonts.Hero,
		TextSize = 24,
		Color = C.White,
		Stroke = 2,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = passive,
	})
end

-- Pouvoirs et recharges -----------------------------------------------------------------------------

local function buildAbilities()
	local bar = Kit.box({
		Size = UDim2.fromOffset(640, 120),
		Position = UDim2.new(0.5, 0, 1, -20),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 5,
		Parent = root,
	})
	Kit.list(bar, 12, true, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)

	local function chip(key: string, order: number, color: Color3): Chip
		local _, face = badge(bar, Vector2.new(64, 64), order, 6)
		local fill = Kit.new("Frame", {
			BackgroundColor3 = color,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			ZIndex = 6,
			Parent = face,
		})
		Kit.gradient(fill, Theme.lighten(color, 0.3), color, 90)
		Kit.label({
			Text = key,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.Tiny + 1,
			Color = C.White,
			Stroke = 1.5,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.fromOffset(0, 6),
			ZIndex = 8,
			Parent = face,
		})
		local value = Kit.label({
			Text = "",
			Font = Theme.Fonts.Number,
			TextSize = 24,
			Color = C.White,
			Stroke = 2,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.fromOffset(0, 24),
			ZIndex = 8,
			Parent = face,
		})
		return { Face = face, Fill = fill, Value = value, Color = color }
	end
	dashChip = chip(if isTouch then "DASH" else "SHIFT", 1, C.Lime)
	contactChip = chip(if isTouch then "CONTRE" else "F", 2, C.Orange)
	Kit.box({ Size = UDim2.fromOffset(8, 8), Order = 3, Parent = bar })

	for slot = 1, 3 do
		local color = SLOT_COLORS[slot]
		local size = if slot == 3 then Vector2.new(120, 110) else Vector2.new(100, 92)
		local holder, face, stroke = badge(bar, size, 3 + slot, 6)
		-- Halo qui pulse quand le pouvoir est prêt (derrière la face).
		local glow = Kit.new("Frame", {
			BackgroundColor3 = color,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(size.X + 14, size.Y + 14),
			Position = UDim2.fromOffset(size.X / 2, size.Y / 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = Theme.Tilt,
			Visible = false,
			ZIndex = 5,
			Parent = holder,
		})
		Kit.corner(glow, 12)
		Kit.tween(
			glow,
			TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundTransparency = 0.85, Size = UDim2.fromOffset(size.X + 26, size.Y + 26) }
		)
		local fill = Kit.new("Frame", {
			BackgroundColor3 = color,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			ZIndex = 6,
			Parent = face,
		})
		Kit.gradient(fill, Theme.lighten(color, 0.35), Theme.darken(color, 0.2), 90)
		local key = Kit.new("Frame", {
			BackgroundColor3 = C.Ink,
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.fromOffset(7, 7),
			ZIndex = 8,
			Parent = face,
		})
		Kit.corner(key, 4)
		Kit.border(key, color, 2)
		Kit.label({
			Text = tostring(slot),
			Font = Theme.Fonts.Number,
			TextSize = Theme.Text.Small + 1,
			Color = color,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 9,
			Parent = key,
		})
		local value = Kit.label({
			Text = "",
			Font = Theme.Fonts.Number,
			TextSize = if slot == 3 then 36 else 30,
			Color = C.White,
			Stroke = 2.5,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 36),
			Position = UDim2.new(0, 0, 0.5, -22),
			ZIndex = 8,
			Parent = face,
		})
		local name = Kit.label({
			Text = "",
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.Tiny + 1,
			Color = C.White,
			Stroke = 1.5,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -10, 0, 16),
			Position = UDim2.new(0, 5, 1, -22),
			ZIndex = 8,
			Parent = face,
		})
		local hit = Kit.new(
			"TextButton",
			{ BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 12, Parent = holder }
		)
		hit.Activated:Connect(function()
			MatchInput.perform(`Power{slot}`)
		end)
		slots[slot] = {
			Holder = holder,
			Face = face,
			Fill = fill,
			Name = name,
			Value = value,
			Stroke = stroke,
			Glow = glow,
			Color = color,
			WasReady = false,
		}
	end
end

-- Centre : viseur, ballon en main, tir ------------------------------------------------------------

local function buildCenter()
	crosshair = Kit.box({
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 5,
		Parent = root,
	})
	local dot = Kit.new("Frame", {
		BackgroundColor3 = C.Accent,
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 6,
		Parent = crosshair,
	})
	Kit.corner(dot, 3)
	Kit.border(dot, C.Ink, 1.5)
	for _, offset in { Vector2.new(-12, 0), Vector2.new(12, 0), Vector2.new(0, -12), Vector2.new(0, 12) } do
		local tick = Kit.new("Frame", {
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			Size = if offset.X ~= 0 then UDim2.fromOffset(8, 3) else UDim2.fromOffset(3, 8),
			Position = UDim2.new(0.5, offset.X, 0.5, offset.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 6,
			Parent = crosshair,
		})
		Kit.border(tick, C.Ink, 1.5)
	end

	-- Chrono des 3 secondes.
	holdBar = Kit.box({
		Size = UDim2.fromOffset(240, 54),
		Position = HOLD_POSITION,
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	holdLabel = Kit.label({
		Text = "",
		Font = Theme.Fonts.Number,
		TextSize = 26,
		Color = C.White,
		Stroke = 2.5,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		ZIndex = 6,
		Parent = holdBar,
	})
	local track = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.fromOffset(0, 36),
		Rotation = Theme.Tilt,
		ClipsDescendants = true,
		ZIndex = 6,
		Parent = holdBar,
	})
	Kit.corner(track, 3)
	Kit.border(track, C.Ink, 2.5)
	holdFill = Kit.new(
		"Frame",
		{ BackgroundColor3 = C.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = track }
	)
	Kit.corner(holdFill, 3)
	Kit.shade(holdFill, 0.25)

	-- Jauge de tir verticale (dégradé jaune → rose → rouge).
	chargeBar = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(14, 120),
		Position = UDim2.new(0.5, 46, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Rotation = 4,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	Kit.corner(chargeBar, 4)
	Kit.border(chargeBar, C.Ink, 2.5)
	chargeFill = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		ZIndex = 6,
		Parent = chargeBar,
	})
	Kit.corner(chargeFill, 4)
	Kit.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.Danger),
			ColorSequenceKeypoint.new(0.45, C.Pink),
			ColorSequenceKeypoint.new(1, C.Accent),
		}),
		Rotation = 90,
		Parent = chargeFill,
	})
	chargeFlash = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
		Parent = chargeBar,
	})
end

-- Boutons tactiles -------------------------------------------------------------------------------------

local function buildTouch()
	touchLayer = Kit.box({
		Size = UDim2.fromOffset(380, 360),
		Position = UDim2.new(1, -24, 1, -150),
		AnchorPoint = Vector2.new(1, 1),
		Visible = isTouch,
		ZIndex = 10,
		Parent = root,
	})
	local function round(
		text: string,
		size: number,
		position: Vector2,
		color: Color3,
		onDown: () -> (),
		onUp: (() -> ())?
	)
		Kit.new("Frame", {
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromOffset(position.X + 4, position.Y + 5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 10,
			Parent = touchLayer,
		}, { Kit.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		local button = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = color,
			Text = text,
			FontFace = Theme.Fonts.Display,
			TextSize = if size > 120 then 30 else 18,
			TextColor3 = Theme.onColor(color),
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromOffset(position.X, position.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 11,
			Parent = touchLayer,
		})
		Kit.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = button })
		Kit.border(button, C.Ink, 3)
		Kit.shade(button, 0.25)
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				Kit.pop(button, 0.88)
				onDown()
			end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch and onUp then
				onUp()
			end
		end)
	end
	round("TIR", 136, Vector2.new(300, 280), C.Accent, function()
		MatchInput.perform("ShootBegin")
	end, function()
		MatchInput.perform("ShootEnd")
	end)
	round("PASSE", 96, Vector2.new(160, 312), C.Cyan, function()
		MatchInput.perform("Pass")
	end)
	round("DASH", 88, Vector2.new(300, 128), C.Lime, function()
		MatchInput.perform("Dash")
	end)
	round("CONTRE", 84, Vector2.new(176, 186), C.Pink, function()
		MatchInput.perform("Contact")
	end)
	round("DRIBBLE", 76, Vector2.new(60, 272), C.Violet, function()
		MatchInput.perform("Dribble")
	end)
end

-- Étiquettes des joueurs --------------------------------------------------------------------------

local function plateFor(participant: any): BillboardGui?
	local model = participant.Model
	if not model or not model.Parent then
		return nil
	end
	local existing = plates[model]
	if existing and existing.Parent then
		return existing
	end
	local head = model:FindFirstChild("Head")
	if not head then
		return nil
	end
	local billboard = Kit.new("BillboardGui", {
		Name = "Etiquette",
		Size = UDim2.fromOffset(200, 50),
		StudsOffset = Vector3.new(0, 2.6, 0),
		MaxDistance = 120,
		AlwaysOnTop = true,
		ResetOnSpawn = false,
		Adornee = head,
		Parent = LocalPlayer:WaitForChild("PlayerGui"),
	})
	Kit.label({
		Name = "Nom",
		Text = "",
		Font = Theme.Fonts.Display,
		TextSize = 17,
		Color = C.White,
		Stroke = 2,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = 2,
		Parent = billboard,
	})
	local bar = Kit.new("Frame", {
		Name = "Equipe",
		BackgroundColor3 = Theme.Team[participant.Team].Main,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(44, 5),
		Position = UDim2.new(0.5, -22, 0, 24),
		Rotation = Theme.Tilt,
		ZIndex = 2,
		Parent = billboard,
	})
	Kit.border(bar, C.Ink, 1.5)
	Kit.label({
		Name = "Statut",
		Text = "",
		Font = Theme.Fonts.Display,
		TextSize = 13,
		Color = C.Warning,
		Stroke = 1.5,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 32),
		ZIndex = 2,
		Parent = billboard,
	})
	plates[model] = billboard
	return billboard
end

local function updatePlates(match: any)
	local seen: { [Model]: boolean } = {}
	local now = Workspace:GetServerTimeNow()
	for _, participant in match.Participants do
		local plate = plateFor(participant)
		if plate and participant.Model then
			seen[participant.Model] = true
			plate.Enabled = participant.UserId ~= LocalPlayer.UserId
			local name = plate:FindFirstChild("Nom") :: TextLabel
			name.Text = `{participant.Number}  {participant.Name}`
			local status = plate:FindFirstChild("Statut") :: TextLabel
			if participant.SuspendedUntil > now then
				status.Text = `EXCLU {Format.clock(participant.SuspendedUntil - now)}`
				status.TextColor3 = C.Danger
			elseif participant.RedCard then
				status.Text = "CARTON ROUGE"
				status.TextColor3 = C.Danger
			elseif participant.YellowCard then
				status.Text = "AVERTI"
				status.TextColor3 = C.Warning
			else
				status.Text = ""
			end
		end
	end
	for model, plate in plates do
		if not seen[model] or not model.Parent then
			plate:Destroy()
			plates[model] = nil
		end
	end
end

-- Mise à jour ------------------------------------------------------------------------------------------

-- Remplissage qui monte depuis le bas (0 = vide, 1 = prêt).
local function setFill(fill: Frame, ratio: number)
	fill.Size = UDim2.fromScale(1, math.clamp(ratio, 0, 1))
end

local function setScore(label: TextLabel, team: string, value: number)
	if lastScore[team] ~= value then
		if lastScore[team] >= 0 then
			Kit.slam(label, 1.8)
		end
		lastScore[team] = value
		label.Text = tostring(value)
	end
end

local function update()
	local match = State.Match
	local me = MatchInput.me()
	local visible = match ~= nil
		and match.Phase ~= "Ended"
		and me ~= nil
		and State.Setup ~= nil
		and State.Setup.Closed == true
	gui.Enabled = visible
	if not visible or not match then
		return
	end
	local now = Workspace:GetServerTimeNow()
	setScore(scoreRouge, "Rouge", match.Score.Rouge)
	setScore(scoreBleu, "Bleu", match.Score.Bleu)
	local clock = match.Clock
	if match.ClockRunning then
		clock = math.max(0, clock - (now - match.ServerTime))
	end
	clockLabel.Text = Format.clock(clock)
	clockLabel.TextColor3 = if match.ClockRunning and clock <= 10 then C.Danger else C.White
	periodLabel.Text = if match.Half == 3 then "BUT EN OR" elseif match.Half == 2 then "2E MI-TEMPS" else "1RE MI-TEMPS"
	possessionRouge.Visible = match.Possession == "Rouge"
	possessionBleu.Visible = match.Possession == "Bleu"
	passive.Visible = match.PassiveWarning == true
	if passive.Visible then
		passive.Rotation = Theme.Tilt + math.sin(os.clock() * 10) * 2
	end

	local archetype = Archetypes.get(me.Archetype)
	if archetype then
		if lastArchetype ~= archetype.Id then
			lastArchetype = archetype.Id
			for index, slot in slots do
				local power = archetype.Powers[index]
				slot.Name.Text = string.upper(power.Name)
			end
		end
		local p1Left = math.max(0, me.Power1ReadyAt - now)
		local states = {
			{
				Ratio = 1 - p1Left / Config.Powers.Power1Cooldown,
				Ready = p1Left <= 0,
				Text = if p1Left > 0 then tostring(math.ceil(p1Left)) else "",
			},
			{
				Ratio = me.Energy / Config.Powers.EnergyMax,
				Ready = me.Energy >= Config.Powers.EnergyMax,
				Text = if me.Energy >= Config.Powers.EnergyMax then "" else `{math.floor(me.Energy)}%`,
			},
			{
				Ratio = me.Ultimate / Config.Powers.UltimateMax,
				Ready = me.Ultimate >= Config.Powers.UltimateMax and not me.RedCard,
				Text = if me.RedCard
					then "—"
					elseif me.Ultimate >= Config.Powers.UltimateMax then ""
					else `{math.floor(me.Ultimate)}%`,
			},
		}
		for index, slot in slots do
			local state = states[index]
			setFill(slot.Fill, state.Ratio)
			slot.Fill.BackgroundTransparency = if state.Ready then 0 else 0.3
			slot.Face.BackgroundColor3 = if state.Ready then slot.Color else C.Surface
			slot.Value.Text = state.Text
			slot.Stroke.Color = if state.Ready then C.White else C.Ink
			slot.Name.TextColor3 = if state.Ready then C.White else C.TextMuted
			slot.Glow.Visible = state.Ready
			if state.Ready and not slot.WasReady then
				Kit.slam(slot.Holder, 1.35)
			end
			-- L'ultime prêt vibre légèrement pour attirer l'œil.
			if index == 3 and state.Ready then
				slot.Face.Rotation = Theme.Tilt + math.sin(os.clock() * 14) * 1.5
			else
				slot.Face.Rotation = Theme.Tilt
			end
			slot.WasReady = state.Ready
		end
	end
	local dashLeft = MatchInput.DashReadyAt - os.clock()
	setFill(dashChip.Fill, 1 - math.max(0, dashLeft) / Config.Movement.DashCooldown)
	dashChip.Value.Text = if dashLeft > 0 then string.format("%.1f", dashLeft) else ""
	dashChip.Face.BackgroundColor3 = if dashLeft <= 0 then Theme.darken(dashChip.Color, 0.35) else C.Surface
	local contactLeft = (me.NextContactAt or 0) - now
	setFill(contactChip.Fill, 1 - math.max(0, contactLeft) / Config.Contact.Cooldown)
	contactChip.Value.Text = if contactLeft > 0 then string.format("%.1f", contactLeft) else ""
	contactChip.Face.BackgroundColor3 = if contactLeft <= 0 then Theme.darken(contactChip.Color, 0.35) else C.Surface

	local ball = State.Ball
	local holding = MatchInput.isHolding()
	holdBar.Visible = holding
	holdBar.Position = HOLD_POSITION
	if holding and ball then
		if ball.Locked then
			holdLabel.Text = "ATTENDS LE SIFFLET"
			holdLabel.TextSize = 20
			holdFill.Size = UDim2.fromScale(1, 1)
			holdFill.BackgroundColor3 = C.TextFaint
		elseif ball.Dribbling then
			holdLabel.Text = "DRIBBLE · R POUR REPRENDRE"
			holdLabel.TextSize = 20
			holdFill.Size = UDim2.fromScale(1, 1)
			holdFill.BackgroundColor3 = C.Cyan
		else
			local left = math.max(0, Config.Rules.MaxHoldTime - (now - ball.HoldStart))
			local color = if left < 1 then C.Danger elseif left < 2 then C.Pink else C.Accent
			holdLabel.Text = string.format("%.1f", left)
			holdLabel.TextSize = if left < 1 then 34 else 28
			holdLabel.TextColor3 = color
			holdFill.Size = UDim2.fromScale(left / Config.Rules.MaxHoldTime, 1)
			holdFill.BackgroundColor3 = color
			if left < 1 then
				holdBar.Position = HOLD_POSITION + UDim2.fromOffset(math.random(-3, 3), math.random(-2, 2))
			end
		end
		if ball.Locked or ball.Dribbling then
			holdLabel.TextColor3 = C.White
		end
	end
	local charge = MatchInput.Charge
	chargeBar.Visible = charge ~= nil
	if charge then
		chargeFill.Size = UDim2.fromScale(1, charge)
		chargeFlash.BackgroundTransparency = if charge >= 1 then 0.4 + 0.4 * math.abs(math.sin(os.clock() * 20)) else 1
	end
	crosshair.Visible = MatchInput.CameraLocked or isTouch
	updatePlates(match)
end

function MatchHUD.start()
	gui, root = Kit.screen("HUD", 20, LocalPlayer:WaitForChild("PlayerGui"))
	gui.Enabled = false
	buildScoreboard()
	buildAbilities()
	buildCenter()
	buildTouch()
	RunService.RenderStepped:Connect(update)
	State.MatchEvent:Connect(function(kind)
		if kind == "Leave" then
			for model, plate in plates do
				plate:Destroy()
				plates[model] = nil
			end
			lastArchetype = nil
			lastScore = { Rouge = -1, Bleu = -1 }
		end
	end)
end

return MatchHUD
