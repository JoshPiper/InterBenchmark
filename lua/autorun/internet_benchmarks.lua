AddCSLuaFile()

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

function BENCH:Include(path, isFull, forceState)
	if not isFull then
		path = "internet_benchmark/" .. path
		if not path:EndsWith(".lua") then
			path = path .. ".lua"
		end
	end

	local prefix = path:match("/?(%w%w)[%w_]*.lua$") or "sh"
	if forceState then
		prefix = forceState
	end
	if self.Logging then
		self.Logging.Debug("Prefix: ", prefix, ". Path: '", path, "'")
	end

	if prefix ~= "sv" then
		AddCSLuaFile(path)
		if CLIENT or prefix == "sh" then
			include(path)
		end
	elseif SERVER then
		include(path)
	end
end

function BENCH:IncludeDir(path, forceState)
	path = "internet_benchmark/" .. path
	if not path:EndsWith("/") then
		path = path .. "/"
	end

	if self.Logging then
		self.Logging.Debug("Including Directory: '", path, "'")
	end

	local search = path:EndsWith("*") and path or (path .. "*")
	local files = file.Find(search, "LUA")
	for _, name in ipairs(files) do
		self:Include(path .. name, true, forceState)
	end
end

BENCH:Include("libs/sh_functional")
BENCH:Include("libs/sh_logging")
BENCH:Include("libs/sh_formatting")
BENCH:Include("libs/sh_templating")
BENCH:Include("classes/sh_trial")
BENCH:Include("sh_core")
BENCH:Include("sh_reporting")

if SERVER then
	-- Force all the trials to be added to the DL list.
	BENCH:IncludeDir("trials", "cl")
end
