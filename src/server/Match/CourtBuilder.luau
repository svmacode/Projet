--!strict
-- Construit le gymnase du lycée Seiryō autour d'un terrain de handball aux
-- dimensions du mode. Direction artistique « animé de sport » façon Haikyuu :
-- parquet clair en bois aux lignes nettes, murs crème, grandes fenêtres
-- lumineuses, scène à rideaux rouges au fond, gradins en bois, banderoles du
-- club, tableau d'affichage et éclairage chaud.
--
-- Si ServerStorage.Assets contient le modèle Assets.Models.Gym (avec une Part
-- « Centre »), ce décor importé remplace le gymnase dessiné en code ; le sol,
-- les lignes, les buts et le tableau restent générés ici.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Court = require(ReplicatedStorage.Shared.Court)

export type Built = {
	Model: Model,
	CFrame: CFrame,
	Dims: Court.Dimensions,
	Collidables: Folder,
	Scoreboard: { Home: TextLabel, Away: TextLabel, Clock: TextLabel, Period: TextLabel },
}

local CourtBuilder = {}

local rgb = Color3.fromRGB
local LINE_Y = 0.035
local LINE_W = 0.34
local WHITE = rgb(252, 252, 248)
local WOOD = rgb(224, 186, 136) -- parquet clair
local WOOD_RUNOFF = rgb(196, 150, 100) -- dégagement, un ton plus foncé
local ZONE_FILL = rgb(64, 118, 196)
local CENTER_FILL = rgb(232, 118, 52)
local WALL = rgb(242, 234, 216) -- crème
local WAINSCOT = rgb(170, 118, 72) -- lambris bas en bois
local TRIM = rgb(120, 78, 46)
local INK = rgb(24, 20, 30)
local CLUB_ORANGE = rgb(240, 120, 40)
local CLUB_BLACK = rgb(28, 26, 30)

local function newPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function decor(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function lineSegment(parent: Instance, origin: CFrame, a: Vector3, b: Vector3, color: Color3?)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	if length < 0.01 then
		return
	end
	local cf = origin * CFrame.lookAt(Vector3.new(mid.X, LINE_Y, mid.Z), Vector3.new(b.X, LINE_Y, b.Z))
	local part = newPart(parent, "Ligne", Vector3.new(LINE_W, 0.07, length + LINE_W * 0.5), cf, color or WHITE)
	decor(part)
end

-- Arc de rayon r autour du point (cx, cz), de l'angle a0 à a1 (radians).
local function arc(
	parent: Instance,
	origin: CFrame,
	cx: number,
	cz: number,
	r: number,
	a0: number,
	a1: number,
	dashed: boolean
)
	local segments = math.max(6, math.floor(r * math.abs(a1 - a0) / 1.6))
	for i = 0, segments - 1 do
		if dashed and i % 2 == 1 then
			continue
		end
		local t0 = a0 + (a1 - a0) * i / segments
		local t1 = a0 + (a1 - a0) * (i + 1) / segments
		local p0 = Vector3.new(cx + r * math.cos(t0), 0, cz + r * math.sin(t0))
		local p1 = Vector3.new(cx + r * math.cos(t1), 0, cz + r * math.sin(t1))
		lineSegment(parent, origin, p0, p1)
	end
end

-- Ligne en « D » autour d'un but : deux quarts de cercle + une droite.
local function goalAreaLine(
	parent: Instance,
	origin: CFrame,
	dims: Court.Dimensions,
	side: number,
	radius: number,
	dashed: boolean
)
	local goalX = side * dims.Length / 2
	local halfWidth = dims.GoalWidth / 2
	local inward = -side
	-- Droite parallèle à la ligne de but.
	local x = goalX + inward * radius
	if dashed then
		local steps = math.max(2, math.floor(dims.GoalWidth / 1.6))
		for i = 0, steps - 1, 2 do
			local z0 = -halfWidth + dims.GoalWidth * i / steps
			local z1 = -halfWidth + dims.GoalWidth * (i + 1) / steps
			lineSegment(parent, origin, Vector3.new(x, 0, z0), Vector3.new(x, 0, z1))
		end
	else
		lineSegment(parent, origin, Vector3.new(x, 0, -halfWidth), Vector3.new(x, 0, halfWidth))
	end
	-- Quarts de cercle autour de chaque poteau, limités au terrain.
	local base = if side > 0 then math.pi else 0
	local maxZ = dims.Width / 2
	for _, zSign in { -1, 1 } do
		local postZ = zSign * halfWidth
		local a0 = base
		local a1 = base + (if side > 0 then -zSign else zSign) * math.pi / 2
		-- Le cercle ne doit pas sortir par la ligne de touche.
		local limit = math.clamp((maxZ - halfWidth) / radius, 0, 1)
		if limit < 1 then
			local cut = math.asin(limit)
			a1 = base + (if side > 0 then -zSign else zSign) * cut
		end
		arc(parent, origin, goalX, postZ, radius, a0, a1, dashed)
	end
end

local function stripedBar(
	parent: Instance,
	origin: CFrame,
	from: Vector3,
	to: Vector3,
	thickness: number,
	collidables: Folder
)
	local length = (to - from).Magnitude
	local direction = (to - from).Unit
	local segments = math.max(2, math.floor(length / 1.2))
	local segmentLength = length / segments
	for i = 0, segments - 1 do
		local a = from + direction * (segmentLength * i)
		local b = a + direction * segmentLength
		local mid = (a + b) / 2
		-- lookAt est indéfini pour une direction verticale : cas particulier.
		local cf = if math.abs(direction.Y) > 0.99
			then origin * CFrame.new(mid) * CFrame.Angles(math.pi / 2, 0, 0)
			else origin * CFrame.lookAt(mid, b)
		local part = newPart(
			collidables,
			"Poteau",
			Vector3.new(thickness, thickness, segmentLength),
			cf,
			if i % 2 == 0 then Color3.fromRGB(255, 52, 76) else WHITE
		)
		part.CanCollide = true
	end
	local _ = parent
end

local function buildGoal(model: Model, origin: CFrame, dims: Court.Dimensions, side: number, collidables: Folder)
	local goalX = side * dims.Length / 2
	local halfWidth = dims.GoalWidth / 2
	local height = dims.GoalHeight
	local post = 0.55
	local x = goalX + side * post / 2
	-- Poteaux et barre transversale rayés.
	stripedBar(
		model,
		origin,
		Vector3.new(x, 0, -halfWidth - post / 2),
		Vector3.new(x, height, -halfWidth - post / 2),
		post,
		collidables
	)
	stripedBar(
		model,
		origin,
		Vector3.new(x, 0, halfWidth + post / 2),
		Vector3.new(x, height, halfWidth + post / 2),
		post,
		collidables
	)
	stripedBar(
		model,
		origin,
		Vector3.new(x, height + post / 2, -halfWidth - post),
		Vector3.new(x, height + post / 2, halfWidth + post),
		post,
		collidables
	)
	-- Filet : fond, côtés, toit.
	local depth = dims.GoalDepth
	local netColor = Color3.fromRGB(245, 245, 240)
	local backX = goalX + side * (depth + post)
	local function net(name: string, size: Vector3, position: Vector3)
		local part = newPart(collidables, name, size, origin * CFrame.new(position), netColor, Enum.Material.Fabric)
		part.Transparency = 0.35
		part.CanCollide = true
	end
	net("FiletFond", Vector3.new(0.2, height, dims.GoalWidth + post * 2), Vector3.new(backX, height / 2, 0))
	net(
		"FiletHaut",
		Vector3.new(depth, 0.2, dims.GoalWidth + post * 2),
		Vector3.new(goalX + side * (depth / 2 + post), height, 0)
	)
	net(
		"FiletCote",
		Vector3.new(depth, height, 0.2),
		Vector3.new(goalX + side * (depth / 2 + post), height / 2, -halfWidth - post)
	)
	net(
		"FiletCote",
		Vector3.new(depth, height, 0.2),
		Vector3.new(goalX + side * (depth / 2 + post), height / 2, halfWidth + post)
	)
end

local function surfaceText(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	stroke: Color3,
	font: Enum.Font
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.FontFace = Font.fromEnum(font)
	label.TextColor3 = color
	label.TextStrokeColor3 = stroke
	label.TextStrokeTransparency = 1
	label.Parent = gui
	return label
end

local function buildScoreboard(model: Model, origin: CFrame, position: Vector3, facing: Vector3): any
	local frame = newPart(
		model,
		"Tableau",
		Vector3.new(26, 9, 1),
		origin * CFrame.lookAt(position, position + facing),
		Color3.fromRGB(16, 16, 22)
	)
	decor(frame)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = frame
	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
	background.Parent = gui

	local function label(name: string, pos: UDim2, size: UDim2, color: Color3, text: string): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = pos
		l.Size = size
		l.FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold)
		l.TextScaled = true
		l.TextColor3 = color
		l.Text = text
		l.Parent = background
		return l
	end
	label("Titre", UDim2.fromScale(0.25, 0.02), UDim2.fromScale(0.5, 0.18), Color3.fromRGB(255, 220, 60), "SEIRYŌ")
	local home =
		label("Rouge", UDim2.fromScale(0.03, 0.25), UDim2.fromScale(0.27, 0.6), Color3.fromRGB(255, 70, 80), "0")
	local away =
		label("Bleu", UDim2.fromScale(0.7, 0.25), UDim2.fromScale(0.27, 0.6), Color3.fromRGB(80, 150, 255), "0")
	local clock =
		label("Temps", UDim2.fromScale(0.32, 0.25), UDim2.fromScale(0.36, 0.42), Color3.fromRGB(255, 255, 255), "0:00")
	local period = label(
		"Periode",
		UDim2.fromScale(0.32, 0.68),
		UDim2.fromScale(0.36, 0.2),
		Color3.fromRGB(255, 220, 60),
		"1re MT"
	)
	return { Home = home, Away = away, Clock = clock, Period = period }
end

-- Banderole du club tendue sur un mur ou une rambarde.
local function banner(
	model: Model,
	origin: CFrame,
	position: Vector3,
	facing: Vector3,
	size: Vector2,
	text: string,
	back: Color3,
	color: Color3,
	font: Enum.Font
)
	local cloth = newPart(
		model,
		"Banderole",
		Vector3.new(size.X, size.Y, 0.2),
		origin * CFrame.lookAt(position, position + facing),
		back,
		Enum.Material.Fabric
	)
	decor(cloth)
	surfaceText(cloth, Enum.NormalId.Front, text, color, INK, font)
	-- Bordure fine en haut et en bas.
	for _, y in { size.Y / 2, -size.Y / 2 } do
		local edge = newPart(
			model,
			"Bordure",
			Vector3.new(size.X, 0.25, 0.25),
			origin * CFrame.lookAt(position, position + facing) * CFrame.new(0, y, 0),
			color
		)
		decor(edge)
	end
end

-- Gymnase importé (facultatif) ---------------------------------------------------------------

local function importedGym(origin: CFrame, model: Model): boolean
	local folder = ServerStorage:FindFirstChild("Assets")
	local template = folder and folder:FindFirstChild(Assets.Models.Gym)
	if not template or not template:IsA("Model") then
		return false
	end
	local gym = template:Clone()
	local centre = gym:FindFirstChild("Centre", true)
	if centre and centre:IsA("BasePart") then
		local offset = gym:GetPivot():ToObjectSpace(centre.CFrame)
		gym:PivotTo(origin * offset:Inverse())
		centre.Transparency = 1
		centre.CanCollide = false
	else
		gym:PivotTo(origin)
	end
	gym.Parent = model
	return true
end

-- Gymnase dessiné en code ----------------------------------------------------------------

local function buildHall(
	model: Model,
	collidables: Folder,
	origin: CFrame,
	dims: Court.Dimensions,
	runoff: number
): (number, number, number)
	local L, W = dims.Length, dims.Width
	local stageDepth = 14
	local standDepth = 20
	local hallLength = L + runoff * 2 + stageDepth
	local hallWidth = W + runoff * 2 + standDepth
	local hallHeight = 44
	-- Le hall est décalé : scène derrière le but +X, gradins côté -Z.
	local hallCenter = Vector3.new(stageDepth / 2, 0, -standDepth / 2)
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(hallCenter.X + x, y, hallCenter.Z + z)
	end
	local wallThickness = 2
	local hx, hz = hallLength / 2, hallWidth / 2

	-- Murs crème, lambris bas en bois.
	local function wall(size: Vector3, cframe: CFrame)
		local part = newPart(collidables, "Mur", size, cframe, WALL)
		part.CanCollide = true
		local low = newPart(
			model,
			"Lambris",
			Vector3.new(size.X + 0.2, 7, size.Z + 0.2),
			cframe * CFrame.new(0, -size.Y / 2 + 3.5, 0),
			WAINSCOT,
			Enum.Material.Wood
		)
		decor(low)
		local rail = newPart(
			model,
			"Moulure",
			Vector3.new(size.X + 0.4, 0.5, size.Z + 0.4),
			cframe * CFrame.new(0, -size.Y / 2 + 7.1, 0),
			TRIM,
			Enum.Material.Wood
		)
		decor(rail)
	end
	wall(Vector3.new(hallLength, hallHeight, wallThickness), at(0, hallHeight / 2, -hz))
	wall(Vector3.new(hallLength, hallHeight, wallThickness), at(0, hallHeight / 2, hz))
	wall(Vector3.new(wallThickness, hallHeight, hallWidth), at(-hx, hallHeight / 2, 0))
	wall(Vector3.new(wallThickness, hallHeight, hallWidth), at(hx, hallHeight / 2, 0))

	-- Plafond : charpente métallique claire et caissons.
	local ceiling = newPart(
		collidables,
		"Plafond",
		Vector3.new(hallLength, 2, hallWidth),
		at(0, hallHeight + 1, 0),
		rgb(214, 210, 200)
	)
	ceiling.CanCollide = true
	local trussCount = math.floor(hallLength / 16)
	for i = 0, trussCount do
		local x = -hx + i * hallLength / trussCount
		local truss = newPart(
			model,
			"Ferme",
			Vector3.new(0.8, 2.4, hallWidth),
			at(x, hallHeight - 1.2, 0),
			rgb(236, 236, 230),
			Enum.Material.Metal
		)
		decor(truss)
	end

	-- Rangées de lampes chaudes.
	for i = -2, 2 do
		for _, zFrac in { -0.25, 0.25 } do
			local lamp = newPart(
				model,
				"Lampe",
				Vector3.new(5, 0.6, 5),
				at(i * hallLength / 6, hallHeight - 3.2, zFrac * hallWidth),
				rgb(255, 246, 222),
				Enum.Material.Neon
			)
			decor(lamp)
			if (i + (if zFrac > 0 then 1 else 0)) % 2 == 0 then
				local light = Instance.new("SpotLight")
				light.Face = Enum.NormalId.Bottom
				light.Angle = 110
				light.Range = 60
				light.Brightness = 2.6
				light.Color = rgb(255, 238, 214)
				light.Shadows = true
				light.Parent = lamp
			end
		end
	end

	-- Grandes fenêtres sur les deux longs murs (vitre + montants crème).
	local windowCount = math.max(4, math.floor(hallLength / 22))
	for i = 0, windowCount - 1 do
		local x = -hx + (i + 0.5) * hallLength / windowCount
		for _, zSign in { -1, 1 } do
			local z = zSign * (hz - 1.6)
			local width = hallLength / windowCount - 5
			local pane = newPart(
				model,
				"Vitre",
				Vector3.new(width, 13, 0.3),
				at(x, hallHeight - 15, z),
				rgb(214, 236, 255),
				Enum.Material.Glass
			)
			pane.Transparency = 0.25
			decor(pane)
			local glow = newPart(
				model,
				"Jour",
				Vector3.new(width, 13, 0.2),
				at(x, hallHeight - 15, z + zSign * 0.45),
				rgb(255, 248, 230),
				Enum.Material.Neon
			)
			glow.Transparency = 0.15
			decor(glow)
			local light = Instance.new("SurfaceLight")
			light.Face = if zSign > 0 then Enum.NormalId.Front else Enum.NormalId.Back
			light.Range = 26
			light.Angle = 80
			light.Brightness = 1.1
			light.Color = rgb(255, 240, 214)
			light.Parent = glow
			for k = 0, 2 do
				local mullion = newPart(
					model,
					"Montant",
					Vector3.new(0.5, 13.4, 0.5),
					at(x - width / 2 + k * width / 2, hallHeight - 15, z - zSign * 0.2),
					WALL
				)
				decor(mullion)
			end
			local sill = newPart(
				model,
				"Appui",
				Vector3.new(width + 0.6, 0.5, 0.9),
				at(x, hallHeight - 21.7, z - zSign * 0.3),
				WALL
			)
			decor(sill)
		end
	end

	-- Scène à rideaux rouges derrière le but +X (typique des gymnases japonais).
	local stageX = hx - stageDepth / 2 + 1
	local stage = newPart(
		collidables,
		"Scene",
		Vector3.new(stageDepth - 2, 5, hallWidth - 8),
		at(stageX, 2.5, 0),
		WAINSCOT,
		Enum.Material.Wood
	)
	stage.CanCollide = true
	local stageFront = newPart(
		model,
		"FaceScene",
		Vector3.new(0.3, 5, hallWidth - 8),
		at(stageX - (stageDepth - 2) / 2 - 0.15, 2.5, 0),
		TRIM,
		Enum.Material.Wood
	)
	decor(stageFront)
	local opening = hallWidth - 14
	-- Cadre de scène : deux piliers et un linteau (l'ouverture reste visible).
	local frameX = stageX - stageDepth / 2 + 1.2
	for _, zSign in { -1, 1 } do
		local pillar =
			newPart(model, "Pilier", Vector3.new(1.2, 22, 4), at(frameX, 16, zSign * (opening / 2 + 2)), CLUB_BLACK)
		decor(pillar)
	end
	local lintel = newPart(model, "Linteau", Vector3.new(1.2, 4, opening + 8), at(frameX, 25, 0), CLUB_BLACK)
	decor(lintel)
	for _, zSign in { -1, 1 } do
		local curtain = newPart(
			model,
			"Rideau",
			Vector3.new(0.6, 16, opening / 2 - 4),
			at(stageX - stageDepth / 2 + 2, 13, zSign * (opening / 4 + 2)),
			rgb(170, 30, 40),
			Enum.Material.Fabric
		)
		decor(curtain)
	end
	local valance = newPart(
		model,
		"Lambrequin",
		Vector3.new(0.8, 3.5, opening),
		at(stageX - stageDepth / 2 + 2.2, 23, 0),
		rgb(150, 22, 32),
		Enum.Material.Fabric
	)
	decor(valance)
	-- Blason du lycée au-dessus de la scène.
	local crest =
		newPart(model, "Blason", Vector3.new(0.4, 6, 6), at(stageX - stageDepth / 2 + 0.6, 31, 0), CLUB_ORANGE)
	crest.Shape = Enum.PartType.Cylinder
	decor(crest)
	local crestText = newPart(
		model,
		"BlasonTexte",
		Vector3.new(4.6, 4.6, 0.1),
		at(stageX - stageDepth / 2 + 0.35, 31, 0) * CFrame.Angles(0, math.pi / 2, 0),
		CLUB_ORANGE
	)
	crestText.Transparency = 1
	decor(crestText)
	surfaceText(crestText, Enum.NormalId.Front, "青", CLUB_BLACK, INK, Enum.Font.BuilderSansExtraBold)

	-- Gradins en bois côté -Z, avec rambarde et banderoles du club.
	local standFront = -dims.Width / 2 - runoff + 1
	local rows = 6
	for row = 0, rows - 1 do
		local depth = 3
		local z = standFront - 1.5 - row * depth
		local height = 1.5 + row * 1.5
		local step = newPart(
			model,
			"Gradin",
			Vector3.new(L * 0.86, height, depth),
			origin * CFrame.new(0, height / 2, z),
			if row % 2 == 0 then rgb(206, 160, 108) else rgb(194, 148, 98),
			Enum.Material.Wood
		)
		step.CanCollide = true
		step.CastShadow = true
	end
	local railY = 1.5 + 0.6
	local railZ = standFront + 0.2
	local rail = newPart(
		model,
		"Rambarde",
		Vector3.new(L * 0.86, 0.3, 0.3),
		origin * CFrame.new(0, railY + 3, railZ),
		rgb(232, 232, 228),
		Enum.Material.Metal
	)
	decor(rail)
	local postCount = math.floor(L * 0.86 / 8)
	for i = 0, postCount do
		local post = newPart(
			model,
			"Barreau",
			Vector3.new(0.25, 3, 0.25),
			origin * CFrame.new(-L * 0.43 + i * L * 0.86 / postCount, railY + 1.5, railZ),
			rgb(232, 232, 228),
			Enum.Material.Metal
		)
		decor(post)
	end
	banner(
		model,
		origin,
		Vector3.new(-L * 0.22, railY + 1.4, railZ + 0.3),
		Vector3.new(0, 0, 1),
		Vector2.new(20, 2.8),
		"飛べ",
		CLUB_BLACK,
		WHITE,
		Enum.Font.BuilderSansExtraBold
	)
	banner(
		model,
		origin,
		Vector3.new(L * 0.22, railY + 1.4, railZ + 0.3),
		Vector3.new(0, 0, 1),
		Vector2.new(20, 2.8),
		"SEIRYŌ HANDBALL",
		CLUB_ORANGE,
		CLUB_BLACK,
		Enum.Font.BuilderSansExtraBold
	)

	-- Grande banderole du club sur le mur opposé aux gradins.
	banner(
		model,
		origin,
		Vector3.new(0, 17, hallCenter.Z + hz - 1.4),
		Vector3.new(0, 0, -1),
		Vector2.new(34, 4.5),
		"全力  —  LYCÉE SEIRYŌ  —  全力",
		CLUB_ORANGE,
		WHITE,
		Enum.Font.BuilderSansExtraBold
	)

	-- Bancs des équipes côté +Z et table de marque.
	local benchZ = dims.Width / 2 + 5
	for _, info in { { X = -L * 0.3, Color = rgb(206, 52, 60) }, { X = L * 0.3, Color = rgb(44, 108, 210) } } do
		local seat = newPart(
			model,
			"Banc",
			Vector3.new(14, 1.4, 2.2),
			origin * CFrame.new(info.X, 0.7, benchZ + 1.5),
			info.Color
		)
		seat.CanCollide = true
		local legs = newPart(
			model,
			"Pieds",
			Vector3.new(13.6, 0.3, 2),
			origin * CFrame.new(info.X, 0.15, benchZ + 1.5),
			rgb(60, 60, 64),
			Enum.Material.Metal
		)
		decor(legs)
	end
	local scoreTable = newPart(
		model,
		"TableMarque",
		Vector3.new(9, 3, 2.6),
		origin * CFrame.new(0, 1.5, benchZ + 1),
		rgb(236, 230, 214),
		Enum.Material.Wood
	)
	scoreTable.CanCollide = true
	local apron =
		newPart(model, "TableFace", Vector3.new(9, 2, 0.1), origin * CFrame.new(0, 1.6, benchZ - 0.35), CLUB_ORANGE)
	decor(apron)
	surfaceText(apron, Enum.NormalId.Front, "SEIRYŌ", WHITE, INK, Enum.Font.BuilderSansExtraBold)

	-- Chariot de ballons dans un coin.
	local cart = newPart(
		model,
		"Chariot",
		Vector3.new(3, 2.4, 2),
		origin * CFrame.new(-dims.Length / 2 - runoff + 3, 1.4, dims.Width / 2 + runoff - 3),
		rgb(70, 70, 76),
		Enum.Material.Metal
	)
	decor(cart)
	for i = 0, 5 do
		local ball = newPart(
			model,
			"BallonDeco",
			Vector3.one * 1.1,
			cart.CFrame * CFrame.new((i % 3 - 1) * 0.9, 1.6, (i // 3 - 0.5) * 0.9),
			if i % 2 == 0 then rgb(240, 240, 236) else rgb(232, 118, 52)
		)
		ball.Shape = Enum.PartType.Ball
		decor(ball)
	end

	return hallLength, hallWidth, hallHeight
end

function CourtBuilder.build(modeId: string, origin: CFrame, parent: Instance): Built
	local dims = Court.get(modeId)
	local model = Instance.new("Model")
	model.Name = `Gymnase_{modeId}`
	local collidables = Instance.new("Folder")
	collidables.Name = "Collisions"
	collidables.Parent = model
	local lines = Instance.new("Folder")
	lines.Name = "Lignes"
	lines.Parent = model

	local L, W = dims.Length, dims.Width
	local runoff = 10
	local hl, hw = L / 2, W / 2

	-- Sol : parquet clair du terrain + dégagement un ton plus foncé.
	local floor = newPart(
		collidables,
		"Parquet",
		Vector3.new(L, 2, W),
		origin * CFrame.new(0, -1, 0),
		WOOD,
		Enum.Material.WoodPlanks
	)
	floor.CanCollide = true
	local runoffFloor = newPart(
		collidables,
		"Degagement",
		Vector3.new(L + runoff * 2 + 40, 2, W + runoff * 2 + 40),
		origin * CFrame.new(0, -1.02, 0),
		WOOD_RUNOFF,
		Enum.Material.WoodPlanks
	)
	runoffFloor.CanCollide = true

	-- Zones de 6 m peintes : rectangle + deux disques ; le surplus derrière la
	-- ligne de but et hors des touches est recouvert par le dégagement.
	for _, side in { -1, 1 } do
		local goalX = side * hl
		local r = dims.GoalAreaRadius
		local rect = newPart(
			lines,
			"Zone",
			Vector3.new(r, 0.03, dims.GoalWidth),
			origin * CFrame.new(goalX - side * r / 2, 0.012, 0),
			ZONE_FILL
		)
		decor(rect)
		for _, zSign in { -1, 1 } do
			local disc = newPart(
				lines,
				"Zone",
				Vector3.new(0.03, r * 2, r * 2),
				origin * CFrame.new(goalX, 0.012, zSign * dims.GoalWidth / 2) * CFrame.Angles(0, 0, math.pi / 2),
				ZONE_FILL
			)
			disc.Shape = Enum.PartType.Cylinder
			decor(disc)
		end
		local behind = newPart(
			lines,
			"DerriereBut",
			Vector3.new(r + 2, 0.06, W + 2 * r + 4),
			origin * CFrame.new(goalX + side * (r + 2) / 2, 0.02, 0),
			WOOD_RUNOFF,
			Enum.Material.WoodPlanks
		)
		decor(behind)
		for _, zSign in { -1, 1 } do
			local sideStrip = newPart(
				lines,
				"Touche",
				Vector3.new(2 * r + 2, 0.06, r + 2),
				origin * CFrame.new(goalX - side * (r / 2), 0.02, zSign * (hw + (r + 2) / 2)),
				WOOD_RUNOFF,
				Enum.Material.WoodPlanks
			)
			decor(sideStrip)
		end
	end

	-- Rond central orange.
	local centerDisc = newPart(
		lines,
		"RondCentral",
		Vector3.new(0.03, 9, 9),
		origin * CFrame.new(0, 0.014, 0) * CFrame.Angles(0, 0, math.pi / 2),
		CENTER_FILL
	)
	centerDisc.Shape = Enum.PartType.Cylinder
	decor(centerDisc)

	-- Tracés nets.
	lineSegment(lines, origin, Vector3.new(-hl, 0, -hw), Vector3.new(hl, 0, -hw))
	lineSegment(lines, origin, Vector3.new(-hl, 0, hw), Vector3.new(hl, 0, hw))
	lineSegment(lines, origin, Vector3.new(-hl, 0, -hw), Vector3.new(-hl, 0, hw))
	lineSegment(lines, origin, Vector3.new(hl, 0, -hw), Vector3.new(hl, 0, hw))
	lineSegment(lines, origin, Vector3.new(0, 0, -hw), Vector3.new(0, 0, hw))
	for _, side in { -1, 1 } do
		goalAreaLine(lines, origin, dims, side, dims.GoalAreaRadius, false)
		goalAreaLine(lines, origin, dims, side, dims.FreeThrowRadius, true)
		buildGoal(model, origin, dims, side, collidables)
	end

	local hallHeight = 40
	if not importedGym(origin, model) then
		local _length, _width, height = buildHall(model, collidables, origin, dims, runoff)
		hallHeight = height
	end

	-- Tableau d'affichage au-dessus du but -X (face au terrain).
	local scoreboard = buildScoreboard(
		model,
		origin,
		Vector3.new(-hl - runoff + 1.2, math.min(24, hallHeight - 12), 0),
		Vector3.new(1, 0, 0)
	)

	model.Parent = parent
	return {
		Model = model,
		CFrame = origin,
		Dims = dims,
		Collidables = collidables,
		Scoreboard = scoreboard,
	}
end

return CourtBuilder
