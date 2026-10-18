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
	local page = Page.full(parent, "Casier", "Tes archétypes, tes cosmétiques et tes tenues.")
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
	Kit.grid(grid, Vector2.new(168, 228), 14)
	Kit.padding(grid, 2, 2)
	local detail = Kit.surface({
		Color = C.Surface,
		Size = UDim2.new(0, 440, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		Radius = Theme.RadiusLarge,
		ZIndex = 13,
		Parent = archetypeSection,
	})

	local renderArchetypes: () -> ()

	local function renderDetail()
		Kit.clear(detail)
		local profile = State.Profile
		local archetype = Archetypes.get(selectedArchetype)
		if not archetype then
			return
		end
		local owned = profile ~= nil and profile.Archetypes[archetype.Id] == true
		local inner = Kit.box({
			Size = UDim2.new(1, -48, 1, -48),
			Position = UDim2.fromOffset(24, 24),
			ZIndex = 14,
			Parent = detail,
		})
		Kit.label({
			Text = string.upper(`{Theme.rarityName(archetype.Rarity)} · {POSTES[archetype.Poste]}`),
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.Tiny,
			Color = Theme.rarityColor(archetype.Rarity),
			Size = UDim2.new(1, 0, 0, 16),
			ZIndex = 15,
			Parent = inner,
		})
		Kit.label({
			Text = archetype.Name,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H2,
			Size = UDim2.new(1, 0, 0, 32),
			Position = UDim2.fromOffset(0, 20),
			ZIndex = 15,
			Parent = inner,
		})
		Kit.label({
			Text = archetype.Title,
			Font = Theme.Fonts.Semibold,
			Color = C.TextMuted,
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(0, 54),
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
			Position = UDim2.fromOffset(0, 86),
			ZIndex = 15,
			Parent = inner,
		})
		local powers = Kit.box({
			Size = UDim2.new(1, 0, 0, 280),
			Position = UDim2.fromOffset(0, 136),
			ZIndex = 15,
			Parent = inner,
		})
		Kit.list(powers, 10)
		for _, power in archetype.Powers do
			Cards.power(powers, power, { Order = power.Slot, ZIndex = 16 })
		end
		local favorite = profile ~= nil and profile.SelectedArchetype[archetype.Poste] == archetype.Id
		local button = Kit.button({
			Text = "",
			Variant = if favorite then "Secondary" else "Primary",
			Size = UDim2.new(1, 0, 0, 48),
			Position = UDim2.new(0, 0, 1, -48),
			ZIndex = 16,
			Parent = inner,
			OnClick = function()
				State.request("LockerAction", "SelectArchetype", archetype.Poste, archetype.Id)
			end,
		})
		button.SetText(
			if favorite
				then `Favori · {POSTES[archetype.Poste]}`
				else `Définir comme favori · {POSTES[archetype.Poste]}`
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
	Kit.grid(cosmeticGrid, Vector2.new(176, 200), 14)
	Kit.padding(cosmeticGrid, 2, 2)

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
	Kit.grid(kitGrid, Vector2.new(300, 196), 16)

	local function renderKits()
		Kit.clear(kitGrid)
		local profile = State.Profile
		local level = if profile then profile.Level else 1
		for index, kit in Progression.Kits do
			local unlocked = level >= kit.Level
			local selected = profile ~= nil and profile.Kit == kit.Id
			local card = Kit.surface({
				Color = C.Surface2,
				Order = index,
				ZIndex = 14,
				BorderColor = if selected then C.Accent else C.Border,
				Parent = kitGrid,
			})
			-- Deux maillots : rouge et bleu, avec la couleur d'accent de la tenue.
			for column, team in { "Rouge", "Bleu" } do
				local shirt = Kit.new("Frame", {
					BackgroundColor3 = if unlocked then Theme.Team[team].Main else C.Surface3,
					Size = UDim2.fromOffset(64, 76),
					Position = UDim2.fromOffset(20 + (column - 1) * 76, 20),
					ZIndex = 15,
					Parent = card,
				})
				Kit.corner(shirt, 6)
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
				Text = kit.Name,
				Font = Theme.Fonts.Bold,
				TextSize = Theme.Text.H3,
				Position = UDim2.fromOffset(180, 20),
				Size = UDim2.new(1, -196, 0, 26),
				ZIndex = 15,
				Parent = card,
			})
			Kit.label({
				Text = if unlocked then "Débloquée" else `Niveau {kit.Level}`,
				TextSize = Theme.Text.Small,
				Color = if unlocked then C.Success else C.TextMuted,
				Position = UDim2.fromOffset(180, 48),
				Size = UDim2.new(1, -196, 0, 18),
				ZIndex = 15,
				Parent = card,
			})
			local button = Kit.button({
				Text = if selected then "Portée" else "Porter",
				Variant = if selected then "Secondary" else "Primary",
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
	end, 12)
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
