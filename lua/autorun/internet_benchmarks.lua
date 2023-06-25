AddCSLuaFile()

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

function BENCH:Include(path, isFull)
	if not isFull then
		path = "internet_benchmark/" .. path
		if not path:EndsWith(".lua") then
			path = path .. ".lua"
		end
	end

	local prefix = path:match("/?(%w%w)[%w_]*.lua$") or "sh"
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

function BENCH:IncludeDir(path)
	path = "internet_benchmark/" .. path
	if not path:EndWith("/") then
		path = path .. "/"
	end

	if self.Logging then
		self.Logging.Debug("Including Directory: '", path, "'")
	end

	local search = path:EndWith("*") and path or (path .. "*")
	local files = file.Find(search)
	for _, name in ipairs(files) do
		self:Include(path .. name, true)
	end
end

BENCH:Include("libs/sh_functional")
BENCH:Include("libs/sh_logging")
