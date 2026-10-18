--!strict
-- Ouverture d'une balle ou d'un pack : la balle tremble, s'ouvre dans la
-- couleur de la rareté, puis la carte se retourne.

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

-- Balle dessinée (cercle + coutures), réutilisée par la boutique.
function PackOpening.ball(parent: Instance, size: number, color: Color3, accent: Color3, z: number): Frame
	local ball = Kit.new("Frame", {
		Name = "Balle",
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(size, size),
		ZIndex = z,
		Parent = parent,
	})
	Kit.corner(ball, size)
	Kit.new("UIGradient", {
		Color = ColorSequence.new(Theme.lighten(color, 0.25), Theme.darken(color, 0.25)),
		Rotation = 60,
		Parent = ball,
	})
	for _, rotation in { 28, -28 } do
		Kit.new("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, math.max(3, size / 22)),
			Rotation = rotation,
			ZIndex = z + 1,
			Parent = ball,
		})
	end
	return ball
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
	local stage = Kit.box({
		Size = UDim2.fromOffset(600, 600),
		Position = UDim2.fromScale(0.5, 0.48),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 101,
		Parent = overlay,
	})

	-- 1. Anticipation.
	local ball = PackOpening.ball(stage, 200, ballColor or C.Accent, ballAccent or C.White, 102)
	ball.AnchorPoint = Vector2.new(0.5, 0.5)
	ball.Position = UDim2.fromScale(0.5, 0.5)
	Kit.pop(ball, 0.6)
	Kit.playSound(Theme.Sounds.Reveal, 0.5)
	local duration = 1 + tier * 0.12
	local stop = os.clock() + duration
	while os.clock() < stop do
		local progress = 1 - (stop - os.clock()) / duration
		local amount = 2 + progress * (4 + tier * 2)
		ball.Rotation = math.sin(os.clock() * 40) * amount
		ball.Position = UDim2.new(0.5, math.random(-amount, amount) * 0.6, 0.5, 0)
		task.wait(1 / 60)
	end

	-- 2. Ouverture : un disque de la couleur de la rareté s'agrandit.
	local burst = Kit.new("Frame", {
		BackgroundColor3 = rarityColor,
		Size = UDim2.fromOffset(200, 200),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 101,
		Parent = stage,
	})
	Kit.corner(burst, 1000)
	ball:Destroy()
	Kit.tween(burst, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { Size = UDim2.fromOffset(1400, 1400) })
	task.wait(0.25)
	local ring = Kit.new("Frame", {
		BackgroundColor3 = C.Background,
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 101,
		Parent = stage,
	})
	Kit.corner(ring, 1000)
	Kit.tween(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Size = UDim2.fromOffset(1500, 1500) })

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
	-- Retournement : la carte s'élargit depuis une fine tranche.
	cardHolder.Size = UDim2.fromOffset(8, 350)
	task.wait(0.15)
	Kit.tween(cardHolder, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(260, 350) })

	Kit.label({
		Text = string.upper(if info then info.Name else result.Rarity),
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H1,
		Color = rarityColor,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(600, 44),
		Position = UDim2.new(0.5, 0, 0.5, -230),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 112,
		Parent = overlay,
	})
	local status = if result.Duplicate then `Déjà possédé · +{result.Refund} Hand Coins` else "Nouveau"
	if result.Pity then
		status ..= "  ·  garantie activée"
	end
	Kit.label({
		Text = `{title}\n<font color="#{C.TextMuted:ToHex()}">{status}</font>`,
		Rich = true,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.H3,
		AlignX = Enum.TextXAlignment.Center,
		Wrap = true,
		Size = UDim2.fromOffset(600, 60),
		Position = UDim2.new(0.5, 0, 0.5, 220),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 112,
		Parent = overlay,
	})
	local closed = false
	Kit.button({
		Text = "Continuer",
		Variant = "Primary",
		Size = UDim2.fromOffset(220, 52),
		Position = UDim2.new(0.5, 0, 1, -80),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 113,
		Parent = overlay,
		OnClick = function()
			closed = true
		end,
	})
	while not closed and overlay.Parent do
		task.wait(0.05)
	end
	overlay:Destroy()
end

return PackOpening
