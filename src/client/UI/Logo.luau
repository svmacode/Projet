--!strict
-- Logo « HANDBALL LEGENDS » façon couverture de manga : lettrage Bangers
-- empilé, ombre rouge décalée, contour encre, sous-titre japonais.
-- Si une image de logo est importée (Theme.Images.Logo), elle est utilisée.

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local C = Theme.Colors

local Logo = {}

local function layeredWord(parent: Instance, text: string, size: UDim2, position: UDim2, rotation: number, face: Color3)
	local holder = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = rotation,
		Parent = parent,
	})
	-- Couches d'ombre (extrusion) puis face.
	for i = 6, 1, -1 do
		Kit.text({
			Text = text,
			Color = if i > 3 then C.Ink else C.RedDark,
			Stroke = C.Ink,
			StrokeThickness = 6,
			Position = UDim2.fromOffset(i * 2, i * 2),
			ZIndex = 2,
			Parent = holder,
		})
	end
	local main = Kit.text({
		Text = text,
		Color = face,
		Stroke = C.Ink,
		StrokeThickness = 6,
		ZIndex = 3,
		Parent = holder,
	})
	Kit.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.shade(face, 0.35)),
			ColorSequenceKeypoint.new(0.55, face),
			ColorSequenceKeypoint.new(1, Theme.shade(face, -0.15)),
		}),
		Rotation = 90,
		Parent = main,
	})
	return holder
end

-- Construit le logo dans `parent` (taille conseillée : 900×420).
function Logo.build(parent: Instance, size: UDim2, position: UDim2): Frame
	local logo = Kit.new("Frame", {
		Name = "Logo",
		BackgroundTransparency = 1,
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = parent,
	})
	if Theme.Images.Logo ~= "" then
		Kit.new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = Theme.Images.Logo,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 1),
			Parent = logo,
		})
		return logo
	end

	-- Balle en arrière-plan.
	local ball = Kit.ball(logo, 250, C.Yellow, C.Red, UDim2.fromScale(0.83, 0.3), Vector2.new(0.5, 0.5))
	ball.Rotation = 18
	ball.ZIndex = 1

	layeredWord(logo, "HANDBALL", UDim2.fromScale(0.95, 0.5), UDim2.fromScale(0.47, 0.3), -4, C.Yellow)
	layeredWord(logo, "LEGENDS", UDim2.fromScale(0.9, 0.5), UDim2.fromScale(0.52, 0.68), -4, C.Paper)

	-- Bandeau japonais.
	local band = Kit.new("Frame", {
		BackgroundColor3 = C.Red,
		Size = UDim2.fromScale(0.62, 0.13),
		Position = UDim2.fromScale(0.5, 0.97),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -4,
		ZIndex = 4,
		Parent = logo,
	})
	Kit.stroke(band, 4)
	Kit.text({
		Text = "ハンドボール・レジェンズ",
		Font = Theme.Fonts.Heavy,
		Color = C.Paper,
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		ZIndex = 5,
		Parent = band,
	})
	return logo
end

return Logo
