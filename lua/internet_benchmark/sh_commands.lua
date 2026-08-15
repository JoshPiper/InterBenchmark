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

	local includeTags = BENCH:ParseTagList(flags.tag)
	local excludeTags = BENCH:ParseTagList(flags["skip-tag"])
	BENCH:ReportWithoutCrashing(dynamic, test, includeTags, excludeTags)
end, BENCH:ArgCompleter({flags = {"dynamic", "test", "tag", "skip-tag"}}), "Benchmark every trial and write the HTML report. '--dynamic'/'--test' set the iteration mode (mutually exclusive). '--tag'/'--skip-tag' (repeatable/comma-separated) filter trials, Ansible-style.")

concommand.Add("internet_benchmark_trial", function(ply, _, args)
	if not canRun(ply) then
		BENCH.Logging.Warning("Only superadmins may run server-side benchmarks.")
		return
	end

	local flags, positional = BENCH:ParseArgs(args)
	if #positional == 0 then
		BENCH.Logging.ForceWarning("Usage: internet_benchmark_trial <name> [<name> ...] [--dynamic] [--test]")
		return
	end

	local dynamic, test = flags.dynamic == true, flags.test == true
	if conflictingFlags(dynamic, test) then
		return
	end

	BENCH:Async(function()
		for _, name in ipairs(positional) do
			BENCH:ConsoleReport(name, dynamic, test)
			BENCH:Yield()
		end
	end)
end, BENCH:ArgCompleter({flags = {"dynamic", "test"}, positionals = {function() return BENCH:TrialNames() end}}), "Benchmark one or more trials and print the results to the console. '--dynamic'/'--test' set the iteration mode (mutually exclusive).")

concommand.Add("internet_benchmark_environment", function()
	BENCH.Environment:Report()
end, nil, "Print the environment statement used alongside benchmark reports.")
