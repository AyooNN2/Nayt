--!optimize 2

--By: @_ayoon (@AyooN2)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Bardo = require(script.Bardo)
local Net = require(script.Parent.Net)

local RunContext: "Server" | "Client" = if RunService:IsServer() then "Server" else "Client"

export type NaytPort<T...> = {
	Send: (NaytPort<T...>, Player, T...) -> () & (NaytPort<T...>, T...) -> (),
	SendUnsafe: (NaytPort<T...>, Player, T...) -> () & (NaytPort<T...>, T...) -> (),
	SendAll: (NaytPort<T...>, T...) -> (),
	SendAllUnsafe: (NaytPort<T...>, T...) -> (),

	Connect: (NaytPort<T...>, (T...) -> ()) -> () & (NaytPort<T...>, (Player, T...) -> ()) -> (),
	Once: (NaytPort<T...>, (T...) -> ()) -> () & (NaytPort<T...>, (Player, T...) -> ()) -> (),
	Wait: ((NaytPort<T...>) -> T...) & (NaytPort<T...>) -> (Player, T...),
	Request: (NaytPort<T...>, ...any?) -> T...,

	HandleRequest: (NaytPort<T...>, (...any) -> T...) -> (),
}

type Nayt = {
	new: (portId: string, schema: { Bardo.BardoType }?, config: { Secure: boolean? }?) -> NaytPort<...any?>,
}

local Nayt = {} :: Nayt
local NaytPorts: { [string]: NaytPort<...any?> } = {}

Nayt.__index = Nayt

const function getn(t: { [any?]: any? }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

const function equal(t1: { [any]: any }, t2: { [any]: any }): boolean
	if t1 == t2 then
		return true
	end
	for k, v in t1 do
		if t2[k] == nil then
			return false
		end
		if t2[k] ~= v then
			return false
		end
	end

	return getn(t1) == getn(t2)
end

const function getArgsType(...): { string }
	local t = { ... }
	for i, var in t do
		t[i] = typeof(var)
	end
	return t
end

function Nayt:_serialize(player: Player?, ...): (buffer?, { any? }?)
	local isServer = RunContext == "Server"

	if not self.fixedSchema then
		local newSchema = Bardo.autoSchema(...)
		local argsType = getArgsType(...)
		local schemaChanged = not equal(self.argsType, argsType)
		if self.secure and next(self.schema) and schemaChanged then
			for i, newType in newSchema do
				if i ~= "size" and self.schema[i] then
					assert(
						Bardo.tryConvertType(self.schema[i], newType, select(i, ...)),
						`Schema mismatch on port '{self.portId}': arg {i} requires {Bardo.getTypeName(self.schema[i])} but got {Bardo.getTypeName(
							newType
						)}`
					)
				end
			end
		end

		if schemaChanged and isServer then
			self.updatedPlayers = {}
		end

		self.schema = newSchema
		self.argsType = argsType
	end

	local buff, unserializable = Bardo.sanctify(self.schema, ...)
	if typeof(buff) ~= "buffer" then
		return buff
	end

	local shouldSendSchema
	if self.fixedSchema then
		shouldSendSchema = false
	elseif isServer then
		shouldSendSchema = not self.updatedPlayers[player]
		if shouldSendSchema then
			self.updatedPlayers[player] = true
		end
	else
		shouldSendSchema = true
	end

	local result = { buff }
	if unserializable then
		for _, value in unserializable do
			table.insert(result, value)
		end
	end

	if shouldSendSchema then
		table.insert(result, Bardo.sanctifySchema(self.schema))
	end

	return unpack(result)
end

function Nayt:_deserialize(...): { [string]: any } | any?
	local args = { ... }
	local buff = table.remove(args, 1) :: buffer
	local possibleSchema = args[#args]

	if not (possibleSchema and typeof(possibleSchema) == "buffer") then
		return Bardo.reborn(self.schema, buff, select(2, ...))
	end

	if RunContext == "Server" and self.fixedSchema then
		if self.secure then
			error(`[{self.portId}]: Client did not respect fixed schema, declined.`)
		end
		warn(`[{self.portId}]: Client did not respect fixed schema, accepted. (port's security is off)`)
	end

	local schemaBuffer = table.remove(args, #args) :: buffer
	local schema = Bardo.rebornSchema(schemaBuffer)

	if RunContext == "Client" then
		if self.fixedSchema then
			if self.secure then
				error(`[{self.portId}]: Server did not respect fixed schema, declined.`)
			end
			warn(`[{self.portId}]: Server did not respect fixed schema, accepted. (port's security is off)`)
		end
		self.schema = schema

		self.argsType = {}

		for i, bardoType in schema do
			if i ~= "size" then
				table.insert(self.argsType, bardoType.type())
			end
		end
	end

	return Bardo.reborn(schema, buff, unpack(args))
end

function Nayt:_send(player: Player?, safe: boolean, ...: any?)
	local serialized = { self:_serialize(player, ...) }
	if RunContext == "Server" then
		assert(player ~= nil, `[{self.portId}]: Player was not specified`)
		local sendFn = safe and Net.Server.SendAsync or Net.Server.SendUnsafeAsync
		sendFn(player :: Player, self.portId, table.unpack(serialized))
	else
		local sendFn = safe and Net.Client.SendAsync or Net.Client.SendUnsafeAsync
		sendFn(self.portId, table.unpack(serialized))
	end
end

function Nayt:Send(...): ()
	if RunContext == "Server" then
		local player = ...
		assert(typeof(player) == "Instance" and player:IsA("Player"), `[{self.portId}]: Player was not specified`)
		self:_send(player, true, select(2, ...))
	else
		self:_send(nil, true, ...)
	end
end

function Nayt:SendUnsafe(...): ()
	if RunContext == "Server" then
		local player = ...
		assert(typeof(player) == "Instance" and player:IsA("Player"), `[{self.portId}]: Player was not specified`)
		self:_send(player, false, select(2, ...))
	else
		self:_send(nil, false, ...)
	end
end

function Nayt:SendAll(...): ()
	assert(RunContext == "Server", `[{script.Name}]: This method is only callable server-side`)
	for _, player: Player in Players:GetPlayers() do
		self:Send(player, ...)
	end
end

function Nayt:SendUnsafeAll(...): ()
	assert(RunContext == "Server", `[{script.Name}]: This method is only callable server-side`)
	for _, player: Player in Players:GetPlayers() do
		self:SendUnsafe(player, ...)
	end
end

function Nayt:_wrapCallback(callback: (...any?) -> ())
	if RunContext == "Server" then
		return function(...)
			local player = ...
			callback(player, self:_deserialize(select(2, ...)))
		end
	else
		return function(...)
			callback(self:_deserialize(...))
		end
	end
end

function Nayt:Connect(callback: (...any?) -> ())
	return Net[RunContext].Connect(self.portId, self:_wrapCallback(callback))
end

function Nayt:Once(callback: (...any?) -> ())
	return Net[RunContext].Once(self.portId, self:_wrapCallback(callback))
end

function Nayt:Wait(): ...any?
	return Net[RunContext].Wait(self.portId)
end

function Nayt:HandleRequest(callback: (...any?) -> ...any?)
	if RunContext == "Server" then
		return Net.Server.HandleRequest(self.portId, function(...: any?): ...any?
			local player = ...
			return callback(player, self:_deserialize(select(2, ...)))
		end)
	else
		return Net.Client.HandleRequest(self.portId, function(...: any?): ...any?
			return callback(self:_deserialize(...))
		end)
	end
end

function Nayt:Request(...): ...any?
	if RunContext == "Server" then
		local player = ...
		assert(typeof(player) == "Instance" and player:IsA("Player"), `[{self.portId}]: Player was not specified`)

		return Net.Server.Request(player :: Player, self.portId, nil, self:_serialize(player, ...))
	else
		return Net.Client.Request(self.portId, nil, self:_serialize(nil, ...))
	end
end

Players.PlayerRemoving:Connect(function(player: Player)
	if RunContext == "Client" then
		return
	end

	for _, naytPort in NaytPorts do
		if naytPort.updatedPlayers[player] then
			naytPort.updatedPlayers[player] = nil
		end
	end
end)

function Nayt.new(portId: string, schema: { Bardo.BardoType }?, config: { Secure: boolean? }?)
	local argsType = {}

	if schema then
		for i, v in schema do
			argsType[i] = v.type()
		end
	end

	local self = setmetatable({
		portId = portId,
		secure = if config then config.Secure ~= false else false,
		fixedSchema = schema or nil,
		schema = schema or {},
		argsType = argsType,
		updatedPlayers = if RunContext == "Server" and not schema then {} else nil,
	}, Nayt)

	NaytPorts[portId] = self

	return self
end

return Nayt
