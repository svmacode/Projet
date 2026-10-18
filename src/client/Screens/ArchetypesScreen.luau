--!strict
-- ARCHÉTYPES : boutique et casier réunis dans une seule fenêtre.
--   BALLES       acheter et ouvrir les balles (taux affichés)
--   ARCHÉTYPES   collection, détail et choix du favori par poste
--   COSMÉTIQUES  pack cosmétique, équipement des masques / gants / chaussures
--   TENUES       tenues débloquées tous les 10 niveaux
--   HAND COINS   offres Robux
-- Le serveur décide de tout (ShopAction / LockerAction) ; l'écran affiche.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Packs = require(ReplicatedStorage.Shared.Data.Packs)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Cards = require(script.Parent.Parent.UI.Cards)
local Kit = require(script.Parent.Parent.UI.Kit)
local PackOpening = require(script.Parent.Parent.Controllers.PackOpening)
local Page = require(script.Parent.Parent.UI.Page)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local ArchetypesScreen = {}

local POSTE_LABELS = { Gardien = "Gardien", Defenseur = "Défenseur", Attaquant = "Attaquant" }
local Z = 34

local function rank(rarity: string): number
	local info = Rarities.get(rarity)
	return if info then info.Rank else 0
end

-- Pastille « pièce + montant ».
local function price(parent: Instance, amount: number, z: number): Frame
	local pill = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 244, 214),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = z,
		Parent = parent,
	})
	Kit.round(pill)
	Kit.border(pill, Color3.fromRGB(240, 196, 110), 1.5)
	Kit.padding(pill, 6, 0)
	Kit.list(pill, 6, true, nil, Enum.VerticalAlignment.Center)
	local coin = Kit.icon("Coin", pill, 22, nil, z + 1)
	coin.LayoutOrder = 1
	Kit.label({
		Text = Format.number(amount),
		Font = Theme.Fonts.Number,
		TextSize = Theme.Text.Body,
		Color = Color3.fromRGB(150, 84, 0),
		Size = UDim2.fromOffset(0, 30),
		AutoSize = Enum.AutomaticSize.X,
		Order = 2,
		ZIndex = z + 1,
		Parent = pill,
	})
	Kit.box({ Size = UDim2.fromOffset(2, 2), Order = 3, Parent = pill })
	return pill
end

-- Petite ligne de taux : pastille de couleur, rareté, pourcentage.
local function oddsList(parent: Instance, odds: { [string]: number }, z: number)
	local list = Kit.box({ Size = UDim2.new(1, 0, 0, 0), AutoSize = Enum.AutomaticSize.Y, ZIndex = z, Parent = parent })
	Kit.list(list, 4)
	local order = 0
	for _, rarity in Rarities.Order do
		local chance = odds[rarity]
		if chance and chance > 0 then
			order += 1
			local row = Kit.box({ Size = UDim2.new(1, 0, 0, 18), Order = order, ZIndex = z, Parent = list })
			local dot = Kit.new("Frame", {
				BackgroundColor3 = Theme.rarityColor(rarity),
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(10, 10),
				Position = UDim2.new(0, 0, 0.5, -5),
				ZIndex = z,
				Parent = row,
			})
			Kit.round(dot)
			Kit.label({
				Text = Theme.rarityName(rarity),
				Font = Theme.Fonts.Semibold,
				TextSize = Theme.Text.Small,
				Color = C.TextMuted,
				Size = UDim2.new(1, -80, 1, 0),
				Position = UDim2.fromOffset(18, 0),
				ZIndex = z,
				Parent = row,
			})
			Kit.label({
				Text = `{chance} %`,
				Font = Theme.Fonts.Bold,
				TextSize = Theme.Text.Small,
				Color = C.Text,
				AlignX = Enum.TextXAlignment.Right,
				Size = UDim2.new(0, 70, 1, 0),
				Position = UDim2.new(1, -70, 0, 0),
				ZIndex = z,
				Parent = row,
			})
		end
	end
	return list
end

function ArchetypesScreen.create(parent: Instance, onClose: () -> ()): Page.Page
	local page = Page.modal(parent, "Archétypes", Vector2.new(1240, 740), onClose, Theme.Section.Archetypes)
	local content = page.Content
	local refreshers: { () -> () } = {}
	local sections: { [string]: Frame } = {}
	local products: { [string]: boolean } = {}
	local busy = false

	-- Solde (à droite des onglets).
	local wallet = Kit.box({
		Size = UDim2.fromOffset(240, 44),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = Z,
		Parent = content,
	})
	Kit.list(wallet, 8, true, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local walletPill: Frame? = nil
	table.insert(refreshers, function()
		if walletPill then
			walletPill:Destroy()
		end
		local profile = State.Profile
		walletPill = price(wallet, if profile then profile.Coins else 0, Z)
	end)

	local function section(name: string): Frame
		local frame = Kit.box({
			Name = name,
			Size = UDim2.new(1, 0, 1, -60),
			Position = UDim2.fromOffset(0, 60),
			Visible = false,
			ZIndex = Z,
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

	-- BALLES ---------------------------------------------------------------------------------------------
	local balls = section("Balles")
	local ballRow = Kit.box({ Size = UDim2.new(1, 0, 0, 500), ZIndex = Z, Parent = balls })
	Kit.list(ballRow, 20, true, Enum.HorizontalAlignment.Center)
	for index, ballId in Packs.BallOrder do
		local pack = Packs.Balls[ballId]
		local card = Kit.surface({
			Size = UDim2.fromOffset(376, 500),
			Radius = Theme.RadiusLarge,
			Border = true,
			BorderThickness = 2,
			Clip = true,
			Order = index,
			ZIndex = Z,
			Parent = ballRow,
		})
		local stage = Kit.new("Frame", {
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 190),
			ClipsDescendants = true,
			ZIndex = Z,
			Parent = card,
		})
		Kit.gradient(stage, Theme.lighten(pack.Color, 0.5), Theme.lighten(pack.Color, 0.05), 110)
		local ball = PackOpening.ball(stage, 128, pack.Color, pack.Accent, Z + 1)
		ball.AnchorPoint = Vector2.new(0.5, 0.5)
		ball.Position = UDim2.fromScale(0.5, 0.52)
		Kit.tween(
			ball,
			TweenInfo.new(1.6 + index * 0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.new(0.5, 0, 0.52, -10) }
		)
		local inner = Kit.box({
			Size = UDim2.new(1, -40, 1, -206),
			Position = UDim2.fromOffset(20, 202),
			ZIndex = Z + 1,
			Parent = card,
		})
		Kit.label({
			Text = pack.Name,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H2,
			Color = C.Text,
			Size = UDim2.new(1, -120, 0, 32),
			ZIndex = Z + 1,
			Parent = inner,
		})
		local cost = price(inner, pack.Price, Z + 1)
		cost.AnchorPoint = Vector2.new(1, 0)
		cost.Position = UDim2.new(1, 0, 0, 1)
		local odds = Kit.box({
			Size = UDim2.new(1, 0, 0, 120),
			Position = UDim2.fromOffset(0, 44),
			ZIndex = Z + 1,
			Parent = inner,
		})
		oddsList(odds, pack.Odds :: any, Z + 1)
		local stock = Kit.label({
			Text = "",
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.Small,
			Color = C.TextMuted,
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.new(0, 0, 1, -82),
			ZIndex = Z + 1,
			Parent = inner,
		})
		Kit.button({
			Text = "ACHETER",
			Variant = "Primary",
			Size = UDim2.new(0.5, -6, 0, 50),
			Position = UDim2.new(0, 0, 1, -58),
			ZIndex = Z + 1,
			Parent = inner,
			OnClick = function()
				State.request("ShopAction", "BuyBall", ballId, 1)
			end,
		})
		local openButton = Kit.button({
			Text = "OUVRIR",
			Variant = "Secondary",
			Size = UDim2.new(0.5, -6, 0, 50),
			Position = UDim2.new(0.5, 6, 1, -58),
			ZIndex = Z + 1,
			Parent = inner,
			OnClick = function()
				open("Ball", ballId, pack.Color, pack.Accent)
			end,
		})
		table.insert(refreshers, function()
			local profile = State.Profile
			local count = if profile then profile.Balls[ballId] or 0 else 0
			stock.Text = if count > 0 then `{count} en stock` else "Aucune en stock"
			stock.TextColor3 = if count > 0 then C.Success else C.TextMuted
			openButton.SetEnabled(count > 0)
		end)
	end
	local pity = Kit.label({
		Text = "",
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -22),
		ZIndex = Z,
		Parent = balls,
	})
	table.insert(refreshers, function()
		local profile = State.Profile
		local remaining = Packs.PityThreshold - (if profile then profile.Pity else 0)
		pity.Text =
			`Légendaire ou mieux garanti au plus tard dans {math.max(1, remaining)} balle(s). Doublons remboursés en Hand Coins.`
	end)

	-- ARCHÉTYPES -----------------------------------------------------------------------------------------
	local collection = section("Archétypes")
	local filter = "Tous"
	local focused: string? = nil
	local filterOptions = { { Id = "Tous", Label = "Tous" } }
	for _, poste in Archetypes.PosteOrder do
		table.insert(filterOptions, { Id = poste, Label = POSTE_LABELS[poste] })
	end
	local grid = Kit.scroll({
		Size = UDim2.new(1, -420, 1, -60),
		Position = UDim2.fromOffset(0, 60),
		ZIndex = Z,
		Parent = collection,
	})
	Kit.grid(grid, Vector2.new(166, 226), 14)
	Kit.padding(grid, 6, 6)
	local count = Kit.label({
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -420, 0, 44),
		ZIndex = Z,
		Parent = collection,
	})
	local detail = Kit.surface({
		Color = C.Surface2,
		Border = false,
		Radius = 16,
		Size = UDim2.new(0, 400, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		Clip = true,
		ZIndex = Z,
		Parent = collection,
	})
	local detailBody = Kit.box({ ZIndex = Z, Parent = detail })

	local renderCollection: () -> ()

	local function renderDetail()
		Kit.clear(detailBody)
		local archetype = Archetypes.get(focused)
		if not archetype then
			Kit.label({
				Text = "Choisis un archétype pour voir ses pouvoirs.",
				Font = Theme.Fonts.Semibold,
				Color = C.TextMuted,
				Wrap = true,
				AlignX = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, -40, 1, 0),
				Position = UDim2.fromOffset(20, 0),
				ZIndex = Z + 1,
				Parent = detailBody,
			})
			return
		end
		local profile = State.Profile
		local owned = profile ~= nil and profile.Archetypes[archetype.Id] == true
		local color = Theme.rarityColor(archetype.Rarity)
		local header = Kit.new("Frame", {
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 150),
			ClipsDescendants = true,
			ZIndex = Z + 1,
			Parent = detailBody,
		})
		Kit.gradient(header, Theme.lighten(color, 0.35), color, 115)
		Kit.label({
			Text = archetype.Kanji,
			Font = Theme.Fonts.Bold,
			TextSize = 120,
			Color = C.White,
			Transparency = 0.55,
			AlignX = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -16, 1, 20),
			ZIndex = Z + 1,
			Parent = header,
		})
		local heading = Kit.title({
			Text = string.upper(archetype.Name),
			TextSize = 34,
			StrokeColor = Theme.darken(color, 0.4),
			Size = UDim2.new(1, -40, 0, 44),
			Position = UDim2.fromOffset(20, 40),
			ZIndex = Z + 2,
			Parent = header,
		})
		Kit.pop(heading.Instance, 0.9)
		Kit.label({
			Text = archetype.Title,
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.Body,
			Color = C.White,
			Stroke = 1.2,
			StrokeColor = Theme.darken(color, 0.4),
			Size = UDim2.new(1, -40, 0, 22),
			Position = UDim2.fromOffset(20, 88),
			ZIndex = Z + 2,
			Parent = header,
		})
		local tags = Kit.box({
			Size = UDim2.new(1, -40, 0, 24),
			Position = UDim2.fromOffset(20, 116),
			ZIndex = Z + 2,
			Parent = header,
		})
		Kit.list(tags, 6, true)
		for order, tag in
			{
				Kit.pill(tags, Theme.rarityName(archetype.Rarity), C.White, 1, Theme.darken(color, 0.3)),
				Kit.pill(tags, POSTE_LABELS[archetype.Poste], C.Ink, 2),
			}
		do
			tag.LayoutOrder = order
			for _, object in tag:GetDescendants() do
				if object:IsA("GuiObject") then
					object.ZIndex = Z + 3
				end
			end
			tag.ZIndex = Z + 2
		end
		local body = Kit.box({
			Size = UDim2.new(1, -32, 1, -236),
			Position = UDim2.fromOffset(16, 162),
			ZIndex = Z + 1,
			Parent = detailBody,
		})
		local powers = Kit.scroll({ ZIndex = Z + 1, Parent = body })
		Kit.list(powers, 8)
		Kit.label({
			Text = archetype.Description,
			TextSize = Theme.Text.Small,
			Color = C.TextMuted,
			Wrap = true,
			Size = UDim2.new(1, -8, 0, 0),
			AutoSize = Enum.AutomaticSize.Y,
			Order = 0,
			ZIndex = Z + 1,
			Parent = powers,
		})
		for _, power in archetype.Powers do
			Cards.power(powers, power, { Size = UDim2.new(1, -8, 0, 112), Order = power.Slot, ZIndex = Z + 1 })
		end
		local favorite = profile ~= nil and profile.SelectedArchetype[archetype.Poste] == archetype.Id
		local choose = Kit.button({
			Text = "",
			Variant = if favorite then "Success" else "Primary",
			TextSize = Theme.Text.Body,
			Size = UDim2.new(1, -32, 0, 52),
			Position = UDim2.new(0, 16, 1, -66),
			ZIndex = Z + 1,
			Parent = detailBody,
			OnClick = function()
				State.request("LockerAction", "SelectArchetype", archetype.Poste, archetype.Id)
			end,
		})
		choose.SetText(
			if not owned
				then "À OBTENIR DANS LES BALLES"
				elseif favorite then `FAVORI · {string.upper(POSTE_LABELS[archetype.Poste])}`
				else `CHOISIR · {string.upper(POSTE_LABELS[archetype.Poste])}`
		)
		choose.SetEnabled(owned and not favorite)
	end

	renderCollection = function()
		Kit.clear(grid)
		local profile = State.Profile
		local list = {}
		for _, poste in Archetypes.PosteOrder do
			if filter == "Tous" or filter == poste then
				for _, archetype in Archetypes.byPoste(poste) do
					table.insert(list, archetype)
				end
			end
		end
		table.sort(list, function(a, b)
			local ownedA = profile ~= nil and profile.Archetypes[a.Id] == true
			local ownedB = profile ~= nil and profile.Archetypes[b.Id] == true
			if ownedA ~= ownedB then
				return ownedA
			end
			if rank(a.Rarity) ~= rank(b.Rarity) then
				return rank(a.Rarity) > rank(b.Rarity)
			end
			return a.Name < b.Name
		end)
		local owned = 0
		for index, archetype in list do
			local isOwned = profile ~= nil and profile.Archetypes[archetype.Id] == true
			if isOwned then
				owned += 1
			end
			local favorite = profile ~= nil and profile.SelectedArchetype[archetype.Poste] == archetype.Id
			Cards.archetype(grid, archetype, {
				Owned = isOwned,
				Selected = focused == archetype.Id,
				Badge = if favorite then "Favori" else nil,
				Order = index,
				ZIndex = Z + 1,
				OnClick = function()
					focused = archetype.Id
					renderCollection()
				end,
			})
		end
		count.Text = `{owned} / {#list} possédés`
		renderDetail()
	end
	Kit.segmented({
		Options = filterOptions,
		Value = filter,
		Size = UDim2.fromOffset(460, 44),
		ZIndex = Z,
		Parent = collection,
		OnChange = function(value: string)
			filter = value
			renderCollection()
		end,
	})
	table.insert(refreshers, function()
		if sections["Archétypes"].Visible then
			renderCollection()
		end
	end)

	-- COSMÉTIQUES ----------------------------------------------------------------------------------------
	local cosmetics = section("Cosmétiques")
	local packCard = Kit.surface({
		Color = C.White,
		Size = UDim2.new(1, 0, 0, 132),
		Radius = 16,
		BorderThickness = 2,
		Clip = true,
		ZIndex = Z,
		Parent = cosmetics,
	})
	local packArt = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 200, 1, 0),
		ZIndex = Z,
		Parent = packCard,
	})
	Kit.gradient(packArt, Theme.lighten(C.Sky, 0.4), C.Sky, 110)
	local packIcon = Kit.icon("Cards", packArt, 84, C.White, Z + 1)
	packIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	packIcon.Position = UDim2.fromScale(0.5, 0.5)
	Kit.label({
		Text = Packs.Cosmetic.Name,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H2,
		Color = C.Text,
		Size = UDim2.fromOffset(360, 32),
		Position = UDim2.fromOffset(222, 16),
		ZIndex = Z + 1,
		Parent = packCard,
	})
	Kit.label({
		Text = "Un masque, une paire de gants ou de chaussures. 100 % esthétique.",
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Size = UDim2.fromOffset(420, 20),
		Position = UDim2.fromOffset(222, 50),
		ZIndex = Z + 1,
		Parent = packCard,
	})
	local packStock = Kit.label({
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Small,
		Color = C.Success,
		Size = UDim2.fromOffset(300, 20),
		Position = UDim2.fromOffset(222, 76),
		ZIndex = Z + 1,
		Parent = packCard,
	})
	local oddsText = {}
	for _, rarity in Rarities.Order do
		local chance = (Packs.Cosmetic.Odds :: any)[rarity]
		if chance then
			table.insert(oddsText, `{Theme.rarityName(rarity)} {chance} %`)
		end
	end
	Kit.label({
		Text = table.concat(oddsText, "  ·  "),
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Tiny,
		Color = C.TextFaint,
		Size = UDim2.fromOffset(560, 18),
		Position = UDim2.fromOffset(222, 100),
		ZIndex = Z + 1,
		Parent = packCard,
	})
	local packActions = Kit.box({
		Size = UDim2.fromOffset(440, 50),
		Position = UDim2.new(1, -18, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		ZIndex = Z + 1,
		Parent = packCard,
	})
	Kit.list(packActions, 8, true, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	Kit.button({
		Text = `{Format.number(Packs.Cosmetic.Price)} HC`,
		Variant = "Primary",
		Size = UDim2.fromOffset(130, 50),
		Order = 1,
		ZIndex = Z + 1,
		Parent = packActions,
		OnClick = function()
			State.request("ShopAction", "BuyCosmeticPack", 1)
		end,
	})
	local robuxOne = Kit.button({
		Text = "",
		Variant = "Success",
		Size = UDim2.fromOffset(130, 50),
		Order = 2,
		ZIndex = Z + 1,
		Parent = packActions,
		OnClick = function()
			State.request("ShopAction", "BuyProduct", "CosmeticPack")
		end,
	})
	local openPack = Kit.button({
		Text = "OUVRIR",
		Variant = "Secondary",
		Size = UDim2.fromOffset(150, 50),
		Order = 3,
		ZIndex = Z + 1,
		Parent = packActions,
		OnClick = function()
			open("Cosmetic", nil, C.Sky, C.White)
		end,
	})
	table.insert(refreshers, function()
		local profile = State.Profile
		local stock = if profile then profile.CosmeticPacks else 0
		packStock.Text = if stock > 0 then `{stock} pack(s) en stock` else "Aucun pack en stock"
		packStock.TextColor3 = if stock > 0 then C.Success else C.TextMuted
		openPack.SetEnabled(stock > 0)
		robuxOne.SetEnabled(products.CosmeticPack == true)
		robuxOne.SetText(if products.CosmeticPack then `{Config.ProductRobuxPrice.CosmeticPack} R$` else "Bientôt")
	end)

	local slot = Cosmetics.SlotOrder[1]
	local slotOptions = {}
	for _, id in Cosmetics.SlotOrder do
		table.insert(slotOptions, { Id = id, Label = Cosmetics.Slots[id].Name })
	end
	local cosmeticGrid = Kit.scroll({
		Size = UDim2.new(1, 0, 1, -208),
		Position = UDim2.fromOffset(0, 208),
		ZIndex = Z,
		Parent = cosmetics,
	})
	Kit.grid(cosmeticGrid, Vector2.new(158, 200), 14)
	Kit.padding(cosmeticGrid, 6, 6)
	local function renderCosmetics()
		Kit.clear(cosmeticGrid)
		local profile = State.Profile
		local list = table.clone(Cosmetics.List)
		table.sort(list, function(a, b)
			local ownedA = profile ~= nil and (profile.Cosmetics[a.Id] or 0) > 0
			local ownedB = profile ~= nil and (profile.Cosmetics[b.Id] or 0) > 0
			if ownedA ~= ownedB then
				return ownedA
			end
			return rank(a.Rarity) > rank(b.Rarity)
		end)
		local order = 0
		for _, item in list do
			if item.Slot == slot then
				order += 1
				local amount = if profile then profile.Cosmetics[item.Id] or 0 else 0
				local equipped = profile ~= nil and profile.Equipped[item.Slot] == item.Id
				Cards.cosmetic(cosmeticGrid, item, {
					Owned = amount > 0,
					Selected = equipped,
					Count = amount,
					Order = order,
					ZIndex = Z + 1,
					OnClick = if amount > 0
						then function()
							State.request("LockerAction", "EquipCosmetic", item.Slot, if equipped then nil else item.Id)
						end
						else nil,
				})
			end
		end
	end
	Kit.segmented({
		Options = slotOptions,
		Value = slot,
		Color = C.Sky,
		Size = UDim2.fromOffset(420, 44),
		Position = UDim2.fromOffset(0, 150),
		ZIndex = Z,
		Parent = cosmetics,
		OnChange = function(value: string)
			slot = value :: any
			renderCosmetics()
		end,
	})
	Kit.label({
		Text = "Clique sur un objet possédé pour l'équiper ou le retirer.",
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -440, 0, 44),
		Position = UDim2.new(1, 0, 0, 150),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = Z,
		Parent = cosmetics,
	})
	table.insert(refreshers, function()
		if sections["Cosmétiques"].Visible then
			renderCosmetics()
		end
	end)

	-- TENUES -------------------------------------------------------------------------------------------
	local kits = section("Tenues")
	local kitGrid = Kit.scroll({ ZIndex = Z, Parent = kits })
	Kit.grid(kitGrid, Vector2.new(276, 268), 16)
	Kit.padding(kitGrid, 6, 6)
	local function jersey(parent: Instance, kit: any, z: number)
		local team = Theme.Team.Rouge
		local holder = Kit.box({
			Size = UDim2.fromOffset(120, 120),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = z,
			Parent = parent,
		})
		for _, side in { -1, 1 } do
			local sleeve = Kit.new("Frame", {
				BackgroundColor3 = team.Main,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, side * 46, 0, 30),
				Size = UDim2.fromOffset(40, 54),
				Rotation = side * 28,
				ZIndex = z,
				Parent = holder,
			})
			Kit.corner(sleeve, 8)
			Kit.border(sleeve, C.White, 2)
		end
		local body = Kit.new("Frame", {
			BackgroundColor3 = team.Main,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.08),
			Size = UDim2.fromOffset(78, 104),
			ZIndex = z + 1,
			Parent = holder,
		})
		Kit.corner(body, 10)
		Kit.border(body, C.White, 2)
		Kit.gradient(body, Theme.lighten(team.Main, 0.15), team.Dark, 90)
		local stripe = Kit.new("Frame", {
			BackgroundColor3 = kit.Accent,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 12),
			Position = UDim2.fromOffset(0, 36),
			ZIndex = z + 2,
			Parent = body,
		})
		Kit.border(stripe, kit.Trim, 1.5)
		Kit.label({
			Text = "10",
			Font = Theme.Fonts.Number,
			TextSize = 28,
			Color = kit.Accent,
			Stroke = 1.5,
			StrokeColor = kit.Trim,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.fromOffset(0, 54),
			ZIndex = z + 2,
			Parent = body,
		})
	end
	local function renderKits()
		Kit.clear(kitGrid)
		local profile = State.Profile
		local level = if profile then profile.Level else 1
		for index, kit in Progression.Kits do
			local unlocked = level >= kit.Level
			local selected = profile ~= nil and profile.Kit == kit.Id
			local card = Kit.surface({
				Order = index,
				Radius = 16,
				BorderColor = if selected then C.Accent else C.Border,
				BorderThickness = if selected then 4 else 2,
				Clip = true,
				ZIndex = Z + 1,
				Parent = kitGrid,
			})
			local stage = Kit.new("Frame", {
				BackgroundColor3 = C.Surface2,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 150),
				ZIndex = Z + 1,
				Parent = card,
			})
			jersey(stage, kit, Z + 2)
			Kit.label({
				Text = kit.Name,
				Font = Theme.Fonts.Display,
				TextSize = Theme.Text.H3,
				Color = C.Text,
				Size = UDim2.new(1, -32, 0, 26),
				Position = UDim2.fromOffset(16, 158),
				ZIndex = Z + 2,
				Parent = card,
			})
			Kit.label({
				Text = if unlocked then "Débloquée" else `Niveau {kit.Level} requis`,
				Font = Theme.Fonts.Semibold,
				TextSize = Theme.Text.Small,
				Color = if unlocked then C.Success else C.TextMuted,
				Size = UDim2.new(1, -32, 0, 18),
				Position = UDim2.fromOffset(16, 184),
				ZIndex = Z + 2,
				Parent = card,
			})
			local button = Kit.button({
				Text = if selected then "PORTÉE" elseif unlocked then "PORTER" else "VERROUILLÉE",
				Variant = if selected then "Success" else "Primary",
				Size = UDim2.new(1, -32, 0, 44),
				Position = UDim2.new(0, 16, 1, -56),
				ZIndex = Z + 2,
				Parent = card,
				OnClick = function()
					State.request("LockerAction", "SetKit", kit.Id)
				end,
			})
			button.SetEnabled(unlocked and not selected)
		end
	end
	table.insert(refreshers, function()
		if sections["Tenues"].Visible then
			renderKits()
		end
	end)

	-- HAND COINS ---------------------------------------------------------------------------------------
	local coins = section("Hand Coins")
	local offerRow = Kit.box({ Size = UDim2.new(1, 0, 0, 300), ZIndex = Z, Parent = coins })
	Kit.list(offerRow, 20, true, Enum.HorizontalAlignment.Center)
	local offers: { { Key: string, Amount: number, Stack: number, Bonus: string? } } = {
		{ Key = "Coins1000", Amount = 1000, Stack = 2, Bonus = nil },
		{ Key = "Coins5000", Amount = 5500, Stack = 5, Bonus = "+10 % offerts" },
	}
	for index, offer in offers do
		local card = Kit.surface({
			Size = UDim2.fromOffset(360, 300),
			Radius = Theme.RadiusLarge,
			BorderThickness = 2,
			Clip = true,
			Order = index,
			ZIndex = Z,
			Parent = offerRow,
		})
		local stage = Kit.new("Frame", {
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 150),
			ZIndex = Z,
			Parent = card,
		})
		Kit.gradient(stage, Color3.fromRGB(255, 236, 170), Color3.fromRGB(255, 196, 70), 110)
		for coin = 1, offer.Stack do
			local icon = Kit.icon("Coin", stage, 64, nil, Z + coin)
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.new(0.5, (coin - (offer.Stack + 1) / 2) * 30, 0.5, (coin % 2) * 8 - 4)
		end
		if offer.Bonus then
			local bonus = Kit.pill(stage, offer.Bonus, C.Danger)
			bonus.Position = UDim2.fromOffset(14, 14)
			bonus.ZIndex = Z + 10
			for _, object in bonus:GetDescendants() do
				if object:IsA("GuiObject") then
					object.ZIndex = Z + 11
				end
			end
		end
		Kit.label({
			Text = `{Format.number(offer.Amount)} Hand Coins`,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H2,
			Color = C.Text,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -40, 0, 34),
			Position = UDim2.fromOffset(20, 166),
			ZIndex = Z + 1,
			Parent = card,
		})
		local buy = Kit.button({
			Text = "",
			Variant = "Success",
			Size = UDim2.new(1, -40, 0, 52),
			Position = UDim2.new(0, 20, 1, -72),
			ZIndex = Z + 1,
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
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 320),
		ZIndex = Z,
		Parent = coins,
	})

	local function refresh()
		for _, refresher in refreshers do
			refresher()
		end
	end
	local select = Page.tabs(
		content,
		{ "Balles", "Archétypes", "Cosmétiques", "Tenues", "Hand Coins" },
		function(name)
			for key, frame in sections do
				frame.Visible = key == name
			end
			refresh()
		end,
		Z,
		Theme.Section.Archetypes
	)
	select("Balles")

	State.ProfileChanged:Connect(function()
		if page.IsOpen() then
			refresh()
		end
	end)
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

return ArchetypesScreen
