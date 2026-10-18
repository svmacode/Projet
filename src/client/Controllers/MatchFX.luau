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
	local row = Kit.surface({
		Color = C.Surface,
		Size = UDim2.fromOffset(0, 36),
		AutoSize = Enum.AutomaticSize.X,
		Order = -feedOrder,
		ZIndex = 20,
		Parent = feed,
	})
	Kit.padding(row, 14, 0)
	local inner =
		Kit.box({ Size = UDim2.fromOffset(0, 36), AutoSize = Enum.AutomaticSize.X, ZIndex = 20, Parent = row })
	Kit.list(inner, 10, true, nil, Enum.VerticalAlignment.Center)
	Kit.new("Frame", {
		BackgroundColor3 = teamColor(team),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(3, 16),
		LayoutOrder = 1,
		ZIndex = 21,
		Parent = inner,
	})
	Kit.label({
		Text = text,
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Small,
		Size = UDim2.fromOffset(0, 36),
		AutoSize = Enum.AutomaticSize.X,
		Order = 2,
		ZIndex = 21,
		Parent = inner,
	})
	Kit.reveal(row, 0, 0)
	task.delay(5, function()
		if row.Parent then
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

-- Bandeau central discret (sifflet, jets, cartons) ---------------------------------------------

local function banner(title: string, detail: string?, accent: Color3, duration: number)
	Kit.clear(bannerSlot)
	local card = Kit.surface({
		Color = C.Surface,
		Size = UDim2.fromOffset(0, if detail then 68 else 48),
		AutoSize = Enum.AutomaticSize.X,
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 30,
		Parent = bannerSlot,
	})
	Kit.padding(card, 24, 0)
	Kit.new("Frame", {
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 48, 0, 3),
		Position = UDim2.fromOffset(-24, 0),
		ZIndex = 31,
		Parent = card,
	})
	local column = Kit.box({
		Size = UDim2.fromOffset(0, if detail then 68 else 48),
		AutoSize = Enum.AutomaticSize.X,
		ZIndex = 31,
		Parent = card,
	})
	Kit.list(column, 0, false, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	Kit.label({
		Text = title,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H3,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(0, 26),
		AutoSize = Enum.AutomaticSize.X,
		Order = 1,
		ZIndex = 32,
		Parent = column,
	})
	if detail then
		Kit.label({
			Text = detail,
			TextSize = Theme.Text.Small,
			Color = C.TextMuted,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(0, 20),
			AutoSize = Enum.AutomaticSize.X,
			Order = 2,
			ZIndex = 32,
			Parent = column,
		})
	end
	Kit.reveal(card, 0, -8)
	task.delay(duration, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

-- GOAL ---------------------------------------------------------------------------------------------------

local function goal(data: any)
	Kit.playSound(Theme.Sounds.Goal, 1)
	local color = teamColor(data.Team)
	local holder = Kit.box({
		Size = UDim2.fromOffset(1200, 260),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 60,
		Parent = root,
	})
	local word = Kit.label({
		Text = "GOAL",
		Font = Theme.Fonts.DisplayItalic,
		TextSize = 220,
		Color = C.White,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 62,
		Parent = holder,
	})
	-- Ombre portée pleine décalée.
	local shadow = Kit.label({
		Text = "GOAL",
		Font = Theme.Fonts.DisplayItalic,
		TextSize = 220,
		Color = color,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(10, 10),
		ZIndex = 61,
		Parent = holder,
	})
	local line = Kit.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 8),
		Position = UDim2.new(0.5, 0, 1, 6),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 61,
		Parent = holder,
	})
	local scale = Kit.new("UIScale", { Scale = 1.8, Parent = holder })
	Kit.tween(scale, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 })
	task.delay(0.15, function()
		Kit.tween(line, Theme.Motion.Slow, { Size = UDim2.fromOffset(620, 8) })
	end)
	-- Léger tremblement à l'impact.
	task.spawn(function()
		local stop = os.clock() + 0.35
		while os.clock() < stop do
			local s = 8 * (stop - os.clock()) / 0.35
			word.Position = UDim2.fromOffset(math.random(-s, s), math.random(-s, s))
			task.wait(1 / 60)
		end
		word.Position = UDim2.new()
	end)
	task.delay(Config.Match.GoalCelebrationTime - 0.8, function()
		Kit.tween(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Scale = 0 })
		task.wait(0.3)
		holder:Destroy()
	end)
	local _ = shadow
	pushFeed(
		if data.OwnGoal then "But contre son camp" elseif data.Scorer then `But de {data.Scorer}` else "But",
		data.Team
	)
end

-- Ultime : bandeau propre, couleur du pouvoir ----------------------------------------------------------

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
	local band = Kit.new("Frame", {
		BackgroundColor3 = Theme.darken(power.Color, 0.55),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 132),
		Position = UDim2.new(-1, 0, 0.62, 0),
		ZIndex = 55,
		Parent = root,
	})
	Kit.new("Frame", {
		BackgroundColor3 = power.Color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 4),
		ZIndex = 56,
		Parent = band,
	})
	Kit.new("Frame", {
		BackgroundColor3 = power.Color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.new(0, 0, 1, -4),
		ZIndex = 56,
		Parent = band,
	})
	Kit.label({
		Text = `ULTIME  ·  {string.upper(data.Name)}  ·  {string.upper(archetype.Name)}`,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Small,
		Color = Theme.lighten(power.Color, 0.4),
		Position = UDim2.fromOffset(120, 24),
		Size = UDim2.new(1, -240, 0, 18),
		ZIndex = 57,
		Parent = band,
	})
	Kit.label({
		Text = string.upper(power.Name),
		Font = Theme.Fonts.DisplayItalic,
		TextSize = 64,
		Position = UDim2.fromOffset(116, 44),
		Size = UDim2.new(1, -240, 0, 72),
		ZIndex = 57,
		Parent = band,
	})
	Kit.tween(band, TweenInfo.new(0.28, Enum.EasingStyle.Quint), { Position = UDim2.new(0, 0, 0.62, 0) })
	task.delay(1.4, function()
		Kit.tween(
			band,
			TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
			{ Position = UDim2.new(1, 0, 0.62, 0) }
		)
		task.wait(0.3)
		band:Destroy()
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

local function countdown(seconds: number)
	task.spawn(function()
		for i = seconds, 1, -1 do
			local number = Kit.label({
				Text = tostring(i),
				Font = Theme.Fonts.Display,
				TextSize = 140,
				AlignX = Enum.TextXAlignment.Center,
				Size = UDim2.fromOffset(300, 160),
				Position = UDim2.fromScale(0.5, 0.4),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 60,
				Parent = root,
			})
			Kit.pop(number, 1.4)
			task.wait(0.9)
			number:Destroy()
		end
		local go = Kit.label({
			Text = "GO",
			Font = Theme.Fonts.DisplayItalic,
			TextSize = 150,
			Color = C.Accent,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(400, 170),
			Position = UDim2.fromScale(0.5, 0.4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 60,
			Parent = root,
		})
		Kit.pop(go, 1.5)
		task.wait(0.7)
		go:Destroy()
	end)
end

local function intro(data: any)
	local match = State.Match
	if not match then
		return
	end
	local overlay = Kit.new("Frame", {
		BackgroundColor3 = C.Background,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 70,
		Parent = root,
	})
	local mode = Config.Modes[data.Mode]
	Kit.label({
		Text = `{if mode then mode.Label else ""}{if data.Ranked
			then "  ·  CLASSÉ"
			elseif data.Training then "  ·  ENTRAÎNEMENT"
			else ""}`,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Small,
		Color = C.Accent,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 110),
		ZIndex = 71,
		Parent = overlay,
	})
	for index, team in { "Rouge", "Bleu" } do
		local column = Kit.box({
			Size = UDim2.fromOffset(460, 480),
			Position = UDim2.new(0.5, if index == 1 then -80 else 80, 0.5, 20),
			AnchorPoint = Vector2.new(if index == 1 then 1 else 0, 0.5),
			ZIndex = 71,
			Parent = overlay,
		})
		local align = if index == 1 then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
		Kit.new("Frame", {
			BackgroundColor3 = teamColor(team),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(60, 4),
			Position = UDim2.new(if index == 1 then 1 else 0, if index == 1 then -60 else 0, 0, 0),
			ZIndex = 72,
			Parent = column,
		})
		Kit.label({
			Text = `ÉQUIPE {Theme.Team[team].Name}`,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H1,
			AlignX = align,
			Size = UDim2.new(1, 0, 0, 44),
			Position = UDim2.fromOffset(0, 16),
			ZIndex = 72,
			Parent = column,
		})
		local list = Kit.box({
			Size = UDim2.new(1, 0, 1, -80),
			Position = UDim2.fromOffset(0, 80),
			ZIndex = 72,
			Parent = column,
		})
		Kit.list(list, 10, false, if index == 1 then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left)
		local order = 0
		for _, participant in match.Participants do
			if participant.Team == team then
				order += 1
				local archetype = Archetypes.get(participant.Archetype)
				local row = Kit.label({
					Text = `<b>{participant.Name}</b>  <font color="#{C.TextMuted:ToHex()}">{if archetype
						then archetype.Name
						else ""}</font>`,
					Rich = true,
					TextSize = Theme.Text.H3,
					AlignX = align,
					Size = UDim2.new(1, 0, 0, 30),
					Order = order,
					ZIndex = 73,
					Parent = list,
				})
				Kit.reveal(row, 0.15 + order * 0.08, 10)
			end
		end
	end
	local versus = Kit.label({
		Text = "VS",
		Font = Theme.Fonts.DisplayItalic,
		TextSize = 72,
		Color = C.TextFaint,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(160, 80),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 72,
		Parent = overlay,
	})
	Kit.pop(versus, 1.6)
	task.delay(3.4, function()
		Kit.tween(overlay, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		for _, child in overlay:GetDescendants() do
			if child:IsA("TextLabel") then
				Kit.tween(child, TweenInfo.new(0.3), { TextTransparency = 1 })
			elseif child:IsA("Frame") and child.BackgroundTransparency < 1 then
				Kit.tween(child, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
			end
		end
		task.wait(0.45)
		overlay:Destroy()
	end)
end

-- Écran de fin ---------------------------------------------------------------------------------------------

local function endScreen(data: any)
	local overlay = Kit.new("Frame", {
		BackgroundColor3 = C.Background,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 90,
		Parent = root,
	})
	local page = Kit.box({
		Size = UDim2.new(1, -160, 1, -120),
		Position = UDim2.fromOffset(80, 60),
		ZIndex = 91,
		Parent = overlay,
	})
	local outcome = data.Outcome
	local title = if outcome == "Win" then "Victoire" elseif outcome == "Loss" then "Défaite" else "Égalité"
	local color = if outcome == "Win" then C.Accent elseif outcome == "Loss" then C.TextMuted else C.Info
	Kit.label({
		Text = if data.Ranked then "MATCH CLASSÉ" elseif data.Training then "ENTRAÎNEMENT" else "MATCH TERMINÉ",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 92,
		Parent = page,
	})
	local heading = Kit.label({
		Text = title,
		Font = Theme.Fonts.DisplayItalic,
		TextSize = 96,
		Color = color,
		Size = UDim2.new(0.6, 0, 0, 104),
		Position = UDim2.fromOffset(0, 20),
		ZIndex = 92,
		Parent = page,
	})
	Kit.reveal(heading, 0, 20)
	Kit.label({
		Text = `<font color="#{teamColor("Rouge"):ToHex()}">ROUGE</font>  {data.Score.Rouge} – {data.Score.Bleu}  <font color="#{teamColor(
			"Bleu"
		):ToHex()}">BLEU</font>{if data.Forfeit then "   (forfait)" else ""}`,
		Rich = true,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H2,
		Size = UDim2.new(0.6, 0, 0, 32),
		Position = UDim2.fromOffset(4, 128),
		ZIndex = 92,
		Parent = page,
	})

	-- Tableau.
	local tableCard = Kit.surface({
		Color = C.Surface,
		Size = UDim2.new(0.62, 0, 1, -200),
		Position = UDim2.fromOffset(0, 190),
		Radius = Theme.RadiusLarge,
		ZIndex = 92,
		Parent = page,
	})
	local list = Kit.box({
		Size = UDim2.new(1, -48, 1, -40),
		Position = UDim2.fromOffset(24, 20),
		ZIndex = 93,
		Parent = tableCard,
	})
	Kit.list(list, 4)
	local function row(cells: { string }, order: number, header: boolean, team: string?, highlight: boolean?)
		local line = Kit.new("Frame", {
			BackgroundColor3 = if highlight then C.Surface3 else C.Surface,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = order,
			ZIndex = 93,
			Parent = list,
		})
		Kit.corner(line, 6)
		if team then
			Kit.new("Frame", {
				BackgroundColor3 = teamColor(team),
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(3, 18),
				Position = UDim2.new(0, 8, 0.5, -9),
				ZIndex = 94,
				Parent = line,
			})
		end
		local widths = { 0.46, 0.135, 0.135, 0.135, 0.135 }
		local x = 0
		for index, cell in cells do
			Kit.label({
				Text = cell,
				Font = if header then Theme.Fonts.Bold elseif index == 1 then Theme.Fonts.Semibold else Theme.Fonts.Bold,
				TextSize = if header then Theme.Text.Tiny else Theme.Text.Body,
				Color = if header then C.TextFaint else C.Text,
				AlignX = if index == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
				Size = UDim2.new(widths[index], 0, 1, 0),
				Position = UDim2.new(x, if index == 1 then 20 else 0, 0, 0),
				ZIndex = 94,
				Parent = line,
			})
			x += widths[index]
		end
	end
	row({ "JOUEUR", "BUTS", "PASSES D.", "ARRÊTS", "INTERC." }, 0, true)
	for index, entry in data.Table do
		row({
			`{entry.Name}{if entry.MVP then "  ·  MVP" else ""}`,
			tostring(entry.Goals),
			tostring(entry.Assists),
			tostring(entry.Saves),
			tostring(entry.Interceptions),
		}, index, false, entry.Team, entry.UserId == LocalPlayer.UserId)
	end

	-- Récompenses.
	local rewardsCard = Kit.surface({
		Color = C.Surface,
		Size = UDim2.new(0.36, 0, 1, -200),
		Position = UDim2.new(1, 0, 0, 190),
		AnchorPoint = Vector2.new(1, 0),
		Radius = Theme.RadiusLarge,
		ZIndex = 92,
		Parent = page,
	})
	local rewards = Kit.box({
		Size = UDim2.new(1, -48, 1, -48),
		Position = UDim2.fromOffset(24, 24),
		ZIndex = 93,
		Parent = rewardsCard,
	})
	Kit.list(rewards, 14)
	Kit.label({
		Text = "Récompenses",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.H3,
		Size = UDim2.new(1, 0, 0, 26),
		Order = 0,
		ZIndex = 94,
		Parent = rewards,
	})
	local function reward(label: string, value: string, order: number, valueColor: Color3?)
		local line = Kit.box({ Size = UDim2.new(1, 0, 0, 28), Order = order, ZIndex = 94, Parent = rewards })
		Kit.label({ Text = label, Color = C.TextMuted, Size = UDim2.fromScale(0.6, 1), ZIndex = 95, Parent = line })
		Kit.label({
			Text = value,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H3,
			Color = valueColor or C.Text,
			AlignX = Enum.TextXAlignment.Right,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 95,
			Parent = line,
		})
		Kit.reveal(line, 0.3 + order * 0.12, 8)
	end
	local summary = data.Rewards
	if summary then
		reward("Hand Coins", `+{Format.number(summary.Coins)}`, 1, C.Warning)
		reward("Expérience", `+{Format.number(summary.XP)} XP`, 2)
		if summary.LevelAfter > summary.LevelBefore then
			reward("Niveau", `{summary.LevelAfter}`, 3, C.Accent)
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
			reward("Cadeau de bienvenue", `{summary.FirstMatchBalls} balles`, 5, C.Accent)
		end
	elseif data.Training then
		reward("Entraînement", "aucune récompense", 1)
	end
	if data.MVP then
		reward("Joueur du match", data.MVP, 6)
	end

	local timer = Kit.label({
		Text = "",
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(400, 20),
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
