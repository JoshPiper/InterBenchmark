AddCSLuaFile()
INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
INTERNET_BENCHMARK.ClassLoader = INTERNET_BENCHMARK.ClassLoader or {}
local cl = INTERNET_BENCHMARK.ClassLoader

cl.Classes = {}
cl.Path = string.format("%s/classes", debug.getinfo(1, "S").short_src:match("lua/(.*)/classloader.lua$"))

function cl:ClassPath(class)
	local classFile = class:EndsWith(".lua") and class or string.format("%s.lua", class)
	return string.format("%s/%s", self.Path, classFile)
end

function cl:ClassExists(class)
	return file.Exists(self:ClassPath(class), "LUA")
end

function cl:New(class, ...)
	if not self.Classes[class] then
		if self:ClassExists(class) then
			self.Classes[class] = include(self:ClassPath(class))
		else
			error(string.format("Attempted to autoload non-existant class: %s", class))
		end
	end

	local classDat = self.Classes[class]
	return classDat.New and classDat:New(...) or classDat
end

function cl:OnLoad()
	local files = file.Find(string.format("%s/*.lua", self.Path), "LUA")
	for _, f in ipairs(files) do
		AddCSLuaFile(string.format("%s/%s", self.Path, f))
	end
end

INTERNET_BENCHMARK.ClassLoader = setmetatable(cl, {
	__index = INTERNET_BENCHMARK,
	__call = function(self, class)
		if class == nil then
			return self:OnLoad()
		else
			return self:New(class)
		end
	end
})
INTERNET_BENCHMARK.ClassLoader()
print(cl("trial"))
