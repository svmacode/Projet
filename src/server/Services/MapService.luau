--!strict
-- Builds the competitive map (Tenshō High gymnasium) at the size of each mode,
-- and the small club room where players wait between matches.
--
-- Court-local space matches CourtGeometry: origin at the centre spot on top of
-- the floor, X along the length (goals at X = ±CourtLength/2), Z across, Y up.
-- The ball is simulated in code, so nothing here needs to collide with it;
-- decoration stays at the edges of the hall and well above head height so it
-- never blocks the camera or hides the ball.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local MapService = {}

export type Court = {
	Model: Model,
	CourtCFrame: CFrame,
	BenchPositions: { [string]: Vector3 },
	Destroy: () -> (),
}

local rgb = Color3.fromRGB

local PALETTE = {
	Court = rgb(226, 182, 124), -- varnished maple, playing area
	RunOff = rgb(38, 92, 96), -- teal surround
	GoalArea = rgb(44, 92, 168), -- painted 6 m area
	Line = rgb(250, 250, 246),
	LineDashed = rgb(250, 250, 246),
	WallWood = rgb(132, 88, 54),
	WallPlaster = rgb(238, 230, 212),
	Ceiling = rgb(214, 206, 190),
	Beam = rgb(96, 64, 40),
	Glass = rgb(196, 226, 246),
	PostRed = rgb(214, 36, 50),
	PostWhite = rgb(248, 248, 248),
	Net = rgb(245, 245, 245),
	Bleacher = rgb(182, 130, 82),
	BleacherDark = rgb(120, 82, 50),
	Bench = rgb(70, 74, 92),
	Curtain = rgb(150, 18, 32),
	StageWood = rgb(118, 76, 44),
	Board = rgb(16, 18, 28),
}

local LINE_WIDTH = 0.32
local LINE_Y = 0.035 -- lines sit just above the court surface
local FILL_Y = 0.012

local mapsFolder: Folder? = nil
local waitingCFrame = CFrame.new(0, 0, -700)

local function folder(): Folder
	if mapsFolder and mapsFolder.Parent then
		return mapsFolder
	end
	local existing = Workspace:FindFirstChild("HL_Maps")
	if existing and existing:IsA("Folder") then
		mapsFolder = existing
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "HL_Maps"
	created.Parent = Workspace
	mapsFolder = created
	return created
end

type PartProps = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Transparency: number?,
	Collide: boolean?,
	Shape: Enum.PartType?,
	Reflectance: number?,
	Shadow: boolean?,
}

local function part(parent: Instance, props: PartProps): Part
	local p = Instance.new("Part")
	p.Name = props.Name or "Part"
	p.Anchored = true
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.Reflectance = props.Reflectance or 0
	p.CanCollide = props.Collide == true
	p.CanTouch = false
	p.CanQuery = props.Collide == true
	p.CastShadow = props.Shadow ~= false
	if props.Shape then
		p.Shape = props.Shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Flat painted strip on the floor between two local points.
local function floorLine(parent: Instance, origin: CFrame, a: Vector3, b: Vector3, color: Color3?, width: number?)
	local delta = b - a
	local length = delta.Magnitude
	if length < 0.05 then
		return
	end
	local middle = (a + b) / 2
	local cf = origin * CFrame.lookAt(Vector3.new(middle.X, LINE_Y, middle.Z), Vector3.new(b.X, LINE_Y, b.Z))
	part(parent, {
		Name = "Line",
		Size = Vector3.new(width or LINE_WIDTH, 0.02, length + (width or LINE_WIDTH) * 0.5),
		CFrame = cf,
		Color = color or PALETTE.Line,
		Shadow = false,
	})
end

-- Arc of a line around `center` (local), from angle a0 to a1 (radians, measured
-- in the XZ plane from +X towards +Z). Dashed if `dash` is given (dash length).
local function arcLine(
	parent: Instance,
	origin: CFrame,
	center: Vector3,
	radius: number,
	a0: number,
	a1: number,
	halfWidth: number,
	dash: number?
)
	local arcLength = math.abs(a1 - a0) * radius
	local step = dash or 1.2
	local count = math.max(2, math.ceil(arcLength / step))
	for i = 0, count - 1 do
		if not dash or i % 2 == 0 then
			local t0 = a0 + (a1 - a0) * (i / count)
			local t1 = a0 + (a1 - a0) * ((i + 1) / count)
			local p0 = center + Vector3.new(math.cos(t0), 0, math.sin(t0)) * radius
			local p1 = center + Vector3.new(math.cos(t1), 0, math.sin(t1)) * radius
			if math.abs(p0.Z) <= halfWidth and math.abs(p1.Z) <= halfWidth then
				floorLine(parent, origin, p0, p1)
			end
		end
	end
end

-- "6 m" / "9 m" shape for the goal at `side`: two quarter circles around the
-- posts joined by a straight line parallel to the goal line.
local function zoneLine(
	parent: Instance,
	origin: CFrame,
	side: number,
	halfLength: number,
	halfWidth: number,
	radius: number,
	dash: number?
)
	local goalX = side * halfLength
	local halfGoal = Config.Goal.Width / 2
	-- Angle pointing from the goal towards the court centre.
	local inward = if side > 0 then math.pi else 0
	local towardPlus = math.pi / 2
	local towardMinus = -math.pi / 2
	-- Quarter around the +Z post: from "inward" to "+Z".
	arcLine(parent, origin, Vector3.new(goalX, 0, halfGoal), radius, inward, towardPlus, halfWidth, dash)
	arcLine(
		parent,
		origin,
		Vector3.new(goalX, 0, -halfGoal),
		radius,
		inward,
		if side > 0 then math.pi * 1.5 else towardMinus,
		halfWidth,
		dash
	)
	local x = goalX - side * radius
	if dash then
		local length = Config.Goal.Width
		local count = math.max(2, math.ceil(length / dash))
		for i = 0, count - 1 do
			if i % 2 == 0 then
				local z0 = -halfGoal + length * (i / count)
				local z1 = -halfGoal + length * ((i + 1) / count)
				floorLine(parent, origin, Vector3.new(x, 0, z0), Vector3.new(x, 0, z1))
			end
		end
	else
		floorLine(parent, origin, Vector3.new(x, 0, -halfGoal), Vector3.new(x, 0, halfGoal))
	end
end

-- Painted fill of the goal area (rectangle between the posts + two discs).
local function goalAreaFill(parent: Instance, origin: CFrame, side: number, halfLength: number, radius: number)
	local goalX = side * halfLength
	local halfGoal = Config.Goal.Width / 2
	part(parent, {
		Name = "GoalAreaFill",
		Size = Vector3.new(radius, 0.02, Config.Goal.Width),
		CFrame = origin * CFrame.new(goalX - side * radius / 2, FILL_Y, 0),
		Color = PALETTE.GoalArea,
		Shadow = false,
	})
	for _, z in { halfGoal, -halfGoal } do
		part(parent, {
			Name = "GoalAreaFill",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.02, radius * 2, radius * 2),
			CFrame = origin * CFrame.new(goalX, FILL_Y, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = PALETTE.GoalArea,
			Shadow = false,
		})
	end
end

-- Striped post (alternating red/white bands, as on real handball goals).
local function stripedBar(parent: Instance, from: CFrame, length: number, thickness: number)
	local band = 0.7
	local count = math.max(1, math.floor(length / band + 0.5))
	local bandLength = length / count
	for i = 0, count - 1 do
		part(parent, {
			Name = "PostBand",
			Size = Vector3.new(thickness, bandLength, thickness),
			CFrame = from * CFrame.new(0, bandLength * (i + 0.5), 0),
			Color = if i % 2 == 0 then PALETTE.PostRed else PALETTE.PostWhite,
			Collide = true,
		})
	end
end

local function buildGoal(parent: Instance, origin: CFrame, side: number, halfLength: number)
	local goal = Instance.new("Model")
	goal.Name = if side > 0 then "GoalPlusX" else "GoalMinusX"
	goal.Parent = parent
	local width = Config.Goal.Width
	local height = Config.Goal.Height
	local depth = Config.Goal.Depth
	local post = 0.5
	local goalX = side * (halfLength + post / 2)
	for _, z in { width / 2 + post / 2, -width / 2 - post / 2 } do
		stripedBar(goal, origin * CFrame.new(goalX, 0, z), height + post, post)
	end
	-- Crossbar: a horizontal striped bar along Z.
	stripedBar(
		goal,
		origin * CFrame.new(goalX, height + post / 2, width / 2 + post) * CFrame.Angles(math.rad(-90), 0, 0),
		width + post * 2,
		post
	)
	-- Net: light panels plus a few cords for texture (no collisions).
	local backX = side * (halfLength + depth)
	local netProps = { Color = PALETTE.Net, Material = Enum.Material.Fabric, Transparency = 0.72, Shadow = false }
	local function panel(size: Vector3, cf: CFrame)
		part(goal, {
			Name = "Net",
			Size = size,
			CFrame = cf,
			Color = netProps.Color,
			Material = netProps.Material,
			Transparency = netProps.Transparency,
			Shadow = false,
		})
	end
	panel(Vector3.new(0.05, height, width), origin * CFrame.new(backX, height / 2, 0))
	panel(Vector3.new(depth, 0.05, width), origin * CFrame.new(side * (halfLength + depth / 2), height, 0))
	for _, z in { width / 2, -width / 2 } do
		panel(Vector3.new(depth, height, 0.05), origin * CFrame.new(side * (halfLength + depth / 2), height / 2, z))
	end
	for i = 1, 7 do
		local z = -width / 2 + width * i / 8
		part(goal, {
			Name = "NetCord",
			Size = Vector3.new(0.08, height, 0.08),
			CFrame = origin * CFrame.new(backX, height / 2, z),
			Color = PALETTE.Net,
			Shadow = false,
		})
	end
	for i = 1, 4 do
		local y = height * i / 5
		part(goal, {
			Name = "NetCord",
			Size = Vector3.new(0.08, 0.08, width),
			CFrame = origin * CFrame.new(backX, y, 0),
			Color = PALETTE.Net,
			Shadow = false,
		})
	end
	-- Weighted frame at the bottom of the net.
	part(goal, {
		Name = "NetFrame",
		Size = Vector3.new(depth, 0.25, 0.25),
		CFrame = origin * CFrame.new(side * (halfLength + depth / 2), 0.12, width / 2),
		Color = PALETTE.PostWhite,
	})
	part(goal, {
		Name = "NetFrame",
		Size = Vector3.new(depth, 0.25, 0.25),
		CFrame = origin * CFrame.new(side * (halfLength + depth / 2), 0.12, -width / 2),
		Color = PALETTE.PostWhite,
	})
end

local function surfaceText(
	parent: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	font: Enum.Font,
	pixelsPerStud: number?
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	gui.LightInfluence = 0.2
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.FontFace = Font.fromEnum(font)
	label.Parent = gui
	return label
end

-- Scoreboard with named labels that clients update locally from MatchState
-- (RedScore, BlueScore, Clock, Period).
local function buildScoreboard(parent: Instance, cf: CFrame)
	local board = part(parent, {
		Name = "Scoreboard",
		Size = Vector3.new(22, 9, 0.6),
		CFrame = cf,
		Color = PALETTE.Board,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.Parent = board
	local function label(name: string, text: string, color: Color3, pos: UDim2, size: UDim2, font: Enum.Font)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = pos
		l.Size = size
		l.Text = text
		l.TextColor3 = color
		l.TextScaled = true
		l.FontFace = Font.fromEnum(font)
		l.Parent = gui
	end
	label(
		"Title",
		"TENSHŌ  天翔  GYM",
		rgb(255, 196, 60),
		UDim2.fromScale(0.05, 0.03),
		UDim2.fromScale(0.9, 0.16),
		Enum.Font.GothamBlack
	)
	label(
		"RedName",
		"▲ ROUGE",
		rgb(255, 90, 100),
		UDim2.fromScale(0.04, 0.24),
		UDim2.fromScale(0.3, 0.14),
		Enum.Font.GothamBold
	)
	label(
		"BlueName",
		"BLEU ●",
		rgb(90, 160, 255),
		UDim2.fromScale(0.66, 0.24),
		UDim2.fromScale(0.3, 0.14),
		Enum.Font.GothamBold
	)
	label(
		"RedScore",
		"0",
		rgb(255, 90, 100),
		UDim2.fromScale(0.04, 0.4),
		UDim2.fromScale(0.3, 0.5),
		Enum.Font.GothamBlack
	)
	label(
		"BlueScore",
		"0",
		rgb(90, 160, 255),
		UDim2.fromScale(0.66, 0.4),
		UDim2.fromScale(0.3, 0.5),
		Enum.Font.GothamBlack
	)
	label(
		"Clock",
		"0:00",
		rgb(255, 230, 120),
		UDim2.fromScale(0.36, 0.34),
		UDim2.fromScale(0.28, 0.32),
		Enum.Font.RobotoMono
	)
	label(
		"Period",
		"—",
		rgb(220, 220, 230),
		UDim2.fromScale(0.36, 0.68),
		UDim2.fromScale(0.28, 0.16),
		Enum.Font.GothamBold
	)
end

local function buildBench(parent: Instance, origin: CFrame, position: Vector3, color: Color3)
	part(parent, {
		Name = "Bench",
		Size = Vector3.new(14, 1.2, 2.4),
		CFrame = origin * CFrame.new(position + Vector3.new(0, 0.6, 0)),
		Color = PALETTE.Bench,
		Collide = true,
	})
	part(parent, {
		Name = "BenchBack",
		Size = Vector3.new(14, 3, 0.4),
		CFrame = origin * CFrame.new(position + Vector3.new(0, 2, -1.3)),
		Color = color,
	})
	-- Team towel-rail and water bottles: small, readable identity details.
	for i = -2, 2 do
		part(parent, {
			Name = "Bottle",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.9, 0.45, 0.45),
			CFrame = origin
				* CFrame.new(position + Vector3.new(i * 2.6, 1.65, 0.6))
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
		})
	end
end

local function buildHall(parent: Instance, origin: CFrame, halfLength: number, halfWidth: number)
	local hallHalfX = halfLength + 22
	local hallHalfZ = halfWidth + 22
	local wallHeight = 36
	local woodHeight = 6

	-- Long walls (±Z) and short walls (±X): wood wainscot + plaster + windows.
	local function wall(cf: CFrame, length: number, outward: Vector3)
		part(parent, {
			Name = "WallWood",
			Size = Vector3.new(length, woodHeight, 1),
			CFrame = cf * CFrame.new(0, woodHeight / 2, 0),
			Color = PALETTE.WallWood,
			Material = Enum.Material.WoodPlanks,
			Collide = true,
		})
		part(parent, {
			Name = "WallPlaster",
			Size = Vector3.new(length, wallHeight - woodHeight, 1),
			CFrame = cf * CFrame.new(0, woodHeight + (wallHeight - woodHeight) / 2, 0),
			Color = PALETTE.WallPlaster,
			Material = Enum.Material.Plaster,
			Collide = true,
		})
		-- Rail at the top of the wainscot.
		part(parent, {
			Name = "Rail",
			Size = Vector3.new(length, 0.5, 0.6),
			CFrame = cf * CFrame.new(0, woodHeight, 0) + outward * -0.4,
			Color = PALETTE.Beam,
		})
	end
	wall(origin * CFrame.new(0, 0, hallHalfZ + 0.5), hallHalfX * 2 + 2, Vector3.new(0, 0, 1))
	wall(origin * CFrame.new(0, 0, -hallHalfZ - 0.5), hallHalfX * 2 + 2, Vector3.new(0, 0, -1))
	wall(
		origin * CFrame.new(hallHalfX + 0.5, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
		hallHalfZ * 2 + 2,
		Vector3.new(1, 0, 0)
	)
	wall(
		origin * CFrame.new(-hallHalfX - 0.5, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
		hallHalfZ * 2 + 2,
		Vector3.new(-1, 0, 0)
	)

	-- Tall windows on both long walls: the main light source of the hall.
	local windowCount = math.floor(hallHalfX * 2 / 14)
	for i = 0, windowCount - 1 do
		local x = -hallHalfX + 7 + i * 14
		for _, sideZ in { 1, -1 } do
			local z = sideZ * (hallHalfZ + 0.05)
			local window = part(parent, {
				Name = "Window",
				Size = Vector3.new(8, 12, 0.3),
				CFrame = origin * CFrame.new(x, 20, z),
				Color = PALETTE.Glass,
				Material = Enum.Material.Neon,
				Transparency = 0.15,
				Shadow = false,
			})
			window.Color = rgb(206, 228, 240)
			part(parent, {
				Name = "WindowBar",
				Size = Vector3.new(0.4, 12, 0.5),
				CFrame = origin * CFrame.new(x, 20, z - sideZ * 0.1),
				Color = PALETTE.Beam,
			})
			part(parent, {
				Name = "WindowBar",
				Size = Vector3.new(8, 0.4, 0.5),
				CFrame = origin * CFrame.new(x, 20, z - sideZ * 0.1),
				Color = PALETTE.Beam,
			})
		end
	end

	-- Ceiling with exposed beams and lamp panels (high: never in the way).
	part(parent, {
		Name = "Ceiling",
		Size = Vector3.new(hallHalfX * 2 + 2, 1, hallHalfZ * 2 + 2),
		CFrame = origin * CFrame.new(0, wallHeight + 0.5, 0),
		Color = PALETTE.Ceiling,
		Collide = true,
	})
	local beamCount = math.floor(hallHalfX * 2 / 16)
	for i = 0, beamCount do
		local x = -hallHalfX + i * (hallHalfX * 2 / beamCount)
		part(parent, {
			Name = "Beam",
			Size = Vector3.new(1.2, 2, hallHalfZ * 2),
			CFrame = origin * CFrame.new(x, wallHeight - 1, 0),
			Color = PALETTE.Beam,
			Material = Enum.Material.Wood,
		})
	end
	for ix = -1, 1 do
		for iz = -1, 1, 2 do
			local lamp = part(parent, {
				Name = "Lamp",
				Size = Vector3.new(10, 0.4, 3),
				CFrame = origin * CFrame.new(ix * halfLength * 0.6, wallHeight - 2.4, iz * halfWidth * 0.45),
				Color = rgb(255, 244, 220),
				Material = Enum.Material.Neon,
				Shadow = false,
			})
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Angle = 120
			light.Range = 48
			light.Brightness = 1.6
			light.Color = rgb(255, 238, 214)
			light.Shadows = true
			light.Parent = lamp
		end
	end

	-- Stage with red curtains behind the +X goal: the classic Japanese gym.
	local stageX = hallHalfX - 4
	part(parent, {
		Name = "Stage",
		Size = Vector3.new(8, 4, hallHalfZ * 1.2),
		CFrame = origin * CFrame.new(stageX, 2, 0),
		Color = PALETTE.StageWood,
		Material = Enum.Material.WoodPlanks,
		Collide = true,
	})
	part(parent, {
		Name = "StageFront",
		Size = Vector3.new(0.4, 3.4, hallHalfZ * 1.2),
		CFrame = origin * CFrame.new(stageX - 4.1, 2, 0),
		Color = PALETTE.Beam,
	})
	for i = -4, 4 do
		part(parent, {
			Name = "Curtain",
			Size = Vector3.new(1, 18, hallHalfZ * 1.2 / 9 + 0.1),
			CFrame = origin * CFrame.new(stageX + 3.4 - (i % 2) * 0.3, 13, i * hallHalfZ * 1.2 / 9),
			Color = PALETTE.Curtain,
			Material = Enum.Material.Fabric,
		})
	end
	local banner = part(parent, {
		Name = "StageBanner",
		Size = Vector3.new(0.4, 3.4, hallHalfZ * 0.9),
		CFrame = origin * CFrame.new(stageX - 3, 24, 0),
		Color = rgb(250, 246, 236),
		Material = Enum.Material.Fabric,
	})
	surfaceText(
		banner,
		Enum.NormalId.Left,
		"天翔高校 ハンドボール部 · TENSHŌ HIGH HANDBALL CLUB",
		rgb(150, 18, 32),
		Enum.Font.GothamBlack,
		30
	)

	-- Scoreboard high on the opposite (-X) wall, facing the court.
	buildScoreboard(parent, origin * CFrame.new(-hallHalfX + 0.2, 22, 0) * CFrame.Angles(0, math.rad(-90), 0))

	-- Club pennants along the +Z wall (above head height, at the wall).
	local pennantColors = { rgb(240, 48, 66), rgb(255, 186, 30), rgb(40, 128, 255), rgb(70, 200, 140) }
	local pennantWords = { "全力", "一球入魂", "TENSHŌ", "飛翔" }
	for i = 1, 4 do
		local x = -halfLength * 0.75 + (i - 1) * (halfLength * 1.5 / 3)
		local p = part(parent, {
			Name = "Pennant",
			Size = Vector3.new(6, 9, 0.2),
			CFrame = origin * CFrame.new(x, 30, hallHalfZ - 0.2),
			Color = pennantColors[i],
			Material = Enum.Material.Fabric,
		})
		surfaceText(p, Enum.NormalId.Front, pennantWords[i], rgb(255, 255, 255), Enum.Font.GothamBlack, 30)
	end

	-- Bleachers along the +Z side (stepped wooden rows behind a safety rail).
	local rows = 4
	local depth = 3
	local rise = 1.6
	local startZ = halfWidth + 10
	for r = 0, rows - 1 do
		part(parent, {
			Name = "Bleacher",
			Size = Vector3.new(halfLength * 1.7, rise * (r + 1), depth),
			CFrame = origin * CFrame.new(0, rise * (r + 1) / 2, startZ + r * depth + depth / 2),
			Color = if r % 2 == 0 then PALETTE.Bleacher else PALETTE.BleacherDark,
			Material = Enum.Material.WoodPlanks,
			Collide = true,
		})
	end
	part(parent, {
		Name = "Rail",
		Size = Vector3.new(halfLength * 1.7, 0.3, 0.3),
		CFrame = origin * CFrame.new(0, 3, startZ - 0.6),
		Color = rgb(60, 60, 70),
		Material = Enum.Material.Metal,
	})
end

function MapService.buildCourt(modeId: string, origin: CFrame): Court
	local mode = Config.Modes[modeId]
	assert(mode, `MapService: unknown mode {modeId}`)
	local halfLength = mode.CourtLength / 2
	local halfWidth = mode.CourtWidth / 2

	local model = Instance.new("Model")
	model.Name = `Court_{modeId}`

	-- Floor: teal run-off base slightly below the playing surface.
	local hallHalfX = halfLength + 22
	local hallHalfZ = halfWidth + 22
	part(model, {
		Name = "RunOff",
		Size = Vector3.new(hallHalfX * 2, 2, hallHalfZ * 2),
		CFrame = origin * CFrame.new(0, -1.01, 0),
		Color = PALETTE.RunOff,
		Material = Enum.Material.SmoothPlastic,
		Collide = true,
	})
	local floor = part(model, {
		Name = "Floor",
		Size = Vector3.new(mode.CourtLength, 0.4, mode.CourtWidth),
		CFrame = origin * CFrame.new(0, -0.2, 0),
		Color = PALETTE.Court,
		Material = Enum.Material.WoodPlanks,
		Reflectance = 0.04,
		Collide = true,
	})
	model.PrimaryPart = floor

	local lines = Instance.new("Folder")
	lines.Name = "Lines"
	lines.Parent = model

	for _, side in { 1, -1 } do
		goalAreaFill(lines, origin, side, halfLength, mode.GoalAreaRadius)
		-- Run-off coloured strip beyond the goal line hides the outer half of the fill discs.
		part(lines, {
			Name = "EndStrip",
			Size = Vector3.new(mode.GoalAreaRadius + 1, 0.02, mode.GoalAreaRadius * 2 + Config.Goal.Width + 2),
			CFrame = origin * CFrame.new(side * (halfLength + (mode.GoalAreaRadius + 1) / 2), FILL_Y + 0.008, 0),
			Color = PALETTE.RunOff,
			Shadow = false,
		})
		zoneLine(lines, origin, side, halfLength, halfWidth, mode.GoalAreaRadius, nil)
		zoneLine(lines, origin, side, halfLength, halfWidth, mode.FreeThrowRadius, 1.1)
		-- 7 m mark (a short line parallel to the goal line).
		local penaltyX = side * (halfLength - mode.PenaltyDistance)
		floorLine(lines, origin, Vector3.new(penaltyX, 0, -1.4), Vector3.new(penaltyX, 0, 1.4))
		-- Goalkeeper restraining line ("4 m").
		local keeperX = side * (halfLength - mode.GoalAreaRadius * 4 / 6)
		floorLine(lines, origin, Vector3.new(keeperX, 0, -0.6), Vector3.new(keeperX, 0, 0.6))
		-- Goal line (wider between the posts, as on a real court).
		floorLine(
			lines,
			origin,
			Vector3.new(side * halfLength, 0, -halfWidth),
			Vector3.new(side * halfLength, 0, halfWidth)
		)
		buildGoal(model, origin, side, halfLength)
	end
	-- Side lines and centre line.
	floorLine(lines, origin, Vector3.new(-halfLength, 0, halfWidth), Vector3.new(halfLength, 0, halfWidth))
	floorLine(lines, origin, Vector3.new(-halfLength, 0, -halfWidth), Vector3.new(halfLength, 0, -halfWidth))
	floorLine(lines, origin, Vector3.new(0, 0, -halfWidth), Vector3.new(0, 0, halfWidth))
	-- Substitution marks on the bench side (-Z).
	for _, x in { -4.5, 4.5 } do
		floorLine(lines, origin, Vector3.new(x, 0, -halfWidth), Vector3.new(x, 0, -halfWidth - 1.2))
	end
	-- Centre circle for the throw-off.
	arcLine(lines, origin, Vector3.zero, 5, 0, math.pi * 2, halfWidth, nil)

	-- School emblem painted inside the centre circle.
	local emblem = part(lines, {
		Name = "Emblem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.02, 9, 9),
		CFrame = origin * CFrame.new(0, FILL_Y, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(150, 18, 32),
		Shadow = false,
	})
	local emblemTop = part(lines, {
		Name = "EmblemText",
		Size = Vector3.new(6.4, 0.02, 6.4),
		CFrame = origin * CFrame.new(0, FILL_Y + 0.01, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = rgb(150, 18, 32),
		Transparency = 1,
		Shadow = false,
	})
	surfaceText(emblemTop, Enum.NormalId.Top, "天翔", rgb(255, 214, 120), Enum.Font.GothamBlack, 30)
	emblem.Name = "Emblem"

	buildHall(model, origin, halfLength, halfWidth)

	-- Team benches on the -Z side, at the substitution area.
	local benchZ = -halfWidth - 7
	local bench = {
		Red = Vector3.new(-halfLength * 0.35, 0, benchZ),
		Blue = Vector3.new(halfLength * 0.35, 0, benchZ),
	}
	buildBench(model, origin, bench.Red, rgb(240, 48, 66))
	buildBench(model, origin, bench.Blue, rgb(40, 128, 255))
	-- Scorer's table between the benches.
	part(model, {
		Name = "ScorerTable",
		Size = Vector3.new(6, 2.6, 2),
		CFrame = origin * CFrame.new(0, 1.3, benchZ),
		Color = rgb(240, 236, 226),
		Collide = true,
	})

	model.Parent = folder()

	return {
		Model = model,
		CourtCFrame = origin,
		BenchPositions = {
			Red = origin:PointToWorldSpace(bench.Red + Vector3.new(0, 0, 3)),
			Blue = origin:PointToWorldSpace(bench.Blue + Vector3.new(0, 0, 3)),
		},
		Destroy = function()
			model:Destroy()
		end,
	}
end

function MapService.waitingSpawn(): CFrame
	return waitingCFrame + Vector3.new(0, 3, 0)
end

-- Club room where players wait between matches (Phase 1).
local function buildWaitingRoom()
	local room = Instance.new("Model")
	room.Name = "ClubRoom"
	local origin = waitingCFrame
	local w, d, h = 56, 40, 16
	part(room, {
		Name = "Floor",
		Size = Vector3.new(w, 1, d),
		CFrame = origin * CFrame.new(0, -0.5, 0),
		Color = PALETTE.Court,
		Material = Enum.Material.WoodPlanks,
		Collide = true,
	})
	part(room, {
		Name = "Ceiling",
		Size = Vector3.new(w, 1, d),
		CFrame = origin * CFrame.new(0, h + 0.5, 0),
		Color = PALETTE.Ceiling,
		Collide = true,
	})
	local walls: { { At: CFrame, Size: Vector3 } } = {
		{ At = CFrame.new(0, h / 2, d / 2 + 0.5), Size = Vector3.new(w + 2, h, 1) },
		{ At = CFrame.new(0, h / 2, -d / 2 - 0.5), Size = Vector3.new(w + 2, h, 1) },
		{ At = CFrame.new(w / 2 + 0.5, h / 2, 0), Size = Vector3.new(1, h, d) },
		{ At = CFrame.new(-w / 2 - 0.5, h / 2, 0), Size = Vector3.new(1, h, d) },
	}
	for _, entry in walls do
		part(room, {
			Name = "Wall",
			Size = entry.Size,
			CFrame = origin * entry.At,
			Color = PALETTE.WallPlaster,
			Material = Enum.Material.Plaster,
			Collide = true,
		})
	end
	-- Lockers along the back wall, alternating team colours.
	for i = 0, 9 do
		part(room, {
			Name = "Locker",
			Size = Vector3.new(3.6, 9, 2.4),
			CFrame = origin * CFrame.new(-w / 2 + 5 + i * 4.2, 4.5, -d / 2 + 1.3),
			Color = if i % 2 == 0 then rgb(176, 44, 56) else rgb(40, 96, 190),
			Material = Enum.Material.Metal,
			Collide = true,
		})
	end
	-- Whiteboard naming the test mode.
	local board = part(room, {
		Name = "Whiteboard",
		Size = Vector3.new(18, 7, 0.3),
		CFrame = origin * CFrame.new(0, 7, d / 2 - 0.2),
		Color = rgb(250, 250, 250),
		Collide = true,
	})
	surfaceText(
		board,
		Enum.NormalId.Front,
		"天翔 HANDBALL — MODE TEST PHASE 1",
		rgb(30, 40, 90),
		Enum.Font.GothamBlack,
		30
	)
	part(room, {
		Name = "Bench",
		Size = Vector3.new(16, 1.2, 2.4),
		CFrame = origin * CFrame.new(0, 0.6, -d / 2 + 5),
		Color = PALETTE.Bench,
		Collide = true,
	})
	for _, x in { -14, 14 } do
		local lamp = part(room, {
			Name = "Lamp",
			Size = Vector3.new(8, 0.4, 2),
			CFrame = origin * CFrame.new(x, h - 0.4, 0),
			Color = rgb(255, 244, 220),
			Material = Enum.Material.Neon,
			Shadow = false,
		})
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 24
		light.Angle = 120
		light.Brightness = 1.4
		light.Parent = lamp
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "WaitingSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.2, 10)
	spawn.CFrame = origin * CFrame.new(0, 0.1, 6)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = room
	room.Parent = folder()
end

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.6
	Lighting.Ambient = rgb(118, 104, 92)
	Lighting.OutdoorAmbient = rgb(150, 140, 128)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	correction.Saturation = 0.08
	correction.Contrast = 0.06
	correction.TintColor = rgb(255, 248, 238)
	correction.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 20
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
end

function MapService.init()
	setupLighting()
	buildWaitingRoom()
end

return MapService
