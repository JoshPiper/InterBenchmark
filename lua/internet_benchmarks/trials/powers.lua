local x = 10
local pow = math.pow

local function a()
	local y = x ^ 2
end

local function b()
	local y = x * x
end

local function c()
	local y = pow(x, 2)
end

return {
	meta = {
		title = "Calculating a Power",
		order = 8
	},
	functions = {
		{title = "x ^ 2", func = a},
		{title = "x * x", func = b},
		{title = "pow(x, 2)", func = c}
	}
}
