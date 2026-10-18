--!strict
-- Animation procédurale des personnages R6 (joueurs et bots).
--
-- Remplace les animations Roblox par défaut : chaque client anime tous les
-- personnages qu'il voit, en pilotant les Motor6D (Transform) à partir de
-- leur vitesse, de leur état (ballon en main, défense, gardien…) et des
-- événements du match (tir, passe, plongeon, contact, but…).
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
local MatchInput = require(script.Parent.MatchInput)
local State = require(script.Parent.State)

local LocalPlayer = Players.LocalPlayer

local CharacterAnimator = {}

type Action = { Kind: string, Start: number, Duration: number, Side: number }

type Rig = {
	Model: Model,
	Root: BasePart,
	Joints: { [string]: Motor6D },
	Current: { [string]: CFrame },
	Phase: number,
	LastPosition: Vector3,
	Velocity: Vector3,
	LastYaw: number,
	TurnRate: number,
	Action: Action?,
	StunUntil: number,
	CelebrateUntil: number,
	Grounded: boolean,
	AirTime: number,
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
	rigs[model] = {
		Model = model,
		Root = root,
		Joints = joints,
		Current = current,
		Phase = math.random() * 6,
		LastPosition = root.Position,
		Velocity = Vector3.zero,
		LastYaw = 0,
		TurnRate = 0,
		Action = nil,
		StunUntil = 0,
		CelebrateUntil = 0,
		Grounded = true,
		AirTime = 0,
	}
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			rigs[model] = nil
		end
	end)
end

local function play(model: Model?, kind: string, duration: number, side: number?)
	local rig = model and rigs[model]
	if rig then
		rig.Action = { Kind = kind, Start = os.clock(), Duration = duration, Side = side or 1 }
	end
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
	local dribbling = holding and ball ~= nil and ball.Dribbling == true
	return participant, holding, dribbling
end

-- Calcul de la pose ----------------------------------------------------------------------------------

local function easeOut(t: number): number
	return 1 - (1 - t) * (1 - t)
end

local function pose(rig: Rig, dt: number, t: number): ({ [string]: CFrame }, number)
	local root = rig.Root
	local flat = Vector3.new(rig.Velocity.X, 0, rig.Velocity.Z)
	local speed = flat.Magnitude
	local look = root.CFrame.LookVector
	local right = root.CFrame.RightVector
	local forwardSpeed = flat:Dot(Vector3.new(look.X, 0, look.Z).Unit)
	local sideSpeed = flat:Dot(Vector3.new(right.X, 0, right.Z).Unit)
	local amp = clamp(speed / 22, 0, 1.35)
	local participant, holding, dribbling = context(rig.Model)
	local inMatch = participant ~= nil
	local isKeeper = inMatch and participant.Poste == "Gardien"
	local match = State.Match
	local defending = inMatch and match.Possession ~= nil and match.Possession ~= participant.Team and not holding

	-- Cadence de course.
	rig.Phase += dt * (5.5 + 7 * amp)
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
		pitch = 0.1 + 0.24 * amp
		yaw = -swing * 0.2 * amp
		roll = clamp(rig.TurnRate * 0.06, -0.25, 0.25)
		bob = lift * 0.24 * amp - 0.14 * amp
		rf, ro = swing * 1.15 * amp, 0.1
		lf, lo = -swing * 1.15 * amp, 0.1
		rlf, rlo = -swing * 1.0 * amp, 0.02
		llf, llo = swing * 1.0 * amp, 0.02
		neckPitch = -pitch * 0.65
		neckYaw = swing * 0.14 * amp
		if forwardSpeed < -2 then
			-- Course en arrière (repli défensif).
			pitch = -0.05
			rlf, llf = -rlf * 0.6, -llf * 0.6
		end
	elseif shuffling then
		-- Pas chassés latéraux.
		local s = math.sin(rig.Phase * 1.2)
		pitch = 0.18
		bob = -0.18 + math.abs(s) * 0.12
		rlo = 0.18 + s * 0.28
		llo = 0.18 - s * 0.28
		rlf, llf = 0.05, -0.05
		rf, ro = 0.5, 0.35
		lf, lo = 0.5, 0.35
		roll = -math.sign(sideSpeed) * 0.06
	else
		-- Repos : posture athlétique et respiration.
		local breath = math.sin(t * 2.2 + rig.Phase) * 0.03
		pitch = 0.08 + breath * 0.5
		bob = breath * 0.4 - 0.04
		ro, lo = 0.12 + breath, 0.12 + breath
	end

	-- Postures de handball.
	if isKeeper and not holding and speed < 14 then
		-- Gardien en étoile : jambes écartées, bras hauts et ouverts.
		pitch = math.max(pitch, 0.14)
		bob = math.min(bob, -0.12)
		rf, ro = 1.35 + swing * 0.1 * amp, -0.95
		lf, lo = 1.35 - swing * 0.1 * amp, -0.95
		rlo, llo = math.max(rlo, 0.26), math.max(llo, 0.26)
	elseif defending and not isKeeper then
		-- Défenseur : bras levés vers l'avant pour couper les passes.
		local weight = if speed > 14 then 0.45 else 1
		rf = rf + (1.55 - rf) * weight
		ro = ro + (-0.45 - ro) * weight
		lf = lf + (1.55 - lf) * weight
		lo = lo + (-0.45 - lo) * weight
		pitch = math.max(pitch, 0.16)
	end

	if holding then
		if dribbling then
			rf, ro = 0.85 + math.sin(t * 9) * 0.35, 0.22
			pitch = math.max(pitch, 0.18)
		else
			-- Ballon porté à hauteur d'épaule.
			rf, ro = 1.5 + swing * 0.15 * amp, 0.05
		end
		if rig.Model == LocalPlayer.Character and MatchInput.Charge then
			-- Armé du tir : bras derrière la tête, bras gauche vise.
			local charge = MatchInput.Charge :: number
			rf, ro = 2.6 + charge * 0.8, -0.25
			lf, lo = 1.3, 0.05
			yaw = 0.25 + charge * 0.25
			pitch = 0.02
			neckYaw = -yaw * 0.8
			blend = 20
		end
	end

	-- En l'air : tir en suspension ou réception.
	if not rig.Grounded and rig.AirTime > 0.12 then
		local air = clamp(rig.AirTime * 4, 0, 1)
		rlf = rlf + (0.55 - rlf) * air
		llf = llf + (-0.35 - llf) * air
		if holding then
			rf, ro = 3.0, -0.2
			lf, lo = 1.1, 0
			yaw = 0.25
		else
			ro, lo = ro - 0.35 * air, lo - 0.35 * air
			rf, lf = rf + 0.4 * air, lf + 0.4 * air
		end
		pitch = pitch * 0.4
		blend = 18
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
				-- Armé éclair puis fouetté du bras et rotation du buste.
				if progress < 0.25 then
					local k = easeOut(progress / 0.25)
					rf, ro = 1.5 + (3.4 - 1.5) * k, -0.2
					yaw = 0.4 * k
					lf, lo = 1.2, 0
				elseif progress < 0.55 then
					local k = easeOut((progress - 0.25) / 0.3)
					rf, ro = 3.4 - 2.9 * k, -0.15
					yaw = 0.4 - 0.85 * k
					pitch = 0.05 + 0.35 * k
					lf, lo = 1.2 - 1.6 * k, 0.1
					neckPitch = 0.1
				else
					local k = (progress - 0.55) / 0.45
					rf = 0.5 + 0.2 * k
					yaw = -0.45 * (1 - k)
					pitch = 0.4 * (1 - k) + pitch * k
				end
			elseif action.Kind == "Pass" then
				local k = easeOut(math.min(1, progress / 0.5))
				rf, ro = 2.1 - 1.3 * k, -0.1
				yaw = 0.2 - 0.4 * k
				pitch = math.max(pitch, 0.12)
			elseif action.Kind == "Dive" then
				-- Plongeon latéral du gardien.
				local k = math.sin(math.min(1, progress) * math.pi)
				local side = action.Side
				roll = side * 1.15 * k
				rf, ro = 2.9, -0.6 * k
				lf, lo = 2.9, -0.6 * k
				rlo, llo = 0.4 * k, 0.4 * k
				pitch = 0.1
			elseif action.Kind == "Contact" then
				local k = math.sin(math.min(1, progress) * math.pi)
				pitch = 0.15 + 0.35 * k
				yaw = -0.35 * k
				rf, ro = 0.6, -0.2
				lf, lo = 1.6 * k, 0.4
			elseif action.Kind == "Catch" then
				local k = math.sin(math.min(1, progress) * math.pi)
				rf = rf + (1.35 - rf) * k
				lf = lf + (1.35 - lf) * k
				ro, lo = 0.25 * k, 0.25 * k
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
		if measured.Magnitude > 200 then
			measured = Vector3.zero -- téléportation
		end
		rig.Velocity = rig.Velocity:Lerp(measured, math.min(1, dt * 12))
		local look = root.CFrame.LookVector
		local yawAngle = math.atan2(-look.X, -look.Z)
		local deltaYaw = (yawAngle - rig.LastYaw + math.pi) % (2 * math.pi) - math.pi
		rig.LastYaw = yawAngle
		rig.TurnRate = rig.TurnRate + (deltaYaw / dt - rig.TurnRate) * math.min(1, dt * 8)
		-- Au sol ?
		rayParams.FilterDescendantsInstances = { model }
		local hit = Workspace:Raycast(position, Vector3.new(0, -3.8, 0), rayParams)
		rig.Grounded = hit ~= nil
		rig.AirTime = if rig.Grounded then 0 else rig.AirTime + dt

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
			play(data.Model, "Throw", 0.5)
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
