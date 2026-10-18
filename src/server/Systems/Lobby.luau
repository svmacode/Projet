--!strict
-- Le lobby : la cour du lycée Seiryō (cerisiers, portail torii, bâtiment,
-- terrain d'échauffement, panneau du tutoriel). Construit par code au
-- démarrage d'un serveur lobby. Ajoute aussi les étiquettes au-dessus des
-- joueurs (niveau, tag de clan) et l'aperçu des cosmétiques équipés.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Tutorial = require(ReplicatedStorage.Shared.Data.Tutorial)
local Clan = require(script.Parent.Clan)
local Outfit = require(script.Parent.Parent.Match.Outfit)
local PlayerData = require(script.Parent.PlayerData)
local ServerRole = require(script.Parent.Parent.Lib.ServerRole)

local Lobby = {}

local INK = Color3.fromRGB(16, 16, 22)
local PAPER = Color3.fromRGB(255, 250, 238)
local RED = Color3.fromRGB(226, 32, 52)

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function outline(model: Instance)
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = INK
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
end

local function sakura(parent: Instance, position: Vector3, scale: number)
	local tree = Instance.new("Model")
	tree.Name = "Cerisier"
	local trunk = part(tree, "Tronc", Vector3.new(1.6, 9, 1.6) * scale, CFrame.new(position + Vector3.new(0, 4.5 * scale, 0)), Color3.fromRGB(110, 70, 60), Enum.Material.Wood)
	trunk.CanCollide = true
	local pinks = { Color3.fromRGB(255, 183, 213), Color3.fromRGB(255, 160, 200), Color3.fromRGB(255, 205, 225) }
	for i = 1, 6 do
		local angle = i * math.pi / 3
		local offset = Vector3.new(math.cos(angle) * 3.2, 9.5 + (i % 2) * 1.6, math.sin(angle) * 3.2) * scale
		local blossom = part(tree, "Fleurs", Vector3.new(6.5, 6.5, 6.5) * scale, CFrame.new(position + offset), pinks[i % 3 + 1])
		blossom.Shape = Enum.PartType.Ball
		blossom.CanCollide = false
	end
	local top = part(tree, "Fleurs", Vector3.new(7, 7, 7) * scale, CFrame.new(position + Vector3.new(0, 12, 0) * scale), pinks[1])
	top.Shape = Enum.PartType.Ball
	top.CanCollide = false
	local petals = Instance.new("ParticleEmitter")
	petals.Color = ColorSequence.new(Color3.fromRGB(255, 190, 215))
	petals.Rate = 3
	petals.Lifetime = NumberRange.new(5, 8)
	petals.Speed = NumberRange.new(1, 2)
	petals.Acceleration = Vector3.new(1, -1.2, 0.5)
	petals.Rotation = NumberRange.new(0, 360)
	petals.RotSpeed = NumberRange.new(-90, 90)
	petals.Size = NumberSequence.new(0.35)
	petals.SpreadAngle = Vector2.new(180, 180)
	petals.Parent = top
	outline(tree)
	tree.Parent = parent
end

local function surfaceGui(target: BasePart, face: Enum.NormalId, ppu: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu
	gui.LightInfluence = 0
	gui.Parent = target
	return gui
end

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, color: Color3, font: Enum.Font, strokeColor: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = position
	l.Size = size
	l.Text = text
	l.TextScaled = true
	l.Font = font
	l.TextColor3 = color
	l.TextStrokeColor3 = strokeColor or INK
	l.TextStrokeTransparency = if strokeColor then 0 else 1
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function buildTutorialBoard(parent: Instance, cframe: CFrame)
	local board = part(parent, "PanneauTutoriel", Vector3.new(22, 14, 0.8), cframe, PAPER)
	local frame = part(parent, "CadrePanneau", Vector3.new(23, 15, 0.6), cframe * CFrame.new(0, 0, 0.2), INK)
	frame.CanCollide = false
	for _, x in { -9, 9 } do
		part(parent, "Pied", Vector3.new(0.8, 8, 0.8), cframe * CFrame.new(x, -10.5, 0.3), INK)
	end
	local gui = surfaceGui(board, Enum.NormalId.Front, 30)
	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = PAPER
	background.Parent = gui
	local header = Instance.new("Frame")
	header.Size = UDim2.fromScale(1, 0.16)
	header.BackgroundColor3 = RED
	header.Parent = background
	label(header, "TUTORIEL  チュートリアル", UDim2.fromScale(0.02, 0.05), UDim2.fromScale(0.96, 0.9), PAPER, Enum.Font.Bangers, INK)
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.04, 0.2)
	list.Size = UDim2.fromScale(0.92, 0.76)
	list.Parent = background
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.015, 0)
	layout.Parent = list
	for index = 2, #Tutorial do
		local step = Tutorial[index]
		local row = label(list, `{index - 1}. {step.Title}`, UDim2.new(), UDim2.fromScale(1, 0.12), INK, Enum.Font.Bangers)
		row.TextXAlignment = Enum.TextXAlignment.Left
	end
	local hint = label(list, "Ouvre le menu TUTORIEL pour tous les détails !", UDim2.new(), UDim2.fromScale(1, 0.1), RED, Enum.Font.GothamBold)
	hint.TextXAlignment = Enum.TextXAlignment.Left
end

local function build(): Model
	local world = Instance.new("Model")
	world.Name = "LyceeSeiryo"

	-- Sol : pelouse + cour pavée.
	part(world, "Pelouse", Vector3.new(420, 4, 420), CFrame.new(0, -2, 0), Color3.fromRGB(110, 200, 110), Enum.Material.Grass)
	part(world, "Cour", Vector3.new(120, 0.4, 140), CFrame.new(0, 0.2, -10), Color3.fromRGB(226, 214, 196), Enum.Material.Pavement)
	part(world, "Allee", Vector3.new(24, 0.42, 120), CFrame.new(0, 0.21, 110), Color3.fromRGB(205, 190, 170), Enum.Material.Pavement)

	-- Point d'apparition.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Apparition"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 0.6, 14)
	spawn.CFrame = CFrame.new(0, 0.5, 40)
	spawn.Color = RED
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = world

	-- Bâtiment du lycée.
	local building = Instance.new("Model")
	building.Name = "Batiment"
	part(building, "Facade", Vector3.new(130, 46, 24), CFrame.new(0, 23, -92), Color3.fromRGB(245, 240, 228))
	part(building, "Toit", Vector3.new(136, 3, 30), CFrame.new(0, 47.5, -92), Color3.fromRGB(60, 80, 120))
	part(building, "Socle", Vector3.new(132, 4, 26), CFrame.new(0, 2, -92), Color3.fromRGB(150, 150, 160))
	for floor = 0, 2 do
		for column = -5, 5 do
			if not (floor == 0 and math.abs(column) <= 1) then
				local window = part(
					building,
					"Fenetre",
					Vector3.new(7, 7, 0.5),
					CFrame.new(column * 11, 10 + floor * 12, -79.9),
					Color3.fromRGB(150, 210, 255),
					Enum.Material.Glass
				)
				window.Reflectance = 0.15
				part(building, "Cadre", Vector3.new(7.6, 0.5, 0.6), CFrame.new(column * 11, 6.3 + floor * 12, -79.8), INK)
			end
		end
	end
	part(building, "Porte", Vector3.new(16, 12, 0.6), CFrame.new(0, 8, -79.8), Color3.fromRGB(120, 80, 60), Enum.Material.Wood)
	-- Horloge.
	local clock = part(building, "Horloge", Vector3.new(0.6, 9, 9), CFrame.new(0, 38, -79.6) * CFrame.Angles(0, math.pi / 2, 0), PAPER)
	clock.Shape = Enum.PartType.Cylinder
	-- Enseigne géante.
	local sign = part(building, "Enseigne", Vector3.new(70, 12, 1), CFrame.new(0, 58, -86), INK)
	local signGui = surfaceGui(sign, Enum.NormalId.Front, 12)
	local signBg = Instance.new("Frame")
	signBg.Size = UDim2.fromScale(1, 1)
	signBg.BackgroundColor3 = INK
	signBg.Parent = signGui
	label(signBg, "HANDBALL LEGENDS", UDim2.fromScale(0.02, 0.02), UDim2.fromScale(0.96, 0.7), Color3.fromRGB(255, 214, 40), Enum.Font.Bangers, RED)
	label(signBg, "ハンドボール・レジェンズ  ✦  LYCÉE SEIRYŌ", UDim2.fromScale(0.05, 0.72), UDim2.fromScale(0.9, 0.24), PAPER, Enum.Font.GothamBold)
	outline(building)
	building.Parent = world

	-- Portail torii à l'entrée.
	local torii = Instance.new("Model")
	torii.Name = "Torii"
	for _, x in { -11, 11 } do
		part(torii, "Pilier", Vector3.new(2.4, 26, 2.4), CFrame.new(x, 13, 150), RED)
		part(torii, "Base", Vector3.new(3.4, 1.6, 3.4), CFrame.new(x, 0.8, 150), INK)
	end
	part(torii, "Kasagi", Vector3.new(34, 2.4, 3.4), CFrame.new(0, 27, 150), INK)
	part(torii, "Shimaki", Vector3.new(30, 1.4, 2.8), CFrame.new(0, 25.2, 150), RED)
	part(torii, "Nuki", Vector3.new(26, 1.4, 1.8), CFrame.new(0, 20, 150), RED)
	outline(torii)
	torii.Parent = world

	-- Terrain d'échauffement avec un but.
	local warmup = Instance.new("Model")
	warmup.Name = "Echauffement"
	part(warmup, "Sol", Vector3.new(50, 0.5, 30), CFrame.new(-40, 0.45, 0), Color3.fromRGB(214, 150, 84), Enum.Material.WoodPlanks)
	for _, z in { -15, 15 } do
		part(warmup, "Ligne", Vector3.new(50, 0.52, 0.3), CFrame.new(-40, 0.46, z), PAPER)
	end
	for i = 0, 4 do
		local color = if i % 2 == 0 then RED else PAPER
		part(warmup, "Poteau", Vector3.new(0.5, 1.3, 0.5), CFrame.new(-64, 0.7 + i * 1.3, -5), color)
		part(warmup, "Poteau", Vector3.new(0.5, 1.3, 0.5), CFrame.new(-64, 0.7 + i * 1.3, 5), color)
	end
	part(warmup, "Barre", Vector3.new(0.5, 0.5, 10.5), CFrame.new(-64, 7.2, 0), RED)
	outline(warmup)
	warmup.Parent = world

	-- Cerisiers.
	local trees = {
		Vector3.new(-50, 0, 60),
		Vector3.new(50, 0, 60),
		Vector3.new(-70, 0, 20),
		Vector3.new(70, 0, 20),
		Vector3.new(-25, 0, 130),
		Vector3.new(25, 0, 130),
		Vector3.new(-80, 0, -50),
		Vector3.new(80, 0, -50),
		Vector3.new(60, 0, 110),
		Vector3.new(-60, 0, 110),
	}
	for index, position in trees do
		sakura(world, position, 1 + (index % 3) * 0.15)
	end

	-- Bancs et lanternes.
	for _, x in { -30, 30 } do
		part(world, "Banc", Vector3.new(10, 1, 3), CFrame.new(x, 1.5, 60), Color3.fromRGB(150, 100, 60), Enum.Material.Wood)
		for _, z in { 70, 95 } do
			local lantern = part(world, "Lanterne", Vector3.new(2, 3, 2), CFrame.new(x * 0.6, 6, z), Color3.fromRGB(255, 220, 140), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 200, 120)
			light.Range = 16
			light.Parent = lantern
			part(world, "Poteau", Vector3.new(0.6, 5, 0.6), CFrame.new(x * 0.6, 2.5, z), INK)
		end
	end

	buildTutorialBoard(world, CFrame.new(30, 12, 10) * CFrame.Angles(0, math.rad(-35), 0))

	world.Parent = Workspace
	return world
end

-- Étiquette au-dessus de la tête (niveau + clan).
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
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, 2.8, 0)
	gui.MaxDistance = 90
	gui.AlwaysOnTop = false
	gui.Parent = head
	local tag = Clan.tagOf(player)
	local name = label(gui, (if tag then `[{tag}] ` else "") .. player.DisplayName, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.6), PAPER, Enum.Font.Bangers, INK)
	name.TextStrokeTransparency = 0
	local level = label(gui, `NIV. {if profile then profile.Level else 1}`, UDim2.fromScale(0.3, 0.6), UDim2.fromScale(0.4, 0.4), Color3.fromRGB(255, 214, 40), Enum.Font.Bangers, INK)
	level.TextStrokeTransparency = 0
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function dressInLobby(player: Player, character: Model)
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
	local world = build()
	-- Le client utilise ce point de vue pour le menu de départ.
	Workspace:SetAttribute("MenuCamera", CFrame.lookAt(Vector3.new(38, 16, 120), Vector3.new(0, 26, -60)))
	local _ = world
end

function Lobby.start()
	if ServerRole.Role ~= "Lobby" then
		return
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.3)
			dressInLobby(player, character)
		end)
		if player.Character then
			task.spawn(dressInLobby, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	-- Rafraîchir l'aperçu quand l'équipement ou le niveau change.
	local lastEquipped: { [Player]: string } = {}
	PlayerData.Changed:Connect(function(player, profile)
		local signature = `{profile.Equipped.Mask}|{profile.Equipped.Gloves}|{profile.Equipped.Shoes}|{profile.Level}|{profile.ClanId}`
		if lastEquipped[player] == signature then
			return
		end
		lastEquipped[player] = signature
		local character = player.Character
		if character and not character:GetAttribute("MatchId") then
			task.spawn(dressInLobby, player, character)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastEquipped[player] = nil
	end)
end

return Lobby
