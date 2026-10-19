--!strict
-- Turns input intents into server actions, depending on context (holding the
-- ball or not, goalkeeper or field player). Also computes the pass target and
-- the local shot-charge display for the HUD.
--
-- Nothing here decides an outcome: the server validates every action.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local CameraController = require(script.Parent.CameraController)
local InputController = require(script.Parent.InputController)
local MatchClient = require(script.Parent.MatchClient)
local MovementController = require(script.Parent.MovementController)

local ActionController = {}

ActionController.PassTargetChanged = Signal.new() :: Signal.Signal<string?>
-- Local refusals, for HUD feedback: "NoTarget", "Cooldown", "NoBall",
-- "Frozen", "DribbleUsed".
ActionController.ActionFeedback = Signal.new() :: Signal.Signal<string>

local PASS_CONE = math.cos(math.rad(55))
local CONTACT_CONE = math.cos(math.rad(70))
local TARGET_REFRESH = 0.1

local localPlayer = Players.LocalPlayer
local charging = false
local chargeStart = 0
local currentTarget: string? = nil
local refreshTimer = 0
local readyAt: { [string]: number } = {}
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

local function rootOf(model: Model?): BasePart?
	if not model then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function myRoot(): BasePart?
	return rootOf(localPlayer.Character)
end

-- World point under the crosshair.
function ActionController.aimPoint(): Vector3
	local ray = CameraController.aimRay()
	local ignore: { Instance } = {}
	if localPlayer.Character then
		table.insert(ignore, localPlayer.Character)
	end
	local clientFolder = Workspace:FindFirstChild("HL_Client")
	if clientFolder then
		table.insert(ignore, clientFolder)
	end
	aimParams.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(ray.Origin, ray.Direction, aimParams)
	if result then
		return result.Position
	end
	return ray.Origin + ray.Direction
end

-- Direction from the throwing hand to the crosshair point.
function ActionController.aimDirection(): Vector3
	local root = myRoot()
	local point = ActionController.aimPoint()
	if not root then
		return CameraController.aimRay().Direction.Unit
	end
	local hand = root.Position + Vector3.new(0, 1.5, 0)
	local direction = point - hand
	if direction.Magnitude < 0.5 then
		return CameraController.aimRay().Direction.Unit
	end
	return direction.Unit
end

function ActionController.passTarget(): string?
	return currentTarget
end

function ActionController.isCharging(): boolean
	return charging
end

function ActionController.chargeProgress(): number
	if not charging then
		return 0
	end
	return math.clamp((os.clock() - chargeStart) / Config.Ball.ShotChargeTime, 0, 1)
end

-- Best teammate in the aim cone (closest to the aim axis, then distance).
local function computeTarget(): string?
	local match = MatchClient.Match
	local me = MatchClient.me()
	local root = myRoot()
	if not match or not me or not root then
		return nil
	end
	local look = CameraController.aimRay().Direction
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.01 then
		return nil
	end
	flatLook = flatLook.Unit
	local best: string? = nil
	local bestScore = -math.huge
	for _, participant in match.Participants do
		if participant.Id ~= me.Id and participant.Team == me.Team and participant.Connected then
			local other = rootOf(participant.Model)
			if other and participant.SuspendedUntil <= MatchClient.now() then
				local offset = other.Position - root.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local dist = flat.Magnitude
				if dist > 1 and dist <= Config.Ball.PassMaxDistance then
					local dot = flat.Unit:Dot(flatLook)
					if dot >= PASS_CONE then
						-- Favour the aim axis strongly, distance slightly.
						local score = dot * 3 - dist / Config.Ball.PassMaxDistance
						if score > bestScore then
							bestScore = score
							best = participant.Id
						end
					end
				end
			end
		end
	end
	return best
end

local function nearestOpponentInFront(): string?
	local match = MatchClient.Match
	local me = MatchClient.me()
	local root = myRoot()
	if not match or not me or not root then
		return nil
	end
	local forward = root.CFrame.LookVector
	forward = Vector3.new(forward.X, 0, forward.Z).Unit
	local best: string? = nil
	local bestDistance = Config.Defense.ContactRange + 1
	for _, participant in match.Participants do
		if participant.Team ~= me.Team then
			local other = rootOf(participant.Model)
			if other then
				local offset = other.Position - root.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local dist = flat.Magnitude
				if dist < bestDistance and (dist < 1 or flat.Unit:Dot(forward) >= CONTACT_CONE) then
					bestDistance = dist
					best = participant.Id
				end
			end
		end
	end
	return best
end

local function onCooldown(key: string, cooldown: number): boolean
	local t = os.clock()
	if (readyAt[key] or 0) > t then
		ActionController.ActionFeedback:Fire("Cooldown")
		return true
	end
	readyAt[key] = t + cooldown
	return false
end

local function setCharging(value: boolean)
	charging = value
	MovementController.setCharging(value)
	if value then
		chargeStart = os.clock()
	end
end

local function cancelCharge()
	if charging then
		setCharging(false)
		MatchClient.send("ShotCancel", {})
	end
end

local function pass(kind: string)
	if not MatchClient.iHoldBall() then
		ActionController.ActionFeedback:Fire("NoBall")
		return
	end
	cancelCharge()
	if kind == "Aimed" then
		MatchClient.send(
			"Pass",
			{ Kind = "Aimed", Direction = ActionController.aimDirection(), TargetId = currentTarget }
		)
		return
	end
	local target = currentTarget or computeTarget()
	if not target then
		ActionController.ActionFeedback:Fire("NoTarget")
		return
	end
	MatchClient.send("Pass", { Kind = kind, TargetId = target })
end

local function onIntent(intent: string, isDown: boolean)
	if not MatchClient.isPlaying() then
		if not isDown and intent == "Shoot" then
			setCharging(false)
		end
		return
	end
	local me = MatchClient.me()
	if not me then
		return
	end
	local holding = MatchClient.iHoldBall()

	if intent == "Shoot" then
		if isDown then
			if not holding then
				ActionController.ActionFeedback:Fire("NoBall")
				return
			end
			if not charging then
				setCharging(true)
				MatchClient.send("ShotCharge", {})
			end
		elseif charging then
			setCharging(false)
			MatchClient.send("ShotRelease", { Direction = ActionController.aimDirection() })
		end
		return
	end

	if not isDown then
		return
	end

	if intent == "PassQuick" then
		pass("Quick")
	elseif intent == "PassHigh" then
		pass("High")
	elseif intent == "PassAimed" then
		pass("Aimed")
	elseif intent == "Primary" then
		if holding then
			local ball = MatchClient.Ball
			if ball and not ball.Dribbling and ball.HasDribbled then
				-- Restarting a dribble after gathering is illegal: warn instead.
				ActionController.ActionFeedback:Fire("DribbleUsed")
				return
			end
			cancelCharge()
			MatchClient.send("Dribble", {})
		else
			if onCooldown("Block", Config.Defense.BlockCooldown) then
				return
			end
			MatchClient.send("Block", {})
		end
	elseif intent == "Secondary" then
		if holding then
			return
		end
		if me.Role == "Goalkeeper" then
			if onCooldown("Dive", Config.Keeper.DiveCooldown) then
				return
			end
			MatchClient.send("Dive", { Target = ActionController.aimPoint() })
		else
			if onCooldown("Intercept", Config.Defense.InterceptCooldown) then
				return
			end
			MatchClient.send("Intercept", {})
		end
	elseif intent == "Contact" then
		if MovementController.isFrozen() then
			ActionController.ActionFeedback:Fire("Frozen")
			return
		end
		if onCooldown("Contact", Config.Defense.ContactCooldown) then
			return
		end
		MatchClient.send("Contact", { TargetId = nearestOpponentInFront() })
	end
end

local function update(dt: number)
	-- The charge stops as soon as the ball is no longer ours.
	if charging and not MatchClient.iHoldBall() then
		setCharging(false)
	end
	refreshTimer -= dt
	if refreshTimer > 0 then
		return
	end
	refreshTimer = TARGET_REFRESH
	local target = if MatchClient.Match then computeTarget() else nil
	if target ~= currentTarget then
		currentTarget = target
		ActionController.PassTargetChanged:Fire(target)
	end
end

function ActionController.start()
	InputController.Intent:Connect(onIntent)
	InputController.EnabledChanged:Connect(function(isEnabled)
		if not isEnabled then
			setCharging(false)
		end
	end)
	RunService.Heartbeat:Connect(update)
end

return ActionController
