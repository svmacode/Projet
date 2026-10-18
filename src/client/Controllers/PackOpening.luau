--!strict
-- Ouverture d'une balle ou d'un pack, façon tirage d'animé :
--   1. anticipation : la balle tremble de plus en plus, les lignes de vitesse
--      accélèrent, puis flash blanc ;
--   2. explosion dans la couleur de la rareté, rayons qui tournent ;
--   3. la carte claque à l'écran, nom de rareté géant en lettrage BD.

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

-- Balle dessinée (cercle dégradé cerclé d'encre + coutures + reflet),
-- réutilisée par la boutique.
function PackOpening.ball(parent: Instance, size: number, color: Color3, accent: Color3, z: number): Frame
	local ball = Kit.new("Frame", {
		Name = "Balle",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
		ZIndex = z,
		Parent = parent,
	})
	Kit.corner(ball, size)
	Kit.border(ball, C.Ink, math.max(2, size / 40))
	Kit.gradient(ball, Theme.lighten(color, 0.35), Theme.darken(color, 0.35), 55)
	-- Coutures en croix légèrement courbées (deux traits inclinés + un central).
	for index, rotation in { 32, -32, 90 } do
		local seam = Kit.new("Frame", {
			Name = "Couture",
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(if index == 3 then 0.98 else 0.9, 0, 0, math.max(3, size / 18)),
			Rotation = rotation,
			ZIndex = z + 1,
			Parent = ball,
		})
		Kit.corner(seam, size)
		Kit.border(seam, C.Ink, math.max(1, size / 90))
	end
	-- Reflet.
	local gloss = Kit.new("Frame", {
		Name = "Reflet",
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.26, 0.18),
		Position = UDim2.fromScale(0.2, 0.14),
		Rotation = -30,
		ZIndex = z + 2,
		Parent = ball,
	})
	Kit.corner(gloss, size)
	return ball
end

-- Rayons qui tournent autour du centre (soleil d'animé).
local function rays(parent: Instance, color: Color3, count: number, z: number, speed: number): Frame
	local hub = Kit.box({
		Name = "Rayons",
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = z,
		Parent = parent,
	})
	for index = 1, count do
		local ray = Kit.new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(if index % 2 == 0 then 46 else 22, 1800),
			Rotation = index * 180 / count,
			ZIndex = z,
			Parent = hub,
		})
		Kit.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.15),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = ray,
		})
	end
	Kit.tween(
		hub,
		TweenInfo.new(speed, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
		{ Rotation = if speed > 0 then 360 else -360 }
	)
	return hub
end

local function flash(parent: Instance, color: Color3, z: number, duration: number)
	local frame = Kit.new("Frame", {
		BackgroundColor3 = color,
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

function PackOpening.play(result: any, ballColor: Color3?, ballAccent: Color3?)
	local parent = getRoot()
	local info = Rarities.get(result.Rarity)
	local rarityColor = if info then info.Color else C.TextMuted
	local tier = if info then info.Rank else 1

	local overlay = Kit.new("Frame", {
		BackgroundColor3 = C.Background,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		Parent = parent,
	})
	local backdrop = Kit.backdrop(overlay, C.Violet, 100)
	local stage = Kit.box({
		Size = UDim2.fromOffset(600, 600),
		Position = UDim2.fromScale(0.5, 0.48),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 101,
		Parent = overlay,
	})

	-- 1. Anticipation.
	local ballSize = 220
	local ball = PackOpening.ball(stage, ballSize, ballColor or C.Accent, ballAccent or C.White, 104)
	ball.AnchorPoint = Vector2.new(0.5, 0.5)
	ball.Position = UDim2.fromScale(0.5, 0.5)
	local scale = Kit.new("UIScale", { Parent = ball })
	Kit.slam(ball, 0.2)
	Kit.playSound(Theme.Sounds.Reveal, 0.5)
	local fast: Frame? = nil
	local duration = 1.1 + tier * 0.15
	local stop = os.clock() + duration
	while os.clock() < stop and overlay.Parent do
		local progress = 1 - (stop - os.clock()) / duration
		local amount = 2 + progress * (5 + tier * 2.5)
		ball.Rotation = math.sin(os.clock() * (30 + progress * 40)) * amount
		ball.Position = UDim2.new(0.5, math.random(-amount, amount) * 0.7, 0.5, math.random(-amount, amount) * 0.3)
		scale.Scale = 1 + progress * 0.18
		-- Les lignes de vitesse accélèrent à mi-parcours.
		if progress > 0.45 and not fast then
			fast = Kit.speedLines({
				Parent = overlay,
				Color = rarityColor,
				Count = 18 + tier * 4,
				Transparency = 0.55,
				Speed = 0.35,
				ZIndex = 102,
			})
		end
		task.wait(1 / 60)
	end

	-- 2. Explosion.
	flash(overlay, C.White, 130, 0.35)
	ball:Destroy()
	if fast then
		fast:Destroy()
	end
	backdrop:Destroy()
	Kit.backdrop(overlay, rarityColor, 100)
	local burst = Kit.new("Frame", {
		BackgroundColor3 = rarityColor,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(200, 200),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 101,
		Parent = stage,
	})
	Kit.corner(burst, 1000)
	Kit.tween(
		burst,
		TweenInfo.new(0.5, Enum.EasingStyle.Quint),
		{ Size = UDim2.fromOffset(1500, 1500), BackgroundTransparency = 1 }
	)
	local ring = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 102,
		Parent = stage,
	})
	Kit.corner(ring, 1000)
	local ringStroke = Kit.border(ring, C.White, 14)
	Kit.tween(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { Size = UDim2.fromOffset(1100, 1100) })
	Kit.tween(ringStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { Transparency = 1, Thickness = 2 })
	rays(stage, rarityColor, 10, 101, 9)
	if tier >= 4 then
		rays(stage, C.White, 6, 101, -14)
	end
	Kit.speedLines({
		Parent = overlay,
		Color = C.White,
		Count = 10 + tier * 2,
		Transparency = 0.7,
		Speed = 0.6,
		ZIndex = 101,
	})

	-- 3. Carte.
	local cardHolder = Kit.box({
		Size = UDim2.fromOffset(260, 350),
		Position = UDim2.fromScale(0.5, 0.5),
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
	cardHolder.Rotation = -8
	Kit.slam(cardHolder, 2.6)
	Kit.tween(cardHolder, Theme.Motion.Slam, { Rotation = -2 })
	task.delay(0.18, function()
		Kit.shake(stage, 4 + tier * 2, 0.3)
	end)

	local rarityTitle = Kit.title({
		Text = string.upper(if info then info.Name else result.Rarity),
		TextSize = 96 + tier * 4,
		Color = C.White,
		ShadowColor = rarityColor,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(900, 120),
		Position = UDim2.new(0.5, 0, 0.5, -270),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -4,
		ZIndex = 112,
		Parent = overlay,
	})
	task.delay(0.1, function()
		Kit.slam(rarityTitle.Instance, 2)
	end)

	local status = if result.Duplicate then `Déjà possédé · +{result.Refund} Hand Coins` else "NOUVEAU !"
	if result.Pity then
		status ..= "  ·  garantie activée"
	end
	local plate = Kit.plate({
		Color = C.Ink,
		BorderColor = rarityColor,
		Size = UDim2.fromOffset(520, 72),
		Position = UDim2.new(0.5, 0, 0.5, 236),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 2,
		ShadowColor = rarityColor,
		ZIndex = 112,
		Parent = overlay,
	})
	Kit.label({
		Text = string.upper(title),
		Font = Theme.Fonts.Hero,
		TextSize = 34,
		Color = C.White,
		Stroke = 2,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 38),
		Position = UDim2.fromOffset(10, 4),
		ZIndex = 113,
		Parent = plate,
	})
	Kit.label({
		Text = status,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Body,
		Color = if result.Duplicate then C.Accent else C.Lime,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 42),
		ZIndex = 113,
		Parent = plate,
	})
	Kit.reveal(plate, 0.25)

	local closed = false
	local continueButton = Kit.button({
		Text = "CONTINUER",
		Variant = "Primary",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H3 + 2,
		Size = UDim2.fromOffset(240, 56),
		Position = UDim2.new(0.5, 0, 1, -70),
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
