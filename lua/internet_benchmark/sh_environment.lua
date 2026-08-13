--- Benchmark environment reporting.
-- Collects everything plain GLua exposes about the game and host, so every
-- report can state the conditions it was generated under.
--
-- When the optional gm_sysinfo binary module is installed
-- (https://github.com/JoshPiper/gm_sysinfo), the statement is extended with
-- host details plain GLua cannot see: precise OS and kernel versions, the
-- distribution, CPU architecture, physical core count, memory and swap
-- totals, load averages and uptime.
--
-- Even with the module, the following still need recording by hand:
--   * CPU model and clock speed (not yet exposed by gm_sysinfo).
--   * GPU model and driver version.
-- @module environment

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK
BENCH.Environment = setmetatable({}, {__index = INTERNET_BENCHMARK})
local ENV = BENCH.Environment

local attemptedRequire = false

--- Fetch the optional gm_sysinfo binary module, loading it on first use.
-- @rtab The module's function table, or nil when it is not installed.
function ENV:SysInfo()
	if not istable(sysinfo) and not attemptedRequire then
		attemptedRequire = true
		pcall(require, "sysinfo")
	end

	return istable(sysinfo) and sysinfo or nil
end

--- Format a byte count as mebibytes or gibibytes.
local function formatBytes(bytes)
	if bytes >= 1024 ^ 3 then
		return string.format("%.2f GiB", bytes / 1024 ^ 3)
	end

	return string.format("%.0f MiB", bytes / 1024 ^ 2)
end

--- Format a load average table's named fields.
local function formatLoad(average)
	return string.format(
		"%.2f / %.2f / %.2f (1/5/15 min)",
		average.one, average.five, average.fifteen
	)
end

--- Format an uptime in seconds as days, hours and minutes.
local function formatUptime(seconds)
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	return string.format("%dd %dh %dm", days, hours, minutes)
end

--- Append a {label, value} row, skipping nil values.
local function push(rows, label, value)
	if value ~= nil then
		table.insert(rows, {label, value})
	end
end

--- Call an optional getter, applying a transform to its result.
-- gm_sysinfo getters raise on values they cannot read, and future module
-- versions may add or remove functions, so nothing here is trusted to exist
-- or succeed. Any failure simply omits the row.
local function try(getter, transform)
	if not isfunction(getter) then
		return nil
	end

	local ok, value = pcall(getter)
	if not ok then
		return nil
	end

	if transform then
		ok, value = pcall(transform, value)
		if not ok then
			return nil
		end
	end

	return value
end

--- Collect the environment details.
-- Rows available to plain GLua always come first, in a fixed order; rows
-- provided by gm_sysinfo are appended after them when the module is present.
-- The host name is deliberately never collected - these statements are meant
-- to be published next to benchmark results.
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

	local rows = {
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

	local si = self:SysInfo()
	if si then
		push(rows, "System Info Module", try(si.get_version, function(version)
			return "gm_sysinfo " .. version
		end))
		push(rows, "OS Version", try(si.get_system_long_version))
		push(rows, "Kernel", try(si.get_kernel_version))
		push(rows, "Distribution", try(si.get_distro_id))
		push(rows, "CPU Architecture", try(si.get_cpu_arch))
		push(rows, "Physical Cores", try(si.get_core_count))
		push(rows, "Total Memory", try(si.get_memory, formatBytes))
		push(rows, "Available Memory", try(si.get_available_memory, formatBytes))
		push(rows, "Total Swap", try(si.get_swap, formatBytes))
		push(rows, "Load Average", try(si.get_load_average, formatLoad))
		push(rows, "Host Uptime", try(si.get_uptime, formatUptime))
	end

	return rows
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
	if self:SysInfo() then
		table.insert(lines, "Host details above are provided by the gm_sysinfo binary module.")
		table.insert(lines, "CPU model, clock speed and GPU are not exposed by plain GLua or")
		table.insert(lines, "the module; record those by hand alongside this statement.")
	else
		table.insert(lines, "Plain GLua cannot inspect the hardware itself. CPU model and clock")
		table.insert(lines, "speed, core count, memory, GPU and precise OS version all need")
		table.insert(lines, "a binary module, or recording by hand alongside this statement.")
		table.insert(lines, "The optional gm_sysinfo module (github.com/JoshPiper/gm_sysinfo)")
		table.insert(lines, "provides everything above except the CPU model, clock and GPU.")
	end

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
	self:WriteOutput("environment.txt", self:Format())
end
