--- Number and text formatting helpers.

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK
BENCH.Formatting = setmetatable({}, {__index = INTERNET_BENCHMARK})
local FORMAT = BENCH.Formatting

--- Metric prefixes, indexed by their power of ten.
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

--- Named sets of allowed prefixes.
FORMAT.AllowedPrefixes = {
	all = table.GetKeys(FORMAT.Prefixes),
	standard = {-24, -21, -18, -15, -12, -9, -6, -3, 0, 3, 6, 9, 12, 15, 18, 21, 24}
}

--- Resolve a prefix specification into a list of allowed powers.
--- Accepts a named set, a list of powers, or a single power.
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

--- Find the first allowed prefix which scales num into the given bounds.
--- @return number? # The prefix's power of ten, or nil when none fit (or num is 0).
function FORMAT:Prefix(num, prefixes, minBound, maxBound)
	prefixes = self:GetAllowedPrefixes(prefixes)
	minBound = minBound or 0
	maxBound = maxBound or 1000

	if num == 0 then
		return
	end

	for _, pow in ipairs(prefixes) do
		local calc = math.abs(num * 10 ^ (-pow))
		if calc >= minBound and calc < maxBound then
			return pow
		end
	end
end

--- Find the most common prefix across a set of numbers.
--- @return number? # The modal prefix's power of ten, or nil for an empty set.
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

--- Format a number against a specific prefix.
--- A nil prefix formats the number without scaling or suffix.
function FORMAT:Number(num, prefix, sigFig)
	local formatterString = sigFig == nil and "%s" or string.format("%%#.%sf", sigFig)

	local out = not prefix and
		string.format(formatterString, num) or
		string.format(formatterString, num * 10 ^ (-prefix))

	if out:EndsWith(".") then
		out = string.sub(out, 1, #out - 1)
	end

	return out .. (prefix and self.Prefixes[prefix] or "")
end

--- Format a number with an automatically selected prefix.
function FORMAT:AutoNumber(num, prefixes, sigFig, minBound, maxBound)
	return self:Number(
		num,
		self:Prefix(num, prefixes, minBound, maxBound),
		sigFig
	)
end

--- Format a number with the prefix most common across a set of numbers.
--- Keeps a column of related values in a single, comparable unit.
function FORMAT:AutoNumbers(num, numbers, sigFig, prefixes, minBound, maxBound)
	return self:Number(
		num,
		self:ModalPrefix(numbers, prefixes, minBound, maxBound),
		sigFig
	)
end

--- Convert a file name into a title-cased display name.
function FORMAT.Title(word)
	if word:sub(-4) == ".lua" then
		word = word:sub(1, -5)
	end

	word = word:Replace("_", " ")
	word = string.gsub(word, " %w", string.upper)
	word = string.gsub(word, "^%w", string.upper)
	return word
end

--- Escape a string for embedding into HTML text content.
function FORMAT.EscapeHTML(text)
	text = string.gsub(text, "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")
	return text
end
