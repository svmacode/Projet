--!strict
-- Réessaie un appel réseau (DataStore, MemoryStore, Teleport…) avec un délai
-- qui double à chaque échec.

local Retry = {}

function Retry.call<T>(label: string, attempts: number, fn: () -> T): (boolean, T?)
	local delaySeconds = 1
	local lastError: any = nil
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < attempts then
			task.wait(delaySeconds)
			delaySeconds = math.min(delaySeconds * 2, 16)
		end
	end
	warn(`[Retry] {label} : échec après {attempts} tentatives : {lastError}`)
	return false, nil
end

return Retry
