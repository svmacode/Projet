--!strict
-- Ouverture d'une balle ou d'un pack cosmétique :
--   1. la balle arrive, tremble de plus en plus fort et brille ;
--   2. elle s'ouvre dans un éclair de la couleur de la rareté, avec des
--      rayons qui tournent lentement derrière ;
--   3. la carte apparaît avec un rebond, la rareté s'affiche au-dessus.
-- PackOpening.play attend que le joueur appuie sur « Continuer ».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Cards = require(script.Parent.Parent.UI.Cards)
local Kit = require(script.Parent.Parent.UI.Kit)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local PackOpening = {}

local root: Frame? = nil

local function getRoot(): Frame
	if not root then
		local _, frame = Kit.screen("Ouverture", 80, Players.LocalPlayer:WaitForChild("PlayerGui"))
		root = frame
	end
	return root :: Frame
end

-- Balle de handball dessinée : sphère en dégradé, deux coutures, reflet.
-- Réutilisée par l'écran Archétypes.
function PackOpening.ball(parent: Instance, size: number, color: Color3, accent: Color3, z: number): Frame
	local ball = Kit.new("Frame", {
		Name = "Balle",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
		ZIndex = z,
		Parent = parent,
	})
	Kit.round(ball)
	Kit.gradient(ball, Theme.lighten(color, 0.45), Theme.darken(color, 0.15), 50)
	Kit.border(ball, C.White, math.max(2, size / 36))
	for _, rotation in { 30, -30 } do
		local seam = Kit.new("Frame", {
			Name = "Couture",
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.98, 0, 0, math.max(3, size / 16)),
			Rotation = rotation,
			ZIndex = z + 1,
			Parent = ball,
		})
		Kit.round(seam)
	end
	local ring = Kit.new("Frame", {
		Name = "Anneau",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.56, 0.56),
		ZIndex = z + 1,
		Parent = ball,
	})
	Kit.round(ring)
	Kit.border(ring, accent, math.max(2, size / 22))
	local shine = Kit.new("Frame", {
		Name = "Reflet",
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.2, 0.14),
		Size = UDim2.fromScale(0.26, 0.16),
		Rotation = -30,
		ZIndex = z + 2,
		Parent = ball,
	})
	Kit.round(shine)
	return ball
end

local function flash(parent: Instance, color: Color3, duration: number, z: number)
	local frame = Kit.new("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = parent,
	})
	Kit.tween(frame, TweenInfo.new(duration, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	task.delay(duration, function()
		frame:Destroy()
	end)
end

-- Rayons de lumière qui tournent derrière la carte.
local function rays(parent: Instance, color: Color3, count: number, z: number): Frame
	local holder = Kit.box({
		Size = UDim2.fromOffset(1400, 1400),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = z,
		Parent = parent,
	})
	for index = 1, count do
		local ray = Kit.new("Frame", {
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 70, 1, 0),
			Rotation = (index / count) * 180,
			ZIndex = z,
			Parent = holder,
		})
		Kit.new("UIGradient", {
			Color = ColorSequence.new(Theme.lighten(color, 0.6), color),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 90,
			Parent = ray,
		})
	end
	Kit.tween(holder, TweenInfo.new(24, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 360 })
	return holder
end

function PackOpening.play(result: any, ballColor: Color3?, ballAccent: Color3?)
	local parent = getRoot()
	local info = Rarities.get(result.Rarity)
	local rarityColor = if info then info.Color else C.TextMuted
	local tier = if info then info.Rank else 1

	local overlay = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		Parent = parent,
	})
	local back = Kit.backdrop(overlay, C.Sky, 100)
	local stage = Kit.box({
		Size = UDim2.fromOffset(600, 600),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 102,
		Parent = overlay,
	})

	-- 1. Anticipation : la balle tombe, puis tremble de plus en plus.
	local ballSize = 220
	local ball = PackOpening.ball(stage, ballSize, ballColor or C.Accent, ballAccent or C.White, 104)
	ball.AnchorPoint = Vector2.new(0.5, 0.5)
	ball.Position = UDim2.fromScale(0.5, -0.4)
	Kit.tween(ball, Theme.Motion.Bounce, { Position = UDim2.fromScale(0.5, 0.5) })
	Kit.playSound(Theme.Sounds.Reveal, 0.5)
	local glow = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(ballSize, ballSize),
		ZIndex = 103,
		Parent = stage,
	})
	Kit.round(glow)
	task.wait(0.5)
	Kit.tween(glow, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.fromOffset(ballSize * 1.9, ballSize * 1.9),
		BackgroundTransparency = 0.4,
	})
	local shakeEnd = os.clock() + 1.3
	while os.clock() < shakeEnd and overlay.Parent do
		local progress = 1 - (shakeEnd - os.clock()) / 1.3
		local power = 2 + progress * 12
		ball.Position = UDim2.new(0.5, math.random(-power, power), 0.5, math.random(-power, power))
		ball.Rotation = math.random(-power, power)
		task.wait(0.03)
	end
	if not overlay.Parent then
		return
	end

	-- 2. Ouverture.
	ball:Destroy()
	glow:Destroy()
	flash(overlay, C.White, 0.5, 120)
	back:Destroy()
	local revealBack = Kit.backdrop(overlay, rarityColor, 100)
	rays(revealBack, rarityColor, 6 + tier * 2, 100)

	-- 3. Carte et rareté.
	local cardHolder = Kit.box({
		Size = UDim2.fromOffset(250, 340),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 110,
		Parent = stage,
	})
	local title = ""
	if result.Kind == "Archetype" then
		local archetype = Archetypes.get(result.Id)
		if archetype then
			Cards.archetype(cardHolder, archetype, { Size = UDim2.fromScale(1, 1), ZIndex = 111 })
			title = archetype.Name
		end
	else
		local item = Cosmetics.get(result.Id)
		if item then
			Cards.cosmetic(cardHolder, item, { Size = UDim2.fromScale(1, 1), ZIndex = 111 })
			title = item.Name
		end
	end
	Kit.slam(cardHolder, 0.3)
	if tier >= 4 then
		task.delay(0.15, function()
			Kit.shake(stage, 2 + tier, 0.3)
		end)
	end

	local rarityTitle = Kit.title({
		Text = string.upper(if info then info.Name else result.Rarity),
		TextSize = 64 + tier * 6,
		Color = C.White,
		StrokeColor = Theme.darken(rarityColor, 0.4),
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(1000, 110),
		Position = UDim2.new(0.5, 0, 0.5, -280),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 112,
		Parent = overlay,
	})
	task.delay(0.08, function()
		Kit.slam(rarityTitle.Instance, 1.6)
	end)

	local card = Kit.surface({
		Transparency = 0.02,
		BorderColor = C.White,
		BorderThickness = 3,
		Radius = 20,
		Size = UDim2.fromOffset(520, 80),
		Position = UDim2.new(0.5, 0, 0.5, 240),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 112,
		Parent = overlay,
	})
	Kit.label({
		Text = title,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H2,
		Color = C.Text,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 34),
		Position = UDim2.fromOffset(10, 10),
		ZIndex = 113,
		Parent = card,
	})
	local status = if result.Duplicate then `Déjà possédé · +{result.Refund} Hand Coins` else "Nouveau !"
	if result.Pity then
		status ..= "  ·  garantie activée"
	end
	Kit.label({
		Text = status,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Body,
		Color = if result.Duplicate then C.AccentDark else C.Success,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 46),
		ZIndex = 113,
		Parent = card,
	})
	Kit.reveal(card, 0.25)

	local closed = false
	local continueButton = Kit.button({
		Text = "CONTINUER",
		Variant = "Primary",
		TextSize = Theme.Text.H3,
		Size = UDim2.fromOffset(240, 56),
		Position = UDim2.new(0.5, 0, 1, -64),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 114,
		Parent = overlay,
		OnClick = function()
			closed = true
		end,
	})
	continueButton.Instance.Visible = false
	task.delay(0.6, function()
		continueButton.Instance.Visible = true
		Kit.pop(continueButton.Instance, 0.6)
	end)
	while not closed and overlay.Parent do
		task.wait(0.05)
	end
	overlay:Destroy()
end

return PackOpening
