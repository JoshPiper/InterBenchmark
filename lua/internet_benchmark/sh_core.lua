--- Core benchmarking pipeline.
--- Every long-running function here is coroutine aware: run inside a
--- coroutine (see BENCH:Async) it yields around each run's garbage
--- collections and its timed measurement, so the game keeps ticking while a
--- benchmark grinds away in the background.

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

local running, yield = coroutine.running, coroutine.yield
local resume, status = coroutine.resume, coroutine.status
local noop = function() end

--- The data directory reports are written into.
BENCH.OutputDir = "internet_benchmarks"

--- Write a file into the suite's output directory, creating it if needed.
--- @param name string The file's name, including extension.
--- @param content string The file's contents.
function BENCH:WriteOutput(name, content)
	file.CreateDir(self.OutputDir)
	file.Write(string.format("%s/%s", self.OutputDir, name), content)
end

--- Yield when currently inside a coroutine, otherwise do nothing.
--- coroutine.isyieldable is Lua 5.2+, and Garry's Mod ships LuaJIT 2.0 on the
--- public branch, so it is not available. In Lua 5.1 coroutine.running()
--- returns nil on the main thread; later versions flag it with a second
--- return, and this handles both.
function BENCH:Yield()
	local co, isMain = running()
	if co and not isMain then
		yield()
	end
end

--- Per-tick time budget for background jobs, in seconds.
--- A fixed, small cap rather than a fraction of the tick interval: on a
--- low-tickrate server a fraction of TickInterval() could itself be tens of
--- milliseconds, defeating the point of chunking work at all. This bounds
--- how much extra work the pump piles into one tick once it is already
--- running - it does not bound the length of a single yield-to-yield
--- segment (see Benchmark's per-run yields for that).
BENCH.AsyncBudget = 0.002

--- Run a job in the background without freezing the game.
--- The job runs inside a coroutine, pumped from a tick timer with a small
--- per-tick time budget. Errors are logged and re-raised with a traceback.
--- @param func function The job to run.
--- @return boolean # Whether the job was started.
function BENCH:Async(func)
	if self._ActiveJob then
		self.Logging.Warning("A benchmark job is already running, ignoring the new request.")
		return false
	end

	local job = coroutine.create(func)
	local name = "internet_benchmark_" .. tostring(job)
	self._ActiveJob = name

	local budget = self.AsyncBudget
	timer.Create(name, 0, 0, function()
		local finish = SysTime() + budget
		repeat
			local ok, err = resume(job)
			if not ok then
				local trace = debug.traceback(job, err)
				timer.Remove(name)
				self._ActiveJob = nil
				self.Logging.Fatal("Benchmark job failed: ", tostring(err))
				error(trace, 0)
			end

			if status(job) == "dead" then
				timer.Remove(name)
				self._ActiveJob = nil
				return
			end
		until SysTime() >= finish
	end)

	return true
end

--- Time a single run of a function, repeated iterations times.
--- @param func function Function to call.
--- @param iterations integer? Number of times to call the function. Defaults to 1.
--- @return number # The time taken, in seconds.
function BENCH:Time(func, iterations)
	local clock = SysTime
	iterations = iterations or 1

	local start = clock()
	for i = 1, iterations do
		func(i)
	end

	return clock() - start
end

--- Benchmark a single function.
--- Performs runs timed runs of iterationsPerRun iterations each, with a
--- garbage collection either side of every run.
---
--- Each full collectgarbage() call is its own yield-to-yield segment, kept
--- apart from the timed run and from each other: on a live server with a
--- large heap, a single full collection can itself take a meaningful slice
--- of a frame, and stacking two of them plus the timed run into one
--- uninterruptible segment (as this used to) is what causes multi-second
--- frame hitches - the pump can only act on its time budget between
--- segments, never partway through one.
--- @return number # Mean time per run.
--- @return table # Each run's time.
function BENCH:Benchmark(func, iterationsPerRun, runs, preRun, postRun)
	local tmpl = string.format("\t\tRun %%0%dd / %%d [ETA: %%ss]", #tostring(runs))
	local time = 0
	local results = {}

	preRun = preRun or noop
	postRun = postRun or noop

	-- Wall clock, not the sum of the timings: the pump only advances this loop for AsyncBudget per tick.
	local started = SysTime()

	for run = 1, runs do
		collectgarbage()
		self:Yield()

		preRun()
		results[run] = self:Time(func, iterationsPerRun)
		postRun()

		collectgarbage()
		self:Yield()

		time = time + results[run]

		local elapsed = SysTime() - started
		local eta = math.floor((elapsed / run) * (runs - run) * 100) / 100
		self.Logging.Debug(tmpl:format(run, runs, eta))
	end

	return time / runs, results
end

--- Benchmark a list of functions.
--- @return table # results[idx] holds the run-times table for functions[idx].
function BENCH:BenchFunctions(functions, iterations, runs, preRun, postRun)
	local results = {}
	local tmpl = string.format("\tFunction %%0%dd / %%d", #tostring(#functions))

	for idx, fn in ipairs(functions) do
		self.Logging.Info(string.format(tmpl, idx, #functions))
		local _, times = self:Benchmark(fn, iterations, runs, preRun, postRun)
		results[idx] = times
	end

	return results
end

--- Load a trial from disk, without benchmarking it.
--- The trial's meta file (if any) is included first, so its If() gate can
--- stop the function file from being included in the wrong environment.
--- @param name string The trial's file name, without extension.
--- @return table? # The trial, or nil when missing, gated off, or empty.
function BENCH:LoadTrial(name)
	local path = string.format("trials/%s", name)
	local metaPath, fnPath = path .. ".meta.lua", path .. ".lua"
	local hasMeta = file.Exists("internet_benchmark/" .. metaPath, "LUA")
	local hasFunctions = file.Exists("internet_benchmark/" .. fnPath, "LUA")

	if not hasFunctions then
		self.Logging.Warning(string.format("Trial '%s' has no function file, skipping.", name))
		return nil
	end

	local trial = self.Classes.Trial()
	trial.id = name

	TRIAL = trial
	if hasMeta then
		self:Include(metaPath, nil, "sh")
	end

	if trial.setRunIf then
		local allowed = trial.runIf
		if isfunction(allowed) then
			allowed = allowed()
		end

		if not allowed then
			TRIAL = nil
			self.Logging.Info(string.format("Trial '%s' is gated off in this environment, skipping.", name))
			return nil
		end
	end

	self:Include(fnPath, nil, "sh")
	TRIAL = nil

	if #trial.functions == 0 then
		self.Logging.Warning(string.format("Trial '%s' defines no functions, skipping.", name))
		return nil
	end

	return trial
end

--- Target duration for a single calibration or measurement run, in seconds,
--- when dynamic iteration calibration is requested (see CalibrateIterations).
--- Large enough to average out scheduler jitter and clock-resolution noise;
--- small enough to keep calibration itself cheap.
BENCH.DynamicTargetDuration = 0.05

--- Iteration bounds dynamic calibration will settle within.
--- The floor keeps a run long enough for LuaJIT to have a chance to compile
--- a hot trace before it ends; the ceiling is a safety valve against a
--- pathologically fast function driving the estimate toward an unbounded
--- iteration count.
BENCH.DynamicMinIterations = 1000
BENCH.DynamicMaxIterations = 10000000

--- Calibrate a trial's iteration count for its actual functions, instead of
--- using the fixed count it was authored with.
---
--- Every function in a trial ends up sharing one iteration count, so raw
--- per-run statistics stay directly comparable across the trial's Results
--- table exactly as they are with a fixed count. Because a count that
--- comfortably clears the target duration for a slow function can badly
--- undershoot it for a fast one in the same trial, the shared count is
--- driven by whichever function needs the MOST iterations to reach the
--- target - the fastest one. Slower functions in the trial will then run
--- for longer than their own minimum would require; that is the necessary
--- trade-off for keeping the comparison meaningful.
---
--- Each function is probed with a doubling sequence of iteration counts,
--- running the trial's own before/after hooks around every probe so the
--- probed cost matches what a real run would see, until a probe reaches the
--- target duration or the iteration ceiling. The final probe is then
--- extrapolated back to an exact target-duration estimate, rather than just
--- using whichever doubled value first crossed the line.
---
--- This does not change trial.runs, and it overrides whatever iteration
--- count the trial was authored with (or its 100,000 default) - dynamic
--- mode is a per-invocation override, not a per-trial author setting.
--- @param trial table The trial to calibrate. Mutates trial.iterations.
function BENCH:CalibrateIterations(trial)
	local target = self.DynamicTargetDuration
	local minIterations = self.DynamicMinIterations
	local maxIterations = self.DynamicMaxIterations
	local preRun, postRun = trial.before or noop, trial.after or noop

	local needed = minIterations
	for _, fn in ipairs(trial.functions) do
		local probe, elapsed = minIterations, 0

		while true do
			preRun()
			elapsed = self:Time(fn, probe)
			postRun()
			self:Yield()

			if elapsed >= target or probe >= maxIterations then
				break
			end

			probe = math.min(probe * 2, maxIterations)
		end

		-- Extrapolate this function's own target-reaching count from its
		-- last probe, rather than keeping whatever doubled value happened
		-- to first cross the target.
		local estimate = elapsed > 0 and math.ceil(probe * (target / elapsed)) or maxIterations
		needed = math.max(needed, math.min(estimate, maxIterations))
	end

	trial.iterations = math.Clamp(needed, minIterations, maxIterations)
	self.Logging.Info(string.format(
		"Calibrated '%s' to %d iterations/run (target %.3fs/run).",
		trial.id, trial.iterations, target
	))
end

--- Fixed iteration/run counts used when test mode is requested (see the
--- console commands' --test flag), overriding a trial's authored or
--- dynamically calibrated counts so a full trial or report can be smoke
--- tested quickly.
BENCH.TestIterations = 10
BENCH.TestRuns = 2

--- Load and benchmark a single trial.
--- Sources are collected before the first run, then every function gets a
--- quarter-scale warm-up pass followed by the timed runs, with the garbage
--- collector held off throughout.
--- @param name string The trial's file name, without extension.
--- @param dynamic boolean? Recalibrate the trial's iteration count (see
--- CalibrateIterations) instead of using its authored or default count.
--- Defaults to false.
--- @param test boolean? Force a low, fixed iteration and run count (see
--- TestIterations and TestRuns) instead of the trial's authored, default, or
--- dynamically calibrated counts. Combining this with dynamic is rejected
--- (see the assert below); the console commands also reject that
--- combination before it reaches here. Defaults to false.
--- @param includeTags table? Only run the trial if it has one of these tags.
--- Empty or omitted matches every trial. @see BENCH.TagsMatch
--- @param excludeTags table? Skip the trial if it has one of these tags,
--- taking precedence over includeTags.
--- @return table? # results[idx] per function, or nil when the trial did not run.
--- @return table? # The trial.
function BENCH:Trial(name, dynamic, test, includeTags, excludeTags)
	assert(not (dynamic and test), "BENCH:Trial: dynamic and test cannot both be set.")

	local trial = self:LoadTrial(name)
	if not trial then
		return nil
	end

	if not self:TagsMatch(trial.tags or {}, includeTags or {}, excludeTags or {}) then
		self.Logging.Info(string.format("Trial '%s' does not match the tag filter, skipping.", name))
		return nil
	end

	self.Logging.Debug(string.format("Collecting sources for '%s'.", name))
	self.Introspection:TrialSources(trial)

	if dynamic then
		self.Logging.Info("Calibrating Iteration Count")
		self:CalibrateIterations(trial)
	end

	if test then
		trial.iterations = self.TestIterations
		trial.runs = self.TestRuns
	end

	-- Checked after dynamic and test mode, against the counts actually about to be used.
	if (trial.runs or 0) < 1 or (trial.iterations or 0) < 1 then
		self.Logging.Warning(string.format(
			"Trial '%s' asks for %s runs of %s iterations; both must be at least 1, skipping.",
			name, tostring(trial.runs), tostring(trial.iterations)
		))
		return nil
	end

	local preRun, postRun = trial.before, trial.after
	local iterations, runs = trial.iterations, trial.runs

	self.Logging.Info("Warming Up")
	collectgarbage()
	collectgarbage()
	collectgarbage("stop")
	local oldStep = collectgarbage("setstepmul", 10000)

	-- Guarded so a raising trial function cannot leave the collector stopped
	-- for the rest of the session. LuaJIT's VM is fully resumable, so the
	-- per-run yields below still reach the pump from inside this pcall.
	local ok, results = pcall(function()
		self:BenchFunctions(trial.functions, math.ceil(iterations / 4), math.ceil(runs / 4), preRun, postRun)

		self.Logging.Info("Benchmarking")
		return self:BenchFunctions(trial.functions, iterations, runs, preRun, postRun)
	end)

	collectgarbage("restart")
	collectgarbage("setstepmul", oldStep)

	if not ok then
		error(results, 0)
	end

	return results, trial
end

--- Compute summary statistics for a set of run times.
--- Quartiles use the same rank-averaging the suite has always used, and
--- outliers are detected with the 1.5 IQR rule; min and max exclude them.
--- @param results table List of run times.
--- @param iterations integer? Iterations per run, for the per-call average. Defaults to 1.
--- @return table? # The statistics, or nil for an empty result set.
function BENCH:Statistic(results, iterations)
	local count = #results
	if count == 0 then
		return nil
	end

	local sorted = {}
	local total = 0
	for _, result in SortedPairsByValue(results) do
		table.insert(sorted, result)
		total = total + result
	end

	-- Average the values at the floor and ceiling of a fractional rank.
	local function rank(position)
		return (sorted[math.floor(position)] + sorted[math.ceil(position)]) / 2
	end

	local stats = {}
	stats.count = count
	stats.total = total
	stats.mean = total / count
	stats.median = rank((count + 1) / 2)
	stats.q1 = rank((count - 1) / 4 + 1)
	stats.q3 = rank(((count - 1) / 4) * 3 + 1)
	stats.iqr = stats.q3 - stats.q1
	stats.average = stats.mean / (iterations or 1)

	local stdDev = 0
	for _, result in ipairs(sorted) do
		stdDev = stdDev + (result - stats.mean) ^ 2
	end
	stats.stdev = math.sqrt(stdDev / count)

	stats.minbound = stats.q1 - (1.5 * stats.iqr)
	stats.maxbound = stats.q3 + (1.5 * stats.iqr)

	local min, max, outliers = math.huge, -math.huge, {}
	for _, result in ipairs(sorted) do
		if result >= stats.minbound and result <= stats.maxbound then
			min = math.min(min, result)
			max = math.max(max, result)
		else
			table.insert(outliers, result)
		end
	end

	-- A zero IQR (too few samples to spread across quartiles) can flag
	-- every point as an outlier, leaving min/max at their sentinel values.
	-- Fall back to the sorted extremes so a real range is always reported.
	if min == math.huge then
		min, max = sorted[1], sorted[count]
	end

	stats.min = min
	stats.max = max
	stats.outliers = outliers

	return stats
end

--- Compute statistics for every function's results.
--- @param results table List of run-time tables, one per function.
--- @param iterations integer? Iterations per run. Defaults to 1.
--- @return table # statistics[idx] per function, plus a minMean key.
function BENCH:Statistics(results, iterations)
	local statistics = {}
	local min = math.huge

	for fnId, result in ipairs(results) do
		local statistic = self:Statistic(result, iterations)
		if not statistic then
			self.Logging.Warning(string.format("Function #%d recorded no runs; it has no statistics.", fnId))
			break
		end

		statistics[fnId] = statistic
		min = math.min(min, statistic.mean)
	end

	statistics.minMean = min

	return statistics
end
