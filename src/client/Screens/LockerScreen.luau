--!strict
-- CASIER : archétypes (avec leurs pouvoirs), cosmétiques, tenues.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Cards = require(script.Parent.Parent.UI.Cards)
local Kit = require(script.Parent.Parent.UI.Kit)
local Page = require(script.Parent.Parent.UI.Page)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local LockerScreen = {}

local POSTES = { Gardien = "Gardien", Defenseur = "Défenseur", Attaquant = "Attaquant" }

local function rank(rarity: string): number
	local info = Rarities.get(rarity)
	return if info then info.Rank else 0
end

function LockerScreen.create(parent: Instance): Page.Page
	local accent = Theme.Section.Locker
	local page = Page.full(parent, "Casier", "Tes archétypes, tes cosmétiques et tes tenues.", accent)
	local content = page.Content
	local sections: { [string]: Frame } = {}
	local current = "Archétypes"
	local selectedArchetype = "Hayato"
	local posteFilter = "Tous"
	local cosmeticSlot = "Mask"

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

	-- Archétypes ---------------------------------------------------------------------------------
	local archetypeSection = section("Archétypes")
	local grid = Kit.scroll({
		Size = UDim2.new(1, -470, 1, -56),
		Position = UDim2.fromOffset(0, 56),
		ZIndex = 13,
		Parent = archetypeSection,
	})
	Kit.grid(grid, Vector2.new(172, 236), 14)
	Kit.padding(grid, 4, 4)
	local detailPanel = Kit.surface({
		Color = C.White,
		Gradient = false,
		Size = UDim2.new(0, 440, 1, -8),
		Position = UDim2.new(1, -8, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		Radius = Theme.RadiusLarge,
		BorderThickness = 3,
		Shadow = true,
		ShadowColor = accent,
		Clip = true,
		ZIndex = 13,
		Parent = archetypeSection,
	})
	local detailGradient = Kit.gradient(detailPanel, C.Surface3, C.Background, 135)
	-- Contenu redessiné à chaque sélection (le cadre, lui, reste).
	local detail = Kit.box({ Name = "Detail", ZIndex = 13, Parent = detailPanel })

	local renderArchetypes: () -> ()

	local function renderDetail()
		Kit.clear(detail)
		local profile = State.Profile
		local archetype = Archetypes.get(selectedArchetype)
		if not archetype then
			return
		end
		local owned = profile ~= nil and profile.Archetypes[archetype.Id] == true
		local rarity = Theme.rarityColor(archetype.Rarity)
		detailGradient.Color = if owned
			then ColorSequence.new(Theme.darken(archetype.Color, 0.35), Theme.darken(rarity, 0.85))
			else ColorSequence.new(C.Surface3, C.Background)
		Kit.label({
			Text = archetype.Kanji,
			Font = Theme.Fonts.Hero,
			TextSize = 220,
			Color = C.White,
			AlignX = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -10, 0, 240),
			Position = UDim2.fromOffset(0, -30),
			ZIndex = 13,
			Parent = detail,
		}).TextTransparency =
			0.88
		Kit.halftone({
			Parent = detail,
			Color = rarity,
			Columns = 16,
			Rows = 7,
			Spacing = 14,
			Flip = true,
			Position = UDim2.new(1, 0, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
			ZIndex = 13,
		})
		local inner = Kit.box({
			Size = UDim2.new(1, -48, 1, -48),
			Position = UDim2.fromOffset(24, 24),
			ZIndex = 14,
			Parent = detail,
		})
		local tags = Kit.box({ Size = UDim2.new(1, 0, 0, 24), ZIndex = 15, Parent = inner })
		Kit.list(tags, 8, true, nil, Enum.VerticalAlignment.Center)
		for order, pill in
			{
				Kit.pill(tags, Theme.rarityName(archetype.Rarity), rarity, 1),
				Kit.pill(tags, POSTES[archetype.Poste], accent, 2),
			}
		do
			pill.Rotation = if order == 1 then -3 else 2
			for _, child in pill:GetDescendants() do
				if child:IsA("GuiObject") then
					child.ZIndex = 16
				end
			end
			pill.ZIndex = 15
		end
		local heading = Kit.title({
			Text = string.upper(archetype.Name),
			TextSize = 46,
			ShadowColor = if owned then archetype.Color else C.Surface3,
			Size = UDim2.new(1, 0, 0, 50),
			Position = UDim2.fromOffset(0, 24),
			Rotation = -2,
			ZIndex = 15,
			Parent = inner,
		})
		Kit.slam(heading.Instance, 1.3)
		Kit.label({
			Text = archetype.Title,
			Font = Theme.Fonts.Semibold,
			Color = C.TextMuted,
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(0, 76),
			ZIndex = 15,
			Parent = inner,
		})
		Kit.label({
			Text = if owned
				then archetype.Description
				else "Débloque cet archétype en ouvrant des balles dans la boutique.",
			TextSize = Theme.Text.Small,
			Color = C.TextMuted,
			Wrap = true,
			AlignY = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromOffset(0, 102),
			ZIndex = 15,
			Parent = inner,
		})
		local powers = Kit.box({
			Size = UDim2.new(1, 0, 0, 280),
			Position = UDim2.fromOffset(0, 148),
			ZIndex = 15,
			Parent = inner,
		})
		Kit.list(powers, 8)
		for _, power in archetype.Powers do
			Cards.power(powers, power, { Size = UDim2.new(1, 0, 0, 80), Order = power.Slot, ZIndex = 16 })
		end
		local favorite = profile ~= nil and profile.SelectedArchetype[archetype.Poste] == archetype.Id
		local button = Kit.button({
			Text = "",
			Variant = if favorite then "Secondary" else "Primary",
			Color = if favorite then nil else accent,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H3,
			Size = UDim2.new(1, -4, 0, 48),
			Position = UDim2.new(0, 0, 1, -48),
			ZIndex = 16,
			Parent = inner,
			OnClick = function()
				State.request("LockerAction", "SelectArchetype", archetype.Poste, archetype.Id)
			end,
		})
		button.SetText(
			if favorite
				then string.upper(`Favori · {POSTES[archetype.Poste]}`)
				else string.upper(`Définir comme favori · {POSTES[archetype.Poste]}`)
		)
		button.SetEnabled(owned and not favorite)
	end

	renderArchetypes = function()
		Kit.clear(grid)
		local profile = State.Profile
		local list = table.clone(Archetypes.List)
		table.sort(list, function(a, b)
			if rank(a.Rarity) ~= rank(b.Rarity) then
				return rank(a.Rarity) > rank(b.Rarity)
			end
			return a.Name < b.Name
		end)
		local order = 0
		for _, archetype in list do
			if posteFilter == "Tous" or archetype.Poste == posteFilter then
				order += 1
				local favorite = profile ~= nil and profile.SelectedArchetype[archetype.Poste] == archetype.Id
				Cards.archetype(grid, archetype, {
					Owned = profile ~= nil and profile.Archetypes[archetype.Id] == true,
					Selected = archetype.Id == selectedArchetype,
					Badge = if favorite then "FAVORI" else nil,
					Order = order,
					ZIndex = 14,
					OnClick = function()
						selectedArchetype = archetype.Id
						renderArchetypes()
						renderDetail()
					end,
				})
			end
		end
	end

	-- Cosmétiques ------------------------------------------------------------------------------------
	local cosmeticSection = section("Cosmétiques")
	local slotOptions = {}
	for _, slot in Cosmetics.SlotOrder do
		table.insert(slotOptions, { Id = slot, Label = Cosmetics.Slots[slot].Name })
	end
	local cosmeticGrid = Kit.scroll({
		Size = UDim2.new(1, 0, 1, -56),
		Position = UDim2.fromOffset(0, 56),
		ZIndex = 13,
		Parent = cosmeticSection,
	})
	Kit.grid(cosmeticGrid, Vector2.new(180, 208), 14)
	Kit.padding(cosmeticGrid, 4, 4)

	local function renderCosmetics()
		Kit.clear(cosmeticGrid)
		local profile = State.Profile
		local list = table.clone(Cosmetics.List)
		table.sort(list, function(a, b)
			return rank(a.Rarity) > rank(b.Rarity)
		end)
		local order = 0
		for _, item in list do
			if item.Slot == cosmeticSlot then
				order += 1
				local owned = profile ~= nil and (profile.Cosmetics[item.Id] or 0) > 0
				local equipped = profile ~= nil and profile.Equipped[item.Slot] == item.Id
				Cards.cosmetic(cosmeticGrid, item, {
					Owned = owned,
					Selected = equipped,
					Badge = if equipped then "ÉQUIPÉ" else nil,
					Order = order,
					ZIndex = 14,
					OnClick = if owned
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
		Size = UDim2.fromOffset(420, 40),
		TextSize = Theme.Text.Small,
		Color = accent,
		ZIndex = 13,
		Parent = cosmeticSection,
		OnChange = function(value: string)
			cosmeticSlot = value
			renderCosmetics()
		end,
	})

	-- Tenues ------------------------------------------------------------------------------------------
	local kitSection = section("Tenues")
	Kit.label({
		Text = "La couleur principale reste toujours celle de ton équipe : rouge ou bleu. Une nouvelle tenue tous les 10 niveaux.",
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Size = UDim2.new(1, 0, 0, 20),
		ZIndex = 13,
		Parent = kitSection,
	})
	local kitGrid = Kit.box({
		Size = UDim2.new(1, 0, 1, -40),
		Position = UDim2.fromOffset(0, 40),
		ZIndex = 13,
		Parent = kitSection,
	})
	Kit.grid(kitGrid, Vector2.new(300, 200), 18)
	Kit.padding(kitGrid, 4, 4)

	local function renderKits()
		Kit.clear(kitGrid)
		local profile = State.Profile
		local level = if profile then profile.Level else 1
		for index, kit in Progression.Kits do
			local unlocked = level >= kit.Level
			local selected = profile ~= nil and profile.Kit == kit.Id
			local card = Kit.surface({
				Color = C.White,
				Order = index,
				ZIndex = 14,
				Clip = true,
				BorderColor = if selected then accent else C.Ink,
				BorderThickness = if selected then 4 else 3,
				Parent = kitGrid,
			})
			-- Remplace l'ombrage par un dégradé teinté selon la tenue.
			for _, child in card:GetChildren() do
				if child:IsA("UIGradient") then
					child:Destroy()
				end
			end
			Kit.gradient(card, if unlocked then Theme.darken(kit.Accent, 0.45) else C.Surface2, C.Background, 135)
			Kit.label({
				Text = tostring(kit.Level),
				Font = Theme.Fonts.Number,
				TextSize = 120,
				Color = C.White,
				AlignX = Enum.TextXAlignment.Right,
				Size = UDim2.new(1, -8, 0, 130),
				Position = UDim2.fromOffset(0, 40),
				ZIndex = 14,
				Parent = card,
			}).TextTransparency =
				0.88
			-- Deux maillots : rouge et bleu, avec la couleur d'accent de la tenue.
			for column, team in { "Rouge", "Bleu" } do
				local shirt = Kit.new("Frame", {
					BackgroundColor3 = if unlocked then Theme.Team[team].Main else C.Surface3,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(64, 76),
					Position = UDim2.fromOffset(20 + (column - 1) * 76, 20),
					Rotation = if column == 1 then -5 else 5,
					ZIndex = 15,
					Parent = card,
				})
				Kit.corner(shirt, 6)
				Kit.border(shirt, C.Ink, 2.5)
				Kit.shade(shirt, 0.3)
				Kit.new("Frame", {
					BackgroundColor3 = if unlocked then kit.Trim else C.Surface2,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 8),
					ZIndex = 16,
					Parent = shirt,
				})
				Kit.new("Frame", {
					BackgroundColor3 = if unlocked then kit.Accent else C.Surface2,
					BorderSizePixel = 0,
					Size = UDim2.new(0, 10, 1, -8),
					Position = UDim2.new(0.5, -5, 0, 8),
					ZIndex = 16,
					Parent = shirt,
				})
			end
			Kit.label({
				Text = string.upper(kit.Name),
				Font = Theme.Fonts.Hero,
				TextSize = 26,
				Stroke = 1.5,
				Position = UDim2.fromOffset(180, 20),
				Size = UDim2.new(1, -196, 0, 26),
				ZIndex = 15,
				Parent = card,
			})
			Kit.label({
				Text = if unlocked then "DÉBLOQUÉE" else `NIVEAU {kit.Level}`,
				Font = Theme.Fonts.Display,
				TextSize = Theme.Text.Small,
				Color = if unlocked then C.Lime else C.TextMuted,
				Position = UDim2.fromOffset(180, 48),
				Size = UDim2.new(1, -196, 0, 18),
				ZIndex = 15,
				Parent = card,
			})
			local button = Kit.button({
				Text = if selected then "PORTÉE" else "PORTER",
				Variant = if selected then "Secondary" else "Primary",
				Color = if selected then nil else accent,
				Font = Theme.Fonts.Display,
				Size = UDim2.new(1, -40, 0, 44),
				Position = UDim2.new(0, 20, 1, -64),
				ZIndex = 15,
				Parent = card,
				OnClick = function()
					State.request("LockerAction", "SetKit", kit.Id)
				end,
			})
			button.SetEnabled(unlocked and not selected)
		end
	end

	local function refresh()
		if current == "Archétypes" then
			renderArchetypes()
			renderDetail()
		elseif current == "Cosmétiques" then
			renderCosmetics()
		else
			renderKits()
		end
	end
	-- Filtre par poste.
	Kit.segmented({
		Options = {
			{ Id = "Tous", Label = "Tous" },
			{ Id = "Gardien", Label = "Gardiens" },
			{ Id = "Defenseur", Label = "Défenseurs" },
			{ Id = "Attaquant", Label = "Attaquants" },
		},
		Size = UDim2.fromOffset(520, 40),
		TextSize = Theme.Text.Small,
		Color = accent,
		ZIndex = 13,
		Parent = archetypeSection,
		OnChange = function(value: string)
			posteFilter = value
			renderArchetypes()
		end,
	})

	local select = Page.tabs(content, { "Archétypes", "Cosmétiques", "Tenues" }, function(name)
		current = name
		for key, frame in sections do
			frame.Visible = key == name
		end
		refresh()
	end, 12, accent)
	select("Archétypes")

	State.ProfileChanged:Connect(function()
		if page.IsOpen() then
			refresh()
		end
	end)
	local open = page.Open
	page.Open = function()
		refresh()
		open()
	end
	return page
end

return LockerScreen
