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

local function oddsRows(parent: Instance, odds: { [string]: number }, z: number)
	local list = Kit.box({ Size = UDim2.new(1, 0, 0, 0), AutoSize = Enum.AutomaticSize.Y, ZIndex = z, Parent = parent })
	Kit.list(list, 4)
	for index, rarity in Rarities.Order do
		local percent = odds[rarity]
		if percent and percent > 0 then
			local row = Kit.box({ Size = UDim2.new(1, 0, 0, 20), Order = index, ZIndex = z, Parent = list })
			local dot = Kit.new("Frame", {
				BackgroundColor3 = Theme.rarityColor(rarity),
				Size = UDim2.fromOffset(8, 8),
				Position = UDim2.new(0, 0, 0.5, -4),
				ZIndex = z,
				Parent = row,
			})
			Kit.corner(dot, 4)
			Kit.label({
				Text = Theme.rarityName(rarity),
				TextSize = Theme.Text.Small,
				Color = C.TextMuted,
				Position = UDim2.fromOffset(16, 0),
				Size = UDim2.new(1, -80, 1, 0),
				ZIndex = z,
				Parent = row,
			})
			Kit.label({
				Text = Format.percent(percent),
				Font = Theme.Fonts.Bold,
				TextSize = Theme.Text.Small,
				AlignX = Enum.TextXAlignment.Right,
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = z,
				Parent = row,
			})
		end
	end
	return list
end

local function price(parent: Instance, amount: number, position: UDim2, z: number)
	local row = Kit.box({
		Size = UDim2.fromOffset(0, 28),
		AutoSize = Enum.AutomaticSize.X,
		Position = position,
		ZIndex = z,
		Parent = parent,
	})
	Kit.list(row, 8, true, nil, Enum.VerticalAlignment.Center)
	local coin = Kit.new(
		"Frame",
		{ BackgroundColor3 = C.Warning, Size = UDim2.fromOffset(14, 14), LayoutOrder = 1, ZIndex = z, Parent = row }
	)
	Kit.corner(coin, 7)
	Kit.label({
		Text = Format.number(amount),
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H3,
		Size = UDim2.fromOffset(0, 28),
		AutoSize = Enum.AutomaticSize.X,
		Order = 2,
		ZIndex = z,
		Parent = row,
	})
end

function ShopScreen.create(parent: Instance): Page.Page
	local page = Page.full(
		parent,
		"Boutique",
		"Débloque des archétypes et des cosmétiques. Les taux d'obtention sont affichés."
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
	local row = Kit.box({ Size = UDim2.new(1, 0, 0, 470), ZIndex = 12, Parent = balls })
	Kit.list(row, 20, true)
	for index, ballId in Packs.BallOrder do
		local pack = Packs.Balls[ballId]
		local card = Kit.surface({
			Color = C.Surface,
			Size = UDim2.fromOffset(320, 470),
			Radius = Theme.RadiusLarge,
			Order = index,
			ZIndex = 13,
			Parent = row,
		})
		local stage = Kit.new("Frame", {
			BackgroundColor3 = C.Surface2,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 170),
			ZIndex = 14,
			Parent = card,
		})
		Kit.corner(stage, Theme.RadiusLarge)
		local ball = PackOpening.ball(stage, 110, pack.Color, pack.Accent, 15)
		ball.AnchorPoint = Vector2.new(0.5, 0.5)
		ball.Position = UDim2.fromScale(0.5, 0.5)
		local inner = Kit.box({
			Size = UDim2.new(1, -40, 1, -190),
			Position = UDim2.fromOffset(20, 186),
			ZIndex = 14,
			Parent = card,
		})
		Kit.label({
			Text = pack.Name,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H2,
			Size = UDim2.new(1, 0, 0, 30),
			ZIndex = 15,
			Parent = inner,
		})
		price(inner, pack.Price, UDim2.fromOffset(0, 34), 15)
		local stock = Kit.label({
			Text = "",
			TextSize = Theme.Text.Small,
			Color = C.TextMuted,
			AlignX = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.fromOffset(0, 34),
			ZIndex = 15,
			Parent = inner,
		})
		local odds = oddsRows(inner, pack.Odds, 15)
		odds.Position = UDim2.fromOffset(0, 74)
		Kit.button({
			Text = "Acheter",
			Variant = "Secondary",
			Size = UDim2.new(0.5, -6, 0, 44),
			Position = UDim2.new(0, 0, 1, -44),
			ZIndex = 15,
			Parent = inner,
			OnClick = function()
				State.request("ShopAction", "BuyBall", ballId, 1)
			end,
		})
		local openButton = Kit.button({
			Text = "Ouvrir",
			Variant = "Primary",
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
			stock.Text = `En stock : {count}`
			openButton.SetEnabled(count > 0)
		end)
	end
	local pity = Kit.label({
		Text = "",
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 486),
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
		Color = C.Surface,
		Size = UDim2.fromOffset(420, 470),
		Radius = Theme.RadiusLarge,
		ZIndex = 13,
		Parent = cosmetics,
	})
	local packInner = Kit.box({
		Size = UDim2.new(1, -48, 1, -48),
		Position = UDim2.fromOffset(24, 24),
		ZIndex = 14,
		Parent = packCard,
	})
	Kit.label({
		Text = Packs.Cosmetic.Name,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H2,
		Size = UDim2.new(1, 0, 0, 30),
		ZIndex = 15,
		Parent = packInner,
	})
	Kit.label({
		Text = "Un masque, des gants ou des chaussures au hasard. 100 % esthétique : aucun avantage en jeu.",
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Wrap = true,
		AlignY = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 36),
		ZIndex = 15,
		Parent = packInner,
	})
	price(packInner, Packs.Cosmetic.Price, UDim2.fromOffset(0, 86), 15)
	local packStock = Kit.label({
		Text = "",
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 86),
		ZIndex = 15,
		Parent = packInner,
	})
	local packOdds = oddsRows(packInner, Packs.Cosmetic.Odds, 15)
	packOdds.Position = UDim2.fromOffset(0, 128)
	Kit.button({
		Text = "Acheter",
		Variant = "Secondary",
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
		Variant = "Secondary",
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
		Text = "Ouvrir un pack",
		Variant = "Primary",
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.new(0, 0, 1, -48),
		ZIndex = 15,
		Parent = packInner,
		OnClick = function()
			open("Cosmetic", nil, C.Info, C.White)
		end,
	})
	local bundle = Kit.surface({
		Color = C.Surface,
		Size = UDim2.fromOffset(320, 150),
		Position = UDim2.fromOffset(440, 0),
		Radius = Theme.RadiusLarge,
		ZIndex = 13,
		Parent = cosmetics,
	})
	Kit.label({
		Text = "Lot de 5 packs",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.H3,
		Position = UDim2.fromOffset(24, 22),
		Size = UDim2.new(1, -48, 0, 26),
		ZIndex = 14,
		Parent = bundle,
	})
	local bundleButton = Kit.button({
		Text = `{Config.ProductRobuxPrice.CosmeticPack5} R$`,
		Variant = "Primary",
		Size = UDim2.new(1, -48, 0, 48),
		Position = UDim2.new(0, 24, 1, -72),
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
	local coinRow = Kit.box({ Size = UDim2.new(1, 0, 0, 220), ZIndex = 12, Parent = coins })
	Kit.list(coinRow, 20, true)
	for index, offer in { { Key = "Coins1000", Amount = 1000 }, { Key = "Coins5000", Amount = 5500 } } do
		local card = Kit.surface({
			Color = C.Surface,
			Size = UDim2.fromOffset(320, 200),
			Radius = Theme.RadiusLarge,
			Order = index,
			ZIndex = 13,
			Parent = coinRow,
		})
		price(card, offer.Amount, UDim2.fromOffset(24, 28), 14)
		Kit.label({
			Text = "Hand Coins",
			TextSize = Theme.Text.Small,
			Color = C.TextMuted,
			Position = UDim2.fromOffset(24, 60),
			Size = UDim2.new(1, -48, 0, 20),
			ZIndex = 14,
			Parent = card,
		})
		local buy = Kit.button({
			Text = "",
			Variant = "Primary",
			Size = UDim2.new(1, -48, 0, 48),
			Position = UDim2.new(0, 24, 1, -72),
			ZIndex = 14,
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
		Position = UDim2.fromOffset(0, 236),
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
	end, 12)
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
