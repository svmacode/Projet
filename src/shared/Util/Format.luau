--!strict
-- Petites fonctions de mise en forme (nombres, temps).

local Format = {}

function Format.number(value: number): string
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (formatted:gsub("^ ", ""))
end

function Format.clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

function Format.percent(value: number): string
	if value >= 10 then
		return string.format("%d %%", math.floor(value + 0.5))
	end
	return (string.format("%.1f %%", value):gsub("%.", ","))
end

return Format
