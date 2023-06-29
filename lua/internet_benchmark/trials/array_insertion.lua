local tab = {
	[0] = 0,
	n = 0
}

local insert = table.insert
local count = 1

local function preRun()
	tab = {
		[0] = 0,
		n = 0
	}
	count = 1
end

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
	:Function(a)
	:Label("table.insert")
	:Function(b)
	:Label("tab[i]")
	:Function(c)
	:Label("tab[#tab + 1]")
	:Function(d)
	:Label("tab[count]")
	:Function(e)
	:Label("tab[tab.n]")
	:Function(f)
	:Label("tab[0]")
	:Before(function()
		tab = {
			[0] = 0,
			n = 0
		}
		count = 1
	end)

return {
	meta = {
		order = 12,
		predefines = {
			{1, 4},
			{9, 15}
		},
		excludedVars = {
			tab = true,
			preRun = true
		}
	},
	functions = {
		{title = "table.insert", func = a, preRun = preRun},
		{title = "tab[times]", func = b, preRun = preRun},
		{title = "tab[#tab + 1]", func = c, preRun = preRun},
		{title = "tab[count]", func = d, preRun = preRun},
		{title = "tab[tab.n]", func = e, preRun = preRun},
		{title = "tab[tab[0]]", func = f, preRun = preRun},
	}
}
