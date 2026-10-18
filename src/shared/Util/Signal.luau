--!strict
-- Signal minimal pour la communication entre modules (sans _G).

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _handlers = {} :: { any } }, Signal)
	return self :: any
end

function Signal:Connect(callback)
	local connection: any = { Connected = true, _callback = callback }
	local handlers = self._handlers
	function connection.Disconnect(conn: any)
		if not conn.Connected then
			return
		end
		conn.Connected = false
		local index = table.find(handlers, conn)
		if index then
			table.remove(handlers, index)
		end
	end
	table.insert(handlers, connection)
	return connection
end

function Signal:Once(callback)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function Signal:Fire(...)
	for _, connection: any in table.clone(self._handlers) do
		if connection.Connected then
			task.spawn(connection._callback, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, connection: any in self._handlers do
		connection.Connected = false
	end
	table.clear(self._handlers)
end

return Signal
