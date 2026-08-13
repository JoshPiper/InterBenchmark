local testVal = false
local setVal

local function a()
	if testVal == false then
		setVal = 1
	end
end

local function b()
	if not testVal then
		setVal = 1
	end
end

TRIAL
	:Name("val == false vs not val")
	:Order(1000)
	:Function(a)
	:Label("== false")
	:Function(b)
	:Label("not val")
	:ManualPredefine(1, 2)
	:Exclude("testVal")
	:Exclude("setVal")
