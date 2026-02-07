--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
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
	["1"] = Players.LocalPlayer.Name,
	["2"] = -Players.LocalPlayer.AccountAge,
	["3"] = Players.LocalPlayer.UserId,
	["4"] = Vector3.one,
}

UserInputService.InputBegan:Connect(function(inputObject: InputObject, gpe: boolean)
	if gpe then
		return
	end
	if inputObject.KeyCode == Enum.KeyCode.E then
		test:Send(
			{ ["aaa"] = "testing" } --[[{
			["1"] = "PING",
			["2"] = 12,
			["3"] = -49816,
			["4"] = Players.LocalPlayer.Character.HumanoidRootPart,
	}]]
		)
	end
end)

rem:Connect(function(...: any?)
	print("got data  (REM): ", ...)
end)
