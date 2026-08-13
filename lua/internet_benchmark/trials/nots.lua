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
	:Order(7)
	:Function(a)
	:Label("not a")
	:Function(b)
	:Label("a or b")
	:ManualPredefine(1, 1)
	:Exclude("y")
