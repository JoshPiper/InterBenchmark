local y

function a()
	local x
	if not y then
		x = 1
	else
		x = y
	end
end

function b()
	local x = y or 1
end

return {
	meta = {
		title = "'not a' vs 'a or b'",
		order = 7
	},
	functions = {
		{title = "not a", func = a},
		{title = "a or b", func = b},
	}
}
