--!strict
-- The ONLY server Script. Requires every service in a fixed order, then runs
-- the two-phase startup: init() for all (synchronous wiring, no yields), then
-- start() for all (long-running work, each in its own thread).

local ORDER = {
	"AntiExploitService",
	"MapService",
	"MatchService",
	"DevService", -- Phase 1 development entry point (start a test match)
}

local services: { { Name: string, Module: any } } = {}
for _, name in ORDER do
	local moduleScript = script.Services:FindFirstChild(name)
	assert(moduleScript and moduleScript:IsA("ModuleScript"), `Missing service {name}`)
	table.insert(services, { Name = name, Module = require(moduleScript) :: any })
end

for _, service in services do
	if typeof(service.Module.init) == "function" then
		service.Module.init()
	end
end

for _, service in services do
	if typeof(service.Module.start) == "function" then
		task.spawn(service.Module.start)
	end
end
