--By: @_ayoon (@AyooN2)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Net = require(script.Parent.Net)
local Sera = require(script.Sera)

local RunContext: "Server" | "Client" = if RunService:IsServer() then "Server" else "Client"

local Nayt = {}
Nayt.__index = Nayt

function Nayt.new(portId: string, Schema: Sera.Schema?)
	return setmetatable({
		portId = portId,
		schema = Schema,
	}, Nayt)
end

function Nayt:_serialize(...): buffer | any?
	if self.schema then
		---... is expected to be a valid table respecting the schema
		return Sera.Serialize(self.schema, ...)
	else
		return ...
	end
end

function Nayt:_deserialize(...): { [string]: any } | any?
	if self.schema then
		local des = Sera.Deserialize(self.schema, ...)
		return des
	else
		return ...
	end
end
--TODO: check for schema validity
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
			--You don't wanna deserialize player instance
			local player = ...
			local deserializedData = self:_deserialize(select(2, ...))
			callback(player, deserializedData)
		end
	else
		return function(...)
			local deserializedData = self:_deserialize(...)
			callback(deserializedData)
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
			local deserializedData = self:_deserialize(select(2, ...))
			return callback(player, deserializedData)
		end)
	else
		return Net.Client.HandleRequest(self.portId, function(...: any?): ...any?
			local deserializedData = self:_deserialize(...)
			return callback(deserializedData)
		end)
	end
end

function Nayt:Request(...): ...any?
	if RunContext == "Server" then
		local player = ...
		assert(typeof(player) == "Instance" and player:IsA("Player"), `[{self.portId}]: Player was not specified`)
		local serializedData = self:_serialize(select(2, ...))

		return Net.Server.Request(player :: Player, self.portId, nil, serializedData)
	else
		return Net.Client.Request(self.portId, nil, self:_serialize(...))
	end
end

return Nayt
