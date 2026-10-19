--!strict
-- DEVELOPMENT bots (Phase 1): fill empty slots so one person can test a real
-- match. They are deliberately simple but follow the rules, and they act ONLY
-- through Match.act, exactly like players (same validation, same cooldowns).
--
-- Goalkeeper: stays between the ball and the goal, reacts to incoming shots
-- with a human-like delay and dives towards the predicted point.
-- Field players: support the attack in lanes, dribble towards the goal,
-- pass to open teammates, shoot from range, press the carrier legally,
-- mark and intercept passes.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallPhysics = require(ReplicatedStorage.Shared.BallPhysics)
local Config = require(ReplicatedStorage.Shared.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local Appearance = require(script.Parent.Appearance)
local MatchTypes = require(script.Parent.MatchTypes)

type Participant = MatchTypes.Participant

local Bots = {}

local THINK_INTERVAL = 0.1
local TAG = "HL_Bot"

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function otherTeam(team: string): string
	return if team == "Red" then "Blue" else "Red"
end

type Brain = {
	Random: Random,
	NextThink: number,
	LastTarget: Vector3?,
	HoldDecisionAt: number,
	ShootAt: number?,
	NextContact: number,
	NextIntercept: number,
	Incoming: { Point: Vector3, ArrivalTime: number, SeenAt: number }?,
	ReactionDelay: number,
	DashDirection: Vector3?,
	Lane: number,
}

-- Builds an R6 body for a bot participant and binds it to the match.
function Bots.spawn(match: any, p: Participant, folder: Instance)
	local description = Instance.new("HumanoidDescription")
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	if not ok or not result then
		warn(`[Bots] could not create a body for {p.Name}: {result}`)
		p.Connected = false
		return
	end
	local model = result :: Model
	model.Name = p.Name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = p.Name
		humanoid.BreakJointsOnDeath = false
		humanoid.MaxHealth = math.huge
		humanoid.Health = math.huge
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	-- The default Animate script would fight the procedural animation on clients.
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	CollectionService:AddTag(model, TAG)
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root:SetNetworkOwner(nil)
	end
	local index = tonumber(string.match(p.Id, "%d+")) or 1
	p.Brain = {
		Random = Random.new(index * 7919),
		NextThink = 0,
		LastTarget = nil,
		HoldDecisionAt = 0,
		ShootAt = nil,
		NextContact = 0,
		NextIntercept = 0,
		Incoming = nil,
		ReactionDelay = 0.22,
		DashDirection = nil,
		Lane = index,
	} :: Brain
	match:bind(p, model)
	Appearance.apply(model, p.Team, p.Role, p.Number)
end

function Bots.destroyAll(match: any)
	for _, p in match.Participants do
		if p.IsBot and p.Model then
			p.Model:Destroy()
			p.Model = nil
			p.Humanoid = nil
			p.Root = nil
		end
	end
end

-- Movement helpers -------------------------------------------------------------------------------------

local function moveTo(match: any, p: Participant, localTarget: Vector3, sprint: boolean)
	local humanoid = p.Humanoid
	local brain = p.Brain :: Brain
	if not humanoid then
		return
	end
	local target = CourtGeometry.clampInside(match.Court, localTarget, 1)
	if p.Role ~= "Goalkeeper" then
		for _, side in { 1, -1 } do
			if CourtGeometry.inGoalArea(match.Court, target, side) then
				target = CourtGeometry.pushOutOfRadius(match.Court, target, side, match.Court.Mode.GoalAreaRadius + 0.8)
			end
		end
	end
	if p.Sprinting ~= sprint then
		match:act(p, "Sprint", { On = sprint })
	end
	if brain.LastTarget and (brain.LastTarget - target).Magnitude < 0.8 then
		return
	end
	brain.LastTarget = target
	humanoid:MoveTo(match:toWorld(target))
end

local function stop(p: Participant)
	local humanoid = p.Humanoid
	local brain = p.Brain :: Brain
	if humanoid and p.Root then
		humanoid:MoveTo(p.Root.Position)
		brain.LastTarget = nil
	end
end

local function face(match: any, p: Participant, localPoint: Vector3)
	local root = p.Root
	if not root then
		return
	end
	local world = match:toWorld(localPoint)
	local look = flat(world - root.Position)
	if look.Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
	end
end

-- Decision helpers ---------------------------------------------------------------------------------------

local function teammates(match: any, p: Participant): { Participant }
	local list = {}
	for _, other in match.Participants do
		if other ~= p and other.Team == p.Team and match:isActive(other) then
			table.insert(list, other)
		end
	end
	return list
end

local function opponents(match: any, p: Participant): { Participant }
	local list = {}
	for _, other in match.Participants do
		if other.Team ~= p.Team and match:isActive(other) then
			table.insert(list, other)
		end
	end
	return list
end

-- Openness of a teammate: distance to the nearest opponent.
local function openness(match: any, mate: Participant): number
	local position = match:localOf(mate)
	local nearest = math.huge
	for _, other in match.Participants do
		if other.Team ~= mate.Team and match:isActive(other) then
			nearest = math.min(nearest, (match:localOf(other) - position).Magnitude)
		end
	end
	return nearest
end

local function bestPassTarget(match: any, p: Participant): Participant?
	local attack = match:attackSide(p.Team)
	local best: Participant? = nil
	local bestScore = -math.huge
	for _, mate in teammates(match, p) do
		if mate.Role ~= "Goalkeeper" or #teammates(match, p) == 1 then
			local position = match:localOf(mate)
			local progress = position.X * attack
			local score = progress * 0.5 + math.min(openness(match, mate), 12) * 1.5
			if score > bestScore then
				bestScore = score
				best = mate
			end
		end
	end
	return best
end

-- Aim point inside the goal, on the side away from the goalkeeper.
local function aimPoint(match: any, p: Participant, brain: Brain): Vector3
	local attack = match:attackSide(p.Team)
	local keeper = match:keeperOf(otherTeam(p.Team))
	local keeperZ = if keeper and keeper.Root then match:localOf(keeper).Z else 0
	local edge = Config.Goal.Width / 2 - 1.3
	local z = if keeperZ > 0 then -edge else edge
	if math.abs(keeperZ) < 0.6 then
		z = if brain.Random:NextNumber() < 0.5 then edge else -edge
	end
	local y = brain.Random:NextNumber(1.2, Config.Goal.Height - 1.6)
	return Vector3.new(attack * (match.Court.HalfLength + 1), y, z)
end

local function shootDirection(match: any, p: Participant, brain: Brain, speed: number): Vector3
	local origin = match:releasePoint(p)
	local target = match:toWorld(aimPoint(match, p, brain))
	return BallPhysics.directVelocity(origin, target, speed).Unit
end

-- Goalkeeper -----------------------------------------------------------------------------------------------

local function keeperThink(match: any, p: Participant, brain: Brain, t: number)
	local ball = match.Ball
	local court = match.Court
	local side = match:defendSide(p.Team)
	local goal = CourtGeometry.goalCenter(court, side)

	if ball.State == "Held" and ball.Holder == p then
		if t >= brain.HoldDecisionAt then
			local mate = bestPassTarget(match, p)
			if mate then
				match:act(p, "Pass", { Kind = "Quick", TargetId = mate.Id })
			else
				match:act(
					p,
					"Pass",
					{ Kind = "Aimed", Direction = match.CourtCFrame:VectorToWorldSpace(Vector3.new(-side, 0.3, 0)) }
				)
			end
		end
		moveTo(match, p, goal + Vector3.new(-side * 3, 0, 0), false)
		return
	end

	-- React to an incoming shot.
	local incoming = brain.Incoming
	if incoming and t > incoming.ArrivalTime + 0.3 then
		brain.Incoming = nil
		incoming = nil
	end
	if incoming and t >= incoming.SeenAt + brain.ReactionDelay and t < incoming.ArrivalTime and p.Root then
		local pointLocal = match:toLocal(incoming.Point)
		local myLocal = match:localOf(p)
		local lateral = math.abs(pointLocal.Z - myLocal.Z)
		local height = pointLocal.Y
		if lateral > Config.Keeper.SaveReachStanding * 0.7 or height > 5.8 then
			match:act(p, "Dive", { Target = incoming.Point })
		end
		brain.Incoming = nil
		brain.ReactionDelay = brain.Random:NextNumber(0.16, 0.32)
	end

	-- Loose ball in the goal area: pick it up.
	local ballLocal = match:toLocal(ball.Position)
	if ball.State == "Loose" and CourtGeometry.inGoalArea(court, ballLocal, side) then
		moveTo(match, p, ballLocal, true)
		return
	end

	-- Positioning on the bisector between the ball and the goal.
	local toBall = flat(ballLocal - goal)
	local direction = if toBall.Magnitude > 0.1 then toBall.Unit else Vector3.new(-side, 0, 0)
	if direction.X * side > -0.1 then
		direction = Vector3.new(-side, 0, direction.Z).Unit
	end
	local spot = goal + direction * 2.4
	spot = Vector3.new(spot.X, 0, math.clamp(spot.Z, -Config.Goal.Width / 2 + 0.6, Config.Goal.Width / 2 - 0.6))
	moveTo(match, p, spot, false)
end

-- Field players ----------------------------------------------------------------------------------------------

local function holdingThink(match: any, p: Participant, brain: Brain, t: number)
	local ball = match.Ball
	local court = match.Court
	local attack = match:attackSide(p.Team)
	local position = match:localOf(p)
	local goalDistance = CourtGeometry.goalDistance(court, position, attack)
	local holdTime = t - ball.HoldStart
	local restart = match.Restart

	-- Set pieces: short think, then play.
	if match.PlayState == "Restart" and restart and restart.Thrower == p then
		if holdTime < 0.8 then
			return
		end
		if
			restart.Kind == "Penalty"
			or (goalDistance < court.Mode.FreeThrowRadius + 3 and brain.Random:NextNumber() < 0.5)
		then
			match:act(p, "ShotCharge", {})
			match:act(
				p,
				"ShotRelease",
				{ Direction = shootDirection(match, p, brain, Config.Ball.ChargedShotMinSpeed) }
			)
			return
		end
		local mate = bestPassTarget(match, p)
		if mate then
			match:act(p, "Pass", { Kind = "Quick", TargetId = mate.Id })
		end
		return
	end

	-- Charging a shot: release on time.
	if p.ChargeStart and brain.ShootAt then
		face(match, p, CourtGeometry.goalCenter(court, attack))
		if t >= brain.ShootAt then
			local charge = math.clamp((t - p.ChargeStart) / Config.Ball.ShotChargeTime, 0, 1)
			local speed = Config.Ball.ChargedShotMinSpeed
				+ (Config.Ball.ChargedShotMaxSpeed - Config.Ball.ChargedShotMinSpeed) * charge
			match:act(p, "ShotRelease", { Direction = shootDirection(match, p, brain, speed) })
			brain.ShootAt = nil
		end
		return
	end

	local inRange = goalDistance < court.Mode.FreeThrowRadius + 5
	if ball.Dribbling then
		if inRange then
			match:act(p, "Dribble", {}) -- gather before shooting
			stop(p)
		else
			moveTo(match, p, CourtGeometry.goalCenter(court, attack) * 0.85, true)
		end
		return
	end

	stop(p)
	if holdTime < 0.25 then
		return
	end
	if inRange then
		match:act(p, "ShotCharge", {})
		brain.ShootAt = t + brain.Random:NextNumber(0.25, 0.7)
		return
	end
	local mate = bestPassTarget(match, p)
	if mate and holdTime > 0.35 then
		local matePosition = match:localOf(mate)
		local ahead = (matePosition.X - position.X) * attack > 5 and openness(match, mate) > 6
		if ahead or ball.HasDribbled or holdTime > 1.4 then
			match:act(p, "Pass", { Kind = if openness(match, mate) > 9 then "Quick" else "High", TargetId = mate.Id })
			return
		end
	end
	if not ball.HasDribbled then
		match:act(p, "Dribble", {})
		return
	end
	if holdTime > 2 then
		-- Nobody to pass to: shoot from where we are rather than lose the ball.
		match:act(p, "ShotCharge", {})
		brain.ShootAt = t + 0.2
	end
end

local function supportSpot(match: any, p: Participant, brain: Brain): Vector3
	local court = match.Court
	local attack = match:attackSide(p.Team)
	local mates = teammates(match, p)
	local lanes = math.max(2, #mates + 1)
	local lane = (brain.Lane % lanes) / math.max(1, lanes - 1) - 0.5
	local depth = court.HalfLength - court.Mode.FreeThrowRadius - 2 - (brain.Lane % 2) * 4
	return Vector3.new(attack * depth, 0, lane * court.HalfWidth * 1.4)
end

local function defendThink(match: any, p: Participant, brain: Brain, t: number)
	local ball = match.Ball
	local court = match.Court
	local defend = match:defendSide(p.Team)
	local goal = CourtGeometry.goalCenter(court, defend)
	local holder: Participant? = if ball.State == "Held" then ball.Holder else nil
	local position = match:localOf(p)

	-- Who presses the carrier: the closest field defender.
	local presser: Participant? = nil
	if holder then
		local holderPosition = match:localOf(holder)
		local best = math.huge
		for _, mate in match.Participants do
			if mate.Team == p.Team and mate.Role ~= "Goalkeeper" and match:isActive(mate) then
				local distance = (match:localOf(mate) - holderPosition).Magnitude
				if distance < best then
					best = distance
					presser = mate
				end
			end
		end
	end

	if holder and presser == p and holder.Root then
		local holderPosition = match:localOf(holder)
		local toGoal = flat(goal - holderPosition)
		local spot = holderPosition + (if toGoal.Magnitude > 0.1 then toGoal.Unit else Vector3.new(defend, 0, 0)) * 3.2
		moveTo(match, p, spot, true)
		match:act(p, "Stance", { On = (holderPosition - position).Magnitude < 8 })
		face(match, p, holderPosition)
		local distance = (holderPosition - position).Magnitude
		if holder.ChargeStart and distance < Config.Defense.BlockReach + 3 then
			match:act(p, "Block", {})
		elseif distance < Config.Defense.ContactRange - 1 and t >= brain.NextContact then
			-- Only legal contacts: from the front of the carrier.
			local look = flat(holder.Root.CFrame.LookVector)
			local toMe = flat(match:toWorld(position) - holder.Root.Position)
			if look.Magnitude > 0.1 and toMe.Magnitude > 0.1 and look.Unit:Dot(toMe.Unit) > 0.35 then
				match:act(p, "Contact", { TargetId = holder.Id })
				brain.NextContact = t + brain.Random:NextNumber(2.5, 5)
			end
		end
		return
	end
	match:act(p, "Stance", { On = false })

	-- Mark the nearest attacker without the ball, between them and the goal.
	local mark: Participant? = nil
	local best = math.huge
	for _, other in opponents(match, p) do
		if other ~= holder and other.Role ~= "Goalkeeper" then
			local distance = (match:localOf(other) - position).Magnitude
			if distance < best then
				best = distance
				mark = other
			end
		end
	end
	if mark then
		local markPosition = match:localOf(mark)
		local spot = markPosition:Lerp(goal, 0.25)
		moveTo(match, p, spot, false)
	else
		moveTo(match, p, goal + Vector3.new(-defend * (court.Mode.FreeThrowRadius - 2), 0, 0), false)
	end

	-- Intercept a pass flying close by.
	if ball.State == "Flight" and ball.ThrowTeam ~= p.Team and t >= brain.NextIntercept and p.Root then
		local ballPosition = ball.Position
		local predicted = ballPosition + ball.Velocity * 0.12
		if (predicted - (p.Root.Position + Vector3.new(0, 1.2, 0))).Magnitude < Config.Defense.InterceptReach + 1.5 then
			match:act(p, "Intercept", {})
			brain.NextIntercept = t + Config.Defense.InterceptCooldown
		end
	end
end

local function fieldThink(match: any, p: Participant, brain: Brain, t: number)
	local ball = match.Ball
	if ball.State == "Held" and ball.Holder == p then
		holdingThink(match, p, brain, t)
		return
	end
	match:act(p, "Stance", { On = false })
	local ballLocal = match:toLocal(ball.Position)
	local position = match:localOf(p)

	-- Free ball: the closest player of each team chases it.
	if ball.State == "Loose" or (ball.State == "Flight" and ball.Throw == "Parry") then
		local inArea = CourtGeometry.inGoalArea(match.Court, ballLocal, 1)
			or CourtGeometry.inGoalArea(match.Court, ballLocal, -1)
		if not inArea then
			local mine = (ballLocal - position).Magnitude
			local closest = true
			for _, mate in teammates(match, p) do
				if mate.Role ~= "Goalkeeper" and (match:localOf(mate) - ballLocal).Magnitude < mine then
					closest = false
				end
			end
			if closest then
				moveTo(match, p, Vector3.new(ballLocal.X, 0, ballLocal.Z), true)
				return
			end
		end
	end

	-- A pass flying to me: wait for it, step towards it.
	if ball.State == "Flight" and ball.Target == p then
		stop(p)
		return
	end

	local ourBall = match.Possession == p.Team and (ball.State == "Held" or ball.State == "Flight")
	if ourBall then
		moveTo(match, p, supportSpot(match, p, brain), true)
	else
		defendThink(match, p, brain, t)
	end
end

-- Per-frame physics for dashes and dives, decisions at 10 Hz.
function Bots.update(match: any, dt: number, t: number)
	for _, p in match.Participants do
		local brain = p.Brain :: Brain?
		local root = p.Root
		if p.IsBot and brain and root and match:isActive(p, t) then
			-- Dash.
			if t < p.DashUntil and brain.DashDirection then
				local velocity = brain.DashDirection * Config.Movement.DashSpeed
				root.AssemblyLinearVelocity = Vector3.new(velocity.X, root.AssemblyLinearVelocity.Y, velocity.Z)
			end
			-- Dive: the body follows the hands.
			if t >= p.DiveStart and t < p.DiveUntil then
				local hands =
					p.DiveFrom:Lerp(p.DiveEnd, math.clamp((t - p.DiveStart) / Config.Keeper.DiveDuration, 0, 1))
				local body = Vector3.new(hands.X, match.FloorY + 1.6, hands.Z)
				local look = flat(root.CFrame.LookVector)
				if look.Magnitude < 0.1 then
					look = Vector3.new(0, 0, -1)
				end
				root.CFrame = CFrame.lookAt(body, body + look)
				root.AssemblyLinearVelocity = Vector3.zero
			end

			local inPlay = match:inPlay() and not p.Frozen
			if t >= brain.NextThink then
				brain.NextThink = t + THINK_INTERVAL
				if not inPlay then
					if match.Phase == "Playing" or match.Phase == "Overtime" then
						-- A set piece: the thrower still has to play the ball.
						local restart = match.Restart
						if restart and restart.Thrower == p then
							if p.Role == "Goalkeeper" then
								if brain.HoldDecisionAt < match.Ball.HoldStart then
									brain.HoldDecisionAt = match.Ball.HoldStart + 0.8
								end
								keeperThink(match, p, brain, t)
							else
								holdingThink(match, p, brain, t)
							end
						end
					end
					if p.Frozen then
						stop(p)
					end
				elseif p.Role == "Goalkeeper" then
					if
						match.Ball.State == "Held"
						and match.Ball.Holder == p
						and brain.HoldDecisionAt < match.Ball.HoldStart
					then
						brain.HoldDecisionAt = match.Ball.HoldStart + brain.Random:NextNumber(0.7, 1.4)
					end
					keeperThink(match, p, brain, t)
				else
					fieldThink(match, p, brain, t)
				end
			end
		end
	end
end

return Bots
