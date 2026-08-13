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
	:Description(
		"Eight ways to walk a 100-element sequential table, from generic iteration to a hard-coded numeric bound. Lua only evaluates a numeric "
		.. "for loop's limit once, before the loop starts - not on every iteration - which is why the tab.n/#tab/tab[0]/length variants all "
		.. "land close together despite reading their bound differently."
	)
	:Order(10)
	:Function(a)
	:Label("pairs")
	:Describe("Generic iteration that has to handle both the array and hash parts of the table, and works even when the table isn't a sequential array - the baseline everything else here is trying to beat.")
	:Function(b)
	:Label("jit pairs")
	:Describe(
		"Returns Lua's raw next as the iterator directly, instead of calling pairs() to get it - which sounds like it should save a function "
		.. "call, but tends to lose the loop specialisation LuaJIT applies to a literal pairs()/ipairs() call, and is usually the slowest "
		.. "candidate here despite doing less per-call work."
	)
	:Function(c)
	:Label("ipairs")
	:Function(d)
	:Label("for i fixed max")
	:Describe("Hard-codes the loop bound as a literal 100 - the fastest option, but silently wrong the moment the table's size changes.")
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
