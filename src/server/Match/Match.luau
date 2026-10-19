--!strict
-- One handball match, fully server-authoritative.
--
-- Responsibilities: match state machine, ball simulation and possession,
-- validation of every player action, the handball rules (3 seconds, 3 steps,
-- dribbling, goal areas, free throws, 7 m throws, passive play, restarts),
-- goalkeeper saves, fouls and progressive punishment, statistics and results.
-- Clients only send intents (Action remote) and draw what the snapshots say.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BallPhysics = require(ReplicatedStorage.Shared.BallPhysics)
local Config = require(ReplicatedStorage.Shared.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local Types = require(ReplicatedStorage.Shared.Types)

local AntiExploitService = require(script.Parent.Parent.Services.AntiExploitService)
local Guard = require(script.Parent.Parent.Lib.Guard)
local Remote = require(script.Parent.Parent.Lib.Remote)
local Appearance = require(script.Parent.Appearance)
local Bots = require(script.Parent.Bots)
local Goalkeeper = require(script.Parent.Goalkeeper)
local MatchTypes = require(script.Parent.MatchTypes)
local Rules = require(script.Parent.Rules)

type Participant = MatchTypes.Participant
type BallState = MatchTypes.BallState

local Match = {}
Match.__index = Match

local TEAMS = { "Red", "Blue" }
local PASS_THROWS = { QuickPass = true, LongPass = true, HighPass = true, AimedPass = true }
local SHOT_THROWS = { QuickShot = true, ChargedShot = true }
local PASS_KINDS = { "Quick", "High", "Aimed" }
local ROLES = { "Goalkeeper", "Field" }

local AREA_TOLERANCE = 0.3 -- seconds inside an illegal area before the whistle
local BALL_MIN_SEND_INTERVAL = 1 / 30
local HELD_BALL_RATE = 4
local MAX_SUBSTEPS = 12

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function clampVertical(direction: Vector3, minY: number, maxY: number): Vector3
	local y = math.clamp(direction.Y, minY, maxY)
	local horizontal = flat(direction)
	if horizontal.Magnitude < 0.01 then
		horizontal = Vector3.new(0, 0, -1)
	end
	horizontal = horizontal.Unit * math.sqrt(math.max(0, 1 - y * y))
	return Vector3.new(horizontal.X, y, horizontal.Z)
end

local function newParticipant(id: string, name: string, team: string, number: number, player: Player?): Participant
	return {
		Id = id,
		Player = player,
		UserId = if player then player.UserId else nil,
		Name = name,
		Team = team,
		Role = "Field",
		RoleChosen = false,
		IsBot = player == nil,
		Model = nil,
		Humanoid = nil,
		Root = nil,
		Number = number,
		Connected = true,
		Goals = 0,
		Assists = 0,
		Saves = 0,
		Interceptions = 0,
		Blocks = 0,
		Fouls = 0,
		Shots = 0,
		Warned = false,
		SuspendedUntil = 0,
		Sprinting = false,
		Stance = false,
		ChargeStart = nil,
		DashReadyAt = 0,
		DashUntil = 0,
		RecoveryUntil = 0,
		InterceptUntil = 0,
		InterceptReadyAt = 0,
		MissRecoveryUntil = 0,
		InterceptHit = false,
		BlockUntil = 0,
		BlockReadyAt = 0,
		ContactReadyAt = 0,
		ContactImmuneUntil = 0,
		StunnedUntil = 0,
		DiveStart = 0,
		DiveUntil = 0,
		DiveRecoveryUntil = 0,
		DiveReadyAt = 0,
		DiveFrom = Vector3.zero,
		DiveEnd = Vector3.zero,
		AreaTime = 0,
		Frozen = false,
		AppliedSpeed = -1,
		AppliedJump = -1,
		Attributes = {},
		Brain = nil,
	}
end

local function newBall(): BallState
	return {
		State = "Dead",
		Holder = nil,
		Position = Vector3.zero,
		Velocity = Vector3.zero,
		Throw = nil,
		Thrower = nil,
		Target = nil,
		ThrowTeam = nil,
		Charge = nil,
		ReleaseTime = 0,
		LastToucher = nil,
		LastTouchTeam = nil,
		Dribbling = false,
		HasDribbled = false,
		KeeperAreaHold = false,
		HoldStart = 0,
		Steps = 0,
		StepDistance = 0,
		LastHolderPosition = nil,
		AssistId = nil,
		AssistTeam = nil,
		AssistTime = 0,
		ShotSide = nil,
		LooseInAreaTime = 0,
	}
end

-- Construction ----------------------------------------------------------------------------------

function Match.new(config: MatchTypes.MatchConfig, mapService: any): any
	local mode = Config.Modes[config.Mode]
	assert(mode, `Unknown mode {config.Mode}`)
	local self = setmetatable({
		Id = HttpService:GenerateGUID(false),
		Config = config,
		ModeInfo = mode,
		MapService = mapService,
		Map = nil :: any,
		Court = CourtGeometry.new(config.Mode, config.Origin),
		CourtCFrame = config.Origin,
		FloorY = config.Origin.Position.Y,
		Bench = {} :: { [string]: Vector3 },
		Folder = nil :: Folder?,
		Participants = {} :: { Participant },
		ById = {} :: { [string]: Participant },
		ByPlayer = {} :: { [Player]: Participant },
		Phase = "Waiting",
		PlayState = "Live",
		Restart = nil :: MatchTypes.Restart?,
		Half = 0,
		Clock = 0,
		ClockRunning = false,
		PhaseEndsAt = nil :: number?,
		Score = { Red = 0, Blue = 0 },
		AttackDirection = { Red = 1, Blue = -1 },
		Possession = nil :: string?,
		PossessionStart = 0,
		PassiveWarning = nil :: { Team: string, Deadline: number }?,
		Ball = newBall(),
		SimAccumulator = 0,
		Scheduled = {} :: { { At: number, Fn: () -> () } },
		Connections = {} :: { RBXScriptConnection },
		Ended = false,
		GoldenGoal = false,
		StateDirty = true,
		BallDirty = true,
		LastStateSent = 0,
		LastBallSent = 0,
		Random = Random.new(),
		Results = nil :: Types.ResultsSnapshot?,
	}, Match)

	local counters = { Red = 0, Blue = 0 }
	for _, team in TEAMS do
		local list: { Player } = config.Teams[team] or {}
		for _, player in list do
			counters[team] += 1
			local participant = newParticipant(`P{player.UserId}`, player.DisplayName, team, counters[team], player)
			self:addParticipant(participant)
		end
	end
	if config.FillWithBots then
		local botIndex = 0
		for _, team in TEAMS do
			while counters[team] < mode.TeamSize do
				counters[team] += 1
				botIndex += 1
				local participant = newParticipant(`B{botIndex}`, `Bot {botIndex}`, team, counters[team], nil)
				self:addParticipant(participant)
			end
		end
	end
	return self
end

function Match.addParticipant(self: any, participant: Participant)
	table.insert(self.Participants, participant)
	self.ById[participant.Id] = participant
	if participant.Player then
		self.ByPlayer[participant.Player] = participant
	end
end

-- Helpers --------------------------------------------------------------------------------------------

function Match.isActive(self: any, p: Participant, t: number?): boolean
	local root = p.Root
	if not p.Connected or not root or not root.Parent then
		return false
	end
	return (t or now()) >= p.SuspendedUntil
end

function Match.canAct(self: any, p: Participant, t: number): boolean
	return self:isActive(p, t) and t >= p.StunnedUntil and t >= p.RecoveryUntil
end

function Match.inPlay(self: any): boolean
	return (self.Phase == "Playing" or self.Phase == "Overtime")
		and (self.PlayState == "Live" or self.PlayState == "Restart")
end

function Match.attackSide(self: any, team: string): number
	return self.AttackDirection[team]
end

function Match.defendSide(self: any, team: string): number
	return -self.AttackDirection[team]
end

function Match.toLocal(self: any, world: Vector3): Vector3
	return self.CourtCFrame:PointToObjectSpace(world)
end

function Match.toWorld(self: any, localPoint: Vector3): Vector3
	return self.CourtCFrame:PointToWorldSpace(localPoint)
end

function Match.localOf(self: any, p: Participant): Vector3
	local root = p.Root
	if not root then
		return Vector3.zero
	end
	local l = self:toLocal(root.Position)
	return Vector3.new(l.X, 0, l.Z)
end

function Match.onGround(self: any, p: Participant): boolean
	local humanoid = p.Humanoid
	if not humanoid then
		return true
	end
	return humanoid.FloorMaterial ~= Enum.Material.Air
end

function Match.handPoint(self: any, p: Participant): Vector3
	local root = p.Root
	if not root then
		return self.Ball.Position
	end
	return root.CFrame:PointToWorldSpace(Config.Ball.HoldOffset)
end

function Match.releasePoint(self: any, p: Participant): Vector3
	local root = p.Root
	if not root then
		return self.Ball.Position
	end
	return root.CFrame:PointToWorldSpace(Vector3.new(1, 2, -0.8))
end

function Match.keeperOf(self: any, team: string): Participant?
	for _, p in self.Participants do
		if p.Team == team and p.Role == "Goalkeeper" and p.Connected then
			return p
		end
	end
	return nil
end

function Match.teamOf(self: any, team: string): { Participant }
	local list = {}
	for _, p in self.Participants do
		if p.Team == team then
			table.insert(list, p)
		end
	end
	return list
end

function Match.schedule(self: any, delay: number, fn: () -> ())
	table.insert(self.Scheduled, { At = now() + delay, Fn = fn })
end

function Match.humans(self: any): { Player }
	local list = {}
	for _, p in self.Participants do
		local player = p.Player
		if player and p.Connected and player.Parent == Players then
			table.insert(list, player)
		end
	end
	return list
end

-- Network ---------------------------------------------------------------------------------------------

function Match.event(self: any, kind: string, data: { [string]: any }?)
	Remote.fireList(self:humans(), "MatchEvent", kind, data or {})
end

function Match.eventTo(self: any, p: Participant, kind: string, data: { [string]: any })
	if p.Player then
		Remote.fire(p.Player, "MatchEvent", kind, data)
	end
end

function Match.markState(self: any)
	self.StateDirty = true
end

function Match.markBall(self: any)
	self.BallDirty = true
end

function Match.participantSnapshot(self: any, p: Participant): Types.ParticipantSnapshot
	return {
		Id = p.Id,
		UserId = p.UserId,
		Name = p.Name,
		Team = p.Team,
		Role = p.Role,
		IsBot = p.IsBot,
		Model = p.Model,
		Number = p.Number,
		Connected = p.Connected,
		Goals = p.Goals,
		Assists = p.Assists,
		Saves = p.Saves,
		Interceptions = p.Interceptions,
		Blocks = p.Blocks,
		Fouls = p.Fouls,
		Warned = p.Warned,
		SuspendedUntil = p.SuspendedUntil,
		DashReadyAt = p.DashReadyAt,
	}
end

function Match.snapshot(self: any): Types.MatchSnapshot
	local participants = {}
	for _, p in self.Participants do
		table.insert(participants, self:participantSnapshot(p))
	end
	local restart: Types.Restart? = nil
	local r = self.Restart
	if r then
		restart = {
			Kind = r.Kind,
			Team = r.Team,
			ThrowerId = r.Thrower.Id,
			Position = self:toWorld(r.Position),
			Deadline = r.Deadline,
		}
	end
	return {
		Id = self.Id,
		Mode = self.Config.Mode,
		Phase = self.Phase,
		PlayState = self.PlayState,
		Restart = restart,
		Half = self.Half,
		Clock = self.Clock,
		ClockRunning = self.ClockRunning and self.PlayState ~= "Goal",
		PhaseEndsAt = self.PhaseEndsAt,
		ServerTime = now(),
		Score = { Red = self.Score.Red, Blue = self.Score.Blue },
		AttackDirection = { Red = self.AttackDirection.Red, Blue = self.AttackDirection.Blue },
		Possession = self.Possession,
		PassiveWarning = self.PassiveWarning,
		CourtCFrame = self.CourtCFrame,
		Participants = participants,
	}
end

function Match.ballSnapshot(self: any): Types.BallSnapshot
	local ball = self.Ball
	return {
		State = ball.State,
		HolderId = if ball.Holder then ball.Holder.Id else nil,
		Position = ball.Position,
		Velocity = ball.Velocity,
		ServerTime = now(),
		Throw = ball.Throw,
		ThrowerId = if ball.Thrower then ball.Thrower.Id else nil,
		TargetId = if ball.Target then ball.Target.Id else nil,
		Charge = ball.Charge,
		Dribbling = ball.Dribbling,
		HasDribbled = ball.HasDribbled,
		HoldStart = ball.HoldStart,
		Steps = ball.Steps,
	}
end

function Match.broadcast(self: any, t: number)
	local stateInterval = 1 / Config.Match.StateBroadcastRate
	if (self.StateDirty and t - self.LastStateSent > 0.05) or t - self.LastStateSent > stateInterval then
		self.StateDirty = false
		self.LastStateSent = t
		Remote.fireList(self:humans(), "MatchState", self:snapshot())
	end
	local ball = self.Ball
	local rate = if ball.State == "Flight" or (ball.State == "Loose" and ball.Velocity.Magnitude > 0.5)
		then Config.Net.BallBroadcastRate
		elseif ball.State == "Held" then HELD_BALL_RATE
		else 1
	if (self.BallDirty and t - self.LastBallSent > BALL_MIN_SEND_INTERVAL) or t - self.LastBallSent > 1 / rate then
		self.BallDirty = false
		self.LastBallSent = t
		Remote.fireList(self:humans(), "BallState", self:ballSnapshot())
	end
end

-- Bodies ------------------------------------------------------------------------------------------------

function Match.setAttribute(self: any, p: Participant, name: string, value: any)
	if p.Attributes[name] == value then
		return
	end
	p.Attributes[name] = value
	local model = p.Model
	if model then
		model:SetAttribute(name, value)
	end
end

function Match.speedFor(self: any, p: Participant, t: number): number
	local m = Config.Movement
	if p.Frozen or t < p.SuspendedUntil then
		return 0
	end
	if t < p.DiveRecoveryUntil and t >= p.DiveStart then
		return 0
	end
	local holder = self.Ball.State == "Held" and self.Ball.Holder == p
	local speed
	if p.ChargeStart then
		speed = m.ChargingSpeed
	elseif t < p.BlockUntil then
		speed = m.StanceSpeed
	elseif holder then
		if self.Ball.Dribbling then
			speed = m.DribbleSpeed
		elseif p.Sprinting then
			speed = m.CarrierSpeed
		else
			speed = m.RunSpeed
		end
	elseif p.Stance then
		speed = m.StanceSpeed
	elseif p.Role == "Goalkeeper" then
		speed = if p.Sprinting then m.KeeperSpeed + 4 else m.KeeperSpeed
	elseif p.Sprinting then
		speed = m.SprintSpeed
	else
		speed = m.RunSpeed
	end
	if t < p.StunnedUntil then
		speed *= 0.35
	elseif t < p.MissRecoveryUntil and not p.InterceptHit then
		speed *= 0.6
	end
	return speed
end

function Match.applyBodies(self: any, t: number)
	local ball = self.Ball
	for _, p in self.Participants do
		local humanoid = p.Humanoid
		if humanoid and p.Model then
			local speed = self:speedFor(p, t)
			if speed ~= p.AppliedSpeed then
				p.AppliedSpeed = speed
				humanoid.WalkSpeed = speed
				if p.Player then
					AntiExploitService.setMaxSpeed(p.Player, speed)
				end
			end
			local jump = if p.Frozen
					or p.ChargeStart
					or t < p.StunnedUntil
					or t < p.SuspendedUntil
				then 0
				else Config.Movement.JumpPower
			if jump ~= p.AppliedJump then
				p.AppliedJump = jump
				humanoid.UseJumpPower = true
				humanoid.JumpPower = jump
			end
			local hasBall = ball.State == "Held" and ball.Holder == p
			self:setAttribute(p, "HL_ParticipantId", p.Id)
			self:setAttribute(p, "HL_Team", p.Team)
			self:setAttribute(p, "HL_Role", p.Role)
			self:setAttribute(p, "HL_HasBall", hasBall)
			self:setAttribute(p, "HL_Dribbling", hasBall and ball.Dribbling)
			self:setAttribute(p, "HL_Charging", p.ChargeStart ~= nil)
			self:setAttribute(p, "HL_Stance", p.Stance and not hasBall)
			self:setAttribute(p, "HL_Blocking", t < p.BlockUntil)
			self:setAttribute(p, "HL_InterceptUntil", p.InterceptUntil)
			self:setAttribute(p, "HL_DashUntil", p.DashUntil)
			self:setAttribute(p, "HL_DiveStart", p.DiveStart)
			self:setAttribute(p, "HL_DiveTarget", p.DiveEnd)
			self:setAttribute(p, "HL_StunnedUntil", p.StunnedUntil)
			self:setAttribute(p, "HL_Suspended", t < p.SuspendedUntil)
			self:setAttribute(p, "HL_Frozen", p.Frozen == true)
			self:setAttribute(p, "HL_RecoveryUntil", math.max(p.RecoveryUntil, p.DiveRecoveryUntil))
		end
	end
end

-- Binds a character model to a participant (initial spawn or respawn).
function Match.bind(self: any, p: Participant, model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	p.Model = model
	p.Humanoid = humanoid
	p.Root = root
	p.Attributes = {}
	p.AppliedSpeed = -1
	p.AppliedJump = -1
	if p.RoleChosen or self.Phase ~= "Selection" then
		Appearance.apply(model, p.Team, p.Role, p.Number)
	end
	self:markState()
end

function Match.teleport(self: any, p: Participant, localPoint: Vector3, faceLocal: Vector3?)
	local model = p.Model
	local root = p.Root
	if not model or not root then
		return
	end
	local inside = CourtGeometry.clampInside(self.Court, localPoint, -6)
	local world = self:toWorld(Vector3.new(inside.X, 3, inside.Z))
	local facing = faceLocal or Vector3.new(self:attackSide(p.Team), 0, 0)
	local worldFacing = self.CourtCFrame:VectorToWorldSpace(flat(facing))
	if worldFacing.Magnitude < 0.01 then
		worldFacing = self.CourtCFrame.LookVector
	end
	local cframe = CFrame.lookAt(world, world + worldFacing.Unit)
	model:PivotTo(cframe)
	root.AssemblyLinearVelocity = Vector3.zero
	if p.Player then
		AntiExploitService.notifyTeleport(p.Player, root.CFrame)
	end
end

-- Formation for a throw-off: keepers in goal, field players in their own half.
function Match.formation(self: any, throwOffTeam: string?)
	local court = self.Court
	for _, team in TEAMS do
		local side = self:defendSide(team)
		local field = {}
		for _, p in self:teamOf(team) do
			if self:isActive(p) then
				if p.Role == "Goalkeeper" then
					self:teleport(p, Vector3.new(side * (court.HalfLength - 2.5), 0, 0))
				else
					table.insert(field, p)
				end
			end
		end
		for index, p in field do
			local spread = if #field > 1 then (index - 1) / (#field - 1) - 0.5 else 0
			local x = side * court.HalfLength * (0.22 + 0.12 * ((index + 1) % 2))
			local z = spread * court.HalfWidth * 1.3
			if team == throwOffTeam and index == 1 then
				x = side * 1.5
				z = 0
			end
			self:teleport(p, Vector3.new(x, 0, z))
		end
	end
end

-- Ball possession ------------------------------------------------------------------------------------

function Match.setPossession(self: any, team: string?)
	if self.Possession ~= team then
		self.Possession = team
		self.PossessionStart = now()
		self.PassiveWarning = nil
		self:markState()
	end
end

function Match.giveBall(self: any, p: Participant, how: string)
	local ball = self.Ball
	local t = now()
	local thrower = ball.Thrower
	if
		how == "Catch"
		and thrower
		and thrower ~= p
		and thrower.Team == p.Team
		and ball.Throw
		and PASS_THROWS[ball.Throw]
	then
		ball.AssistId = thrower.Id
		ball.AssistTeam = p.Team
		ball.AssistTime = t
	elseif ball.AssistTeam ~= p.Team then
		ball.AssistId = nil
		ball.AssistTeam = nil
	end
	ball.State = "Held"
	ball.Holder = p
	ball.Velocity = Vector3.zero
	ball.Position = self:handPoint(p)
	ball.Throw = nil
	ball.Thrower = nil
	ball.Target = nil
	ball.ThrowTeam = nil
	ball.Charge = nil
	ball.ShotSide = nil
	ball.LastToucher = p
	ball.LastTouchTeam = p.Team
	ball.Dribbling = false
	ball.HasDribbled = false
	ball.KeeperAreaHold = p.Role == "Goalkeeper"
		and CourtGeometry.inGoalArea(self.Court, self:localOf(p), self:defendSide(p.Team))
	ball.HoldStart = t
	ball.Steps = 0
	ball.StepDistance = 0
	ball.LastHolderPosition = if p.Root then p.Root.Position else nil
	ball.LooseInAreaTime = 0
	p.ChargeStart = nil
	p.Stance = false
	self:setPossession(p.Team)
	if how == "Catch" or how == "Pickup" then
		self:event("Catch", { Id = p.Id })
	end
	self:markBall()
end

function Match.releaseBall(
	self: any,
	p: Participant,
	throw: string,
	velocity: Vector3,
	origin: Vector3,
	target: Participant?,
	charge: number?
)
	local ball = self.Ball
	local t = now()
	ball.State = "Flight"
	ball.Holder = nil
	ball.Position = origin
	ball.Velocity = velocity
	ball.Throw = throw
	ball.Thrower = p
	ball.ThrowTeam = p.Team
	ball.Target = target
	ball.Charge = charge
	ball.ReleaseTime = t
	ball.LastToucher = p
	ball.LastTouchTeam = p.Team
	ball.Dribbling = false
	ball.ShotSide = if SHOT_THROWS[throw] then self:attackSide(p.Team) else nil
	p.ChargeStart = nil
	self.SimAccumulator = 0
	if self.PlayState == "Restart" then
		self:endRestart()
	end
	self:markBall()
end

-- Drops the ball loose at a point with a velocity (steal, deflection, parry).
function Match.looseBall(self: any, position: Vector3, velocity: Vector3, toucher: Participant?)
	local ball = self.Ball
	ball.State = "Loose"
	ball.Holder = nil
	ball.Position = position
	ball.Velocity = velocity
	ball.Throw = "Free"
	ball.Thrower = toucher
	ball.ThrowTeam = if toucher then toucher.Team else nil
	ball.Target = nil
	ball.Charge = nil
	ball.ShotSide = nil
	ball.ReleaseTime = now()
	ball.Dribbling = false
	if toucher then
		ball.LastToucher = toucher
		ball.LastTouchTeam = toucher.Team
		toucher.ChargeStart = nil
	end
	self.SimAccumulator = 0
	self:markBall()
end

-- Restarts and whistles ------------------------------------------------------------------------------------

function Match.endRestart(self: any)
	self.PlayState = "Live"
	self.Restart = nil
	for _, p in self.Participants do
		p.Frozen = false
	end
	self:markState()
end

-- Picks who takes a restart throw for `team` at a local position.
function Match.pickThrower(self: any, kind: string, team: string, localPoint: Vector3): Participant?
	if kind == "GoalkeeperThrow" then
		local keeper = self:keeperOf(team)
		if keeper and self:isActive(keeper) then
			return keeper
		end
	end
	local best: Participant? = nil
	local bestDistance = math.huge
	for _, p in self.Participants do
		if p.Team == team and self:isActive(p) and (p.Role ~= "Goalkeeper" or kind == "GoalkeeperThrow") then
			local distance = (self:localOf(p) - Vector3.new(localPoint.X, 0, localPoint.Z)).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = p
			end
		end
	end
	if not best then
		-- Only the keeper is left on the court.
		for _, p in self.Participants do
			if p.Team == team and self:isActive(p) then
				return p
			end
		end
	end
	return best
end

-- Legal position for a throw of `kind` taken by `team`.
function Match.restartPosition(self: any, kind: string, team: string, localPoint: Vector3): Vector3
	local court = self.Court
	local attack = self:attackSide(team)
	local defend = -attack
	local point = Vector3.new(localPoint.X, 0, localPoint.Z)
	if kind == "ThrowOff" then
		return Vector3.zero
	elseif kind == "Penalty" then
		return CourtGeometry.penaltySpot(court, attack)
	elseif kind == "GoalkeeperThrow" then
		return Vector3.new(defend * (court.HalfLength - court.Mode.GoalAreaRadius * 0.55), 0, 0)
	elseif kind == "Corner" then
		local z = if point.Z >= 0 then court.HalfWidth - 0.5 else -court.HalfWidth + 0.5
		return Vector3.new(attack * (court.HalfLength - 0.5), 0, z)
	elseif kind == "ThrowIn" then
		local z = if point.Z >= 0 then court.HalfWidth - 0.5 else -court.HalfWidth + 0.5
		return Vector3.new(math.clamp(point.X, -court.HalfLength + 1, court.HalfLength - 1), 0, z)
	end
	-- Free throw: on the 9 m line if the offence happened inside it, never in a goal area.
	point = CourtGeometry.clampInside(court, point, 1)
	if CourtGeometry.inFreeThrowZone(court, point, attack) then
		point = CourtGeometry.pushOutOfRadius(court, point, attack, court.Mode.FreeThrowRadius)
	end
	if CourtGeometry.inGoalArea(court, point, defend) then
		point = CourtGeometry.pushOutOfRadius(court, point, defend, court.Mode.GoalAreaRadius)
	end
	return CourtGeometry.clampInside(court, point, 1)
end

-- Moves `p` radially away from `center` to at least `distance` (local space),
-- never into a goal area for field players.
function Match.pushAway(self: any, p: Participant, center: Vector3, distance: number)
	local position = self:localOf(p)
	local offset = flat(position - center)
	if offset.Magnitude >= distance then
		return
	end
	local direction = if offset.Magnitude > 0.1 then offset.Unit else Vector3.new(self:defendSide(p.Team), 0, 0)
	local target = center + direction * (distance + 1)
	target = CourtGeometry.clampInside(self.Court, target, 1)
	if p.Role ~= "Goalkeeper" then
		for _, side in { 1, -1 } do
			if CourtGeometry.inGoalArea(self.Court, target, side) then
				target = CourtGeometry.pushOutOfRadius(self.Court, target, side, self.Court.Mode.GoalAreaRadius)
			end
		end
	end
	self:teleport(p, target)
end

function Match.startRestart(
	self: any,
	kind: string,
	team: string,
	localPoint: Vector3,
	reason: string?,
	offender: Participant?
)
	local t = now()
	local court = self.Court
	local position = self:restartPosition(kind, team, localPoint)
	local thrower = self:pickThrower(kind, team, position)
	if not thrower then
		return
	end
	local attack = self:attackSide(team)
	local ball = self.Ball

	-- Stop whatever was happening.
	for _, p in self.Participants do
		p.ChargeStart = nil
		p.AreaTime = 0
	end
	ball.State = "Dead"
	ball.Holder = nil

	if kind == "ThrowOff" then
		self:formation(team)
	end
	-- Only the new thrower stays frozen (a previous thrower who timed out is released).
	for _, p in self.Participants do
		p.Frozen = false
	end
	self:teleport(thrower, position, Vector3.new(attack, 0, 0))
	thrower.Frozen = true

	if kind == "Penalty" then
		local defending = Rules.other(team)
		local keeper = self:keeperOf(defending)
		for _, p in self.Participants do
			if p ~= thrower and p ~= keeper and self:isActive(p) then
				local goal = CourtGeometry.goalCenter(court, attack)
				if CourtGeometry.inFreeThrowZone(court, self:localOf(p), attack) then
					self:pushAway(p, goal, court.Mode.FreeThrowRadius)
				end
			end
		end
		if keeper and self:isActive(keeper) then
			self:teleport(keeper, Vector3.new(attack * (court.HalfLength - 1.2), 0, 0), Vector3.new(-attack, 0, 0))
		end
	elseif kind ~= "ThrowOff" then
		for _, p in self.Participants do
			if p ~= thrower and self:isActive(p) then
				if p.Team ~= team then
					self:pushAway(p, position, Config.Rules.SetPieceDistance)
				elseif kind == "FreeThrow" and CourtGeometry.inFreeThrowZone(court, self:localOf(p), attack) then
					self:pushAway(p, CourtGeometry.goalCenter(court, attack), court.Mode.FreeThrowRadius)
				end
			end
		end
	end

	self:giveBall(thrower, "Restart")
	self.PlayState = "Restart"
	local setup = if kind == "ThrowOff" then Config.Match.RestartSetupTime else 0
	self.Restart = {
		Kind = kind,
		Team = team,
		Thrower = thrower,
		Position = position,
		Deadline = t + setup + Config.Match.RestartThrowTimeout,
	}
	if kind == "ThrowOff" then
		-- Everybody holds position for a moment, then only the thrower stays still.
		for _, p in self.Participants do
			p.Frozen = true
		end
		local restart = self.Restart
		self:schedule(setup, function()
			if self.Restart == restart and self:inPlay() then
				for _, p in self.Participants do
					if p ~= thrower then
						p.Frozen = false
					end
				end
			end
		end)
	end
	self:setPossession(team)
	self.PassiveWarning = nil

	local worldPosition = self:toWorld(position)
	if reason then
		local text = Rules.text(reason, team)
		self:event("Whistle", {
			Reason = reason,
			Text = text,
			Kind = kind,
			Team = team,
			OffenderId = if offender then offender.Id else nil,
			Position = worldPosition,
		})
	end
	self:event("Restart", { Kind = kind, Team = team, ThrowerId = thrower.Id, Position = worldPosition })
	self:markState()
end

-- A violation by `offender`: the other team gets a free throw (or `kind`).
function Match.violation(self: any, reason: string, offender: Participant?, localPoint: Vector3, kind: string?)
	local team = if offender then Rules.other(offender.Team) else (self.Possession or "Red")
	self:startRestart(kind or "FreeThrow", team, localPoint, reason, offender)
end

-- Progressive punishment for persistent fouls: warning, then suspensions.
function Match.applySanction(self: any, offender: Participant)
	local t = now()
	if not offender.Warned then
		if offender.Fouls >= Config.Rules.FoulsBeforeWarning then
			offender.Warned = true
			self:event("Warning", { Id = offender.Id })
			self:markState()
		end
		return
	end
	-- After the warning, every further foul is a suspension.
	offender.SuspendedUntil = t + Config.Rules.SuspensionTime
	offender.ChargeStart = nil
	if self.Ball.Holder == offender then
		self:looseBall(self:handPoint(offender), Vector3.zero, offender)
	end
	local bench = self.Bench[offender.Team]
	if bench and offender.Model then
		offender.Model:PivotTo(CFrame.new(bench + Vector3.new(0, 3, 0)))
		if offender.Player and offender.Root then
			AntiExploitService.notifyTeleport(offender.Player, offender.Root.CFrame)
		end
	end
	self:event("Suspension", { Id = offender.Id, Until = offender.SuspendedUntil })
	self:markState()
end

function Match.suspensions(self: any, t: number)
	for _, p in self.Participants do
		if p.SuspendedUntil > 0 and t >= p.SuspendedUntil then
			p.SuspendedUntil = 0
			local side = self:defendSide(p.Team)
			self:teleport(p, Vector3.new(side * self.Court.HalfLength * 0.3, 0, self.Court.HalfWidth - 2))
			self:markState()
		end
	end
end

-- Goals and the ball leaving the court ------------------------------------------------------------------------

function Match.scoreGoal(self: any, side: number, worldPosition: Vector3)
	local scoringTeam = if self.AttackDirection.Red == side then "Red" else "Blue"
	local ball = self.Ball
	local t = now()
	local toucher = ball.LastToucher
	local scorer: Participant? = if toucher and toucher.Team == scoringTeam then toucher else nil
	local assist: Participant? = nil
	if scorer then
		scorer.Goals += 1
		if
			ball.AssistId
			and ball.AssistTeam == scoringTeam
			and ball.AssistId ~= scorer.Id
			and t - ball.AssistTime < 6
		then
			assist = self.ById[ball.AssistId]
			if assist then
				assist.Assists += 1
			end
		end
	end
	self.Score[scoringTeam] += 1
	ball.State = "Dead"
	ball.Holder = nil
	ball.Velocity = Vector3.zero
	self.PlayState = "Goal"
	self.Restart = nil
	self.PassiveWarning = nil
	for _, p in self.Participants do
		p.ChargeStart = nil
	end
	self:event("Goal", {
		Team = scoringTeam,
		ScorerId = if scorer then scorer.Id else nil,
		AssistId = if assist then assist.Id else nil,
		Position = worldPosition,
	})
	self:markState()
	self:markBall()
	if self.Phase == "Overtime" then
		self.GoldenGoal = true
		return
	end
	local conceding = Rules.other(scoringTeam)
	self:schedule(Config.Match.GoalCelebrationTime, function()
		if self.PlayState == "Goal" and not self.Ended and (self.Phase == "Playing" or self.Phase == "Overtime") then
			if self.Clock > 0 then
				self:startRestart("ThrowOff", conceding, Vector3.zero, nil, nil)
			else
				self.PlayState = "Live"
				self:markState()
			end
		end
	end)
end

function Match.ballOut(self: any, localPoint: Vector3)
	local court = self.Court
	local ball = self.Ball
	local lastTeam = ball.LastTouchTeam or self.Possession or "Red"
	if math.abs(localPoint.Z) > court.HalfWidth then
		self:startRestart("ThrowIn", Rules.other(lastTeam), localPoint, "OutOfBounds", nil)
		return
	end
	local side = if localPoint.X > 0 then 1 else -1
	local defending = if self.AttackDirection.Red == side then "Blue" else "Red"
	local attacking = Rules.other(defending)
	local toucher = ball.LastToucher
	local keeperTouched = toucher ~= nil and toucher.Team == defending and toucher.Role == "Goalkeeper"
	if lastTeam == attacking or keeperTouched then
		self:startRestart("GoalkeeperThrow", defending, localPoint, "GoalkeeperThrow", nil)
	else
		self:startRestart("Corner", attacking, localPoint, "Corner", nil)
	end
end

-- Posts and crossbar (local space). Returns the corrected position/velocity.
function Match.goalFrame(self: any, position: Vector3, velocity: Vector3): (Vector3, Vector3, boolean)
	local court = self.Court
	local radius = Config.Ball.Radius + 0.35
	local localPosition = self:toLocal(position)
	local localVelocity = self.CourtCFrame:VectorToObjectSpace(velocity)
	local floor = 0
	local hit = false
	for _, side in { 1, -1 } do
		local goalX = side * court.HalfLength
		if math.abs(localPosition.X - goalX) < radius + 0.5 then
			-- Posts (vertical cylinders).
			for _, postZ in { Config.Goal.Width / 2, -Config.Goal.Width / 2 } do
				local offset = Vector3.new(localPosition.X - goalX, 0, localPosition.Z - postZ)
				if offset.Magnitude < radius and localPosition.Y < floor + Config.Goal.Height + radius then
					local normal = if offset.Magnitude > 0.01 then offset.Unit else Vector3.new(-side, 0, 0)
					local into = localVelocity:Dot(normal)
					if into < 0 then
						localVelocity -= normal * into * (1 + Config.Ball.WallRestitution)
					end
					localPosition = Vector3.new(goalX, localPosition.Y, postZ) + normal * radius
					hit = true
				end
			end
			-- Crossbar (horizontal cylinder along Z).
			if math.abs(localPosition.Z) <= Config.Goal.Width / 2 then
				local offset = Vector3.new(localPosition.X - goalX, localPosition.Y - (floor + Config.Goal.Height), 0)
				if offset.Magnitude < radius then
					local normal = if offset.Magnitude > 0.01 then offset.Unit else Vector3.new(0, 1, 0)
					local into = localVelocity:Dot(normal)
					if into < 0 then
						localVelocity -= normal * into * (1 + Config.Ball.WallRestitution)
					end
					local anchor = Vector3.new(goalX, floor + Config.Goal.Height, localPosition.Z)
					localPosition = anchor + normal * radius
					hit = true
				end
			end
		end
	end
	if not hit then
		return position, velocity, false
	end
	return self:toWorld(localPosition), self.CourtCFrame:VectorToWorldSpace(localVelocity), true
end

-- Ball simulation -----------------------------------------------------------------------------------------------

function Match.blockHits(self: any, p: Participant, a: Vector3, b: Vector3): boolean
	local root = p.Root
	if not root then
		return false
	end
	local base = root.Position
	local ab = b - a
	local lengthSq = ab:Dot(ab)
	local tParam = if lengthSq > 1e-6 then math.clamp((base - a):Dot(ab) / lengthSq, 0, 1) else 0
	local point = a + ab * tParam
	local horizontal = flat(point - base).Magnitude
	local height = point.Y - self.FloorY
	return horizontal < Config.Defense.BlockReach and height > 2.5 and height < Config.Defense.BlockHeight
end

function Match.save(self: any, keeper: Participant, point: Vector3)
	local ball = self.Ball
	local speed = ball.Velocity.Magnitude
	keeper.Saves += 1
	local caught = speed < Config.Keeper.CatchMaxSpeed
	self:event("Save", { KeeperId = keeper.Id, Caught = caught, Position = point })
	if caught then
		self:giveBall(keeper, "Save")
		return
	end
	-- Parry: the ball bounces back into the court, away from the goal.
	local localVelocity = self.CourtCFrame:VectorToObjectSpace(ball.Velocity)
	local away = Vector3.new(-localVelocity.X, 0, localVelocity.Z * 0.6)
	if away.Magnitude < 0.1 then
		away = Vector3.new(-(ball.ShotSide or 1), 0, 0)
	end
	local parried = away.Unit * Config.Keeper.ParrySpeed + Vector3.new(0, Config.Keeper.ParrySpeed * 0.45, 0)
	self:looseBall(point, self.CourtCFrame:VectorToWorldSpace(parried), keeper)
	self.Ball.Throw = "Parry"
end

function Match.deflect(self: any, p: Participant, point: Vector3)
	local velocity = self.Ball.Velocity
	p.Blocks += 1
	self:event("Block", { Id = p.Id, Position = point })
	local bounced = -velocity * 0.25 + Vector3.new(0, 14, 0)
	self:looseBall(point, bounced, p)
end

function Match.intercept(self: any, p: Participant, point: Vector3)
	p.Interceptions += 1
	p.InterceptHit = true
	p.MissRecoveryUntil = 0
	self:event("Intercept", { Id = p.Id, Position = point })
	self:giveBall(p, "Intercept")
end

-- Checks every participant against the ball segment a → b. Returns true if the
-- ball changed state (the substep loop stops).
function Match.interact(self: any, a: Vector3, b: Vector3, t: number): boolean
	local ball = self.Ball
	local throw = ball.Throw
	local isShot = throw ~= nil and SHOT_THROWS[throw] == true
	local isPass = throw ~= nil and PASS_THROWS[throw] == true
	local inFlight = ball.State == "Flight"
	local speed = ball.Velocity.Magnitude
	local bLocal = self:toLocal(b)
	for _, p in self.Participants do
		local root = p.Root
		if root and self:isActive(p, t) then
			local immune = p == ball.Thrower and t - ball.ReleaseTime < Config.Ball.ReleaseImmunity
			if not immune then
				local opponent = ball.ThrowTeam ~= nil and p.Team ~= ball.ThrowTeam
				-- 1. Goalkeeper saves (shots only).
				if
					inFlight
					and isShot
					and opponent
					and p.Role == "Goalkeeper"
					and Goalkeeper.touches(p, a, b, t, self.FloorY)
				then
					self:save(p, b)
					return true
				end
				if t >= p.StunnedUntil then
					-- 2. Raised arms.
					if inFlight and opponent and t < p.BlockUntil and self:blockHits(p, a, b) then
						self:deflect(p, b)
						return true
					end
					-- 3. Interception window.
					if inFlight and opponent and t < p.InterceptUntil then
						local hands = root.Position + Vector3.new(0, 1.2, 0)
						if BallPhysics.segmentDistance(a, b, hands) < Config.Defense.InterceptReach then
							if isPass then
								self:intercept(p, b)
							else
								p.InterceptHit = true
								self:deflect(p, b)
							end
							return true
						end
					end
					-- 4. Pass reception (intended receiver, or any teammate for an aimed pass).
					if isPass and not opponent and p ~= ball.Thrower and (ball.Target == p or ball.Target == nil) then
						local chest = root.Position + Vector3.new(0, 0.5, 0)
						if BallPhysics.segmentDistance(a, b, chest) < Config.Ball.CatchRadius then
							self:giveBall(p, "Catch")
							return true
						end
					end
					-- 5. Loose / slow ball pickup.
					if speed < Config.Ball.LooseBallSpeed and (ball.State == "Loose" or inFlight) then
						local horizontal = flat(b - root.Position).Magnitude
						if horizontal < Config.Ball.PickupRadius and b.Y < self.FloorY + 4.5 then
							local allowed = true
							for _, side in { 1, -1 } do
								if CourtGeometry.inGoalArea(self.Court, bLocal, side) then
									allowed = p.Role == "Goalkeeper" and self:defendSide(p.Team) == side
								end
							end
							if allowed then
								self:giveBall(p, "Pickup")
								return true
							end
						end
					end
				end
			end
		end
	end
	return false
end

function Match.stepBall(self: any, dt: number, t: number)
	local ball = self.Ball
	if ball.State == "Held" then
		local holder = ball.Holder
		if holder then
			ball.Position = self:handPoint(holder)
		end
		return
	end
	if ball.State ~= "Flight" and ball.State ~= "Loose" then
		return
	end
	local step = Config.Ball.SimStep
	self.SimAccumulator = math.min(self.SimAccumulator + dt, step * MAX_SUBSTEPS)
	while self.SimAccumulator >= step do
		self.SimAccumulator -= step
		local a = ball.Position
		local position, velocity, bounced = BallPhysics.step(a, ball.Velocity, step, self.FloorY)
		local framed, framedVelocity, hitFrame = self:goalFrame(position, velocity)
		if hitFrame then
			position, velocity = framed, framedVelocity
			self:event("Post", { Position = position })
			self:markBall()
		end
		ball.Position = position
		ball.Velocity = velocity
		if bounced then
			if ball.State == "Flight" then
				ball.State = "Loose"
				self:markBall()
			end
			if velocity.Magnitude > 20 then
				self:event("Bounce", { Position = position, Speed = velocity.Magnitude })
			end
		end

		-- Goal?
		local aLocal = self:toLocal(a)
		local bLocal = self:toLocal(position)
		for _, side in { 1, -1 } do
			if CourtGeometry.crossesGoal(self.Court, aLocal, bLocal, side) then
				self:scoreGoal(side, position)
				return
			end
		end
		-- Out of the court?
		local radius = Config.Ball.Radius
		if
			math.abs(bLocal.Z) > self.Court.HalfWidth + radius
			or math.abs(bLocal.X) > self.Court.HalfLength + radius
		then
			self:ballOut(bLocal)
			return
		end
		if self:interact(a, position, t) then
			return
		end
		if ball.State == "Flight" and t - ball.ReleaseTime > 4 then
			ball.State = "Loose"
			self:markBall()
		end
	end
end

-- Rules applied every frame ------------------------------------------------------------------------------------

function Match.holderRules(self: any, t: number, dt: number)
	if self.PlayState ~= "Live" then
		return
	end
	local ball = self.Ball
	local holder = ball.Holder
	if not holder or not holder.Root then
		return
	end
	local court = self.Court
	local position = self:localOf(holder)
	local grounded = self:onGround(holder)
	local attack = self:attackSide(holder.Team)
	local defend = -attack

	-- Out of the court with the ball.
	if grounded and (math.abs(position.Z) > court.HalfWidth + 0.5 or math.abs(position.X) > court.HalfLength + 0.5) then
		self:startRestart("ThrowIn", Rules.other(holder.Team), position, "OutOfBounds", holder)
		return
	end

	-- A goalkeeper who took the ball in their area may move freely inside it but
	-- may not leave it with the ball; outside it they play as a field player.
	local keeperHold = holder.Role == "Goalkeeper" and ball.KeeperAreaHold
	local keeperInArea = keeperHold and CourtGeometry.inGoalArea(court, position, defend)
	if keeperHold and not keeperInArea and grounded then
		holder.AreaTime += dt
		if holder.AreaTime > AREA_TOLERANCE then
			self:violation("KeeperLeftArea", holder, position)
		end
		return
	end

	-- Goal areas (field players, and a goalkeeper playing outside the area).
	if not keeperHold and grounded then
		if CourtGeometry.inGoalArea(court, position, attack) then
			holder.AreaTime += dt
			if holder.AreaTime > AREA_TOLERANCE * 0.5 then
				self:startRestart("GoalkeeperThrow", Rules.other(holder.Team), position, "AttackerInArea", holder)
			end
			return
		elseif CourtGeometry.inGoalArea(court, position, defend) then
			holder.AreaTime += dt
			if holder.AreaTime > AREA_TOLERANCE then
				self:violation("OwnArea", holder, position)
			end
			return
		end
	end
	holder.AreaTime = 0

	if keeperInArea or ball.Dribbling then
		ball.LastHolderPosition = holder.Root.Position
		return
	end

	-- 3 seconds.
	if t - ball.HoldStart > Config.Rules.MaxHoldTime then
		self:violation("ThreeSeconds", holder, position)
		return
	end

	-- 3 steps: ground distance only (jumping does not count).
	local current = holder.Root.Position
	local last = ball.LastHolderPosition
	ball.LastHolderPosition = current
	if grounded and last then
		local moved = flat(current - last).Magnitude
		if moved < 8 then -- ignore teleports
			ball.StepDistance += moved
		end
		local steps = math.min(Config.Rules.MaxSteps + 1, math.floor(ball.StepDistance / Config.Rules.StepLength))
		if steps ~= ball.Steps then
			ball.Steps = steps
			self:markBall()
		end
		if ball.StepDistance > (Config.Rules.MaxSteps + Config.Rules.StepGrace) * Config.Rules.StepLength then
			self:violation("Steps", holder, position)
		end
	end
end

-- Players without the ball inside a goal area.
function Match.areaRules(self: any, t: number, dt: number)
	if self.PlayState ~= "Live" or not self.Possession then
		return
	end
	local court = self.Court
	local ball = self.Ball
	local holder = if ball.State == "Held" then ball.Holder else nil
	for _, p in self.Participants do
		if p.Role ~= "Goalkeeper" and p ~= holder and self:isActive(p, t) and self:onGround(p) then
			local position = self:localOf(p)
			local attack = self:attackSide(p.Team)
			local defend = -attack
			local illegal = false
			if p.Team == self.Possession and CourtGeometry.inGoalArea(court, position, attack) then
				-- Attacker gaining an advantage: close to the ball or receiving it.
				local ballLocal = self:toLocal(ball.Position)
				illegal = flat(ballLocal - position).Magnitude < 10 or ball.Target == p
				if illegal then
					p.AreaTime += dt
					if p.AreaTime > AREA_TOLERANCE then
						self:startRestart("FreeThrow", Rules.other(p.Team), position, "AttackerInAreaNoBall", p)
						return
					end
				end
			elseif p.Team ~= self.Possession and CourtGeometry.inGoalArea(court, position, defend) then
				-- Defender defending inside their own area.
				if holder and flat(self:localOf(holder) - position).Magnitude < 9 then
					illegal = true
					p.AreaTime += dt
					if p.AreaTime > AREA_TOLERANCE then
						local holderPosition = self:localOf(holder)
						local defenders = {}
						for _, other in self.Participants do
							if
								other ~= p
								and other.Team == p.Team
								and other.Role ~= "Goalkeeper"
								and self:isActive(other, t)
							then
								table.insert(defenders, self:localOf(other))
							end
						end
						if Rules.isClearChance(court, holderPosition, self:attackSide(holder.Team), defenders) then
							self:startRestart("Penalty", holder.Team, holderPosition, "Penalty", p)
						else
							self:startRestart("FreeThrow", holder.Team, holderPosition, "DefenderInArea", p)
						end
						return
					end
				end
			end
			if not illegal then
				p.AreaTime = 0
			end
		end
	end
end

function Match.passivePlay(self: any, t: number)
	if self.PlayState ~= "Live" or not self.Possession then
		return
	end
	local warning = self.PassiveWarning
	if not warning then
		if t - self.PossessionStart > Config.Rules.PassivePlayTime then
			self.PassiveWarning = { Team = self.Possession, Deadline = t + Config.Rules.PassivePlayGrace }
			self:event("PassiveWarning", { Team = self.Possession })
			self:markState()
		end
	elseif t > warning.Deadline then
		local ball = self.Ball
		local offender = if ball.State == "Held" then ball.Holder else nil
		local position = self:toLocal(ball.Position)
		self:startRestart("FreeThrow", Rules.other(warning.Team), position, "PassivePlay", offender)
	end
end

function Match.restartTimeout(self: any, t: number)
	local restart = self.Restart
	if self.PlayState ~= "Restart" or not restart or t < restart.Deadline then
		return
	end
	local kind = if restart.Kind == "Penalty" then "GoalkeeperThrow" else restart.Kind
	if kind == "ThrowOff" then
		kind = "FreeThrow"
	end
	self:startRestart(kind, Rules.other(restart.Team), restart.Position, "Delay", restart.Thrower)
end

-- A ball resting inside a goal area with no goalkeeper to pick it up.
function Match.looseInArea(self: any, t: number, dt: number)
	local ball = self.Ball
	if self.PlayState ~= "Live" or ball.State ~= "Loose" or ball.Velocity.Magnitude > 4 then
		ball.LooseInAreaTime = 0
		return
	end
	local position = self:toLocal(ball.Position)
	for _, side in { 1, -1 } do
		if CourtGeometry.inGoalArea(self.Court, position, side) then
			ball.LooseInAreaTime += dt
			if ball.LooseInAreaTime > 2 then
				local defending = if self.AttackDirection.Red == side then "Blue" else "Red"
				self:startRestart("GoalkeeperThrow", defending, position, "GoalkeeperThrow", nil)
			end
			return
		end
	end
	ball.LooseInAreaTime = 0
end

-- Actions ---------------------------------------------------------------------------------------------------------

function Match.pickPassTarget(self: any, p: Participant, targetId: unknown, direction: unknown): Participant?
	local root = p.Root
	if not root then
		return nil
	end
	local function valid(other: Participant?): boolean
		if not other or other == p or other.Team ~= p.Team or not self:isActive(other) or not other.Root then
			return false
		end
		return (other.Root.Position - root.Position).Magnitude <= Config.Ball.PassMaxDistance
	end
	local id = Guard.string(targetId, 16)
	if id then
		local chosen = self.ById[id]
		if valid(chosen) then
			return chosen
		end
	end
	local aim = Guard.direction(direction) or root.CFrame.LookVector
	aim = flat(aim)
	if aim.Magnitude < 0.01 then
		aim = flat(root.CFrame.LookVector)
	end
	aim = aim.Unit
	local best: Participant? = nil
	local bestScore = -math.huge
	for _, other in self.Participants do
		if valid(other) and other.Root then
			local offset = flat(other.Root.Position - root.Position)
			local score = if offset.Magnitude > 0.1 then offset.Unit:Dot(aim) else -1
			if score > bestScore then
				bestScore = score
				best = other
			end
		end
	end
	return best
end

function Match.actPass(self: any, p: Participant, payload: { [string]: unknown }, t: number)
	local ball = self.Ball
	if ball.State ~= "Held" or ball.Holder ~= p or not p.Root then
		return
	end
	local restart = self.Restart
	if restart and restart.Kind == "Penalty" then
		return -- a 7 m throw must be a shot
	end
	local kind = Guard.oneOf(payload.Kind, PASS_KINDS) or "Quick"
	local origin = self:handPoint(p)
	local target: Participant? = nil
	if kind ~= "Aimed" then
		target = self:pickPassTarget(p, payload.TargetId, payload.Direction)
		if not target then
			kind = "Aimed"
		end
	end
	local velocity: Vector3
	local throw: string
	if kind == "Aimed" or not target or not target.Root then
		local direction = Guard.direction(payload.Direction) or p.Root.CFrame.LookVector
		direction = clampVertical(direction, -0.3, 0.5)
		velocity = direction * Config.Ball.AimedPassSpeed + Vector3.new(0, 5, 0)
		throw = "AimedPass"
		target = nil
	else
		local targetRoot = target.Root :: BasePart
		local destination = targetRoot.Position + Vector3.new(0, 0.5, 0)
		local distance = (destination - origin).Magnitude
		local lead = flat(targetRoot.AssemblyLinearVelocity)
		if lead.Magnitude > Config.Movement.SprintSpeed + 5 then
			lead = lead.Unit * (Config.Movement.SprintSpeed + 5)
		end
		if kind == "High" then
			local flightTime = math.clamp(distance / 45, 0.4, 1.6)
			velocity = BallPhysics.lobVelocity(origin, destination + lead * flightTime, Config.Ball.HighPassApex)
			throw = "HighPass"
		else
			local long = distance > Config.Ball.LongPassDistance
			local speed = if long then Config.Ball.LongPassSpeed else Config.Ball.QuickPassSpeed
			velocity = BallPhysics.directVelocity(origin, destination + lead * (distance / speed) * 0.85, speed)
			throw = if long then "LongPass" else "QuickPass"
		end
	end
	self:releaseBall(p, throw, velocity, origin, target, nil)
	self:event("Pass", { Id = p.Id, Kind = throw, TargetId = if target then target.Id else nil })
end

function Match.actShotCharge(self: any, p: Participant, t: number)
	local ball = self.Ball
	if ball.State ~= "Held" or ball.Holder ~= p or p.ChargeStart then
		return
	end
	if ball.Dribbling then
		-- Charging gathers the ball (the dribble is over).
		ball.Dribbling = false
		ball.HasDribbled = true
		ball.HoldStart = t
		ball.StepDistance = 0
		ball.Steps = 0
		self:markBall()
	end
	p.ChargeStart = t
end

-- Expected crossing point of a shot on the goal plane, for the keeper hint.
function Match.predictShot(self: any, origin: Vector3, velocity: Vector3, side: number): (Vector3?, number?)
	local position, current = origin, velocity
	local elapsed = 0
	local step = 1 / 60
	local goalX = side * self.Court.HalfLength
	while elapsed < 2 do
		local nextPosition, nextVelocity = BallPhysics.step(position, current, step, self.FloorY)
		local a = self:toLocal(position)
		local b = self:toLocal(nextPosition)
		if (a.X - goalX) * side < 0 and (b.X - goalX) * side >= 0 then
			return nextPosition, elapsed + step
		end
		position, current = nextPosition, nextVelocity
		elapsed += step
	end
	return nil, nil
end

function Match.actShotRelease(self: any, p: Participant, payload: { [string]: unknown }, t: number)
	local ball = self.Ball
	if ball.State ~= "Held" or ball.Holder ~= p or not p.Root then
		return
	end
	local root = p.Root :: BasePart
	local direction = Guard.direction(payload.Direction) or root.CFrame.LookVector
	direction = clampVertical(direction, -0.45, 0.55)
	local held = if p.ChargeStart then t - p.ChargeStart else 0
	local quick = held < Config.Ball.ShotMinChargeHold
	local charge = 0
	local speed: number
	local spread: number
	if quick then
		speed = Config.Ball.QuickShotSpeed
		spread = Config.Ball.ShotSpread
	else
		charge = math.clamp(
			(held - Config.Ball.ShotMinChargeHold) / (Config.Ball.ShotChargeTime - Config.Ball.ShotMinChargeHold),
			0,
			1
		)
		speed = Config.Ball.ChargedShotMinSpeed
			+ (Config.Ball.ChargedShotMaxSpeed - Config.Ball.ChargedShotMinSpeed) * charge
		spread = Config.Ball.ShotSpread * (1 - charge) * 0.6
	end
	if spread > 0 then
		local yaw = self.Random:NextNumber(-spread, spread)
		local pitch = self.Random:NextNumber(-spread, spread) * 0.6
		local right = direction:Cross(Vector3.yAxis)
		if right.Magnitude > 0.01 then
			direction = (CFrame.fromAxisAngle(Vector3.yAxis, yaw) * CFrame.fromAxisAngle(right.Unit, pitch)):VectorToWorldSpace(
				direction
			)
		end
	end
	local jump = not self:onGround(p)
	local origin = self:releasePoint(p)
	-- Gravity compensation: the ball should arrive where the player aimed, so the
	-- drop over the distance to the attacked goal plane is added back upwards.
	local side = self:attackSide(p.Team)
	local localOrigin = CourtGeometry.toLocal(self.Court, origin)
	local localDirection = self.Court.CFrame:VectorToObjectSpace(direction.Unit)
	local travel = 30
	if localDirection.X * side > 0.05 then
		local goalX = side * self.Court.HalfLength
		travel = math.clamp((goalX - localOrigin.X) / localDirection.X, 4, 90)
	end
	local flightTime = travel / speed
	local velocity = direction.Unit * speed + Vector3.new(0, 0.5 * Config.Ball.Gravity * flightTime, 0)
	self:releaseBall(p, if quick then "QuickShot" else "ChargedShot", velocity, origin, nil, charge)
	p.Shots += 1
	self.PossessionStart = t
	self.PassiveWarning = nil
	self:markState()
	self:event("Shot", { Id = p.Id, Kind = if quick then "Quick" else "Charged", Charge = charge, Jump = jump })

	-- Incoming-shot indicator for the goalkeeper of the targeted goal.
	local keeper = self:keeperOf(Rules.other(p.Team))
	if keeper then
		local point, eta = self:predictShot(origin, velocity, side)
		if point and eta then
			local data = { KeeperId = keeper.Id, Point = point, ArrivalTime = t + eta }
			self:eventTo(keeper, "ShotIncoming", data)
			if keeper.Brain then
				keeper.Brain.Incoming = { Point = point, ArrivalTime = t + eta, SeenAt = t }
			end
		end
	end
end

function Match.actDribble(self: any, p: Participant, t: number)
	local ball = self.Ball
	if ball.State ~= "Held" or ball.Holder ~= p or self.PlayState ~= "Live" or not p.Root then
		return
	end
	if ball.Dribbling then
		ball.Dribbling = false
		ball.HasDribbled = true
		ball.HoldStart = t
		ball.StepDistance = 0
		ball.Steps = 0
		ball.LastHolderPosition = p.Root.Position
	elseif ball.HasDribbled then
		self:violation("DoubleDribble", p, self:localOf(p))
		return
	else
		ball.Dribbling = true
		ball.StepDistance = 0
		ball.Steps = 0
		p.ChargeStart = nil
	end
	self:markBall()
end

function Match.actDash(self: any, p: Participant, payload: { [string]: unknown }, t: number)
	if p.Frozen or t < p.DashReadyAt or not p.Root then
		return
	end
	local direction = Guard.direction(payload.Direction) or p.Root.CFrame.LookVector
	direction = flat(direction)
	if direction.Magnitude < 0.01 then
		return
	end
	direction = direction.Unit
	local m = Config.Movement
	p.DashReadyAt = t + m.DashCooldown
	p.DashUntil = t + m.DashDuration
	p.RecoveryUntil = p.DashUntil + m.DashRecovery
	p.ChargeStart = nil
	if p.Player then
		AntiExploitService.allowBurst(p.Player, m.DashDuration + 0.3, m.DashSpeed)
	end
	if p.Brain then
		p.Brain.DashDirection = direction
	end
	self:event("Dash", { Id = p.Id, Direction = direction })
	self:markState()
end

function Match.actIntercept(self: any, p: Participant, t: number)
	if self.Ball.Holder == p or t < p.InterceptReadyAt then
		return
	end
	local d = Config.Defense
	p.InterceptUntil = t + d.InterceptWindow
	p.InterceptReadyAt = t + d.InterceptCooldown
	p.InterceptHit = false
	p.MissRecoveryUntil = p.InterceptUntil + d.InterceptMissRecovery
end

function Match.actBlock(self: any, p: Participant, t: number)
	if self.Ball.Holder == p or t < p.BlockReadyAt then
		return
	end
	p.BlockUntil = t + Config.Defense.BlockDuration
	p.BlockReadyAt = t + Config.Defense.BlockCooldown
end

function Match.actContact(self: any, p: Participant, payload: { [string]: unknown }, t: number)
	local root = p.Root
	if not root or t < p.ContactReadyAt or self.Ball.Holder == p then
		return
	end
	local d = Config.Defense
	local look = flat(root.CFrame.LookVector)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local function eligible(other: Participant?): boolean
		if not other or other.Team == p.Team or not self:isActive(other, t) or not other.Root then
			return false
		end
		if t < other.ContactImmuneUntil then
			return false
		end
		local offset = flat(other.Root.Position - root.Position)
		if offset.Magnitude > d.ContactRange then
			return false
		end
		return offset.Magnitude < 1 or offset.Unit:Dot(look) > math.cos(math.rad(70))
	end
	local target: Participant? = nil
	local id = Guard.string(payload.TargetId, 16)
	if id and eligible(self.ById[id]) then
		target = self.ById[id]
	else
		local bestDistance = math.huge
		for _, other in self.Participants do
			if eligible(other) and other.Root then
				local distance = (other.Root.Position - root.Position).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					target = other
				end
			end
		end
	end
	if not target or not target.Root then
		return
	end
	local victim = target
	local victimRoot = target.Root :: BasePart
	p.ContactReadyAt = t + d.ContactCooldown
	p.RecoveryUntil = t + 0.25
	victim.ContactImmuneUntil = t + d.ContactImmunity

	local ball = self.Ball
	local hasBall = ball.State == "Held" and ball.Holder == victim
	local behind = Rules.isFromBehind(victimRoot.Position, victimRoot.CFrame.LookVector, root.Position)
	local legal = hasBall and not behind
	victim.StunnedUntil = t + d.ContactStun * (if legal then 1 else 0.6)
	victim.ChargeStart = nil

	if legal then
		local chance = d.ContactStealBase
		if ball.Dribbling then
			chance += 0.2
		end
		if victim.ChargeStart then
			chance += 0.15
		end
		local stole = self.Random:NextNumber() < chance
		self:event("Contact", { FromId = p.Id, ToId = victim.Id, Legal = true, Stole = stole })
		if stole then
			local away = flat(root.Position - victimRoot.Position)
			away = if away.Magnitude > 0.01 then away.Unit else look
			self:looseBall(self:handPoint(victim), away * 12 + Vector3.new(0, 8, 0), victim)
		end
		return
	end

	-- Illegal contact: foul.
	p.Fouls += 1
	self:event("Contact", { FromId = p.Id, ToId = victim.Id, Legal = false, Stole = false })
	local victimPosition = self:localOf(victim)
	local reason = if behind then "ContactFromBehind" else "IllegalContact"
	local defenders = {}
	for _, other in self.Participants do
		if other ~= p and other.Team == p.Team and other.Role ~= "Goalkeeper" and self:isActive(other, t) then
			table.insert(defenders, self:localOf(other))
		end
	end
	if hasBall and Rules.isClearChance(self.Court, victimPosition, self:attackSide(victim.Team), defenders) then
		self:startRestart("Penalty", victim.Team, victimPosition, "Penalty", p)
	else
		self:startRestart("FreeThrow", victim.Team, victimPosition, reason, p)
	end
	self:applySanction(p)
end

function Match.actDive(self: any, p: Participant, payload: { [string]: unknown }, t: number)
	local root = p.Root
	if p.Role ~= "Goalkeeper" or not root or self.Ball.Holder == p or t < p.DiveReadyAt or p.Frozen then
		return
	end
	local target = Guard.vector(payload.Target, 1e6)
	if not target then
		return
	end
	local k = Config.Keeper
	local from = root.Position
	local offset = flat(target - from)
	if offset.Magnitude > k.DiveDistance then
		offset = offset.Unit * k.DiveDistance
	end
	local height = math.clamp(target.Y - self.FloorY, 0.6, Config.Goal.Height - 0.3)
	p.DiveStart = t
	p.DiveUntil = t + k.DiveDuration
	p.DiveRecoveryUntil = p.DiveUntil + k.DiveRecovery
	p.DiveReadyAt = math.max(t + k.DiveCooldown, p.DiveRecoveryUntil)
	p.RecoveryUntil = p.DiveRecoveryUntil
	p.DiveFrom = Vector3.new(from.X, self.FloorY + 3, from.Z)
	p.DiveEnd = Vector3.new(from.X + offset.X, self.FloorY + height, from.Z + offset.Z)
	if p.Player then
		AntiExploitService.allowBurst(p.Player, k.DiveDuration + k.DiveRecovery, k.DiveDistance / k.DiveDuration + 6)
	end
	self:event("Dive", { Id = p.Id, Target = p.DiveEnd })
end

-- Entry point for every action, from players (validated remote) and bots.
function Match.act(self: any, p: Participant, name: string, payload: { [string]: unknown })
	local t = now()
	if not self:inPlay() or not self:isActive(p, t) then
		return
	end
	local restart = self.Restart
	if self.PlayState == "Restart" and restart then
		-- During a set piece only the thrower may play the ball; the others may move.
		local throwing = name == "Pass" or name == "ShotCharge" or name == "ShotRelease" or name == "ShotCancel"
		if p == restart.Thrower and not throwing then
			return
		end
		if p ~= restart.Thrower and throwing then
			return
		end
		if name == "Contact" then
			return
		end
	end
	if name == "Sprint" then
		p.Sprinting = Guard.boolean(payload.On) == true
		return
	elseif name == "Stance" then
		p.Stance = Guard.boolean(payload.On) == true
		return
	elseif name == "ShotCancel" then
		p.ChargeStart = nil
		return
	end
	if t < p.StunnedUntil or t < p.RecoveryUntil then
		return
	end
	if name == "Pass" then
		self:actPass(p, payload, t)
	elseif name == "ShotCharge" then
		self:actShotCharge(p, t)
	elseif name == "ShotRelease" then
		self:actShotRelease(p, payload, t)
	elseif name == "Dribble" then
		self:actDribble(p, t)
	elseif name == "Dash" then
		self:actDash(p, payload, t)
	elseif name == "Intercept" then
		self:actIntercept(p, t)
	elseif name == "Block" then
		self:actBlock(p, t)
	elseif name == "Contact" then
		self:actContact(p, payload, t)
	elseif name == "Dive" then
		self:actDive(p, payload, t)
	end
end

function Match.onAction(self: any, player: Player, name: unknown, payload: unknown)
	local participant = self.ByPlayer[player]
	local action = Guard.string(name, 16)
	if not participant or not action then
		return
	end
	self:act(participant, action, Guard.payload(payload))
end

-- Role selection ---------------------------------------------------------------------------------------------------

function Match.selectRole(self: any, player: Player, role: unknown): (boolean, string?)
	local participant = self.ByPlayer[player]
	if not participant then
		return false, "Tu ne joues pas ce match."
	end
	if self.Phase ~= "Selection" then
		return false, "La sélection est terminée."
	end
	local chosen = Guard.oneOf(role, ROLES)
	if not chosen then
		return false, "Poste inconnu."
	end
	if chosen == "Goalkeeper" then
		for _, other in self.Participants do
			if
				other ~= participant
				and other.Team == participant.Team
				and other.Role == "Goalkeeper"
				and other.RoleChosen
			then
				return false, "Ton équipe a déjà un gardien."
			end
		end
	end
	participant.Role = chosen
	participant.RoleChosen = true
	self:markState()
	return true, nil
end

function Match.autoAssignRoles(self: any)
	for _, team in TEAMS do
		local members = self:teamOf(team)
		local keeper: Participant? = nil
		for _, p in members do
			if p.Role == "Goalkeeper" and p.RoleChosen then
				keeper = p
			end
		end
		if not keeper then
			-- A bot takes the goal if there is one; humans are never forced.
			for _, p in members do
				if p.IsBot then
					keeper = p
					break
				end
			end
		end
		for _, p in members do
			p.Role = if p == keeper then "Goalkeeper" else "Field"
			p.RoleChosen = true
		end
		if not keeper then
			for _, p in members do
				if p.Player then
					Remote.notify(
						p.Player,
						"Ton équipe joue sans gardien : le but est grand ouvert, reste groupés en défense.",
						"Warning"
					)
				end
			end
		end
	end
	for _, p in self.Participants do
		if p.Model then
			Appearance.apply(p.Model, p.Team, p.Role, p.Number)
		end
	end
	self:markState()
end

-- Connections ----------------------------------------------------------------------------------------------------------

function Match.onPlayerRemoving(self: any, player: Player)
	local p = self.ByPlayer[player]
	if not p then
		return
	end
	p.Connected = false
	AntiExploitService.untrack(player)
	if self.Ball.Holder == p then
		self:looseBall(self.Ball.Position, Vector3.zero, p)
	end
	if self.Restart and self.Restart.Thrower == p and self:inPlay() then
		local restart = self.Restart
		self:startRestart(restart.Kind, restart.Team, restart.Position, nil, nil)
	end
	self:event("Left", { Id = p.Id, Name = p.Name })
	self:markState()
	if #self:humans() == 0 then
		self.Ended = true
	end
end

function Match.watchCharacter(self: any, p: Participant)
	local player = p.Player
	if not player then
		return
	end
	local function attach(character: Model)
		task.spawn(function()
			local humanoid = character:WaitForChild("Humanoid", 10)
			local root = character:WaitForChild("HumanoidRootPart", 10)
			if not humanoid or not root or self.Ended or self.Phase == "Results" then
				return
			end
			self:bind(p, character)
			local side = self:defendSide(p.Team)
			if p.Role == "Goalkeeper" then
				self:teleport(p, Vector3.new(side * (self.Court.HalfLength - 2.5), 0, 0))
			else
				self:teleport(p, Vector3.new(side * self.Court.HalfLength * 0.3, 0, 0))
			end
		end)
	end
	table.insert(self.Connections, player.CharacterAdded:Connect(attach))
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if humanoid and root then
			self:bind(p, character)
		else
			attach(character)
		end
	end
end

-- Main loop --------------------------------------------------------------------------------------------------------------

function Match.runScheduled(self: any, t: number)
	if #self.Scheduled == 0 then
		return
	end
	local due = {}
	for index = #self.Scheduled, 1, -1 do
		local entry = self.Scheduled[index]
		if t >= entry.At then
			table.insert(due, entry.Fn)
			table.remove(self.Scheduled, index)
		end
	end
	for _, fn in due do
		fn()
	end
end

function Match.update(self: any, dt: number)
	local t = now()
	self:runScheduled(t)
	if self.Phase == "Playing" or self.Phase == "Overtime" then
		if self.PlayState ~= "Goal" and self.ClockRunning then
			self.Clock = math.max(0, self.Clock - dt)
		end
		if self.PlayState ~= "Goal" then
			self:stepBall(dt, t)
			if self.Ball.State == "Held" then
				self:holderRules(t, dt)
			end
			self:areaRules(t, dt)
			self:passivePlay(t)
			self:restartTimeout(t)
			self:looseInArea(t, dt)
		end
		self:suspensions(t)
	end
	Bots.update(self, dt, t)
	self:applyBodies(t)
	self:broadcast(t)
end

function Match.setPhase(self: any, phase: string, duration: number?)
	self.Phase = phase
	self.PhaseEndsAt = if duration then now() + duration else nil
	self:markState()
end

function Match.waitUntil(self: any, deadline: number, condition: (() -> boolean)?)
	while not self.Ended and now() < deadline do
		if condition and condition() then
			return
		end
		task.wait(0.1)
	end
end

function Match.freezeAll(self: any, frozen: boolean)
	for _, p in self.Participants do
		p.Frozen = frozen
	end
end

-- Plays one period; returns when the clock is over (or a golden goal).
function Match.playPeriod(self: any, phase: string, half: number, duration: number, throwOffTeam: string)
	self.Half = half
	self.Clock = duration
	self.ClockRunning = false
	self.GoldenGoal = false
	self:setPhase("Countdown", Config.Match.CountdownTime)
	self:startRestart("ThrowOff", throwOffTeam, Vector3.zero, nil, nil)
	self:freezeAll(true)
	self:event("Countdown", { EndsAt = self.PhaseEndsAt })
	self:waitUntil(self.PhaseEndsAt)
	if self.Ended then
		return
	end
	self:setPhase(phase)
	self.ClockRunning = true
	local restart = self.Restart
	if restart then
		restart.Deadline = now() + Config.Match.RestartThrowTimeout
	end
	-- Always unfreeze, even if no restart could be set up.
	for _, p in self.Participants do
		p.Frozen = restart ~= nil and p == restart.Thrower
	end
	while not self.Ended do
		if phase == "Overtime" and self.GoldenGoal then
			break
		end
		if self.Clock <= 0 and self.PlayState ~= "Goal" then
			local ball = self.Ball
			local shotInFlight = ball.State == "Flight"
				and ball.Throw ~= nil
				and SHOT_THROWS[ball.Throw] == true
				and now() - ball.ReleaseTime < 2.5
			if not shotInFlight then
				break
			end
		end
		task.wait(0.05)
	end
	-- Final whistle of the period.
	self.ClockRunning = false
	self.Restart = nil
	self.PlayState = "Live"
	self.PassiveWarning = nil
	self.Ball.State = "Dead"
	self.Ball.Holder = nil
	self:freezeAll(true)
	self:markBall()
	self:markState()
end

function Match.buildResults(self: any): Types.ResultsSnapshot
	local winner: string? = nil
	if self.Score.Red > self.Score.Blue then
		winner = "Red"
	elseif self.Score.Blue > self.Score.Red then
		winner = "Blue"
	end
	local best: Participant? = nil
	local bestScore = -math.huge
	local players = {}
	for _, p in self.Participants do
		table.insert(players, self:participantSnapshot(p))
		local score = p.Goals * 3 + p.Assists * 2 + p.Saves * 2 + p.Interceptions * 1.5 + p.Blocks - p.Fouls
		if winner and p.Team == winner then
			score += 1
		end
		if score > bestScore then
			bestScore = score
			best = p
		end
	end
	return {
		Winner = winner,
		Score = { Red = self.Score.Red, Blue = self.Score.Blue },
		Players = players,
		Mvp = if best then best.Id else nil,
	}
end

-- Runs the whole match (yields). Returns the results, or nil if aborted.
function Match.run(self: any): Types.ResultsSnapshot?
	local folder = Instance.new("Folder")
	folder.Name = `HL_Match_{string.sub(self.Id, 1, 8)}`
	folder.Parent = Workspace
	self.Folder = folder

	table.insert(
		self.Connections,
		RunService.Heartbeat:Connect(function(dt)
			local ok, err = pcall(self.update, self, dt)
			if not ok then
				warn(`[Match] {err}`)
			end
		end)
	)
	table.insert(
		self.Connections,
		Players.PlayerRemoving:Connect(function(player)
			self:onPlayerRemoving(player)
		end)
	)

	-- Waiting: build the court.
	self:setPhase("Waiting")
	local built = self.MapService.buildCourt(self.Config.Mode, self.Config.Origin)
	self.Map = built
	self.CourtCFrame = built.CourtCFrame
	self.FloorY = built.CourtCFrame.Position.Y
	self.Court = CourtGeometry.new(self.Config.Mode, built.CourtCFrame)
	self.Bench = built.BenchPositions or {}

	-- Team assignment: bodies, bots and positions.
	self:setPhase("TeamAssignment", Config.Match.TeamAssignmentTime)
	for _, p in self.Participants do
		if p.IsBot then
			Bots.spawn(self, p, folder)
		else
			self:watchCharacter(p)
			if p.Player then
				AntiExploitService.track(p.Player)
			end
		end
	end
	-- A team without any active body cannot play (e.g. bot bodies failed to load).
	for _, team in { "Red", "Blue" } do
		local active = false
		for _, p in self.Participants do
			if p.Team == team and p.Connected then
				active = true
			end
		end
		if not active then
			for _, player in self:humans() do
				Remote.notify(player, "Le match ne peut pas commencer : une équipe n'a aucun joueur.", "Danger")
			end
			self.Ended = true
		end
	end
	self:freezeAll(true)
	self:formation(nil)
	self:waitUntil(self.PhaseEndsAt)

	-- Selection of roles.
	self:setPhase("Selection", Config.Match.SelectionTime)
	self:waitUntil(self.PhaseEndsAt, function()
		for _, p in self.Participants do
			if not p.IsBot and p.Connected and not p.RoleChosen then
				return false
			end
		end
		return true
	end)
	self:autoAssignRoles()
	self:formation(nil)

	-- Two halves.
	local firstTeam = if self.Random:NextNumber() < 0.5 then "Red" else "Blue"
	local duration = self.ModeInfo.HalfDuration
	self:playPeriod("Playing", 1, duration, firstTeam)
	if not self.Ended then
		self:setPhase("Halftime", Config.Match.HalftimeTime)
		self:event("Halftime", {})
		self.AttackDirection = { Red = -self.AttackDirection.Red, Blue = -self.AttackDirection.Blue }
		self:formation(nil)
		self:waitUntil(self.PhaseEndsAt)
	end
	if not self.Ended then
		self:playPeriod("Playing", 2, duration, Rules.other(firstTeam))
	end
	if not self.Ended and self.Score.Red == self.Score.Blue then
		self:event("Overtime", {})
		local overtimeTeam = if self.Random:NextNumber() < 0.5 then "Red" else "Blue"
		self:playPeriod("Overtime", 3, Config.Match.OvertimeDuration, overtimeTeam)
	end

	local results = self:buildResults()
	self.Results = results
	self.Ball.State = "Hidden"
	self.Ball.Holder = nil
	self:markBall()
	if #self:humans() > 0 then
		self:setPhase("Results", Config.Match.ResultsTime)
		self:event("Results", results :: any)
		self:waitUntil(self.PhaseEndsAt)
	end
	return results
end

function Match.destroy(self: any, returnTo: CFrame?)
	self.Ended = true
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	table.clear(self.Scheduled)
	Bots.destroyAll(self)
	for _, p in self.Participants do
		local player = p.Player
		if player then
			AntiExploitService.untrack(player)
			if player.Parent == Players then
				Remote.fire(player, "BallState", nil)
				Remote.fire(player, "MatchState", nil)
				task.spawn(function()
					-- Reloading restores the player's own avatar at the waiting room spawn.
					local ok, err = pcall(player.LoadCharacter, player)
					if not ok then
						warn(`[Match] LoadCharacter failed: {err}`)
					elseif returnTo and player.Character then
						player.Character:PivotTo(returnTo)
					end
				end)
			end
		end
	end
	local map = self.Map
	if map and typeof(map.Destroy) == "function" then
		pcall(map.Destroy)
	end
	if self.Folder then
		self.Folder:Destroy()
	end
end

return Match
