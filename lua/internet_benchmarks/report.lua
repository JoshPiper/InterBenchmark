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
	print(string.format("Checking %s", cur))

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
				if isfunction(v) then
					vars[k] = self:LookupGlobal(v) or self:ReadFunction(v) or v
				elseif isstring(v) then
					vars[k] = string.format("%q", v)
				elseif isnumber(v) then
					vars[k] = self:LookupGlobal(v) or v
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
	local results = self:TrialAll()

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
			stat.median = median / 2
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

function INTERNET_BENCHMARK:HTMLReport()
	local results = self:Report()

	print("Generating HTML")
	local tabs = {}
	for trial, trialData in SortedPairsByMemberValue(results, "order") do
		table.insert(tabs, self:HTMLTab(trial, trialData))
	end

	local report = string.format([[
		<!DOCTYPE html>
		<html>
			<head>
				<title>Benchmarking Report</title>
				<link rel="stylesheet" href="style.css">
			</head>
			<body>
				%s
			</body>
		</html>
	]], table.concat(tabs, "\n"))

	file.CreateDir("internet_benchmarks")
	file.Write("internet_benchmarks/report.html.txt", report)
end

function INTERNET_BENCHMARK:HTMLTab(name, data)
	print(string.format("\tGenerating Tab for :%s", name))
	local sections = {}

	local predefines = {}
	local codes = {}

	print("\t\tGenerating Pre-Definitions.")
	for idx, predefine in pairs(data.predefines or {}) do
		table.insert(predefines, predefine)
	end

	print("\t\tGenerating Upvalues.")
	for funcIdx, funcData in ipairs(data.functions) do
		for var, val in pairs(funcData.info.upvars) do
			table.insert(predefines, string.format("local %s = %s", var, val))
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
		table.insert(sections, string.format("<h3>Predefines</h3><code><pre>%s</pre></code>", table.concat(predefines, "\n")))
	end
	for funcIdx, code in pairs(codes) do
		table.insert(sections, string.format("<h3>Function %s</h3><code><pre>%s</pre></code>", funcIdx, code))
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

	local template = string.format([[
		<tr>
			<td>%%0%su</td>
			<td>%%s</td>
			<td>%%.4e</td>
			<td>%%.4e</td>
			<td>%%.4e</td>
			<td>%%.4e</td>
			<td>%%.4e</td>
			<td>%%s%%%%</td>
		</tr>
	]], maxDigits)

	for funcName, mean in SortedPairsByValue(data.results) do
		local stats = data.stats[funcName]
		table.insert(results, string.format(
			template,
			i,
			funcName,
			stats.median,
			stats.min,
			stats.max,
			stats.mean,
			stats.meanPC,
			math.Round((stats.mean / minMean) * 100, 2)
		))
		i = i + 1
	end
	table.insert(sections, string.format("<h3>Benchmarking Results <small>(%s Runs / %s Iterations)</small></h3><table>%s</table>", data.runs, data.iterations, table.concat(results, "\n")))

	return table.concat(sections, "\n\n")
end
