--!strict
-- Match camera: third person over the right shoulder, mouse locked at the
-- centre of the screen (the crosshair), the character always faces the aim
-- direction. Outside of a match the default Roblox camera is restored.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local Workspace = game:GetService("Workspace")

local MatchClient = require(script.Parent.MatchClient)

local CameraController = {}

local BASE_FOV = 70
local SHOULDER = Vector3.new(2.3, 0.6, 0)
local FOCUS_HEIGHT = 2.6
local MIN_DISTANCE, MAX_DISTANCE = 9, 16
local PITCH_MIN, PITCH_MAX = math.rad(-65), math.rad(45)
local MOUSE_SCALE = 0.0045
local GAMEPAD_SPEED = math.rad(220) -- degrees per second at full stick
local TOUCH_SCALE = 0.006

local active = false
local yaw = 0
local pitch = math.rad(-12)
local distance = 12
local sensitivity = 1
local reducedMotion = false
local smoothedFocus: Vector3? = nil
local gamepadLook = Vector2.zero
local fovKick = 0
local shake = 0
local shakeSeed = 0
local touchLook: InputObject? = nil
local lastTouchPosition: Vector3? = nil
local savedAutoRotate = true
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local localPlayer = Players.LocalPlayer

local function character(): (Model?, BasePart?, Humanoid?)
	local model = localPlayer.Character
	if not model then
		return nil, nil, nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid then
		return model, root, humanoid
	end
	return model, nil, nil
end

local function refreshFilter()
	local ignore: { Instance } = {}
	local match = MatchClient.Match
	if match then
		for _, participant in match.Participants do
			if participant.Model then
				table.insert(ignore, participant.Model)
			end
		end
	end
	local own = localPlayer.Character
	if own then
		table.insert(ignore, own)
	end
	local clientFolder = Workspace:FindFirstChild("HL_Client")
	if clientFolder then
		table.insert(ignore, clientFolder)
	end
	raycastParams.FilterDescendantsInstances = ignore
end

local function shouldBeActive(): boolean
	local match = MatchClient.Match
	if not match or not MatchClient.me() then
		return false
	end
	local phase = match.Phase
	return phase == "Countdown" or phase == "Playing" or phase == "Overtime" or phase == "Halftime"
end

local function setActive(value: boolean)
	if active == value then
		return
	end
	active = value
	local camera = Workspace.CurrentCamera
	local _, root, humanoid = character()
	if value then
		if root then
			local look = root.CFrame.LookVector
			yaw = math.atan2(-look.X, -look.Z)
		end
		pitch = math.rad(-12)
		smoothedFocus = nil
		if humanoid then
			savedAutoRotate = humanoid.AutoRotate
			humanoid.AutoRotate = false
		end
		if camera then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		UserInputService.MouseIconEnabled = false
	else
		if humanoid then
			humanoid.AutoRotate = savedAutoRotate
		end
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = BASE_FOV
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

local function onInputChanged(input: InputObject, processed: boolean)
	if not active then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
		distance = math.clamp(distance - input.Position.Z * 1.2, MIN_DISTANCE, MAX_DISTANCE)
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		local value = Vector2.new(input.Position.X, input.Position.Y)
		gamepadLook = if value.Magnitude < 0.15 then Vector2.zero else value
	elseif input == touchLook and lastTouchPosition then
		local delta = input.Position - lastTouchPosition
		lastTouchPosition = input.Position
		yaw -= delta.X * TOUCH_SCALE * sensitivity
		pitch = math.clamp(pitch - delta.Y * TOUCH_SCALE * sensitivity, PITCH_MIN, PITCH_MAX)
	end
end

local function onInputBegan(input: InputObject, processed: boolean)
	if not active or processed or input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	-- Only the right half of the screen rotates the camera (left half = thumbstick).
	local camera = Workspace.CurrentCamera
	if camera and input.Position.X > camera.ViewportSize.X * 0.4 and not touchLook then
		touchLook = input
		lastTouchPosition = input.Position
	end
end

local function onInputEnded(input: InputObject)
	if input == touchLook then
		touchLook = nil
		lastTouchPosition = nil
	end
end

local function update(dt: number)
	local wanted = shouldBeActive()
	setActive(wanted)
	if not active then
		return
	end
	local camera = Workspace.CurrentCamera
	local _, root, _ = character()
	if not camera or not root then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	-- Look input.
	local mouseDelta = UserInputService:GetMouseDelta()
	local mouseSensitivity = UserGameSettings.MouseSensitivity * sensitivity
	yaw -= mouseDelta.X * MOUSE_SCALE * mouseSensitivity
	pitch = math.clamp(pitch - mouseDelta.Y * MOUSE_SCALE * mouseSensitivity, PITCH_MIN, PITCH_MAX)
	if gamepadLook.Magnitude > 0 then
		yaw -= gamepadLook.X * GAMEPAD_SPEED * sensitivity * dt
		pitch = math.clamp(pitch + gamepadLook.Y * GAMEPAD_SPEED * 0.7 * sensitivity * dt, PITCH_MIN, PITCH_MAX)
	end

	-- Focus point, smoothed, with a slight lead in the running direction.
	local velocity = root.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local lead = flatVelocity * 0.035
	if lead.Magnitude > 1.2 then
		lead = lead.Unit * 1.2
	end
	local targetFocus = root.Position + Vector3.new(0, FOCUS_HEIGHT, 0) + lead
	local focus = smoothedFocus or targetFocus
	local alpha = 1 - math.exp(-dt * 18)
	focus = focus:Lerp(targetFocus, alpha)
	-- Never let the camera lag far behind (dashes, teleports to set pieces).
	if (targetFocus - focus).Magnitude > 6 then
		focus = targetFocus
	end
	smoothedFocus = focus

	local rotation = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
	local shoulder = rotation:VectorToWorldSpace(SHOULDER)
	local pivot = focus + shoulder
	local desired = pivot + rotation.LookVector * -distance

	-- Collision: pull the camera in front of walls.
	local castFrom = focus
	local result = Workspace:Raycast(castFrom, desired - castFrom, raycastParams)
	local position = desired
	if result then
		position = result.Position + (castFrom - result.Position).Unit * 0.6
	end

	-- Camera punch (FOV kick + small shake), decays quickly.
	fovKick = fovKick * math.exp(-dt * 9)
	shake = shake * math.exp(-dt * 14)
	local shakeOffset = Vector3.zero
	if shake > 0.01 then
		shakeSeed += dt * 40
		shakeOffset = Vector3.new(math.noise(shakeSeed, 0), math.noise(0, shakeSeed), 0) * shake
	end
	camera.FieldOfView = BASE_FOV + fovKick
	camera.CFrame = CFrame.new(position) * rotation * CFrame.new(shakeOffset)
	camera.Focus = CFrame.new(focus)

	-- The character faces the aim direction (shift-lock style).
	local flatLook = Vector3.new(rotation.LookVector.X, 0, rotation.LookVector.Z)
	if flatLook.Magnitude > 0.01 then
		local current = root.CFrame
		local target = CFrame.lookAt(current.Position, current.Position + flatLook)
		root.CFrame = current:Lerp(target, 1 - math.exp(-dt * 30))
	end
end

-- World ray from the camera through the crosshair (centre of the screen).
function CameraController.aimRay(): Ray
	local camera = Workspace.CurrentCamera
	if not camera then
		return Ray.new(Vector3.zero, Vector3.new(0, 0, -500))
	end
	local cf = camera.CFrame
	if active then
		return Ray.new(cf.Position, cf.LookVector * 500)
	end
	local viewport = camera.ViewportSize
	local unitRay = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	return Ray.new(unitRay.Origin, unitRay.Direction * 500)
end

function CameraController.isActive(): boolean
	return active
end

function CameraController.yaw(): number
	return yaw
end

-- Short FOV kick and shake; strength ~0.2 (pass) to 1 (goal). Disabled when
-- reduced motion is on.
function CameraController.punch(strength: number)
	if reducedMotion then
		return
	end
	local s = math.clamp(strength, 0, 1.5)
	fovKick = math.max(fovKick, 5 * s)
	shake = math.max(shake, 0.25 * s)
end

function CameraController.setSensitivity(value: number)
	sensitivity = math.clamp(value, 0.2, 3)
end

function CameraController.setReducedMotion(value: boolean)
	reducedMotion = value
	if value then
		fovKick = 0
		shake = 0
	end
end

function CameraController.start()
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	MatchClient.MatchChanged:Connect(refreshFilter)
	localPlayer.CharacterAdded:Connect(function()
		active = false
		task.defer(refreshFilter)
	end)
	refreshFilter()
	RunService:BindToRenderStep("HL_Camera", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraController
