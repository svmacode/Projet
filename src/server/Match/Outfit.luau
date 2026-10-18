--!strict
-- Habille un personnage pour le match : maillot aux couleurs de l'équipe
-- (rouge ou bleu, quel que soit le motif de la tenue), numéro dans le dos,
-- cosmétiques équipés et contour noir façon manga.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)

export type OutfitOptions = {
	Team: string,
	KitId: string,
	Number: number,
	Equipped: { [string]: string },
	ClanTag: string?,
	Highlight: boolean?,
}

local Outfit = {}

local OUTFIT_FOLDER = "TenueMatch"

-- Noms des membres en R6, avec les équivalents R15 de repli.
local LIMBS = {
	Torso = { "Torso", "UpperTorso" },
	Head = { "Head" },
	LeftArm = { "Left Arm", "LeftLowerArm" },
	RightArm = { "Right Arm", "RightLowerArm" },
	LeftLeg = { "Left Leg", "LeftLowerLeg" },
	RightLeg = { "Right Leg", "RightLowerLeg" },
}

function Outfit.limb(character: Model, key: string): BasePart?
	for _, name in LIMBS[key] or { key } do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function weldTo(part: BasePart, target: BasePart, offset: CFrame)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = target.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = target
	weld.Part1 = part
	weld.Parent = part
end

local function addPart(folder: Instance, target: BasePart, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: string?): Part
	local part = Instance.new("Part")
	part.Name = "Habit"
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	end
	weldTo(part, target, offset)
	part.Parent = folder
	return part
end

local function addWedge(folder: Instance, target: BasePart, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
	local wedge = Instance.new("WedgePart")
	wedge.Name = "Habit"
	wedge.Size = size
	wedge.Color = color
	wedge.Material = material or Enum.Material.SmoothPlastic
	weldTo(wedge, target, offset)
	wedge.Parent = folder
end

-- Retire vêtements et accessoires encombrants (on garde cheveux et chapeaux).
local function stripAvatar(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("Accessory") then
			local accessoryType = child.AccessoryType
			if accessoryType ~= Enum.AccessoryType.Hair and accessoryType ~= Enum.AccessoryType.Hat then
				child:Destroy()
			end
		end
	end
	local old = character:FindFirstChild(OUTFIT_FOLDER)
	if old then
		old:Destroy()
	end
end

local function jerseyText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, stroke: Color3, scale: UDim2, position: UDim2)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Numero"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.4
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = scale
	label.Position = position
	label.Text = text
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = stroke
	label.TextStrokeTransparency = 0
	label.Parent = gui
end

local function applyKit(character: Model, folder: Folder, options: OutfitOptions)
	local team = (Progression.Teams :: any)[options.Team] or Progression.Teams.Rouge
	local kit = Progression.getKit(options.KitId) or Progression.Kits[1]
	local head = Outfit.limb(character, "Head")
	local torso = Outfit.limb(character, "Torso")
	local skin = if head then head.Color else Color3.fromRGB(234, 184, 146)

	local shortsColor = if kit.Shorts == "White"
		then Color3.fromRGB(245, 245, 240)
		elseif kit.Shorts == "Team" then team.Primary
		else team.Dark

	local colors = character:FindFirstChildOfClass("BodyColors")
	if not colors then
		local created = Instance.new("BodyColors")
		created.Parent = character
		colors = created
	end
	assert(colors, "BodyColors")
	colors.TorsoColor3 = team.Primary
	colors.LeftArmColor3 = skin
	colors.RightArmColor3 = skin
	colors.LeftLegColor3 = skin
	colors.RightLegColor3 = skin
	colors.HeadColor3 = skin

	if not torso then
		return
	end

	-- Manches courtes et short.
	for _, key in { "LeftArm", "RightArm" } do
		local arm = Outfit.limb(character, key)
		if arm then
			addPart(folder, arm, Vector3.new(1.06, 0.7, 1.06), CFrame.new(0, 0.66, 0), team.Primary)
			addPart(folder, arm, Vector3.new(1.08, 0.1, 1.08), CFrame.new(0, 0.3, 0), kit.Trim)
		end
	end
	for _, key in { "LeftLeg", "RightLeg" } do
		local leg = Outfit.limb(character, key)
		if leg then
			addPart(folder, leg, Vector3.new(1.06, 0.9, 1.06), CFrame.new(0, 0.56, 0), shortsColor)
			addPart(folder, leg, Vector3.new(1.08, 0.5, 1.08), CFrame.new(0, -0.62, 0), Color3.fromRGB(245, 245, 240))
		end
	end

	-- Col.
	addPart(folder, torso, Vector3.new(1.2, 0.14, 0.9), CFrame.new(0, 0.95, 0), kit.Trim)

	-- Motif selon la tenue (la couleur de base reste celle de l'équipe).
	local accent = kit.Accent
	local pattern = kit.Pattern
	if pattern == "Plain" then
		addPart(folder, torso, Vector3.new(0.12, 2.02, 1.02), CFrame.new(0.95, 0, 0), accent)
		addPart(folder, torso, Vector3.new(0.12, 2.02, 1.02), CFrame.new(-0.95, 0, 0), accent)
	elseif pattern == "Bolt" then
		addPart(folder, torso, Vector3.new(0.35, 1.3, 0.05), CFrame.new(0.2, 0.3, -0.52) * CFrame.Angles(0, 0, 0.6), accent, Enum.Material.Neon)
		addPart(folder, torso, Vector3.new(0.35, 1.1, 0.05), CFrame.new(-0.2, -0.45, -0.52) * CFrame.Angles(0, 0, 0.6), accent, Enum.Material.Neon)
		addPart(folder, torso, Vector3.new(2.02, 0.12, 1.02), CFrame.new(0, -0.9, 0), kit.Trim)
	elseif pattern == "Scales" then
		for row = 0, 2 do
			for col = -1, 1 do
				addWedge(
					folder,
					torso,
					Vector3.new(0.05, 0.34, 0.4),
					CFrame.new(col * 0.5, 0.45 - row * 0.45, -0.53) * CFrame.Angles(0, math.pi / 2, 0),
					accent,
					Enum.Material.Metal
				)
			end
		end
	elseif pattern == "Armor" then
		addPart(folder, torso, Vector3.new(0.9, 0.35, 1.2), CFrame.new(1.35, 0.85, 0) * CFrame.Angles(0, 0, -0.25), accent, Enum.Material.Metal)
		addPart(folder, torso, Vector3.new(0.9, 0.35, 1.2), CFrame.new(-1.35, 0.85, 0) * CFrame.Angles(0, 0, 0.25), accent, Enum.Material.Metal)
		addPart(folder, torso, Vector3.new(2.04, 0.16, 1.04), CFrame.new(0, -0.6, 0), kit.Trim, Enum.Material.Metal)
	elseif pattern == "Stars" then
		for _, offset in { Vector3.new(-0.5, 0.45, -0.53), Vector3.new(0.45, -0.1, -0.53), Vector3.new(-0.3, -0.6, -0.53) } do
			addPart(folder, torso, Vector3.new(0.3, 0.3, 0.3), CFrame.new(offset), kit.Trim, Enum.Material.Neon, "Ball")
		end
		addPart(folder, torso, Vector3.new(2.02, 0.1, 1.02), CFrame.new(0, -0.95, 0), accent)
	elseif pattern == "Aura" then
		addPart(folder, torso, Vector3.new(2.04, 0.1, 1.04), CFrame.new(0, 0.9, 0), accent, Enum.Material.Neon)
		addPart(folder, torso, Vector3.new(2.04, 0.1, 1.04), CFrame.new(0, -0.95, 0), accent, Enum.Material.Neon)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(accent)
		emitter.LightEmission = 1
		emitter.Rate = 12
		emitter.Lifetime = NumberRange.new(0.6, 1)
		emitter.Speed = NumberRange.new(1, 3)
		emitter.Size = NumberSequence.new(0.25, 0)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Parent = torso
		emitter.Name = "AuraTenue"
		emitter:SetAttribute("Outfit", true)
	end

	-- Numéro dans le dos et sur le devant.
	jerseyText(torso, Enum.NormalId.Back, tostring(options.Number), Color3.fromRGB(255, 255, 255), Color3.fromRGB(20, 20, 24), UDim2.fromScale(0.8, 0.7), UDim2.fromScale(0.1, 0.1))
	jerseyText(torso, Enum.NormalId.Front, tostring(options.Number), kit.Trim, Color3.fromRGB(20, 20, 24), UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.62, 0.08))
	if options.ClanTag and options.ClanTag ~= "" then
		jerseyText(torso, Enum.NormalId.Front, `[{options.ClanTag}]`, Color3.fromRGB(255, 255, 255), Color3.fromRGB(20, 20, 24), UDim2.fromScale(0.5, 0.2), UDim2.fromScale(0.05, 0.75))
	end
end

local function applyCosmetic(character: Model, folder: Folder, itemId: string)
	local item = Cosmetics.get(itemId)
	if not item then
		return
	end
	local targets: { { part: BasePart, mirror: boolean } } = {}
	if item.Slot == "Mask" then
		local head = Outfit.limb(character, "Head")
		if head then
			table.insert(targets, { part = head, mirror = false })
		end
	else
		local keys: { string } = if item.Slot == "Gloves" then { "RightArm", "LeftArm" } else { "RightLeg", "LeftLeg" }
		for index, key in keys do
			local limb = Outfit.limb(character, key)
			if limb then
				table.insert(targets, { part = limb, mirror = index == 2 })
			end
		end
	end
	for _, target in targets do
		-- Mise à l'échelle pour les avatars dont les membres ne font pas 1×2×1.
		local reference = if item.Slot == "Mask" then Vector3.new(2, 1, 1) else Vector3.new(1, 2, 1)
		local scale = target.part.Size / reference
		for _, spec in item.Parts do
			local offset = spec.Offset
			local position = offset.Position * scale
			if target.mirror then
				local rx, ry, rz = offset:ToOrientation()
				offset = CFrame.new(-position.X, position.Y, position.Z) * CFrame.fromOrientation(rx, -ry, -rz)
			else
				offset = CFrame.new(position) * offset.Rotation
			end
			local size = spec.Size * Vector3.new(math.max(scale.X, 0.5), math.max(scale.Y, 0.5), math.max(scale.Z, 0.5))
			local part: BasePart
			if spec.Shape == "Wedge" then
				local wedge = Instance.new("WedgePart")
				wedge.Name = "Cosmetique"
				wedge.Size = size
				wedge.Color = spec.Color
				wedge.Material = spec.Material or Enum.Material.SmoothPlastic
				weldTo(wedge, target.part, offset)
				wedge.Parent = folder
				part = wedge
			else
				part = addPart(folder, target.part, size, offset, spec.Color, spec.Material, spec.Shape)
				part.Name = "Cosmetique"
			end
			if spec.Light then
				local light = Instance.new("PointLight")
				light.Color = spec.Color
				light.Range = spec.Light
				light.Brightness = 1.4
				light.Parent = part
			end
		end
		if item.Sparkles then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Color = ColorSequence.new(item.Sparkles)
			emitter.LightEmission = 1
			emitter.Rate = 10
			emitter.Lifetime = NumberRange.new(0.5, 0.9)
			emitter.Speed = NumberRange.new(0.5, 2)
			emitter.Size = NumberSequence.new(0.2, 0)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Parent = target.part
			emitter:SetAttribute("Outfit", true)
		end
	end
end

function Outfit.apply(character: Model, options: OutfitOptions)
	stripAvatar(character)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("ParticleEmitter") and descendant:GetAttribute("Outfit") then
			descendant:Destroy()
		elseif descendant:IsA("SurfaceGui") and descendant.Name == "Numero" then
			descendant:Destroy()
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = OUTFIT_FOLDER
	folder.Parent = character
	applyKit(character, folder, options)
	for _, slot in Cosmetics.SlotOrder do
		local itemId = options.Equipped[slot]
		if itemId then
			applyCosmetic(character, folder, itemId)
		end
	end
	if options.Highlight ~= false then
		local highlight = character:FindFirstChild("ContourManga")
		if not highlight then
			local h = Instance.new("Highlight")
			h.Name = "ContourManga"
			h.FillTransparency = 1
			h.OutlineColor = Color3.fromRGB(12, 12, 16)
			h.OutlineTransparency = 0
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = character
		end
	end
end

-- Aperçu pour le lobby : mêmes cosmétiques, sans maillot d'équipe.
function Outfit.applyCosmeticsOnly(character: Model, equipped: { [string]: string })
	local old = character:FindFirstChild(OUTFIT_FOLDER)
	if old then
		old:Destroy()
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("ParticleEmitter") and descendant:GetAttribute("Outfit") then
			descendant:Destroy()
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = OUTFIT_FOLDER
	folder.Parent = character
	for _, slot in Cosmetics.SlotOrder do
		local itemId = equipped[slot]
		if itemId then
			applyCosmetic(character, folder, itemId)
		end
	end
end

return Outfit
