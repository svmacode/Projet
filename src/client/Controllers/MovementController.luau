--!strict
-- Local movement feel: run / sprint / defensive stance speeds, quick
-- acceleration, directional dash with immediate local prediction, and input
-- locks (stagger, suspension, restart thrower, non-playing phases).
--
-- The server owns the real limits (it sets the same speeds and checks every
-- displacement); this controller only makes the movement feel instant.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local InputController = require(script.Parent.InputController)
local MatchClient = require(script.Parent.MatchClient)

local MovementController = {}

MovementController.DashUsed = Signal.new() :: Signal.Signal<Vector3>

local M = Config.Movement
local ACCELERATION = 140 -- studs/s² while speeding up

local localPlayer = Players.LocalPlayer
local sprinting = false
local stance = false
local charging = false
local dashReadyAt = 0
local dashEndsAt = 0
local dashDirection = Vector3.zero
local dashVelocity: LinearVelocity? = nil
local wasFrozen = false
local controlled = false -- true while this controller drives the humanoid

local function now(): number
	return MatchClient.now()
end

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

-- True when the local player must not move at all.
function MovementController.isFrozen(): boolean
	local match = MatchClient.Match
	local me = MatchClient.me()
	if not match or not me then
		return false
	end
	if match.Phase ~= "Playing" and match.Phase ~= "Overtime" then
		return true
	end
	if me.SuspendedUntil > now() then
		return true
	end
	local model = localPlayer.Character
	if model then
		local stunnedUntil = model:GetAttribute("HL_StunnedUntil")
		if typeof(stunnedUntil) == "number" and stunnedUntil > now() then
			return true
		end
		if model:GetAttribute("HL_Suspended") == true or model:GetAttribute("HL_Frozen") == true then
			return true
		end
	end
	-- The thrower of a restart stays on the spot until the throw.
	local restart = match.Restart
	if match.PlayState == "Restart" and restart and restart.ThrowerId == me.Id then
		return true
	end
	if match.PlayState == "Goal" then
		return true
	end
	return false
end

function MovementController.dashReadyAt(): number
	local me = MatchClient.me()
	local serverReady = if me then me.DashReadyAt else 0
	return math.max(dashReadyAt, serverReady)
end

function MovementController.isDashing(): boolean
	return now() < dashEndsAt
end

function MovementController.setCharging(value: boolean)
	charging = value
end

local function targetSpeed(): number
	local me = MatchClient.me()
	local ball = MatchClient.Ball
	local holding = me ~= nil and ball ~= nil and ball.State == "Held" and ball.HolderId == me.Id
	if charging then
		return M.ChargingSpeed
	end
	if stance and not holding then
		return M.StanceSpeed
	end
	if holding and ball and ball.Dribbling then
		return M.DribbleSpeed
	end
	if holding then
		return if sprinting then M.CarrierSpeed else M.RunSpeed
	end
	if me and me.Role == "Goalkeeper" and not sprinting then
		return M.KeeperSpeed
	end
	return if sprinting then M.SprintSpeed else M.RunSpeed
end

local function ensureDashConstraint(root: BasePart): LinearVelocity
	local existing = dashVelocity
	if existing and existing.Parent then
		return existing
	end
	local attachment = root:FindFirstChild("HL_DashAttachment") :: Attachment?
	if not attachment then
		local created = Instance.new("Attachment")
		created.Name = "HL_DashAttachment"
		created.Parent = root
		attachment = created
	end
	local constraint = Instance.new("LinearVelocity")
	constraint.Name = "HL_Dash"
	constraint.Attachment0 = attachment
	constraint.RelativeTo = Enum.ActuatorRelativeTo.World
	constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	constraint.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	constraint.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
	constraint.Enabled = false
	constraint.Parent = root
	dashVelocity = constraint
	return constraint
end

local function tryDash()
	if not MatchClient.isPlaying() or MovementController.isFrozen() then
		return
	end
	if now() < MovementController.dashReadyAt() then
		return
	end
	local model = localPlayer.Character
	local recoveryUntil = if model then model:GetAttribute("HL_RecoveryUntil") else nil
	if typeof(recoveryUntil) == "number" and now() < recoveryUntil then
		return
	end
	local _, root, humanoid = character()
	if not root or not humanoid then
		return
	end
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.01 then
		return
	end
	direction = direction.Unit
	dashDirection = direction
	dashEndsAt = now() + M.DashDuration
	dashReadyAt = now() + M.DashCooldown
	local constraint = ensureDashConstraint(root)
	constraint.VectorVelocity = direction * M.DashSpeed
	constraint.Enabled = true
	MatchClient.send("Dash", { Direction = direction })
	MovementController.DashUsed:Fire(direction)
end

local function release(humanoid: Humanoid?)
	if not controlled then
		return
	end
	controlled = false
	if humanoid then
		humanoid.WalkSpeed = M.RunSpeed
		humanoid.JumpPower = M.JumpPower
	end
	if dashVelocity then
		dashVelocity.Enabled = false
	end
end

local function update(dt: number)
	local _, root, humanoid = character()
	local inMatch = MatchClient.Match ~= nil and MatchClient.me() ~= nil
	if not inMatch or not root or not humanoid then
		release(humanoid)
		return
	end
	controlled = true

	local frozen = MovementController.isFrozen()
	if dashVelocity then
		dashVelocity.Enabled = not frozen and now() < dashEndsAt
	end
	if frozen then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		if not wasFrozen then
			-- Stop any sliding immediately.
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, math.min(v.Y, 0), 0)
		end
		wasFrozen = true
		return
	end
	wasFrozen = false
	humanoid.JumpPower = if charging then 0 else M.JumpPower

	local target = targetSpeed()
	if humanoid.MoveDirection.Magnitude < 0.05 then
		humanoid.WalkSpeed = target
		return
	end
	-- Quick but not instant acceleration; deceleration and turns stay instant.
	local velocity = root.AssemblyLinearVelocity
	local current = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local ramp = math.max(current, 7) + ACCELERATION * dt
	humanoid.WalkSpeed = math.min(target, ramp)
end

local function onIntent(intent: string, isDown: boolean)
	if intent == "Sprint" then
		if sprinting ~= isDown then
			sprinting = isDown
			MatchClient.send("Sprint", { On = isDown })
		end
	elseif intent == "Stance" then
		if stance ~= isDown then
			stance = isDown
			MatchClient.send("Stance", { On = isDown })
		end
	elseif intent == "Dash" and isDown then
		tryDash()
	end
end

function MovementController.isSprinting(): boolean
	return sprinting
end

function MovementController.isInStance(): boolean
	return stance
end

function MovementController.start()
	InputController.Intent:Connect(onIntent)
	InputController.EnabledChanged:Connect(function(isEnabled)
		if not isEnabled then
			sprinting = false
			stance = false
			charging = false
		end
	end)
	localPlayer.CharacterAdded:Connect(function()
		dashVelocity = nil
		controlled = false
		wasFrozen = false
	end)
	RunService.Heartbeat:Connect(update)
end

-- Kept for other controllers that want to know the last dash direction.
function MovementController.lastDashDirection(): Vector3
	return dashDirection
end

return MovementController
