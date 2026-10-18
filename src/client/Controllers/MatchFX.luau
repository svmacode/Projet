--!strict
-- Interface d'événements du match : GOAL, fil d'actions, coups de sifflet,
-- présentation des équipes, compte à rebours, ultimes, mi-temps, fin.
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

local function teamInfo(team: string?): any
	return if team then Theme.Team[team] else nil
end

local function teamColor(team: string?): Color3
	local info = teamInfo(team)
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

-- Fil d'actions (haut droite) -------------------------------------------------------------------------

local function pushFeed(text: string, team: string?)
	feedOrder += 1
	local row = Kit.surface({
		Transparency = 0.06,
		BorderColor = C.White,
		BorderThickness = 2,
		Radius = 17,
		Size = UDim2.fromOffset(0, 34),
		AutoSize = Enum.AutomaticSize.X,
		Order = -feedOrder,
		ZIndex = 20,
		Parent = feed,
	})
	Kit.padding(row, 12, 0)
	Kit.list(row, 8, true, nil, Enum.VerticalAlignment.Center)
	local dot = Kit.new("Frame", {
		BackgroundColor3 = teamColor(team),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(10, 10),
		LayoutOrder = 1,
		ZIndex = 21,
		Parent = row,
	})
	Kit.round(dot)
	Kit.label({
		Text = text,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Small,
		Color = C.Text,
		Size = UDim2.fromOffset(0, 34),
		AutoSize = Enum.AutomaticSize.X,
		Order = 2,
		ZIndex = 21,
		Parent = row,
	})
	Kit.pop(row, 0.7)
	local rows = {}
	for _, child in feed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(rows, child)
		end
	end
	table.sort(rows, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = 6, #rows do
		rows[index]:Destroy()
	end
	task.delay(5, function()
		if row.Parent then
			Kit.tween(row, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
			for _, object in row:GetDescendants() do
				if object:IsA("TextLabel") then
					Kit.tween(object, TweenInfo.new(0.3), { TextTransparency = 1 })
				elseif object:IsA("Frame") then
					Kit.tween(object, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
				elseif object:IsA("UIStroke") then
					Kit.tween(object, TweenInfo.new(0.3), { Transparency = 1 })
				end
			end
			task.wait(0.32)
			row:Destroy()
		end
	end)
end

-- Bandeau central (coups de sifflet, mi-temps…) ----------------------------------------------------------

local function banner(title: string, detail: string?, accent: Color3, duration: number)
	Kit.clear(bannerSlot)
	local card = Kit.surface({
		Transparency = 0.03,
		BorderColor = C.White,
		BorderThickness = 3,
		Radius = 24,
		Size = UDim2.fromOffset(0, if detail then 80 else 56),
		AutoSize = Enum.AutomaticSize.X,
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 30,
		Parent = bannerSlot,
	})
	Kit.padding(card, 28, 0)
	local stack = Kit.box({
		Size = UDim2.fromScale(0, 1),
		AutoSize = Enum.AutomaticSize.X,
		ZIndex = 31,
		Parent = card,
	})
	Kit.list(stack, 0, false, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	Kit.label({
		Text = string.upper(title),
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H2,
		Color = accent,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(0, 34),
		AutoSize = Enum.AutomaticSize.X,
		Order = 1,
		ZIndex = 31,
		Parent = stack,
	})
	if detail and detail ~= "" then
		Kit.label({
			Text = detail,
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.Body,
			Color = C.TextMuted,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(0, 24),
			AutoSize = Enum.AutomaticSize.X,
			Order = 2,
			ZIndex = 31,
			Parent = stack,
		})
	end
	local accentBar = Kit.new("Frame", {
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(0.4, 0, 0, 4),
		ZIndex = 32,
		Parent = card,
	})
	Kit.round(accentBar)
	Kit.pop(card, 0.6)
	task.delay(duration, function()
		if card.Parent then
			local scale = card:FindFirstChildOfClass("UIScale")
			if scale then
				Kit.tween(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
			end
			task.wait(0.2)
			card:Destroy()
		end
	end)
end

local function flash(duration: number, color: Color3?, transparency: number?)
	local frame = Kit.new("Frame", {
		BackgroundColor3 = color or C.White,
		BackgroundTransparency = transparency or 0.2,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = root,
	})
	Kit.tween(frame, TweenInfo.new(duration, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	task.delay(duration, function()
		frame:Destroy()
	end)
end

-- GOAL ---------------------------------------------------------------------------------------------

-- Uniquement le mot « GOAL », à la couleur de l'équipe qui marque.
local function goal(data: any)
	Kit.playSound(Theme.Sounds.Goal, 1)
	local info = teamInfo(data.Team) or Theme.Team.Rouge
	flash(0.4, C.White, 0.35)
	local layer = Kit.box({ ZIndex = 58, Parent = root })
	-- Bande de couleur douce derrière le mot, qui s'ouvre puis se referme.
	local band = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(1.2, 0, 0, 0),
		Rotation = -4,
		ZIndex = 58,
		Parent = layer,
	})
	Kit.new("UIGradient", {
		Color = ColorSequence.new(info.Light, info.Main),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.1),
			NumberSequenceKeypoint.new(0.8, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = band,
	})
	Kit.tween(band, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.new(1.2, 0, 0, 230) })
	local word = Kit.title({
		Text = "GOAL",
		TextSize = 200,
		Color = C.White,
		StrokeColor = info.Dark,
		Stroke = 8,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(1000, 230),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -4,
		ZIndex = 60,
		Parent = layer,
	})
	Kit.slam(word.Instance, 2.4)
	task.delay(0.18, function()
		Kit.shake(word.Instance, 6, 0.3)
	end)
	-- Légère respiration pendant la célébration.
	task.delay(0.6, function()
		local scale = word.Instance:FindFirstChildOfClass("UIScale")
		if scale then
			Kit.tween(
				scale,
				TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Scale = 1.04 }
			)
		end
	end)
	local life = math.max(1.5, Config.Match.GoalCelebrationTime - 1)
	task.delay(life, function()
		if not layer.Parent then
			return
		end
		Kit.tween(word.Instance, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(1.6, 0, 0.42, 0),
		})
		Kit.tween(band, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(1.2, 0, 0, 0),
		})
		task.wait(0.32)
		layer:Destroy()
	end)
	pushFeed(
		if data.OwnGoal then "But contre son camp" elseif data.Scorer then `But de {data.Scorer}` else "But",
		data.Team
	)
end

-- Ultime : bandes de cinéma, nom du pouvoir ------------------------------------------------------------------

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
	Kit.playSound(Theme.Sounds.Ultimate ~= "" and Theme.Sounds.Ultimate or Theme.Sounds.Power, 0.8)
	flash(0.25, power.Color, 0.4)
	local layer = Kit.box({ ZIndex = 55, Parent = root })
	local bars = {}
	for index = 1, 2 do
		local top = index == 1
		local bar = Kit.new("Frame", {
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0.11, 0),
			Position = if top then UDim2.fromScale(0, -0.11) else UDim2.fromScale(0, 1),
			ZIndex = 55,
			Parent = layer,
		})
		Kit.tween(bar, Theme.Motion.Base, { Position = if top then UDim2.new() else UDim2.fromScale(0, 0.89) })
		table.insert(bars, bar)
	end
	local card = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(-0.6, 0, 0.62, 0),
		Size = UDim2.fromOffset(640, 120),
		ZIndex = 56,
		Parent = layer,
	})
	Kit.corner(card, 24)
	Kit.gradient(card, Theme.lighten(power.Color, 0.25), power.Color, 90)
	Kit.border(card, C.White, 3)
	Kit.label({
		Text = `{string.upper(data.Name or "")}  ·  ULTIME`,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Small,
		Color = C.White,
		Stroke = 1.5,
		StrokeColor = Theme.darken(power.Color, 0.4),
		Size = UDim2.new(1, -60, 0, 20),
		Position = UDim2.fromOffset(32, 16),
		ZIndex = 57,
		Parent = card,
	})
	Kit.title({
		Text = string.upper(power.Name),
		TextSize = 54,
		StrokeColor = Theme.darken(power.Color, 0.45),
		Size = UDim2.new(1, -60, 0, 66),
		Position = UDim2.fromOffset(30, 40),
		ZIndex = 57,
		Parent = card,
	})
	Kit.tween(card, Theme.Motion.Spring, { Position = UDim2.new(0, 60, 0.62, 0) })
	task.delay(1.5, function()
		Kit.tween(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1.2, 0, 0.62, 0),
		})
		Kit.tween(bars[1], Theme.Motion.Base, { Position = UDim2.fromScale(0, -0.11) })
		Kit.tween(bars[2], Theme.Motion.Base, { Position = UDim2.fromScale(0, 1) })
		task.wait(0.3)
		layer:Destroy()
	end)
	if data.Team then
		pushFeed(`{data.Name} · {power.Name}`, data.Team)
	end
end

local function blind(duration: number)
	local frame = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 80,
		Parent = root,
	})
	task.delay(math.max(0, duration - 0.5), function()
		Kit.tween(frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		task.wait(0.5)
		frame:Destroy()
	end)
end

local function timeStop(duration: number)
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "ArretDuTemps"
	correction.Saturation = -0.85
	correction.Contrast = 0.15
	correction.TintColor = Color3.fromRGB(220, 230, 255)
	correction.Parent = Lighting
	task.delay(duration, function()
		correction:Destroy()
	end)
end

-- Texte qui jaillit au-dessus d'un joueur (« BALLON VOLÉ ! »…).
local POPUP_COLORS: { [string]: Color3 } = { Gold = C.Gold, Danger = C.Danger, Info = C.Sky, Success = C.Success }

local function popup(data: any)
	local model = data.Model
	local head = model and model:FindFirstChild("Head")
	if not head or not data.Text then
		return
	end
	local color = POPUP_COLORS[data.Style or "Info"] or C.Sky
	local billboard = Kit.new("BillboardGui", {
		Size = UDim2.fromOffset(260, 50),
		StudsOffset = Vector3.new(0, 3.4, 0),
		AlwaysOnTop = true,
		MaxDistance = 140,
		Adornee = head,
		Parent = LocalPlayer:WaitForChild("PlayerGui"),
	})
	local label = Kit.label({
		Text = data.Text,
		Font = Theme.Fonts.Hero,
		TextSize = 26,
		Color = color,
		Stroke = 2.5,
		StrokeColor = C.White,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = billboard,
	})
	Kit.slam(label, 1.6)
	Kit.tween(billboard, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 5, 0) })
	task.delay(0.9, function()
		Kit.tween(label, TweenInfo.new(0.3), { TextTransparency = 1 })
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			Kit.tween(stroke, TweenInfo.new(0.3), { Transparency = 1 })
		end
	end)
	task.delay(1.3, function()
		billboard:Destroy()
	end)
end

-- Compte à rebours ------------------------------------------------------------------------------------------

local function countdown(seconds: number)
	task.spawn(function()
		for remaining = math.floor(seconds), 1, -1 do
			local number = Kit.title({
				Text = tostring(remaining),
				TextSize = 150,
				StrokeColor = C.AccentDark,
				AlignX = Enum.TextXAlignment.Center,
				Size = UDim2.fromOffset(300, 170),
				Position = UDim2.fromScale(0.5, 0.4),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 60,
				Parent = root,
			})
			Kit.slam(number.Instance, 1.8)
			Kit.playSound(Theme.Sounds.Click, 0.5)
			task.wait(0.75)
			Kit.tween(number.Label, TweenInfo.new(0.2), { TextTransparency = 1 })
			Kit.tween(number.Shadow, TweenInfo.new(0.2), { TextTransparency = 1 })
			for _, label in { number.Label, number.Shadow } do
				local stroke = label:FindFirstChildOfClass("UIStroke")
				if stroke then
					Kit.tween(stroke, TweenInfo.new(0.2), { Transparency = 1 })
				end
			end
			task.wait(0.25)
			number.Instance:Destroy()
		end
		local go = Kit.title({
			Text = "GO !",
			TextSize = 150,
			Color = C.Gold,
			StrokeColor = C.AccentDark,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(500, 170),
			Position = UDim2.fromScale(0.5, 0.4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 60,
			Parent = root,
		})
		Kit.slam(go.Instance, 2)
		Kit.playSound(Theme.Sounds.Whistle, 0.7)
		task.wait(0.7)
		Kit.tween(go.Instance, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(0.5, 0.2),
		})
		task.wait(0.25)
		go.Instance:Destroy()
	end)
end

-- Présentation des équipes -------------------------------------------------------------------------------------

local function intro(data: any)
	local match = State.Match
	if not match then
		return
	end
	local overlay = Kit.new("CanvasGroup", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 70,
		Parent = root,
	})
	local back = Kit.new("Frame", {
		BackgroundColor3 = C.Overlay,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 70,
		Parent = overlay,
	})
	local mode = Config.Modes[data.Mode]
	local tag = Kit.surface({
		Transparency = 0.03,
		BorderColor = C.White,
		BorderThickness = 2.5,
		Radius = 20,
		Size = UDim2.fromOffset(360, 44),
		Position = UDim2.new(0.5, 0, 0, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 72,
		Parent = back,
	})
	Kit.label({
		Text = `{if mode then mode.Label else ""}{if data.Ranked
			then "  ·  CLASSÉ"
			elseif data.Training then "  ·  ENTRAÎNEMENT"
			else ""}`,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H3,
		Color = C.Text,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 73,
		Parent = tag,
	})
	for index, team in { "Rouge", "Bleu" } do
		local info = Theme.Team[team]
		local left = index == 1
		local panel = Kit.new("Frame", {
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(if left then 1 else 0, 0.5),
			Position = UDim2.new(0.5, if left then -1200 else 1200, 0.55, 0),
			Size = UDim2.fromOffset(500, 440),
			ZIndex = 72,
			Parent = back,
		})
		Kit.corner(panel, 26)
		Kit.gradient(panel, info.Light, info.Main, 120)
		Kit.border(panel, C.White, 4)
		Kit.title({
			Text = `ÉQUIPE {info.Name}`,
			TextSize = 46,
			StrokeColor = info.Dark,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 60),
			Position = UDim2.fromOffset(0, 20),
			ZIndex = 73,
			Parent = panel,
		})
		local list = Kit.box({
			Size = UDim2.new(1, -48, 1, -110),
			Position = UDim2.fromOffset(24, 96),
			ZIndex = 73,
			Parent = panel,
		})
		Kit.list(list, 8)
		local order = 0
		for _, participant in match.Participants do
			if participant.Team == team then
				order += 1
				local archetype = Archetypes.get(participant.Archetype)
				local row = Kit.surface({
					Transparency = 0.04,
					Border = false,
					Radius = 16,
					Size = UDim2.new(1, 0, 0, 56),
					Order = order,
					ZIndex = 74,
					Parent = list,
				})
				Kit.label({
					Text = tostring(participant.Number),
					Font = Theme.Fonts.Number,
					TextSize = Theme.Text.H2,
					Color = info.Main,
					AlignX = Enum.TextXAlignment.Center,
					Size = UDim2.fromOffset(52, 56),
					ZIndex = 75,
					Parent = row,
				})
				Kit.label({
					Text = participant.Name,
					Font = Theme.Fonts.Display,
					TextSize = Theme.Text.Body,
					Color = C.Text,
					Size = UDim2.new(1, -70, 0, 22),
					Position = UDim2.fromOffset(56, 8),
					ZIndex = 75,
					Parent = row,
				})
				Kit.label({
					Text = if archetype
						then `{archetype.Name}  ·  {Theme.rarityName(archetype.Rarity)}`
						else (participant.Poste or ""),
					Font = Theme.Fonts.Bold,
					TextSize = Theme.Text.Small,
					Color = if archetype then Theme.rarityColor(archetype.Rarity) else C.TextMuted,
					Size = UDim2.new(1, -70, 0, 18),
					Position = UDim2.fromOffset(56, 30),
					ZIndex = 75,
					Parent = row,
				})
				Kit.reveal(row, 0.35 + order * 0.08, 14)
			end
		end
		Kit.tween(panel, Theme.Motion.Spring, { Position = UDim2.new(0.5, if left then -40 else 40, 0.55, 0) })
	end
	local versus = Kit.title({
		Text = "VS",
		TextSize = 90,
		Color = C.Gold,
		StrokeColor = C.Ink,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(200, 110),
		Position = UDim2.fromScale(0.5, 0.55),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 80,
		Parent = back,
	})
	versus.Instance.Visible = false
	task.delay(0.35, function()
		versus.Instance.Visible = true
		Kit.slam(versus.Instance, 2.2)
	end)
	task.delay(3.4, function()
		Kit.tween(overlay, TweenInfo.new(0.4), { GroupTransparency = 1 })
		task.wait(0.45)
		overlay:Destroy()
	end)
end

-- Écran de fin ---------------------------------------------------------------------------------------------------

local function endScreen(data: any)
	local outcome = data.Outcome
	local title = if outcome == "Win" then "VICTOIRE !" elseif outcome == "Loss" then "DÉFAITE" else "ÉGALITÉ"
	local color = if outcome == "Win" then C.Accent elseif outcome == "Loss" then C.Sky else Theme.Section.Clan
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
	Kit.label({
		Text = if data.Ranked then "MATCH CLASSÉ" elseif data.Training then "ENTRAÎNEMENT" else "MATCH TERMINÉ",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Body,
		Color = C.White,
		Stroke = 1.5,
		StrokeColor = Theme.darken(color, 0.4),
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = 92,
		Parent = page,
	})
	local heading = Kit.title({
		Text = title,
		TextSize = 110,
		StrokeColor = Theme.darken(color, 0.45),
		Size = UDim2.new(0.62, 0, 0, 124),
		Position = UDim2.fromOffset(0, 24),
		ZIndex = 92,
		Parent = page,
	})
	Kit.slam(heading.Instance, 1.8)
	flash(0.35, C.White, 0.3)

	-- Score.
	local scoreRow = Kit.surface({
		Transparency = 0.03,
		BorderColor = C.White,
		BorderThickness = 3,
		Radius = 26,
		Size = UDim2.fromOffset(360, 60),
		Position = UDim2.fromOffset(4, 162),
		ZIndex = 92,
		Parent = page,
	})
	for index, team in { "Rouge", "Bleu" } do
		local info = Theme.Team[team]
		local pill = Kit.new("Frame", {
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(140, 48),
			Position = if index == 1 then UDim2.fromOffset(6, 6) else UDim2.new(1, -146, 0, 6),
			ZIndex = 93,
			Parent = scoreRow,
		})
		Kit.corner(pill, 24)
		Kit.gradient(pill, info.Light, info.Main, 90)
		Kit.label({
			Text = tostring(if index == 1 then data.Score.Rouge else data.Score.Bleu),
			Font = Theme.Fonts.Number,
			TextSize = 34,
			Color = C.White,
			Stroke = 2,
			StrokeColor = info.Dark,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 94,
			Parent = pill,
		})
	end
	Kit.label({
		Text = if data.Forfeit then "forfait" else "–",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Body,
		Color = C.TextMuted,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.new(0.5, -30, 0, 0),
		ZIndex = 93,
		Parent = scoreRow,
	})

	-- Tableau des joueurs.
	local tableCard = Kit.surface({
		Transparency = 0.03,
		BorderColor = C.White,
		BorderThickness = 3,
		Radius = 22,
		Size = UDim2.new(0.62, -20, 1, -250),
		Position = UDim2.fromOffset(0, 246),
		ZIndex = 92,
		Parent = page,
	})
	local rows = Kit.box({
		Size = UDim2.new(1, -40, 1, -32),
		Position = UDim2.fromOffset(20, 16),
		ZIndex = 93,
		Parent = tableCard,
	})
	Kit.list(rows, 4)
	local widths = { 0.48, 0.13, 0.13, 0.13, 0.13 }
	local function row(cells: { string }, order: number, header: boolean, team: string?, mine: boolean?)
		local line = Kit.new("Frame", {
			BackgroundColor3 = if mine then Color3.fromRGB(255, 240, 220) else C.Surface2,
			BackgroundTransparency = if header then 1 else 0,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, if header then 26 else 38),
			LayoutOrder = order,
			ZIndex = 93,
			Parent = rows,
		})
		Kit.corner(line, 10)
		if team then
			local dot = Kit.new("Frame", {
				BackgroundColor3 = teamColor(team),
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(8, 22),
				Position = UDim2.new(0, 8, 0.5, -11),
				ZIndex = 94,
				Parent = line,
			})
			Kit.round(dot)
		end
		local x = 0
		for index, text in cells do
			Kit.label({
				Text = text,
				Font = if header
					then Theme.Fonts.Display
					elseif index == 1 then Theme.Fonts.Bold
					else Theme.Fonts.Number,
				TextSize = if header then Theme.Text.Tiny else Theme.Text.Body,
				Color = if header then C.TextMuted else C.Text,
				AlignX = if index == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
				Size = UDim2.new(widths[index], if index == 1 then -24 else 0, 1, 0),
				Position = UDim2.new(x, if index == 1 then 24 else 0, 0, 0),
				ZIndex = 94,
				Parent = line,
			})
			x += widths[index]
		end
		if not header then
			Kit.reveal(line, 0.25 + order * 0.05, 12)
		end
	end
	row({ "JOUEUR", "BUTS", "PASSES D.", "ARRÊTS", "INTERC." }, 0, true)
	for index, entry in data.Table or {} do
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
		Transparency = 0.03,
		BorderColor = C.White,
		BorderThickness = 3,
		Radius = 22,
		Size = UDim2.new(0.38, 0, 1, -250),
		Position = UDim2.new(1, 0, 0, 246),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 92,
		Parent = page,
	})
	Kit.label({
		Text = "RÉCOMPENSES",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H3,
		Color = C.Text,
		Size = UDim2.new(1, -48, 0, 28),
		Position = UDim2.fromOffset(24, 18),
		ZIndex = 93,
		Parent = rewardsCard,
	})
	local rewards = Kit.box({
		Size = UDim2.new(1, -48, 1, -70),
		Position = UDim2.fromOffset(24, 56),
		ZIndex = 93,
		Parent = rewardsCard,
	})
	Kit.list(rewards, 8)
	local function reward(label: string, value: string, order: number, valueColor: Color3?)
		local line = Kit.new("Frame", {
			BackgroundColor3 = C.Surface2,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 44),
			LayoutOrder = order,
			ZIndex = 94,
			Parent = rewards,
		})
		Kit.corner(line, 12)
		Kit.label({
			Text = label,
			Font = Theme.Fonts.Bold,
			Color = C.TextMuted,
			Size = UDim2.new(0.6, -14, 1, 0),
			Position = UDim2.fromOffset(14, 0),
			ZIndex = 95,
			Parent = line,
		})
		local amount = Kit.label({
			Text = value,
			Font = Theme.Fonts.Number,
			TextSize = Theme.Text.H3,
			Color = valueColor or C.Text,
			AlignX = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -14, 1, 0),
			ZIndex = 95,
			Parent = line,
		})
		Kit.reveal(line, 0.4 + order * 0.14, 12)
		task.delay(0.5 + order * 0.14, function()
			if amount.Parent then
				Kit.pop(amount, 1.4)
			end
		end)
	end
	local summary = data.Rewards
	if summary then
		reward("Hand Coins", `+{Format.number(summary.Coins)}`, 1, C.AccentDark)
		reward("Expérience", `+{Format.number(summary.XP)} XP`, 2, C.SkyDark)
		if summary.LevelAfter > summary.LevelBefore then
			reward("Niveau supérieur", `{summary.LevelAfter}`, 3, C.Success)
		end
		if data.Ranked then
			local rank = Progression.getRank(summary.RPAfter)
			reward(
				`Classé · {rank.Name}`,
				`{if summary.RPChange >= 0 then "+" else ""}{summary.RPChange} RP`,
				4,
				Theme.darken(rank.Color, 0.2)
			)
		end
		if summary.FirstMatchBalls > 0 then
			reward("Cadeau de bienvenue", `{summary.FirstMatchBalls} balles`, 5, C.Accent)
		end
	elseif data.Training then
		reward("Entraînement", "aucune récompense", 1)
	end
	if data.MVP then
		reward("Joueur du match", data.MVP, 6, C.AccentDark)
	end

	local timer = Kit.label({
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Body,
		Color = C.White,
		Stroke = 1.5,
		StrokeColor = Theme.darken(color, 0.4),
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
			timer.Text = `Retour au lobby dans {remaining} s`
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
	GoalThrow = "Renvoi",
}

local function isMine(model: Model?): boolean
	return model ~= nil and model == LocalPlayer.Character
end

local function onEvent(kind: string, data: any)
	data = data or {}
	if kind == "Goal" then
		goal(data)
	elseif kind == "Power" then
		ultimate(data)
	elseif kind == "SetPiece" then
		Kit.playSound(Theme.Sounds.Whistle, 0.6)
		local label = SET_PIECES[data.Kind] or data.Label
		if label then
			local team = teamInfo(data.Team)
			banner(
				label,
				`{data.Reason or ""}{if data.Reason and team then "  ·  " else ""}{if team
					then "équipe " .. string.lower(team.Name)
					else ""}`,
				teamColor(data.Team),
				1.8
			)
		end
	elseif kind == "Violation" then
		pushFeed(`{nameOf(data.Model)} · {string.lower(data.Label or "faute")}`, data.Team)
	elseif kind == "Foul" then
		pushFeed(`Faute de {nameOf(data.Offender)}`, data.Team)
	elseif kind == "Save" then
		pushFeed(`{if data.Parried then "Parade" else "Arrêt"} de {nameOf(data.Model)}`, data.Team)
	elseif kind == "Interception" then
		pushFeed(`Interception de {nameOf(data.Model)}`, data.Team)
	elseif kind == "Steal" then
		pushFeed(`Ballon volé par {nameOf(data.Model)}`, data.Team)
	elseif kind == "Popup" then
		popup(data)
	elseif kind == "Status" then
		if data.Kind == "Blind" and isMine(data.Model) then
			blind(data.Duration or 2)
		end
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
		banner("But en or", "Le prochain but gagne le match", C.Gold, 2.5)
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
		Position = UDim2.new(1, -24, 0, 24),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 20,
		Parent = root,
	})
	Kit.list(feed, 6, false, Enum.HorizontalAlignment.Right)
	bannerSlot = Kit.box({
		Size = UDim2.fromOffset(900, 90),
		Position = UDim2.new(0.5, 0, 0, 100),
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
