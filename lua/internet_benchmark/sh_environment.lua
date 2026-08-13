--- Benchmark environment reporting.
-- Collects everything plain GLua exposes about the game and host, so every
-- report can state the conditions it was generated under.
--
-- Plain GLua cannot see the hardware itself. The following details would
-- require a binary module (require()), or filling in by hand:
--   * CPU model, core count, clock speed and thermal state.
--   * Total and available system memory.
--   * GPU model and driver version.
--   * Operating system version and kernel, beyond the OS family.
--   * System load from other processes.
-- @module environment

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK
BENCH.Environment = setmetatable({}, {__index = INTERNET_BENCHMARK})
local ENV = BENCH.Environment

--- Collect the environment details available to plain GLua.
-- @rtab An ordered list of {label, value} pairs.
function ENV:Collect()
	local osName = "Unknown"
	if system.IsWindows() then
		osName = "Windows"
	elseif system.IsLinux() then
		osName = "Linux"
	elseif system.IsOSX() then
		osName = "macOS"
	end

	local hosting = "Listen Server"
	if game.SinglePlayer() then
		hosting = "Singleplayer"
	elseif game.IsDedicated() then
		hosting = "Dedicated Server"
	end

	local tickInterval = engine.TickInterval()

	return {
		{"Suite Version", self.Version},
		{"Generated", os.date("!%Y-%m-%d %H:%M:%S UTC")},
		{"Realm", SERVER and "Server" or "Client"},
		{"Hosting", hosting},
		{"Operating System", osName},
		{"Game Branch", BRANCH},
		{"Game Version", string.format("%s (%s)", VERSION, VERSIONSTR)},
		{"Lua Runtime", jit and jit.version or _VERSION},
		{"Architecture", jit and string.format("%s/%s", jit.os, jit.arch) or "Unknown"},
		{"JIT Compiler", jit and jit.status() and "Enabled" or "Disabled"},
		{"Map", game.GetMap()},
		{"Tick Interval", string.format("%.4fs (%s ticks/s)", tickInterval, math.Round(1 / tickInterval))},
		{"Players", player.GetCount()},
	}
end

--- Render the environment statement as plain text.
-- @rstring The formatted statement.
function ENV:Format()
	local lines = {
		"Internet's Benchmark Suite: Environment Statement",
		"",
	}
	for _, pair in ipairs(self:Collect()) do
		table.insert(lines, string.format("%s: %s", pair[1], tostring(pair[2])))
	end

	table.insert(lines, "")
	table.insert(lines, "Plain GLua cannot inspect the hardware itself. CPU model and clock,")
	table.insert(lines, "core count, memory, GPU and precise OS version would need a binary")
	table.insert(lines, "module or to be recorded by hand alongside this statement.")

	return table.concat(lines, "\n")
end

--- Log the environment statement through the suite's logger.
function ENV:Report()
	for _, pair in ipairs(self:Collect()) do
		self.Logging.ForceInfo(pair[1], ": ", tostring(pair[2]))
	end
end

--- Write the environment statement next to the generated report.
function ENV:Write()
	file.CreateDir("internet_benchmarks")
	file.Write("internet_benchmarks/environment.txt", self:Format())
end
