--- Templating, tab rendering and the files written to the data directory.

return {
	groupName = "Internet's Benchmark Suite: Reporting",

	beforeEach = function(state)
		state.trial = {
			id = "example",
			name = "Example Trial",
			description = "Whether caching matters for a single call.",
			runs = 2,
			iterations = 10,
			functions = {function() end, function() end},
			labels = {"First Way", "Second Way"},
			descriptions = {"Calls it directly."},
			functionSources = {"local function a() return 1 < 2 end", "local function b() end"},
			predefineSources = {"local threshold = 5"}
		}

		state.timing = {{0.02, 0.03}, {0.04, 0.05}}
		state.stats = INTERNET_BENCHMARK:Statistics(state.timing, 10)
	end,

	cases = {
		{
			name = "Renders a template with its variables",
			func = function()
				local rendered = INTERNET_BENCHMARK.Templating:Template("nav/tab", {key = "example", title = "Example"})

				local hasKey = string.find(rendered, "data-view=\"trial:example\"", 1, true)
				expect(hasKey).to.exist()

				local hasTitle = string.find(rendered, ">Example<", 1, true)
				expect(hasTitle).to.exist()
			end
		},

		{
			name = "Leaves unknown template variables in place",
			func = function()
				local rendered = INTERNET_BENCHMARK.Templating:Replace("${known}-${unknown}", {known = "value"})
				expect(rendered).to.equal("value-${unknown}")
			end
		},

		{
			name = "Treats a non-table variable as the content field",
			func = function()
				local rendered = INTERNET_BENCHMARK.Templating:Replace("<p>${content}</p>", "text")
				expect(rendered).to.equal("<p>text</p>")
			end
		},

		{
			name = "Builds template paths under the suite directory",
			func = function()
				local path = INTERNET_BENCHMARK.Templating:Path("nav/tab")
				expect(path).to.equal("internet_benchmark/templates/html/nav/tab.html.lua")
			end
		},

		{
			name = "Escapes source code rendered into the report",
			func = function(state)
				local html = INTERNET_BENCHMARK:HTMLTab("example", state.timing, state.stats, state.trial)

				local escaped = string.find(html, "1 &lt; 2", 1, true)
				expect(escaped).to.exist()

				local unescaped = string.find(html, "1 < 2", 1, true)
				expect(unescaped).to.beNil()
			end
		},

		{
			name = "Names every benchmarked function in the results table",
			func = function(state)
				local html = INTERNET_BENCHMARK:HTMLTab("example", state.timing, state.stats, state.trial)

				local hasFirst = string.find(html, "First Way", 1, true)
				expect(hasFirst).to.exist()

				local hasSecond = string.find(html, "Second Way", 1, true)
				expect(hasSecond).to.exist()
			end
		},

		{
			name = "Renders the trial's description beneath its title",
			func = function(state)
				local html = INTERNET_BENCHMARK:HTMLTab("example", state.timing, state.stats, state.trial)

				local hasDescription = string.find(html, "<p>Whether caching matters for a single call.</p>", 1, true)
				expect(hasDescription).to.exist()
			end
		},

		{
			name = "Renders a candidate's description, only where one was given",
			func = function(state)
				local html = INTERNET_BENCHMARK:HTMLTab("example", state.timing, state.stats, state.trial)

				local hasDescription = string.find(html, "<p class=\"definition-description\">Calls it directly.</p>", 1, true)
				expect(hasDescription).to.exist()

				local _, count = string.gsub(html, "definition%-description", "")
				expect(count).to.equal(1)
			end
		},

		{
			name = "States the margin plainly when only two candidates are compared",
			func = function(state)
				local html = INTERNET_BENCHMARK:HTMLTab("example", state.timing, state.stats, state.trial)

				local hasNote = string.find(html, "Beats the other option by 80%.", 1, true)
				expect(hasNote).to.exist()

				local hasOldPhrasing = string.find(html, "and the slowest by", 1, true)
				expect(hasOldPhrasing).to.beNil()
			end
		},

		{
			name = "Includes the trial pre-definitions and configuration",
			func = function(state)
				local html = INTERNET_BENCHMARK:HTMLTab("example", state.timing, state.stats, state.trial)

				local hasPredefine = string.find(html, "local threshold = 5", 1, true)
				expect(hasPredefine).to.exist()

				local hasIterations = string.find(html, "Iterations / run 10", 1, true)
				expect(hasIterations).to.exist()
			end
		},

		{
			name = "Plots the measured timings into the box plot",
			func = function(state)
				local html = INTERNET_BENCHMARK:HTMLTab("example", state.timing, state.stats, state.trial)

				local hasTrack = string.find(html, "boxplot-track", 1, true)
				expect(hasTrack).to.exist()

				local hasLabel = string.find(html, "boxplot-row-name\">First Way<", 1, true)
				expect(hasLabel).to.exist()
			end
		},

		{
			name = "Tags each trial's view section for client-side routing",
			func = function(state)
				local html = INTERNET_BENCHMARK:HTMLTab("example", state.timing, state.stats, state.trial)

				local hasSection = string.find(html, "data-view-section=\"trial:example\"", 1, true)
				expect(hasSection).to.exist()
			end
		},

		{
			name = "Returns an overview summary alongside the rendered view",
			func = function(state)
				local _, summary = INTERNET_BENCHMARK:HTMLTab("example", state.timing, state.stats, state.trial)

				expect(summary.id).to.equal("example")
				expect(summary.candidateCount).to.equal(2)
				expect(summary.winnerLabel).to.exist()
			end
		},

		{
			name = "Writes report assets into the data directory",
			func = function()
				INTERNET_BENCHMARK:WriteAsset("style.css")

				local written = file.Read("internet_benchmarks/style.css.txt", "DATA")
				expect(written).to.exist()

				local source = file.Read("internet_benchmark/templates/html/style.css.lua", "LUA")
				expect(written).to.equal(source)
			end,

			cleanup = function()
				file.Delete("internet_benchmarks/style.css.txt")
			end
		},

		{
			name = "Builds a trial's JSON-exportable data with per-function stats",
			func = function(state)
				local data = INTERNET_BENCHMARK:TrialResultsData(state.stats, state.trial)

				expect(data.id).to.equal("example")
				expect(data.name).to.equal("Example Trial")
				expect(data.runs).to.equal(2)
				expect(data.iterations).to.equal(10)
				expect(#data.functions).to.equal(2)

				local first = data.functions[1]
				expect(first.label).to.equal("First Way")
				expect(first.median).to.beA("number")
				expect(first.min).to.beA("number")
				expect(first.max).to.beA("number")
				expect(first.mean).to.beA("number")
				expect(first.average).to.beA("number")
				expect(first.percentage).to.equal(100)
			end
		},

		{
			name = "Writes results.json.txt alongside the HTML report",
			func = function(state)
				stub(INTERNET_BENCHMARK, "ReportAll").returns({
					{state.timing, state.stats, state.trial, order = 0}
				})

				INTERNET_BENCHMARK:HTMLReport()

				local written = file.Read("internet_benchmarks/results.json.txt", "DATA")
				expect(written).to.exist()

				local data = util.JSONToTable(written)
				expect(data).to.beA("table")
				expect(data.environment).to.beA("table")
				expect(data.environment["Suite Version"]).to.equal(INTERNET_BENCHMARK.Version)
				expect(#data.trials).to.equal(1)
				expect(data.trials[1].id).to.equal("example")
			end,

			cleanup = function()
				file.Delete("internet_benchmarks/results.json.txt")
				file.Delete("internet_benchmarks/report.html.txt")
				file.Delete("internet_benchmarks/environment.txt")
			end
		}
	}
}
