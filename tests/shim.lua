--- A minimal Garry's Mod environment shim.
--- Just enough of GLua to load and test the suite's pure-Lua libraries
--- under a stock LuaJIT interpreter.

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}

SERVER = true
CLIENT = false

-- Garry's Mod ships LuaJIT 2.0 (Lua 5.1) on the public branch, which has no
-- coroutine.isyieldable. Newer interpreters running this suite do, so it is
-- removed here to keep the tests honest about what the game actually provides.
coroutine.isyieldable = nil

function AddCSLuaFile() end
SysTime = os.clock

util = {
	IsBinaryModuleInstalled = function() return false end,
}

-- Console, convar and message surface, enough to load the logging library.
FCVAR_ARCHIVE, FCVAR_ARCHIVE_XBOX, FCVAR_UNLOGGED = 0, 0, 0

function CreateConVar(name, default)
	return {
		GetString = function() return tostring(default) end,
		GetName = function() return name end,
	}
end

cvars = {
	AddChangeCallback = function() end,
	RemoveChangeCallback = function() end,
}

concommand = {
	Add = function() end,
}

function MsgC(...)
	local count = select("#", ...)
	for i = 1, count do
		local value = (select(i, ...))
		if not IsColor(value) then
			io.write(tostring(value))
		end
	end
end

function istable(v) return type(v) == "table" end
function isstring(v) return type(v) == "string" end
function isnumber(v) return type(v) == "number" end
function isfunction(v) return type(v) == "function" end
function isbool(v) return type(v) == "boolean" end

local colorMeta = {}
function Color(r, g, b, a)
	return setmetatable({r = r, g = g, b = b, a = a or 255}, colorMeta)
end
function IsColor(v)
	return getmetatable(v) == colorMeta
end

function math.Round(num, idp)
	local mult = 10 ^ (idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

function math.Clamp(num, low, high)
	return math.min(math.max(num, low), high)
end

function table.GetKeys(tab)
	local keys = {}
	for k in pairs(tab) do
		table.insert(keys, k)
	end

	return keys
end

function table.GetWinningKey(tab)
	local highest, winner = -math.huge, nil
	for k, v in pairs(tab) do
		if v > highest then
			highest, winner = v, k
		end
	end

	return winner
end

function table.Add(dest, source)
	for _, v in ipairs(source) do
		table.insert(dest, v)
	end

	return dest
end

function table.HasValue(tab, value)
	for _, v in pairs(tab) do
		if v == value then
			return true
		end
	end

	return false
end

local function sortedKeyIterator(tab, keys)
	local i = 0
	return function()
		i = i + 1
		local key = keys[i]
		if key ~= nil then
			return key, tab[key]
		end
	end
end

function SortedPairsByValue(tab, descending)
	local keys = table.GetKeys(tab)
	table.sort(keys, function(a, b)
		if descending then
			return tab[a] > tab[b]
		end

		return tab[a] < tab[b]
	end)

	return sortedKeyIterator(tab, keys)
end

function SortedPairsByMemberValue(tab, member, descending)
	local keys = table.GetKeys(tab)
	table.sort(keys, function(a, b)
		if descending then
			return tab[a][member] > tab[b][member]
		end

		return tab[a][member] < tab[b][member]
	end)

	return sortedKeyIterator(tab, keys)
end

-- GLua's string extensions, available as methods on string values.
function string.EndsWith(str, suffix)
	return suffix == "" or str:sub(-#suffix) == suffix
end

function string.StartWith(str, prefix)
	return str:sub(1, #prefix) == prefix
end

function string.Replace(str, find, replace)
	local pattern = find:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
	local replacement = replace:gsub("%%", "%%%%")
	return (str:gsub(pattern, replacement))
end

function string.Trim(str)
	return (str:gsub("^%s*(.-)%s*$", "%1"))
end

function string.Explode(separator, str)
	local out = {}
	local position = 1

	while true do
		local start, stop = str:find(separator, position, true)
		if not start then
			table.insert(out, str:sub(position))
			return out
		end

		table.insert(out, str:sub(position, start - 1))
		position = stop + 1
	end
end
