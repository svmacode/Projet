--!strict
-- Data contracts shared by the server and the client.
-- Every snapshot and event that crosses the network is described here; if a
-- field changes, both sides change with it.

export type TeamId = string -- "Red" | "Blue"
export type Role = string -- "Goalkeeper" | "Field" (Phase 2 adds wings, backs, pivot…)

-- Waiting → TeamAssignment → Selection → Countdown → Playing → Halftime →
-- Playing → Overtime → Results
export type Phase = string

-- Sub-state while Phase is Playing or Overtime.
export type PlayState = string -- "Live" | "Restart" | "Goal"

export type RestartKind = string -- "ThrowOff" | "ThrowIn" | "GoalkeeperThrow" | "FreeThrow" | "Penalty"

export type Restart = {
	Kind: RestartKind,
	Team: TeamId, -- team that takes the throw
	ThrowerId: string,
	Position: Vector3, -- world position of the throw
	Deadline: number, -- server time (Workspace:GetServerTimeNow())
}

export type ParticipantSnapshot = {
	Id: string,
	UserId: number?, -- nil for development bots
	Name: string,
	Team: TeamId,
	Role: Role,
	IsBot: boolean,
	Model: Model?,
	Number: number,
	Connected: boolean,
	Goals: number,
	Assists: number,
	Saves: number,
	Interceptions: number,
	Blocks: number,
	Fouls: number,
	Warned: boolean, -- yellow card for persistent fouls
	SuspendedUntil: number, -- server time, 0 if not suspended
	DashReadyAt: number, -- server time
}

export type MatchSnapshot = {
	Id: string,
	Mode: string,
	Phase: Phase,
	PlayState: PlayState,
	Restart: Restart?,
	Half: number, -- 1, 2, 3 = overtime
	Clock: number, -- seconds left in the current period
	ClockRunning: boolean,
	PhaseEndsAt: number?, -- server time when the current timed phase ends (selection, countdown…)
	ServerTime: number,
	Score: { [TeamId]: number },
	-- Direction each team attacks along the court X axis (+1 or -1).
	AttackDirection: { [TeamId]: number },
	Possession: TeamId?,
	PassiveWarning: { Team: TeamId, Deadline: number }?,
	CourtCFrame: CFrame, -- centre of the court, floor level; X = length axis
	Participants: { ParticipantSnapshot },
}

export type BallStateKind = string -- "Held" | "Flight" | "Loose" | "Dead"
export type ThrowKind = string -- "QuickPass" | "LongPass" | "HighPass" | "AimedPass" | "QuickShot" | "ChargedShot" | "Parry" | "Free"

export type BallSnapshot = {
	State: BallStateKind,
	HolderId: string?,
	Position: Vector3,
	Velocity: Vector3,
	ServerTime: number,
	Throw: ThrowKind?,
	ThrowerId: string?,
	TargetId: string?, -- intended receiver of a pass
	Charge: number?, -- 0..1 for charged shots
	-- Holder rule timers, so the HUD can warn before a violation.
	Dribbling: boolean,
	HasDribbled: boolean, -- gathered after a dribble: dribbling again is illegal
	HoldStart: number, -- server time the current hold (without dribble) started
	Steps: number, -- steps taken during the current hold
}

-- Client → server actions (Action remote: name, payload).
export type PassKind = string -- "Quick" | "High" | "Aimed"

export type ResultsSnapshot = {
	Winner: TeamId?, -- nil = draw
	Score: { [TeamId]: number },
	Players: { ParticipantSnapshot },
	Mvp: string?,
}

return {}
