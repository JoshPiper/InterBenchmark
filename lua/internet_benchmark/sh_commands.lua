--- Console commands.

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

--- Whether a command caller may run benchmarks in this realm; also the authorisation check for realm-bridged requests (see sv_realm.lua).
--- @param ply Player?
--- @return boolean
function BENCH:CanRunHere(ply)
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
function BENCH:ConflictingFlags(dynamic, test)
	if dynamic and test then
		BENCH.Logging.ForceWarning("--dynamic and --test cannot be combined.")
		return true
	end

	return false
end

--- Read and validate a --realm flag.
--- @param flags table As returned by BENCH:ParseArgs.
--- @return string? # "client" or "server", or nil when none was given.
--- @return boolean # Whether an invalid value was passed (already warned about).
local function readRealm(flags)
	local realm = flags.realm
	if realm == nil then
		return nil, false
	end

	realm = type(realm) == "string" and realm:lower() or nil
	if realm ~= "client" and realm ~= "server" then
		BENCH.Logging.ForceWarning("--realm must be 'client' or 'server'.")
		return nil, true
	end

	return realm, false
end

--- Whether --realm names the opposite realm to this one, the only case that needs bridging over the net.
--- @param realm string? "client" or "server".
--- @return boolean
local function isRemoteRealm(realm)
	return realm ~= nil and ((SERVER and realm == "client") or (CLIENT and realm == "server"))
end

--- Join help-text fragments into one console help string, so the fragments stay readable in source.
--- @param ... string
--- @return string
local function helpText(...)
	return table.concat({...}, " ")
end

local helpIterationMode = "'--dynamic'/'--test' set the iteration mode (mutually exclusive)."
local helpTagFilter = "'--tag'/'--skip-tag' (repeatable/comma-separated) filter trials, Ansible-style."
local helpRealm = "'--realm=client'/'--realm=server' bridges the run to the opposite realm ('--realm=client' needs '--target=<player>' and only works from the server console)."

concommand.Add("internet_benchmark_run", function(ply, _, args)
	if not BENCH:CanRunHere(ply) then
		BENCH.Logging.Warning("Only superadmins may run server-side benchmarks.")
		return
	end

	local flags = BENCH:ParseArgs(args)
	local dynamic, test = flags.dynamic == true, flags.test == true
	if BENCH:ConflictingFlags(dynamic, test) then
		return
	end

	local includeTags = BENCH:ParseTagList(flags.tag)
	local excludeTags = BENCH:ParseTagList(flags["skip-tag"])

	local realm, invalidRealm = readRealm(flags)
	if invalidRealm then
		return
	end

	if isRemoteRealm(realm) then
		local params = {dynamic = dynamic, test = test, includeTags = includeTags, excludeTags = excludeTags}

		if SERVER then
			local target, err = BENCH:ResolvePlayer(flags.target)
			if not target then
				BENCH.Logging.ForceWarning(err)
				return
			end

			BENCH:RequestRemoteRun("run", params, target)
		else
			BENCH:RequestRemoteRun("run", params)
		end

		return
	end

	BENCH:ReportWithoutCrashing(dynamic, test, includeTags, excludeTags)
end, BENCH:ArgCompleter({flags = {"dynamic", "test", "tag", "skip-tag", "realm", "target"}}), helpText(
	"Benchmark every trial and write the HTML report.",
	helpIterationMode,
	helpTagFilter,
	helpRealm
))

concommand.Add("internet_benchmark_trial", function(ply, _, args)
	if not BENCH:CanRunHere(ply) then
		BENCH.Logging.Warning("Only superadmins may run server-side benchmarks.")
		return
	end

	local flags, positional = BENCH:ParseArgs(args)
	local name = positional[1]
	if not name then
		BENCH.Logging.ForceWarning("Usage: internet_benchmark_trial <name> [--dynamic] [--test] [--realm=client|server] [--target=<player>]")
		return
	end

	local dynamic, test = flags.dynamic == true, flags.test == true
	if BENCH:ConflictingFlags(dynamic, test) then
		return
	end

	local realm, invalidRealm = readRealm(flags)
	if invalidRealm then
		return
	end

	if isRemoteRealm(realm) then
		local params = {name = name, dynamic = dynamic, test = test}

		if SERVER then
			local target, err = BENCH:ResolvePlayer(flags.target)
			if not target then
				BENCH.Logging.ForceWarning(err)
				return
			end

			BENCH:RequestRemoteRun("trial", params, target)
		else
			BENCH:RequestRemoteRun("trial", params)
		end

		return
	end

	BENCH:Async(function()
		BENCH:ConsoleReport(name, dynamic, test)
	end)
end, BENCH:ArgCompleter({flags = {"dynamic", "test", "realm", "target"}, positionals = {function() return BENCH:TrialNames() end}}), helpText(
	"Benchmark a single trial and print the results to the console.",
	helpIterationMode,
	helpRealm
))

concommand.Add("internet_benchmark_environment", function()
	BENCH.Environment:Report()
end, nil, "Print the environment statement used alongside benchmark reports.")
