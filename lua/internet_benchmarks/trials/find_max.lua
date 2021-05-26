local math = math.max
local num = 100
local y = 0

function a()
	local x = max(num, y)
end

function b()
	local x
	if num > y then
		x = num
	else
		x = y
	end
end

function c()
	local x = num > y and num or y
end

return {
	meta = {
		title = "Finding and Returning a Maximum Value",
		order = 5
	},
	functions = {
		{title = "math.max", func = a},
		{title = "if num > y then", func = b},
		{title = "num > y and num or y", func = c}
	}
}
