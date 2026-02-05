--!strict
--By: @rancidmilk1.5
--Minor changes by: @_ayoon
local RunService = game:GetService("RunService")

type RunContext = "Client" | "Server"

local Signal = require("@self/Signal")

local isClient = RunService:IsClient()
local RunContext: RunContext = if isClient then "Client" else "Server"

local unreliableRemoteEvent = isClient and script:FindFirstChildOfClass("UnreliableRemoteEvent")
	or Instance.new("UnreliableRemoteEvent", script)
local remoteEvent = script:FindFirstChildOfClass("RemoteEvent") or Instance.new("RemoteEvent", script)
local remoteFunc = script:FindFirstChildOfClass("RemoteFunction") or Instance.new("RemoteFunction", script)

local Net = { Client = {}, Server = {} }

local Ports = {} :: { [string]: Signal.Signal }
local Callbacks = {} :: { [string]: (...any) -> ...any }

local function HandleRemoteFired(...: any)
	local args = { ... }
	local argStart = if RunContext == "Client" then 1 else 2
	local portId = table.remove(args, argStart)
	warn(args)
	assert(typeof(portId) == "string", "Invalid port id")
	local port = Ports[portId]
	if port then
		print("found port", portId)
		port:Fire(unpack(args))
		print("port:", port)
	else
		warn(`[{script.Name}]: No receiver subscribed to port [{portId}]`)
	end
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

local function _wait(portId: string): ...any
	Ports[portId] = Ports[portId] or Signal.new()
	return Ports[portId]:Wait()
end

local function _once(portId: string, callback: (...any) -> ()): Signal.Receiver
	Ports[portId] = Ports[portId] or Signal.new()
	return Ports[portId]:Once(callback)
end

local function _connect(portId: string, callback: (...any) -> ()): Signal.Receiver
	Ports[portId] = Ports[portId] or Signal.new()
	return Ports[portId]:Connect(callback)
end

local function _handleRequest(portId: string, callback: (...any?) -> ...any?): ()
	assert(typeof(callback) == "function", "Callback to connect must be a function")
	if Callbacks[portId] then
		warn(`[{script.Name}]: Warning: Overwrote port [{portId}] callback`)
	end
	Callbacks[portId] = callback
end

local function _sendAsync(player: Player?, portId: string, ...: any?): ()
	if RunService:IsClient() then
		remoteEvent.Parent = script
		remoteEvent:FireServer(portId, ...)
		remoteEvent.Parent = nil
	else
		remoteEvent:FireClient(player, portId, ...)
	end
end

local function _sendUnsafeAsync(player: Player?, portId: string, ...: any?): ()
	if RunService:IsClient() then
		unreliableRemoteEvent.Parent = script
		unreliableRemoteEvent:FireServer(portId, ...)
		unreliableRemoteEvent.Parent = nil
	else
		unreliableRemoteEvent:FireClient(player, portId, ...)
	end
end

-- player, portid, args
local function _request(player: Player?, portId: string, timeout: number?, ...: any?): any
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
	Net.Client.Request = function(portId: string, timeout: number?, ...: any?): ...any?
		return _request(nil, portId, timeout, ...)
	end

	Net.Client.SendAsync = function(portId: string, ...: any?): ()
		return _sendAsync(nil, portId, ...)
	end

	Net.Client.SendUnsafeAsync = function(portId: string, ...: any?): ()
		return _sendUnsafeAsync(nil, portId, ...)
	end

	Net.Client.HandleRequest = _handleRequest
	Net.Client.Connect = _connect
	Net.Client.Wait = _wait
	Net.Client.Once = _once

	remoteFunc.OnClientInvoke = HandleInvocation
	remoteEvent.OnClientEvent:Connect(HandleRemoteFired)
	unreliableRemoteEvent.OnClientEvent:Connect(HandleRemoteFired)

	unreliableRemoteEvent.Parent = nil
	remoteEvent.Parent = nil
	remoteFunc.Parent = nil
else
	Net.Server.Request = function(player: Player, portId: string, timeout: number?, ...: any?): ...any?
		return _request(player, portId, timeout, ...)
	end

	Net.Server.SendAsync = function(player: Player, portId: string, ...: any?): ()
		return _sendAsync(player, portId, ...)
	end

	Net.Server.SendUnsafeAsync = function(player: Player, portId: string, ...: any?): ()
		return _sendUnsafeAsync(player, portId, ...)
	end

	Net.Server.HandleRequest = _handleRequest
	Net.Server.Connect = _connect
	Net.Server.Wait = _wait
	Net.Server.Once = _once

	remoteFunc.OnServerInvoke = HandleInvocation
	remoteEvent.OnServerEvent:Connect(HandleRemoteFired)
	unreliableRemoteEvent.OnServerEvent:Connect(HandleRemoteFired)
end

return Net
