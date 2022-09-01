AddCSLuaFile()
INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}

local files = file.Find("internet_benchmarks/*", "LUA")
for _, path in ipairs(files) do
	path = string.format("internet_benchmarks/%s", path)
	include(path)
end

local function AddCSLuaFileRecursive(path)
	print(path)
	local files, folders = file.Find(path .. "*", "LUA")
	PrintTable(files)
	PrintTable(folders)

	for _, f in ipairs(files) do
		AddCSLuaFile(path .. f)
	end
	for _, f in ipairs(folders) do
		AddCSLuaFileRecursive(path .. f .. "/")
	end
end

AddCSLuaFileRecursive("internet_benchmarks/trials/")
AddCSLuaFileRecursive("internet_benchmarks/templates/")
