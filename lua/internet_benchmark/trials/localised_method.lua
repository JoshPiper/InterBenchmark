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
	:Description("Whether hoisting a repeatedly-called method into a local pays off, called three times per candidate to give the saved lookups something to add up against.")
	:Order(3)
	:Tag("default")
	:Function(a)
	:Label("Direct Call")
	:Function(b)
	:Label("Local Call")
	:ManualPredefine(1, 3)
	:Exclude("class")
