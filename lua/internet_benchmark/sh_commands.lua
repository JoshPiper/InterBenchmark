--- Console commands.
-- @module commands

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

--- Whether a command caller may run benchmarks in this realm.
-- Clientside anyone may benchmark their own game. Serverside, only the
-- dedicated console and superadmins qualify.
local function canRun(ply)
	return CLIENT or not IsValid(ply) or ply:IsSuperAdmin()
end

--- Autocomplete callback offering trial names.
local function trialNames(cmd, argStr)
	local partial = argStr:Trim():lower()
	local names = {}

	for _, name in ipairs(BENCH:TrialNames()) do
		if partial == "" or name:lower():StartWith(partial) then
			table.insert(names, string.format("%s %s", cmd, name))
		end
	end

	return names
end

concommand.Add("internet_benchmark_run", function(ply)
	if not canRun(ply) then
		BENCH.Logging.Warning("Only superadmins may run server-side benchmarks.")
		return
	end

	BENCH:ReportWithoutCrashing()
end, nil, "Benchmark every trial and write the HTML report to data/internet_benchmarks/.")

concommand.Add("internet_benchmark_trial", function(ply, _, args)
	if not canRun(ply) then
		BENCH.Logging.Warning("Only superadmins may run server-side benchmarks.")
		return
	end

	local name = args[1]
	if not name then
		BENCH.Logging.ForceWarning("Usage: internet_benchmark_trial <name>")
		return
	end

	BENCH:Async(function()
		BENCH:ConsoleReport(name)
	end)
end, trialNames, "Benchmark a single trial and print the results to the console.")

concommand.Add("internet_benchmark_environment", function()
	BENCH.Environment:Report()
end, nil, "Print the environment statement used alongside benchmark reports.")
