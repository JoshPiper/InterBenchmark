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
	:Describe("Reaches into the gamemode's internal per-player table directly, bypassing its accessor layer entirely - only correct as long as that internal structure doesn't change.")
	:Function(nsViaMeta)
	:Label("getnsvar via pmeta")
	:Describe("Calls the metatable's function directly via the captured pMeta upvalue, skipping the __index lookup that ply:GetNSVar(...) has to perform on every call to find the method.")
	:Function(nsViaPly)
	:Label("getnsvar via player")
	:Function(accessViaMeta)
	:Label("accessor via pmeta")
	:Describe("The same pMeta shortcut as above, applied to the dedicated GetPass() accessor instead of the generic NSVar lookup.")
	:Function(accessViaPly)
	:Label("accessor via player")
	:ManualPredefine(1, 2)
	:Exclude("ply")
	:Exclude("pMeta")
