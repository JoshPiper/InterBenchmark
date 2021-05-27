local a = {}
for i = 1, 100 do
	a[i] = i
end

a.n = 100
a[0] = 100

local length = #a
local nxt = next

local function jit_pairs(t)
	return nxt, t
end

local function a()
	for k, v in pairs(a) do
		local x = v
	end
end

local function b()
	for k, v in jit_pairs(a) do
		local x = v
	end
end

local function c()
	for k, v in ipairs(a) do
		local x = v
	end
end

local function d()
	for i = 1, 100 do
		local x = a[i]
	end
end

local function e()
	for i = 1, #a do
		local x = a[i]
	end
end

local function f()
	for i = 1, length do
		local x = a[i]
	end
end

local function g()
	for i = 1, a.n do
		local x = a[i]
	end
end

local function h()
	for i = 1, a[0] do
		local x = a[i]
	end
end

return {
	meta = {
		title = "For Loops",
		order = 10,
		predefines = {
			{2, 7}
		}
	},
	functions = {
		{title = "pairs", func = a},
		{title = "jit pairs", func = b},
		{title = "ipairs", func = c},
		{title = "for i fixed max", func = d},
		{title = "for i #a", func = e},
		{title = "for i length", func = f},
		{title = "for i a.n", func = g},
		{title = "for i a[0]", func = h}
	}
}
