local EncodingService = game:GetService("EncodingService")
local Bardo = {}

export type BardoType = {
	size: number,
	sanctify: (b: buffer, offset: number, value: any) -> number,
	reborn: (b: buffer, offset: number) -> (any, number),
}
export type Schema = { BardoType } & { size: number }

local U8_SIZE = 255
local I8_MIN = -128
local I8_MAX = 127

local U16_SIZE = 65_535
local I16_MIN = -32_768
local I16_MAX = 32_767

local U32_SIZE = 4_294_967_295
local I32_MIN = -2_147_483_648
local I32_MAX = 2_147_483_647

local function inRange(n: number, min: number, max: number): boolean
	return min <= n and n <= max
end

--sanctify, hallow, enshrine

Bardo.uint8 = {
	size = 1,
	sanctify = function(b: buffer, offset: number, value: number): number
		assert(value < U8_SIZE, `Expected number smaller than {U8_SIZE}, got {value}`)
		buffer.writeu8(b, offset, value)
		return offset + 1
	end,
	reborn = function(b: buffer, offset: number): (number, number)
		return buffer.readu8(b, offset), offset + 1
	end,
}

Bardo.int8 = {
	size = 1,
	sanctify = function(b: buffer, offset: number, value: number): number
		assert(inRange(value, I8_MIN, I8_MAX), `Expected to number to be in range ({I8_MIN} < {value} < {I8_MAX})`)
		buffer.writei8(b, offset, value)
		return offset + 1
	end,
	reborn = function(b: buffer, offset: number): (number, number)
		return buffer.readi8(b, offset), offset + 1
	end,
}

Bardo.uint16 = {
	size = 2,
	sanctify = function(b: buffer, offset: number, value: number): number
		assert(value < U16_SIZE, `Expected number smaller than {U16_SIZE}, got {value}`)
		buffer.writeu16(b, offset, value)
		return offset + 2
	end,
	reborn = function(b: buffer, offset: number): (number, number)
		return buffer.readu16(b, offset), offset + 2
	end,
}

Bardo.int16 = {
	size = 2,
	sanctify = function(b: buffer, offset: number, value: number): number
		assert(inRange(value, I16_MIN, I16_MAX), `Expected to number to be in range ({I16_MIN} < {value} < {I16_MAX})`)
		buffer.writei16(b, offset, value)
		return offset + 2
	end,

	reborn = function(b: buffer, offset: number): (number, number)
		return buffer.readi16(b, offset), offset + 2
	end,
}

Bardo.uint32 = {
	size = 4,
	sanctify = function(b: buffer, offset: number, value: number): number
		assert(value < U32_SIZE, `Expected number smaller than {U32_SIZE}, got {value}`)
		buffer.writeu32(b, offset, value)
		return offset + 4
	end,
	reborn = function(b: buffer, offset: number): (number, number)
		return buffer.readu32(b, offset), offset + 4
	end,
}

Bardo.int32 = {
	size = 4,
	sanctify = function(b: buffer, offset: number, value: number): number
		assert(inRange(value, I32_MIN, I32_MAX), `Expected to number to be in range ({I32_MIN} < {value} < {I32_MAX})`)
		buffer.writei32(b, offset, value)
		return offset + 4
	end,

	reborn = function(b: buffer, offset: number): (number, number)
		return buffer.readi32(b, offset), offset + 4
	end,
}

Bardo.float32 = {
	size = 4,
	sanctify = function(b: buffer, offset: number, value: number): number
		buffer.writef32(b, offset, value)
		return offset + 4
	end,
	reborn = function(b: buffer, offset: number): (number, number)
		return buffer.readf32(b, offset), offset + 4
	end,
}

Bardo.float64 = {
	size = 8,
	sanctify = function(b: buffer, offset: number, value: number): number
		buffer.writef64(b, offset, value)
		return offset + 8
	end,

	reborn = function(b: buffer, offset: number): (number, number)
		return buffer.readf64(b, offset), offset + 8
	end,
}

--Heavy
Bardo.LosslessCFrame = {
	size = 48,
	sanctify = function(b: buffer, offset: number, value: CFrame): number
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
		buffer.writef32(b, offset, x)
		buffer.writef32(b, offset + 4, y)
		buffer.writef32(b, offset + 8, z)
		buffer.writef32(b, offset + 12, r00)
		buffer.writef32(b, offset + 16, r01)
		buffer.writef32(b, offset + 20, r02)
		buffer.writef32(b, offset + 24, r10)
		buffer.writef32(b, offset + 28, r11)
		buffer.writef32(b, offset + 32, r12)
		buffer.writef32(b, offset + 36, r20)
		buffer.writef32(b, offset + 40, r21)
		buffer.writef32(b, offset + 44, r22)
		return offset + 48
	end,
	reborn = function(b: buffer, offset: number): (CFrame, number)
		return CFrame.new(
			buffer.readf32(b, offset),
			buffer.readf32(b, offset + 4),
			buffer.readf32(b, offset + 8),
			buffer.readf32(b, offset + 12),
			buffer.readf32(b, offset + 16),
			buffer.readf32(b, offset + 20),
			buffer.readf32(b, offset + 24),
			buffer.readf32(b, offset + 28),
			buffer.readf32(b, offset + 32),
			buffer.readf32(b, offset + 36),
			buffer.readf32(b, offset + 40),
			buffer.readf32(b, offset + 44)
		),
			offset + 48
	end,
}

Bardo.CFrame = {
	size = 24,
	sanctify = function(b: buffer, offset: number, value: CFrame): number
		local pos = value.Position
		local x, y, z = value:ToOrientation()
		buffer.writef32(b, offset, pos.X)
		buffer.writef32(b, offset + 4, pos.Y)
		buffer.writef32(b, offset + 8, pos.Z)
		buffer.writef32(b, offset + 12, x)
		buffer.writef32(b, offset + 16, y)
		buffer.writef32(b, offset + 20, z)
		return offset + 24
	end,

	reborn = function(b: buffer, offset: number): (CFrame, number)
		return CFrame.new(buffer.readf32(b, offset), buffer.readf32(b, offset + 4), buffer.readf32(b, offset + 8))
			* CFrame.fromOrientation(
				buffer.readf32(b, offset + 12),
				buffer.readf32(b, offset + 16),
				buffer.readf32(b, offset + 20)
			),
			offset + 24
	end,
}

Bardo.Color3 = {
	size = 3,
	sanctify = function(b: buffer, offset: number, value: Color3): number
		buffer.writeu8(b, offset, value.R * 255)
		buffer.writeu8(b, offset + 1, value.G * 255)
		buffer.writeu8(b, offset + 2, value.B * 255)

		return offset + 3
	end,
	reborn = function(b: buffer, offset: number): (Color3, number)
		return Color3.fromRGB(buffer.readu8(b, offset), buffer.readu8(b, offset + 1), buffer.readu8(b, offset + 2)),
			offset + 3
	end,
}

Bardo.string8 = {
	size = 1, --Depends on the string lengths
	sanctify = function(b: buffer, offset: number, value: string): number
		local len = value:len()
		assert(
			len < U8_SIZE,
			`Expected string size to be under {U8_SIZE}, got {len}. Please check for utf8 characters that takes more space than 1 byte`
		)
		buffer.writeu8(b, offset, len)
		buffer.writestring(b, offset + 1, value)
		return offset + 1 + len
	end,

	reborn = function(b: buffer, offset: number): (string, number)
		local len = buffer.readu8(b, offset)
		return buffer.readstring(b, offset + 1, len), offset + 1 + len
	end,
}

Bardo.string16 = {
	size = 2, --Depends on the string lengths
	sanctify = function(b: buffer, offset: number, value: string): number
		local len = value:len()
		assert(
			len < U16_SIZE,
			`Expected string size to be under {U16_SIZE}, got {len}. Please check for utf8 characters that takes more space than 1 byte`
		)
		buffer.writeu16(b, offset, len)
		buffer.writestring(b, offset + 2, value)
		return offset + 2 + len
	end,

	reborn = function(b: buffer, offset: number): (string, number)
		local len = buffer.readu16(b, offset)
		return buffer.readstring(b, offset + 2, len), offset + 2 + len
	end,
}

Bardo.Vector3 = {
	size = 12,
	sanctify = function(b: buffer, offset: number, value: Vector3): number
		buffer.writef32(b, offset, value.X)
		buffer.writef32(b, offset + 4, value.Y)
		buffer.writef32(b, offset + 8, value.Z)
		return offset + 12
	end,

	reborn = function(b: buffer, offset: number): (Vector3, number)
		return Vector3.new(buffer.readf32(b, offset), buffer.readf32(b, offset + 4), buffer.readf32(b, offset + 8)),
			offset + 12
	end,
}

Bardo.Vector2 = {
	size = 8,
	sanctify = function(b: buffer, offset: number, value: Vector2): number
		buffer.writef32(b, offset, value.X)
		buffer.writef32(b, offset + 4, value.Y)
		return offset + 8
	end,

	reborn = function(b: buffer, offset: number): (Vector2, number)
		return Vector2.new(buffer.readf32(b, offset), buffer.readf32(b, offset + 4)), offset + 8
	end,
}

Bardo.Boolean = {
	size = 1,
	sanctify = function(b: buffer, offset: number, value: boolean): number
		buffer.writeu8(b, offset, value and 0xFF or 0x00)
		return offset + 1
	end,

	reborn = function(b: buffer, offset: number): (boolean, number)
		return buffer.readu8(b, offset) == 0xFF and true or false, offset + 1
	end,
}

Bardo.Unserializable = {
	size = 0,
}

--ugly but necessary for O(1)
local _typePairs: { { number | BardoType } } = {
	{ 1, Bardo.uint8 },
	{ 2, Bardo.int8 },
	{ 3, Bardo.uint16 },
	{ 4, Bardo.int16 },
	{ 5, Bardo.uint32 },
	{ 6, Bardo.int32 },
	{ 7, Bardo.float32 },
	{ 8, Bardo.float64 },
	{ 9, Bardo.LosslessCFrame },
	{ 10, Bardo.CFrame },
	{ 11, Bardo.Color3 },
	{ 12, Bardo.string8 },
	{ 13, Bardo.string16 },
	{ 14, Bardo.Vector3 },
	{ 15, Bardo.Vector2 },
	{ 16, Bardo.Boolean },
	{ 17, Bardo.Unserializable },
}

local _typeMap = {}
for _, pair in ipairs(_typePairs) do
	local id, Type = pair[1], pair[2]
	_typeMap[id] = Type
	_typeMap[Type] = id
end

Bardo.Auto = function(value: any): BardoType
	local t = typeof(value)

	if t == "number" then
		if value % 1 == 0 then
			if inRange(value, I8_MIN, I8_MAX) then
				return Bardo.int8
			end
			if value >= 0 and value <= U8_SIZE then
				return Bardo.uint8
			end
			if inRange(value, I16_MIN, I16_MAX) then
				return Bardo.int16
			end
			if value >= 0 and value <= U16_SIZE then
				return Bardo.uint16
			end
			if inRange(value, I32_MIN, I32_MAX) then
				return Bardo.int32
			end
			if value >= 0 and value <= U32_SIZE then
				return Bardo.uint32
			end
			return Bardo.float64
		else
			-- Non-integer numbers -> use float32 by default
			return Bardo.float32
		end
	elseif t == "string" then
		if #value < U8_SIZE then
			return Bardo.string8
		elseif #value < U16_SIZE then
			return Bardo.string16
		end
	elseif t == "CFrame" then
		return Bardo.CFrame
	elseif t == "Color3" then
		return Bardo.Color3
	elseif t == "Vector3" then
		return Bardo.Vector3
	elseif t == "Vector2" then
		return Bardo.Vector2
	elseif t == "boolean" then
		return Bardo.Boolean
	elseif t == "table" then
		-- If a descriptor-like table is passed, return it directly
		if value.size and value.sanctify and value.reborn then
			return value
		end
	end

	return Bardo.Unserializable
end

Bardo.GetSize = function(value: any, bardoType: BardoType): number
	if bardoType == Bardo.string8 or bardoType == Bardo.string16 then
		return bardoType.size + value:len()
	else
		return bardoType.size
	end
end
Bardo.AutoSize = function(value: any): number
	local bardoType = Bardo.Auto(value)
	return Bardo.GetSize(value, bardoType)
end

Bardo.sanctifySchema = function(bardoTypes: Schema): buffer
	local b = buffer.create(#bardoTypes)
	for index, Type in ipairs(bardoTypes) do
		buffer.writeu8(b, index - 1, _typeMap[Type])
	end
	return b
end

Bardo.rebornSchema = function(b: buffer): Schema
	local bardoTypes = {}
	bardoTypes.size = 0
	for index = 1, buffer.len(b) do
		bardoTypes.size += _typeMap[buffer.readu8(b, index - 1)].size
		bardoTypes[index] = _typeMap[buffer.readu8(b, index - 1)]
	end
	return bardoTypes
end

Bardo.AutoSchema = function(...): Schema
	local r = {}
	r.size = 0
	for _, v in { ... } do
		local bardoType = Bardo.Auto(v)
		r.size += Bardo.GetSize(v, bardoType)
		table.insert(r, bardoType)
	end
	return r
end

Bardo.sanctify = function(schema: Schema, ...): (buffer?, { any? }?)
	local args = { ... }
	local size = 0
	if not schema.size then
		for index, bardoType in ipairs(schema) do
			size += Bardo.GetSize(args[index], bardoType)
		end
	else
		size = schema.size
	end

	if size == 0 then
		warn(`[{script.Name}]: could not sanctify anything.`)
		return ...
	end

	local b = buffer.create(size)
	local offset = 0
	local unserializable = {}
	for i, arg in args do
		if schema[i] == Bardo.Unserializable then
			table.insert(unserializable, arg)
		else
			offset = schema[i].sanctify(b, offset, arg)
		end
	end

	local encodedb = EncodingService:CompressBuffer(b, Enum.CompressionAlgorithm.Zstd, 9)
	local useEncoded = buffer.len(encodedb) < buffer.len(b)
	local flag: number

	if useEncoded then
		b = encodedb
		flag = 0xFF
	else
		b = b
		flag = 0x00
	end

	local result = buffer.create(buffer.len(b) + 1)

	--overhead of 1 byte (tells if the buffer is encoded or not)
	buffer.writeu8(result, 0, flag)
	buffer.copy(result, 1, b)

	return result, #unserializable > 0 and unserializable or nil
end

Bardo.reborn = function(schema: Schema, b: buffer, ...): ...any
	if schema.size == 0 or typeof(b) ~= "buffer" then
		warn(`[{script.Name}]: Could not reborn buffer, schema size is zero and no buffer is specified`)
		return b, ...
	end
	local encodedFlag = buffer.readu8(b, 0)
	local raw = buffer.create(buffer.len(b) - 1)
	local unserializedArgs = { ... }
	buffer.copy(raw, 0, b, 1)

	if encodedFlag == 0xFF then
		b = EncodingService:DecompressBuffer(raw, Enum.CompressionAlgorithm.Zstd)
	elseif encodedFlag == 0x00 then
		b = raw
	end

	local ret = table.create(#schema)
	local offset = 0
	local tCount = 1
	local data

	for index, serialized in ipairs(schema) do
		if serialized == Bardo.Unserializable then
			data = unserializedArgs[tCount]
			tCount += 1
		else
			data, offset = serialized.reborn(b, offset)
		end
		ret[index] = data
	end
	return unpack(ret)
end

return Bardo
