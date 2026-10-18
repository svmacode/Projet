--!strict
-- Construit le gymnase du lycée Seiryō autour d'un terrain de handball
-- aux dimensions du mode : parquet, tracés officiels, buts rayés rouge et
-- blanc avec filets, gradins, bancs, banderoles, panneau d'affichage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Court = require(ReplicatedStorage.Shared.Court)

export type Built = {
	Model: Model,
	CFrame: CFrame,
	Dims: Court.Dimensions,
	Collidables: Folder,
	Scoreboard: { Home: TextLabel, Away: TextLabel, Clock: TextLabel, Period: TextLabel },
	BenchSpots: { [string]: Vector3 }, -- local, par équipe
}

local CourtBuilder = {}

local LINE_Y = 0.035
local LINE_W = 0.32
local WHITE = Color3.fromRGB(250, 250, 245)
local PARQUET = Color3.fromRGB(214, 150, 84)
local PARQUET_DARK = Color3.fromRGB(176, 108, 52)
local ZONE_FILL = Color3.fromRGB(64, 128, 214)
local WALL = Color3.fromRGB(236, 232, 220)
local WALL_LOW = Color3.fromRGB(40, 70, 140)
local RUNOFF = Color3.fromRGB(46, 160, 110)

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
			if i % 2 == 0 then Color3.fromRGB(226, 32, 52) else WHITE
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
	label.Font = font
	label.TextColor3 = color
	label.TextStrokeColor3 = stroke
	label.TextStrokeTransparency = 0
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
		l.Font = Enum.Font.Bangers
		l.TextScaled = true
		l.TextColor3 = color
		l.Text = text
		l.Parent = background
		return l
	end
	label(
		"Titre",
		UDim2.fromScale(0.25, 0.02),
		UDim2.fromScale(0.5, 0.18),
		Color3.fromRGB(255, 220, 60),
		"SEIRYŌ ARENA"
	)
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

local function sakuraBanner(
	model: Model,
	origin: CFrame,
	position: Vector3,
	facing: Vector3,
	text: string,
	color: Color3
)
	local banner =
		newPart(model, "Banderole", Vector3.new(18, 4, 0.3), origin * CFrame.lookAt(position, position + facing), color)
	decor(banner)
	surfaceText(banner, Enum.NormalId.Front, text, WHITE, Color3.fromRGB(20, 20, 24), Enum.Font.Bangers)
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
	local runoff = 12
	local hallLength = L + runoff * 2 + 8
	local hallWidth = W + runoff * 2 + 30 -- de la place pour les gradins
	local hallHeight = 42

	-- Sol : parquet du terrain + bandes de dégagement.
	local floor = newPart(
		collidables,
		"Parquet",
		Vector3.new(L, 2, W),
		origin * CFrame.new(0, -1, 0),
		PARQUET,
		Enum.Material.WoodPlanks
	)
	floor.CanCollide = true
	local runoffFloor = newPart(
		collidables,
		"Degagement",
		Vector3.new(hallLength, 2, hallWidth),
		origin * CFrame.new(0, -1.02, 0),
		RUNOFF,
		Enum.Material.SmoothPlastic
	)
	runoffFloor.CanCollide = true
	-- Lattes plus foncées pour un parquet lisible.
	for i = 0, math.floor(W / 6) do
		local z = -W / 2 + i * 6 + 3
		if z < W / 2 then
			local strip = newPart(
				lines,
				"Latte",
				Vector3.new(L, 0.02, 0.2),
				origin * CFrame.new(0, 0.005, z),
				PARQUET_DARK,
				Enum.Material.WoodPlanks
			)
			decor(strip)
		end
	end

	-- Zones de 6 m colorées (remplissage) : rectangle + deux cylindres. Le
	-- dégagement derrière la ligne de but recouvre la partie qui dépasse.
	for _, side in { -1, 1 } do
		local goalX = side * L / 2
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
		-- Bande de dégagement derrière le but (cache le débord des disques).
		local behind = newPart(
			lines,
			"DerriereBut",
			Vector3.new(runoff + 4, 0.06, W + 2 * r),
			origin * CFrame.new(goalX + side * (runoff + 4) / 2, 0.01, 0),
			RUNOFF
		)
		decor(behind)
		-- Les côtés du terrain au-delà de la ligne de touche.
		for _, zSign in { -1, 1 } do
			local sideStrip = newPart(
				lines,
				"Touche",
				Vector3.new(2 * r + 2, 0.06, r),
				origin * CFrame.new(goalX - side * (r / 2), 0.01, zSign * (W / 2 + r / 2)),
				RUNOFF
			)
			decor(sideStrip)
		end
	end

	-- Tracés officiels.
	local hl, hw = L / 2, W / 2
	lineSegment(lines, origin, Vector3.new(-hl, 0, -hw), Vector3.new(hl, 0, -hw))
	lineSegment(lines, origin, Vector3.new(-hl, 0, hw), Vector3.new(hl, 0, hw))
	lineSegment(lines, origin, Vector3.new(-hl, 0, -hw), Vector3.new(-hl, 0, hw))
	lineSegment(lines, origin, Vector3.new(hl, 0, -hw), Vector3.new(hl, 0, hw))
	lineSegment(lines, origin, Vector3.new(0, 0, -hw), Vector3.new(0, 0, hw))
	for _, side in { -1, 1 } do
		goalAreaLine(lines, origin, dims, side, dims.GoalAreaRadius, false)
		goalAreaLine(lines, origin, dims, side, dims.FreeThrowRadius, true)
		local penaltyX = side * (hl - dims.PenaltyDistance)
		lineSegment(lines, origin, Vector3.new(penaltyX, 0, -1.4), Vector3.new(penaltyX, 0, 1.4))
		local keeperX = side * (hl - dims.KeeperLineDistance)
		lineSegment(lines, origin, Vector3.new(keeperX, 0, -0.6), Vector3.new(keeperX, 0, 0.6))
		buildGoal(model, origin, dims, side, collidables)
	end
	-- Logo central.
	local centerLogo = newPart(
		lines,
		"LogoCentre",
		Vector3.new(0.03, 5.6, 5.6),
		origin * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(226, 32, 52)
	)
	centerLogo.Shape = Enum.PartType.Cylinder
	decor(centerLogo)

	-- Murs du gymnase.
	local wallThickness = 2
	local function wall(size: Vector3, position: Vector3)
		local part = newPart(collidables, "Mur", size, origin * CFrame.new(position), WALL, Enum.Material.SmoothPlastic)
		part.CanCollide = true
		local low = newPart(
			model,
			"Plinthe",
			Vector3.new(size.X + 0.1, 6, size.Z + 0.1),
			origin * CFrame.new(position.X, 3, position.Z),
			WALL_LOW
		)
		decor(low)
	end
	wall(Vector3.new(hallLength, hallHeight, wallThickness), Vector3.new(0, hallHeight / 2, -hallWidth / 2))
	wall(Vector3.new(hallLength, hallHeight, wallThickness), Vector3.new(0, hallHeight / 2, hallWidth / 2))
	wall(Vector3.new(wallThickness, hallHeight, hallWidth), Vector3.new(-hallLength / 2, hallHeight / 2, 0))
	wall(Vector3.new(wallThickness, hallHeight, hallWidth), Vector3.new(hallLength / 2, hallHeight / 2, 0))
	local ceiling = newPart(
		collidables,
		"Plafond",
		Vector3.new(hallLength, 2, hallWidth),
		origin * CFrame.new(0, hallHeight, 0),
		Color3.fromRGB(70, 74, 90)
	)
	ceiling.CanCollide = true

	-- Fenêtres hautes (lumière du jour) et poutres.
	for i = -3, 3 do
		local x = i * hallLength / 8
		for _, zSign in { -1, 1 } do
			local window = newPart(
				model,
				"Fenetre",
				Vector3.new(hallLength / 10, 7, 0.4),
				origin * CFrame.new(x, hallHeight - 9, zSign * (hallWidth / 2 - 1.1)),
				Color3.fromRGB(190, 230, 255),
				Enum.Material.Neon
			)
			decor(window)
		end
		local beam = newPart(
			model,
			"Poutre",
			Vector3.new(1.4, 1.6, hallWidth),
			origin * CFrame.new(x, hallHeight - 2, 0),
			Color3.fromRGB(40, 44, 60)
		)
		decor(beam)
		local lamp = newPart(
			model,
			"Lampe",
			Vector3.new(6, 0.5, 3),
			origin * CFrame.new(x, hallHeight - 3, 0),
			Color3.fromRGB(255, 252, 230),
			Enum.Material.Neon
		)
		decor(lamp)
		if i % 2 == 0 then
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Bottom
			light.Angle = 120
			light.Range = 60
			light.Brightness = 2.2
			light.Color = Color3.fromRGB(255, 248, 230)
			light.Shadows = true
			light.Parent = lamp
		end
	end

	-- Gradins côté -Z.
	local standZ = -hw - runoff
	for row = 0, 5 do
		local depth = 3
		local z = standZ - 4 - row * depth
		local y = row * 1.6
		local step = newPart(
			model,
			"Gradin",
			Vector3.new(L * 0.9, 1.6 + y, depth),
			origin * CFrame.new(0, (1.6 + y) / 2, z),
			Color3.fromRGB(90, 96, 120)
		)
		step.CanCollide = true
		local seatColor = if row % 2 == 0 then Color3.fromRGB(226, 32, 52) else Color3.fromRGB(30, 110, 245)
		local seat = newPart(
			model,
			"Siege",
			Vector3.new(L * 0.9, 0.4, 1.4),
			origin * CFrame.new(0, 1.6 + y + 0.2, z - 0.4),
			seatColor
		)
		decor(seat)
	end

	-- Bancs des équipes côté +Z et zone d'exclusion.
	local benchZ = hw + 6
	local benchSpots: { [string]: Vector3 } = {}
	for _, info in
		{
			{ Team = "Rouge", X = -hl * 0.35, Color = Color3.fromRGB(226, 32, 52) },
			{ Team = "Bleu", X = hl * 0.35, Color = Color3.fromRGB(30, 110, 245) },
		}
	do
		local bench =
			newPart(model, "Banc", Vector3.new(14, 1.4, 2.4), origin * CFrame.new(info.X, 0.7, benchZ + 2), info.Color)
		bench.CanCollide = true
		local back = newPart(
			model,
			"Dossier",
			Vector3.new(14, 3, 0.6),
			origin * CFrame.new(info.X, 2.2, benchZ + 3.3),
			info.Color
		)
		decor(back)
		benchSpots[info.Team] = Vector3.new(info.X, 0, benchZ)
	end
	-- Table de marque au milieu.
	local scoreTable = newPart(
		model,
		"TableMarque",
		Vector3.new(8, 3, 3),
		origin * CFrame.new(0, 1.5, benchZ + 1),
		Color3.fromRGB(30, 30, 40)
	)
	scoreTable.CanCollide = true

	-- Banderoles et tableau d'affichage.
	sakuraBanner(
		model,
		origin,
		Vector3.new(-hl * 0.5, 20, -hallWidth / 2 + 1.3),
		Vector3.new(0, 0, 1),
		"SEIRYŌ 青龍",
		Color3.fromRGB(30, 110, 245)
	)
	sakuraBanner(
		model,
		origin,
		Vector3.new(hl * 0.5, 20, -hallWidth / 2 + 1.3),
		Vector3.new(0, 0, 1),
		"全国制覇 !",
		Color3.fromRGB(226, 32, 52)
	)
	sakuraBanner(
		model,
		origin,
		Vector3.new(0, 26, hallWidth / 2 - 1.3),
		Vector3.new(0, 0, -1),
		"HANDBALL LEGENDS",
		Color3.fromRGB(20, 20, 24)
	)
	local scoreboard = buildScoreboard(model, origin, Vector3.new(-hallLength / 2 + 1.6, 22, 0), Vector3.new(1, 0, 0))
	local mirrorBoard = buildScoreboard(model, origin, Vector3.new(hallLength / 2 - 1.6, 22, 0), Vector3.new(-1, 0, 0))

	-- Les deux tableaux affichent la même chose : on relie le second au premier.
	for _, key in { "Home", "Away", "Clock", "Period" } do
		local source: TextLabel = scoreboard[key]
		local target: TextLabel = mirrorBoard[key]
		source:GetPropertyChangedSignal("Text"):Connect(function()
			target.Text = source.Text
		end)
	end

	model.Parent = parent
	return {
		Model = model,
		CFrame = origin,
		Dims = dims,
		Collidables = collidables,
		Scoreboard = scoreboard,
		BenchSpots = benchSpots,
	}
end

return CourtBuilder
