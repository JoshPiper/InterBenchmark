local testString = "${name} hat ${cash} in seiner Brieftasche und ${bank} auf seiner Bank."
local testTab = {name = "Billster", cash = "$1337"}

-- Code from Monolith, via DevulTJ.
local function a(s, tab)
	return (s:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
end

-- Code from Billy
local function b(s, tab)
	return (s:gsub('%${(.-)}', function(w) return tab[w] or ("${%s}"):format(w) end))
end

-- Code from Billy
local function c(s, tab)
	return (s:gsub('%${(.-)}', function(w) return tab[w] or ("${" .. w .. "}") end))
end

local function testA()
	a(testString, testTab)
end

local function testB()
	b(testString, testTab)
end

local function testC()
	c(testString, testTab)
end

return {
	meta = {
		order = 101,
		title = "string templating",
		-- runs = 100,
		-- iterations = 10000
	},
	functions = {
		{title = "string sub", func = testA},
		{title = "capture group", func = testB},
		{title = "concating capture group", func = testC}
	}
}
