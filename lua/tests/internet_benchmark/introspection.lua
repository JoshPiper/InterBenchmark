--- Source reading and captured-value serialisation for the report.

return {
	groupName = "Internet's Benchmark Suite: Introspection",

	beforeAll = function(state)
		state.logLevel = INTERNET_BENCHMARK.Logging.Level
		INTERNET_BENCHMARK.Logging.Level = INTERNET_BENCHMARK.Logging.Levels.NONE
	end,

	afterAll = function(state)
		INTERNET_BENCHMARK.Logging.Level = state.logLevel
	end,

	cases = {
		{
			name = "Reads a range of lines from a file",
			func = function()
				local source = INTERNET_BENCHMARK.Introspection:ReadSource("internet_benchmark/trials/local_vs_global.lua", 1, 3)

				expect(source).to.beA("string")

				local hasDefinition = string.find(source, "local function a()", 1, true)
				expect(hasDefinition).to.exist()

				local hasBody = string.find(source, "type(3)", 1, true)
				expect(hasBody).to.exist()
			end
		},

		{
			name = "Strips carriage returns from files written on Windows",
			func = function()
				local source = INTERNET_BENCHMARK.Introspection:ReadSource("internet_benchmark/trials/local_vs_global.lua", 1, 3)

				local hasCarriageReturn = string.find(source, "\r", 1, true)
				expect(hasCarriageReturn).to.beNil()
			end
		},

		{
			name = "Returns nil for a file it cannot read",
			func = function()
				local source = INTERNET_BENCHMARK.Introspection:ReadSource("internet_benchmark/trials/no_such_file.lua", 1, 1)
				expect(source).to.beNil()
			end
		},

		{
			name = "Names a global function by its route",
			func = function()
				local rendered = INTERNET_BENCHMARK.Introspection:Variable(type)
				expect(rendered).to.equal("type")
			end
		},

		{
			name = "Quotes captured strings",
			func = function()
				local rendered = INTERNET_BENCHMARK.Introspection:Variable("hello")
				expect(rendered).to.equal("\"hello\"")
			end
		},

		{
			name = "Renders captured numbers and booleans",
			func = function()
				local number = INTERNET_BENCHMARK.Introspection:Variable(42)
				expect(number).to.equal("42")

				local boolean = INTERNET_BENCHMARK.Introspection:Variable(true)
				expect(boolean).to.equal("true")
			end
		},

		{
			name = "Renders captured colours as constructor calls",
			func = function()
				local rendered = INTERNET_BENCHMARK.Introspection:Variable(Color(10, 20, 30, 40))
				expect(rendered).to.equal("Color(10, 20, 30, 40)")
			end
		},

		{
			name = "Returns nil for values it cannot serialise",
			func = function()
				local rendered = INTERNET_BENCHMARK.Introspection:Variable({1, 2, 3})
				expect(rendered).to.beNil()
			end
		},

		{
			name = "Collects the source of every benchmarked function",
			func = function()
				local trial = INTERNET_BENCHMARK:LoadTrial("local_vs_global")
				INTERNET_BENCHMARK.Introspection:TrialSources(trial)

				expect(#trial.functionSources).to.equal(2)

				local hasBody = string.find(trial.functionSources[1], "type(3)", 1, true)
				expect(hasBody).to.exist()
			end
		},

		{
			name = "Renders captured upvalues as pre-definitions",
			func = function()
				local trial = INTERNET_BENCHMARK:LoadTrial("local_vs_global")
				INTERNET_BENCHMARK.Introspection:TrialSources(trial)

				local hasLocalisedType = table.HasValue(trial.predefineSources, "local t = type")
				expect(hasLocalisedType).to.beTrue()
			end
		},

		{
			name = "Reads manual pre-defines from the trial file",
			func = function()
				local trial = INTERNET_BENCHMARK:LoadTrial("unpack")
				INTERNET_BENCHMARK.Introspection:TrialSources(trial)

				expect(trial.predefineSources[1]).to.equal("local tbl = {100, 200, 300, 400}")
			end
		},

		{
			name = "Stays quiet about captures the trial excludes",
			func = function()
				local trial = INTERNET_BENCHMARK:LoadTrial("unpack")
				local warning = stub(INTERNET_BENCHMARK.Logging, "Warning")

				INTERNET_BENCHMARK.Introspection:TrialSources(trial)

				expect(warning).wasNot.called()
			end
		},

		{
			name = "Warns when a capture cannot be serialised",
			func = function()
				local captured = {"unserialisable"}
				local function usesTable()
					return captured
				end

				local warning = stub(INTERNET_BENCHMARK.Logging, "Warning")
				local trial = {
					id = "fake_trial",
					functions = {usesTable},
					excludedVars = {},
					preDefines = {}
				}

				INTERNET_BENCHMARK.Introspection:TrialSources(trial)

				expect(warning).was.called()
			end
		}
	}
}
