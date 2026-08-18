--- Client-side realm bridging: handles the server asking this client to run locally, and this client's own requests for the server to run (see sh_realm.lua).

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

--- Direction A reply: the server's answer to a run/trial this client asked it to perform.
--- @param requestId integer
--- @param resultKind string "html", "text" or "reject".
--- @param payload string
function BENCH:OnRealmResult(requestId, resultKind, payload)
	if resultKind == "reject" then
		BENCH.Logging.ForceWarning(payload)
		return
	end

	if resultKind == "html" then
		if self.OpenReport then
			self:OpenReport(payload)
		end
		return
	end

	if resultKind == "text" then
		for _, line in ipairs(string.Explode("\n", payload)) do
			BENCH.Logging.ForceInfo(line)
		end
		return
	end

	BENCH.Logging.ForceWarning(string.format("Received an unexpected realm result of kind '%s' for request #%d.", tostring(resultKind), requestId))
end

--- Ask the server to run a benchmark on this client's behalf.
--- @param kind string "run" or "trial".
--- @param params table Request parameters (see sh_commands.lua's callers).
function BENCH:RequestRemoteRun(kind, params)
	params = table.Copy(params)
	params.kind = kind

	local requestId = self:NextRealmRequestId()
	self:SendRealmRequest(nil, requestId, params)
end

--- Direction B: the server asked this client to run locally.
net.Receive("ib_realm_request", function()
	local requestId = net.ReadUInt(32)
	local params = util.JSONToTable(net.ReadString()) or {}

	local dynamic, test = params.dynamic == true, params.test == true
	if BENCH:ConflictingFlags(dynamic, test) then
		BENCH:SendChunkedString(nil, requestId, "reject", "--dynamic and --test cannot be combined.")
		return
	end

	if params.kind == "run" then
		local includeTags, excludeTags = params.includeTags or {}, params.excludeTags or {}
		local started = BENCH:Async(function()
			local report, overview = BENCH:HTMLReport(dynamic, test, includeTags, excludeTags)
			if not report then
				BENCH:SendChunkedString(nil, requestId, "reject", "The run produced no results.")
				return
			end

			local summary = string.format(
				"Report generated on the requested client (%d trials, %d candidates, widest spread %d%% on '%s').",
				overview.trials, overview.candidates, overview.widestPct, overview.widestName
			)
			BENCH:SendChunkedString(nil, requestId, "summary", summary)
		end)

		if not started then
			BENCH:SendChunkedString(nil, requestId, "reject", "A benchmark job is already running on this client.")
		end
	elseif params.kind == "trial" then
		local name = params.name
		if not name then
			BENCH:SendChunkedString(nil, requestId, "reject", "No trial name was given.")
			return
		end

		local started = BENCH:Async(function()
			local lines = BENCH:ConsoleReport(name, dynamic, test)
			if not lines then
				BENCH:SendChunkedString(nil, requestId, "reject", string.format("Trial '%s' did not run (missing, gated off, or empty).", name))
				return
			end

			BENCH:SendChunkedString(nil, requestId, "text", table.concat(lines, "\n"))
		end)

		if not started then
			BENCH:SendChunkedString(nil, requestId, "reject", "A benchmark job is already running on this client.")
		end
	else
		BENCH:SendChunkedString(nil, requestId, "reject", "Unknown request kind.")
	end
end)
