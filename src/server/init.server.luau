local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nayt = require(ReplicatedStorage.Shared.Nayt)
local Sera = require(ReplicatedStorage.Shared.Nayt.Sera)

local schema = Sera.Schema({
	["1"] = Sera.LossyCFrame,
	["2"] = Sera.LossyCFrame,
	["3"] = Sera.LossyCFrame,
	["4"] = Sera.LossyCFrame,
	["5"] = Sera.LossyCFrame,
})
local testSchema = Sera.Schema({
	["aaa"] = Sera.String8,
})

local test = Nayt.new("testPort", testSchema)
local rem = Nayt.new("rem", schema)

local dataToSend = {
	["1"] = CFrame.new(math.random(1000), math.random(1000), math.random(1000))
		* CFrame.Angles(math.random(1000), math.random(1000), math.random(1000)),
	["2"] = CFrame.new(math.random(1000), math.random(1000), math.random(1000))
		* CFrame.Angles(math.random(1000), math.random(1000), math.random(1000)),
	["3"] = CFrame.new(math.random(1000), math.random(1000), math.random(1000))
		* CFrame.Angles(math.random(1000), math.random(1000), math.random(1000)),
	["4"] = CFrame.new(math.random(1000), math.random(1000), math.random(1000))
		* CFrame.Angles(math.random(1000), math.random(1000), math.random(1000)),
	["5"] = CFrame.new(math.random(1000), math.random(1000), math.random(1000))
		* CFrame.Angles(math.random(1000), math.random(1000), math.random(1000)),
}

test:Connect(function(Player: Player, ...: any?)
	print("data received from", Player)
	print("data:", ...)
end)

task.wait(2)
print("will send data")

while task.wait(0.5) do
	rem:SendUnsafeAll(dataToSend)
end
