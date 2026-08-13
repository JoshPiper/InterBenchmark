--- The timing loop and the statistics computed from it.

return {
	groupName = "Internet's Benchmark Suite: Benchmarking",

	beforeAll = function(state)
		state.logLevel = INTERNET_BENCHMARK.Logging.Level
		INTERNET_BENCHMARK.Logging.Level = INTERNET_BENCHMARK.Logging.Levels.NONE
	end,

	afterAll = function(state)
		INTERNET_BENCHMARK.Logging.Level = state.logLevel
	end,

	cases = {
		{
			name = "Calls the benchmarked function once per iteration",
			func = function()
				local calls = 0
				local function counted()
					calls = calls + 1
				end

				INTERNET_BENCHMARK:Time(counted, 5)

				expect(calls).to.equal(5)
			end
		},

		{
			name = "Returns a non-negative duration",
			func = function()
				local elapsed = INTERNET_BENCHMARK:Time(function() end, 1)

				expect(elapsed).to.beA("number")

				local nonNegative = elapsed >= 0
				expect(nonNegative).to.beTrue()
			end
		},

		{
			name = "Records a time for every run of a benchmark",
			func = function()
				local calls = 0
				local function counted()
					calls = calls + 1
				end

				local mean, results = INTERNET_BENCHMARK:Benchmark(counted, 2, 3)

				expect(#results).to.equal(3)
				expect(calls).to.equal(6)
				expect(mean).to.beA("number")
			end
		},

		{
			name = "Runs the before and after hooks once per run",
			func = function()
				local before, after = 0, 0

				INTERNET_BENCHMARK:Benchmark(function() end, 1, 3, function()
					before = before + 1
				end, function()
					after = after + 1
				end)

				expect(before).to.equal(3)
				expect(after).to.equal(3)
			end
		},

		{
			name = "Returns the mean of the recorded run times",
			func = function()
				local mean, results = INTERNET_BENCHMARK:Benchmark(function() end, 1, 4)

				local total = results[1] + results[2] + results[3] + results[4]
				expect(mean).to.aboutEqual(total / 4, 1e-9)
			end
		},

		{
			name = "Benchmarks every function it is given",
			func = function()
				local first, second = 0, 0

				local results = INTERNET_BENCHMARK:BenchFunctions({
					function() first = first + 1 end,
					function() second = second + 1 end
				}, 2, 3)

				expect(#results).to.equal(2)
				expect(#results[1]).to.equal(3)
				expect(#results[2]).to.equal(3)
				expect(first).to.equal(6)
				expect(second).to.equal(6)
			end
		},

		{
			name = "Computes statistics from recorded timings",
			func = function()
				local results = INTERNET_BENCHMARK:BenchFunctions({function() end}, 2, 4)
				local statistics = INTERNET_BENCHMARK:Statistics(results, 2)

				expect(statistics.minMean).to.beA("number")
				expect(statistics[1].count).to.equal(4)
				expect(statistics[1].average).to.aboutEqual(statistics[1].mean / 2, 1e-12)
			end
		},

		{
			name = "Benchmarks a whole trial and restores the garbage collector",
			func = function()
				local trial = INTERNET_BENCHMARK.Classes.Trial()
				trial.id = "gc_probe"
				trial.runs = 2
				trial.iterations = 2
				trial:Function(function() end)
				trial:Label("noop")

				stub(INTERNET_BENCHMARK, "LoadTrial").returns(trial)

				local results = INTERNET_BENCHMARK:Trial("gc_probe")

				expect(#results).to.equal(1)
				expect(#results[1]).to.equal(2)

				-- Trial raises the step multiplier while it measures; setting it
				-- here hands back whatever Trial left in place.
				local stepMultiplier = collectgarbage("setstepmul", 200)
				expect(stepMultiplier).to.beLessThan(10000)
			end,

			cleanup = function()
				collectgarbage("setstepmul", 200)
				collectgarbage("restart")
			end
		}
	}
}
