--!strict
-- Validation of untrusted remote arguments. Every function returns nil when
-- the value is not acceptable, so handlers can drop the request early.

local Guard = {}

function Guard.string(value: unknown, maxLength: number?): string?
	if typeof(value) ~= "string" then
		return nil
	end
	if #value > (maxLength or 64) then
		return nil
	end
	return value
end

function Guard.oneOf(value: unknown, allowed: { string }): string?
	if typeof(value) ~= "string" or not table.find(allowed, value) then
		return nil
	end
	return value
end

-- Finite number inside [min, max]. Rejects NaN and infinities.
function Guard.number(value: unknown, min: number, max: number): number?
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if value < min or value > max then
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

-- Finite Vector3 with bounded magnitude.
function Guard.vector(value: unknown, maxMagnitude: number?): Vector3?
	if typeof(value) ~= "Vector3" then
		return nil
	end
	local v = value :: Vector3
	if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then
		return nil
	end
	if v.Magnitude > (maxMagnitude or 1e5) then
		return nil
	end
	return v
end

-- Unit direction (normalised) from an untrusted vector; nil if degenerate.
function Guard.direction(value: unknown): Vector3?
	local v = Guard.vector(value, 1e4)
	if not v or v.Magnitude < 1e-3 then
		return nil
	end
	return v.Unit
end

-- A payload table: only a plain table is accepted (remotes strip metatables).
function Guard.payload(value: unknown): { [string]: unknown }
	if typeof(value) ~= "table" then
		return {}
	end
	return value :: any
end

return Guard
