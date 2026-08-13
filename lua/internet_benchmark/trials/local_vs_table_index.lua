local function a()
	math.sin(3.14)
end

local s = math.sin
local function b()
	s(3.14)
end

TRIAL
	:Name("Local vs Global (including Table Index)")
	:Description("The same comparison as 'Local vs Global', but through a table field instead of a plain global: math.sin(3.14) pays for a global lookup of math AND a table index into it on every call, while the local capture pays for neither.")
	:Order(2)
	:Function(a)
	:Label("math.sin(3.14)")
	:Function(b)
	:Label("s(3.14)")
