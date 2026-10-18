--!strict
-- Le lobby : la cour du lycée Seiryō, à la façon d'un décor d'animé de sport
-- (Haikyuu) au coucher du soleil. Une zone compacte et soignée :
--
--   • au nord, la façade du lycée (3 étages, tour de l'horloge) ;
--   • au nord-est, le gymnase ; à l'est, l'aile des classes ;
--   • à l'ouest, cerisiers, abri à vélos et colline boisée ;
--   • au sud, le portail du lycée, la rue et ses maisons, puis les collines.
--
-- Les bâtiments, la colline et les arbres ferment tout l'horizon ; des murs
-- invisibles gardent les joueurs dans la cour. Les terrains de jeu (Pads.luau)
-- occupent le centre de la cour, qui reste dégagé.
--
-- Ressources facultatives (ServerStorage > Assets, voir Shared/Assets.luau) :
--   LobbySchool remplace la façade dessinée en code ; Cerisier remplace les
--   cerisiers dessinés en code.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Clan = require(script.Parent.Clan)
local Outfit = require(script.Parent.Parent.Match.Outfit)
local PlayerData = require(script.Parent.PlayerData)
local ServerRole = require(script.Parent.Parent.Lib.ServerRole)

local Lobby = {}

local rng = Random.new(20261018)
local rgb = Color3.fromRGB
local M = Enum.Material

-- Limites de la cour (zone jouable).
local BOUNDS = { MinX = -148, MaxX = 146, MinZ = -126, MaxZ = 126 }
local SPAWN = Vector3.new(0, 0, 96)

local C = {
	Ground = rgb(196, 168, 128), -- terre battue du terrain de sport
	Paving = rgb(186, 180, 170),
	PavingDark = rgb(150, 144, 136),
	Curb = rgb(214, 210, 200),
	Plaster = rgb(240, 234, 222),
	PlasterShade = rgb(214, 206, 192),
	Trim = rgb(122, 128, 136),
	Frame = rgb(70, 78, 88),
	Glass = rgb(120, 150, 170),
	GlassLit = rgb(214, 160, 96),
	Roof = rgb(70, 74, 82),
	RoofTile = rgb(64, 70, 84),
	GymWall = rgb(214, 220, 214),
	GymRoof = rgb(86, 120, 142),
	Wood = rgb(140, 96, 64),
	WoodDark = rgb(96, 64, 44),
	Metal = rgb(52, 56, 62),
	FenceGreen = rgb(64, 104, 86),
	Grass = rgb(106, 140, 70),
	GrassDark = rgb(72, 104, 54),
	Forest = rgb(54, 82, 46),
	ForestDark = rgb(40, 62, 40),
	Hedge = rgb(70, 112, 60),
	Asphalt = rgb(70, 72, 78),
	Line = rgb(236, 234, 226),
	Blossom = { rgb(255, 196, 210), rgb(250, 178, 198), rgb(255, 214, 224), rgb(244, 164, 188) },
	Bark = rgb(84, 58, 48),
	Lamp = rgb(255, 214, 160),
	Mountain = rgb(92, 104, 128),
}

local GOTHAM = Font.fromEnum(Enum.Font.GothamBlack)
local GOTHAM_BOLD = Font.fromEnum(Enum.Font.GothamBold)

-- Primitives -------------------------------------------------------------------------------------

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

-- Pièce de décor : ni collision, ni requêtes, ni contact (moins coûteux).
local function decor<T>(p: T): T
	local base = p :: any
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	return p
end

local function deco(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	return decor(part(parent, size, cframe, color, material, false))
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

-- Toit à deux pans : `cf` est le milieu du faîtage au niveau de l'égout,
-- le faîtage suit l'axe X local.
local function gable(
	parent: Instance,
	cf: CFrame,
	length: number,
	rise: number,
	depth: number,
	color: Color3,
	material: Enum.Material
)
	wedge(parent, Vector3.new(length, rise, depth / 2), cf * CFrame.new(0, rise / 2, -depth / 4), color, material)
	wedge(
		parent,
		Vector3.new(length, rise, depth / 2),
		cf * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, rise / 2, -depth / 4),
		color,
		material
	)
end

local function ball(
	parent: Instance,
	diameter: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local b = deco(parent, Vector3.one * diameter, CFrame.new(position), color, material)
	b.Shape = Enum.PartType.Ball
	return b
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

-- Cylindre vertical (l'axe d'un cylindre Roblox est X).
local function column(
	parent: Instance,
	height: number,
	diameter: number,
	base: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	return cylinder(
		parent,
		height,
		diameter,
		CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
end

-- Poutre entre deux points.
local function beam(
	parent: Instance,
	from: Vector3,
	to: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material?
): Part
	local length = (to - from).Magnitude
	return deco(parent, Vector3.new(thickness, thickness, length), CFrame.lookAt((from + to) / 2, to), color, material)
end

local function signText(target: BasePart, face: Enum.NormalId, text: string, color: Color3, ppu: number?, font: Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu or 30
	gui.LightInfluence = 0.4
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.FontFace = font or GOTHAM
	label.TextColor3 = color
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

local function vary(color: Color3, amount: number): Color3
	local k = 1 + rng:NextNumber(-amount, amount)
	return Color3.new(math.clamp(color.R * k, 0, 1), math.clamp(color.G * k, 0, 1), math.clamp(color.B * k, 0, 1))
end

local function assetModel(name: string): Model?
	local folder = ServerStorage:FindFirstChild("Assets")
	local found = folder and folder:FindFirstChild(name)
	return if found and found:IsA("Model") then found else nil
end

-- Fenêtre : cadre sombre + vitre (quelques vitres éclairées au soir).
-- `cf` est centré sur la façade, la vitre regarde vers -Z local.
local function window(parent: Instance, width: number, height: number, cf: CFrame, litChance: number)
	deco(parent, Vector3.new(width + 0.6, height + 0.6, 0.3), cf, C.Frame, M.Metal)
	local lit = rng:NextNumber() < litChance
	local pane = deco(
		parent,
		Vector3.new(width, height, 0.2),
		cf * CFrame.new(0, 0, -0.12),
		if lit then C.GlassLit else vary(C.Glass, 0.06),
		if lit then M.Neon else M.Glass
	)
	if lit then
		pane.Transparency = 0.25
	else
		pane.Reflectance = 0.25
	end
	-- Meneau central.
	deco(parent, Vector3.new(0.2, height, 0.35), cf * CFrame.new(0, 0, -0.15), C.Frame, M.Metal)
end

-- Végétation -------------------------------------------------------------------------------------

local function petals(parent: BasePart, rate: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(rgb(255, 205, 220), rgb(255, 176, 200))
	emitter.LightEmission = 0.1
	emitter.Size = NumberSequence.new(0.35, 0.25)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.1),
		NumberSequenceKeypoint.new(0.85, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(6, 9)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(1.2, -1.3, 0.4)
	emitter.Drag = 0.6
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Parent = parent
end

-- Cerisier : tronc incliné, trois branches, houppier de boules irrégulières.
local function sakura(parent: Instance, base: Vector3, scale: number)
	local template = assetModel(Assets.Models.LobbyTrees)
	if template then
		local clone = template:Clone()
		clone:PivotTo(CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		clone:ScaleTo(scale)
		clone.Parent = parent
		return
	end
	local model = Instance.new("Model")
	model.Name = "Cerisier"
	model.Parent = parent
	local lean = CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.12, 0.12))
	local trunkHeight = 9 * scale
	local trunkTop = (CFrame.new(base) * lean * CFrame.new(0, trunkHeight, 0)).Position
	beam(model, base, trunkTop, 1.5 * scale, C.Bark, M.Wood).CanCollide = true
	local canopyCenter = trunkTop + Vector3.new(0, 3 * scale, 0)
	for i = 1, 3 do
		local angle = (i / 3) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local tip = trunkTop
			+ Vector3.new(math.cos(angle) * 5 * scale, rng:NextNumber(2.5, 4.5) * scale, math.sin(angle) * 5 * scale)
		beam(model, trunkTop, tip, 0.8 * scale, C.Bark, M.Wood)
		ball(model, rng:NextNumber(7, 9.5) * scale, tip + Vector3.new(0, 1.2 * scale, 0), pick(C.Blossom), M.Grass)
	end
	for _ = 1, 4 do
		local offset = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(0, 4), rng:NextNumber(-4, 4)) * scale
		ball(model, rng:NextNumber(6, 10) * scale, canopyCenter + offset, pick(C.Blossom), M.Grass)
	end
	-- Pétales au sol (tache rose) et pétales qui tombent.
	local carpet = deco(
		model,
		Vector3.new(0.05, 14 * scale, 14 * scale),
		CFrame.new(base + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		rgb(240, 186, 196),
		M.Grass
	)
	carpet.Shape = Enum.PartType.Cylinder
	carpet.Transparency = 0.35
	local emitterPart = deco(model, Vector3.new(10, 1, 10) * scale, CFrame.new(canopyCenter), C.Bark)
	emitterPart.Transparency = 1
	petals(emitterPart, 1.6)
end

-- Arbre de forêt (colline) : grosses masses sombres, peu de pièces.
local function forestTree(parent: Instance, base: Vector3, scale: number)
	local height = rng:NextNumber(10, 16) * scale
	column(parent, height, 1.6 * scale, base, C.Bark, M.Wood).CanCollide = false
	local top = base + Vector3.new(0, height, 0)
	ball(parent, rng:NextNumber(12, 16) * scale, top, vary(C.Forest, 0.12), M.Grass)
	ball(
		parent,
		rng:NextNumber(9, 12) * scale,
		top + Vector3.new(rng:NextNumber(-4, 4), -3, rng:NextNumber(-4, 4)) * scale,
		vary(C.ForestDark, 0.1),
		M.Grass
	)
end

local function hedge(parent: Instance, from: Vector3, to: Vector3, height: number)
	local length = (to - from).Magnitude
	local cf = CFrame.lookAt((from + to) / 2, to) * CFrame.new(0, height / 2, 0)
	deco(parent, Vector3.new(3, height, length), cf, C.Hedge, M.LeafyGrass)
	deco(parent, Vector3.new(3.4, 0.6, length + 0.4), cf * CFrame.new(0, -height / 2 + 0.3, 0), C.Curb, M.Concrete)
end

-- Mobilier ----------------------------------------------------------------------------------------

local function bench(parent: Instance, cf: CFrame)
	local model = Instance.new("Model")
	model.Name = "Banc"
	model.Parent = parent
	for _, x in { -2.6, 2.6 } do
		part(model, Vector3.new(0.4, 1.6, 1.8), cf * CFrame.new(x, 0.8, 0), C.Metal, M.Metal)
		deco(model, Vector3.new(0.4, 1.8, 0.3), cf * CFrame.new(x, 2.2, 0.85), C.Metal, M.Metal)
	end
	for i = 0, 2 do
		part(model, Vector3.new(6.4, 0.25, 0.5), cf * CFrame.new(0, 1.65, -0.6 + i * 0.6), C.Wood, M.Wood)
	end
	for i = 0, 1 do
		deco(model, Vector3.new(6.4, 0.4, 0.15), cf * CFrame.new(0, 2.3 + i * 0.6, 0.95), C.Wood, M.Wood)
	end
end

local function lampPost(parent: Instance, base: Vector3)
	local model = Instance.new("Model")
	model.Name = "Lampadaire"
	model.Parent = parent
	column(model, 0.8, 1.4, base, C.Metal, M.Metal)
	column(model, 13, 0.45, base, C.Metal, M.Metal)
	deco(model, Vector3.new(0.35, 0.35, 2.6), CFrame.new(base + Vector3.new(0, 13, 1)), C.Metal, M.Metal)
	local head = deco(model, Vector3.new(1.4, 0.5, 2), CFrame.new(base + Vector3.new(0, 12.8, 2.2)), C.Metal, M.Metal)
	local bulb = deco(model, Vector3.new(1, 0.15, 1.6), head.CFrame * CFrame.new(0, -0.3, 0), C.Lamp, M.Neon)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 110
	light.Range = 26
	light.Brightness = 2.2
	light.Color = C.Lamp
	light.Shadows = true
	light.Parent = bulb
end

local function vendingMachine(parent: Instance, cf: CFrame, color: Color3)
	local model = Instance.new("Model")
	model.Name = "Distributeur"
	model.Parent = parent
	part(model, Vector3.new(4, 7, 3), cf * CFrame.new(0, 3.5, 0), color, M.Plastic)
	-- Vitrine éclairée avec rangées de canettes.
	local display = deco(model, Vector3.new(3.2, 3.2, 0.1), cf * CFrame.new(0, 4.6, -1.51), rgb(236, 240, 244), M.Neon)
	display.Transparency = 0.15
	local cans = { rgb(220, 60, 60), rgb(60, 140, 220), rgb(250, 200, 60), rgb(70, 180, 90), rgb(240, 240, 240) }
	for row = 0, 2 do
		for col = 0, 4 do
			deco(
				model,
				Vector3.new(0.4, 0.75, 0.1),
				cf * CFrame.new(-1.2 + col * 0.6, 3.6 + row * 1, -1.58),
				cans[(row * 5 + col) % #cans + 1],
				M.SmoothPlastic
			)
		end
	end
	deco(model, Vector3.new(3, 0.9, 0.2), cf * CFrame.new(0, 1.2, -1.55), rgb(30, 30, 34), M.SmoothPlastic)
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Range = 8
	glow.Brightness = 0.8
	glow.Color = rgb(230, 240, 255)
	glow.Parent = display
end

local function bicycle(parent: Instance, cf: CFrame, color: Color3)
	for _, z in { -1.6, 1.6 } do
		local wheel = deco(parent, Vector3.new(0.2, 2.4, 2.4), cf * CFrame.new(0, 1.2, z), rgb(30, 30, 32), M.Rubber)
		wheel.Shape = Enum.PartType.Cylinder
	end
	beam(
		parent,
		(cf * CFrame.new(0, 1.2, -1.6)).Position,
		(cf * CFrame.new(0, 2.3, 0.2)).Position,
		0.18,
		color,
		M.Metal
	)
	beam(parent, (cf * CFrame.new(0, 2.3, 0.2)).Position, (cf * CFrame.new(0, 1.2, 1.6)).Position, 0.18, color, M.Metal)
	beam(
		parent,
		(cf * CFrame.new(0, 1.2, -1.6)).Position,
		(cf * CFrame.new(0, 2.4, -1.2)).Position,
		0.18,
		color,
		M.Metal
	)
	deco(parent, Vector3.new(0.5, 0.2, 1), cf * CFrame.new(0, 2.6, 0.2), rgb(30, 30, 32), M.Leather)
	deco(parent, Vector3.new(1.6, 0.15, 0.15), cf * CFrame.new(0, 2.6, -1.3), rgb(40, 40, 44), M.Metal)
	-- Panier avant.
	deco(parent, Vector3.new(1, 0.7, 0.8), cf * CFrame.new(0, 2.3, -2), rgb(120, 124, 130), M.DiamondPlate)
end

local function bikeShelter(parent: Instance, origin: CFrame)
	local model = Instance.new("Model")
	model.Name = "AbriVelos"
	model.Parent = parent
	local length = 44
	for i = 0, 4 do
		local z = -length / 2 + i * (length / 4)
		column(model, 9, 0.5, (origin * CFrame.new(-3, 0, z)).Position, C.Metal, M.Metal)
	end
	local roof = part(
		model,
		Vector3.new(10, 0.4, length + 2),
		origin * CFrame.new(0.5, 9.2, 0) * CFrame.Angles(0, 0, math.rad(-8)),
		rgb(120, 150, 160),
		M.CorrodedMetal
	)
	roof.Transparency = 0.15
	part(model, Vector3.new(9, 0.3, length), origin * CFrame.new(0.5, 0.15, 0), C.PavingDark, M.Concrete)
	local colors = { rgb(200, 60, 60), rgb(240, 240, 236), rgb(60, 110, 200), rgb(40, 40, 44), rgb(100, 170, 120) }
	for i = 1, 9 do
		if rng:NextNumber() < 0.75 then
			bicycle(
				model,
				origin * CFrame.new(0.5, 0.3, -length / 2 + i * (length / 10)) * CFrame.Angles(0, math.rad(90), 0),
				pick(colors)
			)
		end
	end
end

local function flagpole(parent: Instance, base: Vector3)
	column(parent, 22, 0.5, base, rgb(220, 222, 226), M.Metal)
	ball(parent, 0.9, base + Vector3.new(0, 22.3, 0), rgb(220, 190, 80), M.Metal)
	local flag = deco(
		parent,
		Vector3.new(0.1, 3.6, 5.4),
		CFrame.new(base + Vector3.new(0, 19.6, 2.9)),
		rgb(246, 246, 240),
		M.Fabric
	)
	signText(flag, Enum.NormalId.Right, "青嶺", rgb(30, 60, 140), 30, GOTHAM)
	signText(flag, Enum.NormalId.Left, "青嶺", rgb(30, 60, 140), 30, GOTHAM)
end

local function stoneLantern(parent: Instance, base: Vector3)
	local stone = rgb(160, 156, 148)
	deco(parent, Vector3.new(2.4, 0.6, 2.4), CFrame.new(base + Vector3.new(0, 0.3, 0)), stone, M.Granite)
	column(parent, 2.4, 0.8, base + Vector3.new(0, 0.6, 0), stone, M.Granite)
	local box = deco(parent, Vector3.new(1.8, 1.4, 1.8), CFrame.new(base + Vector3.new(0, 3.7, 0)), stone, M.Granite)
	local glow = deco(parent, Vector3.new(1.2, 0.9, 1.9), box.CFrame, rgb(255, 196, 120), M.Neon)
	glow.Transparency = 0.2
	gable(parent, CFrame.new(base + Vector3.new(0, 4.4, 0)), 2.6, 0.8, 2.6, stone, M.Granite)
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 1
	light.Color = rgb(255, 190, 120)
	light.Parent = glow
end

-- Bâtiments ----------------------------------------------------------------------------------------

-- Façade du lycée : 3 étages, bandeaux horizontaux, tour de l'horloge,
-- entrée vitrée avec auvent et nom du lycée. La façade regarde vers +Z.
local function schoolBuilding(parent: Instance, origin: CFrame)
	local template = assetModel(Assets.Models.LobbySchool)
	if template then
		local clone = template:Clone()
		clone:PivotTo(origin)
		clone.Parent = parent
		return
	end
	local model = Instance.new("Model")
	model.Name = "Lycee"
	model.Parent = parent
	local width, depth, floorHeight, floors = 250, 26, 13, 3
	local height = floorHeight * floors + 2
	-- Corps (la face avant est à z local = +depth/2).
	part(model, Vector3.new(width, height, depth), origin * CFrame.new(0, height / 2, 0), C.Plaster, M.Plaster)
	-- Socle et acrotère.
	deco(model, Vector3.new(width + 0.6, 2.2, depth + 0.6), origin * CFrame.new(0, 1.1, 0), C.PlasterShade, M.Concrete)
	deco(
		model,
		Vector3.new(width + 1.2, 1.4, depth + 1.2),
		origin * CFrame.new(0, height + 0.7, 0),
		C.PlasterShade,
		M.Concrete
	)
	local face = origin * CFrame.new(0, 0, depth / 2) * CFrame.Angles(0, math.pi, 0) -- -Z local = vers la cour
	for floor = 0, floors - 1 do
		local y = 2 + floor * floorHeight
		-- Bandeau de dalle entre les étages (balcon filant).
		if floor > 0 then
			deco(model, Vector3.new(width, 0.8, 2.2), face * CFrame.new(0, y, -1.1), C.PlasterShade, M.Concrete)
		end
		local x = -width / 2 + 9
		while x < width / 2 - 6 do
			if math.abs(x) > 16 then
				window(model, 7.2, 6.4, face * CFrame.new(x, y + 6.5, -0.2), if floor == 0 then 0.25 else 0.12)
			end
			x += 10.5
		end
	end
	-- Avant-corps de l'entrée et tour de l'horloge.
	local towerHeight = height + 20
	part(model, Vector3.new(30, towerHeight, 6), face * CFrame.new(0, towerHeight / 2, -2.6), C.Plaster, M.Plaster)
	deco(model, Vector3.new(31, 1.4, 7), face * CFrame.new(0, towerHeight + 0.7, -2.6), C.PlasterShade, M.Concrete)
	-- Toit de la tour.
	gable(model, face * CFrame.new(0, towerHeight + 1.4, -2.6), 32, 5, 8, C.RoofTile, M.ClayRoofTiles)
	-- Horloge.
	local clockCF = face * CFrame.new(0, height + 10, -5.7)
	local rim = deco(model, Vector3.new(0.5, 11, 11), clockCF * CFrame.Angles(0, math.rad(90), 0), C.Frame, M.Metal)
	rim.Shape = Enum.PartType.Cylinder
	local dial = deco(
		model,
		Vector3.new(0.4, 10, 10),
		clockCF * CFrame.new(0, 0, -0.1) * CFrame.Angles(0, math.rad(90), 0),
		rgb(250, 248, 240),
		M.SmoothPlastic
	)
	dial.Shape = Enum.PartType.Cylinder
	for hour = 0, 11 do
		local angle = hour / 12 * math.pi * 2
		deco(
			model,
			Vector3.new(0.35, if hour % 3 == 0 then 1.3 else 0.7, 0.1),
			clockCF * CFrame.new(math.sin(angle) * 4.2, math.cos(angle) * 4.2, -0.35) * CFrame.Angles(0, 0, -angle),
			C.Frame,
			M.Metal
		)
	end
	-- 17 h 25 : la cloche de fin des cours vient de sonner.
	local hourAngle = (5 + 25 / 60) / 12 * math.pi * 2
	local minuteAngle = 25 / 60 * math.pi * 2
	deco(
		model,
		Vector3.new(0.45, 2.6, 0.1),
		clockCF
			* CFrame.new(math.sin(hourAngle) * 1.2, math.cos(hourAngle) * 1.2, -0.4)
			* CFrame.Angles(0, 0, -hourAngle),
		rgb(30, 30, 36),
		M.Metal
	)
	deco(
		model,
		Vector3.new(0.3, 3.8, 0.1),
		clockCF
			* CFrame.new(math.sin(minuteAngle) * 1.8, math.cos(minuteAngle) * 1.8, -0.42)
			* CFrame.Angles(0, 0, -minuteAngle),
		rgb(30, 30, 36),
		M.Metal
	)
	-- Entrée vitrée, auvent, marches.
	for _, x in { -6, 0, 6 } do
		window(model, 5.2, 8.5, face * CFrame.new(x, 6.5, -5.75), 0.6)
	end
	deco(model, Vector3.new(26, 0.8, 8), face * CFrame.new(0, 11.5, -9), C.PlasterShade, M.Concrete)
	for _, x in { -12, 12 } do
		column(model, 11.5, 0.8, (face * CFrame.new(x, 0, -12.4)).Position, C.Plaster, M.Concrete)
	end
	for i = 0, 2 do
		part(
			model,
			Vector3.new(28 - i * 2, 0.6, 3),
			face * CFrame.new(0, 0.3 + i * 0.6, -13.5 + i * 2.2),
			C.PlasterShade,
			M.Concrete
		)
	end
	-- Nom du lycée au-dessus de l'entrée.
	local nameplate = deco(model, Vector3.new(24, 3, 0.4), face * CFrame.new(0, 15.5, -5.9), C.Plaster, M.Plaster)
	signText(nameplate, Enum.NormalId.Front, "青嶺高等学校", rgb(40, 52, 72), 30, GOTHAM)
	local latin = deco(model, Vector3.new(16, 1.4, 0.3), face * CFrame.new(0, 13.4, -5.9), C.Plaster, M.Plaster)
	signText(latin, Enum.NormalId.Front, "LYCÉE SEIRYŌ", rgb(80, 90, 110), 30, GOTHAM_BOLD)
	-- Bacs à fleurs le long de la façade.
	for _, side in { -1, 1 } do
		for i = 0, 7 do
			local x = side * (24 + i * 12)
			local planter = face * CFrame.new(x, 0.9, -3)
			deco(model, Vector3.new(8, 1.8, 2.4), planter, C.PlasterShade, M.Concrete)
			deco(model, Vector3.new(7.4, 0.8, 1.8), planter * CFrame.new(0, 1.1, 0), C.Hedge, M.LeafyGrass)
		end
	end
end

-- Gymnase : grand volume, toit en voûte (wedges), portes et bandeau vitré.
-- La façade principale regarde vers -X (la cour).
local function gym(parent: Instance, origin: CFrame)
	local model = Instance.new("Model")
	model.Name = "Gymnase"
	model.Parent = parent
	local width, depth, height = 96, 80, 30
	part(model, Vector3.new(depth, height, width), origin * CFrame.new(0, height / 2, 0), C.GymWall, M.Plaster)
	deco(model, Vector3.new(depth + 0.6, 3, width + 0.6), origin * CFrame.new(0, 1.5, 0), C.PlasterShade, M.Concrete)
	-- Toit voûté : deux pentes douces et un faîtage.
	local roofRise = 12
	gable(model, origin * CFrame.new(0, height, 0), depth + 4, roofRise, width + 4, C.GymRoof, M.CorrodedMetal)
	-- Bandeau vitré haut, sur la façade côté cour.
	local face = origin * CFrame.new(-depth / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	for i = -4, 4 do
		window(model, 8, 4, face * CFrame.new(i * 10, height - 5, -0.2), 0.5)
	end
	-- Portes coulissantes vertes.
	for _, x in { -14, 14 } do
		deco(model, Vector3.new(14, 11, 0.5), face * CFrame.new(x, 5.5, -0.3), rgb(70, 110, 90), M.Metal)
		deco(model, Vector3.new(0.3, 11, 0.6), face * CFrame.new(x, 5.5, -0.35), rgb(40, 60, 50), M.Metal)
	end
	deco(model, Vector3.new(44, 1, 4), face * CFrame.new(0, 12, -2), C.PlasterShade, M.Concrete)
	local sign = deco(model, Vector3.new(28, 4, 0.4), face * CFrame.new(0, 16.5, -0.4), rgb(30, 50, 90), M.Metal)
	signText(sign, Enum.NormalId.Front, "体育館 · GYMNASE", rgb(255, 255, 255), 30, GOTHAM)
end

-- Aile des classes (2 étages), façade vers -X.
local function classWing(parent: Instance, origin: CFrame, length: number)
	local model = Instance.new("Model")
	model.Name = "AileClasses"
	model.Parent = parent
	local depth, floorHeight = 24, 12
	local height = floorHeight * 2 + 2
	part(model, Vector3.new(depth, height, length), origin * CFrame.new(0, height / 2, 0), C.Plaster, M.Plaster)
	deco(
		model,
		Vector3.new(depth + 1, 1.2, length + 1),
		origin * CFrame.new(0, height + 0.6, 0),
		C.PlasterShade,
		M.Concrete
	)
	local face = origin * CFrame.new(-depth / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	for floor = 0, 1 do
		local y = 2 + floor * floorHeight
		if floor > 0 then
			deco(model, Vector3.new(length, 0.8, 2), face * CFrame.new(0, y, -1), C.PlasterShade, M.Concrete)
			-- Garde-corps du couloir extérieur.
			deco(model, Vector3.new(length, 0.25, 0.25), face * CFrame.new(0, y + 3.4, -2), C.Trim, M.Metal)
		end
		local x = -length / 2 + 7
		while x < length / 2 - 5 do
			window(model, 6.4, 6, face * CFrame.new(x, y + 6, -0.2), 0.15)
			x += 9.5
		end
	end
end

-- Maison japonaise : rez-de-chaussée + étage, toit à deux pans en tuiles.
local function house(parent: Instance, origin: CFrame, width: number, depth: number)
	local model = Instance.new("Model")
	model.Name = "Maison"
	model.Parent = parent
	local wall = pick({ rgb(232, 224, 208), rgb(214, 206, 192), rgb(200, 194, 180), rgb(226, 214, 196) })
	local roof = pick({ rgb(60, 66, 80), rgb(84, 70, 64), rgb(56, 72, 70) })
	local height = 16
	deco(model, Vector3.new(width, height, depth), origin * CFrame.new(0, height / 2, 0), wall, M.Plaster)
	deco(model, Vector3.new(width + 0.4, 0.6, depth + 0.4), origin * CFrame.new(0, 8, 0), C.WoodDark, M.Wood)
	local rise = 5
	gable(model, origin * CFrame.new(0, height, 0), width + 3, rise, depth + 3, roof, M.ClayRoofTiles)
	-- Fenêtres sur la façade avant (-Z local).
	local face = origin * CFrame.new(0, 0, -depth / 2)
	for _, x in { -width / 4, width / 4 } do
		window(model, 4, 3.6, face * CFrame.new(x, 12, -0.1), 0.45)
	end
	window(model, 5, 3, face * CFrame.new(-width / 4, 4.6, -0.1), 0.35)
	deco(model, Vector3.new(3.2, 6.4, 0.3), face * CFrame.new(width / 4, 3.2, -0.15), C.WoodDark, M.Wood)
	-- Petit muret et portillon.
	deco(
		model,
		Vector3.new(width, 3, 0.8),
		face * CFrame.new(0, 1.5, -4),
		pick({ rgb(196, 190, 178), rgb(170, 164, 154) }),
		M.Concrete
	)
end

local function utilityPole(parent: Instance, base: Vector3): Attachment
	column(parent, 26, 0.9, base, rgb(150, 146, 138), M.Concrete).CanCollide = false
	deco(parent, Vector3.new(0.4, 0.4, 6), CFrame.new(base + Vector3.new(0, 23.5, 0)), C.Metal, M.Metal)
	deco(parent, Vector3.new(1.2, 1.6, 1.2), CFrame.new(base + Vector3.new(0.8, 20, 0)), rgb(120, 124, 128), M.Metal)
	local anchor = deco(parent, Vector3.new(0.2, 0.2, 0.2), CFrame.new(base + Vector3.new(0, 23.7, 2.6)), C.Metal)
	anchor.Transparency = 1
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	return attachment
end

local function wire(from: Attachment, to: Attachment)
	local cable = Instance.new("Beam")
	cable.Attachment0 = from
	cable.Attachment1 = to
	cable.Width0 = 0.12
	cable.Width1 = 0.12
	cable.CurveSize0 = -3
	cable.CurveSize1 = 3
	cable.Color = ColorSequence.new(rgb(30, 30, 34))
	cable.LightInfluence = 1
	cable.Segments = 12
	cable.FaceCamera = true
	cable.Parent = from.Parent
end

-- Colline boisée : grandes pentes et masse d'arbres, ferme l'horizon.
local function hill(
	parent: Instance,
	center: Vector3,
	width: number,
	depth: number,
	height: number,
	yaw: number,
	trees: number
)
	local cf = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
	gable(parent, cf, width, height, depth, vary(C.GrassDark, 0.08), M.Grass)
	for _ = 1, trees do
		local u = rng:NextNumber(-0.45, 0.45)
		local v = rng:NextNumber(-0.42, 0.42)
		local y = height * (1 - math.abs(v) * 2) - 2
		forestTree(parent, (cf * CFrame.new(u * width, y, v * depth)).Position, rng:NextNumber(1.2, 1.8))
	end
end

local function mountain(parent: Instance, center: Vector3, width: number, height: number, yaw: number)
	local cf = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
	gable(parent, cf, width * 0.6, height, width, vary(C.Mountain, 0.06), M.Rock)
end

-- Sol, allées, limites ---------------------------------------------------------------------------

local function ground(parent: Instance)
	-- Grande dalle d'herbe sous tout le décor, puis la cour en terre battue.
	part(parent, Vector3.new(1400, 2, 1400), CFrame.new(0, -1.01, 0), C.Grass, M.Grass).Name = "Herbe"
	local court = part(
		parent,
		Vector3.new(BOUNDS.MaxX - BOUNDS.MinX + 8, 1, BOUNDS.MaxZ - BOUNDS.MinZ + 8),
		CFrame.new((BOUNDS.MinX + BOUNDS.MaxX) / 2, -0.49, (BOUNDS.MinZ + BOUNDS.MaxZ) / 2),
		C.Ground,
		M.Ground
	)
	court.Name = "Cour"
	-- Allée pavée centrale (portail → terrains) et parvis devant le lycée.
	deco(parent, Vector3.new(22, 0.1, 110), CFrame.new(0, 0.05, 74), C.Paving, M.Pavement)
	for _, x in { -11.4, 11.4 } do
		deco(parent, Vector3.new(0.8, 0.3, 110), CFrame.new(x, 0.15, 74), C.Curb, M.Concrete)
	end
	deco(parent, Vector3.new(250, 0.1, 18), CFrame.new(-27, 0.05, -117), C.Paving, M.Pavement)
	deco(parent, Vector3.new(16, 0.1, 196), CFrame.new(137, 0.05, 28), C.Paving, M.Pavement)
	-- Parvis du point d'apparition : dalle circulaire et emblème.
	local plaza = deco(
		parent,
		Vector3.new(0.12, 30, 30),
		CFrame.new(SPAWN + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		C.PavingDark,
		M.Pavement
	)
	plaza.Shape = Enum.PartType.Cylinder
	local ring = deco(
		parent,
		Vector3.new(0.14, 22, 22),
		CFrame.new(SPAWN + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		C.Paving,
		M.Marble
	)
	ring.Shape = Enum.PartType.Cylinder
	local emblem = deco(parent, Vector3.new(14, 0.05, 14), CFrame.new(SPAWN + Vector3.new(0, 0.17, 0)), C.Paving)
	emblem.Transparency = 1
	signText(emblem, Enum.NormalId.Top, "青嶺", rgb(60, 80, 120), 20, GOTHAM)
end

local function boundaries(parent: Instance)
	local height = 80
	local function wall(size: Vector3, position: Vector3)
		local w = part(parent, size, CFrame.new(position + Vector3.new(0, height / 2, 0)), rgb(0, 0, 0))
		w.Name = "Limite"
		w.Transparency = 1
		w.CanQuery = false
		w.CastShadow = false
	end
	local cx = (BOUNDS.MinX + BOUNDS.MaxX) / 2
	local cz = (BOUNDS.MinZ + BOUNDS.MaxZ) / 2
	local sx = BOUNDS.MaxX - BOUNDS.MinX
	local sz = BOUNDS.MaxZ - BOUNDS.MinZ
	wall(Vector3.new(sx + 4, height, 2), Vector3.new(cx, 0, BOUNDS.MinZ - 1))
	wall(Vector3.new(sx + 4, height, 2), Vector3.new(cx, 0, BOUNDS.MaxZ + 1))
	wall(Vector3.new(2, height, sz + 4), Vector3.new(BOUNDS.MinX - 1, 0, cz))
	wall(Vector3.new(2, height, sz + 4), Vector3.new(BOUNDS.MaxX + 1, 0, cz))
end

-- Mur d'enceinte sud avec le portail du lycée.
local function southGate(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Portail"
	model.Parent = parent
	local z = BOUNDS.MaxZ + 3
	local wallColor = rgb(206, 200, 188)
	for _, side in { -1, 1 } do
		local from, to = 15, 152
		local length = to - from
		local x = side * (from + length / 2)
		part(model, Vector3.new(length, 5, 1.6), CFrame.new(x, 2.5, z), wallColor, M.Concrete)
		deco(model, Vector3.new(length, 0.6, 2), CFrame.new(x, 5.3, z), rgb(170, 164, 152), M.Concrete)
		-- Grille verte au-dessus du muret.
		local grid = deco(model, Vector3.new(length, 4, 0.2), CFrame.new(x, 7.6, z), C.FenceGreen, M.DiamondPlate)
		grid.Transparency = 0.5
		-- Piliers du portail.
		part(model, Vector3.new(3, 10, 3), CFrame.new(side * 14, 5, z), wallColor, M.Concrete)
		deco(model, Vector3.new(3.6, 0.8, 3.6), CFrame.new(side * 14, 10.4, z), rgb(170, 164, 152), M.Concrete)
	end
	local plate = deco(model, Vector3.new(0.4, 6, 1.8), CFrame.new(-15.75, 5.5, z), rgb(236, 232, 222), M.Marble)
	signText(plate, Enum.NormalId.Left, "青嶺高校", rgb(30, 30, 36), 30, GOTHAM)
	-- Grille coulissante à moitié ouverte.
	for i = 0, 8 do
		deco(model, Vector3.new(0.2, 5, 0.2), CFrame.new(-12 + i * 1.2, 2.5, z + 1.2), rgb(150, 154, 160), M.Metal)
	end
	deco(model, Vector3.new(10, 0.3, 0.3), CFrame.new(-7.2, 4.8, z + 1.2), rgb(150, 154, 160), M.Metal)
	deco(model, Vector3.new(10, 0.3, 0.3), CFrame.new(-7.2, 0.4, z + 1.2), rgb(150, 154, 160), M.Metal)
end

-- Rue au sud et maisons, poteaux électriques reliés par des câbles.
local function street(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Rue"
	model.Parent = parent
	local roadZ = 146
	deco(model, Vector3.new(700, 0.2, 22), CFrame.new(0, 0.1, roadZ), C.Asphalt, M.Asphalt)
	for x = -340, 340, 16 do
		deco(model, Vector3.new(7, 0.05, 0.5), CFrame.new(x, 0.22, roadZ), C.Line, M.SmoothPlastic)
	end
	deco(model, Vector3.new(700, 0.4, 6), CFrame.new(0, 0.2, roadZ - 14), C.Paving, M.Pavement)
	deco(model, Vector3.new(700, 0.4, 6), CFrame.new(0, 0.2, roadZ + 14), C.Paving, M.Pavement)
	local previous: Attachment? = nil
	for x = -300, 300, 50 do
		local attachment = utilityPole(model, Vector3.new(x, 0, roadZ + 16))
		if previous then
			wire(previous, attachment)
		end
		previous = attachment
	end
	local x = -320
	while x < 320 do
		local width = rng:NextNumber(18, 26)
		house(model, CFrame.new(x + width / 2, 0, roadZ + 32) * CFrame.Angles(0, 0, 0), width, rng:NextNumber(18, 24))
		x += width + rng:NextNumber(4, 9)
	end
end

-- Construction -------------------------------------------------------------------------------------

local function build(): Model
	local world = Instance.new("Model")
	world.Name = "Lobby"

	ground(world)
	boundaries(world)

	-- Spawn : face aux terrains (vers le nord).
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Apparition"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 0.2, 14)
	spawn.CFrame = CFrame.lookAt(SPAWN + Vector3.new(0, 0.2, 0), SPAWN + Vector3.new(0, 0.2, -10))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = world

	-- Bâtiments qui ferment la cour.
	schoolBuilding(world, CFrame.new(-27, 0, BOUNDS.MinZ - 16))
	gym(world, CFrame.new(150, 0, -118))
	classWing(world, CFrame.new(BOUNDS.MaxX + 14, 0, 28), 200)
	southGate(world)
	street(world)

	-- Côté ouest : haie, cerisiers, abri à vélos, colline boisée derrière.
	hedge(world, Vector3.new(BOUNDS.MinX - 2, 0, BOUNDS.MinZ), Vector3.new(BOUNDS.MinX - 2, 0, BOUNDS.MaxZ + 2), 4)
	for z = -112, 116, 26 do
		sakura(
			world,
			Vector3.new(BOUNDS.MinX + 8 + rng:NextNumber(-2, 2), 0, z + rng:NextNumber(-3, 3)),
			rng:NextNumber(1, 1.25)
		)
	end
	bikeShelter(world, CFrame.new(BOUNDS.MinX + 20, 0, -40))
	hill(world, Vector3.new(-250, -2, 0), 420, 120, 62, math.rad(90), 34)
	hill(world, Vector3.new(-200, -2, -260), 220, 160, 70, math.rad(20), 20)

	-- Côté est, devant l'aile des classes : cerisiers, bancs, distributeurs.
	for z = -50, 116, 34 do
		if z < 8 or z > 44 then
			sakura(world, Vector3.new(BOUNDS.MaxX - 18, 0, z), rng:NextNumber(0.95, 1.15))
			bench(world, CFrame.new(BOUNDS.MaxX - 24, 0, z + 9) * CFrame.Angles(0, math.rad(90), 0))
		end
	end
	vendingMachine(world, CFrame.new(BOUNDS.MaxX - 2.5, 0, 20) * CFrame.Angles(0, math.rad(90), 0), rgb(220, 60, 60))
	vendingMachine(world, CFrame.new(BOUNDS.MaxX - 2.5, 0, 25) * CFrame.Angles(0, math.rad(90), 0), rgb(240, 240, 236))
	vendingMachine(world, CFrame.new(BOUNDS.MaxX - 2.5, 0, 30) * CFrame.Angles(0, math.rad(90), 0), rgb(60, 120, 210))

	-- Devant le lycée : mât, lanternes de pierre, bancs.
	flagpole(world, Vector3.new(-80, 0, -112))
	stoneLantern(world, Vector3.new(-48, 0, -112))
	stoneLantern(world, Vector3.new(-6, 0, -112))
	for _, x in { -130, -110, 60, 80 } do
		bench(world, CFrame.new(x, 0, -111) * CFrame.Angles(0, math.pi, 0))
	end

	-- Allée du portail : lampadaires et cerisiers autour du parvis.
	for z = 30, 116, 28 do
		lampPost(world, Vector3.new(-14, 0, z))
		lampPost(world, Vector3.new(14, 0, z + 14))
	end
	sakura(world, SPAWN + Vector3.new(-26, 0, 4), 1.3)
	sakura(world, SPAWN + Vector3.new(28, 0, -6), 1.25)
	bench(world, CFrame.new(SPAWN + Vector3.new(-22, 0, 16)) * CFrame.Angles(0, math.rad(-150), 0))
	bench(world, CFrame.new(SPAWN + Vector3.new(22, 0, 16)) * CFrame.Angles(0, math.rad(150), 0))
	for _, x in { -110, -60, 60, 110 } do
		lampPost(world, Vector3.new(x, 0, 30))
	end

	-- Fond lointain : collines au sud et à l'est, montagnes bleutées au nord.
	hill(world, Vector3.new(0, -2, 300), 760, 120, 50, 0, 40)
	hill(world, Vector3.new(330, -2, -40), 520, 140, 58, math.rad(90), 26)
	for i = 0, 6 do
		mountain(
			world,
			Vector3.new(-420 + i * 140, -4, -520 - rng:NextNumber(0, 80)),
			rng:NextNumber(220, 300),
			rng:NextNumber(110, 170),
			rng:NextNumber(-0.3, 0.3)
		)
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
	gui.Size = UDim2.fromOffset(240, 48)
	gui.StudsOffset = Vector3.new(0, 2.8, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = head

	local tag = Clan.tagOf(player)
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 24)
	name.FontFace = GOTHAM
	name.TextSize = 20
	name.TextColor3 = rgb(255, 255, 255)
	name.RichText = true
	name.Text = (if tag then `<font color="#7FD3FF">[{tag}]</font> ` else "") .. player.DisplayName
	name.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(22, 30, 58)
	stroke.Thickness = 2
	stroke.Parent = name

	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 26)
	pill.Size = UDim2.fromOffset(64, 18)
	pill.BackgroundColor3 = rgb(255, 122, 30)
	pill.BorderSizePixel = 0
	pill.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = pill
	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color = rgb(22, 30, 58)
	pillStroke.Thickness = 1.5
	pillStroke.Parent = pill
	local level = Instance.new("TextLabel")
	level.BackgroundTransparency = 1
	level.Size = UDim2.fromScale(1, 1)
	level.FontFace = GOTHAM
	level.TextSize = 12
	level.TextColor3 = rgb(255, 255, 255)
	level.Text = `NIV. {if profile then profile.Level else 1}`
	level.Parent = pill

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
	-- Plan de l'écran d'accueil : depuis le portail, sur la cour et le lycée.
	Workspace:SetAttribute("MenuCamera", CFrame.lookAt(Vector3.new(46, 18, 118), Vector3.new(-6, 16, -70)))
	Workspace:SetAttribute("MenuCameraEnd", CFrame.lookAt(Vector3.new(-40, 22, 108), Vector3.new(6, 18, -70)))
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
