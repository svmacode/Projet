--!strict
-- Cartes d'archétypes, de cosmétiques et lignes de pouvoirs, façon cartes
-- à collectionner d'animé : fond dégradé de la couleur de rareté, trame de
-- points, kanji en filigrane, lettrage BD cerclé d'encre, ombre dure.
--
-- Chaque carte est un support transparent (compatible avec les grilles) qui
-- porte une ombre dure, laquelle porte la face : au survol la face se
-- soulève de son ombre.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local C = Theme.Colors

local Cards = {}

local POSTES = { Gardien = "Gardien", Defenseur = "Défenseur", Attaquant = "Attaquant" }
local SLOT_LABEL = { Mask = "Masque", Gloves = "Gants", Shoes = "Chaussures" }
local POWER_KIND = { "Mouvement · 15 s", "Technique · touches de balle", "Ultime" }
local POWER_COLORS = { C.Cyan, C.Pink, C.Accent }

local DEPTH = 5

type Props = { [string]: any }

type Shell = { Holder: Frame, Shadow: Frame, Face: Frame, Stroke: UIStroke }

-- Support + ombre + face. La face est un enfant de l'ombre, donc toujours
-- dessinée au-dessus d'elle.
local function shell(name: string, parent: Instance, props: Props, color: Color3, z: number): Shell
	local holder = Kit.new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromOffset(176, 236),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.Order or 0,
		ZIndex = z,
		Parent = parent,
	})
	local shadow = Kit.new("Frame", {
		Name = "Ombre",
		BackgroundColor3 = if props.Selected then C.Accent else C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -DEPTH, 1, -DEPTH),
		Position = UDim2.fromOffset(DEPTH, DEPTH),
		ZIndex = z,
		Parent = holder,
	})
	Kit.corner(shadow, Theme.Radius)
	local face = Kit.new("Frame", {
		Name = "Face",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(-DEPTH, -DEPTH),
		ZIndex = z,
		Parent = shadow,
	})
	Kit.corner(face, Theme.Radius)
	local stroke = Kit.border(face, if props.Selected then C.Accent else C.Ink, if props.Selected then 4 else 3)
	return { Holder = holder, Shadow = shadow, Face = face, Stroke = stroke }
end

local function interactive(card: Shell, onClick: (() -> ())?)
	if not onClick then
		return
	end
	local hit = Kit.new("TextButton", {
		Name = "Zone",
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = card.Face.ZIndex + 20,
		Parent = card.Face,
	})
	local function lift(offset: number)
		Kit.tween(card.Face, Theme.Motion.Fast, { Position = UDim2.fromOffset(-DEPTH + offset, -DEPTH + offset) })
	end
	hit.MouseEnter:Connect(function()
		lift(-3)
	end)
	hit.MouseLeave:Connect(function()
		lift(0)
	end)
	hit.MouseButton1Down:Connect(function()
		lift(DEPTH)
	end)
	hit.MouseButton1Up:Connect(function()
		lift(0)
	end)
	hit.Activated:Connect(function()
		Kit.playSound(Theme.Sounds.Click, 0.35)
		onClick()
	end)
end

local function stickerBadge(face: Frame, text: string, color: Color3, z: number, rightSide: boolean)
	local badge = Kit.pill(face, text, color)
	badge.Position = if rightSide then UDim2.new(1, -8, 0, 8) else UDim2.fromOffset(8, 8)
	badge.AnchorPoint = if rightSide then Vector2.new(1, 0) else Vector2.zero
	badge.Rotation = if rightSide then 4 else -4
	badge.ZIndex = z
	for _, child in badge:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = z + 1
		end
	end
end

-- Archétype ------------------------------------------------------------------------------------------

function Cards.archetype(parent: Instance, archetype: Archetypes.Archetype, props: Props): Frame
	local owned = props.Owned ~= false
	local z = props.ZIndex or 2
	local rarity = Theme.rarityColor(archetype.Rarity)
	local card = shell(archetype.Id, parent, props, C.White, z)
	local face = card.Face
	if owned then
		Kit.gradient(face, Theme.lighten(rarity, 0.1), Theme.darken(archetype.Color, 0.55), 135)
	else
		Kit.gradient(face, C.Surface3, C.Background, 135)
	end

	-- Bande diagonale de la couleur de l'archétype.
	Kit.new("Frame", {
		BackgroundColor3 = if owned then archetype.Accent else C.Surface2,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.62, 0.32),
		Size = UDim2.new(0.34, 0, 1.6, 0),
		Rotation = 24,
		ZIndex = z + 1,
		Parent = face,
	})
	Kit.halftone({
		Parent = face,
		Color = C.White,
		Columns = 10,
		Rows = 6,
		Spacing = 12,
		Transparency = 0.78,
		Flip = true,
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = z + 1,
	})
	-- Kanji en filigrane.
	Kit.label({
		Text = if owned then archetype.Kanji else "?",
		Font = Theme.Fonts.Hero,
		TextSize = 92,
		Color = C.White,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0.62, 0),
		ZIndex = z + 2,
		Parent = face,
	}).TextTransparency =
		0.72
	-- Grand nom en lettrage BD.
	local name = Kit.title({
		Text = if owned then string.upper(archetype.Name) else "???",
		TextSize = 30,
		Color = C.White,
		ShadowColor = if owned then archetype.Color else C.Surface3,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -12, 0, 38),
		Position = UDim2.new(0, 6, 0.62, -40),
		Rotation = -4,
		ZIndex = z + 3,
		Parent = face,
	})
	name.Label.TextScaled = true
	name.Shadow.TextScaled = true

	-- Bas de carte : bandeau d'encre avec titre et poste.
	local foot = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.38, 0),
		Position = UDim2.fromScale(0, 0.62),
		ZIndex = z + 2,
		Parent = face,
	})
	Kit.gradient(foot, C.Ink, Theme.darken(rarity, 0.7), 90)
	Kit.new("Frame", {
		BackgroundColor3 = rarity,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 4),
		ZIndex = z + 3,
		Parent = foot,
	})
	Kit.label({
		Text = if owned then archetype.Title else "Verrouillé",
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Small,
		Color = if owned then C.TextMuted else C.TextFaint,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 10),
		ZIndex = z + 3,
		Parent = foot,
	})
	local poste = Kit.plate({
		Color = rarity,
		Size = UDim2.new(0, 104, 0, 24),
		Position = UDim2.new(0, 10, 1, -12),
		AnchorPoint = Vector2.new(0, 1),
		BorderThickness = 2,
		Shadow = false,
		ZIndex = z + 3,
		Parent = foot,
	})
	Kit.label({
		Text = string.upper(POSTES[archetype.Poste]),
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Small,
		Color = Theme.onColor(rarity),
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 4,
		Parent = poste,
	})
	Kit.label({
		Text = string.upper(Theme.rarityName(archetype.Rarity)),
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Small,
		Color = rarity,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.new(0.5, -10, 0, 24),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0, 1),
		ZIndex = z + 3,
		Parent = foot,
	})
	if props.Badge then
		stickerBadge(face, props.Badge, C.Accent, z + 6, false)
	end
	interactive(card, props.OnClick)
	return card.Holder
end

-- Cosmétique -------------------------------------------------------------------------------------------

function Cards.cosmetic(parent: Instance, item: Cosmetics.Cosmetic, props: Props): Frame
	local owned = props.Owned ~= false
	local z = props.ZIndex or 2
	local rarity = Theme.rarityColor(item.Rarity)
	local cardProps = table.clone(props)
	cardProps.Size = props.Size or UDim2.fromOffset(176, 200)
	local card = shell(item.Id, parent, cardProps, C.White, z)
	local face = card.Face
	Kit.gradient(
		face,
		if owned then Theme.lighten(rarity, 0.05) else C.Surface3,
		if owned then Theme.darken(rarity, 0.65) else C.Background,
		135
	)
	Kit.speedLines({
		Parent = face,
		Color = C.White,
		Count = 6,
		Transparency = 0.82,
		Size = UDim2.fromScale(1, 0.6),
		ZIndex = z + 1,
	})
	-- Nuancier des couleurs de l'objet : pastilles rondes cerclées d'encre.
	local swatches = Kit.box({
		Size = UDim2.new(1, -24, 0, 70),
		Position = UDim2.fromOffset(12, 22),
		ZIndex = z + 2,
		Parent = face,
	})
	Kit.list(swatches, -12, true, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local seen: { [string]: boolean } = {}
	local count = 0
	for _, spec in item.Parts do
		local key = spec.Color:ToHex()
		if not seen[key] and count < 3 then
			seen[key] = true
			count += 1
			local size = if count == 1 then 70 else 52
			local swatch = Kit.new("Frame", {
				BackgroundColor3 = if owned then spec.Color else C.Surface2,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(size, size),
				LayoutOrder = count,
				ZIndex = z + 5 - count,
				Parent = swatches,
			})
			Kit.corner(swatch, size)
			Kit.border(swatch, C.Ink, 3)
			Kit.shade(swatch, 0.3)
		end
	end
	local foot = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 82),
		Position = UDim2.new(0, 0, 1, -82),
		ZIndex = z + 2,
		Parent = face,
	})
	Kit.new("Frame", {
		BackgroundColor3 = rarity,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 4),
		ZIndex = z + 3,
		Parent = foot,
	})
	Kit.label({
		Text = if owned then string.upper(item.Name) else "VERROUILLÉ",
		Font = Theme.Fonts.Hero,
		TextSize = 22,
		Color = if owned then C.White else C.TextFaint,
		Stroke = 1.5,
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 10),
		ZIndex = z + 3,
		Parent = foot,
	})
	Kit.label({
		Text = SLOT_LABEL[item.Slot] or item.Slot,
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Size = UDim2.new(0.5, -10, 0, 18),
		Position = UDim2.new(0, 10, 1, -26),
		ZIndex = z + 3,
		Parent = foot,
	})
	Kit.label({
		Text = string.upper(Theme.rarityName(item.Rarity)),
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Small,
		Color = rarity,
		AlignX = Enum.TextXAlignment.Right,
		Size = UDim2.new(0.5, -10, 0, 18),
		Position = UDim2.new(0.5, 0, 1, -26),
		ZIndex = z + 3,
		Parent = foot,
	})
	if props.Badge then
		stickerBadge(face, props.Badge, C.Lime, z + 6, true)
	end
	interactive(card, props.OnClick)
	return card.Holder
end

-- Pouvoir ---------------------------------------------------------------------------------------------

function Cards.power(parent: Instance, power: Archetypes.Power, props: Props): Frame
	local z = props.ZIndex or 2
	local badgeColor = POWER_COLORS[power.Slot] or power.Color
	local row = Kit.surface({
		Name = power.Id,
		Color = C.Surface2,
		Size = props.Size or UDim2.new(1, 0, 0, 84),
		Order = props.Order,
		ZIndex = z,
		Clip = true,
		Parent = parent,
	})
	-- Lueur de la couleur du pouvoir à gauche.
	local glow = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.new(0.5, 0, 1, 0),
		ZIndex = z,
		Parent = row,
	})
	Kit.new("UIGradient", {
		Color = ColorSequence.new(power.Color),
		Transparency = NumberSequence.new(0.55, 1),
		Parent = glow,
	})
	-- Badge P1 / P2 / P3 incliné.
	local key = Kit.plate({
		Color = badgeColor,
		Size = UDim2.fromOffset(54, 54),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Rotation = -6,
		Shadow = false,
		ZIndex = z + 1,
		Parent = row,
	})
	Kit.label({
		Text = `P{power.Slot}`,
		Font = Theme.Fonts.Hero,
		TextSize = 30,
		Color = Theme.onColor(badgeColor),
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 2,
		Parent = key,
	})
	Kit.label({
		Text = string.upper(power.Name),
		Font = Theme.Fonts.Hero,
		TextSize = 24,
		Stroke = 1.5,
		Size = UDim2.new(1, -110, 0, 26),
		Position = UDim2.fromOffset(84, 8),
		ZIndex = z + 1,
		Parent = row,
	})
	Kit.label({
		Text = string.upper(POWER_KIND[power.Slot] or ""),
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Tiny + 1,
		Color = badgeColor,
		Size = UDim2.new(1, -110, 0, 16),
		Position = UDim2.fromOffset(84, 34),
		ZIndex = z + 1,
		Parent = row,
	})
	Kit.label({
		Text = power.Description,
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Size = UDim2.new(1, -110, 0, 20),
		Position = UDim2.fromOffset(84, 52),
		ZIndex = z + 1,
		Parent = row,
	})
	return row
end

return Cards
