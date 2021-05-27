AddCSLuaFile()
INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
print("Reloaded Core")

function INTERNET_BENCHMARK:Benchmark(avgCount, iterations, benchmarkFunc, preRun, postRun, silent)
	local time = 0
	local results = {}
	local clock = SysTime

	local tmpl = string.format("\t\tRun %%0%dd of %%d", #tostring(avgCount))
	for run = 1, avgCount do
		if not silent then
			print(string.format(tmpl, run, avgCount))
		end
		local start, stop
		if preRun then
			preRun()
		end
		start = clock()
		for times = 1, iterations do
			benchmarkFunc(times)
		end
		stop = clock()
		if postRun then
			postRun()
		end
		collectgarbage()
		results[run] = (stop - start)
		time = time + results[run]
	end

	time = time / avgCount
	return time, results
end

function INTERNET_BENCHMARK:Titalise(word)
	if word:sub(-4) == ".lua" then
		word = word:sub(0, -4)
	end

	word = word:Replace("_", " ")
	word = string.gsub(word, " %w", string.upper)
	word = string.gsub(word, "^%w", string.upper)
	return word
end

function INTERNET_BENCHMARK:Trial(trial)
	local functionFile = string.format("internet_benchmarks/trials/%s", trial)
	local functions = include(functionFile)

	assert(istable(functions), string.format("failed to get trial data for %s", trial))

	local trialData = table.Merge({runs = 2, iterations = 20, title = self:Titalise(trial)}, functions.meta or {})
	functions = istable(functions.functions) and functions.functions or functions

	local results = {}
	local details = {}
	print(string.format("Benchmarking: %s", trialData.title))
	print("\tWarming Up")
	for idx, funct in ipairs(functions) do
		self:Benchmark(trialData.runs / 4, trialData.iterations / 4, funct.func, funct.preRun, funct.postRun, true)
		collectgarbage()
	end

	print("\tDisabling GC")
	collectgarbage()
	collectgarbage()
	collectgarbage("stop")
	local oldStep = collectgarbage("setstepmul", 10000)
	collectgarbage()
	collectgarbage()


	print("\tRunning Tests.")
	for idx, funct in ipairs(functions) do
		funct.title = funct.title or string.format("Untitled Function: %s", idx)
		print(string.format("\t%s", funct.title))
		results[title], details[title] = self:Benchmark(trialData.runs, trialData.iterations, funct.func, funct.preRun, funct.postRun)
		collectgarbage()
	end

	print("\tTests Complete")
	collectgarbage("restart")
	collectgarbage("setstepmul", oldStep)

	local dpTot = false
	local min = false
	local isMs = true
	for id, time in pairs(results) do
		if not min then
			min = time
		else
			min = math.min(min, time)
		end

		if time >= 0.001 then
			isMs = false
		end

		local localDpTot = 100
		for _, chr in ipairs(tostring(time):ToTable()) do
			if chr ~= "." and chr ~= "0" then
				break
			end
			if chr ~= "." then
				localDpTot = localDpTot * 10
			end
		end

		if not dpTot then
			dpTot = localDpTot
		else
			dpTot = math.min(dpTot, localDpTot)
		end
	end

	print("\tResults:")
	for id, time in SortedPairsByValue(results, false) do
		local perc = math.Round((time / min) * 1000) / 10
		local perCall = time / trialData.iterations

		time = math.Round(time * dpTot) / dpTot
		local unit = "s"
		if isMs then
			unit = "ms"
			time = time * 1000
		end
		print(string.format("\t\t%s: %.3f%s (avg: %.3es/call) (%s%%)", id, time, unit, perCall, perc))
	end

	trialData.results = results
	trialData.details = details
	trialData.functions = functions
	return trialData
end

function INTERNET_BENCHMARK:TrialAll()
	local files = file.Find("internet_benchmarks/trials/*", "LUA")
	local results = {}

	for _, path in ipairs(files) do
		results[path] = self:Trial(path)
	end

	return results
end
