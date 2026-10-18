--!strict
-- Bots : complètent les équipes à l'entraînement et pour tester seul dans
-- Studio. Ils utilisent EXACTEMENT les mêmes actions que les joueurs
-- (passe, tir, dribble, contact, pouvoirs), validées par le match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local BallMath = require(ReplicatedStorage.Shared.BallMath)
local Config = require(ReplicatedStorage.Shared.Config)
local Court = require(ReplicatedStorage.Shared.Court)
local MatchTypes = require(script.Parent.MatchTypes)

type Participant = MatchTypes.Participant

local Bots = {}

Bots.Names = {
	"Kenta",
	"Shota",
	"Riku",
	"Haruto",
	"Yuto",
	"Sota",
	"Daiki",
	"Takumi",
	"Kaede",
	"Mei",
	"Aoi",
	"Hina",
	"Rin",
	"Sakura",
	"Yui",
	"Nao",
}

local SKINS = {
	Color3.fromRGB(255, 220, 190),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(196, 140, 100),
	Color3.fromRGB(140, 94, 64),
}

-- Animations R6 par défaut de Roblox (publiques, utilisables partout).
local ANIMATIONS: { [string]: string } = {
	Idle = "rbxassetid://180435571",
	Walk = "rbxassetid://180426354",
	Jump = "rbxassetid://125750702",
}

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
	local joint = Instance.new("Motor6D")
	joint.Name = name
	joint.Part0 = part0
	joint.Part1 = part1
	joint.C0 = c0
	joint.C1 = c1
	joint.Parent = part0
end

-- Construit un personnage R6 complet sans dépendre d'assets externes.
function Bots.buildRig(name: string): (Model, Humanoid, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	local skin = SKINS[math.random(1, #SKINS)]

	local function limb(partName: string, size: Vector3): Part
		local part = Instance.new("Part")
		part.Name = partName
		part.Size = size
		part.Color = skin
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end

	local root = limb("HumanoidRootPart", Vector3.new(2, 2, 1))
	root.Transparency = 1
	root.CanCollide = false
	local torso = limb("Torso", Vector3.new(2, 2, 1))
	local head = limb("Head", Vector3.new(2, 1, 1))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	local leftArm = limb("Left Arm", Vector3.new(1, 2, 1))
	local rightArm = limb("Right Arm", Vector3.new(1, 2, 1))
	local leftLeg = limb("Left Leg", Vector3.new(1, 2, 1))
	local rightLeg = limb("Right Leg", Vector3.new(1, 2, 1))
	leftArm.CanCollide = false
	rightArm.CanCollide = false
	leftLeg.CanCollide = false
	rightLeg.CanCollide = false

	-- Cheveux style manga : quelques mèches.
	local hairColor = ({
		Color3.fromRGB(20, 20, 26),
		Color3.fromRGB(90, 50, 30),
		Color3.fromRGB(240, 200, 90),
		Color3.fromRGB(230, 60, 60),
		Color3.fromRGB(80, 140, 255),
	})[math.random(1, 5)]
	local hairBase = Instance.new("Part")
	hairBase.Name = "Cheveux"
	hairBase.Size = Vector3.new(1.35, 0.55, 1.35)
	hairBase.Color = hairColor
	hairBase.Massless = true
	hairBase.CanCollide = false
	hairBase.CFrame = head.CFrame * CFrame.new(0, 0.5, 0.05)
	hairBase.Parent = model
	local hairWeld = Instance.new("WeldConstraint")
	hairWeld.Part0 = head
	hairWeld.Part1 = hairBase
	hairWeld.Parent = hairBase
	for i = -1, 1 do
		local spike = Instance.new("WedgePart")
		spike.Name = "Meche"
		spike.Size = Vector3.new(0.3, 0.6, 0.5)
		spike.Color = hairColor
		spike.Massless = true
		spike.CanCollide = false
		spike.CFrame = head.CFrame * CFrame.new(i * 0.4, 0.75, -0.45) * CFrame.Angles(math.rad(-30), 0, 0)
		spike.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = spike
		weld.Parent = spike
	end

	-- Articulations R6 standard.
	motor(
		"RootJoint",
		root,
		torso,
		CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	)
	motor(
		"Neck",
		torso,
		head,
		CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	)
	motor(
		"Right Shoulder",
		torso,
		rightArm,
		CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	)
	motor(
		"Left Shoulder",
		torso,
		leftArm,
		CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	)
	motor(
		"Right Hip",
		torso,
		rightLeg,
		CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	)
	motor(
		"Left Hip",
		torso,
		leftLeg,
		CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.DisplayName = name
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.Movement.JumpPower
	humanoid.WalkSpeed = Config.Movement.WalkSpeed
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	local bodyColors = Instance.new("BodyColors")
	bodyColors.HeadColor3 = skin
	bodyColors.Parent = model

	model.PrimaryPart = root
	return model, humanoid, root
end

-- Animations jouées côté serveur : elles sont répliquées pour un PNJ.
function Bots.animate(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local tracks: { [string]: AnimationTrack } = {}
	for key, id in ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok and track then
			tracks[key] = track
		end
	end
	local current: AnimationTrack? = nil
	local function play(key: string, speed: number?)
		local track = tracks[key]
		if not track then
			return
		end
		if current ~= track then
			if current then
				current:Stop(0.15)
			end
			track:Play(0.15)
			current = track
		end
		if speed then
			track:AdjustSpeed(speed)
		end
	end
	humanoid.Running:Connect(function(speed)
		if speed > 0.6 then
			play("Walk", speed / 16)
		else
			play("Idle")
		end
	end)
	humanoid.Jumping:Connect(function(active)
		if active then
			play("Jump")
		end
	end)
	play("Idle")
end

-- Intelligence artificielle -------------------------------------------------------------

type BotState = {
	NextThink: number,
	Index: number,
	Wander: Vector3?,
	LastPowerTry: number,
}

function Bots.newState(index: number): BotState
	return { NextThink = 0, Index = index, Wander = nil, LastPowerTry = 0 }
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function moveTo(match: any, bot: Participant, localTarget: Vector3)
	local humanoid = bot.Humanoid
	if not humanoid then
		return
	end
	local dims: Court.Dimensions = match.Court.Dims
	local clamped = Vector3.new(
		math.clamp(localTarget.X, -dims.Length / 2 + 1, dims.Length / 2 - 1),
		0,
		math.clamp(localTarget.Z, -dims.Width / 2 + 1, dims.Width / 2 - 1)
	)
	if bot.Poste ~= "Gardien" then
		for _, side in { -1, 1 } do
			clamped = Court.pushOutside(dims, clamped, side, dims.GoalAreaRadius + 1)
		end
	end
	humanoid:MoveTo(match.Court.CFrame:PointToWorldSpace(clamped))
end

local function localOf(match: any, participant: Participant): Vector3?
	local root = participant.Root
	if not root then
		return nil
	end
	return match.Court.CFrame:PointToObjectSpace(root.Position)
end

local function tryPower(match: any, bot: Participant, slot: number, chance: number)
	if math.random() < chance then
		match:actionPower(bot, slot)
	end
end

local function bestPassTarget(match: any, bot: Participant): Participant?
	local attackSide = match:attackSideOf(bot.Team)
	local myLocal = localOf(match, bot)
	local best: Participant? = nil
	local bestScore = -math.huge
	for _, mate: Participant in match:teammatesOf(bot, false) do
		if mate.Poste ~= "Gardien" and match:isActive(mate) then
			local mateLocal = localOf(match, mate)
			if mateLocal and myLocal then
				local progress = (mateLocal.X - myLocal.X) * attackSide
				local distance = (mateLocal - myLocal).Magnitude
				local score = progress - math.abs(distance - 22) * 0.4 + math.random() * 6
				if score > bestScore and distance < 70 then
					best = mate
					bestScore = score
				end
			end
		end
	end
	return best
end

local function shoot(match: any, bot: Participant)
	local dims: Court.Dimensions = match.Court.Dims
	local side = match:attackSideOf(bot.Team)
	local target = Vector3.new(
		side * (dims.Length / 2 + 0.5),
		1.2 + math.random() * (dims.GoalHeight - 2.4),
		(math.random() * 2 - 1) * (dims.GoalWidth / 2 - 1)
	)
	local world = match.Court.CFrame:PointToWorldSpace(target)
	local root = bot.Root
	if not root then
		return
	end
	local origin = root.Position + Vector3.new(0, 1, 0)
	local speed = 120 + math.random() * 30
	local velocity = BallMath.solveLob(origin, world, (world - origin).Magnitude / speed)
	match:actionShoot(bot, velocity.Unit, 0.55 + math.random() * 0.4)
end

local function keeperThink(match: any, bot: Participant)
	local dims: Court.Dimensions = match.Court.Dims
	local ball = match.Ball
	local side = match:defendSideOf(bot.Team)
	local ballLocal = match.Court.CFrame:PointToObjectSpace(ball.Position)

	if ball.Holder == bot then
		if now() - ball.HoldStart > 0.9 then
			local target = bestPassTarget(match, bot)
			if target and target.Root then
				match:actionPass(bot, (target.Root.Position - (bot.Root :: BasePart).Position).Unit, target)
			else
				match:actionPass(bot, match.Court.CFrame:VectorToWorldSpace(Vector3.new(-side, 0.3, 0)).Unit, nil)
			end
		end
		return
	end

	local targetZ = math.clamp(ballLocal.Z * 0.45, -dims.GoalWidth / 2 + 1, dims.GoalWidth / 2 - 1)
	if ball.State == "Flight" and ball.Kind == "Shot" then
		local velocity = match.Court.CFrame:VectorToObjectSpace(ball.Velocity)
		if math.abs(velocity.X) > 1 and math.sign(velocity.X) == side then
			local timeToLine = (side * dims.Length / 2 - ballLocal.X) / velocity.X
			if timeToLine > 0 and timeToLine < 1.2 then
				targetZ = math.clamp(ballLocal.Z + velocity.Z * timeToLine, -dims.GoalWidth / 2, dims.GoalWidth / 2)
				local botLocal = localOf(match, bot)
				if botLocal and math.abs(botLocal.Z - targetZ) > 3 then
					tryPower(match, bot, 1, 0.5)
				end
				tryPower(match, bot, 2, 0.3)
			end
		end
	end
	if bot.Ultimate >= Config.Powers.UltimateMax and ball.Holder and ball.Holder.Team ~= bot.Team then
		if math.abs(ballLocal.X - side * dims.Length / 2) < dims.FreeThrowRadius + 6 then
			tryPower(match, bot, 3, 0.5)
		end
	end
	moveTo(match, bot, Vector3.new(side * (dims.Length / 2 - 2.5), 0, targetZ))
end

local function fieldThink(match: any, bot: Participant, state: BotState)
	local dims: Court.Dimensions = match.Court.Dims
	local ball = match.Ball
	local attackSide = match:attackSideOf(bot.Team)
	local defendSide = -attackSide
	local myLocal = localOf(match, bot)
	if not myLocal then
		return
	end
	local ballLocal = match.Court.CFrame:PointToObjectSpace(ball.Position)
	local holder: Participant? = ball.Holder
	local t = now()

	if match:isBlind(bot) then
		state.Wander = state.Wander or Vector3.new(math.random(-20, 20), 0, math.random(-12, 12))
		moveTo(match, bot, myLocal + (state.Wander :: Vector3))
		return
	end
	state.Wander = nil

	if holder == bot then
		local goalDistance = Court.distanceToGoal(dims, myLocal, attackSide)
		local held = t - ball.HoldStart
		if bot.Energy >= Config.Powers.EnergyMax then
			local archetype = Archetypes.get(bot.ArchetypeId)
			local power2 = archetype and archetype.Powers[2]
			if power2 and power2.Effects[1].Kind == "ShotBuff" then
				match:actionPower(bot, 2)
			end
		end
		if goalDistance < dims.FreeThrowRadius + 7 and held > 0.35 then
			if math.random() < 0.3 then
				match:actionJump(bot)
			end
			shoot(match, bot)
			return
		end
		if held > 2.1 or ball.CarryDistance > Config.Rules.MaxCarryDistance - 4 then
			local target = bestPassTarget(match, bot)
			if target and target.Root and bot.Root then
				match:actionPass(bot, (target.Root.Position - bot.Root.Position).Unit, target)
				return
			elseif not ball.DribbleUsed and not ball.Dribbling then
				match:actionDribble(bot)
			elseif held > 2.5 then
				shoot(match, bot)
				return
			end
		end
		if ball.Dribbling and goalDistance < dims.FreeThrowRadius + 9 then
			match:actionDribble(bot)
		end
		local goalLocal = Vector3.new(attackSide * (dims.Length / 2 - dims.FreeThrowRadius - 2), 0, myLocal.Z * 0.6)
		moveTo(match, bot, goalLocal)
		if t - state.LastPowerTry > 1 then
			state.LastPowerTry = t
			tryPower(match, bot, 1, 0.15)
		end
		return
	end

	local teammates = match:teammatesOf(bot, true)
	-- Le plus proche du ballon de l'équipe va le chercher.
	local function closestToBall(): Participant?
		local best: Participant? = nil
		local bestDistance = math.huge
		for _, mate: Participant in teammates do
			if mate.Poste ~= "Gardien" and mate.Root and match:isActive(mate) then
				local d = (mate.Root.Position - ball.Position).Magnitude
				if d < bestDistance then
					best = mate
					bestDistance = d
				end
			end
		end
		return best
	end

	if not holder and (ball.State == "Flight" or ball.State == "Dead") then
		if closestToBall() == bot then
			local lead = match.Court.CFrame:VectorToObjectSpace(ball.Velocity) * 0.25
			moveTo(match, bot, Vector3.new(ballLocal.X + lead.X, 0, ballLocal.Z + lead.Z))
			if ball.Kind == "Pass" and (ball.Thrower and ball.Thrower.Team ~= bot.Team) then
				if bot.Root and (bot.Root.Position - ball.Position).Magnitude < 10 then
					match:actionContact(bot)
				end
			end
			return
		end
	end

	if holder and holder.Team == bot.Team then
		-- Soutien offensif : s'étaler devant la ligne des 9 m.
		local spread = (state.Index % 3 - 1) * dims.Width * 0.3
		local depth = attackSide * (dims.Length / 2 - dims.FreeThrowRadius - 2 - (state.Index % 2) * 5)
		moveTo(match, bot, Vector3.new(depth, 0, spread))
		return
	end

	local holderRoot = holder and holder.Root
	local botRoot = bot.Root
	if holder and holder.Team ~= bot.Team and holderRoot and botRoot then
		local holderLocal = match.Court.CFrame:PointToObjectSpace(holderRoot.Position)
		if closestToBall() == bot then
			moveTo(match, bot, holderLocal + Vector3.new(defendSide * 2.5, 0, 0))
			local distance = (holderRoot.Position - botRoot.Position).Magnitude
			if distance < Config.Contact.Range and math.random() < 0.18 then
				match:actionContact(bot)
			end
			if bot.Energy >= Config.Powers.EnergyMax and distance < 18 then
				tryPower(match, bot, 2, 0.4)
			end
			if bot.Ultimate >= Config.Powers.UltimateMax then
				tryPower(match, bot, 3, 0.08)
			end
			return
		end
		-- Défense en ligne sur les 9 m de son camp.
		local lineX = defendSide * (dims.Length / 2 - dims.GoalAreaRadius - 3)
		local z = holderLocal.Z * 0.5 + ((state.Index % 3) - 1) * 7
		moveTo(match, bot, Vector3.new(lineX, 0, z))
		return
	end

	-- Ballon libre mais un coéquipier y va : se replacer.
	local backX = attackSide * dims.Length * 0.12
	moveTo(match, bot, Vector3.new(backX, 0, ((state.Index % 3) - 1) * dims.Width * 0.25))
end

function Bots.think(match: any, bot: Participant)
	local state = bot.Bot :: BotState
	local t = now()
	if t < state.NextThink then
		return
	end
	state.NextThink = t + 0.12 + math.random() * 0.06
	if not match:isActive(bot) or match.Phase ~= "Live" then
		return
	end
	if bot.Poste == "Gardien" then
		keeperThink(match, bot)
	else
		fieldThink(match, bot, state)
	end
end

return Bots
