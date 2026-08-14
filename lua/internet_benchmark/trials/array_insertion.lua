local tab = {
	[0] = 0,
	n = 0
}

local insert = table.insert
local count = 1

local function a(times)
	insert(tab, times)
end

local function b(times)
	tab[times] = times
end

local function c(times)
	tab[#tab + 1] = times
end

local function d(times)
	tab[count] = times
	count = count + 1
end

local function e(times)
	tab.n = tab.n + 1
	tab[tab.n] = times
end

local function f(times)
	tab[0] = tab[0] + 1
	tab[tab[0]] = times
end

TRIAL
	:Name("Array Insertion")
	:Description("Six ways to grow an array-style table by one element per call, comparing table.insert() with direct indexed writes and the various count-tracking patterns people reach for to avoid it.")
	:Order(11)
	:Tag("default")
	:Function(a)
	:Label("table.insert")
	:Describe("A full function call that also has to work out where to insert (the end of the table, by default) - direct indexing below skips both costs.")
	:Function(b)
	:Label("tab[i]")
	:Function(c)
	:Label("tab[#tab + 1]")
	:Describe("Recomputes the table's length with # on every single call, rather than tracking it separately.")
	:Function(d)
	:Label("tab[count]")
	:Function(e)
	:Label("tab[tab.n]")
	:Describe("Tracks the count as a field on the table itself instead of a separate local - convenient to pass around as one value, but every call now pays for an extra table read (tab.n) on top of the write.")
	:Function(f)
	:Label("tab[0]")
	:Describe("The same idea as tab.n, but the counter lives at index 0 of the same array instead of a named field.")
	:Before(function()
		tab = {
			[0] = 0,
			n = 0
		}
		count = 1
	end)
	:ManualPredefine(1, 4)
	:Exclude("tab")
