local ply = INTERNET()
local pMeta = FindMetaTable("Player")

local direct
if SERVER then
	function direct()
		return ply._clgdata.pass
	end
else
	function direct()
		return ply._cityrp_global[ply].pass
	end
end

local function nsViaPly()
	return ply:GetNSVar("pass")
end

local function nsViaMeta()
	return pMeta.GetNSVar(ply, "pass")
end

local function accessViaPly()
	return ply:GetPass()
end

local function accessViaMeta()
	return pMeta.GetPass(ply)
end

return {
	meta = {
		order = 1
	},
	functions = {
		{title = "direct access", func = direct},
		{title = "getnsvar via pmeta", func = nsViaMeta},
		{title = "getnsvar via player", func = nsViaPly},
		{title = "accessor via pmeta", func = accessViaMeta},
		{title = "accessor via player", func = accessViaPly}
	}
}
