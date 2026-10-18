--!strict
-- HUD du match, épuré :
--   • en haut au centre : score rouge / bleu, chrono, période ;
--   • en bas au centre : jauge de tir au timing, chrono des 3 secondes,
--     pouvoirs (cercles qui se remplissent), dash et contact ;
--   • boutons tactiles sur mobile, étiquettes au-dessus des joueurs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local ShotTiming = require(ReplicatedStorage.Shared.ShotTiming)
local Kit = require(script.Parent.Parent.UI.Kit)
local MatchInput = require(script.Parent.MatchInput)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local LocalPlayer = Players.LocalPlayer

local MatchHUD = {}

local SLOT_COLORS = { C.Sky, Color3.fromRGB(124, 92, 246), C.Gold }
local GRADE_LOOK = {
	Perfect = { Text = "PARFAIT !", Color = C.Gold },
	Good = { Text = "BIEN", Color = C.Success },
	Weak = { Text = "FAIBLE", Color = C.TextFaint },
}

type Ring = {
	Holder: Frame,
	Fill: Frame,
	Face: Frame,
	Value: TextLabel,
	Name: TextLabel?,
	Glow: Frame,
	Color: Color3,
	WasReady: boolean,
}

local gui: ScreenGui
local root: Frame
local scoreLabels: { [string]: TextLabel } = {}
local possessionDots: { [string]: Frame } = {}
local clockLabel: TextLabel
local periodLabel: TextLabel
local rings: { Ring } = {}
local dashRing: Ring
local contactRing: Ring
local holdPill: Frame
local holdFill: Frame
local holdLabel: TextLabel
local gauge: Frame
local gaugeCursor: Frame
local gradeLabel: TextLabel
local crosshair: Frame
local plates: { [Model]: BillboardGui } = {}
local lastArchetype: string? = nil
local lastScore = { Rouge = -1, Bleu = -1 }

local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Tableau de score --------------------------------------------------------------------------------

local function buildScoreboard()
	local board = Kit.surface({
		Transparency = 0.04,
		BorderColor = C.White,
		BorderThickness = 3,
		Radius = 30,
		Size = UDim2.fromOffset(420, 64),
		Position = UDim2.new(0.5, 0, 0, 16),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 5,
		Parent = root,
	})
	for index, teamId in { "Rouge", "Bleu" } do
		local info = Theme.Team[teamId]
		local left = index == 1
		local pill = Kit.new("Frame", {
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(130, 52),
			Position = if left then UDim2.fromOffset(6, 6) else UDim2.new(1, -136, 0, 6),
			ZIndex = 6,
			Parent = board,
		})
		Kit.corner(pill, 26)
		Kit.gradient(pill, info.Light, info.Main, 90)
		Kit.label({
			Text = info.Name,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.Tiny,
			Color = C.White,
			Transparency = 0.1,
			AlignX = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -36, 1, 0),
			Position = UDim2.fromOffset(18, 0),
			ZIndex = 7,
			Parent = pill,
		})
		scoreLabels[teamId] = Kit.label({
			Text = "0",
			Font = Theme.Fonts.Number,
			TextSize = 38,
			Color = C.White,
			Stroke = 2,
			StrokeColor = info.Dark,
			AlignX = if left then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -36, 1, 0),
			Position = UDim2.fromOffset(18, 0),
			ZIndex = 8,
			Parent = pill,
		})
		-- Indicateur de possession : petit ballon sous l'équipe qui attaque.
		local dot = Kit.icon("Ball", board, 20, nil, 9)
		dot.AnchorPoint = Vector2.new(0.5, 0)
		dot.Position = UDim2.new(if left then 0 else 1, if left then 71 else -71, 1, 4)
		dot.Visible = false
		possessionDots[teamId] = dot
	end
	clockLabel = Kit.label({
		Text = "0:00",
		Font = Theme.Fonts.Number,
		TextSize = 30,
		Color = C.Text,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(140, 36),
		Position = UDim2.new(0.5, 0, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 6,
		Parent = board,
	})
	periodLabel = Kit.label({
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = C.TextMuted,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(140, 16),
		Position = UDim2.new(0.5, 0, 0, 40),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 6,
		Parent = board,
	})
end

-- Cercles de pouvoirs ------------------------------------------------------------------------------

-- Cercle avec remplissage par le bas (CanvasGroup pour une découpe ronde).
local function ring(parent: Instance, size: number, color: Color3, key: string, order: number, z: number): Ring
	local holder = Kit.box({
		Size = UDim2.fromOffset(size + 12, size + 34),
		Order = order,
		ZIndex = z,
		Parent = parent,
	})
	local glow = Kit.new("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, size / 2 + 6),
		Size = UDim2.fromOffset(size + 10, size + 10),
		Visible = false,
		ZIndex = z,
		Parent = holder,
	})
	Kit.round(glow)
	Kit.tween(
		glow,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundTransparency = 0.85, Size = UDim2.fromOffset(size + 22, size + 22) }
	)
	local face = Kit.new("CanvasGroup", {
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(size, size),
		ZIndex = z,
		Parent = holder,
	})
	Kit.round(face)
	local fill = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		ZIndex = z,
		Parent = face,
	})
	Kit.gradient(fill, Theme.lighten(color, 0.3), color, 90)
	local outline = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(size, size),
		ZIndex = z + 1,
		Parent = holder,
	})
	Kit.round(outline)
	Kit.border(outline, C.White, 3)
	local value = Kit.label({
		Text = "",
		Font = Theme.Fonts.Number,
		TextSize = math.floor(size * 0.32),
		Color = C.White,
		Stroke = 2,
		StrokeColor = Theme.darken(color, 0.35),
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.new(0.5, -size / 2, 0, 6),
		ZIndex = z + 3,
		Parent = holder,
	})
	local badge = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(0.5, -size / 2 - 4, 0, 2),
		ZIndex = z + 4,
		Parent = holder,
	})
	Kit.round(badge)
	Kit.border(badge, C.White, 2)
	Kit.label({
		Text = key,
		Font = Theme.Fonts.Number,
		TextSize = if #key > 1 then 9 else 13,
		Color = C.White,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 5,
		Parent = badge,
	})
	return {
		Holder = holder,
		Fill = fill,
		Face = face,
		Value = value,
		Glow = glow,
		Color = color,
		WasReady = false,
	}
end

local function buildBottom()
	local bar = Kit.box({
		Size = UDim2.fromOffset(700, 150),
		Position = UDim2.new(0.5, 0, 1, -14),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 5,
		Parent = root,
	})
	Kit.list(bar, 14, true, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
	dashRing = ring(bar, 58, C.Success, if isTouch then "D" else "⇧", 1, 6)
	contactRing = ring(bar, 58, C.Danger, if isTouch then "C" else "F", 2, 6)
	Kit.box({ Size = UDim2.fromOffset(10, 10), Order = 3, Parent = bar })
	for slot = 1, 3 do
		local size = if slot == 3 then 96 else 80
		local entry = ring(bar, size, SLOT_COLORS[slot], tostring(slot), 3 + slot, 6)
		entry.Name = Kit.label({
			Text = "",
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.Tiny,
			Color = C.White,
			Stroke = 1.5,
			StrokeColor = C.Ink,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 24, 0, 16),
			Position = UDim2.new(0, -12, 1, -22),
			ZIndex = 9,
			Parent = entry.Holder,
		})
		local hit = Kit.new("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 12,
			Parent = entry.Holder,
		})
		hit.Activated:Connect(function()
			MatchInput.perform(`Power{slot}`)
		end)
		rings[slot] = entry
	end
end

-- Centre : jauge de tir, 3 secondes, viseur ------------------------------------------------------------

local function buildCenter()
	-- Jauge de tir au timing.
	gauge = Kit.box({
		Size = UDim2.fromOffset(440, 64),
		Position = UDim2.new(0.5, 0, 1, -190),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		ZIndex = 10,
		Parent = root,
	})
	local track = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 1, -22),
		ClipsDescendants = true,
		ZIndex = 10,
		Parent = gauge,
	})
	Kit.round(track)
	Kit.border(track, C.Ink, 2.5)
	local function zone(from: number, to: number, color: Color3, z: number)
		local frame = Kit.new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(from, 0),
			Size = UDim2.fromScale(to - from, 1),
			ZIndex = z,
			Parent = track,
		})
		return frame
	end
	zone(ShotTiming.GoodMin, 1, Color3.fromRGB(176, 236, 196), 10)
	local perfect = zone(ShotTiming.PerfectMin, ShotTiming.PerfectMax, C.White, 11)
	Kit.gradient(perfect, Color3.fromRGB(255, 230, 120), C.Gold, 90)
	Kit.tween(
		perfect,
		TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundTransparency = 0.25 }
	)
	gaugeCursor = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(8, 34),
		Position = UDim2.new(0, 0, 1, 6),
		ZIndex = 13,
		Parent = gauge,
	})
	Kit.corner(gaugeCursor, 4)
	Kit.border(gaugeCursor, C.White, 2)
	gradeLabel = Kit.label({
		Text = "",
		Font = Theme.Fonts.Hero,
		TextSize = 34,
		Color = C.Gold,
		Stroke = 3,
		StrokeColor = C.Ink,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(440, 44),
		Position = UDim2.new(0.5, 0, 1, -224),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		ZIndex = 14,
		Parent = root,
	})

	-- Chrono des 3 secondes.
	holdPill = Kit.surface({
		Transparency = 0.04,
		BorderColor = C.White,
		BorderThickness = 2.5,
		Radius = 18,
		Size = UDim2.fromOffset(150, 36),
		Position = UDim2.new(0.5, 0, 0.5, 90),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Clip = true,
		Visible = false,
		ZIndex = 10,
		Parent = root,
	})
	holdFill = Kit.new("Frame", {
		BackgroundColor3 = C.Gold,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = holdPill,
	})
	holdLabel = Kit.label({
		Text = "",
		Font = Theme.Fonts.Number,
		TextSize = Theme.Text.H3,
		Color = C.Text,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 11,
		Parent = holdPill,
	})

	crosshair = Kit.box({
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 5,
		Parent = root,
	})
	local dot = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = crosshair,
	})
	Kit.round(dot)
	Kit.border(dot, C.Ink, 2)
end

local function showGrade(grade: string)
	local look = GRADE_LOOK[grade]
	if not look then
		return
	end
	gradeLabel.Text = look.Text
	gradeLabel.TextColor3 = look.Color
	gradeLabel.Visible = true
	gradeLabel.TextTransparency = 0
	Kit.slam(gradeLabel, if grade == "Perfect" then 1.8 else 1.3)
	local stamp = os.clock()
	task.delay(0.9, function()
		if os.clock() - stamp >= 0.85 then
			gradeLabel.Visible = false
		end
	end)
end

-- Boutons tactiles ---------------------------------------------------------------------------------------

local function buildTouch()
	local layer = Kit.box({
		Size = UDim2.fromOffset(360, 340),
		Position = UDim2.new(1, -24, 1, -24),
		AnchorPoint = Vector2.new(1, 1),
		Visible = isTouch,
		ZIndex = 10,
		Parent = root,
	})
	local function button(
		text: string,
		size: number,
		position: Vector2,
		color: Color3,
		onDown: () -> (),
		onUp: (() -> ())?
	)
		local face = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = C.White,
			Text = text,
			FontFace = Theme.Fonts.Display,
			TextSize = if size > 110 then 26 else 15,
			TextColor3 = C.White,
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromOffset(position.X, position.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 11,
			Parent = layer,
		})
		Kit.round(face)
		Kit.gradient(face, Theme.lighten(color, 0.25), color, 90)
		Kit.border(face, C.White, 3)
		Kit.ink(face, 1.5, Theme.darken(color, 0.35))
		face.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				Kit.pop(face, 0.88)
				onDown()
			end
		end)
		face.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch and onUp then
				onUp()
			end
		end)
	end
	button("TIR", 130, Vector2.new(280, 260), C.Accent, function()
		MatchInput.perform("ShootBegin")
	end, function()
		MatchInput.perform("ShootEnd")
	end)
	button("PASSE", 92, Vector2.new(140, 296), C.Sky, function()
		MatchInput.perform("Pass")
	end)
	button("DASH", 84, Vector2.new(286, 110), C.Success, function()
		MatchInput.perform("Dash")
	end)
	button("CONTRE", 84, Vector2.new(156, 170), C.Danger, function()
		MatchInput.perform("Contact")
	end)
end

-- Étiquettes des joueurs -----------------------------------------------------------------------------

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
	local team = Theme.Team[participant.Team] or Theme.Team.Rouge
	local billboard = Kit.new("BillboardGui", {
		Name = "Etiquette",
		Size = UDim2.fromOffset(200, 34),
		StudsOffset = Vector3.new(0, 2.4, 0),
		MaxDistance = 110,
		AlwaysOnTop = true,
		ResetOnSpawn = false,
		Adornee = head,
		Parent = LocalPlayer:WaitForChild("PlayerGui"),
	})
	local pill = Kit.new("Frame", {
		BackgroundColor3 = team.Main,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = billboard,
	})
	Kit.round(pill)
	Kit.border(pill, C.White, 2)
	Kit.label({
		Name = "Nom",
		Text = "",
		Font = Theme.Fonts.Display,
		TextSize = 14,
		Color = C.White,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(0, 26),
		AutoSize = Enum.AutomaticSize.X,
		ZIndex = 2,
		Parent = pill,
	})
	Kit.padding(pill, 10, 0)
	plates[model] = billboard
	return billboard
end

local function updatePlates(match: any)
	local seen: { [Model]: boolean } = {}
	for _, participant in match.Participants do
		local plate = plateFor(participant)
		if plate and participant.Model then
			seen[participant.Model] = true
			plate.Enabled = participant.UserId ~= LocalPlayer.UserId
			local pill = plate:FindFirstChildOfClass("Frame")
			local name = pill and pill:FindFirstChild("Nom") :: TextLabel?
			if name then
				name.Text = `{participant.Number}  {participant.Name}`
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

local function setScore(team: string, value: number)
	if lastScore[team] ~= value then
		local label = scoreLabels[team]
		if lastScore[team] >= 0 then
			Kit.slam(label, 1.7)
		end
		lastScore[team] = value
		label.Text = tostring(value)
	end
end

local function setRing(entry: Ring, ratio: number, ready: boolean, text: string)
	entry.Fill.Size = UDim2.fromScale(1, math.clamp(ratio, 0, 1))
	entry.Fill.BackgroundTransparency = if ready then 0 else 0.35
	entry.Value.Text = text
	entry.Glow.Visible = ready
	if ready and not entry.WasReady then
		Kit.pop(entry.Holder, 0.8)
	end
	entry.WasReady = ready
end

local function currentPhase(): number?
	local start = LocalPlayer:GetAttribute("ShotChargeStart")
	if typeof(start) == "number" then
		return ShotTiming.phase(Workspace:GetServerTimeNow() - start)
	end
	local charge = (MatchInput :: any).Charge
	return if typeof(charge) == "number" then charge else nil
end

local function update()
	local match = State.Match
	local me = State.me()
	local visible = match ~= nil
		and match.Phase ~= "Ended"
		and me ~= nil
		and State.Setup ~= nil
		and State.Setup.Closed == true
	gui.Enabled = visible
	if not visible or not match or not me then
		return
	end
	local now = Workspace:GetServerTimeNow()
	setScore("Rouge", match.Score.Rouge)
	setScore("Bleu", match.Score.Bleu)
	local clock = match.Clock
	if match.ClockRunning then
		clock = math.max(0, clock - (now - match.ServerTime))
	end
	clockLabel.Text = Format.clock(clock)
	clockLabel.TextColor3 = if match.ClockRunning and clock <= 10 then C.Danger else C.Text
	periodLabel.Text = if match.Half == 3 then "BUT EN OR" elseif match.Half == 2 then "2E MI-TEMPS" else "1RE MI-TEMPS"
	possessionDots.Rouge.Visible = match.Possession == "Rouge"
	possessionDots.Bleu.Visible = match.Possession == "Bleu"

	-- Pouvoirs.
	local archetype = Archetypes.get(me.Archetype)
	if archetype and lastArchetype ~= me.Archetype then
		lastArchetype = me.Archetype
		for slot, entry in rings do
			local power = archetype.Powers[slot]
			if entry.Name and power then
				entry.Name.Text = string.upper(power.Name)
			end
		end
	end
	local p1Left = math.max(0, (me.Power1ReadyAt or 0) - now)
	setRing(
		rings[1],
		1 - p1Left / Config.Powers.Power1Cooldown,
		p1Left <= 0,
		if p1Left > 0 then `{math.ceil(p1Left)}` else ""
	)
	local energy = me.Energy or 0
	setRing(
		rings[2],
		energy / Config.Powers.EnergyMax,
		energy >= Config.Powers.EnergyMax,
		if energy >= Config.Powers.EnergyMax then "" else `{math.floor(energy)}%`
	)
	local ultimate = me.Ultimate or 0
	local ultimateReady = ultimate >= Config.Powers.UltimateMax
	setRing(
		rings[3],
		ultimate / Config.Powers.UltimateMax,
		ultimateReady,
		if ultimateReady then "" else `{math.floor(ultimate)}%`
	)
	if ultimateReady then
		rings[3].Face.Rotation = math.sin(os.clock() * 12) * 4
	else
		rings[3].Face.Rotation = 0
	end

	-- Dash et contact.
	local dashReadyAt = me.NextDashAt
	local dashLeft = if typeof(dashReadyAt) == "number"
		then dashReadyAt - now
		else ((MatchInput :: any).DashReadyAt or 0) - os.clock()
	setRing(
		dashRing,
		1 - math.max(0, dashLeft) / Config.Movement.DashCooldown,
		dashLeft <= 0,
		if dashLeft > 0 then string.format("%.1f", dashLeft) else ""
	)
	local contactLeft = (me.NextContactAt or 0) - now
	setRing(
		contactRing,
		1 - math.max(0, contactLeft) / Config.Contact.Cooldown,
		contactLeft <= 0,
		if contactLeft > 0 then string.format("%.1f", contactLeft) else ""
	)
	dashRing.Glow.Visible = false
	contactRing.Glow.Visible = false

	-- Ballon en main : 3 secondes.
	local ball = State.Ball
	local holding = MatchInput.isHolding()
	holdPill.Visible = holding
	if holding and ball then
		if ball.Locked then
			holdLabel.Text = "ATTENDS LE SIFFLET"
			holdLabel.TextSize = Theme.Text.Tiny
			holdFill.Size = UDim2.fromScale(1, 1)
			holdFill.BackgroundColor3 = C.Surface3
			holdPill.Size = UDim2.fromOffset(190, 36)
		else
			local left = math.max(0, Config.Rules.MaxHoldTime - (now - (ball.HoldStart or now)))
			local color = if left < 1 then C.Danger elseif left < 2 then C.Accent else C.Gold
			holdLabel.Text = string.format("%.1f s", left)
			holdLabel.TextSize = Theme.Text.H3
			holdFill.Size = UDim2.fromScale(left / Config.Rules.MaxHoldTime, 1)
			holdFill.BackgroundColor3 = color
			holdPill.Size = UDim2.fromOffset(150, 36)
			holdPill.Position = if left < 1
				then UDim2.new(0.5, math.random(-2, 2), 0.5, 90 + math.random(-1, 1))
				else UDim2.new(0.5, 0, 0.5, 90)
		end
	end

	-- Jauge de tir.
	local phase = currentPhase()
	gauge.Visible = phase ~= nil
	if phase then
		gaugeCursor.Position = UDim2.new(phase, 0, 1, 6)
		local grade = ShotTiming.grade(phase)
		gaugeCursor.BackgroundColor3 = if grade == "Perfect" then C.Gold else C.Ink
	end
	crosshair.Visible = holding or isTouch
	updatePlates(match)
end

function MatchHUD.start()
	gui, root = Kit.screen("HUD", 20, LocalPlayer:WaitForChild("PlayerGui"))
	gui.Enabled = false
	buildScoreboard()
	buildBottom()
	buildCenter()
	buildTouch()
	RunService.RenderStepped:Connect(update)
	local graded = (MatchInput :: any).ShotGraded
	local usesSignal = graded ~= nil
	if usesSignal then
		graded:Connect(showGrade)
	end
	State.MatchEvent:Connect(function(kind, data)
		if kind == "ShotGrade" and not usesSignal and data and data.UserId == LocalPlayer.UserId then
			showGrade(data.Grade)
		elseif kind == "Leave" then
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
