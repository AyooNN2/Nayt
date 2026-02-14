local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Nayt = require(ReplicatedStorage.Shared.Nayt)
local Bardo = require(ReplicatedStorage.Shared.Nayt.Bardo)

local data = {
	"a",
	CFrame.Angles(math.random(5), math.random(360), math.rad(814)),
	139,
	-98514251,
	15.48478,
	Color3.new(0.733333, 0.313725, 0.313725),
}

local port = Nayt.new("bardoPort", Bardo.AutoSchema(unpack(data)), true)

local datarand = {
	"aaaaaaa",
	CFrame.Angles(math.random(15), math.random(360), math.rad(85)),
	"fsdpogjkzrà)",
	Color3.fromRGB(51, 40, 148),
	156,
	-2,
	984.548789,
	42949672951,
}

local testport = Nayt.new("ClientPort", { Bardo.Unserializable }, true)
UserInputService.InputBegan:Connect(function(a0: InputObject, a1: boolean)
	if a1 then
		return
	end

	if a0.KeyCode == Enum.KeyCode.E then
		testport:Send(true, false, 48949)
	end
end)

port:Connect(function(...)
	print(...)
	--for i, data in { ... } do
	--	print("-----------")
	--	print("data:", data)
	--	print("data type: ", typeof(data))
	--end
end)
