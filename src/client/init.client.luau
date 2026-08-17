local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Nayt = require(ReplicatedStorage.Shared.Nayt)

local port = Nayt.new("port")

port:Connect(function(...)
	--print(...)
	--for i, data in { ... } do
	--	print("-----------")
	--	print("data:", data)
	--	print("data type: ", typeof(data))
	--end
end)
