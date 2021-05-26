AddCSLuaFile()
INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}

local files = file.Find("internet_benchmarks/*", "LUA")
for _, path in ipairs(files) do
	path = string.format("internet_benchmarks/%s", path)
	print(path)
	include(path)
end

local files = file.Find("internet_benchmarks/trials/*", "LUA")
for _, path in ipairs(files) do
	path = string.format("internet_benchmarks/trials/%s", path)
	AddCSLuaFile(path)
end
