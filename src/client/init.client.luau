--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Nayt = require(ReplicatedStorage.Shared.Nayt)
local Sera = require(ReplicatedStorage.Shared.Nayt.Sera)

local schema = Sera.Schema({
	["1"] = Sera.String8,
	["2"] = Sera.Int8,
	["3"] = Sera.Uint32,
	["4"] = Sera.Vector3,
})

local test = Nayt.new("testPort", schema)

local dataToSend = {
	["1"] = Players.LocalPlayer.Name,
	["2"] = -Players.LocalPlayer.AccountAge,
	["3"] = Players.LocalPlayer.UserId,
	["4"] = Vector3.one,
}

test:HandleRequest(function(...: any?): ...any?
	print("got data from server: ", ...)
	return dataToSend
end)

UserInputService.InputBegan:Connect(function(inputObject: InputObject, gpe: boolean)
	if gpe then
		return
	end
	if inputObject.KeyCode == Enum.KeyCode.E then
		test:Send("PING")
	end
end)
