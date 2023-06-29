INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

local yieldable, yield, resume, status = coroutine.isyieldable, coroutine.yield, coroutine.resume, coroutine.status

local t, f, l = BENCH.Templating, BENCH.Formatting, BENCH.Logging

function BENCH:ReportTrial(trial)
	local _yieldable = yieldable()
	local doTrial = coroutine.create(function()
		return self:Trial(trial, true)
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
		nav = table.concat(tabHeaders, "\n"),
		body = table.concat(tabBodies, "\n")
	})

	file.CreateDir("internet_benchmarks")
	file.Write("internet_benchmarks/report.html.txt", report)
	file.Write("internet_benchmarks/style.css.txt", file.Read("internet_benchmarks/templates/html/style.css.lua", "LUA"))
	file.Write("internet_benchmarks/script.js.txt", file.Read("internet_benchmarks/templates/html/script.js.lua", "LUA"))
end

function BENCH:HTMLTab(i, timing, stats, trial)
	local first = i == 1
	l.Debug("Generating tab for ", i)

	local sections = {}
	local predefines = {}
	local codes = {}
	local excluded = data.excludedVars or {}

	l.Debug("Generating Pre-Definitions.")
	for _, predefine in pairs(data.predefines or {}) do
		table.insert(predefines, predefine)
	end

	-- l.Debug("Generating Upvalues.")
	-- for fnId, fn in ipairs(data.functions) do
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

	print("\t\tGenerating HTML.")
	table.insert(sections, string.format("<h2 id='%s'>%s</h2>", data.id or i, f.Title(data.title or data.id or i)))
	-- if #predefines > 0 then

	-- end

	-- local functions = {}
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

	local i = 1
	local minMean = statistics.__minMean
	local maxDigits = math.floor(math.log10(#trial.functions)) + 1

	local rows = {}
	for funcName, mean in SortedPairsByValue(timing.results) do
		local stats = statistics[funcName]
		table.insert(rows, t:Template("partial/row", {
			idx = string.format(string.format("%%0%su", maxDigits), i),
			func = funcName,
			median = self:NumberToPrefix(stats.median, nil, (stats.median < 10 and stats.median >= 1) and 3 or 2) .. "s",
			min = self:NumberToPrefix(stats.min, nil, (stats.min < 10 and stats.min >= 1) and 3 or 2) .. "s",
			max = self:NumberToPrefix(stats.max, nil, (stats.max < 10 and stats.max >= 1) and 3 or 2) .. "s",
			mean = self:NumberToPrefix(stats.mean, nil, (stats.mean < 10 and stats.mean >= 1) and 3 or 2) .. "s",
			meanPerCall = self:NumberToPrefix(stats.meanPC, nil, (stats.meanPC < 10 and stats.meanPC >= 1) and 3 or 2) .. "s",
			percentage = math.Round((stats.mean / minMean) * 100) .. "%"
		}))
		i = i + 1
	end

	results = t:Template("partial/table", {
		header = t:Template("partial/header"),
		body = table.concat(rows, "\n")
	})

	return t:Template("tab", {
		key = name,
		runs = data.runs,
		iterations = data.iterations,
		title = self:Titalise(data.title or name),
		class = first and "active" or "",
		predefines = string.format("<code><pre>%s</pre></code>", table.concat(predefines, "\n")),
		tests = table.concat(functions, "\n"),
		content = results
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

			print("done")
			PrintTable(out)

		end
	end)
end
