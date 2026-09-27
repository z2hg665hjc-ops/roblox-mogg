--[[
	Signal.lua
	Minimal, dependency-free event emitter used for in-process (server-only or
	client-only) communication between modules. Not for client<->server use —
	that's what Remotes.lua and RemoteEvents are for.
]]

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({
		_handlers = {},
		_nextId = 0,
	}, Signal)
end

function Signal:Connect(fn)
	self._nextId += 1
	local id = self._nextId
	self._handlers[id] = fn
	local connection = {}
	function connection.Disconnect()
		self._handlers[id] = nil
	end
	return connection
end

function Signal:Fire(...)
	for _, fn in pairs(self._handlers) do
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[Signal] handler error:", err)
		end
	end
end

function Signal:DisconnectAll()
	self._handlers = {}
end

return Signal
