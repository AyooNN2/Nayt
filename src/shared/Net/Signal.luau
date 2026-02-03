--!strict
-- Types
-- -- Receiver type
-- -- -- private
type _Receiver = Receiver & {
	_next: _Receiver,
	_prev: _Receiver | _Signal,
	_func: (...any) -> (),
}
-- -- public
export type Receiver = {
	Type: "Receiver",
	Disconnect: (self: _Receiver | any) -> (),
}

-- -- Signal type
-- -- -- private
type _Signal = Signal & {
	_next: _Receiver,
	_prev: _Receiver | _Signal,
}
-- -- -- public
export type Signal = {
	Type: "Signal",
	Destroy: (self: _Signal | any) -> (),

	Fire: (self: _Signal | any, ...any) -> (),
	Connect: (self: _Signal | any, callback: (...any) -> ...any) -> Receiver,
	Once: (self: _Signal | any, callback: (...any) -> ...any) -> Receiver,
	Wait: (self: _Receiver | any) -> ...any,
}

local Signal = {} :: _Signal & { [any]: any }
Signal.__index = Signal
Signal.Type = "Signal"

local Receiver = {} :: _Receiver & { [any]: any }
Receiver.__index = Receiver
Receiver.Type = "Receiver"

local suspendedCoroutines = {}

-- Functions
-- -- Local Functions

local function call(func, ...)
	func(...)
end

local function reuseable(...)
	call(...)
	while true do
		call(coroutine.yield())
	end
end

-- -- Receiver
-- -- -- public
function Receiver:Disconnect()
	local nextReceiver, prevReceiver = self._next, self._prev
	if nextReceiver then
		nextReceiver._prev = prevReceiver
	end
	prevReceiver._next = nextReceiver
	table.clear(self)
end

-- -- Signal
-- -- -- public
function Signal:Fire(...)
	local receiver = self._next
	while receiver ~= nil do
		local reuseableCoroutine = table.remove(suspendedCoroutines) or coroutine.create(reuseable)
		coroutine.resume(reuseableCoroutine, receiver._func, ...)
		table.insert(suspendedCoroutines, reuseableCoroutine)
		receiver = receiver._next
	end
end

function Signal:Connect(callback)
	assert(typeof(callback) == "function", "callback must be a function")
	local nextReceiver = self._next
	local receiver = {
		_next = nextReceiver,
		_prev = self,
		_func = callback,
	}
	if nextReceiver ~= nil then
		nextReceiver._prev = receiver
	end
	(self :: any)._next = receiver
	return setmetatable(receiver, Receiver) :: any
end

function Signal:Once(callback)
	assert(typeof(callback) == "function", "callback must be a function")
	local receiver: Receiver
	receiver = self:Connect(function(...)
		callback(...)
		receiver:Disconnect()
	end)
	return receiver
end

function Signal:Wait()
	local co = coroutine.running()
	self:Once(function(...)
		coroutine.resume(co, ...)
	end)
	return coroutine.yield()
end

function Signal:Destroy()
	local receiver = self._next
	while receiver ~= nil do
		local temp = receiver._next
		receiver:Disconnect()
		receiver = temp
	end
	table.clear(self)
end

-- Return Constructor
return table.freeze({
	new = function(): Signal
		return setmetatable({}, Signal) :: any
	end,
})
