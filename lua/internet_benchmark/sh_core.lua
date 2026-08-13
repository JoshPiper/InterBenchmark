--- Core benchmarking pipeline.
-- Every long-running function here is coroutine aware: run inside a
-- coroutine (see BENCH:Async) it yields between timed runs, so the game
-- keeps ticking while a benchmark grinds away in the background.
-- @module core

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

local yieldable, yield = coroutine.isyieldable, coroutine.yield
local resume, status = coroutine.resume, coroutine.status
local noop = function() end

--- Yield when currently inside a coroutine, otherwise do nothing.
function BENCH:Yield()
	if yieldable() then
		yield()
	end
end

--- Run a job in the background without freezing the game.
-- The job runs inside a coroutine, pumped from a tick timer with a small
-- per-tick time budget. Errors are logged and re-raised with a traceback.
-- @callable func The job to run.
-- @rbool Whether the job was started.
function BENCH:Async(func)
	if self._ActiveJob then
		self.Logging.Warning("A benchmark job is already running, ignoring the new request.")
		return false
	end

	local job = coroutine.create(func)
	local name = "internet_benchmark_" .. tostring(job)
	self._ActiveJob = name

	local budget = engine.TickInterval() / 2
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
-- @callable func Function to call.
-- @int[opt=1] iterations Number of times to call the function.
-- @rnumber The time taken, in seconds.
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
-- Performs runs timed runs of iterationsPerRun iterations each, with a
-- garbage collection either side of every run.
-- @rnumber Mean time per run.
-- @rtab Each run's time.
function BENCH:Benchmark(func, iterationsPerRun, runs, preRun, postRun)
	local tmpl = string.format("\t\tRun %%0%dd / %%d [ETA: %%ss]", #tostring(runs))
	local time = 0
	local results = {}

	preRun = preRun or noop
	postRun = postRun or noop

	for run = 1, runs do
		collectgarbage()
		preRun()
		results[run] = self:Time(func, iterationsPerRun)
		postRun()
		collectgarbage()
		time = time + results[run]

		local eta = math.floor((time / run) * (runs - run) * 100) / 100
		self.Logging.Debug(tmpl:format(run, runs, eta))

		self:Yield()
	end

	return time / runs, results
end

--- Benchmark a list of functions.
-- @rtab results[idx] holds the run-times table for functions[idx].
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
-- The trial's meta file (if any) is included first, so its If() gate can
-- stop the function file from being included in the wrong environment.
-- @string name The trial's file name, without extension.
-- @rtab The trial, or nil when missing, gated off, or empty.
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

--- Load and benchmark a single trial.
-- Sources are collected before the first run, then every function gets a
-- quarter-scale warm-up pass followed by the timed runs, with the garbage
-- collector held off throughout.
-- @string name The trial's file name, without extension.
-- @rtab results[idx] per function, or nil when the trial did not run.
-- @rtab The trial.
function BENCH:Trial(name)
	local trial = self:LoadTrial(name)
	if not trial then
		return nil
	end

	self.Logging.Debug(string.format("Collecting sources for '%s'.", name))
	self.Introspection:TrialSources(trial)

	local preRun, postRun = trial.before, trial.after
	local iterations, runs = trial.iterations, trial.runs

	self.Logging.Info("Warming Up")
	collectgarbage()
	collectgarbage()
	collectgarbage("stop")
	local oldStep = collectgarbage("setstepmul", 10000)

	self:BenchFunctions(trial.functions, math.ceil(iterations / 4), math.ceil(runs / 4), preRun, postRun)

	self.Logging.Info("Benchmarking")
	local results = self:BenchFunctions(trial.functions, iterations, runs, preRun, postRun)

	collectgarbage("restart")
	collectgarbage("setstepmul", oldStep)

	return results, trial
end

--- Compute summary statistics for a set of run times.
-- Quartiles use the same rank-averaging the suite has always used, and
-- outliers are detected with the 1.5 IQR rule; min and max exclude them.
-- @tab results List of run times.
-- @int[opt=1] iterations Iterations per run, for the per-call average.
-- @rtab The statistics, or nil for an empty result set.
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

	stats.min = min
	stats.max = max
	stats.outliers = outliers

	return stats
end

--- Compute statistics for every function's results.
-- @tab results List of run-time tables, one per function.
-- @int[opt=1] iterations Iterations per run.
-- @rtab statistics[idx] per function, plus a minMean key.
function BENCH:Statistics(results, iterations)
	local statistics = {}
	local min = math.huge

	for fnId, result in ipairs(results) do
		statistics[fnId] = self:Statistic(result, iterations)
		min = math.min(min, statistics[fnId].mean)
	end

	statistics.minMean = min

	return statistics
end
