--- The report's in-game viewer.
--- Since HTMLReport() now renders a single self-contained document, it can be
--- handed straight to a DHTML panel instead of only being written to disk.

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

--- Open (or reuse) the report viewer, and load a report into it.
---@param html string A complete, self-contained report document.
function BENCH:OpenReport(html)
	if IsValid(self._ReportFrame) then
		self._ReportBrowser:SetHTML(html)
		self._ReportFrame:SetVisible(true)
		self._ReportFrame:MakePopup()
		return
	end

	local frame = vgui.Create("DFrame")
	frame:SetTitle("Benchmarking Report")
	frame:SetSize(math.min(1280, ScrW() * 0.9), math.min(860, ScrH() * 0.9))
	frame:Center()
	frame:SetDeleteOnClose(false)
	frame:MakePopup()

	local browser = vgui.Create("DHTML", frame)
	browser:Dock(FILL)
	browser:SetHTML(html)

	self._ReportFrame = frame
	self._ReportBrowser = browser
end
