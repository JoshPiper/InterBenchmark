--- Console command argument parsing.

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

--- Splits a concommand argument list into flags and positional arguments.
---
--- `--flag` tokens set `flags.flag = true`, `--flag=value` tokens set
--- `flags.flag = "value"`, and every other token is collected into the
--- positional list in its original order (flags may be interleaved with
--- positionals in any order). Flag names are lowercased; values are kept
--- verbatim. A flag repeated more than once collapses its values into a
--- sequential table, in the order they appeared.
---
--- Usage:
--- ```lua
--- local flags, positional = BENCH:ParseArgs({"--dynamic", "array_insertion"})
--- -- flags.dynamic == true, positional[1] == "array_insertion"
---
--- local flags = BENCH:ParseArgs({"--tags=a", "--tags=b"})
--- -- flags.tags[1] == "a", flags.tags[2] == "b"
--- ```
--- @param args table? Raw argument list, as passed to a concommand callback.
--- @return table # Flag map: name -> `true`/string, or a table of values if repeated.
--- @return table # Positional arguments, in order.
function BENCH:ParseArgs(args)
	local flags, positional = {}, {}

	for _, token in ipairs(args or {}) do
		local name, value = token:match("^%-%-([^=]+)=(.*)$")
		if not name then
			name, value = token:match("^%-%-([^=]+)$"), true
		end

		if name then
			name = name:lower()
			local existing = flags[name]
			if existing == nil then
				flags[name] = value
			elseif type(existing) == "table" then
				table.insert(existing, value)
			else
				flags[name] = {existing, value}
			end
		else
			table.insert(positional, token)
		end
	end

	return flags, positional
end

--- Normalises a --tag/--skip-tag flag value (as returned in ParseArgs's flag
--- map) into a flat, lower-cased list of tag names.
--- Each value may itself be a comma-separated list, and repeated flags
--- already collapse into a table (see ParseArgs); both forms are flattened
--- into one list here. A bare flag (`--tag` with no value, parsed as `true`)
--- contributes no tags.
--- @param value string|table|boolean|nil A flag's value, as returned by ParseArgs.
--- @return table # A list of lower-cased tag names.
function BENCH:ParseTagList(value)
	local tags = {}
	if value == nil then
		return tags
	end

	local values = type(value) == "table" and value or {value}
	for _, entry in ipairs(values) do
		if type(entry) == "string" then
			for tag in entry:gmatch("[^,]+") do
				table.insert(tags, tag:lower())
			end
		end
	end

	return tags
end

--- Whether a set of tags should run, given --tag/--skip-tag filters, using
--- the same precedence Ansible gives its own --tags/--skip-tags: skipping
--- always wins, and with no include filter every non-skipped item runs.
--- @param tags table The item's own tags.
--- @param includeTags table Tags passed via --tag. An empty list matches everything.
--- @param excludeTags table Tags passed via --skip-tag.
--- @return boolean
function BENCH:TagsMatch(tags, includeTags, excludeTags)
	if #excludeTags > 0 then
		for _, tag in ipairs(tags) do
			if table.HasValue(excludeTags, tag) then
				return false
			end
		end
	end

	if #includeTags == 0 then
		return true
	end

	for _, tag in ipairs(tags) do
		if table.HasValue(includeTags, tag) then
			return true
		end
	end

	return false
end

--- Builds a GMod concommand autocomplete callback from a small schema, so
--- flags and positionals complete correctly regardless of the order they're
--- typed in.
---
--- Usage:
--- ```lua
--- concommand.Add("internet_benchmark_trial", callback, BENCH:ArgCompleter({
--- 	flags = {"dynamic"},
--- 	positionals = {function() return BENCH:TrialNames() end},
--- }))
--- ```
--- @param schema table `{flags = {name, ...}, positionals = {function() return {candidate, ...} end, ...}}`.
--- @return function # `function(cmd, argStr)` suitable for `concommand.Add`.
function BENCH:ArgCompleter(schema)
	local flagNames = schema.flags or {}
	local positionalProviders = schema.positionals or {}

	return function(cmd, argStr)
		local tokens = {}
		for token in argStr:gmatch("%S+") do
			table.insert(tokens, token)
		end

		-- The token currently being completed: the last token, unless the
		-- string ends in whitespace (or is empty), in which case a new,
		-- empty token is being started.
		local current = ""
		if #tokens > 0 and not argStr:match("%s$") then
			current = table.remove(tokens)
		end

		local candidates = {}

		if current:StartWith("-") then
			local typed = {}
			for _, token in ipairs(tokens) do
				typed[token:lower()] = true
			end

			for _, name in ipairs(flagNames) do
				local flag = "--" .. name
				if flag:StartWith(current) and not typed[flag:lower()] then
					table.insert(candidates, flag)
				end
			end
		else
			local slot = 0
			for _, token in ipairs(tokens) do
				if not token:StartWith("--") then
					slot = slot + 1
				end
			end

			-- Past the last provider, the final one repeats (variadic positionals).
			local provider = positionalProviders[slot + 1] or positionalProviders[#positionalProviders]
			if provider then
				local partial = current:lower()
				for _, name in ipairs(provider()) do
					if partial == "" or name:lower():StartWith(partial) then
						table.insert(candidates, name)
					end
				end
			end
		end

		local suggestions = {}
		for _, candidate in ipairs(candidates) do
			local parts = {cmd}
			for _, token in ipairs(tokens) do
				table.insert(parts, token)
			end
			table.insert(parts, candidate)

			table.insert(suggestions, table.concat(parts, " "))
		end

		return suggestions
	end
end
