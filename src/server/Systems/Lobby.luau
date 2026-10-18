--!strict
-- Le lobby : le lycée Seiryō et son quartier au coucher du soleil.
--
-- Campus au centre (bâtiment principal, gymnase, terrain extérieur, cour,
-- cerisiers), rues tout autour (passages piétons, poteaux électriques,
-- lampadaires, distributeurs), pâtés de maisons, immeubles et commerces,
-- puis une ligne de tours qui ferme l'horizon. Des murs invisibles gardent
-- les joueurs dans la zone jouable.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Clan = require(script.Parent.Clan)
local Outfit = require(script.Parent.Parent.Match.Outfit)
local PlayerData = require(script.Parent.PlayerData)
local ServerRole = require(script.Parent.Parent.Lib.ServerRole)

local Lobby = {}

local rng = Random.new(20261018)
local rgb = Color3.fromRGB
local M = Enum.Material

-- Palette du quartier.
local COLORS = {
	SchoolWall = rgb(238, 232, 218),
	SchoolTrim = rgb(196, 190, 178),
	Glass = rgb(120, 150, 175),
	GlassLit = rgb(255, 214, 160),
	Concrete = rgb(176, 172, 166),
	ConcreteDark = rgb(128, 124, 120),
	Asphalt = rgb(58, 58, 64),
	Sidewalk = rgb(170, 164, 156),
	Line = rgb(236, 234, 226),
	Pole = rgb(92, 88, 86),
	Wire = rgb(30, 30, 34),
	Grass = rgb(104, 142, 84),
	Dirt = rgb(176, 140, 102),
	Wood = rgb(120, 82, 58),
}

local HOUSE_WALLS =
	{ rgb(236, 226, 206), rgb(214, 204, 186), rgb(196, 180, 160), rgb(226, 214, 200), rgb(184, 170, 150) }
local ROOFS = { rgb(70, 76, 92), rgb(96, 70, 62), rgb(60, 84, 98), rgb(110, 98, 90), rgb(78, 64, 70) }
local APARTMENT_WALLS = { rgb(214, 208, 198), rgb(198, 192, 186), rgb(226, 216, 196), rgb(186, 182, 178) }
local AWNINGS = { rgb(200, 60, 56), rgb(40, 110, 170), rgb(46, 140, 96), rgb(220, 150, 50), rgb(120, 70, 150) }

-- Primitives --------------------------------------------------------------------------------------

local function part(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = collide ~= false
	p.Parent = parent
	return p
end

local function decor(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function wedge(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cframe
	w.Color = color
	w.Material = material or M.SmoothPlastic
	w.Parent = parent
	return w
end

local function cylinder(
	parent: Instance,
	length: number,
	diameter: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local c = part(parent, Vector3.new(length, diameter, diameter), cframe, color, material)
	c.Shape = Enum.PartType.Cylinder
	return c
end

local function sign(
	target: BasePart,
	face: Enum.NormalId,
	text: string,
	textColor: Color3,
	background: Color3,
	ppu: number?
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu or 30
	gui.LightInfluence = 0.2
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background
	label.BorderSizePixel = 0
	label.Text = text
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold)
	label.TextColor3 = textColor
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.Parent = label
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

-- Fenêtres : vitre sombre ou allumée (lumière chaude du soir).
local function window(parent: Instance, size: Vector3, cframe: CFrame, litChance: number)
	local lit = rng:NextNumber() < litChance
	local pane = part(
		parent,
		size,
		cframe,
		if lit then COLORS.GlassLit else COLORS.Glass,
		if lit then M.Neon else M.Glass,
		false
	)
	decor(pane)
	if not lit then
		pane.Reflectance = 0.25
	end
end

-- Arbres ------------------------------------------------------------------------------------------

local function sakura(parent: Instance, base: Vector3, scale: number)
	local tree = Instance.new("Model")
	tree.Name = "Cerisier"
	local trunkHeight = 7 * scale
	cylinder(
		tree,
		trunkHeight,
		1.3 * scale,
		CFrame.new(base + Vector3.new(0, trunkHeight / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(88, 62, 52),
		M.Wood
	)
	local pinks = { rgb(255, 196, 214), rgb(250, 176, 200), rgb(255, 214, 226), rgb(240, 160, 190) }
	for i = 1, 4 do
		local angle = i * math.pi / 2 + rng:NextNumber() * 0.6
		local branchLength = 4.5 * scale
		local direction = Vector3.new(math.cos(angle), 0.9, math.sin(angle)).Unit
		local start = base + Vector3.new(0, trunkHeight * 0.75, 0)
		local finish = start + direction * branchLength
		decor(
			cylinder(
				tree,
				branchLength,
				0.6 * scale,
				CFrame.lookAt((start + finish) / 2, finish) * CFrame.Angles(0, math.pi / 2, 0),
				rgb(88, 62, 52),
				M.Wood
			)
		)
		for _ = 1, 3 do
			local offset = Vector3.new(rng:NextNumber(-1.8, 1.8), rng:NextNumber(-0.6, 1.6), rng:NextNumber(-1.8, 1.8))
				* scale
			local blossom = part(
				tree,
				Vector3.one * rng:NextNumber(4.5, 6.5) * scale,
				CFrame.new(finish + offset),
				pick(pinks),
				M.SmoothPlastic,
				false
			)
			blossom.Shape = Enum.PartType.Ball
			decor(blossom)
		end
	end
	local crown = part(
		tree,
		Vector3.one * 7 * scale,
		CFrame.new(base + Vector3.new(0, trunkHeight + 2.5 * scale, 0)),
		pick(pinks),
		M.SmoothPlastic,
		false
	)
	crown.Shape = Enum.PartType.Ball
	decor(crown)
	local petals = Instance.new("ParticleEmitter")
	petals.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	petals.Color = ColorSequence.new(rgb(255, 200, 220))
	petals.Size = NumberSequence.new(0.22)
	petals.Rate = 2.5
	petals.Lifetime = NumberRange.new(6, 9)
	petals.Speed = NumberRange.new(0.5, 1.5)
	petals.SpreadAngle = Vector2.new(180, 180)
	petals.Acceleration = Vector3.new(0.8, -0.9, 0.4)
	petals.Rotation = NumberRange.new(0, 360)
	petals.RotSpeed = NumberRange.new(-60, 60)
	petals.Parent = crown
	tree.Parent = parent
end

local function shrub(parent: Instance, position: Vector3)
	local bush = part(
		parent,
		Vector3.new(rng:NextNumber(3, 5), rng:NextNumber(2, 3), rng:NextNumber(3, 5)),
		CFrame.new(position + Vector3.new(0, 1, 0)),
		rgb(70, 110, 64),
		M.Grass,
		false
	)
	bush.Shape = Enum.PartType.Ball
	decor(bush)
end

-- Mobilier urbain ------------------------------------------------------------------------------------

local wireAnchors: { Attachment } = {}

local function utilityPole(parent: Instance, base: Vector3, facing: number)
	local pole = Instance.new("Model")
	pole.Name = "Poteau"
	cylinder(
		pole,
		26,
		1,
		CFrame.new(base + Vector3.new(0, 13, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		COLORS.Pole,
		M.Concrete
	)
	local arm = part(
		pole,
		Vector3.new(7, 0.5, 0.5),
		CFrame.new(base + Vector3.new(0, 24, 0)) * CFrame.Angles(0, facing, 0),
		COLORS.Pole,
		M.Metal,
		false
	)
	decor(arm)
	decor(
		part(
			pole,
			Vector3.new(1.4, 1.8, 1.4),
			CFrame.new(base + Vector3.new(0, 20.5, 0)) * CFrame.Angles(0, facing, 0) * CFrame.new(0.9, 0, 0),
			rgb(110, 110, 112),
			M.Metal,
			false
		)
	)
	for _, x in { -3, 0, 3 } do
		local attachment = Instance.new("Attachment")
		attachment.Position = Vector3.new(x, 0.3, 0)
		attachment.Parent = arm
		table.insert(wireAnchors, attachment)
	end
	pole.Parent = parent
end

local function wires(from: number, to: number)
	for i = 0, 2 do
		local a0 = wireAnchors[from * 3 + i + 1]
		local a1 = wireAnchors[to * 3 + i + 1]
		if a0 and a1 then
			local beam = Instance.new("Beam")
			beam.Attachment0 = a0
			beam.Attachment1 = a1
			beam.Width0 = 0.12
			beam.Width1 = 0.12
			beam.Color = ColorSequence.new(COLORS.Wire)
			beam.LightInfluence = 1
			beam.Segments = 12
			beam.CurveSize0 = -3
			beam.CurveSize1 = 3
			beam.FaceCamera = true
			beam.Parent = a0
		end
	end
end

local function streetLamp(parent: Instance, base: Vector3, facing: number)
	cylinder(
		parent,
		14,
		0.5,
		CFrame.new(base + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(70, 72, 76),
		M.Metal
	)
	local head = decor(
		part(
			parent,
			Vector3.new(2.6, 0.5, 1),
			CFrame.new(base + Vector3.new(0, 14, 0)) * CFrame.Angles(0, facing, 0) * CFrame.new(1, 0, 0),
			rgb(70, 72, 76),
			M.Metal,
			false
		)
	)
	local bulb = decor(
		part(
			parent,
			Vector3.new(1.8, 0.2, 0.7),
			head.CFrame * CFrame.new(0.3, -0.3, 0),
			rgb(255, 226, 180),
			M.Neon,
			false
		)
	)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 100
	light.Range = 28
	light.Brightness = 1.6
	light.Color = rgb(255, 214, 170)
	light.Parent = bulb
end

local function vendingMachine(parent: Instance, cframe: CFrame)
	local colors = { rgb(220, 50, 50), rgb(40, 120, 200), rgb(240, 240, 236), rgb(60, 150, 90) }
	local body = part(parent, Vector3.new(3.2, 6, 2.4), cframe * CFrame.new(0, 3, 0), pick(colors), M.SmoothPlastic)
	local panel = decor(
		part(
			parent,
			Vector3.new(2.6, 3.2, 0.1),
			body.CFrame * CFrame.new(0, 0.9, -1.22),
			rgb(230, 240, 255),
			M.Neon,
			false
		)
	)
	decor(
		part(
			parent,
			Vector3.new(2.6, 0.8, 0.12),
			body.CFrame * CFrame.new(0, -2, -1.22),
			rgb(30, 30, 34),
			M.SmoothPlastic,
			false
		)
	)
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 1.2
	light.Color = rgb(220, 235, 255)
	light.Parent = panel
end

local function trafficMirror(parent: Instance, base: Vector3)
	cylinder(
		parent,
		9,
		0.35,
		CFrame.new(base + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(230, 120, 40),
		M.Metal
	)
	local mirror = decor(
		cylinder(
			parent,
			0.2,
			2.6,
			CFrame.new(base + Vector3.new(0, 9.6, 0)) * CFrame.Angles(0, math.pi / 4, 0),
			rgb(230, 120, 40),
			M.Metal
		)
	)
	local _ = mirror
end

-- Bâtiments -----------------------------------------------------------------------------------------

local function house(parent: Instance, origin: CFrame, width: number, depth: number)
	local model = Instance.new("Model")
	model.Name = "Maison"
	local floors = rng:NextInteger(2, 3)
	local height = floors * 10
	local wall = pick(HOUSE_WALLS)
	part(model, Vector3.new(width, height, depth), origin * CFrame.new(0, height / 2, 0), wall, M.Plaster)
	-- Toit à deux pans.
	local roofColor = pick(ROOFS)
	local roofHeight = depth * 0.35
	wedge(
		model,
		Vector3.new(width + 2, roofHeight, depth / 2 + 1),
		origin * CFrame.new(0, height + roofHeight / 2, -depth / 4 - 0.5),
		roofColor,
		M.Slate
	)
	wedge(
		model,
		Vector3.new(width + 2, roofHeight, depth / 2 + 1),
		origin * CFrame.new(0, height + roofHeight / 2, depth / 4 + 0.5) * CFrame.Angles(0, math.pi, 0),
		roofColor,
		M.Slate
	)
	-- Fenêtres sur la façade (côté -Z local).
	for floor = 0, floors - 1 do
		local columns = math.max(1, math.floor(width / 9))
		for column = 1, columns do
			local x = -width / 2 + column * width / (columns + 1)
			window(model, Vector3.new(3.4, 4, 0.3), origin * CFrame.new(x, 5.5 + floor * 10, -depth / 2 - 0.1), 0.35)
		end
	end
	decor(
		part(
			model,
			Vector3.new(3.4, 7, 0.4),
			origin * CFrame.new(-width / 2 + 4, 3.5, -depth / 2 - 0.15),
			COLORS.Wood,
			M.Wood,
			false
		)
	)
	-- Climatiseur et petit muret.
	decor(
		part(
			model,
			Vector3.new(2.6, 2, 1.4),
			origin * CFrame.new(width / 2 - 3, 12, -depth / 2 - 0.8),
			rgb(220, 220, 214),
			M.SmoothPlastic,
			false
		)
	)
	part(model, Vector3.new(width, 3.5, 0.8), origin * CFrame.new(0, 1.75, -depth / 2 - 4), COLORS.Concrete, M.Concrete)
	model.Parent = parent
end

local function apartment(parent: Instance, origin: CFrame, width: number, depth: number)
	local model = Instance.new("Model")
	model.Name = "Immeuble"
	local floors = rng:NextInteger(4, 8)
	local floorHeight = 9
	local height = floors * floorHeight
	local wall = pick(APARTMENT_WALLS)
	part(model, Vector3.new(width, height, depth), origin * CFrame.new(0, height / 2, 0), wall, M.Concrete)
	for floor = 0, floors - 1 do
		local y = floor * floorHeight
		-- Dalle de balcon + garde-corps sur toute la façade.
		if floor > 0 then
			decor(
				part(
					model,
					Vector3.new(width + 0.4, 0.6, 3),
					origin * CFrame.new(0, y + 0.3, -depth / 2 - 1.5),
					COLORS.SchoolTrim,
					M.Concrete,
					false
				)
			)
			decor(
				part(
					model,
					Vector3.new(width + 0.4, 3, 0.3),
					origin * CFrame.new(0, y + 2, -depth / 2 - 2.9),
					rgb(206, 210, 214),
					M.Concrete,
					false
				)
			)
		end
		local columns = math.max(2, math.floor(width / 8))
		for column = 1, columns do
			local x = -width / 2 + column * width / (columns + 1)
			window(model, Vector3.new(4.2, 5.4, 0.3), origin * CFrame.new(x, y + 4.8, -depth / 2 - 0.1), 0.3)
		end
	end
	-- Toit : château d'eau et antenne.
	decor(
		cylinder(
			model,
			5,
			5,
			origin * CFrame.new(width / 4, height + 2.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
			rgb(180, 184, 190),
			M.Metal
		)
	)
	decor(
		part(
			model,
			Vector3.new(width, 1.6, depth),
			origin * CFrame.new(0, height + 0.8, 0),
			COLORS.ConcreteDark,
			M.Concrete,
			false
		)
	)
	model.Parent = parent
end

local SHOP_NAMES = {
	"KONBINI 24H",
	"RAMEN SEIRYŌ",
	"LIBRAIRIE",
	"CAFÉ SAKURA",
	"SPORT SHOP",
	"PHARMACIE",
	"BOULANGERIE",
	"KARAOKÉ",
}

local function shop(parent: Instance, origin: CFrame, width: number, depth: number)
	local model = Instance.new("Model")
	model.Name = "Commerce"
	local floors = rng:NextInteger(2, 3)
	local height = floors * 10
	part(model, Vector3.new(width, height, depth), origin * CFrame.new(0, height / 2, 0), pick(HOUSE_WALLS), M.Plaster)
	-- Vitrine éclairée.
	local glass = decor(
		part(
			model,
			Vector3.new(width - 4, 6.5, 0.3),
			origin * CFrame.new(0, 4, -depth / 2 - 0.1),
			rgb(255, 232, 200),
			M.Neon,
			false
		)
	)
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 1.2
	light.Color = rgb(255, 220, 180)
	light.Parent = glass
	-- Auvent et enseigne.
	local awning = pick(AWNINGS)
	wedge(
		model,
		Vector3.new(width, 1.6, 4),
		origin * CFrame.new(0, 8.4, -depth / 2 - 2) * CFrame.Angles(0, math.pi, 0),
		awning,
		M.Fabric
	)
	local board = decor(
		part(
			model,
			Vector3.new(width - 2, 2.6, 0.4),
			origin * CFrame.new(0, 10.6, -depth / 2 - 0.3),
			rgb(30, 30, 36),
			M.SmoothPlastic,
			false
		)
	)
	sign(board, Enum.NormalId.Front, pick(SHOP_NAMES), rgb(255, 244, 230), rgb(30, 30, 36), 24)
	for floor = 1, floors - 1 do
		local columns = math.max(1, math.floor(width / 9))
		for column = 1, columns do
			local x = -width / 2 + column * width / (columns + 1)
			window(model, Vector3.new(3.6, 4.4, 0.3), origin * CFrame.new(x, 5.5 + floor * 10, -depth / 2 - 0.1), 0.5)
		end
	end
	model.Parent = parent
end

-- Tour lointaine (silhouette d'horizon, sans collision ni ombre).
local function tower(parent: Instance, position: Vector3, width: number, height: number)
	local color = pick({ rgb(150, 140, 150), rgb(130, 126, 140), rgb(170, 160, 160), rgb(120, 118, 130) })
	local body = decor(
		part(
			parent,
			Vector3.new(width, height, width),
			CFrame.new(position + Vector3.new(0, height / 2, 0)),
			color,
			M.Concrete,
			false
		)
	)
	body.CastShadow = false
	-- Bandes de fenêtres allumées.
	for y = 8, height - 6, 10 do
		if rng:NextNumber() < 0.45 then
			local strip = decor(
				part(
					parent,
					Vector3.new(width + 0.2, 1.6, width + 0.2),
					CFrame.new(position + Vector3.new(0, y, 0)),
					rgb(255, 210, 160),
					M.Neon,
					false
				)
			)
			strip.CastShadow = false
		end
	end
end

-- Campus ------------------------------------------------------------------------------------------------

local function schoolBuilding(parent: Instance, origin: CFrame)
	local model = Instance.new("Model")
	model.Name = "BatimentPrincipal"
	local length, depth, floorHeight, floors = 200, 30, 13, 4
	local height = floors * floorHeight
	part(model, Vector3.new(length, height, depth), origin * CFrame.new(0, height / 2, 0), COLORS.SchoolWall, M.Plaster)
	for floor = 0, floors - 1 do
		local y = floor * floorHeight
		-- Bandeau horizontal entre les étages.
		decor(
			part(
				model,
				Vector3.new(length + 0.6, 1.2, 0.8),
				origin * CFrame.new(0, y + floorHeight - 0.6, depth / 2 + 0.3),
				COLORS.SchoolTrim,
				M.Concrete,
				false
			)
		)
		-- Rangée de grandes fenêtres.
		local columns = 24
		for column = 1, columns do
			local x = -length / 2 + (column - 0.5) * length / columns
			if not (floor == 0 and math.abs(x) < 14) then
				window(
					model,
					Vector3.new(length / columns - 1.6, 7, 0.3),
					origin * CFrame.new(x, y + 6, depth / 2 + 0.12),
					if floor == 0 then 0.2 else 0.4
				)
			end
		end
	end
	-- Entrée : auvent et portes vitrées.
	part(model, Vector3.new(30, 1, 10), origin * CFrame.new(0, 10, depth / 2 + 5), COLORS.SchoolTrim, M.Concrete)
	for _, x in { -13, 13 } do
		cylinder(
			model,
			10,
			0.9,
			origin * CFrame.new(x, 5, depth / 2 + 9) * CFrame.Angles(0, 0, math.pi / 2),
			COLORS.SchoolTrim,
			M.Concrete
		)
	end
	decor(
		part(
			model,
			Vector3.new(22, 8, 0.3),
			origin * CFrame.new(0, 4, depth / 2 + 0.12),
			rgb(255, 226, 180),
			M.Neon,
			false
		)
	)
	-- Tour de l'horloge.
	part(model, Vector3.new(22, 20, 20), origin * CFrame.new(0, height + 10, 0), COLORS.SchoolWall, M.Plaster)
	local clock = decor(
		cylinder(
			model,
			0.4,
			12,
			origin * CFrame.new(0, height + 11, 10.2) * CFrame.Angles(0, math.pi / 2, 0),
			rgb(250, 248, 240),
			M.SmoothPlastic
		)
	)
	decor(
		part(
			model,
			Vector3.new(0.5, 5, 0.3),
			clock.CFrame * CFrame.new(-0.3, 1.8, 0) * CFrame.Angles(0, 0, 0),
			rgb(30, 30, 34),
			M.Metal,
			false
		)
	)
	decor(
		part(
			model,
			Vector3.new(0.5, 3.6, 0.3),
			clock.CFrame * CFrame.new(-0.3, 0, 1.3) * CFrame.Angles(math.rad(-70), 0, 0),
			rgb(30, 30, 34),
			M.Metal,
			false
		)
	)
	-- Garde-corps du toit.
	for x = -length / 2, length / 2, 4 do
		decor(
			part(
				model,
				Vector3.new(0.3, 4, 0.3),
				origin * CFrame.new(x, height + 2, depth / 2 - 0.5),
				rgb(160, 170, 170),
				M.Metal,
				false
			)
		)
	end
	decor(
		part(
			model,
			Vector3.new(length, 0.3, 0.3),
			origin * CFrame.new(0, height + 4, depth / 2 - 0.5),
			rgb(160, 170, 170),
			M.Metal,
			false
		)
	)
	-- Nom du lycée.
	local board = decor(
		part(
			model,
			Vector3.new(60, 6, 0.5),
			origin * CFrame.new(0, height - 4, depth / 2 + 0.4),
			COLORS.SchoolWall,
			M.SmoothPlastic,
			false
		)
	)
	sign(board, Enum.NormalId.Back, "LYCÉE SEIRYŌ", rgb(40, 50, 70), COLORS.SchoolWall, 16)
	model.Parent = parent
end

local function gym(parent: Instance, origin: CFrame)
	local model = Instance.new("Model")
	model.Name = "Gymnase"
	local width, depth, height = 70, 90, 26
	part(
		model,
		Vector3.new(width, height, depth),
		origin * CFrame.new(0, height / 2, 0),
		rgb(214, 210, 200),
		M.Concrete
	)
	-- Toit à deux pans métallique.
	wedge(
		model,
		Vector3.new(width / 2 + 1, 8, depth + 2),
		origin * CFrame.new(-width / 4, height + 4, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		rgb(74, 96, 120),
		M.Metal
	)
	wedge(
		model,
		Vector3.new(width / 2 + 1, 8, depth + 2),
		origin * CFrame.new(width / 4, height + 4, 0) * CFrame.Angles(0, math.pi / 2, 0),
		rgb(74, 96, 120),
		M.Metal
	)
	for z = -depth / 2 + 8, depth / 2 - 8, 12 do
		window(model, Vector3.new(0.3, 6, 8), origin * CFrame.new(width / 2 + 0.12, height - 6, z), 0.6)
	end
	local doors = decor(
		part(
			model,
			Vector3.new(0.4, 10, 18),
			origin * CFrame.new(width / 2 + 0.15, 5, 0),
			rgb(255, 222, 176),
			M.Neon,
			false
		)
	)
	local light = Instance.new("PointLight")
	light.Range = 20
	light.Brightness = 1.4
	light.Color = rgb(255, 214, 170)
	light.Parent = doors
	local board = decor(
		part(
			model,
			Vector3.new(0.5, 5, 36),
			origin * CFrame.new(width / 2 + 0.3, 15, 0),
			rgb(36, 40, 52),
			M.SmoothPlastic,
			false
		)
	)
	sign(board, Enum.NormalId.Right, "GYMNASE · HANDBALL", rgb(255, 255, 255), rgb(36, 40, 52), 18)
	model.Parent = parent
end

local function outdoorCourt(parent: Instance, center: Vector3)
	local model = Instance.new("Model")
	model.Name = "TerrainExterieur"
	local length, width = 64, 34
	part(
		model,
		Vector3.new(length + 8, 0.3, width + 8),
		CFrame.new(center + Vector3.new(0, 0.15, 0)),
		rgb(70, 112, 150),
		M.Concrete
	)
	part(
		model,
		Vector3.new(length, 0.32, width),
		CFrame.new(center + Vector3.new(0, 0.16, 0)),
		rgb(196, 94, 72),
		M.Concrete
	)
	local lineY = 0.34
	for _, z in { -width / 2, width / 2 } do
		decor(
			part(
				model,
				Vector3.new(length, 0.04, 0.35),
				CFrame.new(center + Vector3.new(0, lineY, z)),
				COLORS.Line,
				M.SmoothPlastic,
				false
			)
		)
	end
	for _, x in { -length / 2, 0, length / 2 } do
		decor(
			part(
				model,
				Vector3.new(0.35, 0.04, width),
				CFrame.new(center + Vector3.new(x, lineY, 0)),
				COLORS.Line,
				M.SmoothPlastic,
				false
			)
		)
	end
	for _, side in { -1, 1 } do
		local x = center.X + side * length / 2
		for _, z in { -4.5, 4.5 } do
			cylinder(
				model,
				6.4,
				0.4,
				CFrame.new(x, 3.2, center.Z + z) * CFrame.Angles(0, 0, math.pi / 2),
				rgb(236, 236, 230),
				M.Metal
			)
		end
		cylinder(
			model,
			9.4,
			0.4,
			CFrame.new(x, 6.4, center.Z) * CFrame.Angles(0, math.pi / 2, 0),
			rgb(236, 236, 230),
			M.Metal
		)
		local net = decor(
			part(
				model,
				Vector3.new(0.1, 6.4, 9),
				CFrame.new(x + side * 2.5, 3.2, center.Z),
				rgb(240, 240, 236),
				M.Fabric,
				false
			)
		)
		net.Transparency = 0.4
	end
	-- Grillage autour.
	for _, z in { -width / 2 - 6, width / 2 + 6 } do
		local fence = decor(
			part(
				model,
				Vector3.new(length + 12, 10, 0.2),
				CFrame.new(center + Vector3.new(0, 5, z)),
				rgb(90, 110, 100),
				M.DiamondPlate,
				false
			)
		)
		fence.Transparency = 0.55
	end
	model.Parent = parent
end

local function campusWall(parent: Instance, minX: number, maxX: number, minZ: number, maxZ: number, gateHalf: number)
	local function segment(a: Vector3, b: Vector3)
		local length = (b - a).Magnitude
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, b)
		part(parent, Vector3.new(1.4, 6, length), cf + Vector3.new(0, 3, 0), COLORS.Concrete, M.Concrete)
		decor(part(parent, Vector3.new(2, 0.6, length), cf + Vector3.new(0, 6.3, 0), rgb(110, 100, 96), M.Slate, false))
	end
	segment(Vector3.new(minX, 0, minZ), Vector3.new(maxX, 0, minZ))
	segment(Vector3.new(minX, 0, minZ), Vector3.new(minX, 0, maxZ))
	segment(Vector3.new(maxX, 0, minZ), Vector3.new(maxX, 0, maxZ))
	segment(Vector3.new(minX, 0, maxZ), Vector3.new(-gateHalf, 0, maxZ))
	segment(Vector3.new(gateHalf, 0, maxZ), Vector3.new(maxX, 0, maxZ))
	-- Piliers du portail et plaque.
	for _, x in { -gateHalf, gateHalf } do
		part(parent, Vector3.new(3.4, 9, 3.4), CFrame.new(x, 4.5, maxZ), COLORS.ConcreteDark, M.Concrete)
	end
	local plate = decor(
		part(
			parent,
			Vector3.new(0.3, 2.4, 8),
			CFrame.new(gateHalf + 1.9, 6, maxZ) * CFrame.Angles(0, math.pi / 2, 0),
			rgb(46, 52, 64),
			M.Metal,
			false
		)
	)
	sign(plate, Enum.NormalId.Right, "LYCÉE SEIRYŌ", rgb(240, 236, 224), rgb(46, 52, 64), 30)
end

-- Rues -------------------------------------------------------------------------------------------------

local function road(parent: Instance, from: Vector3, to: Vector3, width: number)
	local length = (to - from).Magnitude
	local cf = CFrame.lookAt((from + to) / 2, to)
	part(parent, Vector3.new(width, 0.4, length), cf + Vector3.new(0, 0.2, 0), COLORS.Asphalt, M.Asphalt)
	-- Trottoirs.
	for _, side in { -1, 1 } do
		part(
			parent,
			Vector3.new(5, 0.8, length),
			cf * CFrame.new(side * (width / 2 + 2.5), 0.4, 0),
			COLORS.Sidewalk,
			M.Pavement
		)
		decor(
			part(
				parent,
				Vector3.new(0.5, 0.9, length),
				cf * CFrame.new(side * (width / 2 + 0.25), 0.45, 0),
				rgb(196, 192, 186),
				M.Concrete,
				false
			)
		)
	end
	-- Ligne centrale en pointillés.
	for d = -length / 2 + 4, length / 2 - 4, 10 do
		decor(
			part(parent, Vector3.new(0.35, 0.05, 5), cf * CFrame.new(0, 0.42, d), COLORS.Line, M.SmoothPlastic, false)
		)
	end
end

local function crosswalk(parent: Instance, center: Vector3, along: Vector3, width: number)
	local right = along:Cross(Vector3.yAxis).Unit
	for i = -4, 4 do
		decor(
			part(
				parent,
				Vector3.new(1.4, 0.05, 6),
				CFrame.lookAt(
					center + right * (i * 2.4) + Vector3.new(0, 0.43, 0),
					center + right * (i * 2.4) + along + Vector3.new(0, 0.43, 0)
				),
				COLORS.Line,
				M.SmoothPlastic,
				false
			)
		)
	end
	local _ = width
end

-- Construction ------------------------------------------------------------------------------------------

local function build(): Model
	local world = Instance.new("Model")
	world.Name = "QuartierSeiryo"

	-- Sol.
	part(world, Vector3.new(1600, 4, 1600), CFrame.new(0, -2, 0), rgb(88, 92, 86), M.Ground)

	-- Campus.
	local campus = Instance.new("Model")
	campus.Name = "Campus"
	campus.Parent = world
	local minX, maxX, minZ, maxZ = -150, 150, -180, 130
	part(
		campus,
		Vector3.new(maxX - minX, 0.3, maxZ - minZ),
		CFrame.new((minX + maxX) / 2, 0.15, (minZ + maxZ) / 2),
		COLORS.Grass,
		M.Grass
	)
	part(campus, Vector3.new(110, 0.35, 150), CFrame.new(0, 0.18, 40), rgb(206, 196, 180), M.Pavement)
	part(campus, Vector3.new(30, 0.36, 40), CFrame.new(0, 0.19, 120), rgb(206, 196, 180), M.Pavement)
	schoolBuilding(campus, CFrame.new(0, 0, -155) * CFrame.Angles(0, 0, 0))
	gym(campus, CFrame.new(-105, 0, -40))
	outdoorCourt(campus, Vector3.new(95, 0, -10))
	campusWall(campus, minX, maxX, minZ, maxZ, 14)
	for z = -20, 110, 26 do
		sakura(campus, Vector3.new(-48, 0, z), rng:NextNumber(1, 1.2))
		sakura(campus, Vector3.new(48, 0, z + 12), rng:NextNumber(1, 1.2))
	end
	for _ = 1, 26 do
		local x = rng:NextNumber(minX + 6, maxX - 6)
		local z = rng:NextNumber(60, maxZ - 6)
		if math.abs(x) > 60 then
			shrub(campus, Vector3.new(x, 0, z))
		end
	end
	-- Bancs et distributeurs dans la cour.
	for _, x in { -30, 30 } do
		part(campus, Vector3.new(8, 0.6, 2.4), CFrame.new(x, 1.8, 70), COLORS.Wood, M.Wood)
		for _, dx in { -3, 3 } do
			part(campus, Vector3.new(0.6, 1.8, 2), CFrame.new(x + dx, 0.9, 70), rgb(70, 72, 76), M.Metal)
		end
	end
	vendingMachine(campus, CFrame.new(-56, 0.3, -118) * CFrame.Angles(0, 0, 0))
	vendingMachine(campus, CFrame.new(-52, 0.3, -118))
	for _, x in { -40, 40 } do
		streetLamp(campus, Vector3.new(x, 0.3, 20), if x < 0 then 0 else math.pi)
		streetLamp(campus, Vector3.new(x, 0.3, 100), if x < 0 then 0 else math.pi)
	end

	-- Point d'apparition : face au lycée.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Apparition"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 0.4, 12)
	spawn.CFrame = CFrame.new(0, 0.4, 70) * CFrame.Angles(0, math.pi, 0)
	spawn.Color = rgb(206, 196, 180)
	spawn.Material = M.Pavement
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = world
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- Rues autour du campus.
	local streets = Instance.new("Model")
	streets.Name = "Rues"
	streets.Parent = world
	local roadWidth = 22
	local southZ, northZ, eastX, westX = maxZ + 20, minZ - 20, maxX + 20, minX - 20
	road(streets, Vector3.new(westX - 200, 0, southZ), Vector3.new(eastX + 200, 0, southZ), roadWidth)
	road(streets, Vector3.new(westX - 200, 0, northZ), Vector3.new(eastX + 200, 0, northZ), roadWidth)
	road(streets, Vector3.new(eastX, 0, northZ - 200), Vector3.new(eastX, 0, southZ + 200), roadWidth)
	road(streets, Vector3.new(westX, 0, northZ - 200), Vector3.new(westX, 0, southZ + 200), roadWidth)
	crosswalk(streets, Vector3.new(0, 0, southZ), Vector3.new(0, 0, 1), roadWidth)
	crosswalk(streets, Vector3.new(eastX, 0, 0), Vector3.new(1, 0, 0), roadWidth)
	crosswalk(streets, Vector3.new(westX, 0, 0), Vector3.new(1, 0, 0), roadWidth)

	-- Poteaux électriques et fils le long de la rue sud.
	local poleIndex = 0
	local previous: number? = nil
	for x = westX - 160, eastX + 160, 40 do
		utilityPole(streets, Vector3.new(x, 0.8, southZ + roadWidth / 2 + 3), 0)
		if previous then
			wires(previous, poleIndex)
		end
		previous = poleIndex
		poleIndex += 1
	end
	previous = nil
	for z = northZ - 120, southZ - 20, 40 do
		utilityPole(streets, Vector3.new(eastX + roadWidth / 2 + 3, 0.8, z), math.pi / 2)
		if previous then
			wires(previous, poleIndex)
		end
		previous = poleIndex
		poleIndex += 1
	end
	previous = nil
	for z = northZ - 120, southZ - 20, 40 do
		utilityPole(streets, Vector3.new(westX - roadWidth / 2 - 3, 0.8, z), math.pi / 2)
		if previous then
			wires(previous, poleIndex)
		end
		previous = poleIndex
		poleIndex += 1
	end
	for x = westX - 140, eastX + 140, 60 do
		streetLamp(streets, Vector3.new(x + 20, 0.8, southZ - roadWidth / 2 - 3), math.pi / 2)
	end
	trafficMirror(streets, Vector3.new(eastX - roadWidth / 2 - 3, 0.8, southZ - roadWidth / 2 - 3))
	trafficMirror(streets, Vector3.new(westX + roadWidth / 2 + 3, 0.8, southZ - roadWidth / 2 - 3))

	-- Quartier : rangées de bâtiments face aux rues (façade côté campus).
	local town = Instance.new("Model")
	town.Name = "Quartier"
	town.Parent = world
	local function row(startPos: Vector3, direction: Vector3, length: number, facingYaw: number, kinds: { string })
		local cursor = 0
		while cursor < length do
			local kind = pick(kinds)
			local width = if kind == "apartment"
				then rng:NextInteger(30, 44)
				elseif kind == "shop" then rng:NextInteger(18, 26)
				else rng:NextInteger(18, 24)
			local depth = if kind == "apartment" then rng:NextInteger(22, 30) else rng:NextInteger(16, 22)
			local position = startPos + direction * (cursor + width / 2)
			local origin = CFrame.new(position) * CFrame.Angles(0, facingYaw, 0) * CFrame.new(0, 0, depth / 2)
			if kind == "apartment" then
				apartment(town, origin, width, depth)
			elseif kind == "shop" then
				shop(town, origin, width, depth)
			else
				house(town, origin, width, depth)
			end
			if rng:NextNumber() < 0.25 then
				vendingMachine(
					town,
					CFrame.new(position + direction * (width / 2 + 1.6))
						* CFrame.Angles(0, facingYaw + math.pi, 0)
						* CFrame.new(0, 0.3, -2)
				)
			end
			cursor += width + rng:NextNumber(1, 3)
		end
	end
	local sideOffset = roadWidth / 2 + 6
	-- Sud (en face du portail) : commerces et maisons, façade vers le nord.
	row(
		Vector3.new(westX - 190, 0, southZ + sideOffset),
		Vector3.new(1, 0, 0),
		(eastX - westX) + 380,
		math.pi,
		{ "shop", "shop", "house", "apartment" }
	)
	-- Nord, derrière le lycée.
	row(
		Vector3.new(westX - 190, 0, northZ - sideOffset),
		Vector3.new(1, 0, 0),
		(eastX - westX) + 380,
		0,
		{ "apartment", "house", "apartment" }
	)
	-- Est et ouest.
	row(
		Vector3.new(eastX + sideOffset, 0, northZ + 30),
		Vector3.new(0, 0, 1),
		(southZ - northZ) - 60,
		-math.pi / 2,
		{ "house", "apartment", "shop" }
	)
	row(
		Vector3.new(westX - sideOffset, 0, northZ + 30),
		Vector3.new(0, 0, 1),
		(southZ - northZ) - 60,
		math.pi / 2,
		{ "house", "apartment", "shop" }
	)
	-- Deuxième ligne de bâtiments, plus hauts, pour fermer la vue.
	type Line = { Start: Vector3, Direction: Vector3, Yaw: number, Length: number }
	local backLines: { Line } = {
		{
			Start = Vector3.new(westX - 220, 0, southZ + 70),
			Direction = Vector3.new(1, 0, 0),
			Yaw = math.pi,
			Length = (eastX - westX) + 440,
		},
		{
			Start = Vector3.new(westX - 220, 0, northZ - 70),
			Direction = Vector3.new(1, 0, 0),
			Yaw = 0,
			Length = (eastX - westX) + 440,
		},
		{
			Start = Vector3.new(eastX + 70, 0, northZ - 60),
			Direction = Vector3.new(0, 0, 1),
			Yaw = -math.pi / 2,
			Length = (southZ - northZ) + 120,
		},
		{
			Start = Vector3.new(westX - 70, 0, northZ - 60),
			Direction = Vector3.new(0, 0, 1),
			Yaw = math.pi / 2,
			Length = (southZ - northZ) + 120,
		},
	}
	for _, line in backLines do
		local cursor = 0
		while cursor < line.Length do
			local width = rng:NextInteger(34, 48)
			local position = line.Start + line.Direction * (cursor + width / 2)
			apartment(town, CFrame.new(position) * CFrame.Angles(0, line.Yaw, 0) * CFrame.new(0, 0, 14), width, 28)
			cursor += width + 2
		end
	end

	-- Horizon : tours lointaines tout autour.
	local skyline = Instance.new("Model")
	skyline.Name = "Horizon"
	skyline.Parent = world
	for i = 0, 71 do
		local angle = i / 72 * math.pi * 2
		local radius = rng:NextNumber(520, 640)
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		tower(skyline, position, rng:NextNumber(30, 60), rng:NextNumber(70, 190))
	end

	-- Murs invisibles : la zone jouable s'arrête aux trottoirs extérieurs.
	local limitX, limitZ = eastX + roadWidth / 2 + 5, southZ + roadWidth / 2 + 5
	local limitNorth = northZ - roadWidth / 2 - 5
	for _, spec in
		{
			{ Vector3.new(limitX * 2, 80, 2), Vector3.new(0, 40, limitZ) },
			{ Vector3.new(limitX * 2, 80, 2), Vector3.new(0, 40, limitNorth) },
			{ Vector3.new(2, 80, limitZ - limitNorth), Vector3.new(limitX, 40, (limitZ + limitNorth) / 2) },
			{ Vector3.new(2, 80, limitZ - limitNorth), Vector3.new(-limitX, 40, (limitZ + limitNorth) / 2) },
		}
	do
		local barrier = part(world, spec[1], CFrame.new(spec[2]), rgb(0, 0, 0), M.SmoothPlastic)
		barrier.Name = "Limite"
		barrier.Transparency = 1
		barrier.CastShadow = false
		barrier.CanQuery = false
	end

	world.Parent = Workspace
	return world
end

-- Étiquette au-dessus des joueurs (nom, niveau, clan) -------------------------------------------------

local function nametag(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head or not head:IsA("BasePart") then
		return
	end
	local old = head:FindFirstChild("Etiquette")
	if old then
		old:Destroy()
	end
	local profile = PlayerData.get(player)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Etiquette"
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 80
	gui.Parent = head
	local tag = Clan.tagOf(player)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 20)
	label.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	label.TextSize = 16
	label.TextColor3 = rgb(255, 255, 255)
	label.TextStrokeTransparency = 0.6
	label.Text = (if tag then `[{tag}] ` else "") .. player.DisplayName
	label.Parent = gui
	local level = Instance.new("TextLabel")
	level.BackgroundTransparency = 1
	level.Position = UDim2.fromOffset(0, 20)
	level.Size = UDim2.new(1, 0, 0, 16)
	level.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	level.TextSize = 13
	level.TextColor3 = rgb(255, 170, 110)
	level.TextStrokeTransparency = 0.7
	level.Text = `NIVEAU {if profile then profile.Level else 1}`
	level.Parent = gui
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function dress(player: Player, character: Model)
	local profile = PlayerData.waitFor(player, 20)
	if not profile or character.Parent == nil or character:GetAttribute("MatchId") then
		return
	end
	Outfit.applyCosmeticsOnly(character, profile.Equipped)
	nametag(player, character)
end

function Lobby.init()
	if ServerRole.Role ~= "Lobby" then
		return
	end
	build()
	-- Travelling de l'écran titre : de la rue vers le lycée.
	Workspace:SetAttribute("MenuCamera", CFrame.lookAt(Vector3.new(70, 14, 128), Vector3.new(0, 30, -150)))
	Workspace:SetAttribute("MenuCameraEnd", CFrame.lookAt(Vector3.new(-50, 18, 100), Vector3.new(10, 34, -150)))
end

function Lobby.start()
	if ServerRole.Role ~= "Lobby" then
		return
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.3)
			dress(player, character)
		end)
		if player.Character then
			task.spawn(dress, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	local signatures: { [Player]: string } = {}
	PlayerData.Changed:Connect(function(player, profile)
		local signature =
			`{profile.Equipped.Mask}|{profile.Equipped.Gloves}|{profile.Equipped.Shoes}|{profile.Level}|{profile.ClanId}`
		if signatures[player] == signature then
			return
		end
		signatures[player] = signature
		local character = player.Character
		if character and not character:GetAttribute("MatchId") then
			task.spawn(dress, player, character)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		signatures[player] = nil
	end)
end

return Lobby
