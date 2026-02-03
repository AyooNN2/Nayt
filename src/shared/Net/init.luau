--!strict
--By: @rancidmilk1.5
--Minor changes by: @_ayoon
local RunService = game:GetService("RunService")

type RunContext = "Client" | "Server"

local Signal = require("@self/Signal")

local isClient = RunService:IsClient()
local RunContext: RunContext = isClient and "Client" or "Server"

local unreliableRemoteEvent = isClient and script:FindFirstChildOfClass("UnreliableRemoteEvent")
	or Instance.new("UnreliableRemoteEvent", script)
local remoteEvent = script:FindFirstChildOfClass("RemoteEvent") or Instance.new("RemoteEvent", script)
local remoteFunc = script:FindFirstChildOfClass("RemoteFunction") or Instance.new("RemoteFunction", script)
--TODO: Faire Net.Client et Net.Server

local Net = {}
local Ports = {} :: { [string]: Signal.Signal }
local Callbacks = {} :: { [string]: (...any) -> ...any }

local function HandleRemoteFired(...: any)
	local args = { ... }
	local portId = if RunService:IsClient() then table.remove(args, 1) else table.remove(args, 2)

	assert(typeof(portId) == "string", "Invalid port id")
	local port = Ports[portId]
	if port then
		port:Fire(unpack(args))
	else
		warn(`[{script.Name}]: No receiver subscribed to port [{portId}]`)
	end
end

local function HandleInvocationClient(portId: string, ...: any?)
	if not isClient then
		warn(`[{script.Name}]: This function is only call-able on client-side`)
		return
	end
	assert(typeof(portId) == "string", `Invalid portId type, expected string, got {typeof(portId)}`)
	local callback = Callbacks[portId]

	if callback then
		return callback(...)
	end
	return warn(`[{script.Name}]: No callback subscribed to port [{portId}]`)
end

local function HandleInvocationServer(Player: Player, portId: string, ...: any?)
	if isClient then
		warn(`[{script.Name}]: This function is only callable server-side`)
		return
	end
	assert(typeof(portId) == "string", `Invalid portId type, expected string, got {typeof(portId)}`)

	local callback = Callbacks[portId]

	if callback then
		return callback(Player, ...)
	end
	return warn(`[{script.Name}]: No callback subscribed to port [{portId}]`)
end

local function HandleInvocation(...: any)
	local args = { ... }
	local portId = if RunService:IsClient() then table.remove(args, 1) else table.remove(args, 2)

	assert(typeof(portId) == "string", `Invalid portId type, expected string, got {typeof(portId)}`)
	local callback = Callbacks[portId]
	if callback then
		return callback(unpack(args))
	end
	return warn(`[{script.Name}]: No callback subscribed to port [{portId}]`)
end

function Net.Wait(portId: string): ...any
	Ports[portId] = Ports[portId] or Signal.new()
	return Ports[portId]:Wait()
end

function Net.Connect(portId: string, callback: (...any) -> ()): Signal.Receiver
	Ports[portId] = Ports[portId] or Signal.new()
	return Ports[portId]:Connect(callback)
end

function Net.HandleRequest(portId: string, callback: (...any?) -> ...any?): ()
	assert(typeof(callback) == "function", "Callback to connect must be a function")
	if Callbacks[portId] then
		warn(`[{script.Name}]: Warning: Overwrote port [{portId}] callback`)
	end
	Callbacks[portId] = callback
end

-- player, portid, args
function Net.SendAsync(portId: string, ...: any?): ()
	if RunService:IsClient() then
		remoteEvent.Parent = script
		remoteEvent:FireServer(portId, ...)
		remoteEvent.Parent = nil
	else
		remoteEvent:FireClient(portId, ...)
	end
end

-- player, portid, args

function _sendUnsafeAsync(portId: string, player: Player?, ...: any?): ()
	if RunService:IsClient() then
		unreliableRemoteEvent.Parent = script
		unreliableRemoteEvent:FireServer(portId, ...)
		unreliableRemoteEvent.Parent = nil
	else
		unreliableRemoteEvent:FireClient(portId, ...)
	end
end

-- player, portid, args
local function _request(portId: string, timeout: number?, player: Player?, ...: any?): any
	local args = nil
	timeout = timeout or 10
	task.spawn(function(...)
		if RunContext == "Client" then
			remoteFunc.Parent = script
			args = { remoteFunc:InvokeServer(portId, ...) }
		else
			args = { remoteFunc:InvokeClient(player, portId, ...) }
		end
	end, ...)
	local t0 = os.clock()
	while timeout > os.clock() - t0 do
		if args then
			if RunContext == "Client" then
				remoteFunc.Parent = nil
			end
			return unpack(args)
		end
		task.wait()
	end
	warn(`[{script.Name}] Port: [{portId}] timed out after {os.clock() - t0} seconds`)
	return nil
end

if isClient then
	Net.Request = function(portId: string, timeout: number?, ...: any?): typeof(_request)
		return _request(portId, timeout, nil, ...)
	end

	Net.SendUnsafeAsync = function(portId: string, ...: any?): ()
		return _sendUnsafeAsync(portId, ...)
	end

	remoteFunc.OnClientInvoke = HandleInvocation
	remoteEvent.OnClientEvent:Connect(HandleRemoteFired)
	unreliableRemoteEvent.OnClientEvent:Connect(HandleRemoteFired)

	unreliableRemoteEvent.Parent = nil
	remoteEvent.Parent = nil
	remoteFunc.Parent = nil
else
	Net.Request = function(portId: string, timeout: number?, player: Player, ...: any?): typeof(_request)
		return _request(portId)
	end

	remoteFunc.OnServerInvoke = HandleInvocation
	remoteEvent.OnServerEvent:Connect(HandleRemoteFired)
	unreliableRemoteEvent.OnServerEvent:Connect(HandleRemoteFired)
end

return Net
