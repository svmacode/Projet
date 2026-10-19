--!strict
-- Minimal typed signal for communication between modules on the same side.

export type Connection = { Disconnect: (Connection) -> () }

export type Signal<T...> = {
	Connect: (Signal<T...>, (T...) -> ()) -> Connection,
	Fire: (Signal<T...>, T...) -> (),
	Wait: (Signal<T...>) -> T...,
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { [number]: (T...) -> () } = {}
	local nextId = 0
	local self = {}

	function self.Connect(_: any, handler: (T...) -> ()): Connection
		nextId += 1
		local id = nextId
		handlers[id] = handler
		return {
			Disconnect = function()
				handlers[id] = nil
			end,
		}
	end

	function self.Fire(_: any, ...: T...)
		for _, handler in handlers do
			task.spawn(handler, ...)
		end
	end

	function self.Wait(_: any): T...
		local thread = coroutine.running()
		local connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end

	return self :: any
end

return Signal
