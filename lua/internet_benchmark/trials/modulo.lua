local fmod = math.fmod
local num = 1000

local function jit_fmod(a, b)
	if b < 0 then b = -b end
	if a < 0 then
		return -(-a % b)
	else
		return a % b
	end
end

local function a()
	local x = fmod(num, 30)
end

local function b()
	local x = num % 30
end

local function c()
	local x = jit_fmod(num, 30)
end

TRIAL
	:Name("Calculating Negative Modulus")
	:Description(
		"Three ways to compute a modulus that also needs to handle negative inputs correctly: math.fmod, the % operator, and a hand-written "
		.. "wrapper that reconciles the two operators' different rounding behaviour. The point here is correctness as much as speed - the "
		.. "three are not interchangeable."
	)
	:Order(9)
	:Function(a)
	:Label("math.fmod")
	:Describe("Matches C's fmod: the result takes the sign of the dividend (num), which differs from Lua's % for negative numbers.")
	:Function(b)
	:Label("% operator")
	:Describe("Lua's % is a floored modulus (its result takes the sign of the divisor) - a different convention to math.fmod for negative inputs, despite both being called 'modulus'.")
	:Function(c)
	:Label("jit'd fmod")
	:Describe("A hand-written function that reproduces math.fmod's sign convention using %, avoiding fmod's call overhead - but only for negative dividends; positive ones fall straight through to plain %.")
