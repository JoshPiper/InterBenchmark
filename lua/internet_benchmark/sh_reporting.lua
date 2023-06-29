INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

local yieldable, yield, resume, status = coroutine.isyieldable, coroutine.yield, coroutine.resume, coroutine.status

local t, f, l = BENCH.Templating, BENCH.Formatting, BENCH.Logging

function BENCH:ReportTrial(trial)
	local _yieldable = yieldable()
	local doTrial = coroutine.create(function()
		return self:Trial(trial)
	end)

	local state, results, trialInfo = status(doTrial), {}
	while state == "suspended" do
		_, results, trialInfo = resume(doTrial)
		l.Debug("Recieved Yield in ReportTrial from Trial")
		if _yieldable then
			l.Debug("Deferring Yield")
			yield()
		end
		state = status(doTrial)
	end

	local statistics = self:Statistics(results)
	return results, statistics, trialInfo
end

function BENCH:ReportAll()
	local _yieldable = yieldable()

	local trials = {}
	local trialFiles = file.Find("internet_benchmark/trials/*", "LUA")
	for _, trial in ipairs(trialFiles) do
		trial = string.sub(trial, 1, #trial - 4)
		if trial:EndsWith(".meta") then
			trial = string.sub(trial, 1, #trial - 5)
		end
		trials[trial] = true
	end

	trials = table.GetKeys(trials)
	for idx, trial in ipairs(trials) do
		local doTrial = coroutine.create(function()
			return self:ReportTrial(trial)
		end)

		local state, results, statistics = status(doTrial), nil, nil
		while state == "suspended" do
			_, results, statistics, trial = resume(doTrial)
			l.Debug("Recieved Yield in ReportAll from ReportTrial")
			if _yieldable then
				l.Debug("Deferring Yield")
				yield()
			end
			state = status(doTrial)
		end

		trials[idx] = {results, statistics, trial, order = trial.order or 0}
	end

	return trials
end

function BENCH:HTMLReport()
	local headers, tabs = {}, {}
	local _yieldable = yieldable()

	local doAllTrials = coroutine.create(function()
		return self:ReportAll()
	end)

	local state, info = status(doAllTrials), nil
	while state == "suspended" do
		_, info = resume(doAllTrials)
		l.Debug("Recieved Yield in HTMLReport from ReportAll")
		if _yieldable then
			l.Debug("Deferring Yield")
			yield()
		end
		state = status(doAllTrials)
	end

	for i, data in SortedPairsByMemberValue(info, "order") do
		local timing, statistics, trial = unpack(data)
		local id = trial.id or i

		local nav = t:Template("nav/tab", {
			key = id,
			title = f.Title(trial.title or id)
		})
		table.insert(headers, nav)
		table.insert(tabs, self:HTMLTab(id, timing, statistics, trial))
		first = nil
	end

	local report = t:Template("document", {
		nav = table.concat(headers, "\n"),
		body = table.concat(tabs, "\n")
	})

	file.CreateDir("internet_benchmarks")
	file.Write("internet_benchmarks/report.html.txt", report)
	file.Write("internet_benchmarks/style.css.txt", file.Read("internet_benchmarks/templates/html/style.css.lua", "LUA"))
	file.Write("internet_benchmarks/script.js.txt", file.Read("internet_benchmarks/templates/html/script.js.lua", "LUA"))
end

function BENCH:HTMLTab(id, timing, stats, trial)
	local first = id == 1
	l.Debug("Generating tab for ", id)

	local sections = {}
	local predefines = {}
	local codes = {}
	local excluded = trial.excludedVars or {}

	l.Debug("Generating Pre-Definitions.")
	for _, predefine in pairs(trial.predefines or {}) do
		table.insert(predefines, predefine)
	end
	print(id)

	-- l.Debug("Generating Upvalues.")
	-- for fnId, fn in ipairs(trial.functions) do
	-- 	for var, val in pairs(fn.info.upvars) do
	-- 		if not excluded[var] then
	-- 			if isstring(val) then
	-- 				table.insert(predefines, string.format("local %s = %s", var, val))
	-- 			elseif istable(val) then
	-- 				local typ, dt = val[1], val[2]
	-- 				if typ == "raw" then
	-- 					table.insert(predefines, dt)
	-- 				end
	-- 			end
	-- 		end
	-- 	end

	-- 	codes[fnId] = fn.info.source
	-- end

	-- local seen = {}
	-- local defines = {}
	-- for _, define in ipairs(predefines) do
	-- 	if not seen[define] then
	-- 		seen[define] = true
	-- 		table.insert(defines, define)
	-- 	end
	-- end
	-- predefines = defines

	-- print("\t\tGenerating HTML.")
	table.insert(sections, string.format("<h2 id='%s'>%s</h2>", id, f.Title(trial.title or id)))
	print(id, string.format("<h2 id='%s'>%s</h2>", id, f.Title(trial.title or id)))
	-- if #predefines > 0 then

	-- end

	local functions = {}
	-- for funcIdx, code in ipairs(codes) do
	-- 	table.insert(functions, t:Template("partial/definition", {
	-- 		title = data.functions[funcIdx].title,
	-- 		content = t:Template("partial/predefine", code)
	-- 	}))
	-- end

	local results = {}
	table.insert(results, [[
		<tr>
			<th>#</th>
			<th>Name</th>
			<th>Median</th>
			<th>Minimum</th>
			<th>Maximum</th>
			<th>Average</th>
			<th>Average/Call</th>
			<th>Percentage</th>
		</tr>
	]])

	local timePairs = {
		median = {},
		min = {},
		max = {},
		mean = {},
		average = {},
		percentage = {}
	}
	local minMean = stats.minMean

	-- print("hi")

	for fnId, _ in ipairs(timing) do
		local stat = stats[fnId]
		table.insert(timePairs.median, stat.median)
		table.insert(timePairs.min, stat.min)
		table.insert(timePairs.max, stat.max)
		table.insert(timePairs.mean, stat.mean)
		table.insert(timePairs.average, stat.average)
		stat.percentage = (stat.mean / minMean) * 100
		table.insert(timePairs.percentage, stat.percentage)
	end

	local i = 1
	local maxDigits = math.floor(math.log10(#trial.functions)) + 1

	-- print("hi2")
	-- PrintTable(timing)
	stats.minMean = nil

	local rows = {}
	local dataRows = {}
	local outlierRows = {}
	local meanRows = {}
	for fnId, stat in ipairs(stats) do
		local name = trial.labels[fnId] or ("Function #" .. fnId)
		table.insert(dataRows, string.format(
			[[{ x: %s, label: "%s",  y: [%s, %s, %s, %s, %s]}]],
			fnId - 1,
			name,
			stat.min,
			stat.q1,
			stat.q3,
			stat.max,
			stat.median
		))
		for _, outlier in ipairs(stat.outliers) do
			table.insert(outlierRows, string.format([[{ x: %s, label: "%s", y: %s}]], fnId - 1, name, outlier))
		end
		table.insert(meanRows, string.format([[{ x: %s, label: "%s", y: [%s, %s]}]], fnId - 1, name, stat.mean, stat.mean))
	end
	for fnId, stat in SortedPairsByMemberValue(stats, "mean") do
		local name = trial.labels[fnId] or ("Function #" .. fnId)

		table.insert(rows, t:Template("partial/row", {
			idx = string.format(string.format("%%0%su", maxDigits), i),
			func = name,
			median = f:AutoNumbers(stat.median, timePairs.median, (stat.median < 10 and stat.median >= 1) and 3 or 2) .. "s",
			min = f:AutoNumbers(stat.min, timePairs.min, (stat.min < 10 and stat.min >= 1) and 3 or 2) .. "s",
			max = f:AutoNumbers(stat.max, timePairs.max, (stat.max < 10 and stat.max >= 1) and 3 or 2) .. "s",
			mean = f:AutoNumbers(stat.mean, timePairs.mean, (stat.mean < 10 and stat.mean >= 1) and 3 or 2) .. "s",
			meanPerCall = f:AutoNumbers(stat.average, timePairs.average, (stat.average < 10 and stat.average >= 1) and 3 or 2) .. "s",
			percentage = math.Round(stat.percentage) .. "%"
		}))

		i = i + 1
	end

	results = t:Template("partial/table", {
		header = t:Template("partial/header"),
		body = table.concat(rows, "\n")
	})

	-- local graph = t:Template("partial/graph", {
	-- 	key = id,
	-- 	title = f.Title(trial.name or id),
	-- 	data = table.concat(dataRows, ",\n"),
	-- 	outliers = table.concat(outlierRows, ",\n"),
	-- })

	local cleanGraph = t:Template("partial/graph-clean", {
		key = id,
		title = f.Title(trial.name or id),
		data = table.concat(dataRows, ",\n"),
		outliers = table.concat(meanRows, ",\n"),
	})

	return t:Template("tab", {
		key = id,
		runs = trial.runs,
		iterations = trial.iterations,
		title = f.Title(trial.name or id),
		class = first and "active" or "",
		predefines = string.format("<code><pre>%s</pre></code>", table.concat(predefines, "\n")),
		tests = table.concat(functions, "\n"),
		content = results .. "\n" .. cleanGraph
	})
end

function BENCH:ReportWithoutCrashing()
	local report = coroutine.create(function()
		self:HTMLReport()
		self._ActiveReport = nil
	end)
	local name = tostring(report)
	local out = {}
	local i = 0
	timer.Create(name, 0.2, 0, function()
		i = i + 1
		self.Logging.Debug("Timer Tick ", i)

		local _status = status(report)
		if _status == "suspended" then
			out = {resume(report)}
		elseif _status == "dead" then
			timer.Remove(name)

			if not out[1] and isstring(out[2]) then
				error(out[2])
			end
		end
	end)
end
