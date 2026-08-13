-- This trial measures accessor patterns from a specific CityRP-derived
-- gamemode. It only runs where that gamemode's globals are present.
TRIAL
	:Name("NS Accessors")
	:Order(6)
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
