--!strict
-- Character animation for every match participant (players and bots).
--
-- Two modes:
--  • Imported animations (Assets.Animations has at least Idle and Run): the
--    local player's character and the bots play Animator tracks; other players
--    animate themselves (their tracks replicate). Any action without an
--    imported animation falls back to the procedural pose for its duration.
--  • Procedural (default): every participant is posed in code through
--    Motor6D.Transform on PreSimulation, which runs after the Animator, so the
--    pose always wins. The default Animate script of the local character is
--    disabled during matches (each client does the same for its own character).
--
-- R6 joint axes (Transform space), established from the R6 C0 frames:
--   RootJoint / Neck: +X = lean (nod) forward, +Y = roll, +Z = yaw.
--   Right Shoulder / Right Hip: +Z = swing forward, +X = towards the body.
--   Left Shoulder / Left Hip: +Z = swing BACKWARD, +X = towards the body.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local MatchClient = require(script.Parent.MatchClient)

local AnimationController = {}

local localPlayer = Players.LocalPlayer

-- Joint slots and their component indices in the pose arrays.
local ROOT, NECK, RS, LS, RH, LH = 1, 2, 3, 4, 5, 6
local DROP = 19 -- vertical drop of the torso (studs)
local SLOTS = 19

local JOINT_NAMES = {
	[ROOT] = "RootJoint",
	[NECK] = "Neck",
	[RS] = "Right Shoulder",
	[LS] = "Left Shoulder",
	[RH] = "Right Hip",
	[LH] = "Left Hip",
}

type Overlay = {
	Kind: string,
	Start: number,
	Duration: number,
	Side: number, -- -1 / 1 for directional actions
	High: boolean,
}

type Rig = {
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Joints: { Motor6D },
	Current: { number },
	Target: { number },
	Phase: number,
	LastYaw: number,
	AirTime: number,
	LandUntil: number,
	Overlay: Overlay?,
	-- Imported animations (asset mode only, for rigs this client animates).
	Tracks: { [string]: AnimationTrack }?,
	Locomotion: string?,
	OwnsTracks: boolean,
}

local rigs: { [Model]: Rig } = {}
local assetMode = Assets.animation("Idle") ~= nil and Assets.animation("Run") ~= nil
local disabledAnimate: LocalScript? = nil

local function now(): number
	return os.clock()
end

local function serverNow(): number
	return MatchClient.now()
end

-- Event kinds → imported animation names.
local ONE_SHOT_ASSETS: { [string]: string } = {
	ShotQuick = "ShotQuick",
	ShotCharged = "ShotCharged",
	JumpShot = "JumpShot",
	PassQuick = "PassQuick",
	PassHigh = "PassHigh",
	Catch = "Catch",
	Intercept = "Intercept",
	Block = "Block",
	Contact = "Contact",
	Stagger = "Stagger",
	DiveLeft = "KeeperDiveLeft",
	DiveRight = "KeeperDiveRight",
	SaveHigh = "KeeperSaveHigh",
	SaveLow = "KeeperSaveLow",
	Celebrate = "Celebrate",
	Dash = "Dash",
	Land = "Land",
}

local OVERLAY_DURATION: { [string]: number } = {
	ShotQuick = 0.38,
	ShotCharged = 0.5,
	JumpShot = 0.5,
	PassQuick = 0.32,
	PassHigh = 0.42,
	Catch = 0.28,
	Intercept = Config.Defense.InterceptWindow + 0.2,
	Block = Config.Defense.BlockDuration,
	Contact = 0.35,
	Stagger = Config.Defense.ContactStun,
	DiveLeft = Config.Keeper.DiveDuration + Config.Keeper.DiveRecovery,
	DiveRight = Config.Keeper.DiveDuration + Config.Keeper.DiveRecovery,
	SaveHigh = 0.4,
	SaveLow = 0.4,
	Celebrate = 2.2,
	Dash = Config.Movement.DashDuration + 0.12,
}

local function attr(model: Model, name: string): any
	return model:GetAttribute(name)
end

-- Helpers --------------------------------------------------------------------------------------------

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) * (1 - t)
end

-- 0 → 1 → 0 bell over the overlay.
local function bell(t: number): number
	return math.sin(math.clamp(t, 0, 1) * math.pi)
end

local function set(target: { number }, joint: number, x: number, y: number, z: number)
	local i = (joint - 1) * 3
	target[i + 1] = x
	target[i + 2] = y
	target[i + 3] = z
end

local function add(target: { number }, joint: number, x: number, y: number, z: number)
	local i = (joint - 1) * 3
	target[i + 1] += x
	target[i + 2] += y
	target[i + 3] += z
end

-- Rig management -------------------------------------------------------------------------------------

local function findJoints(model: Model): { Motor6D }?
	local root = model:FindFirstChild("HumanoidRootPart")
	local torso = model:FindFirstChild("Torso")
	if not root or not torso then
		return nil
	end
	local joints: { Motor6D } = {}
	for slot, name in JOINT_NAMES do
		local parent = if slot == ROOT then root else torso
		local joint = parent:FindFirstChild(name)
		if not joint or not joint:IsA("Motor6D") then
			return nil
		end
		joints[slot] = joint
	end
	return joints
end

local function newPoseArray(): { number }
	local array = table.create(SLOTS, 0)
	return array
end

local function loadTracks(rig: Rig)
	local animator = rig.Humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local created = Instance.new("Animator")
		created.Parent = rig.Humanoid
		animator = created
	end
	local tracks: { [string]: AnimationTrack } = {}
	for name, id in Assets.Animations do
		if id ~= "" then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local ok, track = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			if ok and track then
				local looped = name == "Idle"
					or name == "Run"
					or name == "Sprint"
					or name == "Stance"
					or name == "Dribble"
					or name == "Fall"
					or name == "KeeperReady"
					or name == "ShotCharge"
				track.Looped = looped
				track.Priority = if looped then Enum.AnimationPriority.Movement else Enum.AnimationPriority.Action
				tracks[name] = track
			end
		end
	end
	rig.Tracks = tracks
end

local function isAnimatedByThisClient(model: Model): boolean
	if model == localPlayer.Character then
		return true
	end
	return CollectionService:HasTag(model, "HL_Bot")
end

local function addRig(model: Model)
	if rigs[model] then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local joints = findJoints(model)
	if not root or not root:IsA("BasePart") or not humanoid or not joints then
		return -- not an R6 rig: leave it to the default animations
	end
	local look = root.CFrame.LookVector
	local rig: Rig = {
		Model = model,
		Root = root,
		Humanoid = humanoid,
		Joints = joints,
		Current = newPoseArray(),
		Target = newPoseArray(),
		Phase = 0,
		LastYaw = math.atan2(-look.X, -look.Z),
		AirTime = 0,
		LandUntil = 0,
		Overlay = nil,
		Tracks = nil,
		Locomotion = nil,
		OwnsTracks = assetMode and isAnimatedByThisClient(model),
	}
	if rig.OwnsTracks then
		loadTracks(rig)
	end
	rigs[model] = rig
end

local function removeRig(model: Model)
	local rig = rigs[model]
	if not rig then
		return
	end
	rigs[model] = nil
	if rig.Tracks then
		for _, track in rig.Tracks do
			track:Stop(0.1)
		end
	end
	for _, joint in rig.Joints do
		if joint.Parent then
			joint.Transform = CFrame.identity
		end
	end
end

-- The local character's default Animate script is disabled during matches.
local function setDefaultAnimate(enabled: boolean)
	local character = localPlayer.Character
	if enabled then
		if disabledAnimate and disabledAnimate.Parent then
			disabledAnimate.Enabled = true
		end
		disabledAnimate = nil
		return
	end
	if not character or disabledAnimate then
		return
	end
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		animate.Enabled = false
		disabledAnimate = animate
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				local owned = false
				local rig = rigs[character]
				if rig and rig.Tracks then
					for _, own in rig.Tracks do
						if own == track then
							owned = true
						end
					end
				end
				if not owned then
					track:Stop(0)
				end
			end
		end
	end
end

local function syncRigs()
	local match = MatchClient.Match
	local wanted: { [Model]: boolean } = {}
	if match and match.Phase ~= "Results" then
		for _, participant in match.Participants do
			local model = participant.Model
			if model and model.Parent then
				wanted[model] = true
				addRig(model)
			end
		end
	end
	for model in rigs do
		if not wanted[model] or not model.Parent then
			removeRig(model)
		end
	end
	local inMatch = match ~= nil and MatchClient.me() ~= nil and match.Phase ~= "Results"
	local character = localPlayer.Character
	local ownRig = character ~= nil and rigs[character] ~= nil
	if inMatch and character and not ownRig then
		warn("[Animation] Your character is not R6: set Game Settings > Avatar > R6.")
	end
	-- Keep Roblox's default animations unless this client animates its own rig.
	setDefaultAnimate(not (inMatch and ownRig))
end

-- One-shot actions -----------------------------------------------------------------------------------

local function rigOf(id: any): Rig?
	if typeof(id) ~= "string" then
		return nil
	end
	local participant = MatchClient.participant(id)
	if not participant or not participant.Model then
		return nil
	end
	return rigs[participant.Model]
end

local function play(rig: Rig?, kind: string, side: number?, high: boolean?)
	if not rig then
		return
	end
	local duration = OVERLAY_DURATION[kind] or 0.4
	if rig.Tracks then
		local name = ONE_SHOT_ASSETS[kind]
		local track = name and rig.Tracks[name]
		if track then
			track:Play(0.08)
			return
		end
	end
	rig.Overlay = {
		Kind = kind,
		Start = now(),
		Duration = duration,
		Side = side or 1,
		High = high == true,
	}
end

-- Side (-1 left, +1 right) of a world point relative to a character.
local function sideOf(rig: Rig, point: Vector3): number
	local localPoint = rig.Root.CFrame:PointToObjectSpace(point)
	return if localPoint.X >= 0 then 1 else -1
end

local function onEvent(kind: string, data: any)
	if typeof(data) ~= "table" then
		return
	end
	if kind == "Shot" then
		local shotKind = if data.Jump then "JumpShot" elseif data.Kind == "Charged" then "ShotCharged" else "ShotQuick"
		play(rigOf(data.Id), shotKind)
	elseif kind == "Pass" then
		play(rigOf(data.Id), if data.Kind == "HighPass" or data.Kind == "High" then "PassHigh" else "PassQuick")
	elseif kind == "Catch" then
		play(rigOf(data.Id), "Catch")
	elseif kind == "Intercept" then
		play(rigOf(data.Id), "Intercept")
	elseif kind == "Block" then
		play(rigOf(data.Id), "Block")
	elseif kind == "Contact" then
		play(rigOf(data.FromId), "Contact")
		play(rigOf(data.ToId), "Stagger")
	elseif kind == "Dash" then
		play(rigOf(data.Id), "Dash")
	elseif kind == "Dive" then
		local rig = rigOf(data.Id)
		if rig and typeof(data.Target) == "Vector3" then
			local side = sideOf(rig, data.Target)
			local high = data.Target.Y > rig.Root.Position.Y + 1.5
			play(rig, if side > 0 then "DiveRight" else "DiveLeft", side, high)
		end
	elseif kind == "Save" then
		local rig = rigOf(data.KeeperId)
		if rig and not (rig.Overlay and (rig.Overlay.Kind == "DiveLeft" or rig.Overlay.Kind == "DiveRight")) then
			local high = typeof(data.Position) == "Vector3" and data.Position.Y > rig.Root.Position.Y + 1
			play(rig, if high then "SaveHigh" else "SaveLow", 1, high)
		end
	elseif kind == "Goal" then
		play(rigOf(data.ScorerId), "Celebrate")
	end
end

-- Procedural pose --------------------------------------------------------------------------------------

local function locomotionPose(rig: Rig, dt: number, target: { number })
	local model = rig.Model
	local velocity = rig.Root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local runAmount = math.clamp(speed / Config.Movement.RunSpeed, 0, 1.4)
	local sprint = math.clamp((speed - Config.Movement.RunSpeed) / 6, 0, 1)
	local state = rig.Humanoid:GetState()
	local airborne = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
	local stance = attr(model, "HL_Stance") == true
	local hasBall = attr(model, "HL_HasBall") == true
	local dribbling = attr(model, "HL_Dribbling") == true
	local charging = attr(model, "HL_Charging") == true
	local blocking = attr(model, "HL_Blocking") == true
	local isKeeper = attr(model, "HL_Role") == "Goalkeeper"

	-- Stride: phase advances with distance travelled.
	rig.Phase = (rig.Phase + dt * (4 + speed * 0.42)) % (math.pi * 2)
	local swing = math.sin(rig.Phase)
	local bounce = math.abs(math.cos(rig.Phase))

	-- Turn lean (roll into the turn), from the yaw rate.
	local look = rig.Root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local deltaYaw = (yaw - rig.LastYaw + math.pi) % (math.pi * 2) - math.pi
	rig.LastYaw = yaw
	local yawRate = if dt > 0 then deltaYaw / dt else 0
	local roll = math.clamp(-yawRate * 0.045 * math.min(runAmount, 1), -0.32, 0.32)

	-- Air time / landing.
	if airborne then
		rig.AirTime += dt
	else
		if rig.AirTime > 0.3 then
			rig.LandUntil = now() + 0.22
		end
		rig.AirTime = 0
	end
	local landing = math.clamp((rig.LandUntil - now()) / 0.22, 0, 1)

	-- Base: running.
	local legSwing = 0.95 * math.min(runAmount, 1.2)
	local armSwing = 0.85 * math.min(runAmount, 1.2)
	local lean = 0.06 + 0.16 * math.min(runAmount, 1) + 0.1 * sprint
	set(target, ROOT, lean, roll, 0)
	set(target, NECK, -lean * 0.6, 0, -roll * 0.3)
	set(target, RS, 0.08, 0, armSwing * -swing + 0.1 * runAmount)
	set(target, LS, 0.08, 0, armSwing * -swing - 0.1 * runAmount)
	set(target, RH, 0, 0, legSwing * swing + lean)
	set(target, LH, 0, 0, legSwing * swing - lean)
	target[DROP] = bounce * 0.12 * math.min(runAmount, 1)

	-- Idle breathing.
	if runAmount < 0.1 then
		local breath = math.sin(now() * 2.1) * 0.025
		add(target, ROOT, breath, 0, 0)
		add(target, RS, -0.05, 0, breath)
		add(target, LS, -0.05, 0, -breath)
	end

	if isKeeper and not hasBall then
		-- Keeper ready: wide base, arms open and raised, chest forward.
		local shuffle = math.sin(rig.Phase) * 0.35 * math.min(runAmount, 1)
		set(target, ROOT, 0.18, roll, 0)
		set(target, RS, -1.05, 0, 0.55)
		set(target, LS, -1.05, 0, -0.55)
		set(target, RH, -0.32, 0, 0.18 + shuffle)
		set(target, LH, -0.32, 0, -0.18 + shuffle)
		target[DROP] = 0.25
	elseif stance and not hasBall then
		-- Defensive stance: low, legs wide, arms out to cut lanes.
		local shuffle = math.sin(rig.Phase * 1.3) * 0.3 * math.min(runAmount, 1)
		set(target, ROOT, 0.28, roll * 0.5, 0)
		set(target, NECK, -0.22, 0, 0)
		set(target, RS, -0.8, 0, 0.9)
		set(target, LS, -0.8, 0, -0.9)
		set(target, RH, -0.36, 0, 0.28 + shuffle)
		set(target, LH, -0.36, 0, -0.28 + shuffle)
		target[DROP] = 0.32
	end

	if hasBall and not charging then
		if dribbling then
			local interval = Config.Rules.DribbleBounceInterval
			local t = (serverNow() % interval) / interval
			local pump = math.abs(math.cos(math.pi * t))
			set(target, RS, -0.25, 0, 0.35 + pump * 0.45)
		else
			-- Ball held in front at chest height, left hand guarding.
			set(target, RS, 0.1, 0, 1.15)
			set(target, LS, 0.35, 0, -0.9)
		end
	end

	if charging then
		-- Wind-up: throwing arm cocked behind the head, torso twisted back.
		local pulse = math.sin(now() * 18) * 0.03
		set(target, ROOT, -0.08, 0, 0.45)
		set(target, NECK, 0.05, 0, -0.4)
		set(target, RS, -0.25, 0, 3.55 + pulse)
		set(target, LS, 0.2, 0, -1.35)
	end

	if blocking then
		set(target, RS, -0.12, 0, 3.0)
		set(target, LS, -0.12, 0, -3.0)
		set(target, ROOT, -0.04, 0, 0)
	end

	if airborne then
		local tuck = math.clamp(rig.AirTime * 4, 0, 1)
		add(target, RH, 0, 0, 0.55 * tuck)
		add(target, LH, 0, 0, 0.35 * tuck)
		if not charging and not blocking and not hasBall then
			add(target, RS, -0.35, 0, 0.5 * tuck)
			add(target, LS, -0.35, 0, -0.5 * tuck)
		end
		target[DROP] = 0
	end

	if landing > 0 then
		add(target, ROOT, 0.25 * landing, 0, 0)
		add(target, RH, 0, 0, 0.25 * landing)
		add(target, LH, 0, 0, -0.25 * landing)
		target[DROP] += 0.3 * landing
	end

	-- Stagger after a contact.
	local stunnedUntil = attr(model, "HL_StunnedUntil")
	if typeof(stunnedUntil) == "number" and stunnedUntil > serverNow() then
		local wobble = math.sin(now() * 22) * 0.18
		set(target, ROOT, -0.3, wobble, 0)
		set(target, NECK, 0.2, 0, wobble)
		set(target, RS, -0.9 + wobble, 0, 0.6)
		set(target, LS, -0.9 - wobble, 0, -0.6)
	end

	-- Dive from attributes (keeps the pose even if the event was missed).
	local diveStart = attr(model, "HL_DiveStart")
	if typeof(diveStart) == "number" then
		local elapsed = serverNow() - diveStart
		local total = Config.Keeper.DiveDuration + Config.Keeper.DiveRecovery
		if elapsed >= 0 and elapsed < total and not rig.Overlay then
			local diveTarget = attr(model, "HL_DiveTarget")
			local side = if typeof(diveTarget) == "Vector3" then sideOf(rig, diveTarget) else 1
			rig.Overlay = {
				Kind = if side > 0 then "DiveRight" else "DiveLeft",
				Start = now() - elapsed,
				Duration = total,
				Side = side,
				High = typeof(diveTarget) == "Vector3" and diveTarget.Y > rig.Root.Position.Y + 1.5,
			}
		end
	end
end

local function overlayPose(rig: Rig, overlay: Overlay, target: { number }): boolean
	local t = (now() - overlay.Start) / overlay.Duration
	if t >= 1 then
		rig.Overlay = nil
		return false
	end
	local kind = overlay.Kind
	local b = bell(t)
	if kind == "ShotQuick" or kind == "ShotCharged" or kind == "JumpShot" then
		-- Arm whips from behind the head to forward-down, torso unwinds.
		local strength = if kind == "ShotQuick" then 0.8 else 1
		local whip = ease(t * 1.6)
		set(target, RS, -0.2, 0, 3.4 - whip * 2.6 * strength)
		set(target, LS, 0.2, 0, -1.2 + whip * 0.9)
		set(target, ROOT, -0.05 + whip * 0.35 * strength, 0, 0.45 - whip * 0.85)
		set(target, NECK, -0.1, 0, -0.3 + whip * 0.5)
		if kind == "JumpShot" then
			add(target, RH, 0, 0, 0.7)
			add(target, LH, 0, 0, -0.2)
		end
	elseif kind == "PassQuick" then
		local push = ease(t * 2)
		set(target, RS, 0.05, 0, 1.0 + push * 0.7 * (1 - t))
		set(target, ROOT, 0.05 + push * 0.12 * (1 - t), 0, -0.2 * b)
	elseif kind == "PassHigh" then
		local lift = ease(t * 1.8)
		set(target, RS, -0.1, 0, 2.2 + lift * 0.8)
		set(target, ROOT, -0.08 * b, 0, -0.15 * b)
	elseif kind == "Catch" then
		set(target, RS, 0.25, 0, 1.45 * b + 0.3)
		set(target, LS, 0.25, 0, -1.45 * b - 0.3)
	elseif kind == "Intercept" then
		-- Lunge with the arm stretched across the passing lane.
		set(target, ROOT, 0.35 * b, 0.25 * b * overlay.Side, 0)
		set(target, RS, -0.6 * b, 0, 1.9 * b)
		set(target, LS, -0.3 * b, 0, -0.6 * b)
		add(target, RH, 0, 0, 0.5 * b)
		add(target, LH, 0, 0, 0.4 * b)
	elseif kind == "Block" then
		set(target, RS, -0.15, 0, 3.05)
		set(target, LS, -0.15, 0, -3.05)
	elseif kind == "Contact" then
		-- Shoulder leads into the opponent.
		set(target, ROOT, 0.3 * b, -0.25 * b, -0.45 * b)
		set(target, RS, 0.4 * b, 0, -0.2 * b)
		set(target, LS, 0.5, 0, -0.6 * b)
	elseif kind == "Stagger" then
		local wobble = math.sin(now() * 24) * 0.2 * (1 - t)
		set(target, ROOT, -0.35 * b, wobble, 0)
		set(target, RS, -1.0 * b, 0, 0.5 * b)
		set(target, LS, -1.0 * b, 0, -0.5 * b)
	elseif kind == "DiveLeft" or kind == "DiveRight" then
		local side = overlay.Side
		local diveFraction = Config.Keeper.DiveDuration / overlay.Duration
		local out = ease(t / diveFraction)
		local recover = if t > diveFraction then (t - diveFraction) / (1 - diveFraction) else 0
		local amount = out * (1 - recover)
		local rollAngle = (if overlay.High then 0.9 else 1.25) * amount * -side
		set(target, ROOT, 0.1 * amount, rollAngle, 0)
		-- Arms stretch towards the dive side, above the head for high balls.
		local reach = if overlay.High then 2.9 else 2.2
		if side > 0 then
			set(target, RS, -1.2 * amount, 0, reach * amount)
			set(target, LS, -0.4 * amount, 0, -reach * amount)
		else
			set(target, LS, -1.2 * amount, 0, -reach * amount)
			set(target, RS, -0.4 * amount, 0, reach * amount)
		end
		set(target, RH, -0.5 * amount, 0, 0.2 * amount)
		set(target, LH, -0.5 * amount, 0, -0.2 * amount)
		target[DROP] = 0.6 * amount
	elseif kind == "SaveHigh" then
		set(target, RS, -0.2, 0, 3.0 * b)
		set(target, LS, -0.2, 0, -3.0 * b)
	elseif kind == "SaveLow" then
		set(target, ROOT, 0.45 * b, 0, 0)
		set(target, RS, 0.2, 0, 0.9 * b)
		set(target, LS, 0.2, 0, -0.9 * b)
		target[DROP] = 0.5 * b
	elseif kind == "Celebrate" then
		local pump = math.abs(math.sin(now() * 7))
		set(target, RS, -0.2, 0, 2.6 + pump * 0.4)
		set(target, LS, -0.4, 0, -1.2 - pump * 1.5)
		set(target, ROOT, -0.15 * b, 0, 0)
		set(target, NECK, -0.3 * b, 0, 0)
	elseif kind == "Dash" then
		add(target, ROOT, 0.35 * b, 0, 0)
		add(target, RS, 0, 0, -0.8 * b)
		add(target, LS, 0, 0, 0.8 * b)
	end
	return true
end

local function applyPose(rig: Rig, dt: number)
	local current = rig.Current
	local target = rig.Target
	local alpha = 1 - math.exp(-dt * 16)
	for i = 1, SLOTS do
		current[i] += (target[i] - current[i]) * alpha
	end
	for slot = 1, 6 do
		local i = (slot - 1) * 3
		local rotation = CFrame.fromEulerAnglesXYZ(current[i + 1], current[i + 2], current[i + 3])
		if slot == ROOT then
			-- Joint-space Z is world up for the root joint: a negative Z lowers the torso.
			rig.Joints[slot].Transform = CFrame.new(0, 0, -current[DROP]) * rotation
		else
			rig.Joints[slot].Transform = rotation
		end
	end
end

-- Imported locomotion: one looped track at a time, chosen from the state.
local function updateTracks(rig: Rig)
	local tracks = rig.Tracks
	if not tracks then
		return
	end
	local model = rig.Model
	local velocity = rig.Root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local state = rig.Humanoid:GetState()
	local wanted = "Idle"
	if state == Enum.HumanoidStateType.Freefall then
		wanted = "Fall"
	elseif attr(model, "HL_Charging") == true then
		wanted = "ShotCharge"
	elseif attr(model, "HL_Dribbling") == true then
		wanted = "Dribble"
	elseif attr(model, "HL_Stance") == true then
		wanted = "Stance"
	elseif speed > Config.Movement.RunSpeed + 2 then
		wanted = "Sprint"
	elseif speed > 1.5 then
		wanted = "Run"
	elseif attr(model, "HL_Role") == "Goalkeeper" then
		wanted = "KeeperReady"
	end
	if not tracks[wanted] then
		wanted = if speed > 1.5 then "Run" else "Idle"
	end
	if rig.Locomotion ~= wanted then
		local previous = rig.Locomotion and tracks[rig.Locomotion]
		if previous then
			previous:Stop(0.15)
		end
		local nextTrack = tracks[wanted]
		if nextTrack then
			nextTrack:Play(0.15)
		end
		rig.Locomotion = wanted
	end
	local track = tracks[wanted]
	if track and (wanted == "Run" or wanted == "Sprint") then
		local base = if wanted == "Sprint" then Config.Movement.SprintSpeed else Config.Movement.RunSpeed
		track:AdjustSpeed(math.clamp(speed / base, 0.6, 1.4))
	end
end

local function step(dt: number)
	for model, rig in rigs do
		if not model.Parent or not rig.Root.Parent then
			removeRig(model)
			continue
		end
		local overlay = rig.Overlay
		if rig.OwnsTracks then
			updateTracks(rig)
		end
		-- In asset mode, rigs animated by tracks (ours, bots) or by their owner
		-- (other players) are only posed in code during an action overlay.
		local procedural = not assetMode
		local target = rig.Target
		if procedural then
			locomotionPose(rig, dt, target)
		end
		if overlay then
			if not procedural then
				-- Start the overlay from the neutral pose.
				for i = 1, SLOTS do
					target[i] = 0
				end
			end
			local active = overlayPose(rig, overlay, target)
			if not active and not procedural then
				for _, joint in rig.Joints do
					joint.Transform = CFrame.identity
				end
				continue
			end
			procedural = true
		elseif not procedural then
			continue
		end
		applyPose(rig, dt)
	end
end

function AnimationController.isAssetMode(): boolean
	return assetMode
end

function AnimationController.start()
	MatchClient.MatchChanged:Connect(syncRigs)
	MatchClient.Event:Connect(onEvent)
	localPlayer.CharacterAdded:Connect(function()
		disabledAnimate = nil
		task.defer(syncRigs)
	end)
	RunService.PreSimulation:Connect(step)
	syncRigs()
end

return AnimationController
