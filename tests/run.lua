--- Test runner.
-- Usage, from the repository root: luajit tests/run.lua

local root = arg and arg[0] and arg[0]:match("^(.*)[/\\][^/\\]+$") or "tests"

dofile(root .. "/shim.lua")
dofile(root .. "/../lua/internet_benchmark/libs/sh_functional.lua")
dofile(root .. "/../lua/internet_benchmark/libs/sh_logging.lua")
dofile(root .. "/../lua/internet_benchmark/libs/sh_formatting.lua")
dofile(root .. "/../lua/internet_benchmark/sh_core.lua")

local t = {failures = 0, count = 0}

function t:eq(got, want, label)
	self.count = self.count + 1
	if got ~= want then
		self.failures = self.failures + 1
		print(string.format("FAIL %s: expected %s, got %s", label or "?", tostring(want), tostring(got)))
	end
end

function t:near(got, want, epsilon, label)
	self.count = self.count + 1
	if type(got) ~= "number" or math.abs(got - want) > epsilon then
		self.failures = self.failures + 1
		print(string.format("FAIL %s: expected ~%s, got %s", label or "?", tostring(want), tostring(got)))
	end
end

local tests = {"test_formatting", "test_statistic", "test_core"}
for _, name in ipairs(tests) do
	dofile(root .. "/" .. name .. ".lua")(t)
end

print(string.format("%d assertions, %d failures", t.count, t.failures))
if t.failures > 0 then
	os.exit(1)
end
