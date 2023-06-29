INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK
BENCH.Classes = BENCH.Classes or {}

local TRIAL = {}
TRIAL.__index = TRIAL
TRIAL.__nextOrder = 1


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

function TRIAL:Name(name)
	self.name = name
	return self
end

function TRIAL:Runs(count)
	self.runs = count
	return self
end

function TRIAL:Iterations(count)
	self.iterations = count
	return self
end

function TRIAL:If(booleanOrCallable)
	self.setRunIf = true
	self.runIf = booleanOrCallable
	return self
end

function TRIAL:Order(number)
	if not number then
		number = TRIAL.__nextOrder
		TRIAL.__nextOrder = TRIAL.__nextOrder + 1
	end

	self.order = number
	return self
end

function TRIAL:Exclude(varName)
	self.excludedVars[varName] = true
	return self
end

function TRIAL:Label(label)
	table.insert(self.labels, label)
	return self
end

function TRIAL:ManualPredefine(startLine, endLine, startColumn, endColumn)
	table.insert(self.preDefines, {startLine, endLine, startColumn, endColumn})
	return self
end

function TRIAL:Function(callable)
	table.insert(self.functions, callable)
	return self
end

function TRIAL:Before(callable)
	self.before = callable
	return self
end

function TRIAL:After(callable)
	self.after = callable
	return self
end

TRIAL = setmetatable(TRIAL, {__index = BENCH, __call = TRIAL.__call})
BENCH.Classes.Trial = TRIAL
