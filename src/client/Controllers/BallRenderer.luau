--!strict
-- Draws the ball locally from MatchClient.Ball. The server has no ball Part:
-- it simulates a logical ball and sends snapshots; every client predicts the
-- flight with the same BallPhysics and eases out the error on each snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BallPhysics = require(ReplicatedStorage.Shared.BallPhysics)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local MatchClient = require(script.Parent.MatchClient)

local BallRenderer = {}

local RADIUS = Config.Ball.Radius
local SNAP_DISTANCE = 14 -- beyond this error the ball jumps instead of easing
local ERROR_DECAY = 14

local folder: Folder? = nil
local ball: Part? = nil
local seams: { Part } = {}
local shadow: Part? = nil
local trail: Trail? = nil
local rendered: Vector3? = nil
local spin = CFrame.identity
local lastHolderId: string? = nil

local function getFolder(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local created = Workspace:FindFirstChild("HL_Client") :: Folder?
	if not created then
		local f = Instance.new("Folder")
		f.Name = "HL_Client"
		f.Parent = Workspace
		created = f
	end
	folder = created
	return created :: Folder
end

local function makePart(name: string, shape: Enum.PartType, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function build()
	if ball then
		return
	end
	local parent = getFolder()
	local body = makePart("HL_Ball", Enum.PartType.Ball, Vector3.one * RADIUS * 2, Color3.fromRGB(246, 244, 236))
	body.CastShadow = true
	-- Seams: thin discs slightly wider than the ball read as coloured lines.
	local seamColors = { Color3.fromRGB(220, 40, 52), Color3.fromRGB(30, 92, 220), Color3.fromRGB(32, 32, 40) }
	for index, color in seamColors do
		local seam =
			makePart("Seam", Enum.PartType.Cylinder, Vector3.new(0.07, RADIUS * 2 + 0.03, RADIUS * 2 + 0.03), color)
		seam:SetAttribute("Index", index)
		seam.Parent = body
		table.insert(seams, seam)
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, RADIUS * 0.55, 0)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -RADIUS * 0.55, 0)
	a1.Parent = body
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Lifetime = 0.16
	t.FaceCamera = true
	t.LightEmission = 0.4
	t.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	t.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	t.Enabled = false
	t.Parent = body
	trail = t

	local s = makePart("HL_BallShadow", Enum.PartType.Cylinder, Vector3.new(0.05, 2, 2), Color3.new(0, 0, 0))
	s.Transparency = 0.6
	s.Parent = parent
	shadow = s

	body.Parent = parent
	ball = body
end

local function destroy()
	if ball then
		ball:Destroy()
	end
	if shadow then
		shadow:Destroy()
	end
	ball = nil
	shadow = nil
	trail = nil
	table.clear(seams)
	rendered = nil
	lastHolderId = nil
end

local function floorY(): number
	local match = MatchClient.Match
	return if match then match.CourtCFrame.Position.Y else 0
end

local function holderModel(snapshot: Types.BallSnapshot): Model?
	local participant = MatchClient.participant(snapshot.HolderId)
	return if participant then participant.Model else nil
end

-- Hand position of the holder (bottom of the R6 right arm), or a fallback.
local function handPosition(model: Model): Vector3?
	local arm = model:FindFirstChild("Right Arm")
	if arm and arm:IsA("BasePart") then
		return (arm.CFrame * CFrame.new(0, -arm.Size.Y / 2 - RADIUS * 0.6, -0.15)).Position
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return (root.CFrame * CFrame.new(Config.Ball.HoldOffset)).Position
	end
	return nil
end

local function heldPosition(snapshot: Types.BallSnapshot): Vector3?
	local model = holderModel(snapshot)
	if not model then
		return nil
	end
	local hand = handPosition(model)
	if not hand then
		return nil
	end
	if not snapshot.Dribbling then
		return hand
	end
	-- Dribble: hand → floor → hand, one bounce per interval.
	local interval = Config.Rules.DribbleBounceInterval
	local t = (MatchClient.now() % interval) / interval
	local bottom = floorY() + RADIUS
	local height = math.abs(math.cos(math.pi * t))
	local root = model:FindFirstChild("HumanoidRootPart")
	local base = hand
	if root and root:IsA("BasePart") then
		-- Bounce slightly in front of the carrier's right foot.
		base = (root.CFrame * CFrame.new(1.1, 0, -1.1)).Position
	end
	return Vector3.new(base.X, bottom + (hand.Y - bottom) * height, base.Z)
end

local function update(dt: number)
	local match = MatchClient.Match
	local snapshot = MatchClient.Ball
	if not match or not snapshot or snapshot.State == "Hidden" then
		if ball then
			destroy()
		end
		return
	end
	build()
	local body = ball :: Part

	local target: Vector3?
	local velocity = Vector3.zero
	if snapshot.State == "Held" then
		target = heldPosition(snapshot)
		lastHolderId = snapshot.HolderId
	else
		local elapsed = math.max(0, MatchClient.now() - snapshot.ServerTime)
		local p, v = BallPhysics.predict(snapshot.Position, snapshot.Velocity, elapsed, floorY())
		target = p
		velocity = v
		lastHolderId = nil
	end
	local goal: Vector3 = target or snapshot.Position

	local previous = rendered
	local current: Vector3
	if not previous or (goal - previous).Magnitude > SNAP_DISTANCE or snapshot.State == "Held" then
		current = goal
	else
		current = previous:Lerp(goal, 1 - math.exp(-dt * ERROR_DECAY))
	end
	rendered = current

	-- Rolling spin from velocity.
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	if flat.Magnitude > 0.5 then
		local axis = Vector3.yAxis:Cross(flat).Unit
		spin = CFrame.fromAxisAngle(axis, flat.Magnitude / RADIUS * dt) * spin
	end
	local cframe = CFrame.new(current) * spin
	body.CFrame = cframe
	for index, seam in seams do
		local angle = (index - 1) * math.pi / 3
		seam.CFrame = cframe * CFrame.Angles(0, angle, 0) * CFrame.Angles(0, 0, math.pi / 2 * (index - 1))
	end

	-- Trail only in flight; stronger for charged shots.
	local t = trail
	if t then
		local flying = snapshot.State == "Flight"
		t.Enabled = flying and velocity.Magnitude > 20
		local charged = snapshot.Throw == "ChargedShot"
		t.Lifetime = if charged then 0.26 else 0.14
		local color = if charged then Color3.fromRGB(255, 196, 120) else Color3.fromRGB(255, 255, 255)
		t.Color = ColorSequence.new(color)
	end

	-- Shadow on the floor, smaller and lighter when the ball is high.
	local s = shadow
	if s then
		local ground = floorY()
		local height = math.max(0, current.Y - ground - RADIUS)
		local size = math.clamp(RADIUS * 2.2 - height * 0.04, 0.6, RADIUS * 2.2)
		s.Size = Vector3.new(0.05, size, size)
		s.Transparency = math.clamp(0.55 + height * 0.02, 0.55, 0.92)
		s.CFrame = CFrame.new(current.X, ground + 0.04, current.Z) * CFrame.Angles(0, 0, math.pi / 2)
	end
end

function BallRenderer.ballPart(): BasePart?
	return ball
end

-- Last rendered world position of the ball (nil when not visible).
function BallRenderer.position(): Vector3?
	return rendered
end

function BallRenderer.lastHolderId(): string?
	return lastHolderId
end

function BallRenderer.start()
	-- After animations and the camera so the ball sits exactly in the hand.
	RunService:BindToRenderStep("HL_Ball", Enum.RenderPriority.Camera.Value + 5, update)
end

return BallRenderer
