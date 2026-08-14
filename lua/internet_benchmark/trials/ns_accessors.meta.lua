-- This trial measures accessor patterns from a specific CityRP-derived
-- gamemode. It only runs where that gamemode's globals are present.
TRIAL
	:Name("NS Accessors")
	:Description(
		"Player data on this gamemode can be reached three ways: a hand-written direct table lookup into internal fields, the gamemode's "
		.. "generic 'namespaced var' (NSVar) system, and dedicated accessor methods layered on top of it - each tried through both the "
		.. "player entity and its metatable directly."
	)
	:Order(6)
	:Tag("default")
	:If(function()
		if not isfunction(INTERNET) then
			return false
		end

		local ok, valid = pcall(function()
			local ply = INTERNET()
			return IsValid(ply)
				and isfunction(ply.GetNSVar)
				and isfunction(ply.GetPass)
				and (SERVER and ply._clgdata or ply._cityrp_global) ~= nil
		end)

		return ok and valid == true
	end)
