--!strict
-- BOUTIQUE : balles d'archétypes, packs cosmétiques, Hand Coins.
-- Les taux sont affichés pour chaque objet aléatoire.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Packs = require(ReplicatedStorage.Shared.Data.Packs)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Kit = require(script.Parent.Parent.UI.Kit)
local PackOpening = require(script.Parent.Parent.Controllers.PackOpening)
local Page = require(script.Parent.Parent.UI.Page)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local ShopScreen = {}

-- Taux affichés (obligatoire pour les objets aléatoires payants) :
-- une ligne par rareté, barre colorée proportionnelle au taux.
local function oddsRows(parent: Instance, odds: { [string]: number }, z: number)
	local list = Kit.box({ Size = UDim2.new(1, 0, 0, 0), AutoSize = Enum.AutomaticSize.Y, ZIndex = z, Parent = parent })
	Kit.list(list, 3)
	local header = Kit.box({ Size = UDim2.new(1, 0, 0, 24), Order = 0, ZIndex = z, Parent = list })
	local tag = Kit.plate({
		Color = C.Accent,
		Size = UDim2.fromOffset(64, 20),
		Position = UDim2.fromOffset(2, 2),
		BorderThickness = 2,
		Shadow = false,
		ZIndex = z,
		Parent = header,
	})
	Kit.label({
		Text = "TAUX",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Small,
		Color = C.TextOnAccent,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 1,
		Parent = tag,
	})
	for index, rarity in Rarities.Order do
		local percent = odds[rarity]
		if percent and percent > 0 then
			local row = Kit.box({ Size = UDim2.new(1, 0, 0, 20), Order = index, ZIndex = z, Parent = list })
			local bar = Kit.new("Frame", {
				BackgroundColor3 = Theme.rarityColor(rarity),
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Size = UDim2.new(math.clamp(percent / 100, 0.02, 1), 0, 1, -4),
				Position = UDim2.fromOffset(0, 2),
				ZIndex = z,
				Parent = row,
			})
			Kit.corner(bar, 3)
			local dot = Kit.new("Frame", {
				BackgroundColor3 = Theme.rarityColor(rarity),
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(10, 10),
				Position = UDim2.new(0, 4, 0.5, -5),
				Rotation = 45,
				ZIndex = z + 1,
				Parent = row,
			})
			Kit.border(dot, C.Ink, 1.5)
			Kit.label({
				Text = string.upper(Theme.rarityName(rarity)),
				Font = Theme.Fonts.Display,
				TextSize = Theme.Text.Small,
				Color = C.Text,
				Position = UDim2.fromOffset(22, 0),
				Size = UDim2.new(1, -80, 1, 0),
				ZIndex = z + 1,
				Parent = row,
			})
			Kit.label({
				Text = Format.percent(percent),
				Font = Theme.Fonts.Number,
				TextSize = Theme.Text.Small,
				AlignX = Enum.TextXAlignment.Right,
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = z + 1,
				Parent = row,
			})
		end
	end
	return list
end

-- Prix en pastille jaune inclinée avec pièce.
local function price(parent: Instance, amount: number, position: UDim2, z: number)
	local pill = Kit.new("Frame", {
		Name = "Prix",
		BackgroundColor3 = C.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = position,
		Rotation = -3,
		ZIndex = z,
		Parent = parent,
	})
	Kit.corner(pill, 5)
	Kit.border(pill, C.Ink, 2.5)
	Kit.shade(pill, 0.2)
	Kit.padding(pill, 10, 0)
	Kit.list(pill, 8, true, nil, Enum.VerticalAlignment.Center)
	local coin = Kit.new("Frame", {
		BackgroundColor3 = C.Orange,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(18, 18),
		LayoutOrder = 1,
		ZIndex = z + 1,
		Parent = pill,
	})
	Kit.corner(coin, 9)
	Kit.border(coin, C.Ink, 2)
	Kit.label({
		Text = Format.number(amount),
		Font = Theme.Fonts.Number,
		TextSize = Theme.Text.H3 + 2,
		Color = C.TextOnAccent,
		Size = UDim2.fromOffset(0, 32),
		AutoSize = Enum.AutomaticSize.X,
		Order = 2,
		ZIndex = z + 1,
		Parent = pill,
	})
end

-- Vignette colorée : dégradé de la couleur, rayons, trame et lignes de vitesse.
local function stageArt(parent: Instance, color: Color3, height: number, z: number): Frame
	local stage = Kit.new("Frame", {
		Name = "Scene",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, height),
		ZIndex = z,
		Parent = parent,
	})
	Kit.corner(stage, Theme.RadiusLarge)
	Kit.gradient(stage, Theme.lighten(color, 0.15), Theme.darken(color, 0.6), 135)
	for index = 1, 6 do
		local ray = Kit.new("Frame", {
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(28, 700),
			Rotation = index * 30,
			ZIndex = z,
			Parent = stage,
		})
		ray.Name = "Rayon"
	end
	Kit.halftone({
		Parent = stage,
		Color = C.White,
		Columns = 14,
		Rows = 8,
		Spacing = 14,
		Transparency = 0.8,
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		Rotation = 0,
		ZIndex = z,
	})
	Kit.speedLines({ Parent = stage, Color = C.White, Count = 8, Transparency = 0.75, ZIndex = z })
	return stage
end

-- Balle qui flotte doucement.
local function float(ball: Frame)
	Kit.tween(
		ball,
		TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = ball.Position - UDim2.fromOffset(0, 10), Rotation = 8 }
	)
end

function ShopScreen.create(parent: Instance): Page.Page
	local page = Page.full(
		parent,
		"Boutique",
		"Débloque des archétypes et des cosmétiques. Les taux d'obtention sont affichés.",
		Theme.Section.Shop
	)
	local content = page.Content
	local sections: { [string]: Frame } = {}
	local refreshers: { () -> () } = {}
	local products: { [string]: boolean } = {}
	local busy = false

	local function section(name: string): Frame
		local frame = Kit.box({
			Name = name,
			Size = UDim2.new(1, 0, 1, -64),
			Position = UDim2.fromOffset(0, 64),
			Visible = false,
			ZIndex = 12,
			Parent = content,
		})
		sections[name] = frame
		return frame
	end

	local function open(kind: string, id: string?, color: Color3, accent: Color3)
		if busy then
			return
		end
		busy = true
		local ok, result
		if kind == "Ball" then
			ok, result = State.request("ShopAction", "OpenBall", id)
		else
			ok, result = State.request("ShopAction", "OpenCosmeticPack")
		end
		if ok and result and result.Result then
			PackOpening.play(result.Result, color, accent)
		end
		busy = false
	end

	-- Balles ------------------------------------------------------------------------------------------
	local balls = section("Balles")
	local row = Kit.box({ Size = UDim2.new(1, 0, 0, 520), ZIndex = 12, Parent = balls })
	Kit.list(row, 20, true)
	for index, ballId in Packs.BallOrder do
		local pack = Packs.Balls[ballId]
		local card = Kit.surface({
			Color = Theme.darken(pack.Color, 0.72),
			Size = UDim2.fromOffset(320, 520),
			Radius = Theme.RadiusLarge,
			BorderThickness = 3,
			Order = index,
			ZIndex = 13,
			Parent = row,
		})
		local stage = stageArt(card, pack.Color, 180, 14)
		local ball = PackOpening.ball(stage, 132, pack.Color, pack.Accent, 15)
		ball.AnchorPoint = Vector2.new(0.5, 0.5)
		ball.Position = UDim2.fromScale(0.5, 0.52)
		float(ball)
		local inner = Kit.box({
			Size = UDim2.new(1, -40, 1, -196),
			Position = UDim2.fromOffset(20, 176),
			ZIndex = 14,
			Parent = card,
		})
		Kit.title({
			Text = string.upper(pack.Name),
			TextSize = 36,
			Color = C.White,
			ShadowColor = pack.Color,
			Size = UDim2.new(1, 0, 0, 42),
			Rotation = -3,
			ZIndex = 16,
			Parent = inner,
		})
		price(inner, pack.Price, UDim2.fromOffset(2, 48), 15)
		local stock = Kit.label({
			Text = "",
			TextSize = Theme.Text.Small,
			Color = C.TextMuted,
			AlignX = Enum.TextXAlignment.Right,
			Font = Theme.Fonts.Display,
			Size = UDim2.new(1, 0, 0, 32),
			Position = UDim2.fromOffset(0, 48),
			ZIndex = 15,
			Parent = inner,
		})
		local odds = oddsRows(inner, pack.Odds, 15)
		odds.Position = UDim2.fromOffset(0, 92)
		Kit.button({
			Text = "ACHETER",
			Variant = "Primary",
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H3,
			Size = UDim2.new(0.5, -6, 0, 44),
			Position = UDim2.new(0, 0, 1, -44),
			ZIndex = 15,
			Parent = inner,
			OnClick = function()
				State.request("ShopAction", "BuyBall", ballId, 1)
			end,
		})
		local openButton = Kit.button({
			Text = "OUVRIR",
			Variant = "Primary",
			Color = C.Pink,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H3,
			Size = UDim2.new(0.5, -6, 0, 44),
			Position = UDim2.new(1, 0, 1, -44),
			AnchorPoint = Vector2.new(1, 0),
			ZIndex = 15,
			Parent = inner,
			OnClick = function()
				open("Ball", ballId, pack.Color, pack.Accent)
			end,
		})
		table.insert(refreshers, function()
			local profile = State.Profile
			local count = if profile then profile.Balls[ballId] or 0 else 0
			stock.Text = `EN STOCK : {count}`
			openButton.SetEnabled(count > 0)
		end)
	end
	local pity = Kit.label({
		Text = "",
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Theme.Fonts.Semibold,
		Position = UDim2.fromOffset(0, 536),
		ZIndex = 12,
		Parent = balls,
	})
	table.insert(refreshers, function()
		local profile = State.Profile
		local remaining = Packs.PityThreshold - (if profile then profile.Pity else 0)
		pity.Text =
			`Un archétype Légendaire ou mieux est garanti au plus tard dans {math.max(1, remaining)} balle(s).`
	end)

	-- Cosmétiques ------------------------------------------------------------------------------------
	local cosmetics = section("Cosmétiques")
	local packCard = Kit.surface({
		Color = Theme.darken(C.Cyan, 0.75),
		Size = UDim2.fromOffset(420, 560),
		Radius = Theme.RadiusLarge,
		BorderThickness = 3,
		Shadow = true,
		ShadowColor = C.Cyan,
		ZIndex = 13,
		Parent = cosmetics,
	})
	local packStage = stageArt(packCard, C.Cyan, 120, 14)
	-- Trois pastilles qui représentent masque, gants et chaussures.
	for slot, color in { C.Pink, C.Accent, C.Lime } do
		local token = Kit.new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, (slot - 2) * 74, 0.5, if slot == 2 then -6 else 6),
			Size = UDim2.fromOffset(64, 64),
			Rotation = (slot - 2) * 12,
			ZIndex = 15,
			Parent = packStage,
		})
		Kit.corner(token, 12)
		Kit.border(token, C.Ink, 3)
		Kit.shade(token, 0.3)
		Kit.label({
			Text = ({ "M", "G", "C" })[slot],
			Font = Theme.Fonts.Hero,
			TextSize = 40,
			Color = Theme.onColor(color),
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 16,
			Parent = token,
		})
		float(token)
	end
	local packInner = Kit.box({
		Size = UDim2.new(1, -48, 1, -150),
		Position = UDim2.fromOffset(24, 132),
		ZIndex = 14,
		Parent = packCard,
	})
	Kit.title({
		Text = string.upper(Packs.Cosmetic.Name),
		TextSize = 34,
		Color = C.White,
		ShadowColor = C.Cyan,
		Size = UDim2.new(1, 0, 0, 38),
		Rotation = -2,
		ZIndex = 16,
		Parent = packInner,
	})
	Kit.label({
		Text = "Un masque, des gants ou des chaussures au hasard. 100 % esthétique : aucun avantage en jeu.",
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Wrap = true,
		AlignY = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 40),
		ZIndex = 15,
		Parent = packInner,
	})
	price(packInner, Packs.Cosmetic.Price, UDim2.fromOffset(2, 80), 15)
	local packStock = Kit.label({
		Text = "",
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		AlignX = Enum.TextXAlignment.Right,
		Font = Theme.Fonts.Display,
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.fromOffset(0, 80),
		ZIndex = 15,
		Parent = packInner,
	})
	local packOdds = oddsRows(packInner, Packs.Cosmetic.Odds, 15)
	packOdds.Position = UDim2.fromOffset(0, 118)
	Kit.button({
		Text = "ACHETER",
		Variant = "Primary",
		Font = Theme.Fonts.Display,
		Size = UDim2.new(0.5, -6, 0, 44),
		Position = UDim2.new(0, 0, 1, -100),
		ZIndex = 15,
		Parent = packInner,
		OnClick = function()
			State.request("ShopAction", "BuyCosmeticPack", 1)
		end,
	})
	local robux = Kit.button({
		Text = `{Config.ProductRobuxPrice.CosmeticPack} R$`,
		Variant = "Primary",
		Color = C.Lime,
		Font = Theme.Fonts.Display,
		Size = UDim2.new(0.5, -6, 0, 44),
		Position = UDim2.new(1, 0, 1, -100),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 15,
		Parent = packInner,
		OnClick = function()
			State.request("ShopAction", "BuyProduct", "CosmeticPack")
		end,
	})
	local openPack = Kit.button({
		Text = "OUVRIR UN PACK",
		Variant = "Primary",
		Color = C.Pink,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H3,
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.new(0, 0, 1, -48),
		ZIndex = 15,
		Parent = packInner,
		OnClick = function()
			open("Cosmetic", nil, C.Cyan, C.Pink)
		end,
	})
	local bundle = Kit.surface({
		Color = Theme.darken(C.Pink, 0.7),
		Size = UDim2.fromOffset(340, 170),
		Position = UDim2.fromOffset(452, 0),
		Radius = Theme.RadiusLarge,
		BorderThickness = 3,
		Shadow = true,
		ShadowColor = C.Pink,
		ZIndex = 13,
		Parent = cosmetics,
	})
	Kit.halftone({
		Parent = bundle,
		Color = C.Pink,
		Columns = 12,
		Rows = 6,
		Spacing = 14,
		Flip = true,
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 13,
	})
	Kit.title({
		Text = "LOT DE 5 PACKS",
		TextSize = 34,
		ShadowColor = C.Pink,
		Position = UDim2.fromOffset(24, 18),
		Size = UDim2.new(1, -48, 0, 40),
		Rotation = -3,
		ZIndex = 14,
		Parent = bundle,
	})
	Kit.pill(bundle, "Meilleure offre", C.Lime).Position = UDim2.fromOffset(26, 64)
	local bundleButton = Kit.button({
		Text = `{Config.ProductRobuxPrice.CosmeticPack5} R$`,
		Variant = "Primary",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H3,
		Size = UDim2.new(1, -48, 0, 48),
		Position = UDim2.new(0, 24, 1, -70),
		ZIndex = 14,
		Parent = bundle,
		OnClick = function()
			State.request("ShopAction", "BuyProduct", "CosmeticPack5")
		end,
	})
	table.insert(refreshers, function()
		local profile = State.Profile
		local count = if profile then profile.CosmeticPacks else 0
		packStock.Text = `En stock : {count}`
		openPack.SetEnabled(count > 0)
		robux.SetEnabled(products.CosmeticPack == true)
		robux.SetText(if products.CosmeticPack then `{Config.ProductRobuxPrice.CosmeticPack} R$` else "Bientôt")
		bundleButton.SetEnabled(products.CosmeticPack5 == true)
		bundleButton.SetText(
			if products.CosmeticPack5 then `{Config.ProductRobuxPrice.CosmeticPack5} R$` else "Bientôt"
		)
	end)

	-- Hand Coins -------------------------------------------------------------------------------------------
	local coins = section("Hand Coins")
	local coinRow = Kit.box({ Size = UDim2.new(1, 0, 0, 230), ZIndex = 12, Parent = coins })
	Kit.list(coinRow, 20, true)
	local coinOffers = {
		{ Key = "Coins1000", Amount = 1000, Color = C.Orange, Stack = 2 },
		{ Key = "Coins5000", Amount = 5500, Color = C.Accent, Stack = 5 },
	}
	for index, offer in coinOffers do
		local card = Kit.surface({
			Color = Theme.darken(offer.Color, 0.72),
			Size = UDim2.fromOffset(340, 210),
			Radius = Theme.RadiusLarge,
			BorderThickness = 3,
			Order = index,
			ZIndex = 13,
			Parent = coinRow,
		})
		local coinStage = stageArt(card, offer.Color, 96, 14)
		-- Pile de pièces dessinées.
		for coinIndex = 1, offer.Stack do
			local coin = Kit.new("Frame", {
				BackgroundColor3 = C.Accent,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(
					0.5,
					(coinIndex - (offer.Stack + 1) / 2) * 34,
					0.5,
					if coinIndex % 2 == 0 then -8 else 6
				),
				Size = UDim2.fromOffset(50, 50),
				ZIndex = 15 + coinIndex,
				Parent = coinStage,
			})
			Kit.corner(coin, 25)
			Kit.border(coin, C.Ink, 3)
			Kit.gradient(coin, Theme.lighten(C.Accent, 0.4), C.Orange, 45)
			Kit.label({
				Text = "H",
				Font = Theme.Fonts.Hero,
				TextSize = 30,
				Color = C.TextOnAccent,
				AlignX = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 15 + coinIndex,
				Parent = coin,
			})
		end
		Kit.title({
			Text = `{Format.number(offer.Amount)} HC`,
			Font = Theme.Fonts.Number,
			TextSize = 34,
			ShadowColor = offer.Color,
			Position = UDim2.fromOffset(20, 100),
			Size = UDim2.new(1, -40, 0, 40),
			ZIndex = 15,
			Parent = card,
		})
		if index == 2 then
			local bonus = Kit.pill(card, "+10 % offerts", C.Pink)
			bonus.Position = UDim2.new(1, -14, 0, 108)
			bonus.AnchorPoint = Vector2.new(1, 0)
			bonus.ZIndex = 16
			for _, child in bonus:GetDescendants() do
				if child:IsA("GuiObject") then
					child.ZIndex = 17
				end
			end
		end
		local buy = Kit.button({
			Text = "",
			Variant = "Primary",
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H3,
			Size = UDim2.new(1, -40, 0, 46),
			Position = UDim2.new(0, 20, 1, -62),
			ZIndex = 15,
			Parent = card,
			OnClick = function()
				State.request("ShopAction", "BuyProduct", offer.Key)
			end,
		})
		table.insert(refreshers, function()
			local enabled = products[offer.Key] == true
			buy.SetEnabled(enabled)
			buy.SetText(if enabled then `{Config.ProductRobuxPrice[offer.Key]} R$` else "Bientôt")
		end)
	end
	Kit.label({
		Text = "Tu gagnes aussi des Hand Coins à chaque match : victoire, buts, passes décisives, arrêts et interceptions.",
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Theme.Fonts.Semibold,
		Position = UDim2.fromOffset(0, 246),
		ZIndex = 12,
		Parent = coins,
	})

	local function refresh()
		for _, refresher in refreshers do
			refresher()
		end
	end
	local select = Page.tabs(content, { "Balles", "Cosmétiques", "Hand Coins" }, function(name)
		for key, frame in sections do
			frame.Visible = key == name
		end
	end, 12, Theme.Section.Shop)
	select("Balles")

	State.ProfileChanged:Connect(refresh)
	local baseOpen = page.Open
	page.Open = function()
		task.spawn(function()
			local ok, result = State.request("ShopAction", "Catalog")
			if ok and result.Products then
				products = result.Products
				refresh()
			end
		end)
		refresh()
		baseOpen()
	end
	refresh()
	return page
end

return ShopScreen
