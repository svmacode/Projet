--!strict
-- Commandes du match (PC, manette, mobile) et caméra verrouillée.
--
--   PC       : Clic gauche maintenu = tir chargé · E = passe · Shift = dash
--              R = dribble · F = interception / contact · 1 2 3 = pouvoirs
--              Ctrl = verrouiller / libérer la caméra
--   Manette  : R2 tir · X passe · B dash · L1 dribble · Y contact · croix = pouvoirs
--   Mobile   : boutons à droite de l'écran (créés par MatchHUD)
--
-- Le client ENVOIE des demandes : le serveur décide (ballon, fautes, pouvoirs).
-- Seul le dash est appliqué immédiatement en local pour la réactivité.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BallMath = require(ReplicatedStorage.Shared.BallMath)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local State = require(script.Parent.State)

local LocalPlayer = Players.LocalPlayer

local MatchInput = {}

MatchInput.Charge = nil :: number?
MatchInput.CameraLocked = true
MatchInput.DashReadyAt = 0
MatchInput.ActionFeedback = Signal.new() :: Signal.Signal<string>

local actionRemote: RemoteEvent
local chargeStart: number? = nil
local previewDots: { Part } = {}
local bound = false

local function myEntry(): any
	local match = State.Match
	if not match then
		return nil
	end
	for _, participant in match.Participants do
		if participant.UserId == LocalPlayer.UserId then
			return participant
		end
	end
	return nil
end

function MatchInput.me(): any
	return myEntry()
end

local function isHolding(): boolean
	local ball = State.Ball
	local mine = myEntry()
	return ball ~= nil and mine ~= nil and ball.State == "Held" and ball.HolderId == mine.Id
end

function MatchInput.isHolding(): boolean
	return isHolding()
end

local function character(): (Model?, Humanoid?, BasePart?)
	local char = LocalPlayer.Character
	if not char then
		return nil, nil, nil
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	return char, humanoid, if root and root:IsA("BasePart") then root else nil
end

-- Point visé par le centre de l'écran.
local function aimPoint(): Vector3
	local camera = Workspace.CurrentCamera :: Camera
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local localBall = Workspace:FindFirstChild("BallonLocal")
	if localBall then
		table.insert(ignore, localBall)
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	return if hit then hit.Position else ray.Origin + ray.Direction * 400
end

local function handPosition(): Vector3?
	local _, _, root = character()
	if not root then
		return nil
	end
	return (root.CFrame * CFrame.new(1.35, 0.35, -0.95)).Position
end

local function aimDirection(): Vector3
	local hand = handPosition()
	local target = aimPoint()
	if hand then
		local direction = target - hand
		if direction.Magnitude > 0.1 then
			return direction.Unit
		end
	end
	return (Workspace.CurrentCamera :: Camera).CFrame.LookVector
end

local function send(action: string, a: any?, b: any?)
	actionRemote:FireServer(action, a, b)
end

-- Aperçu de trajectoire ----------------------------------------------------------------------

local function ensurePreview()
	if #previewDots > 0 then
		return
	end
	for i = 1, 22 do
		local dot = Instance.new("Part")
		dot.Name = "Visee"
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.one * (0.32 - i * 0.008)
		dot.Material = Enum.Material.Neon
		dot.Color = Color3.fromRGB(255, 255, 255)
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.CastShadow = false
		table.insert(previewDots, dot)
	end
end

local function hidePreview()
	for _, dot in previewDots do
		dot.Parent = nil
	end
end

local function updatePreview(charge: number)
	ensurePreview()
	local hand = handPosition()
	if not hand then
		hidePreview()
		return
	end
	local direction = (aimDirection() + Vector3.new(0, 0.04, 0)).Unit
	local speed = Config.Ball.ShotMinSpeed + (Config.Ball.ShotMaxSpeed - Config.Ball.ShotMinSpeed) * charge
	local velocity = direction * speed
	local floorY = if State.Match then (State.Match.CourtCFrame :: CFrame).Position.Y else 0
	for index, dot in previewDots do
		local t = index * 0.035
		local position = BallMath.positionAt(hand, velocity, Vector3.zero, t)
		if position.Y < floorY then
			dot.Parent = nil
		else
			dot.CFrame = CFrame.new(position)
			dot.Color = Color3.fromRGB(255, 255 - math.floor(charge * 120), 255 - math.floor(charge * 200))
			dot.Parent = Workspace
		end
	end
end

-- Actions ---------------------------------------------------------------------------------------

local function canPlay(): boolean
	local match = State.Match
	return match ~= nil and (match.Phase == "Live" or match.Phase == "SetPiece") and myEntry() ~= nil
end

local function startCharge()
	if not canPlay() or not isHolding() then
		return
	end
	chargeStart = os.clock()
end

local function releaseCharge()
	if not chargeStart then
		return
	end
	local charge = math.clamp((os.clock() - chargeStart) / Config.Ball.ShotChargeTime, 0, 1)
	chargeStart = nil
	MatchInput.Charge = nil
	hidePreview()
	if isHolding() then
		send("Shoot", aimDirection(), charge)
		MatchInput.ActionFeedback:Fire("Shoot")
	end
end

local function pass()
	if not canPlay() or not isHolding() then
		return
	end
	-- Coéquipier le plus proche du viseur.
	local camera = Workspace.CurrentCamera :: Camera
	local center = camera.ViewportSize / 2
	local mine = myEntry()
	local best: Model? = nil
	local bestDistance = 320
	if State.Match and mine then
		for _, participant in State.Match.Participants do
			local model = participant.Model
			if participant.Team == mine.Team and participant.Id ~= mine.Id and model and model.Parent then
				local root = model:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local screen, onScreen = camera:WorldToViewportPoint(root.Position)
					if onScreen then
						local distance = (Vector2.new(screen.X, screen.Y) - center).Magnitude
						if distance < bestDistance then
							best = model
							bestDistance = distance
						end
					end
				end
			end
		end
	end
	send("Pass", aimDirection(), best)
	MatchInput.ActionFeedback:Fire("Pass")
end

local function applyImpulse(velocity: Vector3, duration: number)
	local _, _, root = character()
	if not root then
		return
	end
	if duration <= 0 then
		root.AssemblyLinearVelocity = velocity
		return
	end
	local attachment = root:FindFirstChild("ImpulsionLocale") :: Attachment?
	if not attachment then
		local created = Instance.new("Attachment")
		created.Name = "ImpulsionLocale"
		created.Parent = root
		attachment = created
	end
	local mover = Instance.new("LinearVelocity")
	mover.Attachment0 = attachment
	mover.MaxForce = 1e6
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	mover.VectorVelocity = velocity
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.Parent = root
	task.delay(duration, function()
		mover:Destroy()
	end)
end

local function dash()
	if not canPlay() then
		return
	end
	local _, humanoid, root = character()
	if not humanoid or not root or humanoid.WalkSpeed <= 0 then
		return
	end
	if os.clock() < MatchInput.DashReadyAt then
		return
	end
	MatchInput.DashReadyAt = os.clock() + Config.Movement.DashCooldown
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		local look = root.CFrame.LookVector
		direction = Vector3.new(look.X, 0, look.Z)
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	applyImpulse(direction * Config.Movement.DashSpeed, Config.Movement.DashDuration)
	send("Dash", direction)
	MatchInput.ActionFeedback:Fire("Dash")
end

function MatchInput.perform(action: string)
	if action == "Shoot" then
		if chargeStart then
			releaseCharge()
		else
			startCharge()
		end
	elseif action == "ShootBegin" then
		startCharge()
	elseif action == "ShootEnd" then
		releaseCharge()
	elseif action == "Pass" then
		pass()
	elseif action == "Dash" then
		dash()
	elseif action == "Dribble" then
		if canPlay() then
			send("Dribble")
			MatchInput.ActionFeedback:Fire("Dribble")
		end
	elseif action == "Contact" then
		if canPlay() then
			send("Contact")
			MatchInput.ActionFeedback:Fire("Contact")
		end
	elseif action == "Power1" or action == "Power2" or action == "Power3" then
		if canPlay() then
			send("Power", tonumber(string.sub(action, 6)))
		end
	end
end

-- Liaisons clavier / manette ----------------------------------------------------------------------

local BINDINGS: { { Name: string, Inputs: { Enum.KeyCode | Enum.UserInputType } } } = {
	{ Name = "Pass", Inputs = { Enum.KeyCode.E, Enum.KeyCode.ButtonX } },
	{ Name = "Dash", Inputs = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonB } },
	{ Name = "Dribble", Inputs = { Enum.KeyCode.R, Enum.KeyCode.ButtonL1 } },
	{ Name = "Contact", Inputs = { Enum.KeyCode.F, Enum.KeyCode.ButtonY } },
	{ Name = "Power1", Inputs = { Enum.KeyCode.One, Enum.KeyCode.DPadLeft } },
	{ Name = "Power2", Inputs = { Enum.KeyCode.Two, Enum.KeyCode.DPadUp } },
	{ Name = "Power3", Inputs = { Enum.KeyCode.Three, Enum.KeyCode.DPadRight } },
}

local function bind()
	if bound then
		return
	end
	bound = true
	for _, binding in BINDINGS do
		ContextActionService:BindAction(`HL_{binding.Name}`, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				MatchInput.perform(binding.Name)
			end
			return Enum.ContextActionResult.Sink
		end, false, table.unpack(binding.Inputs))
	end
	ContextActionService:BindAction("HL_Shoot", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			startCharge()
		elseif inputState == Enum.UserInputState.End then
			releaseCharge()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("HL_CameraLock", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			MatchInput.CameraLocked = not MatchInput.CameraLocked
			State.request("ProfileAction", "SetSetting", "CameraLock", MatchInput.CameraLocked)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl)
end

local function unbind()
	if not bound then
		return
	end
	bound = false
	for _, binding in BINDINGS do
		ContextActionService:UnbindAction(`HL_{binding.Name}`)
	end
	ContextActionService:UnbindAction("HL_Shoot")
	ContextActionService:UnbindAction("HL_CameraLock")
	chargeStart = nil
	MatchInput.Charge = nil
	hidePreview()
end

-- Caméra verrouillée (style « shift lock ») ----------------------------------------------------------

local function updateCamera()
	local _, humanoid, root = character()
	local inMatch = State.inMatch() and myEntry() ~= nil
	local overlayOpen = State.ActiveScreen ~= nil
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local lock = inMatch and MatchInput.CameraLocked and not overlayOpen and not touch
	if lock and humanoid and root then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		humanoid.AutoRotate = false
		humanoid.CameraOffset = Vector3.new(1.75, 0.5, 0)
		local look = (Workspace.CurrentCamera :: Camera).CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 and humanoid.WalkSpeed > 0 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	else
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		UserInputService.MouseIconEnabled = true
		if humanoid then
			humanoid.AutoRotate = true
			humanoid.CameraOffset = if inMatch and not overlayOpen then Vector3.new(1.2, 0.4, 0) else Vector3.zero
		end
	end
end

function MatchInput.start()
	actionRemote = Net.event("MatchAction")

	Net.event("MatchEvent").OnClientEvent:Connect(function(kind, data)
		if kind == "Impulse" and typeof(data) == "table" and typeof(data.Velocity) == "Vector3" then
			applyImpulse(data.Velocity, tonumber(data.Duration) or 0)
		end
	end)

	State.ProfileChanged:Connect(function(profile)
		if profile and profile.Settings and profile.Settings.CameraLock ~= nil then
			MatchInput.CameraLocked = profile.Settings.CameraLock
		end
	end)

	State.MatchChanged:Connect(function()
		if State.inMatch() and myEntry() then
			bind()
			pcall(function()
				StarterGui:SetCore("ResetButtonCallback", false)
			end)
		else
			unbind()
			pcall(function()
				StarterGui:SetCore("ResetButtonCallback", true)
			end)
		end
	end)

	RunService:BindToRenderStep("HL_Camera", Enum.RenderPriority.Camera.Value + 1, function()
		updateCamera()
		if chargeStart then
			local charge = math.clamp((os.clock() - chargeStart) / Config.Ball.ShotChargeTime, 0, 1)
			MatchInput.Charge = charge
			updatePreview(charge)
			if not isHolding() then
				chargeStart = nil
				MatchInput.Charge = nil
				hidePreview()
			end
		end
	end)
end

return MatchInput
