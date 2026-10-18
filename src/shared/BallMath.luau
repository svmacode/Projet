--!strict
-- Physique du ballon partagée entre le serveur (autorité) et les clients
-- (prédiction visuelle entre deux mises à jour). Le ballon n'utilise pas le
-- moteur physique de Roblox : sa trajectoire est calculée ici, ce qui la rend
-- identique partout et permet les effets « animé » (tirs courbés, guidés…).

local Config = require(script.Parent.Config)

local BallMath = {}

export type CastFn = (origin: Vector3, direction: Vector3) -> (Vector3?, Vector3?, Instance?)

export type StepResult = {
	Position: Vector3,
	Velocity: Vector3,
	Bounced: boolean,
	HitInstance: Instance?,
	Grounded: boolean,
}

local GRAVITY = Vector3.new(0, -Config.Ball.Gravity, 0)
local RADIUS = Config.Ball.Radius
local MAX_SUBSTEP = 1 / 90

local function reflect(velocity: Vector3, normal: Vector3, restitution: number): Vector3
	local intoSurface = velocity:Dot(normal)
	if intoSurface >= 0 then
		return velocity
	end
	local normalPart = normal * intoSurface
	local tangentPart = velocity - normalPart
	return tangentPart * 0.92 - normalPart * restitution
end

-- Avance la simulation de `dt` secondes. `accel` est une accélération en plus
-- de la gravité (effet courbé, guidage). `cast` lance une sphère et renvoie
-- le point de contact, la normale et l'objet touché.
function BallMath.step(position: Vector3, velocity: Vector3, accel: Vector3, dt: number, cast: CastFn): StepResult
	local pos = position
	local vel = velocity
	local bounced = false
	local hitInstance: Instance? = nil
	local grounded = false
	local remaining = dt
	while remaining > 1e-5 do
		local h = math.min(remaining, MAX_SUBSTEP)
		remaining -= h
		vel += (GRAVITY + accel) * h
		local displacement = vel * h
		if displacement.Magnitude > 1e-4 then
			local hitPos, normal, instance = cast(pos, displacement)
			if hitPos and normal then
				pos = hitPos + normal * (RADIUS + 0.02)
				local isFloor = normal.Y > 0.7
				local restitution = if isFloor then Config.Ball.FloorRestitution else Config.Ball.WallRestitution
				local impact = -vel:Dot(normal)
				vel = reflect(vel, normal, restitution)
				if isFloor and impact < 7 then
					-- Le ballon roule : on supprime le rebond résiduel.
					vel = Vector3.new(vel.X, 0, vel.Z)
					grounded = true
				end
				if impact > 2 then
					bounced = true
					hitInstance = instance
				end
			else
				pos += displacement
			end
		end
		if grounded then
			local friction = math.max(0, 1 - Config.Ball.RollingFriction * h)
			vel = Vector3.new(vel.X * friction, vel.Y, vel.Z * friction)
		end
	end
	return {
		Position = pos,
		Velocity = vel,
		Bounced = bounced,
		HitInstance = hitInstance,
		Grounded = grounded,
	}
end

-- Vitesse initiale pour atteindre `target` depuis `origin` en `travelTime`
-- secondes (passe en cloche).
function BallMath.solveLob(origin: Vector3, target: Vector3, travelTime: number): Vector3
	local delta = target - origin
	local t = math.max(travelTime, 0.05)
	local horizontal = Vector3.new(delta.X, 0, delta.Z) / t
	local vertical = (delta.Y + 0.5 * Config.Ball.Gravity * t * t) / t
	return Vector3.new(horizontal.X, vertical, horizontal.Z)
end

-- Position au temps t sans collision (pour l'aperçu de trajectoire).
function BallMath.positionAt(origin: Vector3, velocity: Vector3, accel: Vector3, t: number): Vector3
	return origin + velocity * t + 0.5 * (GRAVITY + accel) * t * t
end

return BallMath
