--!strict
-- Exécution des pouvoirs (données dans Shared/Data/Archetypes.luau).
-- Le serveur décide de tout : cibles, durées, effets. Les mouvements des
-- joueurs humains sont appliqués par leur client (qui possède la physique de
-- son personnage) sur ordre du serveur ; ceux des bots par le serveur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Court = require(ReplicatedStorage.Shared.Court)
local MatchTypes = require(script.Parent.MatchTypes)

type Participant = MatchTypes.Participant

local Abilities = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function flatLook(participant: Participant): Vector3
	local root = participant.Root
	if not root then
		return Vector3.new(0, 0, -1)
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
end

-- Élan : appliqué par le client propriétaire (humain) ou le serveur (bot).
function Abilities.impulse(match: any, participant: Participant, velocity: Vector3, duration: number)
	local root = participant.Root
	if not root then
		return
	end
	if participant.Player then
		match:fireTo(participant.Player, "MatchEvent", "Impulse", { Velocity = velocity, Duration = duration })
		return
	end
	-- Bot : vitesse imposée côté serveur.
	if duration <= 0 then
		root.AssemblyLinearVelocity = velocity
		return
	end
	local attachment = root:FindFirstChild("ImpulseAttachment") :: Attachment?
	if not attachment then
		local newAttachment = Instance.new("Attachment")
		newAttachment.Name = "ImpulseAttachment"
		newAttachment.Parent = root
		attachment = newAttachment
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

function Abilities.teleport(match: any, participant: Participant, worldPosition: Vector3, lookAt: Vector3?)
	local model = participant.Model
	local root = participant.Root
	if not model or not root then
		return
	end
	local target = worldPosition + Vector3.new(0, 3, 0)
	local facing = lookAt or (target + flatLook(participant))
	local flatFacing = Vector3.new(facing.X, target.Y, facing.Z)
	if (flatFacing - target).Magnitude < 0.1 then
		flatFacing = target + flatLook(participant)
	end
	model:PivotTo(CFrame.lookAt(target, flatFacing))
	root.AssemblyLinearVelocity = Vector3.zero
	match:fireAll("MatchEvent", "Blink", { Model = model, From = root.Position, To = target })
end

-- Garde un point dans le terrain et hors des zones pour un joueur de champ.
local function legalPoint(match: any, participant: Participant, worldPosition: Vector3): Vector3
	local court = match.Court
	local dims: Court.Dimensions = court.Dims
	local localPos = court.CFrame:PointToObjectSpace(worldPosition)
	localPos = Vector3.new(
		math.clamp(localPos.X, -dims.Length / 2 + 1, dims.Length / 2 - 1),
		0,
		math.clamp(localPos.Z, -dims.Width / 2 + 1, dims.Width / 2 - 1)
	)
	if participant.Poste ~= "Gardien" then
		for _, side in { -1, 1 } do
			localPos = Court.pushOutside(dims, localPos, side, dims.GoalAreaRadius + 0.5)
		end
	end
	return court.CFrame:PointToWorldSpace(localPos)
end

local function enemyCarrier(match: any, participant: Participant, range: number): Participant?
	local holder: Participant? = match.Ball.Holder
	if not holder or holder.Team == participant.Team then
		return nil
	end
	local a, b = participant.Root, holder.Root
	if not a or not b or (a.Position - b.Position).Magnitude > range then
		return nil
	end
	return holder
end

local function targetsAround(match: any, participant: Participant, radius: number?): { Participant }
	local result = {}
	local origin = participant.Root and participant.Root.Position
	for _, other: Participant in match:opponentsOf(participant) do
		local root = other.Root
		if root and (not radius or (origin and (root.Position - origin).Magnitude <= radius)) then
			table.insert(result, other)
		end
	end
	return result
end

-- Vérifie les conditions de ciblage AVANT de consommer le pouvoir.
function Abilities.canExecute(match: any, participant: Participant, power: Archetypes.Power): (boolean, string?)
	for _, effect in power.Effects do
		if effect.Kind == "Steal" and not enemyCarrier(match, participant, effect.Range or 15) then
			return false, "Aucun porteur adverse à portée."
		elseif effect.Kind == "BlinkToCarrier" and not enemyCarrier(match, participant, effect.Range or 40) then
			return false, "Aucun porteur adverse à portée."
		elseif effect.Kind == "ShotBuff" and participant.ShotBuff and participant.ShotBuff.ExpiresAt > now() then
			return false, "Ton tir est déjà chargé."
		end
	end
	return true, nil
end

function Abilities.execute(match: any, participant: Participant, power: Archetypes.Power)
	local root = participant.Root
	if not root then
		return
	end
	local t = now()
	for _, effect in power.Effects do
		local kind = effect.Kind
		if kind == "Dash" then
			local velocity = flatLook(participant) * (effect.Speed or 80)
			Abilities.impulse(match, participant, velocity, effect.Duration or 0.22)
			if effect.Ram then
				participant.RamUntil = t + (effect.Duration or 0.22) + 0.15
			end
		elseif kind == "Leap" then
			local velocity = flatLook(participant) * (effect.Forward or 20) + Vector3.new(0, effect.Up or 70, 0)
			Abilities.impulse(match, participant, velocity, 0)
		elseif kind == "Dive" then
			local humanoid = participant.Humanoid
			local direction = if humanoid and humanoid.MoveDirection.Magnitude > 0.1
				then Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z).Unit
				else flatLook(participant)
			Abilities.impulse(match, participant, direction * (effect.Speed or 70) + Vector3.new(0, 10, 0), effect.Duration or 0.3)
			participant.DiveUntil = t + (effect.Duration or 0.3) + 0.35
		elseif kind == "Blink" then
			local target = root.Position + flatLook(participant) * (effect.Distance or 24)
			Abilities.teleport(match, participant, legalPoint(match, participant, target), nil)
		elseif kind == "BlinkToCarrier" then
			local carrier = enemyCarrier(match, participant, effect.Range or 40)
			if carrier and carrier.Root then
				local carrierRoot = carrier.Root
				local front = carrierRoot.Position + flatLook(carrier) * 4
				Abilities.teleport(match, participant, legalPoint(match, participant, front), carrierRoot.Position)
			end
		elseif kind == "BlinkToGoal" then
			local side = match:defendSideOf(participant.Team)
			local spot = match.Court.CFrame:PointToWorldSpace(Court.keeperSpot(match.Court.Dims, side))
			local center = match.Court.CFrame.Position
			Abilities.teleport(match, participant, spot, center)
		elseif kind == "SelfBuff" then
			local duration = effect.Duration or 5
			if effect.Haste then
				match:addEffect(participant, "Haste", effect.Haste, duration)
			end
			if effect.Unstoppable then
				match:addEffect(participant, "Unstoppable", 1, duration)
			end
			if effect.InterceptMult then
				match:addEffect(participant, "Intercept", effect.InterceptMult, duration)
			end
			if effect.CatchMult then
				match:addEffect(participant, "Catch", effect.CatchMult, duration)
			end
		elseif kind == "ShotBuff" then
			participant.ShotBuff = {
				SpeedMult = effect.SpeedMult or 1,
				Curve = effect.Curve or 0,
				Fire = effect.Fire == true,
				Homing = effect.Homing == true,
				StunKeeper = effect.StunKeeper or 0,
				KeeperRadiusMult = effect.KeeperRadiusMult or 1,
				ExpiresAt = t + (effect.Window or 8),
			}
		elseif kind == "Steal" then
			local carrier = enemyCarrier(match, participant, effect.Range or 15)
			if carrier then
				participant.Steals += 1
				match:stun(carrier, 0.5, nil)
				match.Ball:give(participant)
				match:onCaught(participant, "Steal", carrier)
			end
		elseif kind == "TeamHaste" then
			for _, ally: Participant in match:teammatesOf(participant, true) do
				match:addEffect(ally, "Haste", effect.Mult or 1.2, effect.Duration or 5)
				if effect.ResetPower1 then
					ally.Power1ReadyAt = t
				end
			end
		elseif kind == "EnemySlow" then
			for _, enemy in targetsAround(match, participant, effect.Radius) do
				match:addEffect(enemy, "Slow", effect.Mult or 0.7, effect.Duration or 4)
			end
		elseif kind == "EnemyStun" then
			for _, enemy in targetsAround(match, participant, effect.Radius) do
				match:stun(enemy, effect.Duration or 1, nil)
			end
		elseif kind == "EnemyBlind" then
			for _, enemy in targetsAround(match, participant, effect.Radius) do
				match:blind(enemy, effect.Duration or 2)
			end
		elseif kind == "GoalWall" then
			match:createGoalWall(participant.Team, effect.Duration or 4, effect.Coverage or 1, effect.Style or "Ice")
		elseif kind == "TimeStop" then
			local duration = effect.Duration or 3
			for _, enemy in targetsAround(match, participant, nil) do
				match:stun(enemy, duration, nil)
			end
			match:fireAll("MatchEvent", "TimeStop", { Duration = duration, Team = participant.Team })
		end
	end
end

return Abilities
