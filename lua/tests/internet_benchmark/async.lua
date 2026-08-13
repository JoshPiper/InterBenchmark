--- The background job pump that keeps the game responsive while measuring.

return {
	groupName = "Internet's Benchmark Suite: Background Jobs",

	beforeAll = function(state)
		state.logLevel = INTERNET_BENCHMARK.Logging.Level
		INTERNET_BENCHMARK.Logging.Level = INTERNET_BENCHMARK.Logging.Levels.NONE
	end,

	afterAll = function(state)
		INTERNET_BENCHMARK.Logging.Level = state.logLevel
	end,

	cases = {
		{
			name = "Runs a yielding job through to completion",
			async = true,
			timeout = 2,
			func = function()
				local steps = 0

				local started = INTERNET_BENCHMARK:Async(function()
					for _ = 1, 3 do
						steps = steps + 1
						INTERNET_BENCHMARK:Yield()
					end
				end)

				expect(started).to.beTrue()

				timer.Simple(0.25, function()
					expect(steps).to.equal(3)
					expect(INTERNET_BENCHMARK._ActiveJob).to.beNil()

					done()
				end)
			end,

			cleanup = function()
				INTERNET_BENCHMARK._ActiveJob = nil
			end
		},

		{
			name = "Refuses to start a second job while one is running",
			func = function()
				local first = INTERNET_BENCHMARK:Async(function()
					INTERNET_BENCHMARK:Yield()
				end)
				local second = INTERNET_BENCHMARK:Async(function() end)

				expect(first).to.beTrue()
				expect(second).to.beFalse()
			end,

			cleanup = function()
				INTERNET_BENCHMARK._ActiveJob = nil
			end
		},

		{
			name = "Accepts a new job once the previous one finishes",
			async = true,
			timeout = 2,
			func = function()
				INTERNET_BENCHMARK:Async(function()
					INTERNET_BENCHMARK:Yield()
				end)

				timer.Simple(0.25, function()
					local restarted = INTERNET_BENCHMARK:Async(function() end)
					expect(restarted).to.beTrue()

					done()
				end)
			end,

			cleanup = function()
				INTERNET_BENCHMARK._ActiveJob = nil
			end
		},

		{
			name = "Clears the active job when the job errors",
			async = true,
			timeout = 2,
			func = function(state)
				-- Async re-raises a failed job with its traceback. Stubbing error
				-- keeps that raise out of the console without hiding the failure,
				-- so the job below has to fault at runtime rather than call error.
				local raised = stub(_G, "error")
				state.raised = raised

				INTERNET_BENCHMARK:Async(function()
					local missing = nil
					return missing.field
				end)

				timer.Simple(0.25, function()
					raised:Restore()

					expect(raised).was.called()
					expect(INTERNET_BENCHMARK._ActiveJob).to.beNil()

					done()
				end)
			end,

			cleanup = function()
				INTERNET_BENCHMARK._ActiveJob = nil
			end
		}
	}
}
