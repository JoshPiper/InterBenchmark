--- Trial class.
-- A fluent builder describing a single benchmark trial. Trial files receive
-- a fresh instance as the TRIAL global while they are being included.
-- @classmod Trial

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK
BENCH.Classes = BENCH.Classes or {}

local TRIAL = {}
TRIAL.__index = TRIAL
TRIAL.__nextOrder = 1

--- Create a new trial with default settings.
-- @rtab A fresh trial instance.
function TRIAL:New()
	return setmetatable({
		runs = 100,
		iterations = 100000,

		excludedVars = {},
		labels = {},
		preDefines = {},
		functions = {}
	}, self)
end

function TRIAL:__call()
	return self:New()
end

--- Set the trial's display name.
function TRIAL:Name(name)
	self.name = name
	return self
end

--- Set the number of timed runs.
function TRIAL:Runs(count)
	self.runs = count
	return self
end

--- Set the number of iterations within each run.
function TRIAL:Iterations(count)
	self.iterations = count
	return self
end

--- Gate the trial behind a boolean or callable.
-- When the value (or the callable's return) is falsy, the trial is skipped.
-- Gates run from the trial's meta file, before the function file is
-- included, so they can guard files which would error outside their
-- intended realm or environment.
function TRIAL:If(booleanOrCallable)
	self.setRunIf = true
	self.runIf = booleanOrCallable
	return self
end

--- Set the trial's tab position within the report.
-- With no argument, the next unused order number is taken.
function TRIAL:Order(number)
	if not number then
		number = TRIAL.__nextOrder
		TRIAL.__nextOrder = TRIAL.__nextOrder + 1
	end

	self.order = number
	return self
end

--- Exclude a captured upvalue from the report's pre-definitions.
-- Use together with ManualPredefine for values which cannot be serialised,
-- such as tables and entities.
function TRIAL:Exclude(varName)
	self.excludedVars[varName] = true
	return self
end

--- Label the most recently added function.
function TRIAL:Label(label)
	self.labels[#self.functions] = label
	return self
end

--- Show a range of the trial file's own lines as report pre-definitions.
-- Lines are 1-indexed and inclusive.
function TRIAL:ManualPredefine(startLine, endLine)
	table.insert(self.preDefines, {startLine, endLine})
	return self
end

--- Add a function to be benchmarked.
function TRIAL:Function(callable)
	table.insert(self.functions, callable)
	return self
end

--- Set a callback to run before every timed run, for every function.
function TRIAL:Before(callable)
	self.before = callable
	return self
end

--- Set a callback to run after every timed run, for every function.
function TRIAL:After(callable)
	self.after = callable
	return self
end

TRIAL = setmetatable(TRIAL, {__index = BENCH, __call = TRIAL.__call})
BENCH.Classes.Trial = TRIAL
