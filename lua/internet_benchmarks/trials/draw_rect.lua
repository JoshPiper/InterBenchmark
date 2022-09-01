local surface = surface
local draw = draw

local SetDrawColor = surface.SetDrawColor
local DrawRect = surface.DrawRect
local RoundedBox = draw.RoundedBox
local Start = cam.Start2D
local End = cam.End2D
local c = Color(100, 150, 200, 255)

local function a()
	Start()
		SetDrawColor(100, 150, 200, 255)
		DrawRect(0, 0, 100, 100)
	End()
end

local function b()
	Start()
		DrawRect(0, 0, 0, 100, 100, c)
	End()
end

return {
	meta = {
		order = 100,
		title = "DrawRect vs RoundedBox",
		-- runs = 100,
		-- iterations = 10000
	},
	functions = {
		{title = "DrawRect", func = a},
		{title = "RoundedBox", func = b}
	}
}
