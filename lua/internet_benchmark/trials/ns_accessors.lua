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

TRIAL
	:Function(direct)
	:Label("direct access")
	:Function(nsViaMeta)
	:Label("getnsvar via pmeta")
	:Function(nsViaPly)
	:Label("getnsvar via player")
	:Function(accessViaMeta)
	:Label("accessor via pmeta")
	:Function(accessViaPly)
	:Label("accessor via player")
	:ManualPredefine(1, 2)
	:Exclude("ply")
	:Exclude("pMeta")
