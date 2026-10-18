--!nonstrict
-- Ballon côté serveur (autorité). Sa trajectoire est calculée par BallMath ;
-- le serveur détecte réceptions, interceptions, contres, arrêts du gardien,
-- buts et sorties, puis prévient le match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BallMath = require(ReplicatedStorage.Shared.BallMath)
local Config = require(ReplicatedStorage.Shared.Config)
local Court = require(ReplicatedStorage.Shared.Court)
local MatchTypes = require(script.Parent.MatchTypes)

type Participant = MatchTypes.Participant
type ShotMods = MatchTypes.ShotMods

export type ThrowKind = "Loose" | "Pass" | "Shot"

local Ball = {}
Ball.__index = Ball

export type Ball = {
	Match: any,
	State: "Dead" | "Held" | "Flight" | "Hidden",
	Holder: Participant?,
	Position: Vector3,
	Velocity: Vector3,
	Accel: Vector3,
	Kind: ThrowKind,
	Thrower: Participant?,
	ReleaseTime: number,
	PassTarget: Participant?,
	PassOrigin: Vector3,
	Mods: ShotMods?,
	HomingTarget: Vector3?,
	LastTouch: Participant?,
	Dribbling: boolean,
	DribbleUsed: boolean,
	HoldStart: number,
	CarryDistance: number,
	LastCarryPosition: Vector3?,
	Locked: boolean,
	CastParams: RaycastParams,
	LastBroadcast: number,
}

local RADIUS = Config.Ball.Radius
local HAND_OFFSET = CFrame.new(1.35, 0.35, -0.95)

function Ball.new(match: any): Ball
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { match.Court.Collidables }
	local self = setmetatable({
		Match = match,
		State = "Hidden",
		Holder = nil,
		Position = match.Court.CFrame.Position + Vector3.new(0, 3, 0),
		Velocity = Vector3.zero,
		Accel = Vector3.zero,
		Kind = "Loose",
		Thrower = nil,
		ReleaseTime = 0,
		PassTarget = nil,
		PassOrigin = Vector3.zero,
		Mods = nil,
		HomingTarget = nil,
		LastTouch = nil,
		Dribbling = false,
		DribbleUsed = false,
		HoldStart = 0,
		CarryDistance = 0,
		LastCarryPosition = nil,
		Locked = false,
		CastParams = params,
		LastBroadcast = 0,
	}, Ball)
	return self :: any
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

function Ball.handPosition(participant: Participant): Vector3?
	local root = participant.Root
	if not root then
		return nil
	end
	return (root.CFrame * HAND_OFFSET).Position
end

function Ball.snapshot(self: any): any
	local fire = self.Mods ~= nil and self.Mods.Fire and self.State == "Flight"
	return {
		State = self.State,
		Holder = if self.Holder then self.Holder.Model else nil,
		HolderId = if self.Holder then self.Holder.Id else nil,
		Position = self.Position,
		Velocity = self.Velocity,
		Accel = self.Accel,
		ServerTime = now(),
		Fire = fire,
		Charged = self.Mods ~= nil and self.State == "Flight",
		Kind = self.Kind,
		Dribbling = self.Dribbling,
		HoldStart = self.HoldStart,
		Locked = self.Locked,
	}
end

function Ball.broadcast(self: any)
	self.LastBroadcast = os.clock()
	self.Match:fireAll("BallState", self:snapshot())
end

-- Le ballon passe dans les mains d'un joueur.
function Ball.give(self: any, participant: Participant, locked: boolean?)
	self.State = "Held"
	self.Holder = participant
	self.Velocity = Vector3.zero
	self.Accel = Vector3.zero
	self.Kind = "Loose"
	self.Mods = nil
	self.HomingTarget = nil
	self.PassTarget = nil
	self.Dribbling = false
	self.DribbleUsed = false
	self.HoldStart = now()
	self.CarryDistance = 0
	self.LastCarryPosition = if participant.Root then participant.Root.Position else nil
	self.Locked = locked == true
	self.LastTouch = participant
	local hand = Ball.handPosition(participant)
	if hand then
		self.Position = hand
	end
	self:broadcast()
end

function Ball.release(self: any, origin: Vector3, velocity: Vector3, kind: ThrowKind, mods: ShotMods?, passTarget: Participant?)
	local thrower = self.Holder
	self.State = "Flight"
	self.Holder = nil
	self.Position = origin
	self.Velocity = velocity
	self.Accel = Vector3.zero
	self.Kind = kind
	self.Thrower = thrower
	self.ReleaseTime = now()
	self.PassTarget = passTarget
	self.PassOrigin = origin
	self.Mods = mods
	self.Dribbling = false
	self.Locked = false
	self.LastTouch = thrower or self.LastTouch
	self:broadcast()
end

-- Ballon lâché sans contrôle (contact, étourdissement, contre…).
function Ball.drop(self: any, velocity: Vector3?)
	local origin = self.Position
	if self.Holder then
		local hand = Ball.handPosition(self.Holder)
		origin = hand or origin
	end
	local fallback = Vector3.new(math.random() * 16 - 8, 18, math.random() * 16 - 8)
	self:release(origin, velocity or fallback, "Loose", nil, nil)
end

function Ball.place(self: any, position: Vector3)
	self.State = "Dead"
	self.Holder = nil
	self.Position = position
	self.Velocity = Vector3.zero
	self.Accel = Vector3.zero
	self.Mods = nil
	self:broadcast()
end

function Ball.hide(self: any)
	self.State = "Hidden"
	self.Holder = nil
	self.Mods = nil
	self:broadcast()
end

-- Détection des contacts joueur / ballon en vol ---------------------------------------

local function catchDistance(participant: Participant, position: Vector3): number
	local root = participant.Root
	if not root then
		return math.huge
	end
	local rootPos = root.Position
	local reachUp = if participant.Poste == "Gardien" then 4.5 else 3.4
	local clampedY = math.clamp(position.Y, rootPos.Y - 3, rootPos.Y + reachUp)
	return (position - Vector3.new(rootPos.X, clampedY, rootPos.Z)).Magnitude
end

local function deflect(velocity: Vector3, normalHint: Vector3, factor: number): Vector3
	local flat = Vector3.new(normalHint.X, 0, normalHint.Z)
	local away = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(1, 0, 0)
	local speed = velocity.Magnitude * factor
	local spread = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.8
	local direction = (away + spread).Unit
	return direction * speed + Vector3.new(0, 14 + math.random() * 10, 0)
end

function Ball.checkContacts(self: any)
	local match = self.Match
	local t = now()
	local speed = self.Velocity.Magnitude
	local isShot = self.Kind == "Shot" and speed > 55
	local best: Participant? = nil
	local bestDistance = math.huge
	local bestRole = ""

	for _, participant: Participant in match:activeParticipants() do
		if participant == self.Thrower and t - self.ReleaseTime < Config.Ball.ReleaseImmunity then
			continue
		end
		if not match:canTouchBall(participant) then
			continue
		end
		local distance = catchDistance(participant, self.Position)
		if distance > 9 then
			continue
		end
		local thrower = self.Thrower
		local sameTeam = thrower ~= nil and thrower.Team == participant.Team
		local radius = 0
		local role = ""
		local interceptMult = match:effectValue(participant, "Intercept", 1)
		local stance = participant.InterceptUntil > t
		if isShot then
			if participant.Poste == "Gardien" and not sameTeam then
				local mods = self.Mods
				local keeperMult = if mods then mods.KeeperRadiusMult else 1
				local catchMult = match:effectValue(participant, "Catch", 1)
				local diveBonus = if participant.DiveUntil > t then 1.15 else 1
				radius = Config.Ball.KeeperCatchRadius * catchMult * keeperMult * diveBonus
				role = "Keeper"
			elseif not sameTeam then
				radius = (if stance then Config.Ball.InterceptStanceRadius * 0.6 else Config.Ball.BlockRadius) * interceptMult
				role = "Block"
			end
		elseif self.Kind == "Pass" then
			if sameTeam then
				radius = Config.Ball.CatchRadius * (if participant == self.PassTarget then 1.25 else 1)
				role = "Catch"
			else
				radius = (if stance then Config.Ball.InterceptStanceRadius else Config.Ball.InterceptRadius) * interceptMult
				if participant.Poste == "Gardien" then
					radius = math.max(radius, Config.Ball.KeeperCatchRadius * 0.8)
				end
				role = "Intercept"
			end
		else
			radius = Config.Ball.PickupRadius
			if stance then
				radius = math.max(radius, Config.Ball.InterceptStanceRadius * 0.8)
			end
			role = "Pickup"
		end
		if radius > 0 and distance <= radius and distance < bestDistance then
			best = participant
			bestDistance = distance
			bestRole = role
		end
	end

	local winner = best
	if not winner then
		return
	end
	if bestRole == "Keeper" then
		local mods = self.Mods
		local mustParry = (mods ~= nil and mods.Fire) or speed > Config.Ball.KeeperCatchMaxSpeed
		if mods and mods.StunKeeper > 0 then
			match:stun(winner, mods.StunKeeper, "Foudroyé !")
		end
		match:onSave(winner, self.Thrower, mustParry)
		if mustParry then
			-- Repoussé vers le terrain, loin du but défendu.
			local goalSide = match:defendSideOf(winner.Team)
			local away = match.Court.CFrame:VectorToWorldSpace(Vector3.new(-goalSide, 0, 0))
			self.LastTouch = winner
			self:release(self.Position, deflect(self.Velocity, away, 0.45), "Loose", nil, nil)
		else
			self:give(winner)
			match:onCaught(winner, "Save", self.Thrower)
		end
		return
	end
	if bestRole == "Block" then
		local root = winner.Root
		local away = if root then self.Position - root.Position else -self.Velocity
		self.LastTouch = winner
		match:onBlock(winner, self.Thrower)
		self:release(self.Position, deflect(self.Velocity, away, 0.35), "Loose", nil, nil)
		return
	end
	local previousKind = self.Kind
	local thrower = self.Thrower
	local passOrigin = self.PassOrigin
	self:give(winner)
	if bestRole == "Catch" then
		match:onCaught(winner, "Catch", thrower, (passOrigin - self.Position).Magnitude)
	elseif bestRole == "Intercept" then
		match:onCaught(winner, "Interception", thrower)
	else
		match:onCaught(winner, if previousKind == "Pass" then "Interception" else "Pickup", thrower)
	end
end

-- Buts et sorties -----------------------------------------------------------------------

function Ball.checkBoundaries(self: any, previousLocal: Vector3): boolean
	local match = self.Match
	local dims: Court.Dimensions = match.Court.Dims
	local localPos = match.Court.CFrame:PointToObjectSpace(self.Position)
	local halfLength = dims.Length / 2
	local halfWidth = dims.Width / 2
	for _, side in { -1, 1 } do
		if side * localPos.X > halfLength + RADIUS and side * previousLocal.X <= halfLength + RADIUS + 3 then
			local inFrame = math.abs(localPos.Z) < dims.GoalWidth / 2 and localPos.Y < dims.GoalHeight
			if inFrame then
				match:onGoal(side, self)
			else
				match:onOut("GoalLine", side, localPos, self)
			end
			return true
		end
	end
	if math.abs(localPos.Z) > halfWidth + RADIUS then
		match:onOut("Sideline", 0, localPos, self)
		return true
	end
	if localPos.Y < -6 then
		match:onOut("Sideline", 0, Vector3.new(localPos.X, 0, math.sign(localPos.Z) * halfWidth), self)
		return true
	end
	return false
end

-- Mise à jour -------------------------------------------------------------------------------

function Ball.update(self: any, dt: number)
	if self.State == "Held" then
		local holder = self.Holder
		if not holder or not holder.Root then
			self:drop()
			return
		end
		local hand = Ball.handPosition(holder)
		if hand then
			self.Position = hand
		end
		return
	end
	if self.State ~= "Flight" then
		return
	end

	-- Tir guidé : le ballon s'oriente vers sa cible.
	local mods = self.Mods
	if mods and mods.Homing and self.HomingTarget then
		local desired = (self.HomingTarget - self.Position).Unit * self.Velocity.Magnitude
		self.Accel = (desired - self.Velocity) * 5 + Vector3.new(0, Config.Ball.Gravity * 0.85, 0)
	end

	local match = self.Match
	local previousLocal = match.Court.CFrame:PointToObjectSpace(self.Position)
	local params = self.CastParams
	local result = BallMath.step(self.Position, self.Velocity, self.Accel, dt, function(origin, direction)
		local hit = Workspace:Spherecast(origin, RADIUS, direction, params)
		if hit then
			return hit.Position, hit.Normal, hit.Instance
		end
		return nil, nil, nil
	end)
	self.Position = result.Position
	self.Velocity = result.Velocity

	if self:checkBoundaries(previousLocal) then
		return
	end

	if result.Bounced then
		local hit = result.HitInstance
		local hitFloor = hit ~= nil and (hit.Name == "Parquet" or hit.Name == "Degagement")
		if hitFloor and self.Kind ~= "Loose" then
			self.Kind = "Loose"
			self.Mods = nil
			self.Accel = Vector3.zero
		elseif hit and hit.Name == "MurDePouvoir" then
			match:onWallBlock(hit, self)
			self.Kind = "Loose"
			self.Mods = nil
			self.Accel = Vector3.zero
		elseif self.Mods and self.Mods.Curve > 0 then
			self.Accel = Vector3.zero
		end
		self:broadcast()
	end

	if result.Grounded and self.Velocity.Magnitude < 0.8 then
		self.Velocity = Vector3.zero
	end

	self:checkContacts()

	if self.State == "Flight" and os.clock() - self.LastBroadcast > 0.25 then
		self:broadcast()
	end
end

return Ball
