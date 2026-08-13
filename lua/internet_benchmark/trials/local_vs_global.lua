local function a()
	type(3)
end

local t = type
local function b()
	t(3)
end

TRIAL
	:Name("Local vs Global")
	:Description("Whether caching a global function in a local before calling it is worth the extra local, for a single call. The global lookup goes through _G's hash table; the local capture turns it into a plain upvalue read.")
	:Order(1)
	:Function(a)
	:Label("type(3)")
	:Function(b)
	:Label("t(3)")
