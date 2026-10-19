--!strict
-- Readable, purposeful effects for the major match events (prompt §34).
-- Effects scale with the importance of the action and never cover the ball:
-- bursts appear at the event point and fade in well under a second.
-- Sounds come from Assets (silent when an id is empty).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Assets)
local BallPhysics = require(ReplicatedStorage.Shared.BallPhysics)
local MatchClient = require(script.Parent.MatchClient)

local EffectsController = {}

local reduced = false
local effectsFolder: Folder
local cameraController: any = nil

-- Camera feedback goes through CameraController so the two never fight.
local function punch(strength: number)
	if reduced or not cameraController or typeof(cameraController.punch) ~= "function" then
		return
	end
	pcall(cameraController.punch, strength)
end

local rgb = Color3.fromRGB
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local TEAM_COLORS = {
	Red = rgb(255, 70, 86),
	Blue = rgb(60, 145, 255),
}

function EffectsController.setReduced(value: boolean)
	reduced = value
	if cameraController and typeof(cameraController.setReducedMotion) == "function" then
		pcall(cameraController.setReducedMotion, value)
	end
end

function EffectsController.isReduced(): boolean
	return reduced
end

local function sound(name: string, volume: number?, position: Vector3?)
	local id = Assets.sound(name)
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = 0.96 + math.random() * 0.08
	if position then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = position
		holder.Parent = Workspace.Terrain
		s.RollOffMaxDistance = 220
		s.Parent = holder
		s:Play()
		task.delay(4, function()
			holder:Destroy()
		end)
	else
		s.Parent = SoundService
		SoundService:PlayLocalSound(s)
		task.delay(4, function()
			s:Destroy()
		end)
	end
end

EffectsController.playSound = sound

local function anchorPart(position: Vector3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Position = position
	p.Parent = effectsFolder
	return p
end

local function burst(position: Vector3, color: Color3, count: number, speed: number, size: number, texture: string?)
	local holder = anchorPart(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture or SPARK
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Lifetime = NumberRange.new(0.25, 0.5)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Drag = 4
	emitter.Enabled = false
	emitter.Parent = holder
	emitter:Emit(if reduced then math.ceil(count / 3) else count)
	task.delay(1, function()
		holder:Destroy()
	end)
end

-- Flat expanding ring on the floor (or facing the camera for mid-air events).
local function ring(position: Vector3, color: Color3, maxSize: number, duration: number, flat: boolean?)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.25
	p.Size = Vector3.new(0.08, 1, 1)
	if flat then
		p.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	else
		local camera = Workspace.CurrentCamera
		local look = if camera then (camera.CFrame.Position - position).Unit else Vector3.new(0, 0, 1)
		p.CFrame = CFrame.lookAt(position, position + look) * CFrame.Angles(0, math.rad(90), 0)
	end
	p.Parent = effectsFolder
	local tween = TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.02, maxSize, maxSize),
		Transparency = 1,
	})
	tween:Play()
	task.delay(duration + 0.05, function()
		p:Destroy()
	end)
end

local function modelOf(id: string?): Model?
	local participant = MatchClient.participant(id)
	return if participant then participant.Model else nil
end

local function rootPosition(model: Model?): Vector3?
	if not model then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function floorY(): number
	local match = MatchClient.Match
	return if match then match.CourtCFrame.Position.Y else 0
end

-- Ball trail: a local helper part follows the predicted ball while a pass or
-- shot is in flight. Thin and short so the ball itself stays the focus.
local trailPart: Part
local trail: Trail

local function setupTrail()
	trailPart = anchorPart(Vector3.new(0, -500, 0))
	trailPart.Name = "BallTrail"
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.35, 0)
	a0.Parent = trailPart
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.35, 0)
	a1.Parent = trailPart
	trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.18
	trail.FaceCamera = true
	trail.LightEmission = 0.6
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
	trail.Enabled = false
	trail.Parent = trailPart
end

local function trailStyle(throw: string?): (Color3?, number)
	if throw == "ChargedShot" then
		return rgb(255, 170, 40), 0.3
	elseif throw == "QuickShot" then
		return rgb(255, 230, 160), 0.22
	elseif throw == "QuickPass" or throw == "LongPass" or throw == "AimedPass" or throw == "HighPass" then
		return rgb(170, 225, 255), 0.14
	end
	return nil, 0
end

local function updateTrail()
	local ball = MatchClient.Ball
	if not ball or ball.State ~= "Flight" then
		if trail.Enabled then
			trail.Enabled = false
		end
		return
	end
	local color, lifetime = trailStyle(ball.Throw)
	if not color then
		trail.Enabled = false
		return
	end
	local elapsed = MatchClient.now() - ball.ServerTime
	local position = BallPhysics.predict(ball.Position, ball.Velocity, elapsed, floorY())
	trailPart.Position = position
	trail.Color = ColorSequence.new(color)
	trail.Lifetime = if reduced then lifetime * 0.6 else lifetime
	trail.Enabled = true
end

local function onEvent(kind: string, data: any)
	if kind == "Goal" then
		local position: Vector3? = data.Position
		local color = TEAM_COLORS[data.Team] or rgb(255, 255, 255)
		sound("Goal", 0.8)
		sound("Crowd", 0.5)
		if position then
			burst(position, color, 60, 40, 1.4)
			burst(position, rgb(255, 214, 90), 30, 30, 1)
			ring(position, color, 22, 0.7, false)
		end
		punch(1)
	elseif kind == "Save" then
		local position: Vector3? = data.Position
		sound("Save", 0.7, position)
		if position then
			burst(position, rgb(120, 220, 255), 22, 22, 0.9)
			ring(position, rgb(120, 220, 255), 9, 0.4, false)
		end
	elseif kind == "Intercept" then
		local position: Vector3? = data.Position or rootPosition(modelOf(data.Id))
		sound("Catch", 0.6, position)
		if position then
			burst(position, rgb(255, 214, 90), 14, 16, 0.6)
			ring(position, rgb(255, 214, 90), 6, 0.3, false)
		end
	elseif kind == "Block" then
		local position: Vector3? = data.Position or rootPosition(modelOf(data.Id))
		sound("Save", 0.5, position)
		if position then
			burst(position, rgb(255, 255, 255), 16, 18, 0.7)
		end
	elseif kind == "Post" then
		local position: Vector3? = data.Position
		sound("Post", 0.8, position)
		if position then
			burst(position, rgb(255, 255, 255), 12, 14, 0.5)
		end
	elseif kind == "Shot" then
		local position = rootPosition(modelOf(data.Id))
		sound(if data.Kind == "Charged" then "ShotCharged" else "Shot", 0.7, position)
		if position and data.Kind == "Charged" then
			ring(position + Vector3.new(0, 1, 0), rgb(255, 170, 40), 7, 0.35, false)
			punch(0.4)
		end
	elseif kind == "Pass" then
		sound("Pass", 0.4, rootPosition(modelOf(data.Id)))
	elseif kind == "Catch" then
		sound("Catch", 0.35, rootPosition(modelOf(data.Id)))
	elseif kind == "Bounce" then
		local speed = tonumber(data.Speed) or 20
		sound("Bounce", math.clamp(speed / 60, 0.1, 0.6), data.Position)
	elseif kind == "Dash" then
		local position = rootPosition(modelOf(data.Id))
		sound("Dash", 0.4, position)
		if position then
			burst(position - Vector3.new(0, 2.6, 0), rgb(220, 210, 190), 8, 8, 1.2, SMOKE)
		end
	elseif kind == "Contact" then
		local position = rootPosition(modelOf(data.ToId))
		sound("Contact", 0.6, position)
		if position then
			burst(
				position + Vector3.new(0, 1, 0),
				if data.Legal then rgb(255, 255, 255) else rgb(255, 80, 80),
				12,
				14,
				0.7
			)
		end
	elseif kind == "Whistle" then
		sound(if data.Kind == "Penalty" then "WhistleLong" else "Whistle", 0.7)
	elseif kind == "Halftime" or kind == "Results" then
		sound("WhistleLong", 0.7)
	elseif kind == "Dive" then
		local position = rootPosition(modelOf(data.Id))
		if position then
			burst(position, rgb(120, 220, 255), 8, 10, 0.6)
		end
	end
end

function EffectsController.init()
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "HL_Effects"
	effectsFolder.Parent = Workspace
	setupTrail()
end

function EffectsController.start()
	local cameraModule = script.Parent:FindFirstChild("CameraController")
	if cameraModule and cameraModule:IsA("ModuleScript") then
		local ok, module = pcall(require, cameraModule)
		if ok then
			cameraController = module
		end
	end
	MatchClient.Event:Connect(onEvent)
	RunService.RenderStepped:Connect(updateTrail)
end

return EffectsController
