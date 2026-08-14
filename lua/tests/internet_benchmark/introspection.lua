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
			name = "Reads the whole file when no line range is given",
			func = function()
				local whole = INTERNET_BENCHMARK.Introspection:ReadSource("internet_benchmark/trials/unpack.lua", nil, nil)

				local hasStart = string.find(whole, "local min = math.min", 1, true)
				expect(hasStart).to.exist()

				local hasEnd = string.find(whole, "\"tbl\"", 1, true)
				expect(hasEnd).to.exist()
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
			name = "Falls back to a function's global route when it has no readable source",
			func = function()
				local source = INTERNET_BENCHMARK.Introspection:FunctionSource(debug.getinfo)
				expect(source).to.equal("debug.getinfo")
			end
		},

		{
			name = "Skips the global route lookup when excludeGlobals is set",
			func = function()
				local rendered = INTERNET_BENCHMARK.Introspection:Variable(debug.getinfo, true)

				expect(rendered).to.beA("string")

				local isPlaceholder = string.find(rendered, "-- Unknown function:", 1, true)
				expect(isPlaceholder).to.exist()
			end
		},

		{
			name = "Renders a non-global function's source as a raw predefine block",
			func = function()
				local function anonymousHelper()
					return "sentinel value"
				end

				local rendered = INTERNET_BENCHMARK.Introspection:Variable(anonymousHelper)

				expect(rendered).to.beA("table")
				expect(rendered[1]).to.equal("raw")

				local hasBody = string.find(rendered[2], "sentinel value", 1, true)
				expect(hasBody).to.exist()
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
			name = "Skips non-string keys when walking globals for a route",
			func = function()
				local nonStringKey = {}
				local haystack = {
					[nonStringKey] = {marker = "unreachable"},
				}

				local ok, route = pcall(function()
					return INTERNET_BENCHMARK.Introspection:Lookup({}, haystack, {}, {})
				end)

				expect(ok).to.beTrue()
				expect(route).to.beFalse()
			end
		},

		{
			name = "Still finds a value by its string key alongside a non-string-keyed sibling",
			func = function()
				local target = {}
				local nonStringKey = {}
				local haystack = {
					[nonStringKey] = {marker = "unreachable"},
					found = target,
				}

				local route = INTERNET_BENCHMARK.Introspection:Lookup(target, haystack, {}, {})
				expect(route).to.equal("found")
			end
		},

		{
			name = "Refuses to search blacklisted global tables",
			func = function()
				local target = {}
				local haystack = {inside = target}

				local route = INTERNET_BENCHMARK.Introspection:Lookup(target, haystack, {"GCompute", "Sub"}, {})
				expect(route).to.beFalse()
			end
		},

		{
			name = "Does not loop forever through self-referential tables",
			func = function()
				local target = {}
				local haystack = {}
				haystack.self = haystack
				haystack.child = {}

				local ok, route = pcall(function()
					return INTERNET_BENCHMARK.Introspection:Lookup(target, haystack, {}, {})
				end)

				expect(ok).to.beTrue()
				expect(route).to.beFalse()
			end
		},

		{
			name = "Finds a value nested several tables deep",
			func = function()
				local target = {}
				local haystack = {level1 = {level2 = {level3 = target}}}

				local route = INTERNET_BENCHMARK.Introspection:Lookup(target, haystack, {}, {})
				expect(route).to.equal("level1.level2.level3")
			end
		},

		{
			name = "Caches a route once found",
			func = function()
				local target = {}
				local haystack = {found = target}

				local first = INTERNET_BENCHMARK.Introspection:Lookup(target, haystack, {}, {})
				local second = INTERNET_BENCHMARK.Introspection:Lookup(target, {}, {}, {})

				expect(first).to.equal("found")
				expect(second).to.equal("found")
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
		},

		{
			name = "Warns when a capture is nil",
			func = function()
				local capturedNil
				local function usesNil()
					return capturedNil
				end

				local warning = stub(INTERNET_BENCHMARK.Logging, "Warning")
				local trial = {
					id = "fake_trial",
					functions = {usesNil},
					excludedVars = {},
					preDefines = {}
				}

				INTERNET_BENCHMARK.Introspection:TrialSources(trial)

				expect(warning).was.called()
			end
		},

		{
			name = "Warns when a manual predefine's lines cannot be read",
			func = function()
				local warning = stub(INTERNET_BENCHMARK.Logging, "Warning")
				local trial = {
					id = "no_such_trial_for_predefine_test",
					functions = {},
					excludedVars = {},
					preDefines = {{1, 2}}
				}

				INTERNET_BENCHMARK.Introspection:TrialSources(trial)

				expect(warning).was.called()
				expect(#trial.predefineSources).to.equal(0)
			end
		},

		{
			name = "De-duplicates identical predefine blocks",
			func = function()
				local trial = INTERNET_BENCHMARK:LoadTrial("unpack")
				trial.preDefines = {{3, 3}, {3, 3}}

				INTERNET_BENCHMARK.Introspection:TrialSources(trial)

				local matches = 0
				for _, define in ipairs(trial.predefineSources) do
					if define == "local tbl = {100, 200, 300, 400}" then
						matches = matches + 1
					end
				end

				expect(matches).to.equal(1)
			end
		}
	}
}
