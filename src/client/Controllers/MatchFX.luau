--!strict
-- Interface d'événements du match : GOAL, fil d'actions, coups de sifflet,
-- présentation, compte à rebours, ultimes, mi-temps, écran de fin.
-- Les effets 3D (particules, caméra) sont dans Effects3D.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local LocalPlayer = Players.LocalPlayer

local MatchFX = {}

local root: Frame
local feed: Frame
local bannerSlot: Frame
local feedOrder = 0

local function teamColor(team: string?): Color3
	local info = team and Theme.Team[team]
	return if info then info.Main else C.TextMuted
end

local function nameOf(model: Model?): string
	if not model then
		return "?"
	end
	local match = State.Match
	if match then
		for _, participant in match.Participants do
			if participant.Model == model then
				return participant.Name
			end
		end
	end
	return model.Name
end

-- Fil d'actions (haut droite) ----------------------------------------------------------------------

local function pushFeed(text: string, team: string?)
	feedOrder += 1
	local color = teamColor(team)
	local row = Kit.new("Frame", {
		BackgroundColor3 = C.Surface,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = Theme.Tilt / 2,
		LayoutOrder = -feedOrder,
		ZIndex = 20,
		Parent = feed,
	})
	Kit.corner(row, 4)
	Kit.border(row, C.Ink, 2.5)
	Kit.shade(row, 0.2)
	Kit.new("UIPadding", { PaddingRight = UDim.new(0, 14), Parent = row })
	local inner =
		Kit.box({ Size = UDim2.fromOffset(0, 34), AutoSize = Enum.AutomaticSize.X, ZIndex = 20, Parent = row })
	Kit.list(inner, 10, true, nil, Enum.VerticalAlignment.Center)
	-- Talon de la couleur de l'équipe.
	local heel = Kit.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(12, 34),
		LayoutOrder = 1,
		ZIndex = 21,
		Parent = inner,
	})
	Kit.corner(heel, 4)
	Kit.label({
		Text = text,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Small + 1,
		Color = C.White,
		Size = UDim2.fromOffset(0, 34),
		AutoSize = Enum.AutomaticSize.X,
		Order = 2,
		ZIndex = 21,
		Parent = inner,
	})
	Kit.reveal(row, 0, -40)
	task.delay(5, function()
		if row.Parent then
			Kit.tween(row, Theme.Motion.Base, { BackgroundTransparency = 1 })
			for _, child in row:GetDescendants() do
				if child:IsA("TextLabel") then
					Kit.tween(child, Theme.Motion.Base, { TextTransparency = 1 })
				elseif child:IsA("Frame") then
					Kit.tween(child, Theme.Motion.Base, { BackgroundTransparency = 1 })
				elseif child:IsA("UIStroke") then
					Kit.tween(child, Theme.Motion.Base, { Transparency = 1 })
				end
			end
			task.wait(0.2)
			row:Destroy()
		end
	end)
	local rows = {}
	for _, child in feed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(rows, child)
		end
	end
	if #rows > 5 then
		table.sort(rows, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		rows[1]:Destroy()
	end
end

-- Bandeau d'arbitrage (sifflet, jets, cartons) : plaque inclinée colorée -------------------------

local function banner(title: string, detail: string?, accent: Color3, duration: number)
	Kit.clear(bannerSlot)
	local holder = Kit.box({
		Size = UDim2.fromOffset(640, 96),
		Position = UDim2.fromScale(-1, 0),
		ZIndex = 30,
		Parent = bannerSlot,
	})
	local plate = Kit.plate({
		Color = accent,
		Size = UDim2.fromOffset(560, 56),
		Position = UDim2.fromOffset(40, 0),
		BorderThickness = 3,
		ZIndex = 31,
		Parent = holder,
	})
	Kit.speedLines({ Parent = plate, Color = C.White, Count = 8, Transparency = 0.7, ZIndex = 31 })
	Kit.label({
		Text = string.upper(title),
		Font = Theme.Fonts.Hero,
		TextSize = 40,
		Color = Theme.onColor(accent),
		Stroke = if Theme.onColor(accent) == C.White then 2.5 else nil,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 33,
		Parent = plate,
	})
	if detail and detail ~= "" then
		local strip = Kit.plate({
			Color = C.Ink,
			Gradient = false,
			Size = UDim2.fromOffset(460, 30),
			Position = UDim2.fromOffset(90, 58),
			BorderColor = accent,
			BorderThickness = 2,
			Shadow = false,
			ZIndex = 32,
			Parent = holder,
		})
		Kit.label({
			Text = detail,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.Body,
			Color = C.White,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 33,
			Parent = strip,
		})
	end
	Kit.tween(holder, Theme.Motion.Slam, { Position = UDim2.new(0.5, -320, 0, 0) })
	task.delay(duration, function()
		if holder.Parent then
			Kit.tween(
				holder,
				TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
				{ Position = UDim2.fromScale(1.5, 0) }
			)
			task.wait(0.22)
			holder:Destroy()
		end
	end)
end

-- Flash blanc plein écran.
local function flash(duration: number, color: Color3?)
	local frame = Kit.new("Frame", {
		BackgroundColor3 = color or C.White,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 95,
		Parent = root,
	})
	Kit.tween(frame, TweenInfo.new(duration, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	task.delay(duration + 0.05, function()
		frame:Destroy()
	end)
end

-- GOAL ---------------------------------------------------------------------------------------------------

local function goal(data: any)
	Kit.playSound(Theme.Sounds.Goal, 1)
	local color = teamColor(data.Team)
	local life = Config.Match.GoalCelebrationTime - 0.6
	flash(0.35)

	-- Bandes diagonales qui traversent l'écran.
	local bands = Kit.box({ ZIndex = 58, Parent = root })
	local function band(height: number, y: number, bandColor: Color3, delay: number, transparency: number?): Frame
		local frame = Kit.new("Frame", {
			BackgroundColor3 = bandColor,
			BackgroundTransparency = transparency or 0,
			BorderSizePixel = 0,
			Size = UDim2.new(1.8, 0, 0, height),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(-1.2, y),
			Rotation = -8,
			ZIndex = 58,
			Parent = bands,
		})
		task.delay(delay, function()
			Kit.tween(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quint), { Position = UDim2.fromScale(0.5, y) })
		end)
		return frame
	end
	local main = band(250, 0.43, color, 0)
	Kit.gradient(main, Theme.lighten(color, 0.2), Theme.darken(color, 0.25), 90)
	Kit.halftone({
		Parent = main,
		Color = C.White,
		Columns = 30,
		Rows = 8,
		Spacing = 30,
		Transparency = 0.85,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 58,
	})
	band(26, 0.43 - 0.19, C.Ink, 0.05)
	band(12, 0.43 + 0.19, C.White, 0.08)
	band(60, 0.43 + 0.26, C.Accent, 0.12, 0.15)

	local lines = Kit.speedLines({
		Parent = root,
		Color = C.White,
		Count = 36,
		Transparency = 0.35,
		Speed = 0.4,
		Angle = -8,
		ZIndex = 59,
	})

	local word = Kit.title({
		Text = "GOAL",
		Font = Theme.Fonts.Hero,
		TextSize = 220,
		Color = C.White,
		ShadowColor = Theme.darken(color, 0.15),
		Stroke = 7,
		Offset = 14,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(1200, 260),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -6,
		ZIndex = 62,
		Parent = root,
	})
	Kit.slam(word.Instance, 2.8)
	task.delay(0.2, function()
		Kit.shake(word.Instance, 12, 0.35)
	end)

	task.delay(life, function()
		local out = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		Kit.tween(word.Instance, out, { Position = UDim2.fromScale(1.8, 0.42) })
		for _, child in bands:GetChildren() do
			if child:IsA("Frame") then
				Kit.tween(child, out, { Position = UDim2.fromScale(2.2, child.Position.Y.Scale) })
			end
		end
		task.wait(0.32)
		word.Instance:Destroy()
		bands:Destroy()
		lines:Destroy()
	end)
	pushFeed(
		if data.OwnGoal then "But contre son camp" elseif data.Scorer then `But de {data.Scorer}` else "But",
		data.Team
	)
end

-- Ultime : coupure façon animé (bandes noires, nom du pouvoir, lignes de vitesse) ------------------

local function ultimate(data: any)
	local archetype = Archetypes.get(data.ArchetypeId)
	local power = archetype and archetype.Powers[data.Slot]
	if not archetype or not power then
		return
	end
	if data.Slot < 3 then
		if data.Team then
			pushFeed(`{data.Name} · {power.Name}`, data.Team)
		end
		return
	end
	Kit.playSound(Theme.Sounds.Power, 0.8)
	flash(0.2, power.Color)
	local layer = Kit.box({ ZIndex = 55, Parent = root })
	-- Bandes noires de cinéma.
	local top = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.13, 0),
		Position = UDim2.fromScale(0, -0.13),
		ZIndex = 55,
		Parent = layer,
	})
	local bottom = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.13, 0),
		Position = UDim2.fromScale(0, 1),
		ZIndex = 55,
		Parent = layer,
	})
	Kit.tween(top, Theme.Motion.Base, { Position = UDim2.fromScale(0, 0) })
	Kit.tween(bottom, Theme.Motion.Base, { Position = UDim2.fromScale(0, 0.87) })
	local lines = Kit.speedLines({
		Parent = layer,
		Color = power.Color,
		Count = 30,
		Transparency = 0.45,
		Speed = 0.35,
		Reverse = true,
		ZIndex = 55,
	})
	local band = Kit.new("Frame", {
		BackgroundColor3 = power.Color,
		BorderSizePixel = 0,
		Size = UDim2.new(1.4, 0, 0, 170),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-1, 0.6),
		Rotation = -4,
		ZIndex = 56,
		Parent = layer,
	})
	Kit.gradient(band, Theme.lighten(power.Color, 0.15), Theme.darken(power.Color, 0.55), 90)
	Kit.border(band, C.Ink, 4)
	Kit.halftone({
		Parent = band,
		Color = C.White,
		Columns = 30,
		Rows = 6,
		Spacing = 28,
		Transparency = 0.85,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 56,
	})
	local tag = Kit.plate({
		Color = C.Ink,
		Gradient = false,
		BorderColor = power.Color,
		Shadow = false,
		Rotation = 0,
		Size = UDim2.fromOffset(620, 30),
		Position = UDim2.new(0.5, -440, 0, 18),
		ZIndex = 57,
		Parent = band,
	})
	Kit.label({
		Text = `ULTIME  ·  {string.upper(data.Name)}  ·  {string.upper(archetype.Name)}`,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Body,
		Color = Theme.lighten(power.Color, 0.35),
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		ZIndex = 58,
		Parent = tag,
	})
	local name = Kit.title({
		Text = string.upper(power.Name),
		Font = Theme.Fonts.Hero,
		TextSize = 96,
		Color = C.White,
		ShadowColor = Theme.darken(power.Color, 0.6),
		Stroke = 4,
		Offset = 7,
		Size = UDim2.new(1, -200, 0, 110),
		Position = UDim2.new(0.5, -440, 0, 52),
		ZIndex = 58,
		Parent = band,
	})
	Kit.tween(band, TweenInfo.new(0.24, Enum.EasingStyle.Quint), { Position = UDim2.fromScale(0.5, 0.6) })
	task.delay(0.12, function()
		Kit.slam(name.Instance, 1.6)
	end)
	task.delay(1.5, function()
		local out = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		Kit.tween(band, out, { Position = UDim2.fromScale(2, 0.6) })
		Kit.tween(top, out, { Position = UDim2.fromScale(0, -0.13) })
		Kit.tween(bottom, out, { Position = UDim2.fromScale(0, 1) })
		task.wait(0.28)
		lines:Destroy()
		layer:Destroy()
	end)
	pushFeed(`{data.Name} · {power.Name}`, data.Team)
end

-- Effets plein écran ------------------------------------------------------------------------------------

local function blind(duration: number)
	local frame = Kit.new(
		"Frame",
		{ BackgroundColor3 = C.Black, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 80, Parent = root }
	)
	task.delay(math.max(0, duration - 0.5), function()
		Kit.tween(frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		task.wait(0.5)
		frame:Destroy()
	end)
end

local function timeStop(duration: number)
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "ArretDuTemps"
	correction.Saturation = -1
	correction.Contrast = 0.2
	correction.Parent = Lighting
	task.delay(duration, function()
		correction:Destroy()
	end)
end

local COUNT_COLORS = { C.Accent, C.Pink, C.Cyan, C.Lime, C.Violet }

local function countdown(seconds: number)
	task.spawn(function()
		for i = seconds, 1, -1 do
			local color = COUNT_COLORS[((i - 1) % #COUNT_COLORS) + 1]
			local number = Kit.title({
				Text = tostring(i),
				Font = Theme.Fonts.Hero,
				TextSize = 200,
				Color = C.White,
				ShadowColor = color,
				Stroke = 6,
				Offset = 10,
				AlignX = Enum.TextXAlignment.Center,
				Size = UDim2.fromOffset(320, 220),
				Position = UDim2.fromScale(0.5, 0.4),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = if i % 2 == 0 then 6 else -6,
				ZIndex = 60,
				Parent = root,
			})
			Kit.slam(number.Instance, 2.6)
			Kit.shake(number.Instance, 6, 0.15)
			task.wait(0.9)
			number.Instance:Destroy()
		end
		local lines = Kit.speedLines({
			Parent = root,
			Color = C.Accent,
			Count = 30,
			Transparency = 0.4,
			Speed = 0.35,
			ZIndex = 59,
		})
		local go = Kit.title({
			Text = "GO !",
			Font = Theme.Fonts.Hero,
			TextSize = 210,
			Color = C.Accent,
			ShadowColor = C.Pink,
			Stroke = 7,
			Offset = 12,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(700, 230),
			Position = UDim2.fromScale(0.5, 0.4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = -6,
			ZIndex = 60,
			Parent = root,
		})
		Kit.slam(go.Instance, 3)
		Kit.shake(go.Instance, 10, 0.25)
		task.wait(0.8)
		Kit.tween(
			go.Instance,
			TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
			{ Position = UDim2.fromScale(1.8, 0.4) }
		)
		task.wait(0.22)
		go.Instance:Destroy()
		lines:Destroy()
	end)
end

-- Présentation des équipes : deux panneaux rouge et bleu qui glissent l'un vers l'autre ------------

local function intro(data: any)
	local match = State.Match
	if not match then
		return
	end
	local overlay = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = 70,
		Parent = root,
	})
	local movers: { { Object: GuiObject, From: UDim2, To: UDim2 } } = {}
	for index, team in { "Rouge", "Bleu" } do
		local info = Theme.Team[team]
		local left = index == 1
		local panel = Kit.new("Frame", {
			BackgroundColor3 = info.Main,
			BorderSizePixel = 0,
			Size = UDim2.new(0.62, 0, 1.6, 0),
			AnchorPoint = Vector2.new(if left then 1 else 0, 0.5),
			Rotation = 10,
			ZIndex = 70,
			Parent = overlay,
		})
		Kit.gradient(panel, Theme.lighten(info.Main, 0.1), info.Dark, if left then 0 else 180)
		Kit.border(panel, C.Ink, 8)
		local to = UDim2.fromScale(if left then 0.53 else 0.47, 0.5)
		local from = UDim2.fromScale(if left then -0.2 else 1.2, 0.5)
		panel.Position = from
		table.insert(movers, { Object = panel, From = from, To = to })

		local column = Kit.box({
			Size = UDim2.fromOffset(500, 520),
			AnchorPoint = Vector2.new(if left then 1 else 0, 0.5),
			ZIndex = 72,
			Parent = overlay,
		})
		local columnTo = UDim2.new(0.5, if left then -110 else 110, 0.5, 30)
		local columnFrom = columnTo + UDim2.fromScale(if left then -0.8 else 0.8, 0)
		column.Position = columnFrom
		table.insert(movers, { Object = column :: GuiObject, From = columnFrom, To = columnTo })
		local align = if left then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
		Kit.title({
			Text = `ÉQUIPE {info.Name}`,
			Font = Theme.Fonts.Hero,
			TextSize = 64,
			Color = C.White,
			ShadowColor = C.Ink,
			Stroke = 3,
			Offset = 5,
			AlignX = align,
			Size = UDim2.new(1, 0, 0, 74),
			Rotation = Theme.Tilt,
			ZIndex = 73,
			Parent = column,
		})
		local list = Kit.box({
			Size = UDim2.new(1, 0, 1, -96),
			Position = UDim2.fromOffset(0, 96),
			ZIndex = 73,
			Parent = column,
		})
		Kit.list(list, 10, false, if left then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left)
		local order = 0
		for _, participant in match.Participants do
			if participant.Team == team then
				order += 1
				local archetype = Archetypes.get(participant.Archetype)
				local row = Kit.new("Frame", {
					BackgroundColor3 = C.Ink,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(400, 44),
					Rotation = Theme.Tilt,
					LayoutOrder = order,
					ZIndex = 74,
					Parent = list,
				})
				Kit.corner(row, 4)
				Kit.border(row, C.White, 2)
				Kit.label({
					Text = `<b>{participant.Name}</b>   <font color="#{(if archetype
						then Theme.rarityColor(archetype.Rarity)
						else C.TextMuted):ToHex()}">{if archetype then string.upper(archetype.Name) else ""}</font>`,
					Rich = true,
					Font = Theme.Fonts.Display,
					TextSize = Theme.Text.H3,
					Color = C.White,
					AlignX = align,
					Size = UDim2.new(1, -32, 1, 0),
					Position = UDim2.fromOffset(16, 0),
					ZIndex = 75,
					Parent = row,
				})
				Kit.reveal(row, 0.35 + order * 0.08, if left then 30 else -30)
			end
		end
	end
	local mode = Config.Modes[data.Mode]
	local tag = Kit.plate({
		Color = C.Accent,
		Size = UDim2.fromOffset(380, 40),
		Position = UDim2.new(0.5, 0, 0, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 76,
		Parent = overlay,
	})
	Kit.label({
		Text = `{if mode then mode.Label else ""}{if data.Ranked
			then "  ·  CLASSÉ"
			elseif data.Training then "  ·  ENTRAÎNEMENT"
			else ""}`,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H3 + 2,
		Color = C.TextOnAccent,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 77,
		Parent = tag,
	})
	local versus = Kit.title({
		Text = "VS",
		Font = Theme.Fonts.Hero,
		TextSize = 150,
		Color = C.Accent,
		ShadowColor = C.Ink,
		Stroke = 6,
		Offset = 9,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(260, 170),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -8,
		ZIndex = 78,
		Parent = overlay,
	})
	for _, mover in movers do
		Kit.tween(mover.Object, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Position = mover.To })
	end
	task.delay(0.3, function()
		flash(0.25)
		Kit.slam(versus.Instance, 3)
		Kit.shake(versus.Instance, 8, 0.3)
	end)
	task.delay(3.4, function()
		local out = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		for _, mover in movers do
			Kit.tween(mover.Object, out, { Position = mover.From })
		end
		Kit.tween(versus.Instance, out, { Position = UDim2.fromScale(0.5, -0.4) })
		Kit.tween(tag, out, { Position = UDim2.new(0.5, 0, 0, -120) })
		Kit.tween(overlay, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
		task.wait(0.4)
		overlay:Destroy()
	end)
end

-- Écran de fin ---------------------------------------------------------------------------------------------

local function endScreen(data: any)
	local outcome = data.Outcome
	local title = if outcome == "Win" then "VICTOIRE !" elseif outcome == "Loss" then "DÉFAITE" else "ÉGALITÉ"
	local color = if outcome == "Win" then C.Accent elseif outcome == "Loss" then C.Cyan else C.Violet
	local shadowColor = if outcome == "Win" then C.Pink elseif outcome == "Loss" then C.Violet else C.Cyan
	local overlay = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 90,
		Parent = root,
	})
	Kit.backdrop(overlay, color, 90)
	local page = Kit.box({
		Size = UDim2.new(1, -160, 1, -120),
		Position = UDim2.fromOffset(80, 60),
		ZIndex = 91,
		Parent = overlay,
	})
	local tag = Kit.plate({
		Color = C.Ink,
		Gradient = false,
		BorderColor = color,
		Shadow = false,
		Size = UDim2.fromOffset(230, 30),
		ZIndex = 92,
		Parent = page,
	})
	Kit.label({
		Text = if data.Ranked then "MATCH CLASSÉ" elseif data.Training then "ENTRAÎNEMENT" else "MATCH TERMINÉ",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Body,
		Color = color,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 93,
		Parent = tag,
	})
	local heading = Kit.title({
		Text = title,
		Font = Theme.Fonts.Hero,
		TextSize = 130,
		Color = color,
		ShadowColor = shadowColor,
		Stroke = 5,
		Offset = 9,
		Size = UDim2.new(0.62, 0, 0, 140),
		Position = UDim2.fromOffset(0, 26),
		Rotation = Theme.Tilt,
		ZIndex = 92,
		Parent = page,
	})
	Kit.slam(heading.Instance, 2.2)
	flash(0.3)

	-- Score : deux plaques d'équipe.
	local scoreRow = Kit.box({
		Size = UDim2.fromOffset(520, 56),
		Position = UDim2.fromOffset(8, 168),
		ZIndex = 92,
		Parent = page,
	})
	for index, team in { "Rouge", "Bleu" } do
		local info = Theme.Team[team]
		local plate = Kit.plate({
			Color = info.Main,
			Size = UDim2.fromOffset(170, 50),
			Position = UDim2.fromOffset(if index == 1 then 0 else 230, 0),
			ZIndex = 93,
			Parent = scoreRow,
		})
		Kit.label({
			Text = `{info.Name}  {if index == 1 then data.Score.Rouge else data.Score.Bleu}`,
			Font = Theme.Fonts.Number,
			TextSize = 32,
			Color = C.White,
			Stroke = 2.5,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 94,
			Parent = plate,
		})
	end
	Kit.label({
		Text = if data.Forfeit then "VS   (forfait)" else "VS",
		Font = Theme.Fonts.Hero,
		TextSize = 30,
		Color = C.Accent,
		Stroke = 2,
		AlignX = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(140, 50),
		Position = UDim2.fromOffset(184, 0),
		ZIndex = 94,
		Parent = scoreRow,
	})

	-- Tableau.
	local tableCard = Kit.surface({
		Color = C.Surface,
		Size = UDim2.new(0.62, 0, 1, -260),
		Position = UDim2.fromOffset(0, 250),
		Radius = Theme.RadiusLarge,
		BorderThickness = 3,
		Shadow = true,
		ShadowOffset = 7,
		ShadowColor = color,
		ZIndex = 92,
		Parent = page,
	})
	local list = Kit.box({
		Size = UDim2.new(1, -40, 1, -32),
		Position = UDim2.fromOffset(20, 16),
		ZIndex = 93,
		Parent = tableCard,
	})
	Kit.list(list, 5)
	local function row(cells: { string }, order: number, header: boolean, team: string?, highlight: boolean?)
		local line = Kit.new("Frame", {
			BackgroundColor3 = if highlight then Theme.darken(color, 0.55) elseif header then C.Ink else C.Surface2,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 36),
			LayoutOrder = order,
			ZIndex = 93,
			Parent = list,
		})
		Kit.corner(line, 4)
		if highlight then
			Kit.border(line, color, 2)
		end
		if team then
			local heel = Kit.new("Frame", {
				BackgroundColor3 = teamColor(team),
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(8, 36),
				ZIndex = 94,
				Parent = line,
			})
			Kit.corner(heel, 4)
		end
		local widths = { 0.46, 0.135, 0.135, 0.135, 0.135 }
		local x = 0
		for index, cell in cells do
			Kit.label({
				Text = cell,
				Font = if header
					then Theme.Fonts.Display
					elseif index == 1 then Theme.Fonts.Bold
					else Theme.Fonts.Number,
				TextSize = if header then Theme.Text.Small else Theme.Text.Body + 1,
				Color = if header then color else C.White,
				AlignX = if index == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
				Size = UDim2.new(widths[index], 0, 1, 0),
				Position = UDim2.new(x, if index == 1 then 20 else 0, 0, 0),
				ZIndex = 94,
				Parent = line,
			})
			x += widths[index]
		end
		if not header then
			Kit.reveal(line, 0.25 + order * 0.06, 24)
		end
	end
	row({ "JOUEUR", "BUTS", "PASSES D.", "ARRÊTS", "INTERC." }, 0, true)
	for index, entry in data.Table do
		row({
			`{entry.Name}{if entry.MVP then "  ★ MVP" else ""}`,
			tostring(entry.Goals),
			tostring(entry.Assists),
			tostring(entry.Saves),
			tostring(entry.Interceptions),
		}, index, false, entry.Team, entry.UserId == LocalPlayer.UserId)
	end

	-- Récompenses.
	local rewardsCard = Kit.surface({
		Color = C.Surface,
		Size = UDim2.new(0.35, 0, 1, -260),
		Position = UDim2.new(1, -8, 0, 250),
		AnchorPoint = Vector2.new(1, 0),
		Radius = Theme.RadiusLarge,
		BorderThickness = 3,
		Shadow = true,
		ShadowOffset = 7,
		ShadowColor = C.Pink,
		ZIndex = 92,
		Parent = page,
	})
	local rewardsTag = Kit.plate({
		Color = C.Pink,
		Size = UDim2.fromOffset(220, 40),
		Position = UDim2.fromOffset(18, -18),
		ZIndex = 94,
		Parent = rewardsCard,
	})
	Kit.label({
		Text = "RÉCOMPENSES",
		Font = Theme.Fonts.Hero,
		TextSize = 30,
		Color = C.White,
		Stroke = 2,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 95,
		Parent = rewardsTag,
	})
	local rewards = Kit.box({
		Size = UDim2.new(1, -48, 1, -64),
		Position = UDim2.fromOffset(24, 40),
		ZIndex = 93,
		Parent = rewardsCard,
	})
	Kit.list(rewards, 10)
	local function reward(label: string, value: string, order: number, valueColor: Color3?)
		local line = Kit.new("Frame", {
			BackgroundColor3 = C.Surface2,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = order,
			ZIndex = 94,
			Parent = rewards,
		})
		Kit.corner(line, 4)
		Kit.border(line, C.Ink, 2)
		Kit.label({
			Text = label,
			Font = Theme.Fonts.Semibold,
			Color = C.TextMuted,
			Size = UDim2.new(0.6, -12, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			ZIndex = 95,
			Parent = line,
		})
		local amount = Kit.label({
			Text = value,
			Font = Theme.Fonts.Number,
			TextSize = Theme.Text.H2,
			Color = valueColor or C.White,
			Stroke = 2,
			AlignX = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -12, 1, 0),
			ZIndex = 95,
			Parent = line,
		})
		Kit.reveal(line, 0.4 + order * 0.15, 24)
		task.delay(0.5 + order * 0.15, function()
			if amount.Parent then
				Kit.slam(amount, 1.7)
			end
		end)
	end
	local summary = data.Rewards
	if summary then
		reward("Hand Coins", `+{Format.number(summary.Coins)}`, 1, C.Accent)
		reward("Expérience", `+{Format.number(summary.XP)} XP`, 2, C.Cyan)
		if summary.LevelAfter > summary.LevelBefore then
			reward("Niveau supérieur", `{summary.LevelAfter}`, 3, C.Lime)
		end
		if data.Ranked then
			local rank = Progression.getRank(summary.RPAfter)
			reward(
				`Classement · {rank.Name}`,
				`{if summary.RPChange >= 0 then "+" else ""}{summary.RPChange} RP`,
				4,
				rank.Color
			)
		end
		if summary.FirstMatchBalls > 0 then
			reward("Cadeau de bienvenue", `{summary.FirstMatchBalls} balles`, 5, C.Pink)
		end
	elseif data.Training then
		reward("Entraînement", "aucune récompense", 1)
	end
	if data.MVP then
		reward("Joueur du match", data.MVP, 6, C.Accent)
	end

	local timer = Kit.label({
		Text = "",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Body,
		Color = C.TextMuted,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(400, 22),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 92,
		Parent = page,
	})
	task.spawn(function()
		local remaining = Config.Match.EndScreenTime
		while remaining > 0 and overlay.Parent do
			timer.Text = `RETOUR AU LOBBY DANS {remaining} S`
			task.wait(1)
			remaining -= 1
		end
	end)
	local connection
	connection = State.MatchEvent:Connect(function(kind)
		if kind == "Leave" then
			overlay:Destroy()
			connection:Disconnect()
		end
	end)
	task.delay(Config.Match.EndScreenTime + 15, function()
		if overlay.Parent then
			overlay:Destroy()
		end
	end)
end

-- Routage ---------------------------------------------------------------------------------------------------

local SET_PIECES = {
	FreeThrow = "Jet franc",
	ThrowIn = "Touche",
	Corner = "Corner",
	GoalThrow = "Renvoi",
	Penalty = "Jet de 7 mètres",
}

local function onEvent(kind: string, data: any)
	data = data or {}
	if kind == "Goal" then
		goal(data)
	elseif kind == "Power" then
		ultimate(data)
	elseif kind == "SetPiece" then
		Kit.playSound(Theme.Sounds.Whistle, 0.6)
		local label = SET_PIECES[data.Kind]
		if label then
			banner(
				label,
				`{data.Reason or ""}{if data.Reason then "  ·  " else ""}équipe {string.lower(
					Theme.Team[data.Team].Name
				)}`,
				teamColor(data.Team),
				1.8
			)
		end
	elseif kind == "Violation" then
		pushFeed(`{nameOf(data.Model)} · {string.lower(data.Label)}`, data.Team)
	elseif kind == "Foul" then
		pushFeed(`Faute de {nameOf(data.Offender)}`, data.Team)
	elseif kind == "YellowCard" then
		banner("Avertissement", data.Name, C.Warning, 2)
		pushFeed(`Avertissement · {data.Name}`, data.Team)
	elseif kind == "Suspension" then
		banner(`Exclusion {math.floor(data.Duration or Config.Rules.SuspensionTime)} s`, data.Name, C.White, 2)
		pushFeed(`Exclusion · {data.Name}`, data.Team)
	elseif kind == "RedCard" then
		banner("Carton rouge", data.Name, C.Danger, 2.4)
		pushFeed(`Carton rouge · {data.Name}`, data.Team)
	elseif kind == "Save" then
		pushFeed(`{if data.Parried then "Parade" else "Arrêt"} de {nameOf(data.Model)}`, data.Team)
	elseif kind == "Interception" then
		pushFeed(`Interception de {nameOf(data.Model)}`, data.Team)
	elseif kind == "Steal" then
		pushFeed(`Ballon volé par {nameOf(data.Model)}`, data.Team)
	elseif kind == "PassiveWarning" then
		banner("Jeu passif", "Tirez rapidement", C.Warning, 2)
	elseif kind == "Blind" then
		blind(data.Duration or 2)
	elseif kind == "TimeStop" then
		timeStop(data.Duration or 3)
	elseif kind == "Intro" then
		intro(data)
	elseif kind == "ThrowOff" then
		countdown(data.Countdown or 3)
	elseif kind == "Halftime" then
		banner(
			"Mi-temps",
			`Rouge {data.Score.Rouge} – {data.Score.Bleu} Bleu  ·  changement de côté`,
			C.Accent,
			(data.Duration or 10) - 1
		)
	elseif kind == "GoldenGoal" then
		banner("But en or", "Le prochain but décide du match", C.Accent, 2.5)
	elseif kind == "Left" then
		pushFeed(`{data.Name} a quitté le match`, data.Team)
	elseif kind == "End" then
		endScreen(data)
	end
end

function MatchFX.start()
	local _, frame = Kit.screen("EvenementsMatch", 30, LocalPlayer:WaitForChild("PlayerGui"))
	root = frame
	feed = Kit.box({
		Size = UDim2.fromOffset(420, 260),
		Position = UDim2.new(1, -24, 0, 100),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 20,
		Parent = root,
	})
	Kit.list(feed, 6, false, Enum.HorizontalAlignment.Right)
	bannerSlot = Kit.box({
		Size = UDim2.fromOffset(800, 80),
		Position = UDim2.new(0.5, 0, 0, 128),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 30,
		Parent = root,
	})
	State.MatchEvent:Connect(function(kind, data)
		local result = table.pack(pcall(onEvent, kind, data))
		if not result[1] then
			warn(`[MatchFX] {kind} : {result[2]}`)
		end
	end)
end

return MatchFX
