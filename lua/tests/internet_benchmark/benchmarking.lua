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
		},

		{
			name = "CalibrateIterations is driven by the fastest function in the trial",
			func = function(state)
				local costPerCall = {}
				local function fast() end
				local function slow() end
				costPerCall[fast] = 1e-5
				costPerCall[slow] = 1e-3

				stub(INTERNET_BENCHMARK, "Time").with(function(_, fn, iterations)
					return iterations * costPerCall[fn]
				end)

				state.originalTarget = INTERNET_BENCHMARK.DynamicTargetDuration
				state.originalMin = INTERNET_BENCHMARK.DynamicMinIterations
				state.originalMax = INTERNET_BENCHMARK.DynamicMaxIterations
				INTERNET_BENCHMARK.DynamicTargetDuration = 1.0
				INTERNET_BENCHMARK.DynamicMinIterations = 10
				INTERNET_BENCHMARK.DynamicMaxIterations = 1000000000

				local trial = {id = "ingame_calibration_probe", functions = {fast, slow}}
				INTERNET_BENCHMARK:CalibrateIterations(trial)

				-- The extrapolation step cancels the probe size exactly
				-- against this linear synthetic clock (see the unit tier's
				-- version of this test for the full derivation).
				expect(trial.iterations).to.aboutEqual(100000, 1)
			end,

			cleanup = function(state)
				INTERNET_BENCHMARK.DynamicTargetDuration = state.originalTarget
				INTERNET_BENCHMARK.DynamicMinIterations = state.originalMin
				INTERNET_BENCHMARK.DynamicMaxIterations = state.originalMax
			end
		},

		{
			name = "Trial recalibrates iterations when dynamic mode is requested",
			func = function()
				local trial = INTERNET_BENCHMARK.Classes.Trial()
				trial.id = "dynamic_probe"
				trial.runs = 1
				trial.iterations = 1
				trial:Function(function() end)
				trial:Label("noop")

				stub(INTERNET_BENCHMARK, "LoadTrial").returns(trial)
				local calibrate = stub(INTERNET_BENCHMARK, "CalibrateIterations")

				INTERNET_BENCHMARK:Trial("dynamic_probe", true)

				expect(calibrate).was.called(1)
			end
		},

		{
			name = "Trial does not recalibrate iterations by default",
			func = function()
				local trial = INTERNET_BENCHMARK.Classes.Trial()
				trial.id = "static_probe"
				trial.runs = 1
				trial.iterations = 1
				trial:Function(function() end)
				trial:Label("noop")

				stub(INTERNET_BENCHMARK, "LoadTrial").returns(trial)
				local calibrate = stub(INTERNET_BENCHMARK, "CalibrateIterations")

				INTERNET_BENCHMARK:Trial("static_probe")

				expect(calibrate).wasNot.called()
			end
		},

		{
			name = "Trial forces the fixed test iteration and run count when test mode is requested",
			func = function()
				local trial = INTERNET_BENCHMARK.Classes.Trial()
				trial.id = "test_mode_probe"
				trial.runs = 100
				trial.iterations = 100000
				trial:Function(function() end)
				trial:Label("noop")

				stub(INTERNET_BENCHMARK, "LoadTrial").returns(trial)

				INTERNET_BENCHMARK:Trial("test_mode_probe", false, true)

				expect(trial.iterations).to.equal(INTERNET_BENCHMARK.TestIterations)
				expect(trial.runs).to.equal(INTERNET_BENCHMARK.TestRuns)
			end
		},

		{
			name = "Trial's test mode takes precedence over dynamic calibration",
			func = function()
				local trial = INTERNET_BENCHMARK.Classes.Trial()
				trial.id = "test_over_dynamic_probe"
				trial.runs = 100
				trial.iterations = 100000
				trial:Function(function() end)
				trial:Label("noop")

				stub(INTERNET_BENCHMARK, "LoadTrial").returns(trial)
				stub(INTERNET_BENCHMARK, "CalibrateIterations").with(function(_, t)
					t.iterations = 999999
				end)

				INTERNET_BENCHMARK:Trial("test_over_dynamic_probe", true, true)

				expect(trial.iterations).to.equal(INTERNET_BENCHMARK.TestIterations)
				expect(trial.runs).to.equal(INTERNET_BENCHMARK.TestRuns)
			end
		},

		{
			name = "internet_benchmark_run passes the dynamic flag through to the report job",
			func = function()
				local report = stub(INTERNET_BENCHMARK, "ReportWithoutCrashing")
				local callback = concommand.GetTable()["internet_benchmark_run"]

				callback(nil, "internet_benchmark_run", {"--dynamic"}, "--dynamic")

				expect(report).was.called(1)
				expect(report.callHistory[1][2]).to.equal(true)
			end
		},

		{
			name = "internet_benchmark_run passes the test flag through to the report job",
			func = function()
				local report = stub(INTERNET_BENCHMARK, "ReportWithoutCrashing")
				local callback = concommand.GetTable()["internet_benchmark_run"]

				callback(nil, "internet_benchmark_run", {"--test"}, "--test")

				expect(report).was.called(1)
				expect(report.callHistory[1][3]).to.equal(true)
			end
		},

		{
			name = "internet_benchmark_run defaults the dynamic flag to false",
			func = function()
				local report = stub(INTERNET_BENCHMARK, "ReportWithoutCrashing")
				local callback = concommand.GetTable()["internet_benchmark_run"]

				callback(nil, "internet_benchmark_run", {}, "")

				expect(report).was.called(1)
				expect(report.callHistory[1][2]).to.beFalse()
			end
		},

		{
			name = "internet_benchmark_run defaults the test flag to false",
			func = function()
				local report = stub(INTERNET_BENCHMARK, "ReportWithoutCrashing")
				local callback = concommand.GetTable()["internet_benchmark_run"]

				callback(nil, "internet_benchmark_run", {}, "")

				expect(report).was.called(1)
				expect(report.callHistory[1][3]).to.beFalse()
			end
		},

		{
			name = "internet_benchmark_run does not treat a bare 'dynamic' argument as the flag",
			func = function()
				local report = stub(INTERNET_BENCHMARK, "ReportWithoutCrashing")
				local callback = concommand.GetTable()["internet_benchmark_run"]

				callback(nil, "internet_benchmark_run", {"dynamic"}, "dynamic")

				expect(report).was.called(1)
				expect(report.callHistory[1][2]).to.beFalse()
			end
		},

		{
			name = "internet_benchmark_trial passes the dynamic flag through to the console report",
			async = true,
			timeout = 1,
			func = function()
				local report = stub(INTERNET_BENCHMARK, "ConsoleReport")
				local callback = concommand.GetTable()["internet_benchmark_trial"]

				callback(nil, "internet_benchmark_trial", {"local_vs_global", "--dynamic"}, "local_vs_global --dynamic")

				timer.Simple(0.1, function()
					expect(report).was.called(1)
					expect(report.callHistory[1][2]).to.equal("local_vs_global")
					expect(report.callHistory[1][3]).to.equal(true)

					done()
				end)
			end,

			cleanup = function()
				INTERNET_BENCHMARK._ActiveJob = nil
			end
		},

		{
			name = "internet_benchmark_trial passes the test flag through to the console report",
			async = true,
			timeout = 1,
			func = function()
				local report = stub(INTERNET_BENCHMARK, "ConsoleReport")
				local callback = concommand.GetTable()["internet_benchmark_trial"]

				callback(nil, "internet_benchmark_trial", {"local_vs_global", "--test"}, "local_vs_global --test")

				timer.Simple(0.1, function()
					expect(report).was.called(1)
					expect(report.callHistory[1][2]).to.equal("local_vs_global")
					expect(report.callHistory[1][4]).to.equal(true)

					done()
				end)
			end,

			cleanup = function()
				INTERNET_BENCHMARK._ActiveJob = nil
			end
		},

		{
			name = "internet_benchmark_trial accepts the dynamic flag before the trial name",
			async = true,
			timeout = 1,
			func = function()
				local report = stub(INTERNET_BENCHMARK, "ConsoleReport")
				local callback = concommand.GetTable()["internet_benchmark_trial"]

				callback(nil, "internet_benchmark_trial", {"--dynamic", "local_vs_global"}, "--dynamic local_vs_global")

				timer.Simple(0.1, function()
					expect(report).was.called(1)
					expect(report.callHistory[1][2]).to.equal("local_vs_global")
					expect(report.callHistory[1][3]).to.equal(true)

					done()
				end)
			end,

			cleanup = function()
				INTERNET_BENCHMARK._ActiveJob = nil
			end
		},

		{
			name = "internet_benchmark_trial defaults the dynamic and test flags to false",
			async = true,
			timeout = 1,
			func = function()
				local report = stub(INTERNET_BENCHMARK, "ConsoleReport")
				local callback = concommand.GetTable()["internet_benchmark_trial"]

				callback(nil, "internet_benchmark_trial", {"local_vs_global"}, "local_vs_global")

				timer.Simple(0.1, function()
					expect(report).was.called(1)
					expect(report.callHistory[1][3]).to.equal(false)
					expect(report.callHistory[1][4]).to.equal(false)

					done()
				end)
			end,

			cleanup = function()
				INTERNET_BENCHMARK._ActiveJob = nil
			end
		}
	}
}
