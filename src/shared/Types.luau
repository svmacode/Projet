--!strict
-- Types partagés entre serveur et client (données qui traversent le réseau).

export type Stats = {
	Matches: number,
	Wins: number,
	Losses: number,
	Draws: number,
	Goals: number,
	Assists: number,
	Saves: number,
	Interceptions: number,
	MVPs: number,
}

export type Profile = {
	Version: number,
	Coins: number,
	XP: number,
	Level: number,
	Balls: { [string]: number }, -- balles non ouvertes par type
	CosmeticPacks: number, -- packs cosmétiques non ouverts
	Archetypes: { [string]: boolean }, -- archétypes possédés
	SelectedArchetype: { [string]: string }, -- dernier archétype choisi par poste
	Cosmetics: { [string]: number }, -- cosmétiques possédés (quantité)
	Equipped: { [string]: string }, -- emplacement -> cosmétique
	Kit: string,
	Stats: Stats,
	RP: number,
	PeakRP: number,
	RankedMatches: number,
	FirstMatchRewarded: boolean,
	Pity: number,
	TutorialDone: boolean,
	ClanId: string?,
	ClanCredits: number,
	Receipts: { string },
	SeenPatch: string,
	Settings: { [string]: boolean },
}

export type PartyMember = {
	UserId: number,
	Name: string,
	Level: number,
}

export type PartySnapshot = {
	Id: string,
	LeaderId: number,
	Members: { PartyMember },
	Mode: string,
	Ranked: boolean,
}

export type QueueStatus = {
	State: "Idle" | "Searching" | "Found" | "Teleporting",
	Mode: string?,
	Ranked: boolean?,
	Training: boolean?,
	Since: number?,
	Message: string?,
}

export type ClanSnapshot = {
	Id: string,
	Name: string,
	Tag: string,
	OwnerId: number,
	Members: { { UserId: number, Name: string, Role: string } },
	Emblem: string,
	EmblemColor: Color3,
	BannerPattern: string,
	BannerColor: Color3,
	KitAccent: Color3,
	Wins: number,
	Created: number,
}

export type ParticipantSnapshot = {
	Id: string,
	Name: string,
	UserId: number,
	IsBot: boolean,
	Team: string,
	Poste: string?,
	Archetype: string?,
	Model: Model?,
	Number: number,
	Goals: number,
	Assists: number,
	Saves: number,
	YellowCard: boolean,
	SuspendedUntil: number,
	RedCard: boolean,
	Energy: number,
	Ultimate: number,
	Power1ReadyAt: number,
	Ready: boolean,
}

export type MatchSnapshot = {
	Id: string,
	Mode: string,
	Ranked: boolean,
	Training: boolean,
	Phase: string,
	Half: number,
	Clock: number, -- secondes restantes dans la période
	ClockRunning: boolean,
	ServerTime: number,
	Score: { [string]: number },
	AttackSide: { [string]: number }, -- but attaqué par chaque équipe (-1 / 1)
	Possession: string?,
	PassiveWarning: boolean,
	CourtCFrame: CFrame,
	Participants: { ParticipantSnapshot },
	Message: string?,
}

export type BallSnapshot = {
	State: "Held" | "Flight" | "Dead" | "Hidden",
	Holder: Model?,
	Position: Vector3,
	Velocity: Vector3,
	Accel: Vector3,
	ServerTime: number,
	Fire: boolean,
	Dribbling: boolean,
	Phantom: boolean,
}

return {}
