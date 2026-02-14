local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nayt = require(ReplicatedStorage.Shared.Nayt)
local Bardo = require(ReplicatedStorage.Shared.Nayt.Bardo)

local datarand = {
	156,
	-2,
	64305,
	-31097,
	4_294_967_292,
	1_147_483_643,
	9121560.02589978,
	CFrame.new(math.random(360), math.random(360), math.random(360))
		* CFrame.Angles(math.random(360), math.random(360), math.random(360)),
	Color3.new(math.random(), math.random(), math.random()),
	"ouaiiisdfqsàdfuqsdfjoqsdfhojqsdfhjoqfsdhjhqsdfkqsdfqmsldfjh",
	Vector3.new(math.random(1000), math.random(1000), math.random(1000)),
	Vector2.new(math.random(1000), math.random(1000)),
	true,
	false,
	workspace,
	ReplicatedStorage,
}

local port = Nayt.new("bardoPort", { Bardo.Unserializable }, true)
local testport = Nayt.new("ClientPort", { Bardo.Unserializable }, true)

testport:Connect(function(Player: Player, ...)
	print("got data from: ", Player.Name)
	print("data: ", ...)
end)

while task.wait(10) do
	port:SendAll(
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)],
		datarand[math.random(#datarand)]
	)
end
