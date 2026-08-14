--- Trial class.
--- A fluent builder describing a single benchmark trial. Trial files receive
--- a fresh instance as the TRIAL global while they are being included.

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK
BENCH.Classes = BENCH.Classes or {}

--- @class Trial
--- @field runs integer Number of timed runs.
--- @field iterations integer Number of iterations within each run.
--- @field excludedVars table<string, boolean> Captured upvalue names excluded from pre-definitions.
--- @field labels table<integer, string> Function labels, indexed by function id.
--- @field descriptions table<integer, string> Function descriptions, indexed by function id.
--- @field preDefines table Ranges of the trial file's own lines shown as pre-definitions.
--- @field functions function[] Functions to be benchmarked.
--- @field name string? Display name.
--- @field description string? Description, shown beneath the title in the report.
--- @field setRunIf boolean? Whether If() has been called.
--- @field runIf boolean|function|nil Gate the trial is run behind.
--- @field order integer? Tab position within the report.
--- @field before function? Callback run before every timed run, for every function.
--- @field after function? Callback run after every timed run, for every function.
--- @field tags table<integer, string> Tags used to filter the trial with --tag/--skip-tag.
local TRIAL = {}
TRIAL.__index = TRIAL
TRIAL.__nextOrder = 1

--- Create a new trial with default settings.
--- @return Trial # A fresh trial instance.
function TRIAL:New()
	return setmetatable({
		runs = 100,
		iterations = 100000,

		excludedVars = {},
		labels = {},
		descriptions = {},
		preDefines = {},
		functions = {},
		tags = {}
	}, self)
end

function TRIAL:__call()
	return self:New()
end

--- Set the trial's display name.
--- @param name string
--- @return Trial
function TRIAL:Name(name)
	self.name = name
	return self
end

--- Set the trial's description, shown beneath its title in the report.
--- @param text string
--- @return Trial
function TRIAL:Description(text)
	self.description = text
	return self
end

--- Set the number of timed runs.
--- @param count integer
--- @return Trial
function TRIAL:Runs(count)
	self.runs = count
	return self
end

--- Set the number of iterations within each run.
--- @param count integer
--- @return Trial
function TRIAL:Iterations(count)
	self.iterations = count
	return self
end

--- Gate the trial behind a boolean or callable.
--- When the value (or the callable's return) is falsy, the trial is skipped.
--- Gates run from the trial's meta file, before the function file is
--- included, so they can guard files which would error outside their
--- intended realm or environment.
--- @param booleanOrCallable boolean|function
--- @return Trial
function TRIAL:If(booleanOrCallable)
	self.setRunIf = true
	self.runIf = booleanOrCallable
	return self
end

--- Set the trial's tab position within the report.
--- With no argument, the next unused order number is taken.
--- @param number integer?
--- @return Trial
function TRIAL:Order(number)
	if not number then
		number = TRIAL.__nextOrder
		TRIAL.__nextOrder = TRIAL.__nextOrder + 1
	end

	self.order = number
	return self
end

--- Exclude a captured upvalue from the report's pre-definitions.
--- Use together with ManualPredefine for values which cannot be serialised,
--- such as tables and entities.
--- @param varName string
--- @return Trial
function TRIAL:Exclude(varName)
	self.excludedVars[varName] = true
	return self
end

--- Label the most recently added function.
--- @param label string
--- @return Trial
function TRIAL:Label(label)
	self.labels[#self.functions] = label
	return self
end

--- Describe the most recently added function, shown beneath its source in
--- the report.
--- @param text string
--- @return Trial
function TRIAL:Describe(text)
	self.descriptions[#self.functions] = text
	return self
end

--- Show a range of the trial file's own lines as report pre-definitions.
--- Lines are 1-indexed and inclusive.
--- @param startLine integer
--- @param endLine integer
--- @return Trial
function TRIAL:ManualPredefine(startLine, endLine)
	table.insert(self.preDefines, {startLine, endLine})
	return self
end

--- Add a function to be benchmarked.
--- @param callable function
--- @return Trial
function TRIAL:Function(callable)
	table.insert(self.functions, callable)
	return self
end

--- Set a callback to run before every timed run, for every function.
--- @param callable function
--- @return Trial
function TRIAL:Before(callable)
	self.before = callable
	return self
end

--- Set a callback to run after every timed run, for every function.
--- @param callable function
--- @return Trial
function TRIAL:After(callable)
	self.after = callable
	return self
end

--- Tag the trial, for filtering with the --tag/--skip-tag console command flags.
--- @param ... string One or more tag names.
--- @return Trial
function TRIAL:Tag(...)
	for _, tag in ipairs({...}) do
		table.insert(self.tags, tag)
	end

	return self
end

TRIAL = setmetatable(TRIAL, {__index = BENCH, __call = TRIAL.__call})
BENCH.Classes.Trial = TRIAL
