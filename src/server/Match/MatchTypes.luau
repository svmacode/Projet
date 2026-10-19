--!strict
-- Server-only internal state of a match. Never sent as-is to clients: the
-- snapshots in Shared/Types.luau are built from it.

export type Participant = {
	Id: string,
	Player: Player?,
	UserId: number?,
	Name: string,
	Team: string, -- "Red" | "Blue"
	Role: string, -- "Goalkeeper" | "Field"
	RoleChosen: boolean,
	IsBot: boolean,
	Model: Model?,
	Humanoid: Humanoid?,
	Root: BasePart?,
	Number: number,
	Connected: boolean,

	-- Statistics.
	Goals: number,
	Assists: number,
	Saves: number,
	Interceptions: number,
	Blocks: number,
	Fouls: number,
	Shots: number,
	Warned: boolean,
	SuspendedUntil: number,

	-- Input flags.
	Sprinting: boolean,
	Stance: boolean,
	ChargeStart: number?, -- server time the shot charge began

	-- Timers (server time).
	DashReadyAt: number,
	DashUntil: number,
	RecoveryUntil: number, -- no new action before this
	InterceptUntil: number,
	InterceptReadyAt: number,
	MissRecoveryUntil: number,
	InterceptHit: boolean,
	BlockUntil: number,
	BlockReadyAt: number,
	ContactReadyAt: number,
	ContactImmuneUntil: number,
	StunnedUntil: number,
	DiveStart: number,
	DiveUntil: number,
	DiveRecoveryUntil: number,
	DiveReadyAt: number,
	DiveFrom: Vector3,
	DiveEnd: Vector3,
	AreaTime: number, -- seconds spent illegally in a goal area (jitter filter)
	Frozen: boolean, -- set-piece freeze

	-- Last values written to the Humanoid / attributes (avoid replication spam).
	AppliedSpeed: number,
	AppliedJump: number,
	Attributes: { [string]: any },

	-- Bot brain state (nil for humans).
	Brain: any,
}

export type BallState = {
	State: string, -- "Held" | "Flight" | "Loose" | "Dead"
	Holder: Participant?,
	Position: Vector3,
	Velocity: Vector3,
	Throw: string?,
	Thrower: Participant?,
	Target: Participant?,
	ThrowTeam: string?,
	Charge: number?,
	ReleaseTime: number,
	LastToucher: Participant?,
	LastTouchTeam: string?,
	Dribbling: boolean,
	HasDribbled: boolean,
	KeeperAreaHold: boolean, -- the goalkeeper took the ball inside their own area
	HoldStart: number,
	Steps: number,
	StepDistance: number,
	LastHolderPosition: Vector3?,
	AssistId: string?,
	AssistTeam: string?,
	AssistTime: number,
	ShotSide: number?, -- goal side targeted by the current shot
	LooseInAreaTime: number,
}

export type Restart = {
	Kind: string,
	Team: string,
	Thrower: Participant,
	Position: Vector3, -- local court space
	Deadline: number,
}

export type MatchConfig = {
	Mode: string,
	Teams: { [string]: { Player } },
	FillWithBots: boolean,
	Origin: CFrame,
}

return {}
