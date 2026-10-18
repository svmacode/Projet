--!strict
-- Caméra des matchs : 3e personne au-dessus de l'épaule, façon Volleyball
-- Legends. On garde la caméra Roblox (collisions, tactile, manette) et on la
-- règle : décalage d'épaule lissé, légère avance dans le sens de la course,
-- zoom borné, champ de vision qui s'élargit avec la vitesse, coups de FOV
-- sur le dash et le tir parfait. Ctrl (MatchInput.CameraLocked) = mode
-- verrouillé façon shift-lock : le personnage regarde où vise la caméra.
--
-- Dans le lobby, tout revient aux réglages Roblox standards.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MatchInput = require(script.Parent.MatchInput)
local State = require(script.Parent.State)

local LocalPlayer = Players.LocalPlayer

local CameraController = {}

local BASE_FOV = 72
local SPEED_FOV = 5 -- FOV en plus à pleine course
local SHOULDER = Vector3.new(1.9, 0.6, 0)
local SHOULDER_TOUCH = Vector3.new(1.1, 0.5, 0)
local LEAD = 1.1 -- avance latérale dans le sens de la course
local MIN_ZOOM, MAX_ZOOM = 9, 18

local defaults = {
	Fov = 70,
	MinZoom = LocalPlayer.CameraMinZoomDistance,
	MaxZoom = LocalPlayer.CameraMaxZoomDistance,
}

local active = false
local offset = Vector3.zero
local fov = BASE_FOV
local punch = 0 -- FOV temporaire, décroît vers 0
local shakeUntil = 0
local shakeStrength = 0

local function character(): (Humanoid?, BasePart?)
	local char = LocalPlayer.Character
	if not char then
		return nil, nil
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	return humanoid, if root and root:IsA("BasePart") then root else nil
end

local function inMatch(): boolean
	return State.inMatch() and MatchInput.me() ~= nil
end

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Coup de FOV signé (+ = élargit, − = resserre) et secousse facultative.
function CameraController.punch(amount: number, shake: number?, duration: number?)
	if math.abs(amount) > math.abs(punch) then
		punch = amount
	end
	if shake and shake > 0 then
		shakeStrength = shake
		shakeUntil = os.clock() + (duration or 0.2)
	end
end

local function enter()
	active = true
	LocalPlayer.CameraMinZoomDistance = MIN_ZOOM
	LocalPlayer.CameraMaxZoomDistance = MAX_ZOOM
	fov = BASE_FOV
	offset = Vector3.zero
end

local function leave()
	active = false
	LocalPlayer.CameraMinZoomDistance = defaults.MinZoom
	LocalPlayer.CameraMaxZoomDistance = defaults.MaxZoom
	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = defaults.Fov
	end
	local humanoid = character()
	if humanoid then
		humanoid.CameraOffset = Vector3.zero
		humanoid.AutoRotate = true
	end
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	UserInputService.MouseIconEnabled = true
end

local function update(dt: number)
	local wanted = inMatch()
	if wanted ~= active then
		if wanted then
			enter()
		else
			leave()
		end
	end
	if not active then
		return
	end
	local camera = Workspace.CurrentCamera
	local humanoid, root = character()
	if not camera or not humanoid or not root then
		return
	end
	local overlayOpen = State.ActiveScreen ~= nil
	local touch = isTouch()
	local lock = MatchInput.CameraLocked and not overlayOpen and not touch

	-- Verrouillage façon shift-lock.
	if lock then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		humanoid.AutoRotate = false
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 and humanoid.WalkSpeed > 0 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	else
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		UserInputService.MouseIconEnabled = true
		humanoid.AutoRotate = true
	end

	-- Décalage d'épaule + avance latérale dans le sens de la course (lissés).
	local velocity = root.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = flatVelocity.Magnitude
	local right = camera.CFrame.RightVector
	local sideways = if speed > 1 then flatVelocity:Dot(Vector3.new(right.X, 0, right.Z)) / math.max(speed, 1) else 0
	local shoulder = if touch then SHOULDER_TOUCH else SHOULDER
	local target = if overlayOpen then Vector3.zero else shoulder + Vector3.new(sideways * LEAD, 0, 0)
	local alpha = 1 - math.exp(-dt * 8)
	offset = offset:Lerp(target, alpha)

	-- Petite secousse (tir parfait, gros contact).
	local shake = Vector3.zero
	if os.clock() < shakeUntil then
		local s = shakeStrength * (shakeUntil - os.clock()) / 0.25
		shake = Vector3.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
	end
	humanoid.CameraOffset = offset + shake

	-- Champ de vision : s'ouvre avec la vitesse, coups de FOV qui retombent vite.
	local walk = math.max(humanoid.WalkSpeed, 1)
	local speedFov = math.clamp(speed / walk, 0, 1.4) * SPEED_FOV
	punch -= math.sign(punch) * math.min(math.abs(punch), dt * 40)
	local wantedFov = BASE_FOV + speedFov + punch
	fov += (wantedFov - fov) * (1 - math.exp(-dt * 10))
	camera.FieldOfView = fov
end

function CameraController.start()
	defaults.Fov = if Workspace.CurrentCamera then Workspace.CurrentCamera.FieldOfView else 70
	defaults.MinZoom = LocalPlayer.CameraMinZoomDistance
	defaults.MaxZoom = LocalPlayer.CameraMaxZoomDistance

	MatchInput.ShotGraded:Connect(function(grade)
		if grade == "Perfect" then
			-- Effet « ralenti » : gros coup de FOV qui se referme lentement + secousse.
			CameraController.punch(16, 0.5, 0.25)
		end
	end)

	RunService:BindToRenderStep("HL_Camera", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraController
