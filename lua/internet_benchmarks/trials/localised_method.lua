local class = {
	test = function() return 1 end
}

function a()
	class.test()
	class.test()
	class.test()
end

function b()
	local test = class.test
	test()
	test()
	test()
end

return {
	meta = {
		order = 3,
		predefines = {
			{1, 3}
		}
	},
	functions = {
		{title = "Direct Call", func = a},
		{title = "Local Call", func = b}
	}
}
