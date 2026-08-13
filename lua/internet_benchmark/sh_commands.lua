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

--- Whether an argument list requests dynamic iteration calibration.
local function wantsDynamic(args)
	for _, arg in ipairs(args or {}) do
		if arg:lower() == "dynamic" then
			return true
		end
	end

	return false
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

concommand.Add("internet_benchmark_run", function(ply, _, args)
	if not canRun(ply) then
		BENCH.Logging.Warning("Only superadmins may run server-side benchmarks.")
		return
	end

	BENCH:ReportWithoutCrashing(wantsDynamic(args))
end, nil, "Benchmark every trial and write the HTML report to data/internet_benchmarks/. Pass 'dynamic' to calibrate each trial's iteration count instead of using its fixed default.")

concommand.Add("internet_benchmark_trial", function(ply, _, args)
	if not canRun(ply) then
		BENCH.Logging.Warning("Only superadmins may run server-side benchmarks.")
		return
	end

	local name = args[1]
	if not name then
		BENCH.Logging.ForceWarning("Usage: internet_benchmark_trial <name> [dynamic]")
		return
	end

	local dynamic = wantsDynamic(args)
	BENCH:Async(function()
		BENCH:ConsoleReport(name, dynamic)
	end)
end, trialNames, "Benchmark a single trial and print the results to the console. Pass 'dynamic' as a second argument to calibrate the iteration count instead of using the trial's fixed default.")

concommand.Add("internet_benchmark_environment", function()
	BENCH.Environment:Report()
end, nil, "Print the environment statement used alongside benchmark reports.")
