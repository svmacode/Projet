--!strict
-- Cartes : archétype, cosmétique, pouvoir.
-- Carte blanche arrondie ; le haut porte un dégradé de la couleur de rareté
-- avec le kanji de l'archétype, le bas le nom et les infos. Au survol la
-- carte se soulève légèrement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Kit = require(script.Parent.Kit)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Theme = require(script.Parent.Theme)

local C = Theme.Colors

local Cards = {}

export type CardOptions = {
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Order: number?,
	ZIndex: number?,
	Owned: boolean?,
	Selected: boolean?,
	Count: number?,
	Badge: string?,
	OnClick: (() -> ())?,
}

local POSTE_COLORS = { Gardien = C.Sky, Defenseur = C.Success, Attaquant = C.Accent }
local SLOT_COLORS = { C.Sky, Color3.fromRGB(124, 92, 246), C.Gold }

-- Coque commune : bouton transparent + carte qui se soulève au survol.
local function shell(parent: Instance, options: CardOptions, defaultSize: UDim2): (TextButton, Frame, UIStroke)
	local z = options.ZIndex or 1
	local holder = Kit.new("TextButton", {
		Name = "Carte",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Size = options.Size or defaultSize,
		Position = options.Position or UDim2.new(),
		AnchorPoint = options.AnchorPoint or Vector2.zero,
		LayoutOrder = options.Order or 0,
		ZIndex = z,
		Parent = parent,
	})
	local card = Kit.new("Frame", {
		Name = "Face",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -6),
		Position = UDim2.fromOffset(0, 3),
		ClipsDescendants = true,
		ZIndex = z,
		Parent = holder,
	})
	Kit.corner(card, 14)
	local stroke = Kit.border(card, C.Border, 2)
	if options.Selected then
		stroke.Color = C.Accent
		stroke.Thickness = 4
	end
	holder.MouseEnter:Connect(function()
		if options.OnClick then
			Kit.tween(card, Theme.Motion.Fast, { Position = UDim2.fromOffset(0, -1) })
			Kit.playSound(Theme.Sounds.Hover, 0.12)
		end
	end)
	holder.MouseLeave:Connect(function()
		Kit.tween(card, Theme.Motion.Base, { Position = UDim2.fromOffset(0, 3) })
	end)
	holder.Activated:Connect(function()
		if options.OnClick then
			Kit.playSound(Theme.Sounds.Click, 0.3)
			Kit.pop(card, 0.95)
			task.spawn(options.OnClick)
		end
	end)
	return holder, card, stroke
end

-- Zone haute en dégradé de couleur, avec reflets.
local function art(card: Frame, color: Color3, height: UDim, z: number): Frame
	local area = Kit.new("Frame", {
		Name = "Visuel",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.new(UDim.new(1, 0), height),
		ClipsDescendants = true,
		ZIndex = z,
		Parent = card,
	})
	Kit.gradient(area, Theme.lighten(color, 0.35), Theme.darken(color, 0.08), 120)
	-- Reflet en diagonale.
	Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.75, 0.3),
		Size = UDim2.new(0.3, 0, 2, 0),
		Rotation = 25,
		ZIndex = z,
		Parent = area,
	})
	return area
end

local function rarityTag(parent: Instance, rarity: string, z: number): Frame
	local info = Rarities.get(rarity)
	local color = if info then info.Color else C.TextMuted
	local pill = Kit.pill(parent, if info then info.Name else rarity, color)
	pill.ZIndex = z
	for _, child in pill:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = z + 1
		end
	end
	return pill
end

local function lockOverlay(card: Frame, z: number)
	local veil = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = card,
	})
	local icon = Kit.icon("Lock", veil, 30, C.TextFaint, z + 1)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.35)
end

function Cards.archetype(parent: Instance, archetype: Archetypes.Archetype, options: CardOptions): TextButton
	local z = options.ZIndex or 1
	local holder, card = shell(parent, options, UDim2.fromOffset(170, 230))
	local rarity = Rarities.get(archetype.Rarity)
	local color = if rarity then rarity.Color else archetype.Color
	local area = art(card, color, UDim.new(0.6, 0), z)
	Kit.label({
		Text = archetype.Kanji,
		Font = Theme.Fonts.Bold,
		TextSize = 72,
		Color = C.White,
		Transparency = 0.1,
		Stroke = 3,
		StrokeColor = Theme.darken(color, 0.35),
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 1,
		Parent = area,
	})
	-- Poste en haut à gauche.
	local poste = Archetypes.Postes[archetype.Poste]
	local posteTag = Kit.pill(area, poste.Short, POSTE_COLORS[archetype.Poste] or C.Sky)
	posteTag.Position = UDim2.fromOffset(8, 8)
	for _, object in posteTag:GetDescendants() do
		if object:IsA("GuiObject") then
			object.ZIndex = z + 3
		end
	end
	posteTag.ZIndex = z + 2
	if options.Badge then
		local badge = Kit.pill(area, options.Badge, C.Accent)
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -8, 0, 8)
		badge.ZIndex = z + 2
		for _, object in badge:GetDescendants() do
			if object:IsA("GuiObject") then
				object.ZIndex = z + 3
			end
		end
	end
	local info = Kit.box({
		Size = UDim2.new(1, -20, 0.4, -10),
		Position = UDim2.new(0, 10, 0.6, 6),
		ZIndex = z + 1,
		Parent = card,
	})
	Kit.label({
		Text = archetype.Name,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H3 - 2,
		Color = C.Text,
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = z + 2,
		Parent = info,
	})
	Kit.label({
		Text = archetype.Title,
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Tiny,
		Color = C.TextMuted,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 22),
		ZIndex = z + 2,
		Parent = info,
	})
	local tag = rarityTag(info, archetype.Rarity, z + 2)
	tag.Position = UDim2.new(0, 0, 1, -22)
	if options.Owned == false then
		lockOverlay(card, z + 4)
	end
	return holder
end

function Cards.cosmetic(parent: Instance, item: Cosmetics.Cosmetic, options: CardOptions): TextButton
	local z = options.ZIndex or 1
	local holder, card = shell(parent, options, UDim2.fromOffset(160, 200))
	local rarity = Rarities.get(item.Rarity)
	local color = if rarity then rarity.Color else C.Sky
	local area = art(card, color, UDim.new(0.58, 0), z)
	-- Aperçu : pastilles des couleurs de l'objet, en éventail.
	local swatches = Kit.box({
		Size = UDim2.fromOffset(120, 56),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = z + 1,
		Parent = area,
	})
	Kit.list(swatches, -12, true, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	for index = 1, math.min(3, #item.Parts) do
		local dot = Kit.new("Frame", {
			BackgroundColor3 = item.Parts[index].Color,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(46, 46),
			LayoutOrder = index,
			ZIndex = z + 1 + index,
			Parent = swatches,
		})
		Kit.round(dot)
		Kit.border(dot, C.White, 3)
	end
	local slot = Cosmetics.Slots[item.Slot]
	local slotTag = Kit.pill(area, slot.Single, C.Ink)
	slotTag.Position = UDim2.fromOffset(8, 8)
	slotTag.ZIndex = z + 2
	for _, object in slotTag:GetDescendants() do
		if object:IsA("GuiObject") then
			object.ZIndex = z + 3
		end
	end
	if options.Count and options.Count > 1 then
		local count = Kit.pill(area, `x{options.Count}`, C.White, nil, C.Ink)
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, -8, 0, 8)
		count.ZIndex = z + 2
		for _, object in count:GetDescendants() do
			if object:IsA("GuiObject") then
				object.ZIndex = z + 3
			end
		end
	end
	local info = Kit.box({
		Size = UDim2.new(1, -20, 0.42, -10),
		Position = UDim2.new(0, 10, 0.58, 6),
		ZIndex = z + 1,
		Parent = card,
	})
	Kit.label({
		Text = item.Name,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Small + 1,
		Color = C.Text,
		Size = UDim2.new(1, 0, 0, 20),
		ZIndex = z + 2,
		Parent = info,
	})
	local tag = rarityTag(info, item.Rarity, z + 2)
	tag.Position = UDim2.new(0, 0, 1, -24)
	if options.Selected then
		local equipped = Kit.pill(info, "Équipé", C.Success)
		equipped.AnchorPoint = Vector2.new(1, 0)
		equipped.Position = UDim2.new(1, 0, 1, -24)
		equipped.ZIndex = z + 2
		for _, object in equipped:GetDescendants() do
			if object:IsA("GuiObject") then
				object.ZIndex = z + 3
			end
		end
	end
	if options.Owned == false then
		lockOverlay(card, z + 4)
	end
	return holder
end

-- Pouvoir : pastille ronde numérotée de la couleur de l'emplacement,
-- nom et description.
function Cards.power(parent: Instance, power: Archetypes.Power, options: CardOptions): Frame
	local z = options.ZIndex or 1
	local color = SLOT_COLORS[power.Slot] or C.Sky
	local card = Kit.surface({
		Color = C.Surface2,
		Border = false,
		Radius = 12,
		Size = options.Size or UDim2.new(1, 0, 0, 88),
		Position = options.Position,
		Order = options.Order,
		ZIndex = z,
		Parent = parent,
	})
	local key = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(12, 12),
		ZIndex = z + 1,
		Parent = card,
	})
	Kit.round(key)
	Kit.gradient(key, Theme.lighten(color, 0.25), color, 90)
	Kit.label({
		Text = tostring(power.Slot),
		Font = Theme.Fonts.Number,
		TextSize = Theme.Text.H3,
		Color = C.White,
		Stroke = 1.5,
		StrokeColor = Theme.darken(color, 0.3),
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 2,
		Parent = key,
	})
	Kit.label({
		Text = power.Name,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Small + 1,
		Color = C.Text,
		Size = UDim2.new(1, -72, 0, 20),
		Position = UDim2.fromOffset(62, 12),
		ZIndex = z + 1,
		Parent = card,
	})
	Kit.label({
		Text = if power.Slot == 1
			then "Recharge 15 s"
			elseif power.Slot == 2 then "Se charge en touchant le ballon"
			else "Ultime",
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Tiny,
		Color = color,
		Size = UDim2.new(1, -72, 0, 16),
		Position = UDim2.fromOffset(62, 32),
		ZIndex = z + 1,
		Parent = card,
	})
	Kit.label({
		Text = power.Description,
		TextSize = Theme.Text.Tiny + 1,
		Color = C.TextMuted,
		Wrap = true,
		AlignY = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -24, 1, -60),
		Position = UDim2.fromOffset(12, 56),
		ZIndex = z + 1,
		Parent = card,
	})
	return card
end

return Cards
