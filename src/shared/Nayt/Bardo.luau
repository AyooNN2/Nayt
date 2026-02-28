--!optimize 2

--By: @_ayoon (@AyooN2)
local EncodingService = game:GetService("EncodingService")
local Bardo = {}

export type BardoType = {
	size: number,
	sanctify: (b: buffer, offset: number, value: any) -> number,
	reborn: (b: buffer, offset: number) -> (any, number),
}
export type Schema = { BardoType } & { size: number }

local U8_MAX = 255
local I8_MIN = -128
local I8_MAX = 127

local U16_MAX = 65_535
local I16_MIN = -32_768
local I16_MAX = 32_767

local U24_MAX = 16_777_215
local I24_MIN = -8_388_608
local I24_MAX = 8_388_607

local U32_MAX = 4_294_967_295
local I32_MIN = -2_147_483_648
local I32_MAX = 2_147_483_647

local wi8 = buffer.writei8
local wu8 = buffer.writeu8
local wi16 = buffer.writei16
local wu16 = buffer.writeu16
local wi32 = buffer.writei32
local wu32 = buffer.writeu32
local wf32 = buffer.writef32
local wf64 = buffer.writef64

local ri8 = buffer.readi8
local ru8 = buffer.readu8
local ri16 = buffer.readi16
local ru16 = buffer.readu16
local ri32 = buffer.readi32
local ru32 = buffer.readu32
local rf32 = buffer.readf32
local rf64 = buffer.readf64

local function inRange(n: number, min: number, max: number): boolean
	return min <= n and n <= max
end

local function floatToI16(v: number): number
	v = math.clamp(v, -1, 1)
	return math.clamp(math.round(v * I16_MAX), I16_MIN, I16_MAX)
end

local function i16ToFloat(i: number): number
	return i / I16_MAX
end

local function CompressQuaternion(cf: CFrame): (number, number, number, number)
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()

	local trace = r00 + r11 + r22
	local qx, qy, qz, qw

	if trace > 0 then
		local s = math.sqrt(trace + 1) * 2
		qw = 0.25 * s
		qx = (r21 - r12) / s
		qy = (r02 - r20) / s
		qz = (r10 - r01) / s
	elseif r00 > r11 and r00 > r22 then
		local s = math.sqrt(1 + r00 - r11 - r22) * 2
		qw = (r21 - r12) / s
		qx = 0.25 * s
		qy = (r01 + r10) / s
		qz = (r02 + r20) / s
	elseif r11 > r22 then
		local s = math.sqrt(1 + r11 - r00 - r22) * 2
		qw = (r02 - r20) / s
		qx = (r01 + r10) / s
		qy = 0.25 * s
		qz = (r12 + r21) / s
	else
		local s = math.sqrt(1 + r22 - r00 - r11) * 2
		qw = (r10 - r01) / s
		qx = (r02 + r20) / s
		qy = (r12 + r21) / s
		qz = 0.25 * s
	end

	local components = { qx, qy, qz, qw }
	local minIdx = 1
	local minAbs = math.abs(qx)
	for i = 2, 4 do
		local absVal = math.abs(components[i])
		if absVal > minAbs then
			minAbs = absVal
			minIdx = i
		end
	end

	if components[minIdx] < 0 then
		qx, qy, qz, qw = -qx, -qy, -qz, -qw
		components = { qx, qy, qz, qw }
	end

	local result = {}
	for i = 1, 4 do
		if i ~= minIdx then
			result[#result + 1] = components[i]
		end
	end

	return minIdx - 1, result[1], result[2], result[3]
end

local function DecompressQuaternion(idx: number, a: number, b: number, c: number): CFrame
	local components = {}
	local values = { a, b, c }
	local valueIdx = 1

	for i = 1, 4 do
		if i - 1 == idx then
			components[i] = 0
		else
			components[i] = values[valueIdx]
			valueIdx += 1
		end
	end

	local sumSquares = 0
	for i = 1, 4 do
		if i - 1 ~= idx then
			sumSquares += components[i] * components[i]
		end
	end

	components[idx + 1] = math.sqrt(math.clamp(1 - sumSquares, 0, 1))

	local qx, qy, qz, qw = components[1], components[2], components[3], components[4]

	local xx, yy, zz = qx * qx, qy * qy, qz * qz
	local xy, xz, yz = qx * qy, qx * qz, qy * qz
	local wx, wy, wz = qw * qx, qw * qy, qw * qz

	local r00 = 1 - 2 * (yy + zz)
	local r01 = 2 * (xy - wz)
	local r02 = 2 * (xz + wy)

	local r10 = 2 * (xy + wz)
	local r11 = 1 - 2 * (xx + zz)
	local r12 = 2 * (yz - wx)

	local r20 = 2 * (xz - wy)
	local r21 = 2 * (yz + wx)
	local r22 = 1 - 2 * (xx + yy)

	return CFrame.new(0, 0, 0, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

Bardo.uint8 = {
	size = 1,

	sanctify = function(b: buffer, offset: number, value: number): number
		assert(value < U8_MAX, `Expected number smaller than {U8_MAX}, got {value}`)
		wu8(b, offset, value)
		return offset + 1
	end,

	reborn = function(b: buffer, offset: number): (number, number)
		return ru8(b, offset), offset + 1
	end,
}

Bardo.int8 = {
	size = 1,

	sanctify = function(b: buffer, offset: number, value: number): number
		assert(inRange(value, I8_MIN, I8_MAX), `Expected to number to be in range ({I8_MIN} < {value} < {I8_MAX})`)
		wi8(b, offset, value)
		return offset + 1
	end,

	reborn = function(b: buffer, offset: number): (number, number)
		return ri8(b, offset), offset + 1
	end,
}

Bardo.uint16 = {
	size = 2,

	sanctify = function(b: buffer, offset: number, value: number): number
		assert(value < U16_MAX, `Expected number smaller than {U16_MAX}, got {value}`)
		wu16(b, offset, value)
		return offset + 2
	end,

	reborn = function(b: buffer, offset: number): (number, number)
		return ru16(b, offset), offset + 2
	end,
}

Bardo.int16 = {
	size = 2,

	sanctify = function(b: buffer, offset: number, value: number): number
		assert(inRange(value, I16_MIN, I16_MAX), `Expected to number to be in range ({I16_MIN} < {value} < {I16_MAX})`)
		wi16(b, offset, value)
		return offset + 2
	end,

	reborn = function(b: buffer, offset: number): (number, number)
		return ri16(b, offset), offset + 2
	end,
}

Bardo.uint32 = {
	size = 4,

	sanctify = function(b: buffer, offset: number, value: number): number
		assert(value < U32_MAX, `Expected number smaller than {U32_MAX}, got {value}`)
		wu32(b, offset, value)
		return offset + 4
	end,

	reborn = function(b: buffer, offset: number): (number, number)
		return ru32(b, offset), offset + 4
	end,
}

Bardo.int32 = {
	size = 4,

	sanctify = function(b: buffer, offset: number, value: number): number
		assert(inRange(value, I32_MIN, I32_MAX), `Expected to number to be in range ({I32_MIN} < {value} < {I32_MAX})`)
		wi32(b, offset, value)
		return offset + 4
	end,

	reborn = function(b: buffer, offset: number): (number, number)
		return ri32(b, offset), offset + 4
	end,
}

Bardo.float32 = {
	size = 4,

	sanctify = function(b: buffer, offset: number, value: number): number
		wf32(b, offset, value)
		return offset + 4
	end,

	reborn = function(b: buffer, offset: number): (number, number)
		return rf32(b, offset), offset + 4
	end,
}

Bardo.float64 = {
	size = 8,

	sanctify = function(b: buffer, offset: number, value: number): number
		wf64(b, offset, value)
		return offset + 8
	end,

	reborn = function(b: buffer, offset: number): (number, number)
		return rf64(b, offset), offset + 8
	end,
}

Bardo.LosslessCFrame = {
	size = 25,

	sanctify = function(b: buffer, offset: number, value: CFrame): number
		wf32(b, offset, value.X)
		wf32(b, offset + 4, value.Y)
		wf32(b, offset + 8, value.Z)

		local idx, a, qb, c = CompressQuaternion(value)
		wu8(b, offset + 12, idx)
		wf32(b, offset + 13, a)
		wf32(b, offset + 17, qb)
		wf32(b, offset + 21, c)
		return offset + 25
	end,

	reborn = function(b: buffer, offset: number): (CFrame, number)
		local idx = ru8(b, offset + 12)
		local a = rf32(b, offset + 13)
		local qb = rf32(b, offset + 17)
		local c = rf32(b, offset + 21)
		local rotCF = DecompressQuaternion(idx, a, qb, c)
		return CFrame.new(rf32(b, offset), rf32(b, offset + 4), rf32(b, offset + 8)) * rotCF, offset + 25
	end,
}

Bardo.CFrame = {
	size = 19,

	sanctify = function(b: buffer, offset: number, value: CFrame): number
		wf32(b, offset, value.X)
		wf32(b, offset + 4, value.Y)
		wf32(b, offset + 8, value.Z)

		local idx, a, qb, c = CompressQuaternion(value)
		wu8(b, offset + 12, idx)
		wi16(b, offset + 13, floatToI16(a))
		wi16(b, offset + 15, floatToI16(qb))
		wi16(b, offset + 17, floatToI16(c))

		return offset + 19
	end,

	reborn = function(b: buffer, offset: number): (CFrame, number)
		local idx = ru8(b, offset + 12)
		local a, qb, c =
			i16ToFloat(ri16(b, offset + 13)), i16ToFloat(ri16(b, offset + 15)), i16ToFloat(ri16(b, offset + 17))
		local rotCF = DecompressQuaternion(idx, a, qb, c)

		return CFrame.new(rf32(b, offset), rf32(b, offset + 4), rf32(b, offset + 8)) * rotCF, offset + 19
	end,
}

Bardo.AxisAlignedCFrame = {
	size = 12,

	sanctify = function(b: buffer, offset: number, value: CFrame): number
		wf32(b, offset, value.X)
		wf32(b, offset + 4, value.Y)
		wf32(b, offset + 8, value.Z)
		return offset + 12
	end,

	reborn = function(b: buffer, offset: number): (CFrame, number)
		return CFrame.new(rf32(b, offset), rf32(b, offset + 4), rf32(b, offset + 8)), offset + 12
	end,
}

Bardo.Color3 = {
	size = 3,

	sanctify = function(b: buffer, offset: number, value: Color3): number
		wu8(b, offset, value.R * 255)
		wu8(b, offset + 1, value.G * 255)
		wu8(b, offset + 2, value.B * 255)

		return offset + 3
	end,

	reborn = function(b: buffer, offset: number): (Color3, number)
		return Color3.fromRGB(ru8(b, offset), ru8(b, offset + 1), ru8(b, offset + 2)), offset + 3
	end,
}

Bardo.string8 = {
	size = 1, --Depends on the string lengths

	sanctify = function(b: buffer, offset: number, value: string): number
		local len = value:len()
		assert(
			len < U8_MAX,
			`Expected string size to be under {U8_MAX}, got {len}. Please check for utf8 characters that takes more space than 1 byte`
		)
		wu8(b, offset, len)
		buffer.writestring(b, offset + 1, value)
		return offset + 1 + len
	end,

	reborn = function(b: buffer, offset: number): (string, number)
		local len = ru8(b, offset)
		return buffer.readstring(b, offset + 1, len), offset + 1 + len
	end,
}

Bardo.string16 = {
	size = 2, --Depends on the string lengths

	sanctify = function(b: buffer, offset: number, value: string): number
		local len = value:len()
		assert(
			len < U16_MAX,
			`Expected string size to be under {U16_MAX}, got {len}. Please check for utf8 characters that takes more space than 1 byte`
		)
		wu16(b, offset, len)
		buffer.writestring(b, offset + 2, value)
		return offset + 2 + len
	end,

	reborn = function(b: buffer, offset: number): (string, number)
		local len = ru16(b, offset)
		return buffer.readstring(b, offset + 2, len), offset + 2 + len
	end,
}

Bardo.Vector3 = {
	size = 12,

	sanctify = function(b: buffer, offset: number, value: Vector3): number
		wf32(b, offset, value.X)
		wf32(b, offset + 4, value.Y)
		wf32(b, offset + 8, value.Z)
		return offset + 12
	end,

	reborn = function(b: buffer, offset: number): (Vector3, number)
		return Vector3.new(rf32(b, offset), rf32(b, offset + 4), rf32(b, offset + 8)), offset + 12
	end,
}

Bardo.Vector2 = {
	size = 8,

	sanctify = function(b: buffer, offset: number, value: Vector2): number
		wf32(b, offset, value.X)
		wf32(b, offset + 4, value.Y)
		return offset + 8
	end,

	reborn = function(b: buffer, offset: number): (Vector2, number)
		return Vector2.new(rf32(b, offset), rf32(b, offset + 4)), offset + 8
	end,
}

Bardo.Boolean = {
	size = 1,

	sanctify = function(b: buffer, offset: number, value: boolean): number
		wu8(b, offset, value and 0xFF or 0x00)
		return offset + 1
	end,

	reborn = function(b: buffer, offset: number): (boolean, number)
		return ru8(b, offset) == 0xFF and true or false, offset + 1
	end,
}

Bardo.buffer8 = {
	size = 1,

	sanctify = function(b: buffer, offset: number, value: buffer): number
		local len = buffer.len(value)
		assert(len < U8_MAX, `Expected buffer size to be under {U8_MAX}, got {len}.`)

		wu8(b, offset, len)
		buffer.copy(b, offset + 1, value)
		return offset + 1 + len
	end,

	reborn = function(b: buffer, offset: number): (buffer, number)
		local len = ru8(b, offset)
		local value = buffer.create(len)
		buffer.copy(value, 0, b, offset + 1, len)
		return value, offset + 1 + len
	end,
}

Bardo.buffer16 = {
	size = 2,
	sanctify = function(b: buffer, offset: number, value: buffer): number
		local len = buffer.len(value)
		assert(len < U16_MAX, `Expected buffer size to be under {U16_MAX}, got {len}.`)

		wu16(b, offset, len)
		buffer.copy(b, offset + 2, value)
		return offset + 2 + len
	end,

	reborn = function(b: buffer, offset: number): (buffer, number)
		local len = ru16(b, offset)
		local value = buffer.create(len)
		buffer.copy(value, 0, b, offset + 2, len)
		return value, offset + 2 + len
	end,
}

Bardo.uint24 = {
	size = 3,

	sanctify = function(b: buffer, offset: number, value: number): number
		assert(value < U24_MAX, `Expected number smaller than {U24_MAX}, got {value}`)
		local ls16 = bit32.extract(value, 0, 16)
		local ms8 = bit32.extract(value, 16, 8)

		wu8(b, offset, ms8)
		wu16(b, offset + 1, ls16)
		return offset + 3
	end,

	reborn = function(b: buffer, offset: number): (number, number)
		local ms8 = ru8(b, offset)
		local ls16 = ru16(b, offset + 1)

		return bit32.lshift(ms8, 16) + ls16, offset + 3
	end,
}

Bardo.int24 = {
	size = 3,

	sanctify = function(b: buffer, offset: number, value: number): number
		assert(inRange(value, I24_MIN, I24_MAX), `Expected number in range ({I24_MIN} < {value} < {I24_MAX})`)

		local ls16 = bit32.extract(value, 0, 16)
		local ms8 = bit32.extract(value, 16, 8)

		wu8(b, offset, ms8)
		wu16(b, offset + 1, ls16)
		return offset + 3
	end,

	reborn = function(b: buffer, offset: number): (number, number)
		local ms8 = ru8(b, offset)
		local ls16 = ru16(b, offset + 1)
		local value = bit32.lshift(ms8, 16) + ls16

		if value > I24_MAX then
			value = value - U24_MAX - 1
		end

		return value, offset + 3
	end,
}

Bardo.Unserializable = {
	size = 0,
}

local TYPE_HIERARCHY = {
	uint = { Bardo.uint8, Bardo.uint16, Bardo.uint24, Bardo.uint32 },
	int = { Bardo.int8, Bardo.int16, Bardo.int24, Bardo.int32 },
	float = { Bardo.float32, Bardo.float64 },
	string = { Bardo.string8, Bardo.string16 },
	buffer = { Bardo.buffer8, Bardo.buffer16 },
	cframe = { Bardo.AxisAlignedCFrame, Bardo.CFrame, Bardo.LosslessCFrame },
}

--ugly but necessary for O(1)
local _TYPE_PAIRS: { { number | BardoType } } = {
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
	{ 17, Bardo.AxisAlignedCFrame },
	{ 18, Bardo.buffer8 },
	{ 19, Bardo.buffer16 },
	{ 20, Bardo.uint24 },
	{ 21, Bardo.int24 },
	{ 22, Bardo.Unserializable },
}

local _TYPE_MAP = {}
for _, pair in ipairs(_TYPE_PAIRS) do
	local id, Type = pair[1], pair[2]
	_TYPE_MAP[id] = Type
	_TYPE_MAP[Type] = id
end

_TYPE_PAIRS = nil

Bardo.auto = function(value: any): BardoType
	local t = typeof(value)

	if t == "number" then
		if value % 1 == 0 then
			if value >= 0 and value <= U8_MAX then
				return Bardo.uint8
			end
			if inRange(value, I8_MIN, I8_MAX) then
				return Bardo.int8
			end
			if value >= 0 and value <= U16_MAX then
				return Bardo.uint16
			end
			if inRange(value, I16_MIN, I16_MAX) then
				return Bardo.int16
			end
			if value >= 0 and value <= U24_MAX then
				return Bardo.uint24
			end
			if inRange(value, I24_MIN, I24_MAX) then
				return Bardo.int24
			end
			if value >= 0 and value <= U32_MAX then
				return Bardo.uint32
			end
			if inRange(value, I32_MIN, I32_MAX) then
				return Bardo.int32
			end

			return Bardo.float64
		else
			return Bardo.float32
		end
	elseif t == "string" then
		if #value < U8_MAX then
			return Bardo.string8
		elseif #value < U16_MAX then
			return Bardo.string16
		end
	elseif t == "CFrame" then
		local x, y, z = value:ToOrientation()
		if x == 0 and y == 0 and z == 0 then
			return Bardo.AxisAlignedCFrame
		else
			return Bardo.CFrame
		end
	elseif t == "buffer" then
		if buffer.len(value) < U8_MAX then
			return Bardo.buffer8
		elseif buffer.len(value) < U16_MAX then
			return Bardo.buffer16
		end
	elseif t == "Color3" then
		return Bardo.Color3
	elseif t == "Vector3" then
		return Bardo.Vector3
	elseif t == "Vector2" then
		return Bardo.Vector2
	elseif t == "boolean" then
		return Bardo.Boolean
	elseif t == "table" then
		if value.size and value.sanctify and value.reborn then
			return value
		end
	end

	return Bardo.Unserializable
end

Bardo.getLuaType = function(bardoType: BardoType)
	if
		bardoType == Bardo.int8
		or bardoType == Bardo.uint8
		or bardoType == Bardo.int16
		or bardoType == Bardo.uint16
		or bardoType == Bardo.int24
		or bardoType == Bardo.uint24
		or bardoType == Bardo.int32
		or bardoType == Bardo.uint32
		or bardoType == Bardo.float32
		or bardoType == Bardo.float64
	then
		return "number"
	elseif bardoType == Bardo.CFrame or bardoType == Bardo.LosslessCFrame or bardoType == Bardo.AxisAlignedCFrame then
		return "CFrame"
	elseif bardoType == Bardo.Color3 then
		return "Color3"
	elseif bardoType == Bardo.Vector3 then
		return "Vector3"
	elseif bardoType == Bardo.Vector2 then
		return "Vector2"
	elseif bardoType == Bardo.string8 or bardoType == Bardo.string16 then
		return "string"
	elseif bardoType == Bardo.Boolean then
		return "boolean"
	elseif bardoType == Bardo.buffer8 or bardoType == Bardo.buffer16 then
		return "buffer"
	elseif bardoType == Bardo.Unserializable then
		return "unserializable"
	end
	return
end

Bardo.getTypeInfo = function(bardoType: BardoType): (string?, number?)
	for family, types in TYPE_HIERARCHY do
		for i, t in types do
			if t == bardoType then
				return family, i
			end
		end
	end
	return nil, nil
end

Bardo.tryConvertType = function(targetType: BardoType, valueType: BardoType, value: any): BardoType?
	if targetType == valueType then
		return targetType
	end

	local function getIntRange(intType: BardoType): (number, number)
		if intType == Bardo.int8 then
			return I8_MIN, I8_MAX
		end
		if intType == Bardo.int16 then
			return I16_MIN, I16_MAX
		end
		if intType == Bardo.int24 then
			return I24_MIN, I24_MAX
		end
		if intType == Bardo.int32 then
			return I32_MIN, I32_MAX
		end
		return -math.huge, math.huge
	end

	local function getUintMax(uintType: BardoType): number
		if uintType == Bardo.uint8 then
			return U8_MAX
		end
		if uintType == Bardo.uint16 then
			return U16_MAX
		end
		if uintType == Bardo.uint24 then
			return U24_MAX
		end
		if uintType == Bardo.uint32 then
			return U32_MAX
		end
		return math.huge
	end
	local targetFamily, targetIndex = Bardo.getTypeInfo(targetType)
	local valueFamily, valueIndex = Bardo.getTypeInfo(valueType)

	if targetFamily and targetFamily == valueFamily then
		if targetIndex >= valueIndex then
			return targetType
		end
	end

	if targetFamily == "int" and valueFamily == "uint" and typeof(value) == "number" then
		local intMin, intMax = getIntRange(targetType)
		if value >= intMin and value <= intMax then
			return targetType
		end
	end

	if targetFamily == "uint" and valueFamily == "int" and typeof(value) == "number" then
		local uintMax = getUintMax(targetType)
		if value >= 0 and value <= uintMax then
			return targetType
		end
	end

	return nil
end

Bardo.getSize = function(value: any, bardoType: BardoType): number
	if bardoType == Bardo.string8 or bardoType == Bardo.string16 then
		return bardoType.size + value:len()
	elseif bardoType == Bardo.buffer8 or bardoType == Bardo.buffer16 then
		return bardoType.size + buffer.len(value)
	else
		return bardoType.size
	end
end

Bardo.autoSize = function(value: any): number
	local bardoType = Bardo.auto(value)
	return Bardo.getSize(value, bardoType)
end

Bardo.sanctifySchema = function(bardoTypes: Schema): buffer
	local b = buffer.create(#bardoTypes)
	for index, Type in ipairs(bardoTypes) do
		wu8(b, index - 1, _TYPE_MAP[Type])
	end
	return b
end

Bardo.getTypeName = function(bardoType: BardoType): string
	for name, t in Bardo do
		if t == bardoType then
			return name
		end
	end
	return ""
end

Bardo.rebornSchema = function(b: buffer): Schema
	local bardoTypes = {}
	bardoTypes.size = 0
	for index = 1, buffer.len(b) do
		bardoTypes.size += _TYPE_MAP[ru8(b, index - 1)].size
		bardoTypes[index] = _TYPE_MAP[ru8(b, index - 1)]
	end
	return bardoTypes
end

Bardo.autoSchema = function(...): Schema
	local r = {}
	r.size = 0
	for _, v in { ... } do
		local bardoType = Bardo.auto(v)
		r.size += Bardo.getSize(v, bardoType)
		table.insert(r, bardoType)
	end
	return r
end

Bardo.sanctify = function(schema: Schema, ...): (buffer?, { any? }?)
	local args = { ... }
	local size = 0
	if not schema.size then
		for index, bardoType in ipairs(schema) do
			size += Bardo.getSize(args[index], bardoType)
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
	wu8(result, 0, flag)
	buffer.copy(result, 1, b)

	return result, #unserializable > 0 and unserializable or nil
end

Bardo.reborn = function(schema: Schema, b: buffer, ...): ...any
	if schema.size == 0 or typeof(b) ~= "buffer" then
		warn(`[{script.Name}]: Could not reborn buffer, schema size is zero and no buffer is specified`)
		return b, ...
	end
	local encodedFlag = ru8(b, 0)
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
