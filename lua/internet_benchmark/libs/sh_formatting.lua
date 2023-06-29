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
		self.Logging.Debug("Checking prefix power ", pow, " if ", calc, " is within ", minBound, " and ", maxBound)
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
	local formatterString = sigFig == nil and "%s" or string.format("%%#.%sg", sigFig)

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
