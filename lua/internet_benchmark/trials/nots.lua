local y

local function a()
	local x
	if not y then
		x = 1
	else
		x = y
	end
end

local function b()
	local x = y or 1
end

TRIAL
	:Name("'not a' vs 'a or b'")
	:Description("Two ways to substitute a default when a value is falsy: an explicit if/not branch, and the 'or' idiom.")
	:Order(7)
	:Function(a)
	:Label("not a")
	:Function(b)
	:Label("a or b")
	:Describe("Relies on 'or' returning its right operand whenever the left is falsy (nil or false) - concise, but only correct when explicit false is never a valid value for y.")
	:ManualPredefine(1, 1)
	:Exclude("y")
