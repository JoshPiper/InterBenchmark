local min = math.min
local unpack = unpack
local tbl = {100, 200, 300, 400}

local function unpack4(tbl)
	return tbl[1], tbl[2], tbl[3], tbl[4]
end

local function a()
	min(tbl[1], tbl[2], tbl[3], tbl[4])
end

local function b()
	min(unpack(tbl))
end

local function c()
	min(unpack4(tbl))
end

TRIAL
	:Name("Unpack")
	:Description("Three ways to pass a fixed-size table's contents as separate arguments to math.min: indexing each slot by hand, letting the generic unpack() walk the table, and a hand-written unpack4() specialised to exactly four elements.")
	:Order(4)
	:Function(a)
	:Label("table index")
	:Function(b)
	:Label("unpack")
	:Describe("unpack() doesn't know tbl has exactly four elements - it has to walk it (and work out its length) every call, which is the whole reason it's dramatically slower here despite looking like the more 'proper' abstraction.")
	:Function(c)
	:Label("unpack4")
	:Describe("Hard-codes the assumption that tbl always has exactly four elements - fast, but silently wrong the moment that changes.")
	:ManualPredefine(3, 3)
	:Exclude("tbl")
