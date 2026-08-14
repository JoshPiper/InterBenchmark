--- Console commands.

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

--- Whether a command caller may run benchmarks in this realm.
--- Clientside anyone may benchmark their own game. Serverside, only the
--- dedicated console and superadmins qualify.
local function canRun(ply)
	return CLIENT or not IsValid(ply) or ply:IsSuperAdmin()
end

--- Whether '--dynamic' and '--test' were both passed.
--- The two are mutually exclusive: '--dynamic' calibrates toward a target
--- run duration, while '--test' forces a fixed, deliberately-too-short
--- count for a quick smoke test - combining them is always a mistake, not a
--- meaningful configuration, so it is rejected outright rather than having
--- one silently win.
--- @param dynamic boolean
--- @param test boolean
--- @return boolean
local function conflictingFlags(dynamic, test)
	if dynamic and test then
		BENCH.Logging.ForceWarning("--dynamic and --test cannot be combined.")
		return true
	end

	return false
end

concommand.Add("internet_benchmark_run", function(ply, _, args)
	if not canRun(ply) then
		BENCH.Logging.Warning("Only superadmins may run server-side benchmarks.")
		return
	end

	local flags = BENCH:ParseArgs(args)
	local dynamic, test = flags.dynamic == true, flags.test == true
	if conflictingFlags(dynamic, test) then
		return
	end

	BENCH:ReportWithoutCrashing(dynamic, test)
end, BENCH:ArgCompleter({flags = {"dynamic", "test"}}), "Benchmark every trial and write the HTML report to data/internet_benchmarks/. Pass '--dynamic' to calibrate each trial's iteration count instead of using its fixed default. Pass '--test' to force a low iteration and run count for a quick smoke test. The two flags cannot be combined.")

concommand.Add("internet_benchmark_trial", function(ply, _, args)
	if not canRun(ply) then
		BENCH.Logging.Warning("Only superadmins may run server-side benchmarks.")
		return
	end

	local flags, positional = BENCH:ParseArgs(args)
	local name = positional[1]
	if not name then
		BENCH.Logging.ForceWarning("Usage: internet_benchmark_trial <name> [--dynamic] [--test]")
		return
	end

	local dynamic, test = flags.dynamic == true, flags.test == true
	if conflictingFlags(dynamic, test) then
		return
	end

	BENCH:Async(function()
		BENCH:ConsoleReport(name, dynamic, test)
	end)
end, BENCH:ArgCompleter({flags = {"dynamic", "test"}, positionals = {function() return BENCH:TrialNames() end}}), "Benchmark a single trial and print the results to the console. Pass '--dynamic' to calibrate the iteration count instead of using the trial's fixed default. Pass '--test' to force a low iteration and run count for a quick smoke test. The two flags cannot be combined.")

concommand.Add("internet_benchmark_environment", function()
	BENCH.Environment:Report()
end, nil, "Print the environment statement used alongside benchmark reports.")
