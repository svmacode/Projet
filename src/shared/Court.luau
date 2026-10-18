--!strict
-- Géométrie du terrain de handball, dans le repère local du terrain :
--   origine = centre du terrain, X = longueur (les buts sont en ±X),
--   Z = largeur, Y = hauteur (le sol est à Y = 0).
--
-- Proportions officielles (40 m × 20 m, zone de 6 m, ligne de 9 m, 7 m) mises
-- à l'échelle selon le mode de jeu : plus il y a de joueurs, plus le terrain
-- est grand. 1 m ≈ 2,6 studs sur le 5v5.

local Court = {}

export type Dimensions = {
	Length: number,
	Width: number,
	GoalWidth: number,
	GoalHeight: number,
	GoalDepth: number,
	GoalAreaRadius: number, -- zone (6 m)
	FreeThrowRadius: number, -- ligne de jet franc (9 m), en pointillés
	PenaltyDistance: number, -- point de jet de 7 m
	KeeperLineDistance: number, -- limite de sortie du gardien (4 m)
	SubstitutionHalfWidth: number,
}

local DIMENSIONS: { [string]: Dimensions } = {
	["2v2"] = {
		Length = 66,
		Width = 38,
		GoalWidth = 10,
		GoalHeight = 6.4,
		GoalDepth = 3.4,
		GoalAreaRadius = 12.5,
		FreeThrowRadius = 18.5,
		PenaltyDistance = 15,
		KeeperLineDistance = 8.5,
		SubstitutionHalfWidth = 6,
	},
	["3v3"] = {
		Length = 80,
		Width = 44,
		GoalWidth = 11,
		GoalHeight = 6.6,
		GoalDepth = 3.6,
		GoalAreaRadius = 14,
		FreeThrowRadius = 21,
		PenaltyDistance = 17,
		KeeperLineDistance = 9.5,
		SubstitutionHalfWidth = 7,
	},
	["4v4"] = {
		Length = 92,
		Width = 50,
		GoalWidth = 11.5,
		GoalHeight = 6.8,
		GoalDepth = 3.8,
		GoalAreaRadius = 15.5,
		FreeThrowRadius = 23.5,
		PenaltyDistance = 18.5,
		KeeperLineDistance = 10.5,
		SubstitutionHalfWidth = 8,
	},
	["5v5"] = {
		Length = 104,
		Width = 56,
		GoalWidth = 12,
		GoalHeight = 7,
		GoalDepth = 4,
		GoalAreaRadius = 17,
		FreeThrowRadius = 25.5,
		PenaltyDistance = 20,
		KeeperLineDistance = 11.5,
		SubstitutionHalfWidth = 9,
	},
}

function Court.get(modeId: string): Dimensions
	return DIMENSIONS[modeId] or DIMENSIONS["5v5"]
end

-- `side` = côté du but : -1 (but en -X) ou 1 (but en +X).
function Court.goalLineX(dims: Dimensions, side: number): number
	return side * dims.Length / 2
end

-- Distance horizontale entre un point et le segment entre les deux poteaux.
-- La zone de 6 m est l'ensemble des points à moins de GoalAreaRadius de ce
-- segment : deux quarts de cercle reliés par une droite, comme en vrai.
function Court.distanceToGoal(dims: Dimensions, localPos: Vector3, side: number): number
	local goalX = Court.goalLineX(dims, side)
	local halfWidth = dims.GoalWidth / 2
	local clampedZ = math.clamp(localPos.Z, -halfWidth, halfWidth)
	local dx = localPos.X - goalX
	local dz = localPos.Z - clampedZ
	return math.sqrt(dx * dx + dz * dz)
end

function Court.inGoalArea(dims: Dimensions, localPos: Vector3, side: number): boolean
	if side * localPos.X > dims.Length / 2 + 0.5 then
		return false
	end
	return Court.distanceToGoal(dims, localPos, side) <= dims.GoalAreaRadius
end

function Court.inFreeThrowArea(dims: Dimensions, localPos: Vector3, side: number): boolean
	return Court.distanceToGoal(dims, localPos, side) <= dims.FreeThrowRadius
end

function Court.inBounds(dims: Dimensions, localPos: Vector3, margin: number?): boolean
	local m = margin or 0
	return math.abs(localPos.X) <= dims.Length / 2 + m and math.abs(localPos.Z) <= dims.Width / 2 + m
end

-- Ramène un point juste à l'extérieur d'une distance donnée autour du but
-- (utile pour placer un jet franc sur la ligne des 9 m).
function Court.pushOutside(dims: Dimensions, localPos: Vector3, side: number, radius: number): Vector3
	local goalX = Court.goalLineX(dims, side)
	local halfWidth = dims.GoalWidth / 2
	local clampedZ = math.clamp(localPos.Z, -halfWidth, halfWidth)
	local anchor = Vector3.new(goalX, 0, clampedZ)
	local flat = Vector3.new(localPos.X, 0, localPos.Z)
	local offset = flat - anchor
	if offset.Magnitude < 0.01 then
		offset = Vector3.new(-side, 0, 0)
	end
	if offset.Magnitude >= radius then
		return localPos
	end
	local pushed = anchor + offset.Unit * (radius + 0.5)
	-- Le point doit rester dans le terrain, côté terrain du but.
	local maxX = dims.Length / 2 - 1
	return Vector3.new(math.clamp(pushed.X, -maxX, maxX), localPos.Y, math.clamp(pushed.Z, -dims.Width / 2 + 1, dims.Width / 2 - 1))
end

function Court.penaltySpot(dims: Dimensions, side: number): Vector3
	return Vector3.new(side * (dims.Length / 2 - dims.PenaltyDistance), 0, 0)
end

function Court.keeperSpot(dims: Dimensions, side: number): Vector3
	return Vector3.new(side * (dims.Length / 2 - 2.5), 0, 0)
end

-- Positions de départ d'une équipe qui défend le but `side`.
-- Indice 1 = gardien, ensuite les joueurs de champ répartis dans sa moitié.
function Court.formation(dims: Dimensions, fieldPlayers: number, side: number, kickoff: boolean): { Vector3 }
	local positions = { Court.keeperSpot(dims, side) }
	local halfLength = dims.Length / 2
	local depth = if kickoff then 0.22 else 0.42
	local x = side * halfLength * depth
	for i = 1, fieldPlayers do
		local t = if fieldPlayers == 1 then 0.5 else (i - 1) / (fieldPlayers - 1)
		local z = (t - 0.5) * dims.Width * 0.7
		local stagger = if i % 2 == 0 then side * 4 else 0
		table.insert(positions, Vector3.new(x + stagger, 0, z))
	end
	return positions
end

return Court
