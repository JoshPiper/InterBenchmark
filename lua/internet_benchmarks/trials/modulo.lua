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

return {
	meta = {
		title = "Calculating Negative Modulus",
		order = 9
	},
	functions = {
		{title = "math.fmod", func = a},
		{title = "% operator", func = b},
		{title = "jit'd fmod", func = c}
	}
}
