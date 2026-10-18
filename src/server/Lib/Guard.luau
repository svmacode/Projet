--!strict
-- Validation des arguments venant du client. Tout argument est hostile
-- jusqu'à preuve du contraire (NaN, infini, mauvais type, table piégée…).

local Guard = {}

function Guard.number(value: unknown, min: number, max: number): number?
	if typeof(value) ~= "number" then
		return nil
	end
	if value ~= value or value < min or value > max then
		return nil
	end
	return value
end

function Guard.integer(value: unknown, min: number, max: number): number?
	local n = Guard.number(value, min, max)
	if n and n == math.floor(n) then
		return n
	end
	return nil
end

function Guard.string(value: unknown, maxLength: number): string?
	if typeof(value) ~= "string" then
		return nil
	end
	if #value > maxLength or not utf8.len(value) then
		return nil
	end
	return value
end

function Guard.boolean(value: unknown): boolean?
	if typeof(value) ~= "boolean" then
		return nil
	end
	return value
end

-- Vecteur fini et non nul, renvoyé normalisé.
function Guard.direction(value: unknown): Vector3?
	if typeof(value) ~= "Vector3" then
		return nil
	end
	local x, y, z = value.X, value.Y, value.Z
	if x ~= x or y ~= y or z ~= z then
		return nil
	end
	if math.abs(x) == math.huge or math.abs(y) == math.huge or math.abs(z) == math.huge then
		return nil
	end
	if value.Magnitude < 1e-3 then
		return nil
	end
	return value.Unit
end

function Guard.oneOf(value: unknown, options: { string }): string?
	if typeof(value) ~= "string" then
		return nil
	end
	if table.find(options, value) then
		return value
	end
	return nil
end

return Guard
