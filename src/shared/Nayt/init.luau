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
	new: (portId: string, Secure: boolean?, AutoUpdate: boolean?, schema: { Bardo.BardoType }?) -> NaytPort<...any?>,
}

local Nayt = {} :: Nayt
local NaytPorts: { [string]: NaytPort<...any?> } = {}

Nayt.__index = Nayt

local function getn(t: { [any?]: any? }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function equal(t1: { [any]: any }, t2: { [any]: any }): boolean
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

local function getArgsType(...): { string }
	local t = { ... }
	for i, var in t do
		t[i] = typeof(var)
	end
	return t
end

function Nayt:_serialize(player: Player?, ...): (buffer?, { any? }?)
	local argsType = getArgsType(...)
	local isServer = RunContext == "Server"
	local argsTypeChanged = not equal(self.argsType, argsType)
	local schemaUpdated = false
	local newSchema = Bardo.autoSchema(...)

	if #self.argsType == 0 then
		local shouldInit = (isServer and self.autoUpdate) or (not isServer and not self.autoUpdate)
		if shouldInit then
			self.schema = newSchema
			schemaUpdated = true
		end
		self.argsType = argsType
	elseif argsTypeChanged then
		if self.autoUpdate then
			if isServer and self.secure then
				self.schema = newSchema
				self.argsType = argsType
				self.updatedPlayers = {}
				self.updatedPlayers[player] = true
				schemaUpdated = true
			elseif not isServer and self.secure then
				if self.secure then
					error(`Incorrect arguments for port '{self.portId}', will not send to server.`)
				end
				self.schema = newSchema
				self.argsType = argsType
				schemaUpdated = true
			end
		else
			self.schema = newSchema
			self.argsType = argsType
			schemaUpdated = true
		end
	else
		local schemaDiffers = not equal(self.schema, newSchema)

		if schemaDiffers then
			if self.autoUpdate and isServer then
				self.schema = newSchema
				self.updatedPlayers = {}
				self.updatedPlayers[player] = true
				schemaUpdated = true
			elseif not self.autoUpdate and not isServer then
				self.schema = newSchema
				self.argsType = argsType
			elseif not isServer and self.secure then
				for i, newType in newSchema do
					--Combining 2 if statements to reduce end-staircase
					if (i ~= "size" and self.schema[i]) and (self.autoUpdate and not isServer) then
						assert(
							Bardo.tryConvertType(self.schema[i], newType, select(i, ...)),
							`Schema mismatch for port '{self.portId}': argument {i} requires {Bardo.getTypeName(
								self.schema[i]
							)} but detected {Bardo.getTypeName(newType)}. Value could not fit in the current schema`
						)
					end
				end
			end
		end
	end

	local result = { Bardo.sanctify(self.schema, ...) }

	local shouldSendSchema = false
	if isServer then
		shouldSendSchema = schemaUpdated or not self.updatedPlayers[player]
		if shouldSendSchema then
			self.updatedPlayers[player] = true
		end
	else
		shouldSendSchema = not self.autoUpdate
	end

	if typeof(result[1]) ~= "buffer" then
		if shouldSendSchema then
			table.insert(result, Bardo.sanctifySchema(self.schema))
		end
		return unpack(result)
	end

	local unserializedValues = table.remove(result, 2) :: { any }
	if unserializedValues then
		for _, value in unserializedValues do
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

	local newSchema = table.remove(args, #args) :: buffer
	local isClient = RunContext == "Client"

	if not isClient and self.autoUpdate then
		error(`Player tried to change server's schema.`)
	end

	if isClient and self.autoUpdate then
		local schema = Bardo.rebornSchema(newSchema)
		self.schema = schema
		self.argsType = {}

		for i, bardoType in schema do
			if i ~= "size" then
				table.insert(self.argsType, Bardo.getLuaType(bardoType))
			end
		end

		return Bardo.reborn(schema, buff, unpack(args))
	end

	local schema = Bardo.rebornSchema(newSchema)
	return Bardo.reborn(schema, buff, unpack(args))
end

function Nayt:_send(player: Player?, safe: boolean, ...: any?): ()
	if RunContext == "Server" then
		assert(player ~= nil, `[{self.portId}]: Player was not specified`)
		if safe then
			Net.Server.SendAsync(player :: Player, self.portId, self:_serialize(player, ...))
		else
			Net.Server.SendUnsafeAsync(player :: Player, self.portId, self:_serialize(player, ...))
		end
	else
		if safe then
			Net.Client.SendAsync(self.portId, self:_serialize(nil, ...))
		else
			Net.Client.SendUnsafeAsync(self.portId, self:_serialize(nil, ...))
		end
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
	for _, naytPort in NaytPorts do
		if naytPort.updatedPlayers[player] then
			naytPort.updatedPlayers[player] = nil
		end
	end
end)

function Nayt.new(portId: string, Secure: boolean?, AutoUpdate: boolean?, schema: { Bardo.BardoType }?)
	local argsType = {}

	if schema then
		for i, v in schema do
			argsType[i] = Bardo.getLuaType(v)
		end
	end

	local self = setmetatable({
		portId = portId,
		autoUpdate = AutoUpdate ~= false,
		secure = Secure ~= false,
		schema = schema or {},
		argsType = argsType,
		updatedPlayers = RunContext == "Server" and {} or nil,
	}, Nayt)

	NaytPorts[portId] = self

	return self
end

return Nayt
