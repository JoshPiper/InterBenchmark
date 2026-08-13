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
end
