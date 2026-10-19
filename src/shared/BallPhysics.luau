--!strict
-- Ball flight model shared by the server (authoritative simulation) and the
-- client (prediction between snapshots). Pure functions only: no Instances.
-- Positions are world space; `floorY` is the court floor height.

local Config = require(script.Parent.Config)

local BallPhysics = {}

local GRAVITY = Vector3.new(0, -Config.Ball.Gravity, 0)

-- Advances one step. Returns the new position, the new velocity and whether
-- the ball bounced on the floor during this step.
function BallPhysics.step(position: Vector3, velocity: Vector3, dt: number, floorY: number): (Vector3, Vector3, boolean)
	local radius = Config.Ball.Radius
	local newVelocity = velocity + GRAVITY * dt
	local newPosition = position + (velocity + newVelocity) * 0.5 * dt
	local bounced = false
	if newPosition.Y <= floorY + radius then
		newPosition = Vector3.new(newPosition.X, floorY + radius, newPosition.Z)
		if newVelocity.Y < 0 then
			local bounceY = -newVelocity.Y * Config.Ball.FloorRestitution
			if bounceY < 6 then
				bounceY = 0 -- settles and rolls
			end
			newVelocity = Vector3.new(newVelocity.X, bounceY, newVelocity.Z)
			bounced = velocity.Y < -6
		end
		-- Rolling friction while touching the floor.
		local keep = math.max(0, 1 - Config.Ball.RollingFriction * dt)
		newVelocity = Vector3.new(newVelocity.X * keep, newVelocity.Y, newVelocity.Z * keep)
	end
	return newPosition, newVelocity, bounced
end

-- Predicts the state `elapsed` seconds ahead with fixed sub-steps.
function BallPhysics.predict(position: Vector3, velocity: Vector3, elapsed: number, floorY: number): (Vector3, Vector3)
	local step = Config.Ball.SimStep * 2
	local p, v = position, velocity
	local remaining = math.min(elapsed, 3)
	while remaining > 0 do
		local dt = math.min(step, remaining)
		p, v = BallPhysics.step(p, v, dt, floorY)
		remaining -= dt
	end
	return p, v
end

-- Velocity that sends the ball from `from` to `to` at roughly `speed`,
-- compensating gravity so that it arrives at the target height.
function BallPhysics.directVelocity(from: Vector3, to: Vector3, speed: number): Vector3
	local delta = to - from
	local flat = Vector3.new(delta.X, 0, delta.Z)
	local distance = flat.Magnitude
	if distance < 0.01 then
		return Vector3.new(0, speed, 0)
	end
	local time = distance / speed
	local vy = (delta.Y + 0.5 * Config.Ball.Gravity * time * time) / time
	return flat.Unit * speed + Vector3.new(0, vy, 0)
end

-- Lob: reaches `apex` studs above the higher of the two points, lands on `to`.
function BallPhysics.lobVelocity(from: Vector3, to: Vector3, apex: number): Vector3
	local g = Config.Ball.Gravity
	local top = math.max(from.Y, to.Y) + apex
	local up = math.sqrt(2 * g * math.max(0.1, top - from.Y))
	local down = math.sqrt(2 * g * math.max(0.1, top - to.Y))
	local time = up / g + down / g
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return flat / time + Vector3.new(0, up, 0)
end

-- Straight launch along a direction (shots and aimed passes).
function BallPhysics.alongDirection(direction: Vector3, speed: number): Vector3
	if direction.Magnitude < 0.01 then
		return Vector3.new(0, 0, -speed)
	end
	return direction.Unit * speed
end

-- Closest approach between a moving ball segment and a point (for catches,
-- interceptions, blocks and saves between two simulation steps).
function BallPhysics.segmentDistance(a: Vector3, b: Vector3, point: Vector3): number
	local ab = b - a
	local lengthSq = ab:Dot(ab)
	if lengthSq < 1e-6 then
		return (point - a).Magnitude
	end
	local t = math.clamp((point - a):Dot(ab) / lengthSq, 0, 1)
	return (a + ab * t - point).Magnitude
end

return BallPhysics
