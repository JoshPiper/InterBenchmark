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
	:Description("Whether checking == false instead of not costs anything, for a value that's always exactly false. The two aren't generally interchangeable: not also treats nil as falsy, which == false alone would miss.")
	:Order(1000)
	:Tag("default")
	:Function(a)
	:Label("== false")
	:Describe("Would not catch a nil value, only literal false - safe here because testVal is only ever set to false or left at its initial false.")
	:Function(b)
	:Label("not val")
	:ManualPredefine(1, 2)
	:Exclude("testVal")
	:Exclude("setVal")
