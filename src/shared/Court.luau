--!strict
-- Géométrie du terrain de handball, dans le repère local du terrain :
--   origine = centre du terrain, X = longueur (les buts sont en ±X),
--   Z = largeur, Y = hauteur (le sol est à Y = 0).
--
-- Terrains « moyens » : environ 7 s pour traverser le 5v5 en courant.
-- Proportions inspirées du handball (zone de 6 m, ligne des 9 m), mises à
-- l'échelle selon le mode ; les buts rétrécissent moins que le terrain pour
-- garder des tirs lisibles en 2v2.

local Court = {}

export type Dimensions = {
	Length: number,
	Width: number,
	GoalWidth: number,
	GoalHeight: number,
	GoalDepth: number,
	GoalAreaRadius: number, -- zone (6 m) réservée au gardien
	FreeThrowRadius: number, -- ligne des 9 m (pointillés, repère visuel)
}

local DIMENSIONS: { [string]: Dimensions } = {
	["2v2"] = {
		Length = 100,
		Width = 56,
		GoalWidth = 11,
		GoalHeight = 7.2,
		GoalDepth = 4,
		GoalAreaRadius = 15,
		FreeThrowRadius = 23,
	},
	["3v3"] = {
		Length = 120,
		Width = 64,
		GoalWidth = 12,
		GoalHeight = 7.5,
		GoalDepth = 4.2,
		GoalAreaRadius = 17.5,
		FreeThrowRadius = 26.5,
	},
	["4v4"] = {
		Length = 140,
		Width = 74,
		GoalWidth = 12.5,
		GoalHeight = 7.8,
		GoalDepth = 4.4,
		GoalAreaRadius = 20,
		FreeThrowRadius = 30,
	},
	["5v5"] = {
		Length = 160,
		Width = 84,
		GoalWidth = 13,
		GoalHeight = 8,
		GoalDepth = 4.5,
		GoalAreaRadius = 22,
		FreeThrowRadius = 33,
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

function Court.inBounds(dims: Dimensions, localPos: Vector3, margin: number?): boolean
	local m = margin or 0
	return math.abs(localPos.X) <= dims.Length / 2 + m and math.abs(localPos.Z) <= dims.Width / 2 + m
end

-- Ramène un point juste à l'extérieur d'une distance donnée autour du but
-- (utile pour placer un jet franc hors de la zone).
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
	return Vector3.new(
		math.clamp(pushed.X, -maxX, maxX),
		localPos.Y,
		math.clamp(pushed.Z, -dims.Width / 2 + 1, dims.Width / 2 - 1)
	)
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
