local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
print("hey from server")

Net.Connect("portId", function(Player: Player, ...)
	print(`Player {Player.Name} fired portId`)
	print("params: ", ...)
end)

Net.Connect("something", function(Player: Player, ...)
	print(`received from player {Player.Name}.`)
	print("params: ", ...)
end)

Net.HandleRequest("some port", function(...: any?): ...any?
	return "random stuff"
end)

local a = Net.Request("player")
print("got info from client", a)
