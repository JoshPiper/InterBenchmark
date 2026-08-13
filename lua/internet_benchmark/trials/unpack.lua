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
	:Order(4)
	:Function(a)
	:Label("table index")
	:Function(b)
	:Label("unpack")
	:Function(c)
	:Label("unpack4")
	:ManualPredefine(3, 3)
	:Exclude("tbl")
