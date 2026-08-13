--- Report generation.
-- Runs trials, computes their statistics and renders the HTML report.
-- @module reporting

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

local t, f, l = BENCH.Templating, BENCH.Formatting, BENCH.Logging

--- A function's mean as a percentage of the trial's fastest mean.
-- Guards against a zero minimum, which a too-coarse timer can produce.
local function percentageOf(mean, minMean)
	if minMean <= 0 then
		return 100
	end

	return (mean / minMean) * 100
end

--- Benchmark one trial and compute its statistics.
-- @string name The trial's file name, without extension.
-- @bool[opt=false] dynamic Recalibrate the trial's iteration count instead
-- of using its authored or default count. @see BENCH:CalibrateIterations
-- @return results, statistics, trial — or nil when the trial did not run.
function BENCH:ReportTrial(name, dynamic)
	local results, trial = self:Trial(name, dynamic)
	if not results then
		return nil
	end

	return results, self:Statistics(results, trial.iterations), trial
end

--- Discover every trial on disk.
-- @rtab A sorted list of trial names.
function BENCH:TrialNames()
	local names = {}
	local files = file.Find("internet_benchmark/trials/*.lua", "LUA")
	for _, name in ipairs(files) do
		name = string.sub(name, 1, #name - 4)
		if name:EndsWith(".meta") then
			name = string.sub(name, 1, #name - 5)
		end
		names[name] = true
	end

	names = table.GetKeys(names)
	table.sort(names)
	return names
end

--- Benchmark every trial on disk.
-- Trials which are missing, gated off or empty are skipped.
-- @bool[opt=false] dynamic Recalibrate every trial's iteration count
-- instead of using its authored or default count.
-- @rtab A list of {results, statistics, trial, order = n} entries.
function BENCH:ReportAll(dynamic)
	local reports = {}
	local names = self:TrialNames()

	for idx, name in ipairs(names) do
		l.ForceInfo(string.format("Trial '%s' (%d of %d)", name, idx, #names))
		local results, statistics, trial = self:ReportTrial(name, dynamic)
		if results then
			table.insert(reports, {results, statistics, trial, order = trial.order or 0})
		end

		self:Yield()
	end

	return reports
end

--- Generate the full HTML report.
-- Writes report.html.txt, style.css.txt, script.js.txt and environment.txt
-- to data/internet_benchmarks/.
-- @bool[opt=false] dynamic Recalibrate every trial's iteration count
-- instead of using its authored or default count.
function BENCH:HTMLReport(dynamic)
	self.Environment:Report()

	local reports = self:ReportAll(dynamic)
	if #reports == 0 then
		l.Warning("No trials produced results; the report was not written.")
		return
	end

	local headers, tabs = {}, {}
	local first = true

	l.ForceInfo("Generating the HTML report.")
	for _, data in SortedPairsByMemberValue(reports, "order") do
		local timing, statistics, trial = data[1], data[2], data[3]
		local id = trial.id

		table.insert(headers, t:Template("nav/tab", {
			key = id,
			title = f.EscapeHTML(f.Title(trial.name or id))
		}))
		table.insert(tabs, self:HTMLTab(id, timing, statistics, trial, first))
		first = false

		self:Yield()
	end

	local report = t:Template("document", {
		nav = table.concat(headers, "\n"),
		body = table.concat(tabs, "\n")
	})

	self:WriteOutput("report.html.txt", report)
	self:WriteAsset("style.css")
	self:WriteAsset("script.js")
	self.Environment:Write()

	l.ForceInfo("The report has been written to garrysmod/data/internet_benchmarks/.")
	l.ForceInfo("To view it: rename report.html.txt to report.html, style.css.txt to style.css and script.js.txt to script.js, then open report.html in a browser.")
	l.ForceInfo("(Garry's Mod can only write a limited set of file extensions, hence the .txt suffixes.)")
end

--- Copy a static asset out of the templates directory, as a .txt file.
-- @string name The asset's file name, without the .lua suffix.
function BENCH:WriteAsset(name)
	local content = file.Read("internet_benchmark/templates/html/" .. name .. ".lua", "LUA")
	if not content then
		l.Warning(string.format("Asset '%s' could not be read; an empty file was written.", name))
		content = ""
	end

	self:WriteOutput(name .. ".txt", content)
end

--- Generate a single trial's report tab.
-- @string id The trial's identifier.
-- @tab timing Per-function run-time tables.
-- @tab stats Per-function statistics, with a minMean key.
-- @tab trial The trial.
-- @bool first Whether this is the report's initially active tab.
-- @rstring The rendered tab.
function BENCH:HTMLTab(id, timing, stats, trial, first)
	l.Debug(string.format("Generating tab for '%s'.", id))

	local predefines = {}
	for _, predefine in ipairs(trial.predefineSources or {}) do
		table.insert(predefines, f.EscapeHTML(predefine))
	end

	local labels = trial.labels or {}
	local tests = {}
	for fnId in ipairs(trial.functions) do
		local source = trial.functionSources and trial.functionSources[fnId] or "-- Source unavailable."
		table.insert(tests, t:Template("partial/definition", {
			title = f.EscapeHTML(labels[fnId] or ("Function #" .. fnId)),
			content = t:Template("partial/predefine", f.EscapeHTML(source))
		}))
	end

	local minMean = stats.minMean
	stats.minMean = nil

	local timePairs = {median = {}, min = {}, max = {}, mean = {}, average = {}}
	for _, stat in ipairs(stats) do
		table.insert(timePairs.median, stat.median)
		table.insert(timePairs.min, stat.min)
		table.insert(timePairs.max, stat.max)
		table.insert(timePairs.mean, stat.mean)
		table.insert(timePairs.average, stat.average)
		stat.percentage = percentageOf(stat.mean, minMean)
	end

	local dataRows, meanRows = {}, {}
	for fnId, stat in ipairs(stats) do
		local name = labels[fnId] or ("Function #" .. fnId)
		table.insert(dataRows, string.format(
			[[{ x: %s, label: %q, y: [%s, %s, %s, %s, %s]}]],
			fnId - 1, name, stat.min, stat.q1, stat.q3, stat.max, stat.median
		))
		table.insert(meanRows, string.format(
			[[{ x: %s, label: %q, y: [%s, %s]}]],
			fnId - 1, name, stat.mean, stat.mean
		))
	end

	local maxDigits = math.floor(math.log10(#trial.functions)) + 1
	local idxFormat = string.format("%%0%du", maxDigits)

	local rows = {}
	local i = 1
	for fnId, stat in SortedPairsByMemberValue(stats, "mean") do
		table.insert(rows, t:Template("partial/row", {
			idx = string.format(idxFormat, i),
			func = f.EscapeHTML(labels[fnId] or ("Function #" .. fnId)),
			median = f:AutoNumbers(stat.median, timePairs.median, (stat.median < 10 and stat.median >= 1) and 3 or 2) .. "s",
			min = f:AutoNumbers(stat.min, timePairs.min, (stat.min < 10 and stat.min >= 1) and 3 or 2) .. "s",
			max = f:AutoNumbers(stat.max, timePairs.max, (stat.max < 10 and stat.max >= 1) and 3 or 2) .. "s",
			mean = f:AutoNumbers(stat.mean, timePairs.mean, (stat.mean < 10 and stat.mean >= 1) and 3 or 2) .. "s",
			meanPerCall = f:AutoNumbers(stat.average, timePairs.average, (stat.average < 10 and stat.average >= 1) and 3 or 2) .. "s",
			percentage = math.Round(stat.percentage) .. "%"
		}))
		i = i + 1
	end

	local results = t:Template("partial/table", {
		header = t:Template("partial/header"),
		body = table.concat(rows, "\n")
	})

	local graph = t:Template("partial/graph-clean", {
		key = id,
		title = f.Title(trial.name or id),
		data = table.concat(dataRows, ",\n"),
		outliers = table.concat(meanRows, ",\n"),
	})

	return t:Template("tab", {
		key = id,
		runs = trial.runs,
		iterations = trial.iterations,
		title = f.EscapeHTML(f.Title(trial.name or id)),
		class = first and "active" or "",
		predefines = string.format("<code><pre>%s</pre></code>", table.concat(predefines, "\n")),
		tests = table.concat(tests, "\n"),
		content = results .. "\n" .. graph
	})
end

--- Benchmark a single trial and print its results to the console.
-- @string name The trial's file name, without extension.
-- @bool[opt=false] dynamic Recalibrate the trial's iteration count instead
-- of using its authored or default count.
function BENCH:ConsoleReport(name, dynamic)
	local results, statistics, trial = self:ReportTrial(name, dynamic)
	if not results then
		l.ForceWarning(string.format("Trial '%s' did not run (missing, gated off, or empty).", name))
		return
	end

	local minMean = statistics.minMean
	statistics.minMean = nil

	local labels = trial.labels or {}
	l.ForceInfo(string.format(
		"Results for '%s' (%d runs of %d iterations):",
		trial.name or name, trial.runs, trial.iterations
	))

	local i = 1
	for fnId, stat in SortedPairsByMemberValue(statistics, "mean") do
		l.ForceInfo(string.format(
			"%2d. %s: median %ss, mean %ss (%ss/call), %d%%",
			i,
			labels[fnId] or ("Function #" .. fnId),
			f:AutoNumber(stat.median, nil, 3),
			f:AutoNumber(stat.mean, nil, 3),
			f:AutoNumber(stat.average, nil, 3),
			math.Round(percentageOf(stat.mean, minMean))
		))
		i = i + 1
	end
end

--- Generate the HTML report in the background.
-- @bool[opt=false] dynamic Recalibrate every trial's iteration count
-- instead of using its authored or default count.
-- @rbool Whether the job was started.
function BENCH:ReportWithoutCrashing(dynamic)
	return self:Async(function()
		self:HTMLReport(dynamic)
	end)
end
