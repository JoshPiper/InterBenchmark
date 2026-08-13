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

TRIAL
	:Name("Calculating a Power")
	:Order(8)
	:Function(a)
	:Label("x ^ 2")
	:Function(b)
	:Label("x * x")
	:Function(c)
	:Label("pow(x, 2)")
