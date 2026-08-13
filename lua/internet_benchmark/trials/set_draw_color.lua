local rComp = 100
local gComp = 150
local bComp = 200
local aComp = 255
local color = Color(90, 140, 190)
local colorA = Color(90, 140, 190, 255)

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

TRIAL
	:Function(a)
	:Label("numeric set")
	:Function(aa)
	:Label("numeric set /w alpha")
	:Function(b)
	:Label("numeric var set")
	:Function(ba)
	:Label("numeric var set /w alpha")
	:Function(c)
	:Label("color")
	:Function(ca)
	:Label("color /w alpha")
	:Function(cc)
	:Label("cached color")
	:Function(cca)
	:Label("cached color /w alpha")
	:Function(d)
	:Label("unpacked color")
	:Function(da)
	:Label("unpacked /w alpha")
	:Function(dc)
	:Label("unpacked cached color")
	:Function(dca)
	:Label("unpacked cached color /w alpha")
	:Function(e)
	:Label("color components")
	:Function(ea)
	:Label("color components /w alpha")
	:Function(ec)
	:Label("cached color components")
	:Function(eca)
	:Label("cached color components /w alpha")
