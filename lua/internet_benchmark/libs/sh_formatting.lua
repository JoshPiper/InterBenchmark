INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK
BENCH.Formatting = setmetatable({}, {__index = INTERNET_BENCHMARK})
local FORMAT = BENCH.Formatting

FORMAT.Prefixes = {
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

FORMAT.AllowedPrefixes = {
	all = table.GetKeys(FORMAT.Prefixes),
	standard = {-24, -21, -18, -15, -12, -9, -6, -3, 0, 3, 6, 9, 12, 15, 18, 21}
}

FORMAT.DontLookup = {
	"GCompute",
	"GLib",
	"EMVU",
	"Photon",
	"package.loaded",
}
FORMAT.Lookedup = {}

function FORMAT:GetAllowedPrefixes(name)
	if isstring(name) then
		return self.AllowedPrefixes[name] or self.AllowedPrefixes.standard
	end

	if istable(name) then
		return name
	end

	if isnumber(name) then
		return {name}
	end

	return self.AllowedPrefixes.standard
end

function FORMAT:Prefix(num, prefixes, minBound, maxBound)
	self.Logging.Debug("Getting prefix for ", num)
	prefixes = self:GetAllowedPrefixes(prefixes)
	minBound = minBound or 0
	maxBound = maxBound or 1000

	if num == 0 then
		return
	end

	for _, pow in ipairs(prefixes) do
		local calc = math.abs(num * math.pow(10, -pow))
		if calc >= minBound and calc < maxBound then
			return pow
		end
	end
end

function FORMAT:ModalPrefix(numbers, prefixes, minBound, maxBound)
	local calc = {}

	for _, number in ipairs(numbers) do
		local pref = self:Prefix(number, prefixes, minBound, maxBound)
		if pref then
			calc[pref] = (calc[pref] or 0) + 1
		end
	end

	return table.GetWinningKey(calc)
end

function FORMAT:Number(num, prefix, sigFig)
	local formatterString = sigFig == nil and "%s" or string.format("%%#.%sf", sigFig)

	local out = not prefix and
		string.format(formatterString, num) or
		string.format(formatterString, num * math.pow(10, -prefix))

	if out:EndsWith(".") then
		out = string.sub(out, 1, #out - 1)
	end
	out = out .. self.Prefixes[prefix]

	return out
end

function FORMAT:AutoNumber(num, prefixes, sigFig, minBound, maxBound)
	return self:Number(
		num,
		self:Prefix(num, prefixes, minBound, maxBound),
		sigFig
	)
end

function FORMAT:AutoNumbers(num, numbers, sigFig, prefixes, minBound, maxBound)
	return self:Number(
		num,
		self:ModalPrefix(numbers, prefixes, minBound, maxBound),
		sigFig
	)
end

function FORMAT.Title(word)
	if word:sub(-4) == ".lua" then
		word = word:sub(0, -4)
	end

	word = word:Replace("_", " ")
	word = string.gsub(word, " %w", string.upper)
	word = string.gsub(word, "^%w", string.upper)
	return word
end

function FORMAT.Source(path, start, stop)
	local data = file.Read(path, "LUA")
	data = string.Explode("\n", data)
	return table.concat(data, "\n", start, stop)
end

function FORMAT:Function(fn)
	local info = debug.getinfo(fn, "flLnSu")
	if info.what == "Lua" and info.short_src:find("/lua/") then
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

	return self:Lookup(fn)
end

function FORMAT:Lookup(var, inTable, route, seen)
	if self.Lookedup[var] then
		return self.Lookedup[var]
	end

	if not seen then seen = {[_G] = true} end
	if not route then route = {} end
	if not inTable then inTable = _G end

	local cur = table.concat(route, ".")
	for _, bl in ipairs(self.LookupBlacklist) do
		if cur:StartWith(bl) then
			return false
		end
	end

	local toDo = {}
	for k, v in pairs(inTable) do
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

		local found = self:Lookup(var, v, route, seen)
		if found then
			return found
		end

		seen[v] = nil
		table.remove(route)
	end

	return false
end

function FORMAT:Local(var, excludeGlobals)
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
