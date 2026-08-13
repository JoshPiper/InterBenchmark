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
	:Description("Three ways to square a number - useful context for when a variable exponent (not just squaring) is unavoidable and ^ can't be hand-expanded into repeated multiplication.")
	:Order(8)
	:Function(a)
	:Label("x ^ 2")
	:Describe("A general power operator, good for any exponent - x*x only wins below because the exponent here happens to be the literal 2.")
	:Function(b)
	:Label("x * x")
	:Function(c)
	:Label("pow(x, 2)")
	:Describe("math.pow isn't part of standard Lua; where present it's a plain C function call, and offers no advantage over ^ for a fixed exponent like this.")
