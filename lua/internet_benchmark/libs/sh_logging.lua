--- Photon Logging Module
-- @module logging

local BENCH = INTERNET_BENCHMARK
BENCH.Logging = {}
local logging = BENCH.Logging

--- Various Logging Level Enumerations
logging.Levels = {
	NONE = 100,
	FATAL = 50,
	ERROR = 40,
	WARNING = 30,
	INFO = 20,
	DEBUG = 10,
	ANY = 0
}
logging.Levels.DEFAULT = logging.Levels.WARNING
logging.Levels._MAX = logging.Levels.NONE
logging.Levels._MIN = logging.Levels.ANY

--- Colours used in the logging library.
logging.Colours = {
	[logging.Levels.NONE] = Color(20, 20, 20),
	[logging.Levels.FATAL] = Color(255, 0, 0),
	[logging.Levels.ERROR] = Color(255, 60, 60),
	[logging.Levels.WARNING] = Color(255, 200, 0),
	[logging.Levels.INFO] = Color(20, 140, 255),
	[logging.Levels.DEBUG] = Color(160, 160, 160),

	Brand = Color(230, 92, 78),
	Client = Color(222, 169, 9),
	Server = Color(3, 169, 224),
	Text = Color(200, 200, 200),
	Disabled = Color(20, 20, 20),
}

--- Parse a string logging level (such as that from cvars.String) into a level.
-- If it fails to parse, the default is used instead.
-- @string level Input Level
-- @rnumber Logging Level
function logging.Parse(level)
	if tonumber(level) ~= nil then
		level = tonumber(level)
	end

	if isnumber(level) then
		return math.Clamp(level, logging.Levels.ANY, logging.Levels.FATAL)
	end

	if logging.Levels[level] then
		return logging.Levels[level]
	end

	return logging.Levels.DEFAULT
end

function logging:EnumDescription()
	local desc = "int[%0d <= X <= %0d]|string<%s>"
	local levels = {}

	for name, level in SortedPairsByValue(self.Levels, true) do
		if name == "DEFAULT" or name:StartWith("_") then
			continue
		end

		table.insert(levels, name)
	end

	return string.format(desc, self.Levels._MIN, self.Levels._MAX, table.concat(levels, ", "))
end

local level_cvar = CreateConVar(
	"internet_benchmark_logging_level",
	logging.Levels.DEFAULT,
	FCVAR_ARCHIVE + FCVAR_ARCHIVE_XBOX + FCVAR_UNLOGGED,
	string.format("Set the logging level for Internet Benchmarks Suite (%s)", logging:EnumDescription()),
	logging.Levels._MIN,
	logging.Levels._MAX
)

logging.Level = logging.Parse(level_cvar:GetString())
cvars.RemoveChangeCallback(level_cvar:GetName(), "logging")
cvars.AddChangeCallback(level_cvar:GetName(), function(_, _, val)
	logging.Level = logging.Parse(val)
end, "logging")



local function flatten(...)
	local out = {}
	local n = select('#', ...)
	for i = 1, n do
		local v = (select(i, ...))
		if istable(v) and not IsColor(v) then
			table.Add(out, flatten(unpack(v)))
		elseif isfunction(v) then
			table.Add(out, flatten(v()))
		else
			table.insert(out, v)
		end
	end

	return out
end


--- Print a message with colour to console.
-- @internal
-- @see MsgC
function logging._print(...)
	MsgC(unpack(flatten(...)))
	print()
end

--- A table storing often used logging "phrases".
logging.Phrases = {
	Brand = {logging.Colours.Brand, "Internet's Benchmark Suite"},
	BrandPride = {
		Color(228, 3, 3), "Inter",
		Color(255, 140, 0), "net's ",
		Color(255, 237, 0), "Bench",
		Color(0, 128, 38), "mark ",
		Color(36, 64, 142), "Sui",
		Color(115, 41, 130), "te",
	}
}

--- Create a table with the brand name.
-- @bool wrapped Should the Brand be wrapped in [].
-- @string event It's a secret tool that'll help us later.
-- @rtab
function logging:Brand(wrapped, event)
	if not event then
		event = ""

		local dt = os.date("%d-%m")
		if os.date("%m") == "06" then
			event = "Pride"
		end
	end

	local brand = self.Phrases["Brand" .. event] or self.Phrases.Brand
	if wrapped then
		return {self.Colours.Text, "[", brand, self.Colours.Text, "]"}
	end

	return {brand, self.Colours.Text}
end

--- Build the message functions for a given level.
-- Adds the function to logging.<LEVEL>, ie logging.Warning
-- @tparam string level Message level.
function logging:Build(level)
	local levelValue = isnumber(level) and level or self.Levels[level:upper()]

	if self[level] then
		self[level] = nil
	end

	local args = {}
	table.insert(args, BENCH.Functional.partial(self.Brand, self, true))
	table.insert(args, self.Colours.Text)
	table.insert(args, "[")

	if SERVER then
		table.insert(args, self.Colours.Server)
		table.insert(args, "sv")
		table.insert(args, self.Colours.Text)
		table.insert(args, "][")
	end
	if CLIENT then
		table.insert(args, self.Colours.Client)
		table.insert(args, "cl")
		table.insert(args, self.Colours.Text)
		table.insert(args, "][")
	end

	if self.Colours[levelValue] then
		table.insert(args, self.Colours[levelValue])
		table.insert(args, level)
		table.insert(args, self.Colours.Text)
		table.insert(args, "] ")
	else
		table.insert(args, level .. "] ")
	end

	local _prt = self._print
	local function prt(...)
		if (select(1, ...)) == true then
			_prt(select(2, ...))
		end

		if self.Level > levelValue then
			return
		end

		_prt(...)
	end

	self[level] = BENCH.Functional.partial(
		prt,
		unpack(args)
	)
	self["Force" .. level] = BENCH.Functional.partial(
		prt,
		true,
		unpack(args)
	)
end

-- @function logging:Fatal(...)
-- Emit a Fatal Level Log.
logging:Build("Fatal")

-- @function logging:Error(...)
-- Emit a Error Level Log.
logging:Build("Error")

-- @function logging:Warning(...)
-- Emit a Warning Level Log.
logging:Build("Warning")

-- @function logging:Info(...)
-- Emit a Info Level Log.
logging:Build("Info")

-- @function logging:Debug(...)
-- Emit a Debug Level Log.
logging:Build("Debug")

concommand.Add("internet_benchmark_logging_report", function()
	local last = math.huge
	local cur = logging.Level

	local l = logging
	local c = l.Colours
	local t = c.Text

	MsgC(unpack(flatten(l:Brand(), " Logging Configuration Report\n")))
	MsgC(t, "Logging is configurable, to be as chatty or quiet as required.\n")
	MsgC(t, "For this, we have various logging levels, representing how dire a log represents.\n")
	MsgC(t, "The `internet_benchmark_logging_level` ConVar is used to control which of these output.\n")
	MsgC(t, "Any logs at the given level or above will be shown.\n")
	MsgC(t, "Any logs below will be hidden.\n\n")

	for name, level in SortedPairsByValue(l.Levels, true) do
		if name == "DEFAULT" or name:StartWith("_") then
			continue
		end

		if cur < last and cur > level then
			MsgC(t, "--> Current Logging Level (" .. cur .. ")\n")
		end

		local args = {}
		local color = level < cur and c.Disabled or c[level] or nil
		if color then
			table.insert(args, color)
		end
		table.insert(args, name)
		table.insert(args, "\n")
		MsgC(t, cur == level and "--> " or "    ", unpack(args))

		last = level
	end

	MsgC("\n", t, "Below here, we'll print one of each log, in decending order of severity.\n\n")
	l.Fatal("Example Fatal Log")
	l.Error("Example Error Log")
	l.Warning("Example Warning Log")
	l.Info("Example Informational Log")
	l.Debug("Example Debug Log")
end, nil, "Report on which logging levels will be reported by Internet's Benchmark Suite.")
