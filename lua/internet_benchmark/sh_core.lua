INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

local yieldable, yield = coroutine.isyieldable, coroutine.yield
local function noop() end

--- Time a single run of a function.
-- Repeated <iterations> number of times.
-- @callable func Function to call.
-- @int[opt=1] Number of times to run the function for.
-- @rfloat The time taken.
function BENCH:Time(func, iterations)
	local clock = SysTime
	iterations = iterations or 1
	local start, stop

	start = clock()
	for i = 1, iterations do
		func(i)
	end
	stop = clock()

	return stop - start
end

--- Run a benchmark for a single function.
-- Runs X times, each time will be iterated Y times.
-- @treturn float Average time for an entire run.
-- @treturn table A table with each run's time.
function BENCH:Benchmark(func, iterationsPerRun, runs, preRun, postRun)
	local tmpl = string.format("\t\tRun %%0%dd / %%0%dd [ETA: %%ss]", #tostring(runs), #tostring(runs))
	local time = 0
	local results = {}

	preRun = preRun or noop
	postRun = postRun or noop

	for run = 1, runs do
		self.Logging.Debug("Preparing Run")
		if preRun then preRun() end
		results[run] = self:Time(func, iterationsPerRun)
		if postRun then postRun() end
		collectgarbage()
		time = time + results[run]

		local eta = math.floor((time / run) * (runs - run) * 100) / 100
		if run == 1 and eta < 1 then
			tmpl = string.format("\t\tRun %%0%dd / %%0%dd", #tostring(runs), #tostring(runs))
		end
		self.Logging.Info(tmpl:format(run, runs, eta))

		if yieldable() then
			self.Logging.Debug("Yielding Complete Run")
			yield(results[run])
		end
	end

	time = time / runs
	return time, results
end

function BENCH:BenchFunctions(functions, iterations, runs, preRun, postRun)
	local results = {}
	local tmpl = string.format("Function %%0%dd / %%0%dd", #tostring(#functions), #tostring(#functions))

	for idx, fn in ipairs(functions) do
		self.Logging.Info(string.format(tmpl, idx, #functions))
		local bench = coroutine.create(function()
			return self:Benchmark(fn, iterations, runs, preRun, postRun)
		end)

		local cnt, _, res
		cnt = true
		while cnt do
			cnt, _, res = coroutine.resume(bench)
			self.Logging.Debug("Recieved Yield in BenchFunctions from Benchmark")
			if res then
				self.Logging.Debug("Complete")
				break
			end
			if yieldable() then
				self.Logging.Debug("Deferring Yield")
				yield()
			end
		end

		results[idx] = res
	end

	return results
end

function BENCH:Trial(name, debug_timing)
	local path = string.format("trials/%s", name)
	local metaPath, fnPath = path .. ".meta.lua", path .. ".lua"
	local mpe, fpe = file.Exists("internet_benchmark/" .. metaPath, "LUA"), file.Exists("internet_benchmark/" .. fnPath, "LUA")

	self.Logging.Debug(name, " => ", metaPath, ": ", fnPath)

	local trial = self.Classes.Trial()
	TRIAL = trial
	if mpe then
		self.Logging.Debug("Meta Path Exists: ", metaPath)
		self:Include(metaPath, nil, "sh")
	end
	if trial.setRunIf then
		if not trial.runIf then
			self.Logging.Debug("Cancelled, setRunIf set, runIf false.")
			TRIAL = nil
			return
		end

		if isfunction(trial.runIf) and not trial.runIf() then
			self.Logging.Debug("Cancelled, runIf callable returned false.")
			TRIAL = nil
			return
		end
	end
	if fpe then
		self.Logging.Debug("Functions Path Exists: ", fnPath)
		self:Include(fnPath, nil, "sh")
	end
	trial.id = name
	TRIAL = nil

	if debug_timing then
		-- Discard Iterations, calculate our own.
		trial.runs = 10

		local time = 0
		for _, fn in ipairs(trial.functions) do
			time = math.max(time, self:Time(fn, 10000))
			if yieldable() then
				yield()
			end
		end
		if time ~= 0 then
			trial.iterations = math.ceil(1 / (time / 1000))
			self.Logging.Debug("Ran 10,000 iterations in ", time)
			self.Logging.Debug("0.1s => ", trial.iterations)
		end
		trial.iterations = 100
	end

	local preRun, postRun, iterations, runs = trial.before, trial.after, trial.iterations, trial.runs

	local warm = coroutine.create(function()
		return self:BenchFunctions(trial.functions, math.ceil(iterations / 4), math.ceil(runs / 4), preRun, postRun)
	end)
	local bench = coroutine.create(function()
		return self:BenchFunctions(trial.functions, iterations, runs, preRun, postRun)
	end)

	self.Logging.Info("Warming Up")
	local cnt, res
	cnt = true
	while cnt do
		cnt, res = coroutine.resume(warm)
		self.Logging.Debug("Recieved Yield in Trial from BenchFunctions")
		if res then
			self.Logging.Debug("Complete")
			break
		end
		if yieldable() then
			self.Logging.Debug("Deferring Yield")
			yield()
		end
	end

	self.Logging.Info("Benching Functions")
	cnt = true
	while cnt do
		cnt, res = coroutine.resume(bench)
		self.Logging.Debug("Recieved Yield in Trial from BenchFunctions")
		if res then
			self.Logging.Debug("Complete")
			break
		end
		if yieldable() then
			self.Logging.Debug("Deferring Yield")
			yield()
		end
	end

	return res, trial
end

function BENCH:Statistic(results)
	local stats = {}
	local min, max, total = math.huge, 0, 0
	local count = #results
	local median1, median2 = math.floor((count - 1) / 2) + 1, math.ceil((count - 1) / 2) + 1

	for idx, result in SortedPairsByValue(results) do
		min = math.min(min, result)
		max = math.max(max, result)

		if idx == median1 then
			median1 = result
		end
		if idx == median2 then
			median2 = result
		end

		total = total + result
	end

	stats.total = total
	stats.min = min
	stats.max = max
	stats.median = (median1 + median2) / 2
	stats.mean = total / count
	stats.count = count
	stats.average = stats.mean / count

	local stdDev = 0
	for _, result in ipairs(results) do
		stdDev = stdDev + math.pow(result - stats.mean, 2)
	end
	stats.stdev = math.sqrt(stdDev / count)

	return stats
end

function BENCH:Statistics(results)
	local statistics = {}
	local min = math.huge

	for fnId, result in ipairs(results) do
		statistics[fnId] = self:Statistic(result)
		min = math.min(min, statistics[fnId].mean)
	end

	statistics.minMean = min

	return statistics
end
