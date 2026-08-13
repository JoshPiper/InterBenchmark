local function a()
	type(3)
end

local t = type
local function b()
	t(3)
end

TRIAL
	:Name("Local vs Global")
	:Order(1)
	:Function(a)
	:Label("type(3)")
	:Function(b)
	:Label("t(3)")
