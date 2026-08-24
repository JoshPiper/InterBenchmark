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
			name = "Projects the ETA from wall clock rather than from the measured times",
			func = function()
				-- The extra 0.875s per run stands in for the pump idling between ticks.
				local now = 1000

				local clock = stub(_G, "SysTime")
				clock.with(function() return now end)

				local timed = stub(INTERNET_BENCHMARK, "Time")
				timed.with(function()
					now = now + 0.125
					return 0.125
				end)

				local logged = stub(INTERNET_BENCHMARK.Logging, "Debug")

				local mean = INTERNET_BENCHMARK:Benchmark(function() end, 1, 4, function()
					now = now + 0.875
				end)

				-- Restored before asserting: SysTime is too central to leave faked while an assertion unwinds.
				clock:Restore()
				timed:Restore()
				logged:Restore()

				expect(logged.callHistory[1][1]).to.equal("\t\tRun 1 / 4 [ETA: 3s]")
				expect(logged.callHistory[4][1]).to.equal("\t\tRun 4 / 4 [ETA: 0s]")
				expect(mean).to.aboutEqual(0.125, 1e-9)
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
			name = "Statistic computes count, spread and quartiles for a clean set",
			func = function()
				local stats = INTERNET_BENCHMARK:Statistic({1, 2, 3, 4, 5, 6, 7, 8, 9, 10}, 100)

				expect(stats.count).to.equal(10)
				expect(stats.total).to.equal(55)
				expect(stats.mean).to.equal(5.5)
				expect(stats.median).to.equal(5.5)
				expect(stats.q1).to.equal(3.5)
				expect(stats.q3).to.equal(7.5)
				expect(stats.iqr).to.equal(4)
				expect(stats.stdev).to.aboutEqual(2.8722813232690143, 1e-9)
				expect(stats.average).to.equal(0.055)
				expect(stats.min).to.equal(1)
				expect(stats.max).to.equal(10)
				expect(#stats.outliers).to.equal(0)
			end
		},

		{
			name = "Statistic separates an extreme value into outliers, excluding it from min/max",
			func = function()
				local stats = INTERNET_BENCHMARK:Statistic({9, 1, 100, 3, 7, 5, 4, 6, 2, 8}, 1)

				expect(stats.median).to.equal(5.5)
				expect(stats.q1).to.equal(3.5)
				expect(stats.q3).to.equal(7.5)
				expect(#stats.outliers).to.equal(1)
				expect(stats.outliers[1]).to.equal(100)
				expect(stats.min).to.equal(1)
				expect(stats.max).to.equal(9)
				expect(stats.mean).to.equal(14.5)
			end
		},

		{
			name = "Statistic does not treat identical run times as outliers",
			func = function()
				local stats = INTERNET_BENCHMARK:Statistic({5, 5, 5, 5}, 1)

				expect(stats.median).to.equal(5)
				expect(stats.min).to.equal(5)
				expect(stats.max).to.equal(5)
				expect(#stats.outliers).to.equal(0)
			end
		},

		{
			name = "Statistic produces sane statistics for a single run",
			func = function()
				local stats = INTERNET_BENCHMARK:Statistic({7}, 10)

				expect(stats.median).to.equal(7)
				expect(stats.q1).to.equal(7)
				expect(stats.q3).to.equal(7)
				expect(stats.min).to.equal(7)
				expect(stats.max).to.equal(7)
				expect(#stats.outliers).to.equal(0)
				expect(stats.average).to.aboutEqual(0.7, 1e-12)
			end
		},

		{
			name = "Statistic returns nil for an empty result set",
			func = function()
				expect(INTERNET_BENCHMARK:Statistic({}, 1)).to.beNil()
			end
		},

		{
			name = "Statistics tracks the smallest per-function mean as minMean",
			func = function()
				local all = INTERNET_BENCHMARK:Statistics({{1, 2, 3}, {4, 5, 6}}, 10)

				expect(all.minMean).to.equal(2)
				expect(all[1].average).to.aboutEqual(0.2, 1e-12)
				expect(all[2].mean).to.equal(5)
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
			name = "Trial skips a trial that does not match the tag filter",
			func = function()
				local trial = INTERNET_BENCHMARK.Classes.Trial()
				trial.id = "tag_probe_excluded"
				trial.runs = 1
				trial.iterations = 1
				trial:Tag("slow")
				trial:Function(function() end)
				trial:Label("noop")

				stub(INTERNET_BENCHMARK, "LoadTrial").returns(trial)

				local results = INTERNET_BENCHMARK:Trial("tag_probe_excluded", false, false, {"default"}, {})

				expect(results).to.beNil()
			end
		},

		{
			name = "Trial rejects combining dynamic and test",
			func = function()
				local trial = INTERNET_BENCHMARK.Classes.Trial()
				trial.id = "test_and_dynamic_probe"
				trial.runs = 100
				trial.iterations = 100000
				trial:Function(function() end)
				trial:Label("noop")

				stub(INTERNET_BENCHMARK, "LoadTrial").returns(trial)

				local ok = pcall(function()
					INTERNET_BENCHMARK:Trial("test_and_dynamic_probe", true, true)
				end)

				expect(ok).to.beFalse()
			end
		},

		{
			name = "Trial runs a trial that matches the tag filter",
			func = function()
				local trial = INTERNET_BENCHMARK.Classes.Trial()
				trial.id = "tag_probe_included"
				trial.runs = 1
				trial.iterations = 1
				trial:Tag("default")
				trial:Function(function() end)
				trial:Label("noop")

				stub(INTERNET_BENCHMARK, "LoadTrial").returns(trial)

				local results = INTERNET_BENCHMARK:Trial("tag_probe_included", false, false, {"default"}, {})

				expect(#results).to.equal(1)
			end
		},

		{
			name = "Trial skips a trial matching skip-tag even when it also matches tag",
			func = function()
				local trial = INTERNET_BENCHMARK.Classes.Trial()
				trial.id = "tag_probe_skipped"
				trial.runs = 1
				trial.iterations = 1
				trial:Tag("default")
				trial:Function(function() end)
				trial:Label("noop")

				stub(INTERNET_BENCHMARK, "LoadTrial").returns(trial)

				local results = INTERNET_BENCHMARK:Trial("tag_probe_skipped", false, false, {"default"}, {"default"})

				expect(results).to.beNil()
			end
		},

		{
			name = "Trial runs a trial with no explicit tag filter at all",
			func = function()
				local trial = INTERNET_BENCHMARK.Classes.Trial()
				trial.id = "tag_probe_unfiltered"
				trial.runs = 1
				trial.iterations = 1
				trial:Tag("default")
				trial:Function(function() end)
				trial:Label("noop")

				stub(INTERNET_BENCHMARK, "LoadTrial").returns(trial)

				local results = INTERNET_BENCHMARK:Trial("tag_probe_unfiltered")

				expect(#results).to.equal(1)
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
			name = "internet_benchmark_run rejects combining the dynamic and test flags",
			func = function()
				local report = stub(INTERNET_BENCHMARK, "ReportWithoutCrashing")
				local callback = concommand.GetTable()["internet_benchmark_run"]

				callback(nil, "internet_benchmark_run", {"--dynamic", "--test"}, "--dynamic --test")

				expect(report).wasNot.called()
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
			name = "internet_benchmark_run passes --tag and --skip-tag through to the report job",
			func = function()
				local report = stub(INTERNET_BENCHMARK, "ReportWithoutCrashing")
				local callback = concommand.GetTable()["internet_benchmark_run"]

				callback(nil, "internet_benchmark_run", {"--tag=default,slow", "--skip-tag=flaky"}, "--tag=default,slow --skip-tag=flaky")

				expect(report).was.called(1)
				local includeTags = report.callHistory[1][4]
				local excludeTags = report.callHistory[1][5]

				expect(includeTags[1]).to.equal("default")
				expect(includeTags[2]).to.equal("slow")
				expect(excludeTags[1]).to.equal("flaky")
			end
		},

		{
			name = "internet_benchmark_run defaults to no tag filters",
			func = function()
				local report = stub(INTERNET_BENCHMARK, "ReportWithoutCrashing")
				local callback = concommand.GetTable()["internet_benchmark_run"]

				callback(nil, "internet_benchmark_run", {}, "")

				expect(report).was.called(1)
				expect(#report.callHistory[1][4]).to.equal(0)
				expect(#report.callHistory[1][5]).to.equal(0)
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
			name = "internet_benchmark_trial rejects combining the dynamic and test flags",
			func = function()
				local report = stub(INTERNET_BENCHMARK, "ConsoleReport")
				local callback = concommand.GetTable()["internet_benchmark_trial"]

				callback(nil, "internet_benchmark_trial", {"local_vs_global", "--dynamic", "--test"}, "local_vs_global --dynamic --test")

				expect(report).wasNot.called()
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
