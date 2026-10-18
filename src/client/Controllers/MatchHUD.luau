--!strict
-- HUD du match : score et temps, pouvoirs, recharges, chrono des 3 secondes,
-- jauge de tir, viseur, boutons tactiles, étiquettes des joueurs.

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

type Slot = {
	Frame: Frame,
	Fill: Frame,
	Name: TextLabel,
	Value: TextLabel,
	Stroke: UIStroke,
	Scale: UIScale,
	WasReady: boolean,
}
type Chip = { Fill: Frame, Value: TextLabel }

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
local crosshair: Frame
local touchLayer: Frame
local plates: { [Model]: BillboardGui } = {}
local lastArchetype: string? = nil

local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Tableau de score ------------------------------------------------------------------------------

local function buildScoreboard()
	local board = Kit.surface({
		Color = C.Surface,
		Size = UDim2.fromOffset(420, 60),
		Position = UDim2.new(0.5, 0, 0, 20),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 5,
		Parent = root,
	})
	local function team(teamId: string, x: number, anchor: number): (TextLabel, Frame)
		local block = Kit.box({
			Size = UDim2.fromOffset(140, 60),
			Position = UDim2.new(x, 0, 0, 0),
			AnchorPoint = Vector2.new(anchor, 0),
			ZIndex = 6,
			Parent = board,
		})
		Kit.new("Frame", {
			BackgroundColor3 = Theme.Team[teamId].Main,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(4, 32),
			Position = UDim2.new(if anchor == 0 then 0 else 1, if anchor == 0 then 16 else -20, 0.5, -16),
			ZIndex = 7,
			Parent = block,
		})
		Kit.label({
			Text = Theme.Team[teamId].Name,
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.Small,
			Color = C.TextMuted,
			AlignX = if anchor == 0 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -40, 1, 0),
			Position = UDim2.fromOffset(if anchor == 0 then 30 else 10, 0),
			ZIndex = 7,
			Parent = block,
		})
		local score = Kit.label({
			Text = "0",
			Font = Theme.Fonts.Display,
			TextSize = 34,
			AlignX = if anchor == 0 then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -24, 1, 0),
			Position = UDim2.fromOffset(if anchor == 0 then 0 else 24, 0),
			ZIndex = 7,
			Parent = block,
		})
		local possession = Kit.new("Frame", {
			BackgroundColor3 = Theme.Team[teamId].Main,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -32, 0, 2),
			Position = UDim2.new(0, 16, 1, -2),
			Visible = false,
			ZIndex = 7,
			Parent = block,
		})
		return score, possession
	end
	scoreRouge, possessionRouge = team("Rouge", 0, 0)
	scoreBleu, possessionBleu = team("Bleu", 1, 1)
	local center = Kit.new("Frame", {
		BackgroundColor3 = C.Surface2,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(140, 60),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 6,
		Parent = board,
	})
	clockLabel = Kit.label({
		Text = "0:00",
		Font = Theme.Fonts.Display,
		TextSize = 26,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 4),
		ZIndex = 7,
		Parent = center,
	})
	periodLabel = Kit.label({
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = C.TextMuted,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 38),
		ZIndex = 7,
		Parent = center,
	})
	passive = Kit.surface({
		Color = C.Warning,
		Border = false,
		Size = UDim2.fromOffset(140, 26),
		Position = UDim2.new(0.5, 0, 0, 88),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	Kit.label({
		Text = "JEU PASSIF",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = C.TextOnAccent,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = passive,
	})
end

-- Pouvoirs et recharges -----------------------------------------------------------------------------

local function buildAbilities()
	local bar = Kit.box({
		Size = UDim2.fromOffset(560, 100),
		Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 5,
		Parent = root,
	})
	Kit.list(bar, 10, true, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)

	local function chip(key: string, order: number): Chip
		local frame = Kit.surface({
			Color = C.Surface,
			Size = UDim2.fromOffset(64, 64),
			Clip = true,
			Order = order,
			ZIndex = 6,
			Parent = bar,
		})
		local fill = Kit.new("Frame", {
			BackgroundColor3 = C.Surface3,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			ZIndex = 6,
			Parent = frame,
		})
		Kit.label({
			Text = key,
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.Tiny,
			Color = C.TextMuted,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.fromOffset(0, 8),
			ZIndex = 7,
			Parent = frame,
		})
		local value = Kit.label({
			Text = "",
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H3,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.fromOffset(0, 26),
			ZIndex = 7,
			Parent = frame,
		})
		return { Fill = fill, Value = value }
	end
	dashChip = chip(if isTouch then "DASH" else "SHIFT", 1)
	contactChip = chip(if isTouch then "CONTRE" else "F", 2)
	Kit.box({ Size = UDim2.fromOffset(10, 10), Order = 3, Parent = bar })

	for slot = 1, 3 do
		local frame = Kit.surface({
			Color = C.Surface,
			Size = UDim2.fromOffset(if slot == 3 then 112 else 96, if slot == 3 then 100 else 88),
			Clip = true,
			Order = 3 + slot,
			ZIndex = 6,
			Parent = bar,
		})
		local fill = Kit.new("Frame", {
			BackgroundColor3 = C.Surface3,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			ZIndex = 6,
			Parent = frame,
		})
		local key = Kit.new("Frame", {
			BackgroundColor3 = C.Surface3,
			Size = UDim2.fromOffset(22, 22),
			Position = UDim2.fromOffset(8, 8),
			ZIndex = 8,
			Parent = frame,
		})
		Kit.corner(key, 4)
		Kit.label({
			Text = tostring(slot),
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.Tiny,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 9,
			Parent = key,
		})
		local value = Kit.label({
			Text = "",
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H3,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.new(0, 0, 0.5, -14),
			ZIndex = 8,
			Parent = frame,
		})
		local name = Kit.label({
			Text = "",
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.Tiny,
			Color = C.TextMuted,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -12, 0, 16),
			Position = UDim2.new(0, 6, 1, -22),
			ZIndex = 8,
			Parent = frame,
		})
		local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
		local scale = Kit.new("UIScale", { Parent = frame })
		local hit = Kit.new(
			"TextButton",
			{ BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 12, Parent = frame }
		)
		hit.Activated:Connect(function()
			MatchInput.perform(`Power{slot}`)
		end)
		slots[slot] =
			{ Frame = frame, Fill = fill, Name = name, Value = value, Stroke = stroke, Scale = scale, WasReady = false }
	end
end

-- Centre : viseur, ballon en main, tir ------------------------------------------------------------

local function buildCenter()
	crosshair = Kit.box({
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 5,
		Parent = root,
	})
	local dot = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		Size = UDim2.fromOffset(4, 4),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 6,
		Parent = crosshair,
	})
	Kit.corner(dot, 2)
	for _, offset in { Vector2.new(-10, 0), Vector2.new(10, 0), Vector2.new(0, -10), Vector2.new(0, 10) } do
		Kit.new("Frame", {
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			Size = if offset.X ~= 0 then UDim2.fromOffset(6, 2) else UDim2.fromOffset(2, 6),
			Position = UDim2.new(0.5, offset.X, 0.5, offset.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 6,
			Parent = crosshair,
		})
	end
	holdBar = Kit.box({
		Size = UDim2.fromOffset(200, 34),
		Position = UDim2.new(0.5, 0, 0.5, 60),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	holdLabel = Kit.label({
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Small,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 20),
		ZIndex = 6,
		Parent = holdBar,
	})
	local track = Kit.new("Frame", {
		BackgroundColor3 = C.Surface3,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.fromOffset(0, 26),
		ZIndex = 6,
		Parent = holdBar,
	})
	Kit.corner(track, 2)
	holdFill = Kit.new(
		"Frame",
		{ BackgroundColor3 = C.Success, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = track }
	)
	Kit.corner(holdFill, 2)
	chargeBar = Kit.new("Frame", {
		BackgroundColor3 = C.Surface3,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(4, 90),
		Position = UDim2.new(0.5, 40, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	Kit.corner(chargeBar, 2)
	chargeFill = Kit.new("Frame", {
		BackgroundColor3 = C.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		ZIndex = 6,
		Parent = chargeBar,
	})
	Kit.corner(chargeFill, 2)
end

-- Boutons tactiles -------------------------------------------------------------------------------------

local function buildTouch()
	touchLayer = Kit.box({
		Size = UDim2.fromOffset(380, 360),
		Position = UDim2.new(1, -24, 1, -140),
		AnchorPoint = Vector2.new(1, 1),
		Visible = isTouch,
		ZIndex = 10,
		Parent = root,
	})
	local function round(
		text: string,
		size: number,
		position: Vector2,
		primary: boolean,
		onDown: () -> (),
		onUp: (() -> ())?
	)
		local button = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = if primary then C.Accent else C.Surface2,
			Text = text,
			FontFace = Theme.Fonts.Bold,
			TextSize = Theme.Text.Small,
			TextColor3 = if primary then C.TextOnAccent else C.Text,
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromOffset(position.X, position.Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 11,
			Parent = touchLayer,
		})
		Kit.corner(button, size)
		Kit.border(button, if primary then C.Accent else C.BorderStrong)
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				Kit.pop(button, 0.92)
				onDown()
			end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch and onUp then
				onUp()
			end
		end)
	end
	round("TIR", 136, Vector2.new(300, 280), true, function()
		MatchInput.perform("ShootBegin")
	end, function()
		MatchInput.perform("ShootEnd")
	end)
	round("PASSE", 96, Vector2.new(160, 312), false, function()
		MatchInput.perform("Pass")
	end)
	round("DASH", 88, Vector2.new(300, 128), false, function()
		MatchInput.perform("Dash")
	end)
	round("CONTRE", 84, Vector2.new(176, 186), false, function()
		MatchInput.perform("Contact")
	end)
	round("DRIBBLE", 76, Vector2.new(60, 272), false, function()
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
		Size = UDim2.fromOffset(180, 44),
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
		Font = Theme.Fonts.Bold,
		TextSize = 15,
		Color = C.White,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 20),
		ZIndex = 2,
		Parent = billboard,
	})
	Kit.new("Frame", {
		Name = "Equipe",
		BackgroundColor3 = Theme.Team[participant.Team].Main,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(28, 3),
		Position = UDim2.new(0.5, -14, 0, 21),
		ZIndex = 2,
		Parent = billboard,
	})
	Kit.label({
		Name = "Statut",
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = 12,
		Color = C.Warning,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 26),
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

local function setFill(fill: Frame, ratio: number)
	fill.Size = UDim2.fromScale(1, 1 - math.clamp(ratio, 0, 1))
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
	scoreRouge.Text = tostring(match.Score.Rouge)
	scoreBleu.Text = tostring(match.Score.Bleu)
	local clock = match.Clock
	if match.ClockRunning then
		clock = math.max(0, clock - (now - match.ServerTime))
	end
	clockLabel.Text = Format.clock(clock)
	periodLabel.Text = if match.Half == 3 then "BUT EN OR" elseif match.Half == 2 then "2E MI-TEMPS" else "1RE MI-TEMPS"
	possessionRouge.Visible = match.Possession == "Rouge"
	possessionBleu.Visible = match.Possession == "Bleu"
	passive.Visible = match.PassiveWarning == true

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
			local power = archetype.Powers[index]
			setFill(slot.Fill, state.Ratio)
			slot.Fill.BackgroundColor3 = C.Surface3
			slot.Frame.BackgroundColor3 = if state.Ready then Theme.darken(power.Color, 0.45) else C.Surface
			slot.Value.Text = state.Text
			slot.Stroke.Color = if state.Ready then power.Color else C.Border
			slot.Stroke.Thickness = if state.Ready then 2 else 1
			slot.Name.TextColor3 = if state.Ready then C.Text else C.TextMuted
			if state.Ready and not slot.WasReady then
				Kit.pop(slot.Frame, 1.12)
			end
			slot.WasReady = state.Ready
		end
	end
	local dashLeft = MatchInput.DashReadyAt - os.clock()
	setFill(dashChip.Fill, 1 - math.max(0, dashLeft) / Config.Movement.DashCooldown)
	dashChip.Value.Text = if dashLeft > 0 then string.format("%.1f", dashLeft) else ""
	local contactLeft = (me.NextContactAt or 0) - now
	setFill(contactChip.Fill, 1 - math.max(0, contactLeft) / Config.Contact.Cooldown)
	contactChip.Value.Text = if contactLeft > 0 then string.format("%.1f", contactLeft) else ""

	local ball = State.Ball
	local holding = MatchInput.isHolding()
	holdBar.Visible = holding
	if holding and ball then
		if ball.Locked then
			holdLabel.Text = "Attends le coup de sifflet"
			holdFill.Size = UDim2.fromScale(1, 1)
			holdFill.BackgroundColor3 = C.TextMuted
		elseif ball.Dribbling then
			holdLabel.Text = "Dribble  ·  R pour reprendre la balle"
			holdFill.Size = UDim2.fromScale(1, 1)
			holdFill.BackgroundColor3 = C.Info
		else
			local left = math.max(0, Config.Rules.MaxHoldTime - (now - ball.HoldStart))
			holdLabel.Text = string.format("%.1f s", left)
			holdFill.Size = UDim2.fromScale(left / Config.Rules.MaxHoldTime, 1)
			holdFill.BackgroundColor3 = if left < 1 then C.Danger elseif left < 2 then C.Warning else C.Success
		end
	end
	local charge = MatchInput.Charge
	chargeBar.Visible = charge ~= nil
	if charge then
		chargeFill.Size = UDim2.fromScale(1, charge)
		chargeFill.BackgroundColor3 = if charge >= 1 then C.Danger else C.Accent
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
		end
	end)
end

return MatchHUD
