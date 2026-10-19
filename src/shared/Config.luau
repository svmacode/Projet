--!strict
-- Handball Legends: every gameplay tuning value lives here.
-- The client can read this module; the server never trusts the client and
-- re-validates everything with these same numbers.
--
-- Units: studs and seconds. 1 metre ≈ 2.8 studs (an R6 character is ~5 studs tall).
-- All numbers are STARTING values meant to be tuned through real playtests.

local Config = {}

Config.Version = "0.1.0-phase1"

-- Match sizes -----------------------------------------------------------------------------

export type ModeId = string -- "2v2" | "3v3" | "4v4" | "5v5"

export type Mode = {
	Id: ModeId,
	Label: string,
	TeamSize: number,
	HalfDuration: number, -- seconds per half
	RankedAllowed: boolean,
	-- Court geometry (studs). Length runs along X (goal to goal), width along Z.
	CourtLength: number,
	CourtWidth: number,
	GoalAreaRadius: number, -- the "6 m" area
	FreeThrowRadius: number, -- the dashed "9 m" line
	PenaltyDistance: number, -- the "7 m" mark, measured from the goal line
}

Config.Modes = {
	["2v2"] = {
		Id = "2v2",
		Label = "2 VS 2",
		TeamSize = 2,
		HalfDuration = 120,
		RankedAllowed = false,
		CourtLength = 72,
		CourtWidth = 42,
		GoalAreaRadius = 12,
		FreeThrowRadius = 18,
		PenaltyDistance = 15,
	},
	["3v3"] = {
		Id = "3v3",
		Label = "3 VS 3",
		TeamSize = 3,
		HalfDuration = 120,
		RankedAllowed = true,
		CourtLength = 88,
		CourtWidth = 50,
		GoalAreaRadius = 14,
		FreeThrowRadius = 21,
		PenaltyDistance = 17,
	},
	["4v4"] = {
		Id = "4v4",
		Label = "4 VS 4",
		TeamSize = 4,
		HalfDuration = 180,
		RankedAllowed = true,
		CourtLength = 104,
		CourtWidth = 58,
		GoalAreaRadius = 15,
		FreeThrowRadius = 23,
		PenaltyDistance = 18,
	},
	["5v5"] = {
		Id = "5v5",
		Label = "5 VS 5",
		TeamSize = 5,
		HalfDuration = 180,
		RankedAllowed = true,
		CourtLength = 120,
		CourtWidth = 64,
		GoalAreaRadius = 16.8,
		FreeThrowRadius = 25.2,
		PenaltyDistance = 19.6,
	},
} :: { [string]: Mode }

Config.ModeOrder = { "2v2", "3v3", "4v4", "5v5" } :: { ModeId }

-- Goals (bigger than the real 3 m × 2 m so that shooting reads well on screen).
Config.Goal = {
	Width = 12,
	Height = 7,
	Depth = 4,
}

-- Match flow ----------------------------------------------------------------------------------

Config.Match = {
	TeamAssignmentTime = 2,
	SelectionTime = 20,
	CountdownTime = 3,
	HalftimeTime = 10,
	OvertimeDuration = 60, -- golden goal; draw if still level afterwards
	ResultsTime = 12,
	GoalCelebrationTime = 3.5,
	RestartSetupTime = 1.5, -- players reposition before a restart throw
	RestartThrowTimeout = 5, -- the thrower must release within this window
	StateBroadcastRate = 4, -- full MatchState snapshots per second (plus on change)
}

-- Movement ------------------------------------------------------------------------------------

Config.Movement = {
	RunSpeed = 18,
	SprintSpeed = 24,
	KeeperSpeed = 18,
	CarrierSpeed = 22, -- max speed while holding the ball (sprinting with it)
	DribbleSpeed = 21,
	StanceSpeed = 11, -- defensive stance (shuffle)
	ChargingSpeed = 9, -- while charging a shot
	JumpPower = 52,
	DashSpeed = 70,
	DashDuration = 0.18,
	DashCooldown = 2.5,
	DashRecovery = 0.2, -- no new action right after a dash
	-- Anti-exploit tolerance on top of the theoretical max speed.
	SpeedTolerance = 10,
	SpeedStrikesBeforeCorrection = 2,
}

-- Ball ------------------------------------------------------------------------------------------

Config.Ball = {
	Radius = 0.8,
	Gravity = 150,
	FloorRestitution = 0.55,
	WallRestitution = 0.55,
	RollingFriction = 1.4, -- fraction of horizontal speed lost per second on the floor
	HoldOffset = Vector3.new(1.2, 0.6, -0.8), -- right hand, relative to the root part

	QuickPassSpeed = 85,
	LongPassSpeed = 105, -- used automatically beyond LongPassDistance
	LongPassDistance = 40,
	HighPassApex = 12, -- extra height of a lob above the straight line
	AimedPassSpeed = 80,
	PassMaxDistance = 80,

	QuickShotSpeed = 95,
	ChargedShotMinSpeed = 105,
	ChargedShotMaxSpeed = 150,
	ShotChargeTime = 0.9, -- seconds to reach full power
	ShotMinChargeHold = 0.18, -- a tap shorter than this is a quick shot
	ShotSpread = 0.035, -- radians of random error on a quick shot (none on full charge)

	CatchRadius = 3.2, -- intended receiver of a pass
	PickupRadius = 3, -- loose (slow) ball
	LooseBallSpeed = 30, -- below this speed a free ball can simply be picked up
	ReleaseImmunity = 0.3, -- the thrower cannot touch their own throw right away

	-- Fixed simulation step, shared by server and client prediction.
	SimStep = 1 / 120,
}

-- Rules (traditional handball foundation) ---------------------------------------------------------

Config.Rules = {
	MaxHoldTime = 3, -- seconds holding the ball without dribbling
	HoldWarningTime = 1.8, -- the HUD starts warning here
	StepLength = 4.5, -- studs of ground travel counted as one step
	MaxSteps = 3,
	StepGrace = 0.5, -- extra fraction of a step before calling the violation (network jitter)
	DribbleBounceInterval = 0.45,

	PassivePlayTime = 35, -- seconds of one possession before the referee warns
	PassivePlayGrace = 10, -- seconds after the warning to shoot

	SetPieceDistance = 8, -- opponents must stay this far from a restart throw ("3 m")

	-- Clear scoring opportunity (for 7 m throws): carrier within this distance of
	-- the opposing goal, moving or facing towards it, no defender in between.
	ClearChanceDistance = 30,

	-- Progressive punishment for persistent illegal contact.
	FoulsBeforeWarning = 2,
	FoulsBeforeSuspension = 3, -- each further foul after the warning
	SuspensionTime = 20, -- "2 minutes", scaled to the match length
}

-- Defensive actions ------------------------------------------------------------------------------------

Config.Defense = {
	InterceptWindow = 0.35, -- seconds the interception hitbox is active
	InterceptReach = 3.4,
	InterceptCooldown = 1.6,
	InterceptMissRecovery = 0.45, -- slowed after a whiffed interception

	BlockDuration = 0.6,
	BlockReach = 2.6, -- horizontal radius of raised arms
	BlockHeight = 8.5, -- top of the arms above the floor
	BlockCooldown = 1.4,

	ContactRange = 5.5,
	ContactCooldown = 2.5,
	ContactStun = 0.6, -- the victim of a contact staggers
	ContactBehindAngle = 75, -- degrees from the victim's back counted as "from behind"
	ContactStealBase = 0.45, -- chance a legal frontal contact knocks the ball loose
	ContactImmunity = 1.5, -- the same player cannot be contacted again right away
}

-- Goalkeeper ---------------------------------------------------------------------------------------------

Config.Keeper = {
	DiveDistance = 7, -- lateral reach of a dive
	DiveDuration = 0.45,
	DiveRecovery = 0.55,
	DiveCooldown = 1.1,
	SaveReachStanding = 2.4, -- radius around the hands while standing
	SaveReachDive = 3, -- radius around the hands during a dive
	CatchMaxSpeed = 110, -- slower shots are caught, faster ones are parried
	ParrySpeed = 35,
	ShotWarningTime = 0.6, -- incoming-shot indicator lead time
}

-- Network / security -------------------------------------------------------------------------------------

Config.Net = {
	BallBroadcastRate = 15, -- BallState snapshots per second while the ball moves
	ActionRate = 12, -- Action remote: tokens per second
	ActionBurst = 20,
	MaxPingCompensation = 0.15,
}

return Config
