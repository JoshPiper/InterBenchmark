local tab = {}
for i = 1, 100 do
	tab[i] = i
end

tab.n = 100
tab[0] = 100

local length = #tab
local nxt = next

local function jit_pairs(t)
	return nxt, t
end

local function a()
	for k, v in pairs(tab) do
		local x = v
	end
end

local function b()
	for k, v in jit_pairs(tab) do
		local x = v
	end
end

local function c()
	for k, v in ipairs(tab) do
		local x = v
	end
end

local function d()
	for i = 1, 100 do
		local x = tab[i]
	end
end

local function e()
	for i = 1, #tab do
		local x = tab[i]
	end
end

local function f()
	for i = 1, length do
		local x = tab[i]
	end
end

local function g()
	for i = 1, tab.n do
		local x = tab[i]
	end
end

local function h()
	for i = 1, tab[0] do
		local x = tab[i]
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
		{title = "for i #tab", func = e},
		{title = "for i length", func = f},
		{title = "for i tab.n", func = g},
		{title = "for i tab[0]", func = h}
	}
}
