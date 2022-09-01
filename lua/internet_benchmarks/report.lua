AddCSLuaFile()
INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
INTERNET_BENCHMARK.LookupCache = INTERNET_BENCHMARK.LookupCache or {}
INTERNET_BENCHMARK.LookupBlacklist = {
	"GCompute",
	"GLib",
	"EMVU",
	"Photon",
	"package.loaded"
}

function INTERNET_BENCHMARK:LookupGlobal(var, tbl, route, seen)
	if self.LookupCache[var] then
		return self.LookupCache[var]
	end

	if not seen then seen = {[_G] = true} end
	if not route then route = {} end
	if not tbl then tbl = _G end

	local cur = table.concat(route, ".")
	for _, bl in ipairs(self.LookupBlacklist) do
		if cur:StartWith(bl) then
			return false
		end
	end
	-- print(string.format("Checking %s", cur))

	local toDo = {}
	for k, v in pairs(tbl) do
		if v == var then
			table.insert(route, k)
			route = table.concat(route, ".")
			self.LookupCache[var] = route
			return route
		end

		if istable(v) and not seen[v] then
			toDo[k] = v
		end
	end

	for k, v in pairs(toDo) do
		-- Prevent infinate loop.
		seen[v] = true
		table.insert(route, k)

		local found = self:LookupGlobal(var, v, route, seen)
		if found then
			return found
		end

		seen[v] = nil
		table.remove(route)
	end

	return false
end

function INTERNET_BENCHMARK:ReadSource(path, startLine, stopLine)
	local data = file.Read(path, "LUA")
	data = string.Explode("\n", data)
	return table.concat(data, "\n", startLine, stopLine)
end

function INTERNET_BENCHMARK:ReadFunction(func)
	local info = debug.getinfo(func, "flLnSu")
	if info.what == "Lua" and info.short_src:find("/lua/") then
		-- This is defined in a file, so we can get the source.
		local path = info.short_src:match("/lua/(.*)")
		if path then
			local body = self:ReadSource(path, info.linedefined, info.lastlinedefined)
			body = body:Trim()
			-- body = string.Explode("\n", body)

			-- local first = body[1]
			-- if first then
			-- 	-- Strip the func prefix from anonymous functions.
			-- 	first = first:gsub("^[%s%w]*function%(", "")
			-- 	-- Ditto for named functions.
			-- 	first = first:gsub("^[%s%w]*function [%w_]+%(", "")
			-- 	if first:StartWith(")") then
			-- 		first = first:sub(1)
			-- 	end
			-- 	body[1] = first
			-- end

			-- local last = body[#body]
			-- if last then
			-- 	last = last:gsub("end[%w%s,]-$", "")
			-- 	body[#body] = last
			-- end

			-- Finally, make all functions anonymous.
			-- return "function(" .. table.concat(body, "\n")
			return body
		end
	end

	return self:LookupGlobal(func)
end

function INTERNET_BENCHMARK:LookupVariable(var, excludeGlobals)
	local val
	if isfunction(var) then
		if not val and not excludeGlobals then
			val = self:LookupGlobal(var)
		end

		if not val then
			local src = self:ReadFunction(var)
			if src then
				val = {"raw", src}
			end
		end

		if not val then
			val = string.format("function() end -- Unknown Function %p", var)
		end
	elseif isstring(v) then
		val = string.format("%q", var)
	elseif isnumber(v) then
		val = var
	elseif IsColor(v) then
		val = Format("Color(%s, %s, %s, %s)", v.r, v.g, v.b, v.a)
	else
		-- This will need to be expanded, but for now it should work.
		val = tostring(var)
	end

	if val then
		return val
	end
end

function INTERNET_BENCHMARK:GetTrialPredefines(trialData)
	local manualPredefines = trialData.predefines
	local donePredefines = false

	for idx, funcData in ipairs(trialData.functions) do
		local funcInfo = {}
		local info = debug.getinfo(funcData.func, "flLnSu")

		if info.what == "Lua" and info.short_src:find("/lua/") then
			-- This is defined in a file, so we can get the source.
			local path = info.short_src:match("/lua/(.*)")
			if path then
				if not donePredefines and manualPredefines then
					donePredefines = true
					for idx, predefine in ipairs(manualPredefines) do
						manualPredefines[idx] = self:ReadSource(path, predefine[1], predefine[2])
					end
				end
				local data = file.Read(path, "LUA")
				data = string.Explode("\n", data)
				funcInfo.source = table.concat(data, "\n", info.linedefined, info.lastlinedefined)
			end

			local vars = {}
			local ups = info.nups
			if ups and ups ~= 0 then
				for i = 0, ups do
					local k, v = debug.getupvalue(funcData.func, i)
					if k ~= nil then
						vars[k] = v
					end
				end
			end

			for k, v in pairs(vars) do
				local val = self:LookupVariable(v)
				if val then
					vars[k] = val
				else
					vars[k] = nil
				end
			end
			funcInfo.upvars = vars
		end

		funcData.info = funcInfo
	end
end

function INTERNET_BENCHMARK:Report()
	-- local results = self:TrialAll()
	local results = {string_templating = self:Trial("string_templating.lua"), equals_false_vs_not = self:Trial("equals_false_vs_not.lua")}

	for trial, trialData in pairs(results) do
		print(string.format("Calculating Results for :%s", trialData.title))
		local runs = trialData.runs

		local medianIdx1, medianIdx2
		if runs % 2 == 0 then
			medianIdx1 = math.floor((runs + 1) / 2)
			medianIdx2 = math.ceil((runs + 1) / 2)
		else
			medianIdx1 = (runs + 1) / 2
			medianIdx2 = (runs + 1) / 2
		end

		print("\tGenerating Predefines / Function Source")
		self:GetTrialPredefines(trialData)

		local stats = {}
		local minMean
		print("\tGenerating Statistics")
		for func, funcResults in pairs(trialData.details) do
			local stat = {}
			local total = 0
			local median = 0

			local i = 1
			local min, max
			print("\t\tCalculating Min/Max/Median")
			for idx, result in SortedPairsByValue(funcResults) do
				if min then
					min = math.min(min, result)
				else
					min = result
				end

				if max then
					max = math.max(max, result)
				else
					max = result
				end

				if i == medianIdx1 or i == medianIdx2 then
					median = median + result
				end
				total = total + result
				i = i + 1
			end

			stat.total = total
			stat.median = i == 1 and median or (median / 2)
			stat.mean = total / runs
			stat.min = min
			stat.max = max

			if not minMean then
				minMean = stat.mean
			else
				minMean = math.min(minMean, stat.mean)
			end

			stat.meanPC = stat.mean / trialData.iterations

			local stdDevSum = 0
			print("\t\tCalculating Standard Deviation")
			for idx, result in ipairs(funcResults) do
				stdDevSum = stdDevSum + math.pow(result - stat.mean, 2)
			end
			stat.stdev = math.sqrt(stdDevSum / runs)

			stats[func] = stat
		end

		stats.__minMean = minMean
		trialData.stats = stats

	end

	return results
end

INTERNET_BENCHMARK.Prefixes = {
	[-24] = "y",
	[-21] = "z",
	[-18] = "a",
	[-15] = "f",
	[-12] = "p",
	[-9] = "n",
	[-6] = "µ",
	[-3] = "m",
	[-2] = "c",
	[-1] = "d",
	[0] = "",
	[1] = "da",
	[2] = "h",
	[3] = "k",
	[6] = "M",
	[9] = "G",
	[12] = "T",
	[15] = "P",
	[18] = "E",
	[21] = "Z",
	[24] = "Y"
}

INTERNET_BENCHMARK.Allowables = {
	all = table.GetKeys(INTERNET_BENCHMARK.Prefixes),
	norm = {-24, -21, -18, -15, -12, -9, -6, -3, 0, 3, 6, 9, 12, 15, 18, 21, 14}
}

function INTERNET_BENCHMARK:NumberToPrefix(num, allowed, sigFig, minBound, maxBound)
	allowed = allowed or self.Allowables.norm
	minBound = minBound or 0.01
	maxBound = maxBound or 10
	local formatterString = sigFig == nil and "%s%s" or string.format("%%.%sf%%s", sigFig)

	for _, pow in ipairs(allowed) do
		local pref = self.Prefixes[pow]
		local calc = num * math.pow(10, -pow)

		if num < 0 then
			if calc >= minBound and calc < maxBound then
				return string.format(formatterString, calc, pref)
			end
		else
			if calc > minBound and calc <= maxBound then
				return string.format(formatterString, calc, pref)
			end
		end
	end

	return num
end

function INTERNET_BENCHMARK:HTMLTemplate(template, variables)
	if variables == nil then
		variables = {}
	end
	if not istable(variables) then
		variables = {content = tostring(variables)}
	end

	template = string.format("internet_benchmarks/templates/html/%s.html.lua", template)
	template = file.Read(template, "LUA") or ""
	template = string.gsub(template, "%${(.-)}", function(w)
		return variables[w] or ("${" .. w .. "}")
	end)

	return template
end

function INTERNET_BENCHMARK:HTMLReport()
	local results = self:Report()
	local tabHeaders, tabBodies = {}, {}
	local first = true

	print("Generating HTML")
	for trial, trialData in SortedPairsByMemberValue(results, "order") do
		table.insert(tabHeaders, self:HTMLTemplate("nav/tab", {
			key = trial,
			title = self:Titalise(trialData.title or trial)
		}))
		table.insert(tabBodies, self:HTMLTab(trial, trialData, first))

		if first then
			first = nil
		end
	end

	local report = self:HTMLTemplate("document", {
		nav = table.concat(tabHeaders, "\n"),
		body = table.concat(tabBodies, "\n")
	})

	file.CreateDir("internet_benchmarks")
	file.Write("internet_benchmarks/report.html.txt", report)
	file.Write("internet_benchmarks/style.css.txt", file.Read("internet_benchmarks/templates/html/style.css.lua", "LUA"))
	file.Write("internet_benchmarks/script.js.txt", file.Read("internet_benchmarks/templates/html/script.js.lua", "LUA"))
end

function INTERNET_BENCHMARK:HTMLTab(name, data, first)
	print(string.format("\tGenerating Tab for :%s", name))
	local sections = {}

	local predefines = {}
	local codes = {}
	local excluded = data.excludedVars or {}

	print("\t\tGenerating Pre-Definitions.")
	for idx, predefine in pairs(data.predefines or {}) do
		table.insert(predefines, predefine)
	end

	print("\t\tGenerating Upvalues.")
	for funcIdx, funcData in ipairs(data.functions) do
		for var, val in pairs(funcData.info.upvars) do
			if not excluded[var] then
				if isstring(val) then
					table.insert(predefines, string.format("local %s = %s", var, val))
				elseif istable(val) then
					local typ, dt = val[1], val[2]
					if typ == "raw" then
						table.insert(predefines, dt)
					end
				end
			end
		end

		codes[funcIdx] = funcData.info.source
	end

	local seen = {}
	local defines = {}
	for _, define in ipairs(predefines) do
		if not seen[define] then
			seen[define] = true
			table.insert(defines, define)
		end
	end
	predefines = defines

	print("\t\tGenerating HTML.")
	table.insert(sections, string.format("<h2 id='%s'>%s</h2>", name, data.title))
	if #predefines > 0 then

	end

	local functions = {}
	for funcIdx, code in ipairs(codes) do
		table.insert(functions, self:HTMLTemplate("partial/definition", {
			title = data.functions[funcIdx].title,
			content = self:HTMLTemplate("partial/predefine", code)
		}))
	end

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
	local minMean = data.stats.__minMean
	local maxDigits = math.floor(math.log10(#data.functions)) + 1

	local template = string.format(self:HTMLTemplate("partial/row"), maxDigits)

	local rows = {}
	for funcName, mean in SortedPairsByValue(data.results) do
		local stats = data.stats[funcName]
		table.insert(rows, self:HTMLTemplate("partial/row", {
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

	results = self:HTMLTemplate("partial/table", {
		header = self:HTMLTemplate("partial/header"),
		body = table.concat(rows, "\n")
	})

	return self:HTMLTemplate("tab", {
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
