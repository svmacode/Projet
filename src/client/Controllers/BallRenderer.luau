--!strict
-- Rendu du ballon côté client. Le serveur envoie l'état (tenu, en vol…) ;
-- entre deux mises à jour, le client prolonge la trajectoire avec la même
-- physique (BallMath) pour un mouvement parfaitement fluide.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BallMath = require(ReplicatedStorage.Shared.BallMath)
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local BallRenderer = {}

local RADIUS = Config.Ball.Radius
local HAND_OFFSET = CFrame.new(1.35, 0.35, -0.95)

local model: Model
local ball: Part
local rings: { Part } = {}
local trail: Trail
local fire: Fire
local glow: PointLight

local simPosition = Vector3.zero
local simVelocity = Vector3.zero
local simAccel = Vector3.zero
local visualPosition = Vector3.zero
local spin = CFrame.identity
local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Include

function BallRenderer.position(): Vector3
	return visualPosition
end

function BallRenderer.velocity(): Vector3
	return simVelocity
end

local function build()
	model = Instance.new("Model")
	model.Name = "BallonLocal"
	ball = Instance.new("Part")
	ball.Name = "Ballon"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * RADIUS * 2
	ball.Color = Color3.fromRGB(245, 245, 240)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = true
	ball.Parent = model
	for index, color in { Color3.fromRGB(232, 58, 68), Color3.fromRGB(40, 90, 210) } do
		local ring = Instance.new("Part")
		ring.Name = "Couture"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.16, RADIUS * 2 + 0.06, RADIUS * 2 + 0.06)
		ring.Color = color
		ring.Material = Enum.Material.SmoothPlastic
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Parent = model
		rings[index] = ring
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.45, 0)
	a0.Parent = ball
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.45, 0)
	a1.Parent = ball
	trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Enabled = false
	trail.Parent = ball
	fire = Instance.new("Fire")
	fire.Heat = 12
	fire.Size = 4
	fire.Color = Color3.fromRGB(255, 120, 30)
	fire.SecondaryColor = Color3.fromRGB(255, 230, 80)
	fire.Enabled = false
	fire.Parent = ball
	glow = Instance.new("PointLight")
	glow.Range = 10
	glow.Brightness = 2
	glow.Enabled = false
	glow.Parent = ball
	local outline = Instance.new("Highlight")
	outline.FillTransparency = 1
	outline.OutlineColor = Color3.fromRGB(12, 12, 16)
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
end

local function holderHand(holder: Model): (Vector3?, BasePart?)
	local arm = holder:FindFirstChild("Right Arm") or holder:FindFirstChild("RightHand")
	local root = holder:FindFirstChild("HumanoidRootPart")
	if arm and arm:IsA("BasePart") then
		local offset = if arm.Name == "Right Arm" then CFrame.new(0, -1.25, -0.3) else CFrame.new(0, -0.3, -0.4)
		return (arm.CFrame * offset).Position, if root and root:IsA("BasePart") then root else nil
	end
	if root and root:IsA("BasePart") then
		return (root.CFrame * HAND_OFFSET).Position, root
	end
	return nil, nil
end

local function onBallState(snapshot: any)
	if not snapshot then
		return
	end
	local match = State.Match
	local courtModel = match and match.CourtModel
	if courtModel then
		local collisions = courtModel:FindFirstChild("Collisions")
		if collisions then
			castParams.FilterDescendantsInstances = { collisions }
		end
	end
	if snapshot.State == "Flight" or snapshot.State == "Dead" then
		simPosition = snapshot.Position
		simVelocity = snapshot.Velocity
		simAccel = snapshot.Accel
		if snapshot.State == "Flight" then
			-- Rattrape la latence réseau.
			local latency = math.clamp(Workspace:GetServerTimeNow() - snapshot.ServerTime, 0, 0.3)
			if latency > 0 then
				local result = BallMath.step(simPosition, simVelocity, simAccel, latency, function(origin, direction)
					local hit = Workspace:Spherecast(origin, RADIUS, direction, castParams)
					if hit then
						return hit.Position, hit.Normal, hit.Instance
					end
					return nil, nil, nil
				end)
				simPosition = result.Position
				simVelocity = result.Velocity
			end
		end
		if (visualPosition - simPosition).Magnitude > 18 then
			visualPosition = simPosition
		end
	end
	local speed = snapshot.Velocity.Magnitude
	trail.Enabled = snapshot.State == "Flight" and speed > 45
	trail.Color = ColorSequence.new(
		if snapshot.Fire
			then Color3.fromRGB(255, 140, 40)
			elseif snapshot.Charged then Color3.fromRGB(120, 230, 255)
			else Color3.fromRGB(255, 255, 255)
	)
	trail.Lifetime = if snapshot.Kind == "Shot" then 0.4 else 0.2
	fire.Enabled = snapshot.Fire == true
	glow.Enabled = snapshot.Fire == true or snapshot.Charged == true
	glow.Color = if snapshot.Fire then Color3.fromRGB(255, 140, 40) else Color3.fromRGB(120, 230, 255)
end

local function update(dt: number)
	local snapshot = State.Ball
	local match = State.Match
	if not snapshot or not match or snapshot.State == "Hidden" or match.Phase == "Ended" then
		model.Parent = nil
		return
	end
	model.Parent = Workspace
	local t = os.clock()

	if snapshot.State == "Held" and snapshot.Holder and snapshot.Holder.Parent then
		local hand, root = holderHand(snapshot.Holder)
		if hand then
			if snapshot.Dribbling and root then
				local floorY = (match.CourtCFrame :: CFrame).Position.Y + RADIUS
				local bounce = math.abs(math.sin(t * 9))
				local side = (root.CFrame * CFrame.new(1.3, 0, -1.3)).Position
				visualPosition = Vector3.new(side.X, floorY + bounce * (hand.Y - floorY), side.Z)
			else
				visualPosition = hand
			end
			simPosition = visualPosition
			simVelocity = Vector3.zero
		end
		spin = spin * CFrame.Angles(0, dt * 2, 0)
	elseif snapshot.State == "Flight" then
		local result = BallMath.step(simPosition, simVelocity, simAccel, dt, function(origin, direction)
			local hit = Workspace:Spherecast(origin, RADIUS, direction, castParams)
			if hit then
				return hit.Position, hit.Normal, hit.Instance
			end
			return nil, nil, nil
		end)
		simPosition = result.Position
		simVelocity = result.Velocity
		visualPosition = visualPosition:Lerp(simPosition, math.min(1, dt * 22))
		local speed = simVelocity.Magnitude
		if speed > 0.5 then
			local axis = simVelocity:Cross(Vector3.yAxis)
			if axis.Magnitude > 0.01 then
				spin = CFrame.fromAxisAngle(axis.Unit, -speed * dt / RADIUS) * spin
			end
		end
	else
		visualPosition = visualPosition:Lerp(simPosition, math.min(1, dt * 15))
	end

	local cframe = CFrame.new(visualPosition) * spin
	ball.CFrame = cframe
	rings[1].CFrame = cframe * CFrame.Angles(0, 0, math.pi / 2)
	rings[2].CFrame = cframe * CFrame.Angles(0, math.pi / 2, 0)
end

function BallRenderer.start()
	build()
	State.BallChanged:Connect(onBallState)
	RunService.RenderStepped:Connect(update)
end

return BallRenderer
