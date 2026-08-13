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

TRIAL
	:Name("For Loops")
	:Order(10)
	:Function(a)
	:Label("pairs")
	:Function(b)
	:Label("jit pairs")
	:Function(c)
	:Label("ipairs")
	:Function(d)
	:Label("for i fixed max")
	:Function(e)
	:Label("for i #tab")
	:Function(f)
	:Label("for i length")
	:Function(g)
	:Label("for i tab.n")
	:Function(h)
	:Label("for i tab[0]")
	:ManualPredefine(1, 7)
	:Exclude("tab")
