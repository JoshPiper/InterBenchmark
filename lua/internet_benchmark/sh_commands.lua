--- Console commands.

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

--- Whether a command caller may run benchmarks in this realm.
--- Clientside anyone may benchmark their own game. Serverside, only the
--- dedicated console and superadmins qualify.
local function canRun(ply)
	return CLIENT or not IsValid(ply) or ply:IsSuperAdmin()
end

concommand.Add("internet_benchmark_run", function(ply, _, args)
	if not canRun(ply) then
		BENCH.Logging.Warning("Only superadmins may run server-side benchmarks.")
		return
	end

	local flags = BENCH:ParseArgs(args)
	BENCH:ReportWithoutCrashing(flags.dynamic == true)
end, BENCH:ArgCompleter({flags = {"dynamic"}}), "Benchmark every trial and write the HTML report to data/internet_benchmarks/. Pass '--dynamic' to calibrate each trial's iteration count instead of using its fixed default.")

concommand.Add("internet_benchmark_trial", function(ply, _, args)
	if not canRun(ply) then
		BENCH.Logging.Warning("Only superadmins may run server-side benchmarks.")
		return
	end

	local flags, positional = BENCH:ParseArgs(args)
	local name = positional[1]
	if not name then
		BENCH.Logging.ForceWarning("Usage: internet_benchmark_trial <name> [--dynamic]")
		return
	end

	local dynamic = flags.dynamic == true
	BENCH:Async(function()
		BENCH:ConsoleReport(name, dynamic)
	end)
end, BENCH:ArgCompleter({flags = {"dynamic"}, positionals = {function() return BENCH:TrialNames() end}}), "Benchmark a single trial and print the results to the console. Pass '--dynamic' to calibrate the iteration count instead of using the trial's fixed default.")

concommand.Add("internet_benchmark_environment", function()
	BENCH.Environment:Report()
end, nil, "Print the environment statement used alongside benchmark reports.")
