function a()
	return table.HasValue({"vip", "admin"}, "user")
end

function b()
	return ({["vip"] = true, ["admin"] = true})["user"]
end

local c_data = {"vip", "admin"}
function c()
	return table.HasValue(c_data, "user")
end

local d_data = {["vip"] = true, ["admin"] = true}
function d()
	return d_data["user"]
end

return {
	meta = {
		title = "HasValue vs Key Lookup in Table Construction vs Upvalues.",
		order = 1000,
		runs = 500,
		iterations = 100000
	},
	functions = {
		{title = "Constructed HasValue", func = a},
		{title = "Constructed Key Lookup", func = b},
		{title = "UpValue HasValue", func = c},
		{title = "UpValue Key Lookup", func = d},
	}
}
