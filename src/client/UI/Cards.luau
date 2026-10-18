--!strict
-- Cartes d'archétypes, de cosmétiques et lignes de pouvoirs.

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

type Props = { [string]: any }

local function initials(name: string): string
	local parts = string.split(name, " ")
	local first = string.sub(parts[1] or "", 1, 1)
	local second = string.sub(parts[2] or "", 1, 1)
	return string.upper(first .. second)
end

local function interactive(card: GuiObject, onClick: (() -> ())?, selected: boolean)
	if not onClick then
		return
	end
	local hit = Kit.new("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = card.ZIndex + 10,
		Parent = card,
	})
	local stroke = card:FindFirstChildOfClass("UIStroke")
	hit.MouseEnter:Connect(function()
		if stroke and not selected then
			stroke.Color = C.BorderStrong
		end
		Kit.tween(card, Theme.Motion.Fast, { BackgroundColor3 = C.Surface3 })
	end)
	hit.MouseLeave:Connect(function()
		if stroke and not selected then
			stroke.Color = C.Border
		end
		Kit.tween(card, Theme.Motion.Fast, { BackgroundColor3 = C.Surface2 })
	end)
	hit.Activated:Connect(function()
		Kit.pop(card, 0.97)
		onClick()
	end)
end

function Cards.archetype(parent: Instance, archetype: Archetypes.Archetype, props: Props): Frame
	local owned = props.Owned ~= false
	local z = props.ZIndex or 2
	local card = Kit.surface({
		Name = archetype.Id,
		Color = C.Surface2,
		Size = props.Size or UDim2.fromOffset(176, 236),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Clip = true,
		Order = props.Order,
		ZIndex = z,
		BorderColor = if props.Selected then C.Accent else C.Border,
		Parent = parent,
	})
	if props.Selected then
		(card:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 2
	end
	-- Visuel : aplat à la couleur de l'archétype et monogramme.
	local art = Kit.new("Frame", {
		BackgroundColor3 = if owned then Theme.darken(archetype.Color, 0.35) else C.Surface,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.6, 0),
		ZIndex = z + 1,
		Parent = card,
	})
	Kit.new("UIGradient", {
		Color = ColorSequence.new(
			if owned then Theme.darken(archetype.Color, 0.1) else C.Surface2,
			if owned then Theme.darken(archetype.Color, 0.55) else C.Surface
		),
		Rotation = 90,
		Parent = art,
	})
	Kit.label({
		Text = if owned then initials(archetype.Name) else "?",
		Font = Theme.Fonts.Display,
		TextSize = 64,
		Color = if owned then Theme.lighten(archetype.Color, 0.55) else C.TextFaint,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 2,
		Parent = art,
	})
	Kit.new("Frame", {
		BackgroundColor3 = Theme.rarityColor(archetype.Rarity),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 3),
		Position = UDim2.new(0, 0, 0.6, -3),
		ZIndex = z + 3,
		Parent = card,
	})
	local info = Kit.box({
		Size = UDim2.new(1, -24, 0.4, -12),
		Position = UDim2.new(0, 12, 0.6, 8),
		ZIndex = z + 1,
		Parent = card,
	})
	Kit.label({
		Text = if owned then archetype.Name else "Verrouillé",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Body,
		Color = if owned then C.Text else C.TextMuted,
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = z + 2,
		Parent = info,
	})
	Kit.label({
		Text = if owned then archetype.Title else POSTES[archetype.Poste],
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 22),
		ZIndex = z + 2,
		Parent = info,
	})
	Kit.label({
		Text = `{string.upper(Theme.rarityName(archetype.Rarity))}  ·  {string.upper(POSTES[archetype.Poste])}`,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = Theme.rarityColor(archetype.Rarity),
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 1, -18),
		ZIndex = z + 2,
		Parent = info,
	})
	if props.Badge then
		local badge = Kit.pill(card, props.Badge, C.Accent)
		badge.Position = UDim2.fromOffset(10, 10)
		badge.ZIndex = z + 4
		for _, child in badge:GetDescendants() do
			if child:IsA("GuiObject") then
				child.ZIndex = z + 5
			end
		end
	end
	interactive(card, props.OnClick, props.Selected == true)
	return card
end

function Cards.cosmetic(parent: Instance, item: Cosmetics.Cosmetic, props: Props): Frame
	local owned = props.Owned ~= false
	local z = props.ZIndex or 2
	local card = Kit.surface({
		Name = item.Id,
		Color = C.Surface2,
		Size = props.Size or UDim2.fromOffset(176, 200),
		Clip = true,
		Order = props.Order,
		ZIndex = z,
		BorderColor = if props.Selected then C.Accent else C.Border,
		Parent = parent,
	})
	if props.Selected then
		(card:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 2
	end
	-- Nuancier des couleurs de l'objet.
	local swatches =
		Kit.box({ Size = UDim2.new(1, -24, 0, 96), Position = UDim2.fromOffset(12, 12), ZIndex = z + 1, Parent = card })
	Kit.list(swatches, 6, true)
	local seen: { [string]: boolean } = {}
	local count = 0
	for _, spec in item.Parts do
		local key = spec.Color:ToHex()
		if not seen[key] and count < 3 then
			seen[key] = true
			count += 1
			local swatch = Kit.new("Frame", {
				BackgroundColor3 = if owned then spec.Color else C.Surface3,
				Size = UDim2.new(if count == 1 then 0.5 else 0.25, -4, 1, 0),
				LayoutOrder = count,
				ZIndex = z + 2,
				Parent = swatches,
			})
			Kit.corner(swatch, 6)
		end
	end
	Kit.label({
		Text = if owned then item.Name else "Verrouillé",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Body,
		Color = if owned then C.Text else C.TextMuted,
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 118),
		ZIndex = z + 1,
		Parent = card,
	})
	Kit.label({
		Text = SLOT_LABEL[item.Slot] or item.Slot,
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(12, 140),
		ZIndex = z + 1,
		Parent = card,
	})
	Kit.label({
		Text = string.upper(Theme.rarityName(item.Rarity)),
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = Theme.rarityColor(item.Rarity),
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.new(0, 12, 1, -26),
		ZIndex = z + 1,
		Parent = card,
	})
	if props.Badge then
		local badge = Kit.pill(card, props.Badge, C.Success)
		badge.Position = UDim2.new(1, -10, 0, 10)
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.ZIndex = z + 4
		for _, child in badge:GetDescendants() do
			if child:IsA("GuiObject") then
				child.ZIndex = z + 5
			end
		end
	end
	interactive(card, props.OnClick, props.Selected == true)
	return card
end

function Cards.power(parent: Instance, power: Archetypes.Power, props: Props): Frame
	local z = props.ZIndex or 2
	local row = Kit.surface({
		Name = power.Id,
		Color = C.Surface2,
		Size = props.Size or UDim2.new(1, 0, 0, 84),
		Order = props.Order,
		ZIndex = z,
		Parent = parent,
	})
	local key = Kit.new("Frame", {
		BackgroundColor3 = Theme.darken(power.Color, 0.3),
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.fromOffset(16, 16),
		ZIndex = z + 1,
		Parent = row,
	})
	Kit.corner(key, 8)
	Kit.label({
		Text = tostring(power.Slot),
		Font = Theme.Fonts.Display,
		TextSize = 26,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 2,
		Parent = key,
	})
	Kit.label({
		Text = power.Name,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.H3,
		Size = UDim2.new(1, -110, 0, 24),
		Position = UDim2.fromOffset(84, 10),
		ZIndex = z + 1,
		Parent = row,
	})
	Kit.label({
		Text = string.upper(POWER_KIND[power.Slot] or ""),
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = power.Color,
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
