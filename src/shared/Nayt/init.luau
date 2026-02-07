--!optimize 2

--By: @_ayoon (@AyooN2)
local EncodingService = game:GetService("EncodingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--TODO: use encoding service
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

function Nayt:_serialize(...): (buffer?, boolean?)
	if self.schema then
		---... is expected to be a valid table respecting the schema
		local buff = Sera.Serialize(self.schema, ...)
		local encoded = EncodingService:CompressBuffer(buff, Enum.CompressionAlgorithm.Zstd, 9)
		if buffer.len(encoded) < buffer.len(buff) then
			return encoded, true
		else
			return buff, false
		end
	else
		return ...
	end
end

function Nayt:_deserialize(...): { [string]: any } | any?
	if self.schema then
		--if schema exists, then '...' is a buffer
		local buff: buffer, isEncoded: boolean = ...
		if isEncoded then
			buff = EncodingService:DecompressBuffer(buff, Enum.CompressionAlgorithm.Zstd)
		end

		local des = Sera.Deserialize(self.schema, buff)
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
		local serializedData = self:_serialize(select(2, ...))

		return Net.Server.Request(player :: Player, self.portId, nil, serializedData)
	else
		return Net.Client.Request(self.portId, nil, self:_serialize(...))
	end
end

return Nayt
