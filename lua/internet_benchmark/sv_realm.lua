--- Server-side realm bridging (see sh_realm.lua).
--- Handles a client asking the server to run on its behalf ('--realm=server',
--- typed in a client console), and the server console asking one specific
--- connected client to run locally ('--realm=client --target=<player>').

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

--- Resolve a --target flag value to exactly one connected player.
--- Tries an exact SteamID/SteamID64 match first, then falls back to a
--- case-insensitive substring match on nickname.
--- @param query string? A flag value, as returned by BENCH:ParseArgs.
--- @return Player? # The matched player, or nil when no single match was found.
--- @return string? # An error message, set whenever the first return is nil.
function BENCH:ResolvePlayer(query)
	if type(query) ~= "string" or query == "" then
		return nil, "--realm=client requires --target=<name or SteamID>."
	end

	for _, ply in ipairs(player.GetAll()) do
		if ply:SteamID() == query or ply:SteamID64() == query then
			return ply
		end
	end

	local needle = query:lower()
	local matches = {}
	for _, ply in ipairs(player.GetAll()) do
		if ply:Nick():lower():find(needle, 1, true) then
			table.insert(matches, ply)
		end
	end

	if #matches == 0 then
		return nil, string.format("No connected player matches '%s'.", query)
	end

	if #matches > 1 then
		local names = {}
		for _, match in ipairs(matches) do
			table.insert(names, match:Nick())
		end
		return nil, string.format("'%s' matches multiple players: %s", query, table.concat(names, ", "))
	end

	return matches[1]
end

--- Direction B reply: a targeted client's answer to a run/trial the server
--- console asked it to perform.
--- @param requestId integer
--- @param resultKind string "text", "summary" or "reject".
--- @param payload string
function BENCH:OnRealmResult(requestId, resultKind, payload)
	if resultKind == "reject" then
		BENCH.Logging.ForceWarning(payload)
		return
	end

	if resultKind == "text" then
		for _, line in ipairs(string.Explode("\n", payload)) do
			BENCH.Logging.ForceInfo(line)
		end
		return
	end

	if resultKind == "summary" then
		BENCH.Logging.ForceInfo(payload)
		return
	end

	BENCH.Logging.ForceWarning(string.format("Received an unexpected realm result of kind '%s' for request #%d.", tostring(resultKind), requestId))
end

--- Ask a specific connected client to run a benchmark locally.
--- @param kind string "run" or "trial".
--- @param params table Request parameters (see sh_commands.lua's callers).
--- @param targetPly Player The resolved target (see BENCH:ResolvePlayer).
function BENCH:RequestRemoteRun(kind, params, targetPly)
	params = table.Copy(params)
	params.kind = kind

	local requestId = self:NextRealmRequestId()
	self:SendRealmRequest(targetPly, requestId, params)
end

--- Direction A: a client asked the server to run on its behalf.
net.Receive("ib_realm_request", function(_, ply)
	local requestId = net.ReadUInt(32)
	local params = util.JSONToTable(net.ReadString()) or {}

	if not BENCH:CanRunHere(ply) then
		BENCH:SendChunkedString(ply, requestId, "reject", "Only superadmins may run server-side benchmarks.")
		return
	end

	local dynamic, test = params.dynamic == true, params.test == true
	if BENCH:ConflictingFlags(dynamic, test) then
		BENCH:SendChunkedString(ply, requestId, "reject", "--dynamic and --test cannot be combined.")
		return
	end

	if params.kind == "run" then
		local includeTags, excludeTags = params.includeTags or {}, params.excludeTags or {}
		local started = BENCH:Async(function()
			local report = BENCH:HTMLReport(dynamic, test, includeTags, excludeTags)
			if not IsValid(ply) then
				BENCH.Logging.Info(string.format("The requesting player disconnected before request #%d finished; dropping the reply.", requestId))
				return
			end

			if not report then
				BENCH:SendChunkedString(ply, requestId, "reject", "The run produced no results.")
				return
			end

			BENCH:SendChunkedString(ply, requestId, "html", report)
		end)

		if not started then
			BENCH:SendChunkedString(ply, requestId, "reject", "A benchmark job is already running on the server.")
		end
	elseif params.kind == "trial" then
		local name = params.name
		if not name then
			BENCH:SendChunkedString(ply, requestId, "reject", "No trial name was given.")
			return
		end

		local started = BENCH:Async(function()
			local lines = BENCH:ConsoleReport(name, dynamic, test)
			if not IsValid(ply) then
				BENCH.Logging.Info(string.format("The requesting player disconnected before request #%d finished; dropping the reply.", requestId))
				return
			end

			if not lines then
				BENCH:SendChunkedString(ply, requestId, "reject", string.format("Trial '%s' did not run (missing, gated off, or empty).", name))
				return
			end

			BENCH:SendChunkedString(ply, requestId, "text", table.concat(lines, "\n"))
		end)

		if not started then
			BENCH:SendChunkedString(ply, requestId, "reject", "A benchmark job is already running on the server.")
		end
	else
		BENCH:SendChunkedString(ply, requestId, "reject", "Unknown request kind.")
	end
end)
