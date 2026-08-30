--- Drives one unattended benchmark run on a headless server, then closes it.
--- Staged into the test server by tools/benchmark/harness.js; never shipped
--- with the addon.

local config = include("internet_benchmark_harness/config.lua")

local WATCHDOG = "internet_benchmark_harness_watchdog"

local function say(message)
	MsgN("[benchmark-harness] " .. message)
end

--- GitHub only reads a workflow command at the start of a line, and the
--- console's colour codes trail the end of the previous one.
local function annotate(message)
	MsgN("\n::error title=Benchmark harness::" .. message)
end

--- Report the run's outcome and shut the server down.
--- The sentinel file and the deferred close are GLuaTest's docker contract:
--- its entrypoint fails the container unless the file reads "true".
--- @param reason string? The failure, or nil when the run succeeded.
local function finish(reason)
	if reason then
		annotate(reason)
		say("status=failed")
	else
		say("status=ok")
	end

	file.Write("gluatest_clean_exit.txt", reason and "false" or "true")
	timer.Simple(1, engine.CloseServer)
end

--- @param BENCH table
--- @param name string
--- @return boolean
local function knownTrial(BENCH, name)
	for _, trial in ipairs(BENCH:TrialNames()) do
		if trial == name then
			return true
		end
	end

	return false
end

--- Restrict trial discovery to a single trial.
--- The report pipeline filters by tag rather than by name, so a single-trial
--- report has to narrow what it discovers instead.
local function onlyTrial(BENCH, name)
	BENCH.TrialNames = function()
		return {name}
	end
end

--- Start the run and watch it through to completion.
local function begin(BENCH)
	local done, failure = false, nil

	local started = BENCH:Async(function()
		local report = BENCH:HTMLReport(config.dynamic, config.test, config.includeTags, config.excludeTags)
		failure = not report and "the run produced no results" or nil
		done = true
	end)

	if not started then
		finish("the benchmark job could not be started")
		return
	end

	local deadline = SysTime() + config.deadline

	timer.Create(WATCHDOG, 1, 0, function()
		if done then
			timer.Remove(WATCHDOG)
			finish(failure)
		elseif not BENCH._ActiveJob then
			-- Async clears the job before re-raising, so a job that vanished
			-- without setting done is one that errored partway through.
			timer.Remove(WATCHDOG)
			finish("the benchmark job stopped before it finished")
		elseif SysTime() > deadline then
			timer.Remove(WATCHDOG)
			finish(string.format("the run exceeded its %d second deadline", config.deadline))
		end
	end)
end

hook.Add("Tick", "InternetBenchmarkHarness", function()
	hook.Remove("Tick", "InternetBenchmarkHarness")

	-- GLuaTest's own fixture closes the server the moment its suite finishes,
	-- which would cut a benchmark short if the suite ran here at all.
	hook.Remove("GLuaTest_Finished", "TestComplete")

	-- Measuring straight off the first tick would bill the map load's
	-- allocations and cold traces to the first trial.
	timer.Simple(config.warmup, function()
		local BENCH = INTERNET_BENCHMARK
		if not istable(BENCH) or not isfunction(BENCH.HTMLReport) then
			finish("the Internet's Benchmark Suite did not load")
			return
		end

		if config.trial then
			if not knownTrial(BENCH, config.trial) then
				finish(string.format(
					"unknown trial '%s'; known trials: %s",
					config.trial, table.concat(BENCH:TrialNames(), ", ")
				))

				return
			end

			onlyTrial(BENCH, config.trial)
		end

		say(config.summary)
		begin(BENCH)
	end)
end)
