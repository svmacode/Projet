--!strict
-- Ouverture d'une Balle ou d'un Pack Cosmétique : anticipation (la balle
-- tremble), éclat, puis révélation de la carte avec rayons de la rareté.

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

local gui: ScreenGui? = nil

local function ensureGui(): Frame
	if not gui then
		gui = Kit.screen("OuverturePack", 80, Players.LocalPlayer:WaitForChild("PlayerGui"))
	end
	return Kit.root(gui :: ScreenGui)
end

-- `result` vient du serveur : { Kind, Id, Rarity, Duplicate, Refund, Pity }.
function PackOpening.play(result: any, ballColor: Color3?, ballAccent: Color3?)
	local root = ensureGui()
	local rarityInfo = Rarities.get(result.Rarity)
	local rarityColor = if rarityInfo then rarityInfo.Color else C.Steel
	local rank = if rarityInfo then rarityInfo.Rank else 1

	local overlay = Kit.new("Frame", {
		Name = "Ouverture",
		BackgroundColor3 = C.Night,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		Parent = root,
	})
	local burst = Kit.sunburst(overlay, C.Night, Theme.shade(C.Night, 0.08), 22, true)
	burst.ZIndex = 100

	-- 1. La balle tremble de plus en plus.
	local ball = Kit.ball(
		overlay,
		260,
		ballColor or C.Yellow,
		ballAccent or C.Red,
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5)
	)
	ball.ZIndex = 110
	for _, child in ball:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 111
		end
	end
	Kit.pop(ball, 0.2)
	Kit.playSound(Theme.Sounds.PackOpen, 0.7)
	local hint = Kit.text({
		Text = "...",
		Color = C.Paper,
		Stroke = C.Ink,
		Size = UDim2.fromOffset(600, 60),
		Position = UDim2.new(0.5, 0, 0.82, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 112,
		Parent = overlay,
	})
	local shakeTime = 1.2 + rank * 0.15
	local stop = os.clock() + shakeTime
	while os.clock() < stop do
		local intensity = 4 + (1 - (stop - os.clock()) / shakeTime) * (6 + rank * 3)
		ball.Rotation = math.random(-intensity, intensity)
		ball.Position = UDim2.new(0.5, math.random(-intensity, intensity), 0.5, math.random(-intensity, intensity))
		-- Les hautes raretés teintent la balle juste avant l'éclat.
		if rank >= 4 and os.clock() > stop - 0.5 then
			ball.BackgroundColor3 = rarityColor
		end
		task.wait(1 / 30)
	end

	-- 2. Éclat.
	local flash =
		Kit.new("Frame", { BackgroundColor3 = C.White, Size = UDim2.fromScale(1, 1), ZIndex = 130, Parent = overlay })
	ball:Destroy()
	hint:Destroy()
	burst:Destroy()
	local reveal = Kit.sunburst(overlay, rarityColor, Theme.shade(rarityColor, 0.25), 20, true)
	reveal.ZIndex = 101
	Kit.playSound(Theme.Sounds.Reveal, 0.8)
	Kit.tween(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
	task.delay(0.5, function()
		flash:Destroy()
	end)

	-- 3. Carte.
	local card: Frame
	local title = ""
	if result.Kind == "Archetype" then
		local archetype = Archetypes.get(result.Id)
		if archetype then
			card = Cards.archetype(overlay, archetype, {
				Size = UDim2.fromOffset(300, 420),
				Position = UDim2.fromScale(0.5, 0.46),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 120,
			})
			title = `{archetype.Name} — {archetype.Title}`
		end
	else
		local item = Cosmetics.get(result.Id)
		if item then
			card = Cards.cosmetic(overlay, item, {
				Size = UDim2.fromOffset(260, 310),
				ZIndex = 120,
			})
			card.Position = UDim2.fromScale(0.5, 0.46)
			card.AnchorPoint = Vector2.new(0.5, 0.5)
			title = item.Name
		end
	end
	local cardFrame = card :: Frame?
	if cardFrame then
		Kit.pop(cardFrame, 0.2)
		cardFrame.Rotation = -6
		Kit.tween(cardFrame, Theme.Tween.Bounce, { Rotation = 0 })
	end

	local rarityName = string.upper(if rarityInfo then rarityInfo.Name else result.Rarity)
	local banner = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		Size = UDim2.fromOffset(760, 80),
		Position = UDim2.new(0.5, 0, 0.1, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -3,
		ZIndex = 125,
		Parent = overlay,
	})
	Kit.text({
		Text = `{rarityName} !`,
		Color = rarityColor,
		Stroke = C.Paper,
		StrokeThickness = 3,
		ZIndex = 126,
		Parent = banner,
	})
	Kit.pop(banner, 0.3)

	local status = if result.Duplicate then `DOUBLON : +{result.Refund} Hand Coins` else "NOUVEAU !"
	if result.Pity then
		status ..= "  ·  GARANTIE ACTIVÉE"
	end
	Kit.text({
		Text = `{title}\n{status}`,
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 3,
		Size = UDim2.fromOffset(900, 100),
		Position = UDim2.new(0.5, 0, 0.82, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 126,
		Parent = overlay,
	})

	local closed = false
	local continue = Kit.button({
		Text = "CONTINUER",
		Color = C.Yellow,
		Size = UDim2.fromOffset(300, 70),
		Position = UDim2.new(0.5, 0, 0.94, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 127,
		Parent = overlay,
		OnClick = function()
			closed = true
		end,
	})
	local _ = continue
	while not closed and overlay.Parent do
		task.wait(0.05)
	end
	overlay:Destroy()
end

return PackOpening
