--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Nayt = require(ReplicatedStorage.Shared.Nayt)
local Sera = require(ReplicatedStorage.Shared.Nayt.Sera)
local Net = require(ReplicatedStorage.Shared.Net)

local schema = Sera.Schema({
	["1"] = Sera.String8,
	["2"] = Sera.Int16,
	["3"] = Sera.Uint32,
	["4"] = Sera.Vector3,
})

local rem = Nayt.new("NaytPort", "Event", false, schema)

local dataToSend = {
	["1"] = "hey",
	["2"] = -584,
	["3"] = 1300000000,
	["4"] = Vector3.one,
}
UserInputService.InputBegan:Connect(function(inputObject: InputObject, gpe: boolean)
	if gpe then
		return
	end
	if inputObject.KeyCode == Enum.KeyCode.E then
		rem:Send(dataToSend)
	end
end)

rem:Connect(function(...: any?)
	print("got stuff from server: ")
	print(...)
end)
