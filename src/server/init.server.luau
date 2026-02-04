local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nayt = require(ReplicatedStorage.Shared.Nayt)
local Sera = require(ReplicatedStorage.Shared.Nayt.Sera)

local schema = Sera.Schema({
	["1"] = Sera.String8,
	["2"] = Sera.Int16,
	["3"] = Sera.Uint32,
	["4"] = Sera.Vector3,
})

local test = Nayt.new("testPort", schema)

local dataToSend = {
	["1"] = "HELLO",
	["2"] = -541,
	["3"] = 614900000,
	["4"] = Vector3.one,
}

Players.PlayerAdded:Connect(function(a0: Player)
	task.wait(7)
	local data = { test:Request(a0, dataToSend) }
	print("GOT dATA: ", data)
end)

--[[
rem:Connect(function(Player: Player, ...: any?)
	print("received from player ", Player)
	print("deserialized data:", ...)

	while task.wait(2) do
		rem:SendUnsafeAll(dataToSend)
	end
end)
]]
