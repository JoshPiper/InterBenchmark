local function a()
	type(3)
end

local t = type
local function b()
	t(3)
end

return {
	meta = {
		order = 1
	},
	functions = {
		{title = "type(3)", func = a},
		{title = "t(3)", func = b}
	}
}
