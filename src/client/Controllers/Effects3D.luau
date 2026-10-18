--!strict
-- Effets visuels 3D du match : ondes d'impact, poussière, éclats, auras de
-- pouvoir, explosion au but, tremblement et zoom de caméra.
-- Palette d'animé : couleurs d'équipe vives, éclats jaunes, roses et cyan.
-- Textures de particules : uniquement celles intégrées à Roblox.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local BallRenderer = require(script.Parent.BallRenderer)
local MatchInput = require(script.Parent.MatchInput)
local State = require(script.Parent.State)

local LocalPlayer = Players.LocalPlayer

local Effects3D = {}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local TEAM_COLORS = {
	Rouge = Color3.fromRGB(255, 52, 76),
	Bleu = Color3.fromRGB(40, 140, 255),
}

local YELLOW = Color3.fromRGB(255, 220, 40)
local PINK = Color3.fromRGB(255, 60, 160)
local CYAN = Color3.fromRGB(0, 220, 255)
local VIOLET = Color3.fromRGB(160, 100, 255)
local CONFETTI = { YELLOW, PINK, CYAN, VIOLET, Color3.fromRGB(140, 255, 90) }

local folder: Folder
local shakeStrength = 0
local shakeUntil = 0
local baseFov = 70

-- Primitives --------------------------------------------------------------------------------------

local function anchor(position: Vector3): (Part, Attachment)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.CFrame = CFrame.new(position)
	part.Parent = folder
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	Debris:AddItem(part, 4)
	return part, attachment
end

local function burst(position: Vector3, color: Color3, count: number, options: { [string]: any }?)
	local o: { [string]: any } = options or {}
	local _, attachment = anchor(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = o.Texture or SMOKE
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = o.Light or 0
	emitter.Size = o.Size
		or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = o.Lifetime or NumberRange.new(0.4, 0.8)
	emitter.Speed = o.Speed or NumberRange.new(4, 10)
	emitter.SpreadAngle = o.Spread or Vector2.new(180, 180)
	emitter.Acceleration = o.Acceleration or Vector3.new(0, 2, 0)
	emitter.Drag = o.Drag or 4
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-120, 120)
	emitter.EmissionDirection = o.Direction or Enum.NormalId.Top
	emitter.Enabled = false
	emitter.Parent = attachment
	emitter:Emit(count)
end

local function sparkles(position: Vector3, color: Color3, count: number, speed: number?, size: number?)
	burst(position, color, count, {
		Texture = SPARKLE,
		Light = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.35, 0.7),
		Speed = NumberRange.new((speed or 14) * 0.5, speed or 14),
		Acceleration = Vector3.new(0, -10, 0),
		Drag = 3,
	})
end

-- Onde circulaire qui s'étend puis disparaît.
local function ring(cframe: CFrame, color: Color3, fromSize: number, toSize: number, duration: number)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.15
	part.Size = Vector3.new(0.12, fromSize, fromSize)
	part.CFrame = cframe
	part.Parent = folder
	TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.04, toSize, toSize),
		Transparency = 1,
	}):Play()
	Debris:AddItem(part, duration + 0.1)
end

local function flash(position: Vector3, color: Color3, size: number, duration: number)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.1
	part.Size = Vector3.one * size * 0.3
	part.CFrame = CFrame.new(position)
	part.Parent = folder
	TweenService
		:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quint), { Size = Vector3.one * size, Transparency = 1 })
		:Play()
	Debris:AddItem(part, duration + 0.1)
end

local function groundRing(position: Vector3, color: Color3, size: number)
	ring(CFrame.new(position.X, position.Y - 2.9, position.Z) * CFrame.Angles(0, 0, math.pi / 2), color, 1, size, 0.45)
end

local function rootOf(model: Model?): BasePart?
	if not model then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Caméra ------------------------------------------------------------------------------------------

function Effects3D.shake(strength: number, duration: number)
	shakeStrength = math.max(shakeStrength, strength)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

function Effects3D.punch(amount: number, duration: number)
	local camera = Workspace.CurrentCamera :: Camera
	camera.FieldOfView = baseFov + amount
	TweenService:Create(camera, TweenInfo.new(duration, Enum.EasingStyle.Quint), { FieldOfView = baseFov }):Play()
end

local function isMine(model: Model?): boolean
	return model ~= nil and model == LocalPlayer.Character
end

-- Événements --------------------------------------------------------------------------------------

local function onShot(data: any)
	local root = rootOf(data.Model)
	if not root then
		return
	end
	local hand = (root.CFrame * CFrame.new(1.35, 0.6, -1.4)).Position
	local strong = data.Charge > 0.75 or data.Powered
	local color = if data.Fire
		then Color3.fromRGB(255, 130, 30)
		elseif data.Powered then CYAN
		else TEAM_COLORS[data.Team] or YELLOW
	ring(
		CFrame.lookAt(hand, hand + root.CFrame.LookVector) * CFrame.Angles(0, math.pi / 2, 0),
		color,
		1.5,
		if strong then 9 else 5,
		0.35
	)
	if strong then
		task.delay(
			0.06,
			ring,
			CFrame.lookAt(hand, hand + root.CFrame.LookVector) * CFrame.Angles(0, math.pi / 2, 0),
			color,
			1,
			6,
			0.4
		)
	end
	burst(hand, Color3.fromRGB(255, 240, 250), if strong then 10 else 5, { Speed = NumberRange.new(6, 14) })
	sparkles(hand, if strong then YELLOW else color, if strong then 24 else 10, if strong then 22 else 14)
	if strong then
		sparkles(hand, PINK, 12, 18, 0.4)
	end
	if isMine(data.Model) then
		Effects3D.punch(if strong then -8 else -4, 0.35)
		Effects3D.shake(if strong then 0.5 else 0.2, 0.2)
	end
end

local function onDash(model: Model?)
	local root = rootOf(model)
	if not root then
		return
	end
	local feet = root.Position - Vector3.new(0, 2.8, 0)
	burst(
		feet,
		Color3.fromRGB(220, 200, 255),
		8,
		{ Speed = NumberRange.new(2, 6), Spread = Vector2.new(70, 70), Size = NumberSequence.new(0.6, 2) }
	)
	groundRing(root.Position, CYAN, 7)
	sparkles(feet, CYAN, 8, 10, 0.35)
	if isMine(model) then
		Effects3D.punch(7, 0.35)
	end
end

local function onContact(data: any)
	local victim = rootOf(data.To)
	if not victim then
		return
	end
	flash(victim.Position + Vector3.new(0, 0.6, 0), YELLOW, 4, 0.25)
	burst(victim.Position, Color3.fromRGB(255, 230, 245), 6, { Speed = NumberRange.new(5, 10) })
	sparkles(victim.Position + Vector3.new(0, 1, 0), YELLOW, 14, 16, 0.6)
	sparkles(victim.Position + Vector3.new(0, 1, 0), PINK, 8, 12, 0.45)
	if isMine(data.To) or isMine(data.From) then
		Effects3D.shake(0.6, 0.25)
	end
end

local function onGoal(data: any)
	local color = TEAM_COLORS[data.Team] or Color3.new(1, 1, 1)
	local position = BallRenderer.position()
	flash(position, Color3.fromRGB(255, 255, 255), 10, 0.35)
	for i = 0, 2 do
		task.delay(
			i * 0.08,
			ring,
			CFrame.new(position) * CFrame.Angles(0, (i - 1) * 0.6, math.pi / 2 + (i - 1) * 0.4),
			color,
			2,
			18 + i * 6,
			0.7
		)
	end
	burst(position, color, 90, {
		Texture = SPARKLE,
		Light = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(18, 40),
		Acceleration = Vector3.new(0, -30, 0),
		Drag = 2,
	})
	for index, confetti in CONFETTI do
		task.delay(index * 0.04, burst, position, confetti, 26, {
			Texture = SPARKLE,
			Light = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.1) }),
			Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(14, 34),
			Acceleration = Vector3.new(0, -18, 0),
			Drag = 1.5,
		})
	end
	ring(CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), YELLOW, 2, 30, 0.9)
	burst(position, Color3.fromRGB(255, 255, 255), 50, {
		Texture = SPARKLE,
		Light = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(10, 28),
		Acceleration = Vector3.new(0, -24, 0),
		Drag = 2,
	})
	Effects3D.shake(1.1, 0.6)
	Effects3D.punch(-10, 0.8)
end

local function aura(model: Model?, color: Color3, duration: number, strong: boolean)
	local root = rootOf(model)
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if strong then 0.7 else 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 6, 0)
	emitter.Rate = if strong then 60 else 30
	emitter.Parent = attachment
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = if strong then 14 else 8
	light.Brightness = 1.5
	light.Parent = attachment
	task.delay(duration, function()
		emitter.Enabled = false
		light:Destroy()
		task.wait(1)
		attachment:Destroy()
	end)
	groundRing(root.Position, color, if strong then 22 else 10)
	if strong then
		task.delay(0.1, groundRing, root.Position, color, 32)
		flash(root.Position, color, 12, 0.4)
	end
end

local function onPower(data: any)
	local archetype = Archetypes.get(data.ArchetypeId)
	local power = archetype and archetype.Powers[data.Slot]
	if not power then
		return
	end
	local strong = data.Slot == 3
	aura(data.Model, power.Color, if strong then 2.5 else 1.2, strong)
	if strong then
		Effects3D.shake(0.8, 0.5)
		Effects3D.punch(-6, 0.6)
	end
end

local function onBlink(data: any)
	if typeof(data.From) ~= "Vector3" or typeof(data.To) ~= "Vector3" then
		return
	end
	local from, to = data.From, data.To
	local distance = (to - from).Magnitude
	if distance < 1 then
		return
	end
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = CYAN
	beam.Size = Vector3.new(0.5, 0.5, distance)
	beam.CFrame = CFrame.lookAt((from + to) / 2, to)
	beam.Parent = folder
	TweenService:Create(
		beam,
		TweenInfo.new(0.35, Enum.EasingStyle.Quint),
		{ Size = Vector3.new(0.05, 0.05, distance), Transparency = 1 }
	):Play()
	Debris:AddItem(beam, 0.4)
	burst(from, VIOLET, 10, { Texture = SPARKLE, Light = 1, Size = NumberSequence.new(0.4, 0) })
	burst(to, VIOLET, 10, { Texture = SPARKLE, Light = 1, Size = NumberSequence.new(0.4, 0) })
end

local function stars(model: Model?, duration: number)
	local root = rootOf(model)
	local head = model and model:FindFirstChild("Head")
	if not root or not head or not head:IsA("BasePart") then
		return
	end
	local orbs: { Part } = {}
	for i = 1, 3 do
		local orb = Instance.new("Part")
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.one * 0.35
		orb.Material = Enum.Material.Neon
		orb.Color = Color3.fromRGB(255, 220, 90)
		orb.Anchored = true
		orb.CanCollide = false
		orb.CanQuery = false
		orb.CanTouch = false
		orb.CastShadow = false
		orb.Parent = folder
		orbs[i] = orb
	end
	local stop = os.clock() + duration
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if os.clock() > stop or not head.Parent then
			connection:Disconnect()
			for _, orb in orbs do
				orb:Destroy()
			end
			return
		end
		for i, orb in orbs do
			local angle = os.clock() * 6 + i * (math.pi * 2 / 3)
			orb.CFrame = CFrame.new(head.Position + Vector3.new(math.cos(angle) * 1.1, 1, math.sin(angle) * 1.1))
		end
	end)
end

local function onEvent(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	if kind == "Shot" then
		onShot(data)
	elseif kind == "Dash" then
		onDash(data.Model)
	elseif kind == "Contact" then
		onContact(data)
	elseif kind == "Goal" then
		onGoal(data)
	elseif kind == "Power" then
		onPower(data)
	elseif kind == "Blink" then
		onBlink(data)
	elseif kind == "Save" then
		flash(BallRenderer.position(), Color3.fromRGB(255, 255, 255), 5, 0.25)
		sparkles(BallRenderer.position(), CYAN, 18, 18, 0.55)
		ring(CFrame.new(BallRenderer.position()) * CFrame.Angles(0, 0, math.pi / 2), CYAN, 1, 8, 0.3)
	elseif kind == "Block" or kind == "WallBlock" then
		flash(BallRenderer.position(), PINK, 4, 0.25)
		sparkles(BallRenderer.position(), PINK, 12, 14, 0.5)
	elseif kind == "Interception" or kind == "Steal" then
		local root = rootOf(data.Model)
		if root then
			groundRing(root.Position, TEAM_COLORS[data.Team] or Color3.new(1, 1, 1), 8)
		end
	elseif kind == "GoalWall" then
		local part = data.Part
		if typeof(part) == "Instance" and part:IsA("BasePart") then
			burst(
				part.Position,
				part.Color,
				40,
				{ Texture = SPARKLE, Light = 1, Size = NumberSequence.new(0.5, 0), Speed = NumberRange.new(4, 14) }
			)
			flash(part.Position, part.Color, 10, 0.4)
		end
	elseif kind == "Status" and data.Kind == "Stun" then
		stars(data.Model, math.min(data.Duration or 1, 3))
	end
end

function Effects3D.start()
	folder = Instance.new("Folder")
	folder.Name = "EffetsLocaux"
	folder.Parent = Workspace
	State.MatchEvent:Connect(function(kind, data)
		local result = table.pack(pcall(onEvent, kind, data))
		if not result[1] then
			warn(`[Effects3D] {kind} : {result[2]}`)
		end
	end)
	MatchInput.ActionFeedback:Connect(function(action)
		if action == "Dash" then
			Effects3D.punch(6, 0.3)
		end
	end)
	-- Tremblement de caméra appliqué après la mise à jour de la caméra.
	RunService:BindToRenderStep("HL_Tremblement", Enum.RenderPriority.Camera.Value + 2, function()
		if os.clock() > shakeUntil then
			shakeStrength = 0
			return
		end
		local camera = Workspace.CurrentCamera :: Camera
		local s = shakeStrength * (shakeUntil - os.clock()) / 0.5
		camera.CFrame = camera.CFrame
			* CFrame.Angles(math.rad((math.random() - 0.5) * s), math.rad((math.random() - 0.5) * s), 0)
	end)
end

return Effects3D
