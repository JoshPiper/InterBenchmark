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

local function d()
	local x = Either(num > y, num, y)
end

TRIAL
	:Name("Finding and Returning a Maximum Value")
	:Description("Four ways to pick the larger of two numbers: the standard library function, an explicit branch, the 'and/or' ternary idiom, and GMod's Either() helper.")
	:Order(5)
	:Function(a)
	:Label("math.max")
	:Describe("A C function call, with all the calling overhead that implies compared to inlined Lua.")
	:Function(b)
	:Label("if num > y then")
	:Function(c)
	:Label("num > y and num or y")
	:Describe("The classic Lua ternary idiom - but it silently breaks if the 'true' branch value can be false or nil, since 'or' would then fall through to the other side. Safe here because the values are always numbers.")
	:Function(d)
	:Label("Either(num > y, num, y)")
	:Describe("Unlike 'and/or' or the branch, both num and y are evaluated eagerly before Either() is even called - the branch only decides which one to return, not which one to compute. Fine here since both are cheap plain reads.")
