local rComp = 100
local gComp = 150
local bComp = 200
local aComp = 255
local color = Color(90, 140, 190)
local colorA = Color(90, 140, 190, 255)

local surface = surface
local setDrawColor = surface.SetDrawColor

local function a()
	setDrawColor(80, 130, 180)
end

local function aa()
	setDrawColor(80, 130, 180, 255)
end

local function b()
	setDrawColor(rComp, gComp, bComp)
end

local function ba()
	setDrawColor(rComp, gComp, bComp, aComp)
end

local function c()
	setDrawColor(Color(70, 120, 170))
end

local function ca()
	setDrawColor(Color(70, 120, 170, 255))
end

local function cc()
	setDrawColor(color)
end

local function cca()
	setDrawColor(colorA)
end

local function d()
	setDrawColor(Color(70, 120, 170):Unpack())
end

local function da()
	setDrawColor(Color(70, 120, 170, 255):Unpack())
end

local function dc()
	setDrawColor(color:Unpack())
end

local function dca()
	setDrawColor(colorA:Unpack())
end

local function e()
	local lColor = Color(70, 120, 170)
	setDrawColor(lColor.r, lColor.g, lColor.b)
end

local function ea()
	local lColor = Color(70, 120, 170, 255)
	setDrawColor(lColor.r, lColor.g, lColor.b, lColor.a)
end

local function ec()
	setDrawColor(color.r, color.g, color.b)
end

local function eca()
	setDrawColor(colorA.r, colorA.g, colorA.b, colorA.a)
end

return {
	meta = {
		order = 100,
		title = "surface.SetDrawColor",
		-- runs = 100,
		-- iterations = 10000
	},
	functions = {
		{title = "numeric set", func = a},
		{title = "numeric set /w alpha", func = aa},
		{title = "numeric var set", func = b},
		{title = "numeric var set /w alpha", func = ba},
		{title = "color", func = c},
		{title = "color /w alpha", func = ca},
		{title = "cached color", func = cc},
		{title = "cached color /w alpha", func = cca},
		{title = "unpacked color", func = d},
		{title = "unpacked /w alpha", func = da},
		{title = "unpacked cached color", func = dc},
		{title = "unpacked cached color /w alpha", func = dca},
		{title = "color components", func = e},
		{title = "color components /w alpha", func = ea},
		{title = "cached color components", func = ec},
		{title = "cached color components /w alpha", func = eca},
	}
}
