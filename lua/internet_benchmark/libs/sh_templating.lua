INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK
BENCH.Templating = setmetatable({}, {__index = INTERNET_BENCHMARK})
local TEMPLATE = BENCH.Templating

function TEMPLATE:Replace(template, variables)
	if variables == nil then
		variables = {}
	end
	if not istable(variables) then
		variables = {content = tostring(variables)}
	end

	return string.gsub(template, "%${(.-)}", function(w)
		return variables[w] or ("${" .. w .. "}")
	end)
end

function TEMPLATE:Path(path, type)
	if not type then
		type = "html"
	end
	if type == "html" then
		path = path .. ".html"
	end

	return string.format("internet_benchmark/templates/%s/%s.lua", type, path)
end

function TEMPLATE:Get(path, type)
	return file.Read(self:Path(path, type), "LUA") or ""
end

function TEMPLATE:Template(path, variables, type)
	self.Logging.Debug("Loading Template ", path)
	return self:Replace(
		self:Get(path, type),
		variables
	)
end
