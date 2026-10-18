--!strict
-- Types internes du moteur de match (côté serveur uniquement).

export type Effect = {
	Kind: string, -- "Haste" | "Slow" | "Stun" | "Unstoppable" | "Intercept" | "Catch"
	Value: number,
	ExpiresAt: number,
}

export type ShotMods = {
	SpeedMult: number,
	Curve: number,
	Fire: boolean,
	Homing: boolean,
	StunKeeper: number,
	KeeperRadiusMult: number,
	ExpiresAt: number,
}

export type Participant = {
	Id: string,
	Player: Player?,
	IsBot: boolean,
	Name: string,
	UserId: number,
	Team: string, -- "Rouge" | "Bleu"
	Poste: string?,
	ArchetypeId: string?,
	Model: Model?,
	Humanoid: Humanoid?,
	Root: BasePart?,
	Number: number,
	KitId: string,
	Equipped: { [string]: string },
	ClanTag: string?,

	-- Statistiques du match
	Goals: number,
	Assists: number,
	Saves: number,
	Interceptions: number,
	Steals: number,
	ShotsOnTarget: number,

	-- Discipline
	Fouls: number,
	Yellow: boolean,
	Suspensions: number,
	SuspendedUntil: number,
	Red: boolean,

	-- Pouvoirs
	Energy: number,
	Ultimate: number,
	Power1ReadyAt: number,
	EnergyGainAt: { [string]: number },

	-- Actions de base
	NextDashAt: number,
	NextContactAt: number,
	NextInterceptAt: number,
	InterceptUntil: number,
	RamUntil: number,
	DiveUntil: number,
	ZoneTouchUntil: number,
	Effects: { Effect },
	ShotBuff: ShotMods?,
	LastSpeedApplied: number,
	LastJumpApplied: number,

	Ready: boolean,
	Connected: boolean,
	Bot: any,
}

return {}
