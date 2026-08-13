local function a()
	math.sin(3.14)
end

local s = math.sin
local function b()
	s(3.14)
end

TRIAL
	:Name("Local vs Global (including Table Index)")
	:Order(2)
	:Function(a)
	:Label("math.sin(3.14)")
	:Function(b)
	:Label("s(3.14)")
