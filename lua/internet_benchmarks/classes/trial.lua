
local TRIAL = {}

function TRIAL:New()
	return setmetatable({}, {
		__index = TRIAL
	})
end

return TRIAL
