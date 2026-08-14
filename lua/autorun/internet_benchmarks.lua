AddCSLuaFile()

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

--- The suite's semantic version.
BENCH.Version = "2.0.0"

--- Include a file, obeying the sh/sv/cl realm prefix of its file name.
--- Files without a recognised prefix are treated as shared.
--- @param path string Path to the file, relative to lua/internet_benchmark unless isFull is set.
--- @param isFull boolean? If set, the path is treated as relative to lua/.
--- @param forceState string? Override the detected realm prefix ("sh", "sv" or "cl").
function BENCH:Include(path, isFull, forceState)
	if not isFull then
		path = "internet_benchmark/" .. path
		if not path:EndsWith(".lua") then
			path = path .. ".lua"
		end
	end

	local name = path:match("([^/]+)$") or path
	local prefix = name:sub(1, 2)
	if prefix ~= "sh" and prefix ~= "sv" and prefix ~= "cl" then
		prefix = "sh"
	end
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

--- Recursively include a directory, obeying realm prefixes.
--- @param path string Path to the directory, relative to lua/internet_benchmark.
--- @param forceState string? Override the detected realm prefix for every file.
function BENCH:IncludeDir(path, forceState)
	local full = "internet_benchmark/" .. path
	if not full:EndsWith("/") then
		full = full .. "/"
	end

	if self.Logging then
		self.Logging.Debug("Including Directory: '", full, "'")
	end

	local files, folders = file.Find(full .. "*", "LUA")
	for _, name in ipairs(files or {}) do
		self:Include(full .. name, true, forceState)
	end
	for _, name in ipairs(folders or {}) do
		self:IncludeDir(path .. "/" .. name, forceState)
	end
end

BENCH:Include("libs/sh_functional")
BENCH:Include("libs/sh_logging")
BENCH:Include("libs/sh_formatting")
BENCH:Include("libs/sh_templating")
BENCH:Include("libs/sh_introspection")
BENCH:Include("classes/sh_trial")
BENCH:Include("sh_environment")
BENCH:Include("sh_core")
BENCH:Include("sh_reporting")
BENCH:Include("cl_reporting")
BENCH:Include("sh_commands")

if SERVER then
	-- Trials and templates are only ever executed on demand, but they must be
	-- on the client download list so clients can generate their own reports.
	-- The "cl" force state adds them to the list without including them here.
	BENCH:IncludeDir("trials", "cl")
	BENCH:IncludeDir("templates", "cl")
end
