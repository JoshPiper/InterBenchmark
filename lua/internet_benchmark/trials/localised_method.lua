local class = {
	test = function() return 1 end
}

local function a()
	class.test()
	class.test()
	class.test()
end

local function b()
	local test = class.test
	test()
	test()
	test()
end

TRIAL
	:Name("Localised Method Calls")
	:Order(3)
	:Function(a)
	:Label("Direct Call")
	:Function(b)
	:Label("Local Call")
	:ManualPredefine(1, 3)
	:Exclude("class")
