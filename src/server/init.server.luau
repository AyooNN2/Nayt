local CreatorStoreService = game:GetService("CreatorStoreService")
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
	Enum.AssetType.Decal,
	CFrame.identity,
	Vector3.one,
	buffer.create(32),
}

local port = Nayt.new("port", true, false, { Bardo.CFrame })

port:Connect(function(player: Player, ...)
	print("client, ", player.Name, "sent: ", ...)
end)

while task.wait(1) do
	port:SendAll(CFrame.Angles(6, 84, 65))
end
