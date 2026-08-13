local testString = "${name} hat ${cash} in seiner Brieftasche und ${bank} auf seiner Bank."
local testTab = {name = "Billster", cash = "$1337"}

-- Code from Monolith, via DevulTJ.
local function a(s, tab)
	return s:gsub("($%b{})", function(w) return tab[w:sub(3, -2)] or w end)
end

-- Code from Billy
local function b(s, tab)
	return s:gsub("%${(.-)}", function(w) return tab[w] or ("${%s}"):format(w) end)
end

-- Code from Billy
local function c(s, tab)
	return s:gsub("%${(.-)}", function(w) return tab[w] or ("${" .. w .. "}") end)
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

TRIAL
	:Name("String Templating")
	:Description(
		"Three implementations of ${...} string interpolation, all built on string.gsub. The capture-group variants only differ in how "
		.. "they'd rebuild an unmatched placeholder - string.format vs concatenation - a fallback path this particular test string never "
		.. "actually exercises, worth keeping in mind when reading how close their results are."
	)
	:Order(102)
	:Function(testA)
	:Label("string sub")
	:Describe("Matches the whole ${...} token and strips the delimiters by hand with :sub(), rather than capturing just the inner name.")
	:Function(testB)
	:Label("capture group")
	:Describe("Rebuilds an unmatched placeholder with string.format ('${%s}') - a path this test string never triggers, since every placeholder here resolves.")
	:Function(testC)
	:Label("concating capture group")
	:ManualPredefine(2, 2)
	:Exclude("testTab")
