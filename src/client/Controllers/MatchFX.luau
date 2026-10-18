--!strict
-- Effets « animé » du match : cut-in des pouvoirs, BUUUT !!, onomatopées,
-- cartons, coups de sifflet, aveuglement, arrêt du temps, présentation des
-- équipes et écran de fin avec récompenses.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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

local gui: ScreenGui
local root: Frame
local bannerSlot: Frame

local ONOMATOPOEIA = {
	Shot = { "DOOON !", "BAM !", "ZUBAAN !", "SHUUUT !" },
	Fire = { "GOOOOO !!", "ZUDOOON !!", "BAKOOOM !!" },
	Contact = { "BAM !", "DOKA !", "GUSH !" },
	Pass = { "SHU !", "PAF !" },
	Dash = { "ZOOM !", "SHUN !" },
}

local function pick(list: { string }): string
	return list[math.random(1, #list)]
end

local function teamColor(team: string?): Color3
	if team and Theme.Team[team] then
		return Theme.Team[team].Main
	end
	return C.Yellow
end

-- Texte flottant au-dessus d'un personnage --------------------------------------------------------

local function popup(model: Model?, text: string, color: Color3, size: number?)
	if not model or not model.Parent then
		return
	end
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local billboard = Kit.new("BillboardGui", {
		Size = UDim2.fromOffset(260, 80),
		StudsOffset = Vector3.new(math.random(-15, 15) / 10, 3.5, 0),
		AlwaysOnTop = true,
		MaxDistance = 160,
		Adornee = head,
		Parent = LocalPlayer:WaitForChild("PlayerGui"),
	})
	local label = Kit.text({
		Text = text,
		Font = Theme.Fonts.Title,
		Color = color,
		Stroke = C.Ink,
		StrokeThickness = 4,
		Rotation = math.random(-12, 12),
		Parent = billboard,
	})
	label.Size = UDim2.fromScale(size or 1, size or 1)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	Kit.pop(label, 0.3)
	Kit.tween(
		billboard,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad),
		{ StudsOffset = billboard.StudsOffset + Vector3.new(0, 1.8, 0) }
	)
	task.delay(0.95, function()
		billboard:Destroy()
	end)
end

-- Bandeaux à l'écran ----------------------------------------------------------------------------------

local function banner(text: string, sub: string?, color: Color3, duration: number)
	Kit.clear(bannerSlot)
	local face, container = Kit.panel({
		Size = UDim2.fromOffset(700, if sub then 120 else 86),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = color,
		Rotation = -3,
		ShadowOffset = 8,
		StrokeThickness = 5,
		ZIndex = 40,
		Parent = bannerSlot,
	})
	Kit.text({
		Text = text,
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 4,
		Size = UDim2.new(1, -30, 0, 76),
		Position = UDim2.fromOffset(15, 6),
		ZIndex = 41,
		Parent = face,
	})
	if sub then
		Kit.text({
			Text = sub,
			Font = Theme.Fonts.Body,
			Color = C.Ink,
			Size = UDim2.new(1, -30, 0, 30),
			Position = UDim2.fromOffset(15, 82),
			ZIndex = 41,
			Parent = face,
		})
	end
	Kit.pop(container, 0.4)
	task.delay(duration, function()
		if container.Parent then
			Kit.tween(container, Theme.Tween.Slide, { Position = UDim2.new(1.6, 0, 0.5, 0) })
			task.wait(0.35)
			container:Destroy()
		end
	end)
end

local function flash(color: Color3, duration: number)
	local frame =
		Kit.new("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(1, 1), ZIndex = 90, Parent = root })
	Kit.tween(frame, TweenInfo.new(duration), { BackgroundTransparency = 1 })
	task.delay(duration, function()
		frame:Destroy()
	end)
end

local function cameraShake(strength: number, duration: number)
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local base = humanoid.CameraOffset
	task.spawn(function()
		local stop = os.clock() + duration
		while os.clock() < stop do
			local s = strength * (stop - os.clock()) / duration
			humanoid.CameraOffset = base + Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * s
			task.wait()
		end
		humanoid.CameraOffset = base
	end)
end

-- Lignes de vitesse (concentration) autour de l'écran.
local function speedLines(color: Color3, duration: number)
	local holder =
		Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = root })
	for i = 1, 28 do
		local angle = i / 28 * math.pi * 2
		local line = Kit.new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(math.random(220, 420), math.random(3, 8)),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.5 + math.cos(angle) * 0.62, 0, 0.5 + math.sin(angle) * 0.62, 0),
			Rotation = math.deg(angle) + 180,
			ZIndex = 30,
			Parent = holder,
		})
		local _ = line
	end
	task.delay(duration, function()
		holder:Destroy()
	end)
end

-- Cut-in de pouvoir (ultime en plein écran) ---------------------------------------------------------------

local function powerCutIn(data: any)
	local archetype = Archetypes.get(data.ArchetypeId)
	local power = archetype and archetype.Powers[data.Slot]
	if not archetype or not power then
		return
	end
	if data.Slot < 3 then
		popup(data.Model, `{string.upper(power.Name)} !`, power.Color, 1)
		return
	end
	Kit.playSound(Theme.Sounds.Ultimate, 0.9)
	local band = Kit.new("Frame", {
		BackgroundColor3 = archetype.Color,
		Size = UDim2.new(1.4, 0, 0, 230),
		Position = UDim2.new(-1.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Rotation = -6,
		ClipsDescendants = true,
		ZIndex = 60,
		Parent = root,
	})
	Kit.stroke(band, 8)
	local burst = Kit.sunburst(band, archetype.Color, Theme.shade(archetype.Color, 0.2), 16, true)
	burst.ZIndex = 60
	Kit.text({
		Text = archetype.Kanji,
		Font = Theme.Fonts.Heavy,
		Color = archetype.Accent,
		Stroke = C.Ink,
		StrokeThickness = 6,
		Size = UDim2.fromOffset(320, 260),
		Position = UDim2.new(0.18, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 62,
		Parent = band,
	})
	Kit.text({
		Text = `{string.upper(power.Name)} !!`,
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 6,
		Size = UDim2.fromOffset(820, 110),
		Position = UDim2.new(0.33, 0, 0.18, 0),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 62,
		Parent = band,
	})
	Kit.text({
		Text = `{power.Japanese}  ·  {data.Name}`,
		Font = Theme.Fonts.Heavy,
		Color = C.Ink,
		Size = UDim2.fromOffset(820, 44),
		Position = UDim2.new(0.33, 0, 0.66, 0),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 62,
		Parent = band,
	})
	speedLines(C.Paper, 1.2)
	Kit.tween(band, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { Position = UDim2.new(-0.2, 0, 0.5, 0) })
	task.delay(1.15, function()
		Kit.tween(
			band,
			TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
			{ Position = UDim2.new(1.2, 0, 0.5, 0) }
		)
		task.wait(0.3)
		band:Destroy()
	end)
	popup(data.Model, `{string.upper(power.Name)} !!`, power.Color, 1)
end

-- But ! -----------------------------------------------------------------------------------------------

local function goal(data: any)
	Kit.playSound(Theme.Sounds.Goal, 1)
	flash(C.White, 0.35)
	cameraShake(1.2, 0.6)
	local color = teamColor(data.Team)
	local holder =
		Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 70, Parent = root })
	local burstFrame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(1200, 520),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -4,
		ClipsDescendants = true,
		ZIndex = 70,
		Parent = holder,
	})
	local burst = Kit.sunburst(burstFrame, color, Theme.shade(color, 0.25), 20, true)
	burst.ZIndex = 70
	Kit.stroke(burstFrame, 8)
	local word = Kit.text({
		Text = if data.OwnGoal then "CONTRE SON CAMP !" else "BUUUT !!",
		Color = C.Yellow,
		Stroke = C.Ink,
		StrokeThickness = 8,
		Size = UDim2.fromOffset(1100, 260),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 72,
		Parent = holder,
	})
	Kit.pop(word, 0.2)
	Kit.text({
		Text = "ゴール！",
		Font = Theme.Fonts.Heavy,
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 4,
		Size = UDim2.fromOffset(400, 70),
		Position = UDim2.fromScale(0.72, 0.24),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 8,
		ZIndex = 72,
		Parent = holder,
	})
	local scorer = if data.Scorer then string.upper(data.Scorer) else ""
	local assist = if data.Assist then `   ·   passe : {data.Assist}` else ""
	Kit.text({
		Text = `{scorer}{assist}\nROUGE {data.Score.Rouge} – {data.Score.Bleu} BLEU`,
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 4,
		Size = UDim2.fromOffset(1000, 110),
		Position = UDim2.fromScale(0.5, 0.66),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 72,
		Parent = holder,
	})
	if data.ScorerModel then
		popup(data.ScorerModel, "BUUUT !!", C.Yellow, 1)
	end
	task.delay(Config.Match.GoalCelebrationTime - 0.6, function()
		Kit.tween(burstFrame, Theme.Tween.Slide, { Size = UDim2.fromOffset(1200, 0) })
		task.wait(0.4)
		holder:Destroy()
	end)
end

-- Effets d'écran ---------------------------------------------------------------------------------------------

local function blind(duration: number)
	local frame =
		Kit.new("Frame", { BackgroundColor3 = C.Ink, Size = UDim2.fromScale(1, 1), ZIndex = 80, Parent = root })
	Kit.text({
		Text = "AVEUGLÉ !",
		Color = C.Paper,
		Size = UDim2.fromOffset(500, 90),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 81,
		Parent = frame,
	})
	speedLines(C.Paper, duration)
	task.delay(math.max(0, duration - 0.6), function()
		Kit.tween(frame, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
		for _, child in frame:GetChildren() do
			if child:IsA("TextLabel") then
				Kit.tween(child, TweenInfo.new(0.6), { TextTransparency = 1 })
			end
		end
		task.wait(0.6)
		frame:Destroy()
	end)
end

local function timeStop(duration: number)
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Saturation = -1
	correction.Contrast = 0.25
	correction.Parent = Lighting
	local label = Kit.text({
		Text = "時よ止まれ",
		Font = Theme.Fonts.Heavy,
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 6,
		Size = UDim2.fromOffset(700, 140),
		Position = UDim2.fromScale(0.5, 0.3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 75,
		Parent = root,
	})
	Kit.pop(label, 0.3)
	task.delay(duration, function()
		correction:Destroy()
		label:Destroy()
	end)
end

local function card(data: any, color: Color3, label: string)
	local cardFrame = Kit.new("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(110, 150),
		Position = UDim2.new(0.5, -330, 0.32, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -12,
		ZIndex = 50,
		Parent = root,
	})
	Kit.stroke(cardFrame, 5)
	Kit.pop(cardFrame, 0.2)
	banner(label, data.Name, color, 2.4)
	task.delay(2.4, function()
		cardFrame:Destroy()
	end)
end

-- Présentation et coups d'envoi --------------------------------------------------------------------------

local function intro(data: any)
	local match = State.Match
	if not match then
		return
	end
	local holder =
		Kit.new("Frame", { BackgroundColor3 = C.Ink, Size = UDim2.fromScale(1, 1), ZIndex = 85, Parent = root })
	for index, team in { "Rouge", "Bleu" } do
		local side = Kit.new("Frame", {
			BackgroundColor3 = Theme.Team[team].Main,
			Size = UDim2.new(0.56, 0, 1.2, 0),
			Position = UDim2.new(if index == 1 then -0.6 else 1.04, 0, -0.1, 0),
			Rotation = 6,
			ClipsDescendants = true,
			ZIndex = 86,
			Parent = holder,
		})
		Kit.stroke(side, 8)
		Kit.sunburst(side, Theme.Team[team].Main, Theme.shade(Theme.Team[team].Main, 0.15), 14, true).ZIndex = 86
		local list = Kit.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0.8, 0, 0.6, 0),
			Position = UDim2.fromScale(0.1, 0.2),
			ZIndex = 87,
			Parent = side,
		})
		Kit.list(list, 10)
		Kit.text({
			Text = `ÉQUIPE {string.upper(team)}`,
			Color = C.Paper,
			Stroke = C.Ink,
			StrokeThickness = 4,
			Size = UDim2.new(1, 0, 0, 80),
			Order = 0,
			ZIndex = 88,
			Parent = list,
		})
		local order = 0
		for _, participant in match.Participants do
			if participant.Team == team then
				order += 1
				local archetype = Archetypes.get(participant.Archetype)
				Kit.text({
					Text = `#{participant.Number} {participant.Name}{if archetype
						then "  ·  " .. archetype.Name
						else ""}`,
					Font = Theme.Fonts.Title,
					Color = C.Paper,
					Stroke = C.Ink,
					StrokeThickness = 3,
					Size = UDim2.new(1, 0, 0, 44),
					Order = order,
					ZIndex = 88,
					Parent = list,
				})
			end
		end
		Kit.tween(side, Theme.Tween.Slide, { Position = UDim2.new(if index == 1 then -0.06 else 0.5, 0, -0.1, 0) })
	end
	local versus = Kit.text({
		Text = "VS",
		Color = C.Yellow,
		Stroke = C.Ink,
		StrokeThickness = 8,
		Size = UDim2.fromOffset(300, 220),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 95,
		Parent = holder,
	})
	task.delay(0.35, function()
		Kit.pop(versus, 0.1)
		cameraShake(0.8, 0.4)
	end)
	local mode = Config.Modes[data.Mode]
	Kit.text({
		Text = `{if mode then mode.Label else ""}{if data.Ranked
			then " · CLASSÉ"
			elseif data.Training then " · ENTRAÎNEMENT"
			else ""}`,
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 4,
		Size = UDim2.fromOffset(700, 60),
		Position = UDim2.new(0.5, 0, 0.88, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 95,
		Parent = holder,
	})
	task.delay(3.6, function()
		Kit.tween(holder, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		task.wait(0.3)
		holder:Destroy()
	end)
end

local function countdown(seconds: number)
	task.spawn(function()
		for i = seconds, 1, -1 do
			local label = Kit.text({
				Text = tostring(i),
				Color = C.Yellow,
				Stroke = C.Ink,
				StrokeThickness = 8,
				Size = UDim2.fromOffset(240, 200),
				Position = UDim2.fromScale(0.5, 0.38),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 60,
				Parent = root,
			})
			Kit.pop(label, 2)
			task.wait(0.95)
			label:Destroy()
		end
		local go = Kit.text({
			Text = "HAJIME ! 始め",
			Color = C.Red,
			Stroke = C.Ink,
			StrokeThickness = 8,
			Size = UDim2.fromOffset(800, 180),
			Position = UDim2.fromScale(0.5, 0.38),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 60,
			Parent = root,
		})
		Kit.pop(go, 0.4)
		task.wait(0.8)
		go:Destroy()
	end)
end

-- Écran de fin ------------------------------------------------------------------------------------------

local function endScreen(data: any)
	local outcome = data.Outcome
	local title = if outcome == "Win" then "VICTOIRE !!" elseif outcome == "Loss" then "DÉFAITE…" else "ÉGALITÉ"
	local color = if outcome == "Win" then C.Yellow elseif outcome == "Loss" then C.Steel else C.Blue
	local holder =
		Kit.new("Frame", { BackgroundColor3 = C.Night, Size = UDim2.fromScale(1, 1), ZIndex = 100, Parent = root })
	Kit.sunburst(holder, C.Night, Theme.shade(color, -0.5), 22, true).ZIndex = 100
	local titleLabel = Kit.text({
		Text = title,
		Color = color,
		Stroke = C.Ink,
		StrokeThickness = 8,
		Size = UDim2.fromOffset(1000, 170),
		Position = UDim2.new(0.5, 0, 0, 110),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -3,
		ZIndex = 102,
		Parent = holder,
	})
	Kit.pop(titleLabel, 0.2)
	Kit.text({
		Text = `ROUGE {data.Score.Rouge} – {data.Score.Bleu} BLEU{if data.Forfeit then "  (forfait)" else ""}`,
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 4,
		Size = UDim2.fromOffset(800, 60),
		Position = UDim2.new(0.5, 0, 0, 210),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 102,
		Parent = holder,
	})

	-- Tableau des joueurs.
	local tableFace, _ = Kit.panel({
		Size = UDim2.fromOffset(760, 400),
		Position = UDim2.new(0.5, -400, 0, 260),
		Color = C.Paper,
		ZIndex = 102,
		Parent = holder,
	})
	local list = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 1, -24),
		Position = UDim2.fromOffset(12, 12),
		ZIndex = 103,
		Parent = tableFace,
	})
	Kit.list(list, 4)
	local header = Kit.text({
		Text = "JOUEUR                                  BUTS · PD · ARRÊTS · INTER.",
		Font = Theme.Fonts.Heavy,
		Size = UDim2.new(1, 0, 0, 26),
		AlignX = Enum.TextXAlignment.Left,
		Order = 0,
		ZIndex = 104,
		Parent = list,
	})
	local _ = header
	for index, row in data.Table do
		local line = Kit.new("Frame", {
			BackgroundColor3 = if row.UserId == LocalPlayer.UserId then C.Yellow else teamColor(row.Team),
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = index,
			ZIndex = 104,
			Parent = list,
		})
		Kit.stroke(line, 2)
		Kit.text({
			Text = `{if row.MVP then "★ " else ""}{row.Name}`,
			Font = Theme.Fonts.Body,
			Color = if row.UserId == LocalPlayer.UserId then C.Ink else C.Paper,
			Size = UDim2.new(0.55, 0, 1, -6),
			Position = UDim2.fromOffset(10, 3),
			AlignX = Enum.TextXAlignment.Left,
			ZIndex = 105,
			Parent = line,
		})
		Kit.text({
			Text = `{row.Goals}  ·  {row.Assists}  ·  {row.Saves}  ·  {row.Interceptions}`,
			Font = Theme.Fonts.Heavy,
			Color = if row.UserId == LocalPlayer.UserId then C.Ink else C.Paper,
			Size = UDim2.new(0.4, 0, 1, -6),
			Position = UDim2.new(0.58, 0, 0, 3),
			ZIndex = 105,
			Parent = line,
		})
	end

	-- Récompenses.
	local rewards = data.Rewards
	local rewardFace, rewardContainer = Kit.panel({
		Size = UDim2.fromOffset(360, 400),
		Position = UDim2.new(0.5, 380, 0, 260),
		Color = C.Yellow,
		ZIndex = 102,
		Parent = holder,
	})
	Kit.header(rewardFace, "RÉCOMPENSES", C.Red)
	local rewardList = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -30, 1, -70),
		Position = UDim2.fromOffset(15, 56),
		ZIndex = 103,
		Parent = rewardFace,
	})
	Kit.list(rewardList, 10)
	local function line(text: string, order: number, textColor: Color3?)
		Kit.text({
			Text = text,
			Color = textColor or C.Ink,
			Size = UDim2.new(1, 0, 0, 40),
			AlignX = Enum.TextXAlignment.Left,
			Order = order,
			ZIndex = 104,
			Parent = rewardList,
		})
	end
	if data.MVP then
		line(`★ MVP : {data.MVP}`, 0, C.Red)
	end
	if rewards then
		line(`+{Format.number(rewards.Coins)} HAND COINS`, 1)
		line(`+{Format.number(rewards.XP)} XP`, 2)
		if rewards.LevelAfter > rewards.LevelBefore then
			line(`NIVEAU {rewards.LevelAfter} !`, 3, C.Purple)
		end
		if data.Ranked then
			local rank = Progression.getRank(rewards.RPAfter)
			line(`{if rewards.RPChange >= 0 then "+" else ""}{rewards.RPChange} RP · {rank.Name}`, 4, rank.Color)
		end
		if rewards.FirstMatchBalls > 0 then
			line(`CADEAU : {rewards.FirstMatchBalls} BALLES !`, 5, C.Red)
		end
	elseif data.Training then
		line("Entraînement : pas de récompense", 1)
	end
	Kit.pop(rewardContainer, 0.5)

	local timer = Kit.text({
		Text = "",
		Font = Theme.Fonts.Body,
		Color = C.Paper,
		Size = UDim2.fromOffset(600, 30),
		Position = UDim2.new(0.5, 0, 1, -40),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 102,
		Parent = holder,
	})
	task.spawn(function()
		local remaining = Config.Match.EndScreenTime
		while remaining > 0 and holder.Parent do
			timer.Text = `Retour au lobby dans {remaining} s`
			task.wait(1)
			remaining -= 1
		end
	end)
	local connection
	connection = State.MatchEvent:Connect(function(kind)
		if kind == "Leave" then
			holder:Destroy()
			connection:Disconnect()
		end
	end)
	task.delay(Config.Match.EndScreenTime + 15, function()
		if holder.Parent then
			holder:Destroy()
		end
	end)
end

-- Routage des événements ------------------------------------------------------------------------------

local SET_PIECE_COLORS =
	{ Penalty = C.Red, FreeThrow = C.Blue, ThrowIn = C.Green, Corner = C.Purple, GoalThrow = C.Steel }

local function onEvent(kind: string, data: any)
	data = data or {}
	if kind == "Power" then
		powerCutIn(data)
	elseif kind == "Goal" then
		goal(data)
	elseif kind == "Shot" then
		popup(
			data.Model,
			pick(if data.Fire or data.Powered then ONOMATOPOEIA.Fire else ONOMATOPOEIA.Shot),
			if data.Fire then C.Red else C.Yellow,
			if data.Charge > 0.8 then 1.2 else 0.9
		)
		Kit.playSound(Theme.Sounds.Shot, 0.7)
	elseif kind == "Pass" then
		Kit.playSound(Theme.Sounds.Pass, 0.4)
	elseif kind == "Dash" then
		if data.Model ~= LocalPlayer.Character then
			popup(data.Model, pick(ONOMATOPOEIA.Dash), C.Paper, 0.7)
		end
	elseif kind == "Contact" then
		popup(data.To, pick(ONOMATOPOEIA.Contact), C.Red, 1)
		if data.To == LocalPlayer.Character then
			cameraShake(0.6, 0.3)
		end
	elseif kind == "Whiff" then
		popup(data.Model, "RATÉ…", C.Paper, 0.7)
	elseif kind == "InterceptStance" then
		popup(data.Model, "!", C.Yellow, 0.8)
	elseif kind == "Interception" then
		popup(data.Model, "INTERCEPTÉ !", C.Yellow, 1)
	elseif kind == "Steal" then
		popup(data.Model, "VOLÉ !", C.Yellow, 1)
	elseif kind == "Save" then
		popup(data.Model, if data.Parried then "REPOUSSÉ !" else "ARRÊT !!", C.Green, 1.1)
	elseif kind == "Block" then
		popup(data.Model, "CONTRE !", C.Blue, 1)
	elseif kind == "WallBlock" then
		banner("MUR !", "Le tir s'écrase sur le pouvoir du gardien", C.Blue, 1.4)
	elseif kind == "Popup" then
		local color = if data.Style == "Danger" then C.Red elseif data.Style == "Gold" then C.Yellow else C.Paper
		popup(data.Model, data.Text, color, 1)
	elseif kind == "SetPiece" then
		Kit.playSound(Theme.Sounds.Whistle, 0.7)
		if data.Kind ~= "ThrowOff" then
			banner(data.Label, data.Reason, SET_PIECE_COLORS[data.Kind] or C.Blue, 1.6)
		end
	elseif kind == "Violation" then
		Kit.playSound(Theme.Sounds.Whistle, 0.8)
		popup(data.Model, "ピーッ !", C.Paper, 0.8)
	elseif kind == "Foul" then
		popup(data.Victim, "FAUTE !", C.Red, 1)
	elseif kind == "YellowCard" then
		card(data, C.Yellow, "AVERTISSEMENT")
	elseif kind == "Suspension" then
		card(data, C.Paper, `EXCLUSION {math.floor(data.Duration or Config.Rules.SuspensionTime)} s`)
	elseif kind == "RedCard" then
		card(data, C.Red, "CARTON ROUGE !")
	elseif kind == "Return" then
		popup(data.Model, "DE RETOUR !", C.Green, 0.9)
	elseif kind == "PassiveWarning" then
		banner("JEU PASSIF", "L'arbitre lève le bras : tirez vite !", C.Yellow, 1.8)
	elseif kind == "Blind" then
		blind(data.Duration or 2)
	elseif kind == "TimeStop" then
		timeStop(data.Duration or 3)
	elseif kind == "Blink" then
		if typeof(data.From) == "Vector3" then
			local ghost = Instance.new("Part")
			ghost.Anchored = true
			ghost.CanCollide = false
			ghost.CanQuery = false
			ghost.Material = Enum.Material.Neon
			ghost.Color = C.Paper
			ghost.Size = Vector3.new(2, 5, 1)
			ghost.CFrame = CFrame.new(data.From)
			ghost.Parent = Workspace
			task.spawn(function()
				for i = 1, 10 do
					ghost.Transparency = i / 10
					ghost.Size = Vector3.new(2 - i * 0.18, 5 + i * 0.3, 1)
					task.wait(0.03)
				end
				ghost:Destroy()
			end)
		end
	elseif kind == "Intro" then
		intro(data)
	elseif kind == "ThrowOff" then
		countdown(data.Countdown or 3)
	elseif kind == "Halftime" then
		banner(
			"MI-TEMPS",
			`ROUGE {data.Score.Rouge} – {data.Score.Bleu} BLEU  ·  changement de côté`,
			C.Purple,
			(data.Duration or 10) - 1
		)
	elseif kind == "GoldenGoal" then
		banner("BUT EN OR !", "Le prochain but gagne le match !", C.Yellow, 2.5)
	elseif kind == "Left" then
		State.Notify:Fire(`{data.Name} a quitté le match.`, "Danger")
	elseif kind == "End" then
		endScreen(data)
	end
end

function MatchFX.start()
	gui = Kit.screen("EffetsMatch", 30, LocalPlayer:WaitForChild("PlayerGui"))
	root = Kit.root(gui)
	bannerSlot = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(800, 160),
		Position = UDim2.new(0.5, 0, 0.26, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 40,
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
