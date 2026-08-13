return function(t)
	local BENCH = INTERNET_BENCHMARK

	-- Yield has to work on Lua 5.1, which has no coroutine.isyieldable. Calling
	-- it on the main thread must be a no-op rather than an error, because
	-- Benchmark yields between every run whether or not it is running as a job.
	local ok, err = pcall(function() BENCH:Yield() end)
	t:eq(ok, true, "Yield outside a coroutine does not error")
	t:eq(err, nil, "Yield outside a coroutine raises nothing")

	local co = coroutine.create(function()
		BENCH:Yield()
		return "finished"
	end)

	local resumed = coroutine.resume(co)
	t:eq(resumed, true, "Yield inside a coroutine does not error")
	t:eq(coroutine.status(co), "suspended", "Yield inside a coroutine suspends it")

	local completed, result = coroutine.resume(co)
	t:eq(completed, true, "the coroutine resumes after yielding")
	t:eq(result, "finished", "the coroutine runs to completion")

	-- Benchmark yields between runs; it must survive being called directly.
	local calls = 0
	local benchmarked, mean = pcall(function()
		local average = BENCH:Benchmark(function() calls = calls + 1 end, 2, 3)
		return average
	end)
	t:eq(benchmarked, true, "Benchmark runs outside a coroutine")
	t:eq(calls, 6, "Benchmark calls the function for every iteration of every run")
	t:eq(type(mean), "number", "Benchmark returns a mean")

	-- CalibrateIterations, tested with a deterministic synthetic clock so the
	-- maths can be checked exactly rather than tolerating real timing noise.
	-- BENCH:Time is monkeypatched to a pure function of (fn, iterations), with
	-- each fn's per-call cost fixed up front - real wall-clock timing never
	-- enters the picture.
	do
		local originalTime = BENCH.Time
		local originalTarget = BENCH.DynamicTargetDuration
		local originalMin = BENCH.DynamicMinIterations
		local originalMax = BENCH.DynamicMaxIterations

		BENCH.DynamicTargetDuration = 1.0
		BENCH.DynamicMinIterations = 10
		BENCH.DynamicMaxIterations = 1000000000

		local costPerCall = {}
		function BENCH:Time(fn, iterations)
			return iterations * costPerCall[fn]
		end

		local function fast() end
		local function slow() end
		costPerCall[fast] = 1e-5 -- 10us/call
		costPerCall[slow] = 1e-3 -- 1ms/call, 100x slower than fast

		local beforeCalls, afterCalls = 0, 0
		local trial = {
			id = "test_fast_slow",
			functions = {fast, slow},
			before = function() beforeCalls = beforeCalls + 1 end,
			after = function() afterCalls = afterCalls + 1 end
		}

		BENCH:CalibrateIterations(trial)

		-- Driven by the FASTEST function: needed = target / costPerCall.
		-- The extrapolation step cancels the probe size exactly against this
		-- synthetic linear clock, so this holds to a tight tolerance.
		t:near(trial.iterations, 100000, 1, "calibration is driven by the fastest function in the trial")

		local ranHooks = beforeCalls > 0 and afterCalls > 0
		t:eq(ranHooks, true, "calibration probes run the trial's before/after hooks")

		-- Adding an even slower function must not change the shared count -
		-- the fastest function still dominates.
		local function slower() end
		costPerCall[slower] = 1e-1
		local widerTrial = {id = "test_wider", functions = {fast, slow, slower}}
		BENCH:CalibrateIterations(widerTrial)
		t:eq(widerTrial.iterations, trial.iterations, "an additional slower function does not change the calibrated count")

		-- A trial of only slow functions calibrates to a smaller count.
		local slowOnlyTrial = {id = "test_slow_only", functions = {slow}}
		BENCH:CalibrateIterations(slowOnlyTrial)
		t:near(slowOnlyTrial.iterations, 1000, 1, "a trial with no fast functions calibrates to a smaller count")

		-- The result never drops below DynamicMinIterations, even for an
		-- absurdly slow function.
		BENCH.DynamicMinIterations = 5000
		local function glacial() end
		costPerCall[glacial] = 10
		local flooredTrial = {id = "test_floored", functions = {glacial}}
		BENCH:CalibrateIterations(flooredTrial)
		t:eq(flooredTrial.iterations, 5000, "the calibrated count is clamped to the configured floor")

		BENCH.Time = originalTime
		BENCH.DynamicTargetDuration = originalTarget
		BENCH.DynamicMinIterations = originalMin
		BENCH.DynamicMaxIterations = originalMax
	end
end
