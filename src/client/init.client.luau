--!strict
-- The ONLY client LocalScript. Same two-phase startup as the server.

local ORDER = {
	"MatchClient", -- receives MatchState / BallState / MatchEvent, exposes signals
	"InputController",
	"CameraController",
	"MovementController",
	"BallRenderer",
	"AnimationController",
	"ActionController",
	"EffectsController",
	"HUDController",
	"DevPanel", -- Phase 1 development entry point
}

local controllers: { any } = {}
for _, name in ORDER do
	local moduleScript = script.Controllers:FindFirstChild(name)
	assert(moduleScript and moduleScript:IsA("ModuleScript"), `Missing controller {name}`)
	table.insert(controllers, require(moduleScript) :: any)
end

for _, controller in controllers do
	if typeof(controller.init) == "function" then
		controller.init()
	end
end

for _, controller in controllers do
	if typeof(controller.start) == "function" then
		task.spawn(controller.start)
	end
end
