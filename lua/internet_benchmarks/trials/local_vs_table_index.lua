local function a()
	math.sin(3.14)
end

local s = math.sin
local function b()
	s(3.14)
end

return {
	meta = {
		title = "Local vs Global (including Table Index)",
		order = 2
	},
	functions = {
		{title = "math.sin(3.14)", func = a},
		{title = "s(3.14)", func = b}
	}
}
