local testVal = false
local setVal

function a()
	if testVal == false then
		setVal = 1
	end
end

function b()
	if not testVal then
		setVal = 1
	end
end

return {
	meta = {
		title = "val == false vs not val",
		order = 1000,
		-- runs = 500,
		-- iterations = 100000
	},
	functions = {
		{title = "== false", func = a},
		{title = "not val", func = b},
	}
}
