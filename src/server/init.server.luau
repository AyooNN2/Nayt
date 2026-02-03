local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nayt = require(ReplicatedStorage.Shared.Nayt)
local Sera = require(ReplicatedStorage.Shared.Nayt.Sera)

local schema = Sera.Schema({
	["1"] = Sera.String8,
	["2"] = Sera.Int16,
	["3"] = Sera.Uint32,
	["4"] = Sera.Vector3,
})

local rem = Nayt.new("NaytPort", "Event", false, schema)

local dataToSend = {
	["1"] = "HELLO",
	["2"] = -541,
	["3"] = 614900000,
	["4"] = Vector3.one,
	["5"] = 3,
}

print("waiting data from client...")
local data = { rem:Wait() }
print("GOT dATA: ", data)

--[[
rem:Connect(function(Player: Player, ...: any?)
	print("received from player ", Player)
	print("deserialized data:", ...)

	while task.wait(2) do
		rem:SendUnsafeAll(dataToSend)
	end
end)
]]
