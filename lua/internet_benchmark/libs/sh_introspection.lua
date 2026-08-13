--- Source introspection for benchmark reports.
-- Extracts function sources and upvalue definitions so the report can show
-- exactly what code was measured, alongside the values it captured.
-- @module introspection

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK
BENCH.Introspection = setmetatable({}, {__index = INTERNET_BENCHMARK})
local INTROSPECT = BENCH.Introspection

--- Global tables which are never searched when naming a value.
-- These are either huge, expensive to walk, or both.
INTROSPECT.Blacklist = {
	"GCompute",
	"GLib",
	"EMVU",
	"Photon",
	"package.loaded",
}

--- Cache of value to global route lookups.
INTROSPECT.Cache = {}

--- Read a range of lines from a file on the LUA search path.
-- @string path Path relative to lua/.
-- @int[opt] startLine First line to read, inclusive.
-- @int[opt] stopLine Last line to read, inclusive.
-- @rstring The requested lines, or nil when the file cannot be read.
function INTROSPECT:ReadSource(path, startLine, stopLine)
	local data = file.Read(path, "LUA")
	if not data then
		return nil
	end

	-- Files authored on Windows arrive with CRLF endings, which would
	-- otherwise leave a stray carriage return on the end of every line.
	data = string.gsub(data, "\r\n", "\n")
	data = string.Explode("\n", data)
	return table.concat(data, "\n", startLine, stopLine)
end

--- Find the dotted global route to a value, if one exists.
-- @param var The value to search for.
-- @rstring The route (such as "math.max"), or false when none was found.
function INTROSPECT:Lookup(var, inTable, route, seen)
	if self.Cache[var] then
		return self.Cache[var]
	end

	if not seen then seen = {[_G] = true} end
	if not route then route = {} end
	if not inTable then inTable = _G end

	local cur = table.concat(route, ".")
	for _, blacklisted in ipairs(self.Blacklist) do
		if cur:StartWith(blacklisted) then
			return false
		end
	end

	local toDo = {}
	for k, v in pairs(inTable) do
		if v == var then
			table.insert(route, k)
			route = table.concat(route, ".")
			self.Cache[var] = route
			return route
		end

		if istable(v) and not seen[v] then
			toDo[k] = v
		end
	end

	for k, v in pairs(toDo) do
		-- Prevent infinite loops through self-referential tables.
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

--- Get the defining file (relative to lua/) and line range of a function.
-- @return path, first line, last line — or nil for C or unlocatable functions.
local function sourceInfo(fn)
	local info = debug.getinfo(fn, "S")
	if info.what ~= "Lua" then
		return nil
	end

	local path = info.short_src:match("^.-lua/(.*)$")
	if not path then
		return nil
	end

	return path, info.linedefined, info.lastlinedefined
end

--- Read a function's defining source.
-- Falls back to its global route when the source is unavailable.
-- @rstring The function's source, its global route, or a placeholder.
function INTROSPECT:FunctionSource(fn)
	local path, startLine, stopLine = sourceInfo(fn)
	if path then
		local body = self:ReadSource(path, startLine, stopLine)
		if body then
			return body:Trim()
		end
	end

	local route = self:Lookup(fn)
	if route then
		return route
	end

	return "-- Source unavailable."
end

--- Serialise a captured value into a Lua expression for the report.
-- @param var The captured value.
-- @bool[opt] excludeGlobals Skip the global route lookup for functions.
-- @return A string expression, a {"raw", source} table for function bodies,
-- or nil when the value cannot be represented (exclude it, or cover it with
-- a manual predefine).
function INTROSPECT:Variable(var, excludeGlobals)
	if isfunction(var) then
		if not excludeGlobals then
			local route = self:Lookup(var)
			if route then
				return route
			end
		end

		local path, startLine, stopLine = sourceInfo(var)
		if path then
			local body = self:ReadSource(path, startLine, stopLine)
			if body then
				return {"raw", body:Trim()}
			end
		end

		return string.format("nil -- Unknown function: %s.", tostring(var))
	end

	if isstring(var) then
		return string.format("%q", var)
	end

	if isnumber(var) or isbool(var) then
		return tostring(var)
	end

	if IsColor(var) then
		return string.format("Color(%s, %s, %s, %s)", var.r, var.g, var.b, var.a)
	end

	return nil
end

--- Collect the upvalues of a function.
-- @return A name-to-value map, and a list of names whose values were nil.
local function upvalues(fn)
	local vars, nils = {}, {}
	local info = debug.getinfo(fn, "u")
	for i = 1, info.nups do
		local k, v = debug.getupvalue(fn, i)
		if k ~= nil then
			if v == nil then
				table.insert(nils, k)
			else
				vars[k] = v
			end
		end
	end

	return vars, nils
end

--- Populate a trial with the sources of its functions and pre-definitions.
-- Must run before benchmarking, so captured values are shown in their
-- initial state rather than whatever the runs left behind.
-- @tab trial The trial instance to populate.
function INTROSPECT:TrialSources(trial)
	local excluded = trial.excludedVars or {}

	trial.functionSources = {}
	trial.predefineSources = {}

	local trialPath = string.format("internet_benchmark/trials/%s.lua", trial.id)
	for _, range in ipairs(trial.preDefines or {}) do
		local source = self:ReadSource(trialPath, range[1], range[2])
		if source then
			table.insert(trial.predefineSources, source)
		else
			self.Logging.Warning(string.format(
				"Trial '%s' has a manual predefine for lines %s-%s, which could not be read.",
				trial.id, range[1], range[2]
			))
		end
	end

	local seen = {}
	for idx, fn in ipairs(trial.functions) do
		trial.functionSources[idx] = self:FunctionSource(fn)

		local vars, nils = upvalues(fn)
		for name, value in pairs(vars) do
			if not excluded[name] and not seen[name] then
				seen[name] = true

				local rendered = self:Variable(value)
				if rendered == nil then
					self.Logging.Warning(string.format(
						"Trial '%s' captures '%s', which cannot be serialised. Exclude it or add a manual predefine.",
						trial.id, name
					))
				elseif istable(rendered) then
					table.insert(trial.predefineSources, rendered[2])
				else
					table.insert(trial.predefineSources, string.format("local %s = %s", name, rendered))
				end
			end
		end

		for _, name in ipairs(nils) do
			if not excluded[name] and not seen[name] then
				seen[name] = true
				self.Logging.Warning(string.format(
					"Trial '%s' captures '%s' with a nil value. Exclude it or add a manual predefine.",
					trial.id, name
				))
			end
		end
	end

	-- De-duplicate identical predefine blocks.
	local unique, defines = {}, {}
	for _, define in ipairs(trial.predefineSources) do
		if not unique[define] then
			unique[define] = true
			table.insert(defines, define)
		end
	end
	trial.predefineSources = defines
end
