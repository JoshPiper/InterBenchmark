--- Report generation.
--- Runs trials, computes their statistics and renders the HTML report.

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

local t, f, l = BENCH.Templating, BENCH.Formatting, BENCH.Logging

--- A function's mean as a percentage of the trial's fastest mean.
--- Guards against a zero minimum, which a too-coarse timer can produce.
local function percentageOf(mean, minMean)
	if minMean <= 0 then
		return 100
	end

	return (mean / minMean) * 100
end

--- Benchmark one trial and compute its statistics.
--- @param name string The trial's file name, without extension.
--- @param dynamic boolean? Recalibrate the trial's iteration count instead
--- of using its authored or default count. Defaults to false.
--- @param test boolean? Force a low, fixed iteration and run count.
--- Combining this with dynamic is not meaningful and is rejected by the
--- console commands before it reaches here. Defaults to false.
--- @param includeTags table? Only run the trial if it has one of these tags.
--- Empty or omitted matches every trial.
--- @param excludeTags table? Skip the trial if it has one of these tags,
--- taking precedence over includeTags.
--- @see BENCH.CalibrateIterations
--- @return table? results
--- @return table? statistics
--- @return table? trial
function BENCH:ReportTrial(name, dynamic, test, includeTags, excludeTags)
	local results, trial = self:Trial(name, dynamic, test, includeTags, excludeTags)
	if not results then
		return nil
	end

	return results, self:Statistics(results, trial.iterations), trial
end

--- Discover every trial on disk.
--- @return table # A sorted list of trial names.
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
--- Trials which are missing, gated off, tag-filtered or empty are skipped.
--- @param dynamic boolean? Recalibrate every trial's iteration count
--- instead of using its authored or default count. Defaults to false.
--- @param test boolean? Force a low, fixed iteration and run count for every
--- trial. Combining this with dynamic is not meaningful and is rejected by
--- the console commands before it reaches here. Defaults to false.
--- @param includeTags table? Only run trials which have one of these tags.
--- Empty or omitted matches every trial. @see BENCH.TagsMatch
--- @param excludeTags table? Skip trials which have one of these tags,
--- taking precedence over includeTags.
--- @return table # A list of {results, statistics, trial, order = n} entries.
function BENCH:ReportAll(dynamic, test, includeTags, excludeTags)
	local reports = {}
	local names = self:TrialNames()

	for idx, name in ipairs(names) do
		l.ForceInfo(string.format("Trial '%s' (%d of %d)", name, idx, #names))
		local results, statistics, trial = self:ReportTrial(name, dynamic, test, includeTags, excludeTags)
		if results then
			table.insert(reports, {results, statistics, trial, order = trial.order or 0})
		end

		self:Yield()
	end

	return reports
end

--- A row's severity class, driving its accent colour.
--- @param pct number The row's percentage of the trial's fastest mean.
--- @param twoTier boolean? Skip the intermediate "notable" tier, for spots
--- (like the sidebar) that only distinguish "fine" from "critical". Defaults to false.
--- @return string # A CSS class, or "" for the default (muted) tier.
function BENCH:SeverityClass(pct, twoTier)
	if pct >= 200 then
		return "sev-critical"
	end

	if not twoTier and pct >= 105 then
		return "sev-warn"
	end

	return ""
end

--- Render the environment page's summary tiles.
--- @return string # The concatenated tile markup.
function BENCH:HTMLEnvironmentHighlights()
	local tiles = {}
	for _, pair in ipairs(self.Environment:Highlights()) do
		table.insert(tiles, t:Template("partial/env-highlight", {
			label = f.EscapeHTML(pair[1]),
			value = f.EscapeHTML(tostring(pair[2]))
		}))
	end

	return table.concat(tiles, "\n")
end

--- Render the environment page's grouped detail sections.
--- @return string # The concatenated group markup.
function BENCH:HTMLEnvironmentGroups()
	local groups = {}
	for _, group in ipairs(self.Environment:Groups()) do
		local rows = {}
		for _, pair in ipairs(group[2]) do
			table.insert(rows, t:Template("partial/env-row", {
				label = f.EscapeHTML(pair[1]),
				value = f.EscapeHTML(tostring(pair[2]))
			}))
		end

		table.insert(groups, t:Template("partial/env-group", {
			title = f.EscapeHTML(group[1]),
			rows = table.concat(rows, "\n")
		}))
	end

	return table.concat(groups, "\n")
end

--- Build one trial's plain-data results, for the JSON export.
--- Reads stats.minMean before HTMLTab (which runs later in HTMLReport's own
--- trial loop) clears it, so this must be called first.
--- @param stats table Per-function statistics, with a minMean key.
--- @param trial table The trial.
--- @return table # {id, name, order, runs, iterations, functions}
function BENCH:TrialResultsData(stats, trial)
	local minMean = stats.minMean
	local labels = trial.labels or {}

	local functions = {}
	for fnId, stat in ipairs(stats) do
		table.insert(functions, {
			id = fnId,
			label = labels[fnId] or ("Function #" .. fnId),
			median = stat.median,
			min = stat.min,
			max = stat.max,
			mean = stat.mean,
			average = stat.average,
			percentage = percentageOf(stat.mean, minMean)
		})
	end

	return {
		id = trial.id,
		name = trial.name or trial.id,
		order = trial.order or 0,
		runs = trial.runs,
		iterations = trial.iterations,
		functions = functions
	}
end

--- Build the raw results table written to results.json.
--- @param reports table A list of {results, statistics, trial, order = n}
--- entries, as returned by ReportAll.
--- @return table # {environment = {...}, trials = {...}}
function BENCH:ResultsData(reports)
	local trials = {}
	for _, data in SortedPairsByMemberValue(reports, "order") do
		table.insert(trials, self:TrialResultsData(data[2], data[3]))
	end

	return {
		environment = self.Environment:Data(),
		trials = trials
	}
end

--- Generate the full HTML report.
--- Writes report.html.txt, results.json and environment.txt to
--- data/internet_benchmarks/. The report is a single self-contained file:
--- its stylesheet and script are inlined, so nothing else needs to travel
--- alongside it.
--- @param dynamic boolean? Recalibrate every trial's iteration count
--- instead of using its authored or default count. Defaults to false.
--- @param test boolean? Force a low, fixed iteration and run count for every
--- trial. Combining this with dynamic is not meaningful and is rejected by
--- the console commands before it reaches here. Defaults to false.
--- @param includeTags table? Only run trials which have one of these tags.
--- Empty or omitted matches every trial. @see BENCH.TagsMatch
--- @param excludeTags table? Skip trials which have one of these tags,
--- taking precedence over includeTags.
--- @return string? # The rendered report, so callers (like the client's report
--- viewer) can use it without reading it back off disk.
--- @return table? # A short overview summary (trials, candidates, widestPct, widestName, tieCount) for callers like the realm bridge.
function BENCH:HTMLReport(dynamic, test, includeTags, excludeTags)
	self.Environment:Report()

	local reports = self:ReportAll(dynamic, test, includeTags, excludeTags)
	if #reports == 0 then
		l.Warning("No trials produced results; the report was not written.")
		return
	end

	l.ForceInfo("Generating the HTML report.")

	-- Computed before the tab loop below, which mutates each trial's
	-- statistics table (clearing minMean, adding percentage) as it renders.
	local resultsData = self:ResultsData(reports)

	local tabs, summaries = {}, {}
	local totalCandidates = 0

	for _, data in SortedPairsByMemberValue(reports, "order") do
		local timing, statistics, trial = data[1], data[2], data[3]

		local html, summary = self:HTMLTab(trial.id, timing, statistics, trial)
		table.insert(tabs, html)
		table.insert(summaries, summary)
		totalCandidates = totalCandidates + summary.candidateCount

		self:Yield()
	end

	local maxWorst, widestName, tieCount = 0, "-", 0
	for _, summary in ipairs(summaries) do
		if summary.worstPct > maxWorst then
			maxWorst = summary.worstPct
			widestName = summary.title
		end

		if summary.worstPct <= 105 then
			tieCount = tieCount + 1
		end
	end

	local headers, overviewRows = {}, {}
	for _, summary in ipairs(summaries) do
		table.insert(headers, t:Template("nav/tab", {
			key = summary.id,
			title = summary.title,
			spread = summary.worstPct .. "%",
			spreadClass = self:SeverityClass(summary.worstPct, true)
		}))

		table.insert(overviewRows, t:Template("partial/overview-row", {
			key = summary.id,
			name = summary.title,
			countLabel = summary.candidateCount .. " candidates",
			winner = summary.winnerLabel,
			winnerPerCall = summary.winnerPerCall,
			spread = summary.worstPct .. "%",
			spreadClass = self:SeverityClass(summary.worstPct, false),
			barW = math.max(3, summary.worstPct / maxWorst * 100)
		}))
	end

	local overview = t:Template("overview", {
		totalTrials = #summaries,
		totalCandidates = totalCandidates,
		widestSpread = maxWorst .. "%",
		widestName = widestName,
		tieCount = tieCount,
		rows = table.concat(overviewRows, "\n")
	})

	local environment = t:Template("environment", {
		highlights = self:HTMLEnvironmentHighlights(),
		groups = self:HTMLEnvironmentGroups()
	})

	local report = t:Template("document", {
		summary = string.format("%d trials &middot; %d candidates", #summaries, totalCandidates),
		navTrials = table.concat(headers, "\n"),
		overview = overview,
		environment = environment,
		trials = table.concat(tabs, "\n"),
		style = self:ReadAsset("style.css"),
		script = self:ReadAsset("script.js")
	})

	self:WriteOutput("report.html.txt", report)
	self:WriteOutput("results.json", util.TableToJSON(resultsData, true))
	self.Environment:Write()

	l.ForceInfo("The report has been written to garrysmod/data/internet_benchmarks/.")
	l.ForceInfo("To view it: rename report.html.txt to report.html, then open it in a browser.")
	l.ForceInfo("(Garry's Mod can only write a limited set of file extensions, hence the .txt suffix.)")

	if CLIENT and self.OpenReport then
		self:OpenReport(report)
	end

	return report, {
		trials = #summaries,
		candidates = totalCandidates,
		widestPct = maxWorst,
		widestName = widestName,
		tieCount = tieCount
	}
end

--- Read an asset out of the templates directory.
--- @param name string The asset's file name, without the .lua suffix.
--- @return string # The asset's content, or "" when it could not be read.
function BENCH:ReadAsset(name)
	local content = file.Read("internet_benchmark/templates/html/" .. name .. ".lua", "LUA")
	if not content then
		l.Warning(string.format("Asset '%s' could not be read; an empty file was used.", name))
		content = ""
	end

	return content
end

--- Copy a static asset out of the templates directory, as a .txt file.
--- @param name string The asset's file name, without the .lua suffix.
function BENCH:WriteAsset(name)
	self:WriteOutput(name .. ".txt", self:ReadAsset(name))
end

--- Generate a single trial's report view.
--- @param id string The trial's identifier.
--- @param timing table Per-function run-time tables.
--- @param stats table Per-function statistics, with a minMean key.
--- @param trial table The trial.
--- @return string view The rendered view.
--- @return table summary A summary for the overview page and sidebar: id, title,
--- worstPct, candidateCount, winnerLabel, winnerPerCall.
function BENCH:HTMLTab(id, timing, stats, trial)
	l.Debug(string.format("Generating tab for '%s'.", id))

	local labels = trial.labels or {}
	local descriptions = trial.descriptions or {}
	local title = f.EscapeHTML(f.Title(trial.name or id))
	local description = trial.description and string.format("<p>%s</p>", f.EscapeHTML(trial.description)) or ""

	local minMean = stats.minMean
	stats.minMean = nil

	local timePairs = {median = {}, min = {}, max = {}, mean = {}, average = {}}
	local lo, hi = math.huge, -math.huge
	for _, stat in ipairs(stats) do
		table.insert(timePairs.median, stat.median)
		table.insert(timePairs.min, stat.min)
		table.insert(timePairs.max, stat.max)
		table.insert(timePairs.mean, stat.mean)
		table.insert(timePairs.average, stat.average)
		stat.percentage = percentageOf(stat.mean, minMean)

		lo = math.min(lo, stat.min)
		hi = math.max(hi, stat.max)
	end

	-- Timings span orders of magnitude within a trial, so bars and the box
	-- plot share one log domain, padded either side of the data.
	lo = lo / 1.35
	hi = hi * 1.1

	-- A zero lower bound would make the log domain infinite, and every coordinate NaN.
	if lo <= 0 and hi > 0 then
		lo = hi / 1000
	end

	local span = lo > 0 and math.log(hi / lo) or 0
	local function pos(v)
		if span <= 0 then
			return 0
		end

		return math.Clamp(math.log(v / lo) / span * 100, 0, 100)
	end

	local resultRows, boxRows = {}, {}
	local winnerFnId, winnerStat
	local worstPct, secondPct = 0, 100
	local i = 1

	for fnId, stat in SortedPairsByMemberValue(stats, "mean") do
		if i == 1 then
			winnerFnId, winnerStat = fnId, stat
		elseif i == 2 then
			secondPct = math.Round(stat.percentage)
		end
		worstPct = math.max(worstPct, stat.percentage)

		local name = f.EscapeHTML(labels[fnId] or ("Function #" .. fnId))
		local severity = i == 1 and "sev-warn" or self:SeverityClass(stat.percentage, false)

		table.insert(resultRows, t:Template("partial/result-row", {
			rank = i,
			func = name,
			severity = severity,
			median = f:AutoNumbers(stat.median, timePairs.median, (stat.median < 10 and stat.median >= 1) and 3 or 2) .. "s",
			min = f:AutoNumbers(stat.min, timePairs.min, (stat.min < 10 and stat.min >= 1) and 3 or 2) .. "s",
			max = f:AutoNumbers(stat.max, timePairs.max, (stat.max < 10 and stat.max >= 1) and 3 or 2) .. "s",
			mean = f:AutoNumbers(stat.mean, timePairs.mean, (stat.mean < 10 and stat.mean >= 1) and 3 or 2) .. "s",
			meanPerCall = f:AutoNumbers(stat.average, timePairs.average, (stat.average < 10 and stat.average >= 1) and 3 or 2) .. "s",
			percentage = math.Round(stat.percentage) .. "%",
			barW = math.max(4, pos(stat.mean))
		}))

		table.insert(boxRows, t:Template("partial/boxplot-row", {
			func = name,
			whiskerLeft = pos(stat.min),
			whiskerW = pos(stat.max) - pos(stat.min),
			maxLeft = pos(stat.max),
			boxLeft = pos(stat.q1),
			boxW = pos(stat.q3) - pos(stat.q1),
			medLeft = pos(stat.median),
			avgLeft = pos(stat.mean),
			range = f:AutoNumber(stat.min, nil, 2) .. "s – " .. f:AutoNumber(stat.max, nil, 2) .. "s"
		}))

		i = i + 1
	end
	worstPct = math.Round(worstPct)

	local predefines = {}
	for _, predefine in ipairs(trial.predefineSources or {}) do
		table.insert(predefines, f.EscapeHTML(predefine))
	end

	local tests = {}
	for fnId in ipairs(trial.functions) do
		local source = trial.functionSources and trial.functionSources[fnId] or "-- Source unavailable."
		local candidateDescription = descriptions[fnId]
		table.insert(tests, t:Template("partial/definition", {
			title = f.EscapeHTML(labels[fnId] or ("Function #" .. fnId)),
			tag = fnId == winnerFnId and "<span class=\"tag tag-accent\">Fastest</span>" or "",
			description = candidateDescription and string.format("<p class=\"definition-description\">%s</p>", f.EscapeHTML(candidateDescription)) or "",
			content = t:Template("partial/predefine", f.EscapeHTML(source))
		}))
	end

	local winnerLabel = f.EscapeHTML(labels[winnerFnId] or ("Function #" .. winnerFnId))
	local winnerPerCall = f:AutoNumber(winnerStat.average, nil, 2) .. "s"

	local winnerNote
	if secondPct <= 105 then
		winnerNote = string.format("Within %d%% of the next candidate — effectively a tie at this sample size.", secondPct - 100)
	elseif #trial.functions <= 2 then
		-- With only two candidates, "next" and "slowest" are the same
		-- function - stating its percentage twice would just be noise.
		winnerNote = string.format("Beats the other option by %d%%.", secondPct - 100)
	else
		winnerNote = string.format("Beats the next candidate by %d%%, and the slowest by %d%%.", secondPct - 100, worstPct - 100)
	end

	local html = t:Template("tab", {
		key = id,
		runs = trial.runs,
		iterations = trial.iterations,
		title = title,
		description = description,
		candidateLabel = #trial.functions .. " candidates",
		winnerName = winnerLabel,
		winnerAvg = f:AutoNumber(winnerStat.mean, nil, 2) .. "s",
		winnerPerCall = winnerPerCall,
		trialSpread = worstPct .. "%",
		winnerNote = winnerNote,
		results = table.concat(resultRows, "\n"),
		boxplot = table.concat(boxRows, "\n"),
		axisMin = f:AutoNumber(lo, nil, 2) .. "s",
		axisMax = f:AutoNumber(hi, nil, 2) .. "s",
		tests = table.concat(tests, "\n"),
		predefines = t:Template("partial/predefine", table.concat(predefines, "\n"))
	})

	return html, {
		id = id,
		title = title,
		worstPct = worstPct,
		candidateCount = #trial.functions,
		winnerLabel = winnerLabel,
		winnerPerCall = winnerPerCall
	}
end

--- Benchmark a single trial and print its results to the console.
--- @param name string The trial's file name, without extension.
--- @param dynamic boolean? Recalibrate the trial's iteration count instead
--- of using its authored or default count. Defaults to false.
--- @param test boolean? Force a low, fixed iteration and run count.
--- Combining this with dynamic is not meaningful and is rejected by the
--- console commands before it reaches here. Defaults to false.
--- @return table? # The formatted lines that were logged, for callers like the realm bridge; nil when the trial did not run.
function BENCH:ConsoleReport(name, dynamic, test)
	local results, statistics, trial = self:ReportTrial(name, dynamic, test)
	if not results then
		l.ForceWarning(string.format("Trial '%s' did not run (missing, gated off, or empty).", name))
		return nil
	end

	local minMean = statistics.minMean
	statistics.minMean = nil

	local labels = trial.labels or {}
	local lines = {}
	table.insert(lines, string.format(
		"Results for '%s' (%d runs of %d iterations):",
		trial.name or name, trial.runs, trial.iterations
	))

	local i = 1
	for fnId, stat in SortedPairsByMemberValue(statistics, "mean") do
		table.insert(lines, string.format(
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

	for _, line in ipairs(lines) do
		l.ForceInfo(line)
	end

	return lines
end

--- Generate the HTML report in the background.
--- @param dynamic boolean? Recalibrate every trial's iteration count
--- instead of using its authored or default count. Defaults to false.
--- @param test boolean? Force a low, fixed iteration and run count for every
--- trial. Combining this with dynamic is not meaningful and is rejected by
--- the console commands before it reaches here. Defaults to false.
--- @param includeTags table? Only run trials which have one of these tags.
--- Empty or omitted matches every trial. @see BENCH.TagsMatch
--- @param excludeTags table? Skip trials which have one of these tags,
--- taking precedence over includeTags.
--- @return boolean # Whether the job was started.
function BENCH:ReportWithoutCrashing(dynamic, test, includeTags, excludeTags)
	return self:Async(function()
		self:HTMLReport(dynamic, test, includeTags, excludeTags)
	end)
end
