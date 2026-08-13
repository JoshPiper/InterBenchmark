local max = math.max
local num = 100
local y = 0

local function a()
	local x = max(num, y)
end

local function b()
	local x
	if num > y then
		x = num
	else
		x = y
	end
end

local function c()
	local x = num > y and num or y
end

TRIAL
	:Name("Finding and Returning a Maximum Value")
	:Order(5)
	:Function(a)
	:Label("math.max")
	:Function(b)
	:Label("if num > y then")
	:Function(c)
	:Label("num > y and num or y")
