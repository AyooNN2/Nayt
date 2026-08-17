local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nayt = require(ReplicatedStorage.Shared.Nayt)

local datarandom = {
	156,
	-2,
	64305,
	-31097,
	4_294_967_292,
	1_147_483_643,
	9121560.02589978,
	255,
	CFrame.new(math.random(360), math.random(360), math.random(360))
		* CFrame.Angles(math.random(360), math.random(360), math.random(360)),
	Color3.new(math.random(), math.random(), math.random()),
	"very big string AAAAAAAAAAAAAAAAAAAAAAAAaaa qdisfqsidufhiqsudfhgiqsdfvgbiuqsdfiuzhfieuhsdf",
	Vector3.new(math.random(1000), math.random(1000), math.random(1000)),
	Vector2.new(math.random(1000), math.random(1000)),
	true,
	false,
	workspace,
	CFrame.identity,
	Vector3.one,
	buffer.create(255),
	BrickColor.random(),
	UDim.new(math.random(), math.random(1, 1000)),
	UDim2.new(math.random(), math.random(1, 1000), math.random(), math.random(1, 1000)),
	{ 196, "element1", "element2", "aaa" },
}

local port = Nayt.new("port")
port:Connect(function(player: Player, ...)
	print("client, ", player.Name, "sent: ", ...)
end)

while task.wait() do
	local datatosend = table.create(1000)
	for i = 1, 1000 do
		table.insert(datatosend, datarandom[math.random(#datarandom)])
	end

	for i = 1, 10 do
		port:SendAll(unpack(datatosend))
	end
end
