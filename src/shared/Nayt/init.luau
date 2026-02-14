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
	new: (portId: string, Schema: { Bardo.BardoType }?, AutoUpdate: boolean?) -> NaytPort<...any?>,
}

local Nayt = {} :: Nayt
local NaytPorts: { [string]: NaytPort<...any?> } = {}

Nayt.__index = Nayt

--WARNING: Not recommended to use AutoUpdate when sending strings with varying length
function Nayt.new(portId: string, Schema: { Bardo.BardoType }?, AutoUpdate: boolean?)
	local self = setmetatable({
		portId = portId,
		autoUpdate = AutoUpdate or true,
		schema = Schema,
		updatedPlayers = {},
	}, Nayt)

	NaytPorts[portId] = self

	return self
end

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

function Nayt:_serialize(player: Player?, ...): (buffer?, { any? }?)
	if not self.schema then
		return ...
	end

	local newSchema = Bardo.AutoSchema(...)
	local schemaChanged: boolean = not equal(newSchema, self.schema)

	if schemaChanged then
		if RunContext == "Server" then
			if self.autoUpdate then
				self.schema = newSchema
				self.updatedPlayers = {}
				self.updatedPlayers[player] = true
			end
		else
			error(`Incorrect schema for port '{self.portId}', will not send to server.`)
		end
	end

	local result = { Bardo.sanctify(self.schema, ...) }

	--Possible if none of the passed args are serializable
	if typeof(result[1]) ~= "buffer" then
		if schemaChanged or not self.updatedPlayers[player] and RunContext == "Server" then
			table.insert(result, Bardo.sanctifySchema(self.schema))
			self.updatedPlayers[player] = true
		end

		return unpack(result)
	end

	local unserializedValues = table.remove(result, 2) :: { any }

	if unserializedValues then --table of unserializable values,
		for _, v in ipairs(unserializedValues) do
			table.insert(result, v)
		end
	end

	if schemaChanged or not self.updatedPlayers[player] and RunContext == "Server" then
		table.insert(result, Bardo.sanctifySchema(self.schema))
		self.updatedPlayers[player] = true
	end

	return unpack(result)
end

function Nayt:_deserialize(...): { [string]: any } | any?
	if not self.schema then
		return ...
	end

	--if schema exists, then '...' is a buffer
	local args = { ... }
	local buff = table.remove(args, 1) :: buffer
	local newSchema: buffer? = table.remove(args, #args)
	local schema: Bardo.Schema = self.schema

	print("possible buffer: ", newSchema)
	if newSchema and typeof(newSchema) == "buffer" then
		if RunContext == "Server" then
			error(`Player tried to change server's schema.`)
		else
			schema = Bardo.rebornSchema(newSchema)
			self.schema = schema
			return Bardo.reborn(schema, buff, unpack(args))
		end
	end

	return Bardo.reborn(schema, buff, select(2, ...))
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

return Nayt
