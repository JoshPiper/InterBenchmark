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
	:Order(1001)
	:Function(a)
	:Label("Constructed HasValue")
	:Function(b)
	:Label("Constructed Key Lookup")
	:Function(c)
	:Label("UpValue HasValue")
	:Function(d)
	:Label("UpValue Key Lookup")
	:ManualPredefine(9, 9)
	:ManualPredefine(14, 14)
	:Exclude("c_data")
	:Exclude("d_data")
