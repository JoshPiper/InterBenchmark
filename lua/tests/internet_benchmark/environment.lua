--- The environment statement and the suite's console commands.

return {
	groupName = "Internet's Benchmark Suite: Environment",

	cases = {
		{
			name = "Collects environment details as label and value pairs",
			func = function()
				local details = INTERNET_BENCHMARK.Environment:Collect()

				expect(details).to.beA("table")
				expect(#details).to.beGreaterThan(9)
				expect(details[1][1]).to.equal("Suite Version")
				expect(details[1][2]).to.equal(INTERNET_BENCHMARK.Version)
			end
		},

		{
			name = "Reports the server realm when collected on the server",
			func = function()
				local details = INTERNET_BENCHMARK.Environment:Collect()

				expect(details[3][1]).to.equal("Realm")
				expect(details[3][2]).to.equal("Server")
			end
		},

		{
			name = "States the hardware details plain GLua cannot provide",
			func = function()
				local statement = INTERNET_BENCHMARK.Environment:Format()

				local hasHeading = string.find(statement, "Environment Statement", 1, true)
				expect(hasHeading).to.exist()

				local hasCaveat = string.find(statement, "binary module", 1, true)
				expect(hasCaveat).to.exist()
			end
		},

		{
			name = "Records the Lua runtime the game is using",
			func = function()
				local statement = INTERNET_BENCHMARK.Environment:Format()

				local hasRuntime = string.find(statement, "Lua Runtime: LuaJIT", 1, true)
				expect(hasRuntime).to.exist()
			end
		},

		{
			name = "Writes the environment statement into the data directory",
			func = function()
				INTERNET_BENCHMARK.Environment:Write()

				local written = file.Read("internet_benchmarks/environment.txt", "DATA")
				expect(written).to.exist()

				local hasHeading = string.find(written, "Environment Statement", 1, true)
				expect(hasHeading).to.exist()
			end,

			cleanup = function()
				file.Delete("internet_benchmarks/environment.txt")
			end
		},

		{
			name = "Registers the suite console commands",
			func = function()
				local commands = concommand.GetTable()

				expect(commands["internet_benchmark_run"]).to.beA("function")
				expect(commands["internet_benchmark_trial"]).to.beA("function")
				expect(commands["internet_benchmark_environment"]).to.beA("function")
				expect(commands["internet_benchmark_logging_report"]).to.beA("function")
			end
		}
	}
}
