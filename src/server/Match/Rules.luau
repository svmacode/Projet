--!strict
-- Referee vocabulary: reason codes, the French explanation shown to players,
-- and pure helpers used by the match to decide between a free throw and a
-- 7-metre throw. Keeping the texts here makes every whistle explainable.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)

local Rules = {}

-- Reason code → explanation. "%s" is replaced by the team that gets the ball.
Rules.Texts = {
	ThreeSeconds = "3 secondes : ballon gardé trop longtemps sans dribbler. Jet franc pour %s.",
	Steps = "Marcher : plus de 3 pas avec le ballon. Jet franc pour %s.",
	DoubleDribble = "Reprise de dribble : interdit de redribbler après avoir ramassé le ballon. Jet franc pour %s.",
	AttackerInArea = "Zone : un attaquant a pris appui dans la zone du gardien avec le ballon. Renvoi du gardien pour %s.",
	AttackerInAreaNoBall = "Zone : un attaquant est entré dans la zone pour en tirer avantage. Jet franc pour %s.",
	DefenderInArea = "Zone : un défenseur a défendu à l'intérieur de sa propre zone. Jet franc pour %s.",
	OwnArea = "Zone : un joueur de champ est entré dans sa propre zone avec le ballon. Jet franc pour %s.",
	KeeperLeftArea = "Le gardien est sorti de sa zone avec le ballon. Jet franc pour %s.",
	IllegalContact = "Faute : contact sur un joueur qui n'a pas le ballon. Jet franc pour %s.",
	ContactFromBehind = "Faute : contact par derrière. Jet franc pour %s.",
	Penalty = "Occasion de but manifeste empêchée irrégulièrement : jet de 7 mètres pour %s !",
	PassivePlay = "Jeu passif : pas de tir après l'avertissement de l'arbitre. Jet franc pour %s.",
	OutOfBounds = "Sortie de terrain : remise en jeu pour %s.",
	GoalkeeperThrow = "Ballon sorti derrière le but : renvoi du gardien pour %s.",
	Corner = "Ballon sorti derrière le but après un défenseur : corner pour %s.",
	Delay = "Remise en jeu trop lente : ballon pour %s.",
}

Rules.TeamNames = {
	Red = "les Rouges",
	Blue = "les Bleus",
}

function Rules.text(reason: string, team: string): string
	local template = Rules.Texts[reason] or "Coup de sifflet : ballon pour %s."
	return (string.gsub(template, "%%s", Rules.TeamNames[team] or team))
end

function Rules.other(team: string): string
	return if team == "Red" then "Blue" else "Red"
end

export type Body = { Team: string, Position: Vector3 } -- local court space

-- Clear scoring opportunity: the attacker is close to the goal they attack,
-- not behind the goal line, and no defending field player stands in the
-- corridor between them and the goal (the goalkeeper does not count).
function Rules.isClearChance(
	court: CourtGeometry.Court,
	attackerLocal: Vector3,
	attackSide: number,
	defenders: { Vector3 }
): boolean
	if CourtGeometry.goalDistance(court, attackerLocal, attackSide) > Config.Rules.ClearChanceDistance then
		return false
	end
	local goal = CourtGeometry.goalCenter(court, attackSide)
	local toGoal = Vector3.new(goal.X - attackerLocal.X, 0, goal.Z - attackerLocal.Z)
	local length = toGoal.Magnitude
	if length < 0.1 then
		return true
	end
	local direction = toGoal / length
	for _, defender in defenders do
		local offset = Vector3.new(defender.X - attackerLocal.X, 0, defender.Z - attackerLocal.Z)
		local along = offset:Dot(direction)
		if along > 0 and along < length then
			local lateral = (offset - direction * along).Magnitude
			if lateral < 3.5 then
				return false
			end
		end
	end
	return true
end

-- True when `attacker` is behind `victim` (contact from behind).
-- `victimLook` is the victim's horizontal facing direction.
function Rules.isFromBehind(victimPosition: Vector3, victimLook: Vector3, attackerPosition: Vector3): boolean
	local toAttacker = Vector3.new(attackerPosition.X - victimPosition.X, 0, attackerPosition.Z - victimPosition.Z)
	local look = Vector3.new(victimLook.X, 0, victimLook.Z)
	if toAttacker.Magnitude < 0.01 or look.Magnitude < 0.01 then
		return false
	end
	local cosine = toAttacker.Unit:Dot(look.Unit)
	-- Behind = inside the cone of ContactBehindAngle degrees around the victim's back.
	return cosine < -math.cos(math.rad(Config.Defense.ContactBehindAngle))
end

return Rules
