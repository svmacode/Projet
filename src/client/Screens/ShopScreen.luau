--!strict
-- Écran BOUTIQUE : Balles d'archétypes (Hand Coins), Pack Cosmétique
-- (Hand Coins ou Robux) et Hand Coins (Robux). Les taux sont affichés.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Packs = require(ReplicatedStorage.Shared.Data.Packs)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Kit = require(script.Parent.Parent.UI.Kit)
local PackOpening = require(script.Parent.Parent.Controllers.PackOpening)
local ScreenFrame = require(script.Parent.Parent.UI.ScreenFrame)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local ShopScreen = {}

local function oddsList(parent: Instance, odds: { [string]: number }, position: UDim2, z: number): Frame
	local face, container = Kit.panel({
		Size = UDim2.fromOffset(300, 220),
		Position = position,
		Color = C.Paper,
		ZIndex = z,
		Parent = parent,
	})
	Kit.text({
		Text = "TAUX D'OBTENTION",
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, 8),
		ZIndex = z + 1,
		Parent = face,
	})
	local list = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 1, -50),
		Position = UDim2.fromOffset(10, 44),
		ZIndex = z + 1,
		Parent = face,
	})
	Kit.list(list, 4)
	for index, rarity in Rarities.Order do
		local percent = odds[rarity]
		if percent and percent > 0 then
			local row = Kit.new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 24),
				LayoutOrder = index,
				ZIndex = z + 1,
				Parent = list,
			})
			local dot = Kit.new("Frame", {
				BackgroundColor3 = Theme.rarityColor(rarity),
				Size = UDim2.fromOffset(18, 18),
				Position = UDim2.fromOffset(0, 3),
				ZIndex = z + 2,
				Parent = row,
			})
			Kit.stroke(dot, 2)
			Kit.text({
				Text = Theme.rarityName(rarity),
				Font = Theme.Fonts.Body,
				Size = UDim2.new(0.6, 0, 1, 0),
				Position = UDim2.fromOffset(28, 0),
				AlignX = Enum.TextXAlignment.Left,
				ZIndex = z + 2,
				Parent = row,
			})
			Kit.text({
				Text = Format.percent(percent),
				Font = Theme.Fonts.Heavy,
				Size = UDim2.new(0.35, 0, 1, 0),
				Position = UDim2.fromScale(0.65, 0),
				AlignX = Enum.TextXAlignment.Right,
				ZIndex = z + 2,
				Parent = row,
			})
		end
	end
	return container
end

local function priceTag(parent: Instance, amount: number, position: UDim2, z: number)
	local tag = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		Size = UDim2.fromOffset(170, 40),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = z,
		Parent = parent,
	})
	Kit.coin(tag, 30, UDim2.fromOffset(6, 5)).ZIndex = z + 1
	Kit.text({
		Text = Format.number(amount),
		Color = C.Yellow,
		Size = UDim2.new(1, -50, 1, -6),
		Position = UDim2.fromOffset(44, 3),
		ZIndex = z + 1,
		Parent = tag,
	})
end

function ShopScreen.create(parent: Instance, close: () -> ()): ScreenFrame.Screen
	local screen = ScreenFrame.new(parent, "BOUTIQUE", "ショップ", C.Red, close)
	local content = screen.Content
	local products: { [string]: boolean } = {}
	local pages: { [string]: Frame } = {}
	local refreshers: { () -> () } = {}

	local function page(name: string): Frame
		local frame = Kit.new("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -66),
			Position = UDim2.fromOffset(0, 66),
			Visible = false,
			ZIndex = 22,
			Parent = content,
		})
		pages[name] = frame
		return frame
	end

	local busy = false
	local function openBall(ballId: string)
		if busy then
			return
		end
		busy = true
		local ok, result = State.request("ShopAction", "OpenBall", ballId)
		if ok and result.Result then
			local pack = Packs.Balls[ballId]
			PackOpening.play(result.Result, pack and pack.Color, pack and pack.Accent)
		end
		busy = false
	end

	-- BALLES ---------------------------------------------------------------------------------------
	local ballsPage = page("BALLES")
	local pity = Kit.text({
		Text = "",
		Font = Theme.Fonts.Heavy,
		Color = C.Purple,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 1, -28),
		ZIndex = 23,
		Parent = ballsPage,
	})
	for index, ballId in Packs.BallOrder do
		local pack = Packs.Balls[ballId]
		local face, _ = Kit.panel({
			Size = UDim2.fromOffset(330, 470),
			Position = UDim2.fromOffset((index - 1) * 356, 0),
			Color = pack.Color,
			ZIndex = 23,
			Clip = true,
			Parent = ballsPage,
		})
		Kit.sunburst(face, pack.Color, Theme.shade(pack.Color, 0.15), 12, false).ZIndex = 23
		Kit.ball(face, 150, pack.Color, pack.Accent, UDim2.new(0.5, 0, 0, 30), Vector2.new(0.5, 0)).ZIndex = 25
		Kit.text({
			Text = string.upper(pack.Name),
			Color = C.Paper,
			Stroke = C.Ink,
			StrokeThickness = 4,
			Size = UDim2.new(1, -20, 0, 50),
			Position = UDim2.fromOffset(10, 190),
			ZIndex = 25,
			Parent = face,
		})
		Kit.text({
			Text = pack.Japanese,
			Font = Theme.Fonts.Heavy,
			Color = C.Ink,
			Size = UDim2.new(1, -20, 0, 22),
			Position = UDim2.fromOffset(10, 238),
			ZIndex = 25,
			Parent = face,
		})
		priceTag(face, pack.Price, UDim2.new(0.5, 0, 0, 268), 25)
		local owned = Kit.text({
			Text = "",
			Color = C.Paper,
			Stroke = C.Ink,
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.fromOffset(10, 314),
			ZIndex = 25,
			Parent = face,
		})
		Kit.button({
			Text = "ACHETER",
			Color = C.Yellow,
			Size = UDim2.fromOffset(140, 50),
			Position = UDim2.fromOffset(16, 356),
			ZIndex = 26,
			Parent = face,
			OnClick = function()
				State.request("ShopAction", "BuyBall", ballId, 1)
			end,
		})
		local openButton = Kit.button({
			Text = "OUVRIR",
			Color = C.Green,
			Size = UDim2.fromOffset(140, 50),
			Position = UDim2.fromOffset(172, 356),
			ZIndex = 26,
			Parent = face,
			OnClick = function()
				openBall(ballId)
			end,
		})
		local oddsPopup: Frame? = nil
		Kit.button({
			Text = "TAUX",
			Color = C.Paper,
			Size = UDim2.fromOffset(296, 34),
			Position = UDim2.fromOffset(16, 420),
			ZIndex = 26,
			Parent = face,
			OnClick = function()
				if oddsPopup then
					oddsPopup:Destroy()
					oddsPopup = nil
				else
					oddsPopup = oddsList(ballsPage, pack.Odds, UDim2.fromOffset((index - 1) * 356 + 15, 120), 40)
				end
			end,
		})
		table.insert(refreshers, function()
			local profile = State.Profile
			local count = if profile then (profile.Balls[ballId] or 0) else 0
			owned.Text = `EN STOCK : {count}`
			openButton.SetEnabled(count > 0)
		end)
	end
	table.insert(refreshers, function()
		local profile = State.Profile
		local remaining = Packs.PityThreshold - (if profile then profile.Pity else 0)
		pity.Text = `★ Légendaire garanti dans {math.max(1, remaining)} balle(s) maximum`
	end)

	-- COSMÉTIQUES -----------------------------------------------------------------------------------
	local cosmeticPage = page("COSMÉTIQUES")
	local packFace, _ = Kit.panel({
		Size = UDim2.fromOffset(420, 470),
		Color = C.Pink,
		ZIndex = 23,
		Clip = true,
		Parent = cosmeticPage,
	})
	Kit.sunburst(packFace, C.Pink, Theme.shade(C.Pink, 0.15), 12, false).ZIndex = 23
	Kit.text({
		Text = "PACK COSMÉTIQUE",
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 4,
		Size = UDim2.new(1, -20, 0, 56),
		Position = UDim2.fromOffset(10, 20),
		ZIndex = 25,
		Parent = packFace,
	})
	Kit.text({
		Text = "Masques · Gants · Chaussures\n100 % esthétique, aucun avantage en jeu.",
		Font = Theme.Fonts.Body,
		Color = C.Ink,
		Size = UDim2.new(1, -30, 0, 56),
		Position = UDim2.fromOffset(15, 84),
		ZIndex = 25,
		Parent = packFace,
	})
	for i, glyph in { "面", "手", "足" } do
		local icon = Kit.new("Frame", {
			BackgroundColor3 = C.Paper,
			Size = UDim2.fromOffset(90, 90),
			Position = UDim2.fromOffset(30 + (i - 1) * 125, 150),
			Rotation = (i - 2) * 8,
			ZIndex = 25,
			Parent = packFace,
		})
		Kit.stroke(icon, 4)
		Kit.text({ Text = glyph, Font = Theme.Fonts.Heavy, Color = C.Ink, ZIndex = 26, Parent = icon })
	end
	priceTag(packFace, Packs.Cosmetic.Price, UDim2.new(0.5, 0, 0, 262), 25)
	local packsOwned = Kit.text({
		Text = "",
		Color = C.Paper,
		Stroke = C.Ink,
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, 308),
		ZIndex = 25,
		Parent = packFace,
	})
	Kit.button({
		Text = "ACHETER (HC)",
		Color = C.Yellow,
		Size = UDim2.fromOffset(185, 50),
		Position = UDim2.fromOffset(18, 350),
		ZIndex = 26,
		Parent = packFace,
		OnClick = function()
			State.request("ShopAction", "BuyCosmeticPack", 1)
		end,
	})
	local robuxButton = Kit.button({
		Text = `{Config.ProductRobuxPrice.CosmeticPack} R$`,
		Color = C.Green,
		Size = UDim2.fromOffset(185, 50),
		Position = UDim2.fromOffset(217, 350),
		ZIndex = 26,
		Parent = packFace,
		OnClick = function()
			State.request("ShopAction", "BuyProduct", "CosmeticPack")
		end,
	})
	local openPack = Kit.button({
		Text = "OUVRIR UN PACK",
		Color = C.Purple,
		TextColor = C.Paper,
		TextStroke = C.Ink,
		Size = UDim2.fromOffset(384, 50),
		Position = UDim2.fromOffset(18, 408),
		ZIndex = 26,
		Parent = packFace,
		OnClick = function()
			if busy then
				return
			end
			busy = true
			local ok, result = State.request("ShopAction", "OpenCosmeticPack")
			if ok and result.Result then
				PackOpening.play(result.Result, C.Pink, C.Paper)
			end
			busy = false
		end,
	})
	oddsList(cosmeticPage, Packs.Cosmetic.Odds, UDim2.fromOffset(460, 0), 23)
	local bundle = Kit.button({
		Text = `5 PACKS · {Config.ProductRobuxPrice.CosmeticPack5} R$`,
		Color = C.Green,
		Size = UDim2.fromOffset(300, 60),
		Position = UDim2.fromOffset(460, 250),
		ZIndex = 26,
		Parent = cosmeticPage,
		OnClick = function()
			State.request("ShopAction", "BuyProduct", "CosmeticPack5")
		end,
	})
	table.insert(refreshers, function()
		local profile = State.Profile
		local count = if profile then profile.CosmeticPacks else 0
		packsOwned.Text = `PACKS EN STOCK : {count}`
		openPack.SetEnabled(count > 0)
		robuxButton.SetEnabled(products.CosmeticPack == true)
		bundle.SetEnabled(products.CosmeticPack5 == true)
	end)

	-- HAND COINS ---------------------------------------------------------------------------------------
	local coinsPage = page("HAND COINS")
	for index, info in { { Key = "Coins1000", Amount = 1000 }, { Key = "Coins5000", Amount = 5500 } } do
		local face, _ = Kit.panel({
			Size = UDim2.fromOffset(340, 360),
			Position = UDim2.fromOffset((index - 1) * 370, 0),
			Color = C.Yellow,
			ZIndex = 23,
			Clip = true,
			Parent = coinsPage,
		})
		Kit.sunburst(face, C.Yellow, Theme.shade(C.Yellow, 0.3), 12, false).ZIndex = 23
		for i = 1, index + 1 do
			Kit.coin(face, 90, UDim2.fromOffset(60 + (i - 1) * 50, 40 + (i % 2) * 20)).ZIndex = 25 + i
		end
		Kit.text({
			Text = `{Format.number(info.Amount)} HAND COINS`,
			Color = C.Paper,
			Stroke = C.Ink,
			StrokeThickness = 4,
			Size = UDim2.new(1, -20, 0, 50),
			Position = UDim2.fromOffset(10, 190),
			ZIndex = 30,
			Parent = face,
		})
		local buy = Kit.button({
			Text = `{Config.ProductRobuxPrice[info.Key]} R$`,
			Color = C.Green,
			Size = UDim2.fromOffset(240, 60),
			Position = UDim2.new(0.5, 0, 0, 268),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 30,
			Parent = face,
			OnClick = function()
				State.request("ShopAction", "BuyProduct", info.Key)
			end,
		})
		table.insert(refreshers, function()
			buy.SetEnabled(products[info.Key] == true)
			buy.SetText(if products[info.Key] then `{Config.ProductRobuxPrice[info.Key]} R$` else "BIENTÔT")
		end)
	end
	Kit.text({
		Text = "Les Hand Coins se gagnent aussi en jouant : victoire, buts, passes décisives, arrêts…",
		Font = Theme.Fonts.Body,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 390),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 23,
		Parent = coinsPage,
	})

	local function refresh()
		for _, refresher in refreshers do
			refresher()
		end
	end

	local select = ScreenFrame.tabs(content, { "BALLES", "COSMÉTIQUES", "HAND COINS" }, function(name)
		for key, frame in pages do
			frame.Visible = key == name
		end
	end)
	select("BALLES")

	State.ProfileChanged:Connect(refresh)
	local open = screen.Open
	screen.Open = function()
		task.spawn(function()
			local ok, result = State.request("ShopAction", "Catalog")
			if ok and result.Products then
				products = result.Products
				refresh()
			end
		end)
		refresh()
		open()
	end
	refresh()
	return screen
end

return ShopScreen
