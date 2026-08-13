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
		RoundedBox(0, 0, 0, 100, 100, c)
	End()
end

TRIAL
	:Function(a)
	:Label("DrawRect")
	:Function(b)
	:Label("RoundedBox")
