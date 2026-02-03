--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Net = require(script.Parent.Net)
local Sera = require(script.Sera)

local RunContext: "Server" | "Client" = if RunService:IsServer() then "Server" else "Client"

--TODO: "Event"|"Function" and then type cast what .new() returns
export type RemoteType = "Event" | "Function"

local Nayt = {}
Nayt.__index = Nayt

function Nayt.new(portId: string, Type: RemoteType, isDataDynamic: boolean?, Schema: Sera.Schema?)
	return setmetatable({
		portId = portId,
		type = Type,
		isDynamic = isDataDynamic == nil and true,
		schema = Schema,
	}, Nayt)
end

function Nayt:_serialize(...): buffer | any?
	if self.isDynamic then
		return ...
	else
		---... is expected to be a valid table respecting the schema
		print(...)
		return Sera.Serialize(self.schema, ...)
	end
end

function Nayt:_deserialize(...): { [string]: any } | any?
	return nil
end

function Nayt:_send(player: Player?, safe: boolean, ...: any?): ()
	if RunContext == "Server" then
		assert(player ~= nil, `[{self.portId}]: Player was not specified`)
		if safe then
			Net.Server.SendAsync(player :: Player, self.portId, self:_serialize(...))
		else
			Net.Server.SendUnsafeAsync(player :: Player, self.portId, self:_serialize(...))
		end
	else
		if safe then
			Net.Client.SendAsync(self.portId, self:_serialize(...))
		else
			Net.Client.SendUnsafeAsync(self.portId, self:_serialize(...))
		end
	end
end

function Nayt:Send(...): ()
	if RunContext == "Server" then
		local args = { ... }
		local player = table.remove(args, 1)
		print(typeof(player) == "Instance" and player:IsA("Player"))
		assert(typeof(player) == "Instance" and player:IsA("Player"), `[{self.portId}]: Player was not specified`)
		self:_send(player, true, unpack(args))
	else
		self:_send(nil, true, ...)
	end
end

function Nayt:SendUnsafe(...): ()
	if RunContext == "Server" then
		local args = { ... }
		local player = table.remove(args, 1)
		assert(typeof(player) == "Instance" and player:IsA("Player"), `[{self.portId}]: Player was not specified`)
		self:_send(player, false, unpack(args))
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

function Nayt:Connect(callback: (...any?) -> ())
	if RunContext == "Server" then
		return Net.Server.Connect(self.portId, function(...)
			if self.isDynamic then
				callback(...)
			else
				local args = { ... }
				--You don't wanna deserialize Player instance
				local Player: Player = RunContext == "Server" and table.remove(args, 1)
				local DeserializedData = Sera.Deserialize(self.schema, args[1] :: buffer)
				callback(Player, DeserializedData)
			end
		end)
	else
		return Net.Client.Connect(self.portId, function(...)
			if self.isDynamic then
				callback(...)
			else
				local DeserializedData = Sera.Deserialize(self.schema, ... :: buffer)
				callback(DeserializedData)
			end
		end)
	end
end

return Nayt
