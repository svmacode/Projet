--!strict
-- Court geometry, in court-local space: origin at the centre spot on the floor,
-- X along the length (goal at X = ±Length/2), Z along the width, Y up.
-- Used by the server for rule decisions and by the client for drawing and hints.

local Config = require(script.Parent.Config)

local CourtGeometry = {}

export type Court = {
	Mode: Config.Mode,
	CFrame: CFrame, -- court centre on the floor
	HalfLength: number,
	HalfWidth: number,
}

function CourtGeometry.new(modeId: string, cframe: CFrame): Court
	local mode = Config.Modes[modeId]
	assert(mode, `Unknown mode {modeId}`)
	return {
		Mode = mode,
		CFrame = cframe,
		HalfLength = mode.CourtLength / 2,
		HalfWidth = mode.CourtWidth / 2,
	}
end

function CourtGeometry.toLocal(court: Court, world: Vector3): Vector3
	return court.CFrame:PointToObjectSpace(world)
end

function CourtGeometry.toWorld(court: Court, localPoint: Vector3): Vector3
	return court.CFrame:PointToWorldSpace(localPoint)
end

-- Centre of the goal line of the goal at `side` (+1 or -1), local space.
function CourtGeometry.goalCenter(court: Court, side: number): Vector3
	return Vector3.new(side * court.HalfLength, 0, 0)
end

-- Horizontal distance from a local point to the goal line segment between the posts.
-- The goal area in handball is exactly the set of points within the radius of
-- that segment (two quarter circles joined by a straight line).
local function distanceToGoalSegment(court: Court, localPoint: Vector3, side: number): number
	local goalX = side * court.HalfLength
	local halfGoal = Config.Goal.Width / 2
	local z = math.clamp(localPoint.Z, -halfGoal, halfGoal)
	local dx = localPoint.X - goalX
	local dz = localPoint.Z - z
	return math.sqrt(dx * dx + dz * dz)
end

function CourtGeometry.goalDistance(court: Court, localPoint: Vector3, side: number): number
	return distanceToGoalSegment(court, localPoint, side)
end

-- True when the point is inside the goal area ("6 m") in front of the goal at `side`.
function CourtGeometry.inGoalArea(court: Court, localPoint: Vector3, side: number): boolean
	if localPoint.X * side > court.HalfLength + 0.01 then
		return false
	end
	return distanceToGoalSegment(court, localPoint, side) < court.Mode.GoalAreaRadius
end

-- True when the point is inside the free-throw line ("9 m") at `side`.
function CourtGeometry.inFreeThrowZone(court: Court, localPoint: Vector3, side: number): boolean
	return distanceToGoalSegment(court, localPoint, side) < court.Mode.FreeThrowRadius
end

function CourtGeometry.penaltySpot(court: Court, side: number): Vector3
	return Vector3.new(side * (court.HalfLength - court.Mode.PenaltyDistance), 0, 0)
end

function CourtGeometry.inBounds(court: Court, localPoint: Vector3, margin: number?): boolean
	local m = margin or 0
	return math.abs(localPoint.X) <= court.HalfLength + m and math.abs(localPoint.Z) <= court.HalfWidth + m
end

-- Pushes a local point radially out of a zone around the goal at `side`
-- (used to place free throws on the 9 m line and defenders off a throw).
function CourtGeometry.pushOutOfRadius(court: Court, localPoint: Vector3, side: number, radius: number): Vector3
	local goalX = side * court.HalfLength
	local halfGoal = Config.Goal.Width / 2
	local z = math.clamp(localPoint.Z, -halfGoal, halfGoal)
	local anchor = Vector3.new(goalX, 0, z)
	local offset = Vector3.new(localPoint.X - goalX, 0, localPoint.Z - z)
	if offset.Magnitude >= radius then
		return localPoint
	end
	local direction = if offset.Magnitude > 0.01 then offset.Unit else Vector3.new(-side, 0, 0)
	if direction.X * side > 0 then
		direction = Vector3.new(-side, 0, direction.Z).Unit
	end
	local pushed = anchor + direction * (radius + 0.5)
	return Vector3.new(pushed.X, localPoint.Y, pushed.Z)
end

-- Clamps a local point inside the court lines.
function CourtGeometry.clampInside(court: Court, localPoint: Vector3, margin: number?): Vector3
	local m = margin or 1
	return Vector3.new(
		math.clamp(localPoint.X, -court.HalfLength + m, court.HalfLength - m),
		localPoint.Y,
		math.clamp(localPoint.Z, -court.HalfWidth + m, court.HalfWidth - m)
	)
end

-- Did a ball segment (local space) cross the goal line between the posts and
-- under the crossbar? Returns the crossing point if so.
function CourtGeometry.crossesGoal(court: Court, fromLocal: Vector3, toLocal: Vector3, side: number): Vector3?
	local goalX = side * court.HalfLength
	local a = (fromLocal.X - goalX) * side
	local b = (toLocal.X - goalX) * side
	if not (a < 0 and b >= 0) then
		return nil
	end
	local t = a / (a - b)
	local point = fromLocal:Lerp(toLocal, t)
	local radius = Config.Ball.Radius
	if math.abs(point.Z) <= Config.Goal.Width / 2 - radius and point.Y <= Config.Goal.Height - radius then
		return point
	end
	return nil
end

return CourtGeometry
