--!strict
-- Écran CASIER : collection d'archétypes (avec leurs 3 pouvoirs),
-- cosmétiques à équiper, tenues débloquées tous les 10 niveaux.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Cards = require(script.Parent.Parent.UI.Cards)
local Kit = require(script.Parent.Parent.UI.Kit)
local ScreenFrame = require(script.Parent.Parent.UI.ScreenFrame)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local LockerScreen = {}

local POSTE_NAMES = { Gardien = "GARDIEN", Defenseur = "DÉFENSEUR", Attaquant = "ATTAQUANT" }

local function sortedArchetypes(): { Archetypes.Archetype }
	local list = table.clone(Archetypes.List)
	table.sort(list, function(a, b)
		local pa = table.find(Archetypes.PosteOrder, a.Poste) or 0
		local pb = table.find(Archetypes.PosteOrder, b.Poste) or 0
		if pa ~= pb then
			return pa < pb
		end
		local ra = (Rarities.get(a.Rarity) :: Rarities.RarityInfo).Rank
		local rb = (Rarities.get(b.Rarity) :: Rarities.RarityInfo).Rank
		return ra < rb
	end)
	return list
end

-- Aperçu d'une tenue : deux maillots (rouge et bleu) avec le motif.
local function kitPreview(parent: Instance, kit: Progression.Kit, z: number)
	for index, team in { "Rouge", "Bleu" } do
		local color = Theme.Team[team].Main
		local shirt = Kit.new("Frame", {
			BackgroundColor3 = color,
			Size = UDim2.fromOffset(70, 80),
			Position = UDim2.fromOffset(16 + (index - 1) * 84, 16),
			ZIndex = z,
			Parent = parent,
		})
		Kit.stroke(shirt, 3)
		local collar = Kit.new(
			"Frame",
			{ BackgroundColor3 = kit.Trim, Size = UDim2.new(1, 0, 0, 8), ZIndex = z + 1, Parent = shirt }
		)
		local _ = collar
		local accent = kit.Accent
		if kit.Pattern == "Plain" then
			for _, x in { 0, 1 } do
				Kit.new("Frame", {
					BackgroundColor3 = accent,
					Size = UDim2.new(0, 6, 1, 0),
					Position = UDim2.new(x, -x * 6, 0, 0),
					ZIndex = z + 1,
					Parent = shirt,
				})
			end
		elseif kit.Pattern == "Bolt" then
			Kit.new("Frame", {
				BackgroundColor3 = accent,
				Size = UDim2.fromOffset(12, 60),
				Position = UDim2.fromOffset(30, 12),
				Rotation = 30,
				ZIndex = z + 1,
				Parent = shirt,
			})
		elseif kit.Pattern == "Scales" then
			for row = 0, 2 do
				for column = 0, 2 do
					Kit.new("Frame", {
						BackgroundColor3 = accent,
						Size = UDim2.fromOffset(14, 10),
						Position = UDim2.fromOffset(6 + column * 21, 16 + row * 20),
						Rotation = 45,
						ZIndex = z + 1,
						Parent = shirt,
					})
				end
			end
		elseif kit.Pattern == "Armor" then
			Kit.new("Frame", {
				BackgroundColor3 = accent,
				Size = UDim2.new(1, 8, 0, 18),
				Position = UDim2.fromOffset(-4, 6),
				ZIndex = z + 1,
				Parent = shirt,
			})
			Kit.new("Frame", {
				BackgroundColor3 = kit.Trim,
				Size = UDim2.new(1, 0, 0, 6),
				Position = UDim2.fromOffset(0, 54),
				ZIndex = z + 1,
				Parent = shirt,
			})
		elseif kit.Pattern == "Stars" then
			for _, offset in { Vector2.new(12, 20), Vector2.new(44, 40), Vector2.new(20, 58) } do
				local star = Kit.new("Frame", {
					BackgroundColor3 = kit.Trim,
					Size = UDim2.fromOffset(10, 10),
					Position = UDim2.fromOffset(offset.X, offset.Y),
					Rotation = 45,
					ZIndex = z + 1,
					Parent = shirt,
				})
				Kit.stroke(star, 1)
			end
		elseif kit.Pattern == "Aura" then
			Kit.new("Frame", {
				BackgroundColor3 = accent,
				Size = UDim2.new(1, 0, 0, 6),
				Position = UDim2.fromOffset(0, 10),
				ZIndex = z + 1,
				Parent = shirt,
			})
			Kit.new("Frame", {
				BackgroundColor3 = accent,
				Size = UDim2.new(1, 0, 0, 6),
				Position = UDim2.new(0, 0, 1, -8),
				ZIndex = z + 1,
				Parent = shirt,
			})
		end
	end
end

function LockerScreen.create(parent: Instance, close: () -> ()): ScreenFrame.Screen
	local screen = ScreenFrame.new(parent, "CASIER", "ロッカー", C.Purple, close)
	local content = screen.Content
	local pages: { [string]: Frame } = {}
	local current = "ARCHÉTYPES"
	local selectedArchetype = "Hayato"
	local cosmeticSlot = "Mask"

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

	-- ARCHÉTYPES -------------------------------------------------------------------------------------
	local archetypePage = page("ARCHÉTYPES")
	local grid = Kit.scroll(archetypePage, { Size = UDim2.new(0, 560, 1, 0), ZIndex = 23 })
	Kit.grid(grid, Vector2.new(126, 176), 12)
	Kit.padding(grid, 6)
	local detail = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -590, 1, 0),
		Position = UDim2.fromOffset(590, 0),
		ZIndex = 23,
		Parent = archetypePage,
	})

	local function renderDetail()
		Kit.clear(detail)
		local profile = State.Profile
		local archetype = Archetypes.get(selectedArchetype)
		if not archetype then
			return
		end
		local owned = profile ~= nil and profile.Archetypes[archetype.Id] == true
		Cards.archetype(detail, archetype, { Size = UDim2.fromOffset(190, 260), Owned = owned, ZIndex = 24 })
		Kit.text({
			Text = if owned
				then archetype.Description
				else "Débloque cet archétype en ouvrant des Balles à la boutique.",
			Font = Theme.Fonts.Body,
			Size = UDim2.new(1, -210, 0, 110),
			Position = UDim2.fromOffset(210, 10),
			AlignX = Enum.TextXAlignment.Left,
			AlignY = Enum.TextYAlignment.Top,
			MaxSize = 22,
			ZIndex = 24,
			Parent = detail,
		})
		Kit.rarityChip(
			detail,
			archetype.Rarity,
			{ Position = UDim2.fromOffset(210, 130), Size = UDim2.fromOffset(170, 34), ZIndex = 24 }
		)
		local favorite = profile ~= nil and profile.SelectedArchetype[archetype.Poste] == archetype.Id
		local favButton = Kit.button({
			Text = if favorite
				then `★ FAVORI {POSTE_NAMES[archetype.Poste]}`
				else `CHOISIR EN {POSTE_NAMES[archetype.Poste]}`,
			Color = if favorite then C.Yellow else C.Green,
			Size = UDim2.fromOffset(300, 50),
			Position = UDim2.fromOffset(210, 190),
			ZIndex = 25,
			Parent = detail,
			OnClick = function()
				State.request("LockerAction", "SelectArchetype", archetype.Poste, archetype.Id)
			end,
		})
		favButton.SetEnabled(owned and not favorite)
		local powers = Kit.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -280),
			Position = UDim2.fromOffset(0, 280),
			ZIndex = 24,
			Parent = detail,
		})
		Kit.list(powers, 12)
		for _, power in archetype.Powers do
			Cards.power(powers, power, { Order = power.Slot, ZIndex = 25 })
		end
	end

	local function renderGrid()
		Kit.clear(grid)
		local profile = State.Profile
		for index, archetype in sortedArchetypes() do
			local owned = profile ~= nil and profile.Archetypes[archetype.Id] == true
			local favorite = profile ~= nil and profile.SelectedArchetype[archetype.Poste] == archetype.Id
			Cards.archetype(grid, archetype, {
				Owned = owned,
				Selected = archetype.Id == selectedArchetype,
				Badge = if favorite then "FAVORI" else nil,
				Order = index,
				ZIndex = 24,
				OnClick = function()
					selectedArchetype = archetype.Id
					renderGrid()
					renderDetail()
				end,
			})
		end
	end

	-- COSMÉTIQUES ------------------------------------------------------------------------------------
	local cosmeticPage = page("COSMÉTIQUES")
	local slotBar = Kit.new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), ZIndex = 23, Parent = cosmeticPage }
	)
	Kit.list(slotBar, 12, true)
	local cosmeticGrid =
		Kit.scroll(cosmeticPage, { Size = UDim2.new(1, 0, 1, -64), Position = UDim2.fromOffset(0, 64), ZIndex = 23 })
	Kit.grid(cosmeticGrid, Vector2.new(170, 200), 14)
	Kit.padding(cosmeticGrid, 6)
	local slotButtons: { [string]: Kit.Button } = {}

	local function renderCosmetics()
		Kit.clear(cosmeticGrid)
		local profile = State.Profile
		for slot, button in slotButtons do
			button.SetColor(if slot == cosmeticSlot then C.Yellow else C.PaperDark)
		end
		local order = 0
		for _, rarity in Rarities.Order do
			for _, item in Cosmetics.byRarity(rarity) do
				if item.Slot == cosmeticSlot then
					order += 1
					local owned = profile ~= nil and (profile.Cosmetics[item.Id] or 0) > 0
					local equipped = profile ~= nil and profile.Equipped[item.Slot] == item.Id
					Cards.cosmetic(cosmeticGrid, item, {
						Owned = owned,
						Selected = equipped,
						Badge = if equipped then "ÉQUIPÉ" else nil,
						Order = order,
						ZIndex = 24,
						OnClick = if owned
							then function()
								State.request(
									"LockerAction",
									"EquipCosmetic",
									item.Slot,
									if equipped then nil else item.Id
								)
							end
							else nil,
					})
				end
			end
		end
	end
	for index, slot in Cosmetics.SlotOrder do
		slotButtons[slot] = Kit.button({
			Text = string.upper(Cosmetics.Slots[slot].Name),
			Color = C.PaperDark,
			Size = UDim2.fromOffset(190, 44),
			Order = index,
			ZIndex = 24,
			Parent = slotBar,
			OnClick = function()
				cosmeticSlot = slot
				renderCosmetics()
			end,
		})
	end

	-- TENUES -------------------------------------------------------------------------------------------
	local kitPage = page("TENUES")
	local kitGrid =
		Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 23, Parent = kitPage })
	Kit.grid(kitGrid, Vector2.new(330, 200), 18)
	Kit.text({
		Text = "Ta tenue garde toujours la couleur de ton équipe (ROUGE ou BLEU). Une nouvelle tenue tous les 10 niveaux !",
		Font = Theme.Fonts.Body,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 1, -30),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 23,
		Parent = kitPage,
	})
	local function renderKits()
		Kit.clear(kitGrid)
		local profile = State.Profile
		local level = if profile then profile.Level else 1
		for index, kit in Progression.Kits do
			local unlocked = level >= kit.Level
			local selected = profile ~= nil and profile.Kit == kit.Id
			local face, _ = Kit.panel({
				Size = UDim2.fromScale(1, 1),
				Color = if unlocked then C.Paper else C.InkSoft,
				StrokeColor = if selected then C.Yellow else C.Ink,
				StrokeThickness = if selected then 6 else 4,
				Order = index,
				ZIndex = 24,
				Parent = kitGrid,
			})
			kitPreview(face, kit, 25)
			Kit.text({
				Text = string.upper(kit.Name),
				Color = if unlocked then C.Ink else C.Paper,
				Size = UDim2.new(0, 140, 0, 40),
				Position = UDim2.fromOffset(180, 16),
				AlignX = Enum.TextXAlignment.Left,
				ZIndex = 25,
				Parent = face,
			})
			Kit.text({
				Text = if unlocked then "Débloquée" else `Niveau {kit.Level}`,
				Font = Theme.Fonts.Heavy,
				Color = if unlocked then C.Green else C.Yellow,
				Size = UDim2.new(0, 140, 0, 24),
				Position = UDim2.fromOffset(180, 60),
				AlignX = Enum.TextXAlignment.Left,
				ZIndex = 25,
				Parent = face,
			})
			local button = Kit.button({
				Text = if selected then "PORTÉE" else "PORTER",
				Color = if selected then C.Yellow else C.Green,
				Size = UDim2.new(1, -32, 0, 46),
				Position = UDim2.new(0, 16, 1, -62),
				ZIndex = 26,
				Parent = face,
				OnClick = function()
					State.request("LockerAction", "SetKit", kit.Id)
				end,
			})
			button.SetEnabled(unlocked and not selected)
		end
	end

	local function refresh()
		if current == "ARCHÉTYPES" then
			renderGrid()
			renderDetail()
		elseif current == "COSMÉTIQUES" then
			renderCosmetics()
		else
			renderKits()
		end
	end

	local select = ScreenFrame.tabs(content, { "ARCHÉTYPES", "COSMÉTIQUES", "TENUES" }, function(name)
		current = name
		for key, frame in pages do
			frame.Visible = key == name
		end
		refresh()
	end)
	select("ARCHÉTYPES")

	State.ProfileChanged:Connect(function()
		if screen.Container.Visible then
			refresh()
		end
	end)
	local open = screen.Open
	screen.Open = function()
		refresh()
		open()
	end
	return screen
end

return LockerScreen
