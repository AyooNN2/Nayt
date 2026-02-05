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
local rem = Nayt.new("rem", schema)

local dataToSend = {
	["1"] = "HELLO",
	["2"] = -541,
	["3"] = os.time(),
	["4"] = Vector3.one,
}

test:Connect(function(Player: Player, ...: any?)
	print("data received from", Player)
	print("data:", ...)
end)

task.wait(2)
rem:SendUnsafeAll(dataToSend)
