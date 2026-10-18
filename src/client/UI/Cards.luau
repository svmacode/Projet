--!strict
-- Cartes d'archétypes, de cosmétiques et de pouvoirs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local C = Theme.Colors

local Cards = {}

local POSTE_LABEL = { Gardien = "GARDIEN", Defenseur = "DÉFENSEUR", Attaquant = "ATTAQUANT" }
local SLOT_GLYPH = { Mask = "面", Gloves = "手", Shoes = "足" }

type Props = { [string]: any }

local function rarityGradient(rarity: string): ColorSequence
	local info = Rarities.get(rarity)
	if not info then
		return ColorSequence.new(C.Steel)
	end
	if rarity == "Mythique" then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 160)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(150, 70, 255)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(40, 210, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 80)),
		})
	end
	return ColorSequence.new(info.ColorLight, info.Color)
end

local function clickable(container: Frame, onClick: (() -> ())?)
	if not onClick then
		return
	end
	local hit = Kit.new("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 40,
		Parent = container,
	})
	local scale = container:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = container })
	hit.MouseEnter:Connect(function()
		Kit.tween(scale, Theme.Tween.Fast, { Scale = 1.04 })
	end)
	hit.MouseLeave:Connect(function()
		Kit.tween(scale, Theme.Tween.Fast, { Scale = 1 })
	end)
	hit.Activated:Connect(function()
		Kit.pop(container, 0.9)
		onClick()
	end)
end

function Cards.archetype(parent: Instance, archetype: Archetypes.Archetype, props: Props): Frame
	local owned = props.Owned ~= false
	local rarity = archetype.Rarity
	local face, container = Kit.panel({
		Name = archetype.Id,
		Size = props.Size or UDim2.fromOffset(200, 280),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Color = if owned then Theme.rarityColor(rarity) else Theme.rarityDark(rarity),
		Gradient = if owned then rarityGradient(rarity) else nil,
		GradientRotation = 100,
		StrokeThickness = if props.Selected then 6 else 4,
		StrokeColor = if props.Selected then C.Yellow else C.Ink,
		Order = props.Order,
		ZIndex = props.ZIndex or 3,
		Clip = true,
		Parent = parent,
	})
	local z = (props.ZIndex or 3) + 1
	-- Kanji géant en filigrane.
	Kit.text({
		Text = archetype.Kanji,
		Font = Theme.Fonts.Heavy,
		Color = if owned
			then Theme.shade(Theme.rarityColor(rarity), -0.25)
			else Theme.shade(Theme.rarityDark(rarity), 0.15),
		Size = UDim2.fromScale(1.1, 0.75),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -8,
		ZIndex = z,
		Parent = face,
	})
	if owned then
		-- Bande de couleur signature de l'archétype.
		local band = Kit.new("Frame", {
			BackgroundColor3 = archetype.Color,
			Size = UDim2.new(1.4, 0, 0, 16),
			Position = UDim2.fromScale(-0.2, 0.56),
			Rotation = -12,
			ZIndex = z,
			Parent = face,
		})
		Kit.stroke(band, 3)
	else
		Kit.text({
			Text = "?",
			Color = C.Paper,
			Stroke = C.Ink,
			StrokeThickness = 4,
			Size = UDim2.fromScale(0.5, 0.35),
			Position = UDim2.fromScale(0.5, 0.38),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = z + 1,
			Parent = face,
		})
	end
	local poste = Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		Size = UDim2.new(0.62, 0, 0, 24),
		Position = UDim2.fromOffset(8, 8),
		ZIndex = z + 1,
		Parent = face,
	})
	Kit.text({
		Text = POSTE_LABEL[archetype.Poste] or archetype.Poste,
		Color = C.Yellow,
		Size = UDim2.new(1, -8, 1, -4),
		Position = UDim2.fromOffset(4, 2),
		ZIndex = z + 2,
		Parent = poste,
	})
	local nameplate = Kit.new("Frame", {
		BackgroundColor3 = C.Paper,
		Size = UDim2.new(1, 0, 0.3, 0),
		Position = UDim2.fromScale(0, 0.7),
		ZIndex = z + 1,
		Parent = face,
	})
	Kit.stroke(nameplate, 3)
	Kit.text({
		Text = if owned then string.upper(archetype.Name) else "???",
		Color = C.Ink,
		Size = UDim2.new(1, -12, 0.5, 0),
		Position = UDim2.fromOffset(6, 4),
		ZIndex = z + 2,
		Parent = nameplate,
	})
	Kit.text({
		Text = if owned then archetype.Title else Theme.rarityName(rarity),
		Font = Theme.Fonts.Body,
		Color = Theme.rarityDark(rarity),
		Size = UDim2.new(1, -12, 0.36, 0),
		Position = UDim2.new(0, 6, 0.55, 0),
		ZIndex = z + 2,
		Parent = nameplate,
	})
	if props.Badge then
		local badge = Kit.new("Frame", {
			BackgroundColor3 = C.Red,
			Size = UDim2.fromOffset(84, 26),
			Position = UDim2.new(1, -90, 0, 40),
			Rotation = 6,
			ZIndex = z + 3,
			Parent = face,
		})
		Kit.stroke(badge, 2)
		Kit.text({ Text = props.Badge, Color = C.Paper, ZIndex = z + 4, Parent = badge })
	end
	clickable(container, props.OnClick)
	return container
end

function Cards.cosmetic(parent: Instance, item: Cosmetics.Cosmetic, props: Props): Frame
	local owned = props.Owned ~= false
	local face, container = Kit.panel({
		Name = item.Id,
		Size = props.Size or UDim2.fromOffset(170, 200),
		Color = if owned then Theme.rarityColor(item.Rarity) else Theme.rarityDark(item.Rarity),
		Gradient = if owned then rarityGradient(item.Rarity) else nil,
		StrokeThickness = if props.Selected then 6 else 4,
		StrokeColor = if props.Selected then C.Yellow else C.Ink,
		Order = props.Order,
		ZIndex = props.ZIndex or 3,
		Clip = true,
		Parent = parent,
	})
	local z = (props.ZIndex or 3) + 1
	-- Pastille de couleur principale de l'objet.
	local swatch = Kit.new("Frame", {
		BackgroundColor3 = item.Parts[1].Color,
		Size = UDim2.fromOffset(92, 92),
		Position = UDim2.new(0.5, 0, 0, 16),
		AnchorPoint = Vector2.new(0.5, 0),
		Rotation = 8,
		ZIndex = z,
		Parent = face,
	})
	Kit.stroke(swatch, 4)
	Kit.text({
		Text = SLOT_GLYPH[item.Slot] or "?",
		Font = Theme.Fonts.Heavy,
		Color = if item.Parts[2] then item.Parts[2].Color else C.Ink,
		Stroke = C.Ink,
		StrokeThickness = 2,
		Rotation = -8,
		ZIndex = z + 1,
		Parent = swatch,
	})
	Kit.text({
		Text = if owned then string.upper(item.Name) else "???",
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 2,
		Size = UDim2.new(1, -12, 0, 44),
		Position = UDim2.new(0, 6, 1, -80),
		ZIndex = z,
		Parent = face,
	})
	Kit.rarityChip(
		face,
		item.Rarity,
		{ Size = UDim2.new(0.8, 0, 0, 24), Position = UDim2.new(0.1, 0, 1, -32), ZIndex = z }
	)
	if props.Badge then
		local badge = Kit.new("Frame", {
			BackgroundColor3 = C.Green,
			Size = UDim2.fromOffset(90, 24),
			Position = UDim2.fromOffset(6, 6),
			Rotation = -6,
			ZIndex = z + 3,
			Parent = face,
		})
		Kit.stroke(badge, 2)
		Kit.text({ Text = props.Badge, Color = C.Ink, ZIndex = z + 4, Parent = badge })
	end
	clickable(container, props.OnClick)
	return container
end

function Cards.power(parent: Instance, power: Archetypes.Power, props: Props): Frame
	local labels = { "MOUVEMENT · 15 s", "TECHNIQUE · touches de balle", "ULTIME" }
	local face, container = Kit.panel({
		Name = power.Id,
		Size = props.Size or UDim2.new(1, -10, 0, 96),
		Color = C.Paper,
		Order = props.Order,
		ZIndex = props.ZIndex or 3,
		Parent = parent,
	})
	local z = (props.ZIndex or 3) + 1
	local number = Kit.new("Frame", {
		BackgroundColor3 = power.Color,
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.fromOffset(14, 16),
		Rotation = -6,
		ZIndex = z,
		Parent = face,
	})
	Kit.stroke(number, 4)
	Kit.text({
		Text = tostring(power.Slot),
		Color = C.Paper,
		Stroke = C.Ink,
		StrokeThickness = 3,
		ZIndex = z + 1,
		Parent = number,
	})
	Kit.text({
		Text = `{string.upper(power.Name)}  <font color="#E2203A">{power.Japanese}</font>`,
		Rich = true,
		Size = UDim2.new(1, -110, 0, 32),
		Position = UDim2.fromOffset(94, 8),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = z,
		Parent = face,
	})
	Kit.text({
		Text = labels[power.Slot] or "",
		Font = Theme.Fonts.Heavy,
		Color = C.Steel,
		Size = UDim2.new(1, -110, 0, 16),
		Position = UDim2.fromOffset(94, 40),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = z,
		Parent = face,
	})
	Kit.text({
		Text = power.Description,
		Font = Theme.Fonts.Body,
		Size = UDim2.new(1, -110, 0, 30),
		Position = UDim2.fromOffset(94, 58),
		AlignX = Enum.TextXAlignment.Left,
		MaxSize = 20,
		ZIndex = z,
		Parent = face,
	})
	return container
end

return Cards
