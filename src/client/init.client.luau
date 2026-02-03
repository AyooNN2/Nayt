local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
print("hey from client")

Net.HandleRequest("player", function(...: any?): ...any?
	print("got resqquest from server")
	return 5
end)

local info = Net.Request("some port", 0)
print("got info from server:", info)
