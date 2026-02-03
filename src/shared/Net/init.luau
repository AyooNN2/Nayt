--!strict
--By: @rancidmilk1.5
--Minor changes by: @_ayoon
local ExperienceStateRecordingService = game:GetService("ExperienceStateRecordingService")
local RunService = game:GetService("RunService")

type RunContext = "Client" | "Server"

local Signal = require("@self/Signal")

local isClient = RunService:IsClient()
local RunContext: RunContext = if isClient then "Client" else "Server"

local unreliableRemoteEvent = isClient and script:FindFirstChildOfClass("UnreliableRemoteEvent")
	or Instance.new("UnreliableRemoteEvent", script)
local remoteEvent = script:FindFirstChildOfClass("RemoteEvent") or Instance.new("RemoteEvent", script)
local remoteFunc = script:FindFirstChildOfClass("RemoteFunction") or Instance.new("RemoteFunction", script)
--TODO: Faire Net.Client et Net.Server

local NetClient = {}
local NetServer = {}
local Ports = {} :: { [string]: Signal.Signal }
local Callbacks = {} :: { [string]: (...any) -> ...any }

local function HandleRemoteFired(...: any)
	local args = { ... }
	local portId = if RunContext == "Client" then table.remove(args, 1) else table.remove(args, 2)

	assert(typeof(portId) == "string", "Invalid port id")
	local port = Ports[portId]
	if port then
		port:Fire(unpack(args))
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

function _wait(portId: string): ...any
	Ports[portId] = Ports[portId] or Signal.new()
	return Ports[portId]:Wait()
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
	NetClient.Request = function(portId: string, timeout: number?, ...: any?): typeof(_request)
		return _request(nil, portId, timeout, ...)
	end

	NetClient.SendAsync = function(portId: string, ...: any?): ()
		return _sendUnsafeAsync(nil, portId, ...)
	end

	NetClient.SendUnsafeAsync = function(portId: string, ...: any?): ()
		return _sendUnsafeAsync(nil, portId, ...)
	end

	NetClient.HandleRequest = _handleRequest
	NetClient.Connect = _connect
	NetClient.Wait = _wait

	remoteFunc.OnClientInvoke = HandleInvocation
	remoteEvent.OnClientEvent:Connect(HandleRemoteFired)
	unreliableRemoteEvent.OnClientEvent:Connect(HandleRemoteFired)

	unreliableRemoteEvent.Parent = nil
	remoteEvent.Parent = nil
	remoteFunc.Parent = nil
else
	NetServer.Request = function(player: Player, portId: string, timeout: number?, ...: any?): typeof(_request)
		return _request(player, portId, timeout, ...)
	end

	NetServer.SendAsync = function(player: Player, portId: string, ...: any?): ()
		return _sendUnsafeAsync(player, portId, ...)
	end

	NetServer.SendUnsafeAsync = function(player: Player, portId: string, ...: any?): ()
		return _sendUnsafeAsync(player, portId, ...)
	end

	NetServer.HandleRequest = _handleRequest
	NetServer.Connect = _connect
	NetServer.Wait = _wait

	remoteFunc.OnServerInvoke = HandleInvocation
	remoteEvent.OnServerEvent:Connect(HandleRemoteFired)
	unreliableRemoteEvent.OnServerEvent:Connect(HandleRemoteFired)
end

return if RunContext == "Server" then NetServer else NetClient
