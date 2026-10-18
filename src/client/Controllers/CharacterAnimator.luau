--!strict
-- Animation des personnages R6 (joueurs et bots), en deux modes :
--
-- 1. Animations importées (Shared/Assets.Animations) : si au moins Idle et
--    Run sont renseignées, la locomotion et les actions passent par
--    l'Animator (transitions, priorités). Le joueur local joue ses pistes
--    (elles se répliquent aux autres) ; chaque client joue celles des bots.
--    Une action sans animation importée retombe sur sa version procédurale.
-- 2. Procédural (par défaut) : chaque client anime tous les personnages en
--    pilotant les Motor6D (Transform) à partir de leur vitesse, de leur
--    accélération (poids du corps), des virages, des sauts et réceptions, de
--    leur état (ballon, tir armé, défense, gardien) et des événements du match.
--
-- Axes des articulations R6 (repère du C0) :
--   RootJoint / Neck : X = tangage (+ = vers l'avant), Y = roulis, Z = lacet
--   Épaule / hanche  : Z = balancier (droite : + = avant ; gauche : + = arrière)
--                      X = écart (+ = vers l'intérieur, − = vers l'extérieur)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local MatchInput = require(script.Parent.MatchInput)
local State = require(script.Parent.State)

local LocalPlayer = Players.LocalPlayer

local CharacterAnimator = {}

type Action = { Kind: string, Start: number, Duration: number, Side: number }

type Tracks = { [string]: AnimationTrack }

type Rig = {
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid?,
	Joints: { [string]: Motor6D },
	Current: { [string]: CFrame },
	Phase: number,
	LastPosition: Vector3,
	Velocity: Vector3,
	Accel: Vector3, -- accélération lissée (poids du corps)
	LastYaw: number,
	TurnRate: number,
	Action: Action?,
	StunUntil: number,
	CelebrateUntil: number,
	Grounded: boolean,
	AirTime: number,
	Landing: number, -- impact de réception (0..1), décroît
	-- Mode « animations importées » : pistes chargées (nil = procédural).
	Tracks: Tracks?,
	Loco: string?, -- piste de locomotion en cours
}

local JOINTS: { [string]: string } = {
	Root = "RootJoint",
	Neck = "Neck",
	RightArm = "Right Shoulder",
	LeftArm = "Left Shoulder",
	RightLeg = "Right Hip",
	LeftLeg = "Left Hip",
}

local rigs: { [Model]: Rig } = {}

-- Le mode « pistes » n'est actif que si la locomotion de base est importée.
local USE_TRACKS = Assets.animation("Idle") ~= nil and Assets.animation("Run") ~= nil
local LOOPED = { Idle = true, Run = true, Sprint = true, Fall = true, KeeperReady = true, ShootCharge = true }
local PRIORITY: { [string]: Enum.AnimationPriority } = {
	Idle = Enum.AnimationPriority.Idle,
	KeeperReady = Enum.AnimationPriority.Idle,
	Run = Enum.AnimationPriority.Movement,
	Sprint = Enum.AnimationPriority.Movement,
	Jump = Enum.AnimationPriority.Movement,
	Fall = Enum.AnimationPriority.Movement,
	ShootCharge = Enum.AnimationPriority.Action,
}
-- Événement de match -> nom de l'animation importée.
local ACTION_ASSET: { [string]: string } = {
	Throw = "Shoot",
	Pass = "Pass",
	Dive = "Dive",
	Contact = "Contact",
	Catch = "Catch",
	Dash = "Dash",
	Block = "Block",
}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function clamp(x: number, a: number, b: number): number
	return math.clamp(x, a, b)
end

-- Fabrique des transformations ------------------------------------------------------------------

local function torso(pitch: number, roll: number, yaw: number, bob: number): CFrame
	return CFrame.new(0, 0, bob) * CFrame.Angles(pitch, roll, yaw)
end

local function arm(side: number, forward: number, outward: number): CFrame
	-- side = 1 (droite) ou -1 (gauche)
	return CFrame.Angles(-outward, 0, forward * side)
end

local function leg(side: number, forward: number, outward: number): CFrame
	return CFrame.Angles(-outward, 0, forward * side)
end

-- Gestion des personnages ------------------------------------------------------------------------

local function disableDefaultAnimations(model: Model)
	local animate = model:FindFirstChild("Animate")
	if animate and animate:IsA("BaseScript") then
		(animate :: BaseScript).Enabled = false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
	end
end

local function loadTracks(humanoid: Humanoid): Tracks?
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local created = Instance.new("Animator")
		created.Parent = humanoid
		animator = created
	end
	local result: Tracks = {}
	for name in Assets.Animations do
		local id = Assets.animation(name)
		if id then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local ok, loaded = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			if ok and loaded then
				loaded.Looped = LOOPED[name] == true
				loaded.Priority = PRIORITY[name] or Enum.AnimationPriority.Action
				result[name] = loaded
			end
		end
	end
	return if result.Idle and result.Run then result else nil
end

local function track(model: Model)
	if rigs[model] then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5)
	local torsoPart = model:WaitForChild("Torso", 5)
	if not root or not torsoPart or not root:IsA("BasePart") then
		return -- R15 : on garde les animations Roblox.
	end
	local joints: { [string]: Motor6D } = {}
	for key, name in JOINTS do
		local holder = if key == "Root" then root else torsoPart
		local joint = holder:WaitForChild(name, 3)
		if joint and joint:IsA("Motor6D") then
			joints[key] = joint
		end
	end
	if not joints.Root or not joints.RightArm or not joints.RightLeg then
		return
	end
	if model == LocalPlayer.Character then
		disableDefaultAnimations(model)
	end
	local current = {}
	for key in joints do
		current[key] = CFrame.identity
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local isBot = CollectionService:HasTag(model, "HL_Bot")
	local tracks: Tracks? = nil
	if USE_TRACKS and humanoid then
		if model ~= LocalPlayer.Character and not isBot then
			-- Autre joueur : ses pistes sont jouées par son client et répliquées.
			return
		end
		tracks = loadTracks(humanoid)
	end
	rigs[model] = {
		Model = model,
		Root = root,
		Humanoid = humanoid,
		Joints = joints,
		Current = current,
		Phase = math.random() * 6,
		LastPosition = root.Position,
		Velocity = Vector3.zero,
		Accel = Vector3.zero,
		LastYaw = 0,
		TurnRate = 0,
		Action = nil,
		StunUntil = 0,
		CelebrateUntil = 0,
		Grounded = true,
		AirTime = 0,
		Landing = 0,
		Tracks = tracks,
		Loco = nil,
	}
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			rigs[model] = nil
		end
	end)
end

local function play(model: Model?, kind: string, duration: number, side: number?)
	local rig = model and rigs[model]
	if not rig then
		return
	end
	local tracks = rig.Tracks
	local assetName = ACTION_ASSET[kind]
	local actionTrack = tracks and assetName and tracks[assetName]
	if actionTrack then
		actionTrack:Play(0.08)
		return
	end
	rig.Action = { Kind = kind, Start = os.clock(), Duration = duration, Side = side or 1 }
end

-- Contexte de match pour un personnage.
local function context(model: Model): (any, boolean, boolean)
	local match = State.Match
	local ball = State.Ball
	local participant = nil
	if match and match.Phase ~= "Ended" then
		for _, entry in match.Participants do
			if entry.Model == model then
				participant = entry
				break
			end
		end
	end
	local holding = ball ~= nil and ball.State == "Held" and ball.Holder == model
	return participant, holding, model:GetAttribute("ShotCharging") == true
end

-- Calcul de la pose ----------------------------------------------------------------------------------

local function easeOut(t: number): number
	return 1 - (1 - t) * (1 - t)
end

local REFERENCE_SPEED = Config.Movement.WalkSpeed

local function pose(rig: Rig, dt: number, t: number): ({ [string]: CFrame }, number)
	local root = rig.Root
	local flat = Vector3.new(rig.Velocity.X, 0, rig.Velocity.Z)
	local speed = flat.Magnitude
	local look = root.CFrame.LookVector
	local right = root.CFrame.RightVector
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit
	local flatRight = Vector3.new(right.X, 0, right.Z).Unit
	local forwardSpeed = flat:Dot(flatLook)
	local sideSpeed = flat:Dot(flatRight)
	local forwardAccel = rig.Accel:Dot(flatLook)
	local amp = clamp(speed / REFERENCE_SPEED, 0, 1.4)
	local participant, holding, charging = context(rig.Model)
	local inMatch = participant ~= nil
	local isKeeper = inMatch and participant.Poste == "Gardien"
	local match = State.Match
	local defending = inMatch and match.Possession ~= nil and match.Possession ~= participant.Team and not holding

	-- Cadence de course : plus rapide avec la vitesse, foulée plus ample.
	rig.Phase += dt * (6 + 7.5 * amp)
	local swing = math.sin(rig.Phase)
	local lift = math.abs(math.cos(rig.Phase))

	local pitch, roll, yaw, bob = 0.06, 0, 0, 0
	local neckPitch, neckRoll, neckYaw = -0.03, 0, 0
	local rf, ro = 0.22, 0.12 -- bras droit : balancier, écart
	local lf, lo = 0.22, 0.12
	local rlf, rlo = 0.06, 0.06 -- jambe droite
	local llf, llo = -0.06, 0.06
	local blend = 14

	local shuffling = math.abs(sideSpeed) > math.abs(forwardSpeed) * 1.2 and speed > 4

	if speed > 1.5 and not shuffling then
		-- Course athlétique : buste penché, bras qui pompent, contre-rotation.
		pitch = 0.08 + 0.26 * amp
		yaw = -swing * 0.2 * amp
		bob = lift * 0.26 * amp - 0.14 * amp
		rf, ro = swing * 1.2 * amp, 0.1
		lf, lo = -swing * 1.2 * amp, 0.1
		rlf, rlo = -swing * 1.05 * amp, 0.02
		llf, llo = swing * 1.05 * amp, 0.02
		neckPitch = -pitch * 0.65
		neckYaw = swing * 0.12 * amp
		if forwardSpeed < -2 then
			-- Course en arrière (repli défensif).
			pitch = -0.06
			rlf, llf = -rlf * 0.6, -llf * 0.6
		end
	elseif shuffling then
		-- Pas chassés latéraux, centre de gravité bas.
		local s = math.sin(rig.Phase * 1.2)
		pitch = 0.2
		bob = -0.2 + math.abs(s) * 0.12
		rlo = 0.18 + s * 0.28
		llo = 0.18 - s * 0.28
		rlf, llf = 0.05, -0.05
		rf, ro = 0.5, 0.35
		lf, lo = 0.5, 0.35
		roll = -math.sign(sideSpeed) * 0.08
	else
		-- Repos : posture athlétique, respiration, poids qui bascule doucement.
		local breath = math.sin(t * 2.2 + rig.Phase) * 0.03
		local sway = math.sin(t * 0.9 + rig.Phase) * 0.025
		pitch = 0.08 + breath * 0.5
		roll = sway
		bob = breath * 0.4 - 0.04
		ro, lo = 0.12 + breath, 0.12 + breath
		rlo, llo = 0.06 + sway, 0.06 - sway
	end

	-- Poids du corps : on se penche dans l'accélération, on se redresse au
	-- freinage, et on s'incline vers l'intérieur des virages.
	pitch += clamp(forwardAccel * 0.0035, -0.22, 0.2)
	roll += clamp(rig.TurnRate * math.min(speed, 30) * 0.0024, -0.32, 0.32)

	-- Postures de handball.
	if isKeeper and not holding and speed < 16 then
		-- Gardien en étoile : jambes écartées, bras hauts et ouverts, sur les appuis.
		local ready = math.sin(t * 6 + rig.Phase) * 0.04
		pitch = math.max(pitch, 0.14)
		bob = math.min(bob, -0.14) + ready
		rf, ro = 1.35 + swing * 0.1 * amp, -0.95
		lf, lo = 1.35 - swing * 0.1 * amp, -0.95
		rlo, llo = math.max(rlo, 0.28), math.max(llo, 0.28)
	elseif defending and not isKeeper then
		-- Défenseur : bras levés vers l'avant pour couper les passes.
		local weight = if speed > 16 then 0.45 else 1
		rf = rf + (1.55 - rf) * weight
		ro = ro + (-0.45 - ro) * weight
		lf = lf + (1.55 - lf) * weight
		lo = lo + (-0.45 - lo) * weight
		pitch = math.max(pitch, 0.16)
	end

	if holding then
		-- Ballon porté à hauteur d'épaule, l'autre bras équilibre.
		rf, ro = 1.5 + swing * 0.15 * amp, 0.05
		local charge: number? = nil
		if rig.Model == LocalPlayer.Character then
			charge = MatchInput.Charge
		elseif charging then
			charge = 0.6
		end
		if charge then
			-- Armé du tir : bras loin derrière la tête, buste vrillé, bras gauche vise.
			rf, ro = 2.7 + charge * 0.7, -0.3
			lf, lo = 1.35, 0.05
			yaw = 0.3 + charge * 0.25
			pitch = 0.0 - charge * 0.06
			neckYaw = -yaw * 0.8
			rlf, llf = rlf * 0.5 + 0.2, llf * 0.5 - 0.25
			blend = 20
		end
	end

	-- En l'air : montée bras hauts, descente bras écartés pour l'équilibre.
	if not rig.Grounded and rig.AirTime > 0.08 then
		local air = clamp(rig.AirTime * 5, 0, 1)
		local rising = rig.Velocity.Y > 2
		rlf = rlf + ((if rising then 0.7 else 0.35) - rlf) * air
		llf = llf + ((if rising then -0.2 else -0.45) - llf) * air
		if holding then
			rf, ro = 3.0, -0.2
			lf, lo = 1.1, 0
			yaw = 0.25
		elseif rising then
			rf, lf = rf + (1.4 - rf) * air, lf + (1.4 - lf) * air
		else
			ro, lo = ro - 0.5 * air, lo - 0.5 * air
		end
		pitch = pitch * 0.4 + (if rising then -0.05 else 0.08)
		blend = 18
	end

	-- Réception d'un saut : on encaisse (buste qui plonge, bassin qui descend).
	if rig.Landing > 0 then
		local k = rig.Landing
		pitch += 0.28 * k
		bob -= 0.5 * k
		rlf, llf = rlf + 0.3 * k, llf - 0.3 * k
		ro, lo = ro - 0.25 * k, lo - 0.25 * k
	end

	-- Actions ponctuelles (prioritaires).
	local action = rig.Action
	if action then
		local progress = (os.clock() - action.Start) / action.Duration
		if progress >= 1 then
			rig.Action = nil
		else
			blend = 28
			if action.Kind == "Throw" then
				-- Armé éclair puis fouetté du bras, rotation du buste et transfert du poids.
				if progress < 0.22 then
					local k = easeOut(progress / 0.22)
					rf, ro = 1.5 + (3.4 - 1.5) * k, -0.2
					yaw = 0.45 * k
					lf, lo = 1.2, 0
				elseif progress < 0.55 then
					local k = easeOut((progress - 0.22) / 0.33)
					rf, ro = 3.4 - 3.0 * k, -0.15
					yaw = 0.45 - 0.95 * k
					pitch = 0.05 + 0.4 * k
					lf, lo = 1.2 - 1.7 * k, 0.1
					rlf, llf = -0.35 * k, 0.45 * k
					neckPitch = 0.1
				else
					local k = (progress - 0.55) / 0.45
					rf = 0.4 + 0.3 * k
					yaw = -0.5 * (1 - k)
					pitch = 0.45 * (1 - k) + pitch * k
				end
			elseif action.Kind == "Pass" then
				local k = easeOut(math.min(1, progress / 0.45))
				rf, ro = 2.1 - 1.4 * k, -0.1
				yaw = 0.2 - 0.45 * k
				pitch = math.max(pitch, 0.12)
			elseif action.Kind == "Dash" then
				-- Départ explosif : buste très penché, bras rejetés en arrière.
				local k = math.sin(math.min(1, progress) * math.pi)
				pitch = 0.35 + 0.35 * k
				rf, ro = -0.9 * k, 0.15
				lf, lo = -0.9 * k, 0.15
				rlf, llf = -0.6 * k, 0.7 * k
				bob = -0.15 * k
			elseif action.Kind == "Dive" then
				-- Plongeon latéral du gardien.
				local k = math.sin(math.min(1, progress) * math.pi)
				local side = action.Side
				roll = side * 1.2 * k
				rf, ro = 2.9, -0.6 * k
				lf, lo = 2.9, -0.6 * k
				rlo, llo = 0.4 * k, 0.4 * k
				pitch = 0.1
			elseif action.Kind == "Contact" then
				local k = math.sin(math.min(1, progress) * math.pi)
				pitch = 0.15 + 0.4 * k
				yaw = -0.35 * k
				rf, ro = 0.6, -0.2
				lf, lo = 1.6 * k, 0.4
			elseif action.Kind == "Catch" then
				local k = math.sin(math.min(1, progress) * math.pi)
				rf = rf + (1.35 - rf) * k
				lf = lf + (1.35 - lf) * k
				ro, lo = 0.25 * k, 0.25 * k
				pitch += 0.1 * k
			elseif action.Kind == "Block" then
				local k = math.sin(math.min(1, progress) * math.pi)
				rf, ro = 2.9 * k + rf * (1 - k), -0.25
				lf, lo = 2.9 * k + lf * (1 - k), -0.25
				pitch = -0.05
			elseif action.Kind == "Power" then
				local k = math.sin(math.min(1, progress) * math.pi)
				rf, ro = 2.6 * k, -0.7 * k
				lf, lo = 2.6 * k, -0.7 * k
				pitch = -0.15 * k
				bob = -0.1 * k
			end
		end
	end

	-- Étourdi : vacille, bras ballants.
	if rig.StunUntil > os.clock() then
		roll = math.sin(t * 11) * 0.18
		pitch = 0.22
		rf, ro = -0.15, -0.35
		lf, lo = -0.15, -0.35
		neckRoll = math.sin(t * 9) * 0.25
		blend = 10
	end

	-- Célébration après un but.
	if rig.CelebrateUntil > os.clock() then
		local hop = math.abs(math.sin(t * 7))
		rf, ro = 2.9 + math.sin(t * 7) * 0.1, -0.5
		lf, lo = 2.9 - math.sin(t * 7) * 0.1, -0.5
		pitch = -0.12
		bob = hop * 0.35
		neckPitch = -0.25
		blend = 16
	end

	return {
		Root = torso(pitch, roll, yaw, bob),
		Neck = CFrame.Angles(neckPitch, neckRoll, neckYaw),
		RightArm = arm(1, rf, ro),
		LeftArm = arm(-1, lf, lo),
		RightLeg = leg(1, rlf, rlo),
		LeftLeg = leg(-1, llf, llo),
	},
		blend
end

-- Locomotion par pistes importées.
local function setLoco(rig: Rig, name: string)
	local tracks = rig.Tracks :: Tracks
	if not tracks[name] then
		name = if name == "KeeperReady" or name == "Fall" or name == "Jump" then "Idle" else "Run"
	end
	if rig.Loco == name then
		return
	end
	local previous = rig.Loco and tracks[rig.Loco]
	if previous then
		previous:Stop(0.18)
	end
	rig.Loco = name
	tracks[name]:Play(0.18)
end

local function stepTracks(rig: Rig, speed: number)
	local tracks = rig.Tracks :: Tracks
	local participant, holding, charging = context(rig.Model)
	if not rig.Grounded and rig.AirTime > 0.1 then
		setLoco(rig, if rig.Velocity.Y > 2 then "Jump" else "Fall")
	elseif speed > REFERENCE_SPEED * 1.3 and tracks.Sprint then
		setLoco(rig, "Sprint")
	elseif speed > 1.5 then
		setLoco(rig, "Run")
		tracks.Run:AdjustSpeed(clamp(speed / REFERENCE_SPEED, 0.5, 1.6))
	elseif participant and participant.Poste == "Gardien" and not holding then
		setLoco(rig, "KeeperReady")
	else
		setLoco(rig, "Idle")
	end
	local charge = tracks.ShootCharge
	if charge then
		local wantCharge = holding and ((rig.Model == LocalPlayer.Character and MatchInput.Charge ~= nil) or charging)
		if wantCharge and not charge.IsPlaying then
			charge:Play(0.1)
		elseif not wantCharge and charge.IsPlaying then
			charge:Stop(0.1)
		end
	end
	local celebrate = tracks.Celebrate
	if celebrate and rig.CelebrateUntil > os.clock() and not celebrate.IsPlaying then
		celebrate:Play(0.15)
	end
	local stunned = tracks.Stunned
	if stunned then
		local wantStun = rig.StunUntil > os.clock()
		if wantStun and not stunned.IsPlaying then
			stunned:Play(0.1)
		elseif not wantStun and stunned.IsPlaying then
			stunned:Stop(0.2)
		end
	end
end

local function step(dt: number)
	if dt <= 0 then
		return
	end
	local t = os.clock()
	for model, rig in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		local root = rig.Root
		-- Vitesse mesurée par déplacement (fiable aussi pour les autres joueurs).
		local position = root.Position
		local measured = (position - rig.LastPosition) / dt
		rig.LastPosition = position
		if measured.Magnitude > 220 then
			measured = rig.Velocity -- téléportation
		end
		local previous = rig.Velocity
		rig.Velocity = previous:Lerp(measured, math.min(1, dt * 12))
		local accel = (rig.Velocity - previous) / dt
		rig.Accel = rig.Accel:Lerp(Vector3.new(accel.X, 0, accel.Z), math.min(1, dt * 6))
		local look = root.CFrame.LookVector
		local yawAngle = math.atan2(-look.X, -look.Z)
		local deltaYaw = (yawAngle - rig.LastYaw + math.pi) % (2 * math.pi) - math.pi
		rig.LastYaw = yawAngle
		rig.TurnRate = rig.TurnRate + (deltaYaw / dt - rig.TurnRate) * math.min(1, dt * 8)
		-- Au sol ? (réception = impact proportionnel au temps passé en l'air)
		rayParams.FilterDescendantsInstances = { model }
		local hit = Workspace:Raycast(position, Vector3.new(0, -3.8, 0), rayParams)
		local grounded = hit ~= nil
		if grounded and not rig.Grounded and rig.AirTime > 0.25 then
			rig.Landing = clamp(rig.AirTime * 1.4, 0.35, 1)
		end
		rig.Grounded = grounded
		rig.AirTime = if grounded then 0 else rig.AirTime + dt
		rig.Landing = math.max(0, rig.Landing - dt * 4.5)

		if rig.Tracks then
			stepTracks(rig, Vector3.new(rig.Velocity.X, 0, rig.Velocity.Z).Magnitude)
			-- Les actions sans animation importée restent procédurales.
			if not rig.Action then
				continue
			end
		end

		local targets, blend = pose(rig, dt, t)
		local alpha = 1 - math.exp(-dt * blend)
		for key, joint in rig.Joints do
			local target = targets[key]
			if target then
				local current = rig.Current[key]:Lerp(target, alpha)
				rig.Current[key] = current
				joint.Transform = current
			end
		end
	end
end

local function watchCharacter(player: Player)
	local function onCharacter(character: Model)
		task.defer(track, character)
		-- Le script Animate peut arriver après : on le coupe dès qu'il apparaît.
		if player == LocalPlayer then
			character.ChildAdded:Connect(function(child)
				if child.Name == "Animate" then
					task.defer(disableDefaultAnimations, character)
				end
			end)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

local function powerHasDive(archetypeId: string?, slot: number): boolean
	local archetype = Archetypes.get(archetypeId)
	local power = archetype and archetype.Powers[slot]
	if not power then
		return false
	end
	for _, effect in power.Effects do
		if effect.Kind == "Dive" then
			return true
		end
	end
	return false
end

function CharacterAnimator.start()
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	for _, model in CollectionService:GetTagged("HL_Bot") do
		if model:IsA("Model") then
			task.spawn(track, model)
		end
	end
	CollectionService:GetInstanceAddedSignal("HL_Bot"):Connect(function(model)
		if model:IsA("Model") then
			task.spawn(track, model)
		end
	end)

	State.MatchEvent:Connect(function(kind, data)
		if type(data) ~= "table" then
			return
		end
		if kind == "Shot" then
			play(data.Model, "Throw", 0.48)
		elseif kind == "Dash" then
			play(data.Model, "Dash", 0.28)
		elseif kind == "Block" then
			play(data.Model, "Block", 0.4)
		elseif kind == "Pass" then
			play(data.Model, "Pass", 0.32)
			if data.Target then
				task.delay(0.3, play, data.Target, "Catch", 0.3)
			end
		elseif kind == "Contact" then
			play(data.From, "Contact", 0.35)
			local victim = data.To and rigs[data.To]
			if victim then
				victim.StunUntil = os.clock() + 0.6
			end
		elseif kind == "Power" then
			local rig = data.Model and rigs[data.Model]
			if rig and powerHasDive(data.ArchetypeId, data.Slot) then
				local right = rig.Root.CFrame.RightVector
				local side = if rig.Velocity:Dot(right) >= 0 then -1 else 1
				play(data.Model, "Dive", 0.7, side)
			elseif data.Slot == 3 then
				play(data.Model, "Power", 0.8)
			end
		elseif kind == "Status" and data.Kind == "Stun" then
			local rig = data.Model and rigs[data.Model]
			if rig then
				rig.StunUntil = os.clock() + (data.Duration or 1)
			end
		elseif kind == "Save" then
			play(data.Model, "Catch", 0.35)
		elseif kind == "Interception" or kind == "Steal" then
			play(data.Model, "Catch", 0.3)
		elseif kind == "Goal" then
			local match = State.Match
			if match then
				for _, participant in match.Participants do
					local rig = participant.Model and rigs[participant.Model]
					if rig and participant.Team == data.Team then
						rig.CelebrateUntil = os.clock() + 2.6
					end
				end
			end
		end
	end)

	RunService.PreSimulation:Connect(step)
end

return CharacterAnimator
