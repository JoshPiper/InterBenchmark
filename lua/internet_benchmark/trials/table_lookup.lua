local function a()
	return table.HasValue({"vip", "admin"}, "user")
end

local function b()
	return ({["vip"] = true, ["admin"] = true})["user"]
end

local c_data = {"vip", "admin"}
local function c()
	return table.HasValue(c_data, "user")
end

local d_data = {["vip"] = true, ["admin"] = true}
local function d()
	return d_data["user"]
end

TRIAL
	:Name("HasValue vs Key Lookup in Table Construction vs Upvalues")
	:Description("Four ways to check membership, crossing two independent choices: a linear scan (table.HasValue) vs a direct key lookup, and building the lookup table fresh on every call vs reusing one captured as an upvalue.")
	:Order(1001)
	:Function(a)
	:Label("Constructed HasValue")
	:Describe("Rebuilds the table AND does a linear scan through it on every call - combines both costs, and is the one most people write by accident.")
	:Function(b)
	:Label("Constructed Key Lookup")
	:Describe("Still rebuilds the table on every call, but replaces the scan with a hash lookup - isolates the cost of construction from the cost of table.HasValue's scan.")
	:Function(c)
	:Label("UpValue HasValue")
	:Function(d)
	:Label("UpValue Key Lookup")
	:ManualPredefine(9, 9)
	:ManualPredefine(14, 14)
	:Exclude("c_data")
	:Exclude("d_data")
