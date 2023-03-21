-----------------------------------------------------------------------------
--  World of Warcraft addon to monitor: 
--	1.	Active time (ie. max(Cast Time, GCD if relevant) / Time in Combat)
--	2.	Frenzy buff (3 stacks)
--	3.	Kill Command (Off-cooldown time)
--	4.	Bestial Wrath (Off-cooldown time)
--
--  (c) March 2023 Duncan Baxter
--
--  License: All available rights reserved to the author
-----------------------------------------------------------------------------
-- SECTION 1: Constant/Variable definitions
-----------------------------------------------------------------------------
-- Define some local constants
local addonName = "Rexxar" -- Use this constant wherever possible, to facilitate code re-use)
local scale = 1.4 -- Scale multiplier for parent frame
local width = 0 -- Width of parent frame after scaling (initialised early in Section 2)
local height= 0 -- Height of parent frame after scaling
local insets = { left = 20 * scale, right = -22 * scale, top = -28 * scale, bottom = 20 * scale } -- Insets are relative to the edges of the parent frame
local usableW = 0 -- Usable width of parent frame (ie. after after scaling and insets) (again, initialised early in Section 2)
local usableH = 0 -- Usable height of parent frame
local portrait = 2031684 -- This FileDataID references "interface\\icons\\inv_rexxar"

-- Define our fonts
CreateFont("Rexxar_Small"):SetFont("Fonts\\skurri.ttf", 8, "") -- Smaller text in Dark Red
Rexxar_Small:SetTextColor(0.25, 0, 0, 1)

CreateFont("Rexxar_Normal"):SetFont("Fonts\\skurri.ttf", 14, "") -- Dark Red
Rexxar_Normal:SetTextColor(0.25, 0, 0, 1)

CreateFont("Rexxar_Header"):SetFont("Fonts\\skurri.ttf", 16, "") -- Larger text in a darker Red
Rexxar_Header:SetTextColor(0.15, 0, 0, 1)
	
CreateFont("Rexxar_Pass"):SetFont("Fonts\\skurri.ttf", 14, "") -- Black (for passing KPIs)
Rexxar_Pass:SetTextColor(0, 0, 0, 1)

CreateFont("Rexxar_Fail"):SetFont("Fonts\\skurri.ttf", 14, "") -- Bright Red (for failing KPIs)
Rexxar_Fail:SetTextColor(1, 0, 0, 1)

-- Implement a table for text strings
local tText = {}
	tText["addonLoaded"] = addonName .. ": Need something tracked?"
	tText["playerLogout"] = addonName .. ": Good hunting."

	tText["ttframe"] = addonName .. ": Only beasts are above deceit."
	tText["ttExit"] = addonName .. ": You can't escape!"
	tText["ttClose"] = addonName .. ": I will hunt you down!"
	tText["ttBtn1"] = addonName .. ": Let's get this business over with."
	tText["ttBtn2"] = addonName .. ": A clean kill."

	tText["header"] = addonName .. "'s Academy\n-for-\nWayward Hunters"
	tText["intro"] = "\nI am Rexxar, champion of the Horde, master to the beasts of the wilds, " ..
										'and I require you to ... err ... "focus" on your studies. ' ..
										"Or you will be eaten by wild beasts. Mine."
	tText["footer"] = "I really mean it about the beasts!"

-- Implement an index and table for spell/aura objects
local iSpells = {	1, 272790, 34026, 19574, 61304 } -- index --> spellID (ordered list of keys to the tSpells table)

local tSpells = {} -- spellID --> iconID, spell/aura name, state, KPI "fail" time for current fight, total KPI "fail" time
	tSpells[1] =  { icon = 236398, text = "Inactive time" } -- There's nothing magic about the "1": "Inactive time" just has no spellID
	tSpells[272790] = { icon = 2058007, text = "Frenzy downtime\n(< 3 stacks)" }
	tSpells[34026] = { icon = 132176, text = "Kill Command\n(Off-CD time)" }
	tSpells[19574] = { icon = 132127, text = "Bestial Wrath\n(Off-CD time)" }
	tSpells[61304] = { icon = 134376, text = "Global Cooldown" } -- Dummy spellID that tracks the Global Cooldown

for k, v in pairs(tSpells) do
	tSpells[k].state = true -- current fail (true)/pass (false) state for this KPI
	tSpells[k].fight = 0 -- "fail" time for this KPI in the current/most recent fight (if in/out of combat)
	tSpells[k].total = 0 -- total "fail" time for this KPI since the data was last reset
end

-----------------------------------------------------------------------------
-- SECTION 1.1: Debugging utilities (remove before release)
-----------------------------------------------------------------------------
-- Debugging function to recursively print the contents of a table (eg. a frame)
local function dumpTable(tbl, lvl) -- Parameters are the table(tbl) and the recursion level (lvl): initially 0 ie. table (tbl)
	for k, v in pairs(tbl) do 
		print(strrep("-->", lvl), format("[%s] ", k), v) -- Each recursion level is indented relative to the level that called it
		if (type(v) == "table") then 
			dumpTable(v, lvl + 1)
		end
	end
end

-- Debugging function to search the list of available fonts for a key string (eg. "quest")
local fontList = GetFonts()
local function findFonts(key)
	for i, v in ipairs(fontList) do
		if (strmatch(strlower(v), strlower(key)) ~= nil) then print(i, v) end -- Search is case-insensitive
	end
end

-----------------------------------------------------------------------------
-- SECTION 2: Create the parent frame and implement core functionality
-----------------------------------------------------------------------------
-- Create the parent frame for our addon (includes a portrait, title bar, tooltip text and event handlers)
-- local frame, events = CreateFrame("Frame", addonName, UIParent, "PortraitFrameTemplate"), {}
local frame, events = CreateFrame("Frame", addonName, UIParent), {}
frame:SetPoint("CENTER")

-- Import an Atlas texture into the background
local page = frame:CreateTexture()
page:SetDrawLayer("BACKGROUND", -8) -- Push down our new texture from ("ARTWORK", 0) to the lowest possible layer
page:SetAtlas("UI-Frame-Necrolord-CardParchment", true) -- The "true" resizes our texture (t) to match the imported texture
page:SetPoint("TOPLEFT")
page:SetPoint("BOTTOMRIGHT")
width, height = scale * page:GetWidth(), scale * page:GetHeight() -- Set the value of these "local constants"
usableW, usableH = width + insets.right - insets.left, height + insets.top - insets.bottom
frame:SetSize(width, height)

-- Make the parent frame draggable
frame:SetMovable(true)
frame:SetScript("OnMouseDown", function(self, button) self:StartMoving() end)
frame:SetScript("OnMouseUp", function(self, button) self:StopMovingOrSizing() end)

-- Display the mouseover tooltip
frame:SetScript("OnEnter", function(self, motion)
	GameTooltip:SetOwner(self, "ANCHOR_PRESERVE") -- Keeps the tooltip text in its default position
	GameTooltip:AddLine(tText["ttframe"])
	GameTooltip:Show()
end)
frame:SetScript("OnLeave", function(self, motion) GameTooltip:Hide() end)

-- Define the callback handler for our slash commands
local function cbSlash(msg, editBox)
	local cmd = msg:lower()
	if (cmd == "show") then frame:Show()
	elseif (cmd == "hide") then frame:Hide()
	elseif (cmd == "reset") then 
		frame:SetPoint("CENTER")
		frame:SetSize(width, height)
	end
	print(addonName .. ": Processed (" .. cmd .. ") command")
end

-- Add our slash commands to the global table
_G["SLASH_" .. strupper(addonName) .. "1"] = "/" .. strlower(strsub(addonName, 1, 2))
_G["SLASH_" .. strupper(addonName) .. "2"] = "/" .. strupper(strsub(addonName, 1, 2))
_G["SLASH_" .. strupper(addonName) .. "3"] = "/" .. strlower(addonName)
_G["SLASH_" .. strupper(addonName) .. "3"] = "/" .. strupper(addonName)
SlashCmdList[strupper(addonName)] = cbSlash

-----------------------------------------------------------------------------
-- SECTION 3: Create the other interactable objects
-----------------------------------------------------------------------------
-- Define function handler for button "OnEnter" scripts
local function cbOnEnter(self, motion)
	self:SetVertexColor(1, 1, 1)
	GameTooltip:SetOwner(self, "ANCHOR_PRESERVE") -- Keeps the tooltip text in its default position
	GameTooltip:AddLine(self.tooltip)
	GameTooltip:Show()
end

-- Define function handler for button "OnLeave" scripts
local function cbOnLeave(self, motion)
	self:SetVertexColor(0.85, 0.85, 0.85)
	GameTooltip:Hide()
end

-- Define function handler for button "OnMouseDown" scripts
local function cbOnMouseDown(self, ...)
	self:SetVertexColor(0.6, 0.6, 0.6)
--	frame:Hide()
end

-- Define function handler for button "OnMouseUp" scripts
local function cbOnMouseUp(self, ...)
	self:SetVertexColor(0.85, 0.85, 0.85)
end

-- Set all the function handlers for a button
local function setAllScripts(self)
self:SetVertexColor(0.85, 0.85, 0.85)
self:EnableMouse(true)
self:SetScript("OnEnter", cbOnEnter)
self:SetScript("OnLeave", cbOnLeave)
self:SetScript("OnMouseDown", cbOnMouseDown)
self:SetScript("OnMouseUp", cbOnMouseUp)
end

--[[ Display a small "exit" button (at top-right)
local bExit = CreateFrame("Button", nil, frame)
--bExit:SetDrawLayer("BACKGROUND", -7)
bExit:SetPoint("TOPRIGHT", page, "TOPRIGHT", insets.top, insets.top)
bExit:SetNormalAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare")
bExit:SetSize(20 * scale, 20 * scale)
print(bExit:GetWidth(), bExit:GetHeight())

--bExit:SetSize(scale * bExit:GetWidth(), scale * bExit:GetHeight())
bExit["tooltip"] = tText.ttExit
bSetAllScripts(bExit)--]]

-- Display a small "exit" button (at top-right)
local bExit = frame:CreateTexture()
bExit:SetDrawLayer("BACKGROUND", -7) -- One layer above the background
bExit:SetPoint("TOPRIGHT", page, "TOPRIGHT", insets.top, insets.top)
bExit:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare", true)
bExit:SetSize(scale * bExit:GetWidth(), scale * bExit:GetHeight())
bExit["tooltip"] = tText.ttExit
setAllScripts(bExit)

-- Display a small "close" button (at bottom)
local bClose = frame:CreateTexture()
bClose:SetDrawLayer("BACKGROUND", -7)
bClose:SetPoint("BOTTOM", page, "BOTTOM", 0, insets.bottom)
bClose:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare", true)
bClose:SetSize(scale * bClose:GetWidth(), scale * bClose:GetHeight())
bClose["tooltip"] = tText.ttClose
setAllScripts(bClose)

-- Display a second small button and its key (to left of "close" button)
local bBtn1 = frame:CreateTexture()
bBtn1:SetDrawLayer("BACKGROUND", -7)
bBtn1:SetPoint("BOTTOM", page, "BOTTOM", -width/6, insets.bottom)
bBtn1:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-IconRing", true)
bBtn1:SetSize(scale * bBtn1:GetWidth(), scale * bBtn1:GetHeight())
bBtn1["tooltip"] = tText.ttBtn1
setAllScripts(bBtn1)

local bBtn1key = frame:CreateFontString(nil, "BACKGROUND")
bBtn1key:SetFontObject("Rexxar_Normal")
bBtn1key:SetPoint("RIGHT", bBtn1, "LEFT", -5, 0)
bBtn1key:SetJustifyH("RIGHT")
bBtn1key:SetJustifyV("CENTER")
bBtn1key:SetText("Button 1")

-- Display a third small button and its key (to right of "close" button)
local bBtn2 = frame:CreateTexture()
bBtn2:SetDrawLayer("BACKGROUND", -7)
bBtn2:SetPoint("BOTTOM", page, "BOTTOM", width/6, insets.bottom)
bBtn2:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-IconRing", true)
bBtn2:SetSize(scale * bBtn2:GetWidth(), scale * bBtn2:GetHeight())
bBtn2["tooltip"] = tText.ttBtn2
setAllScripts(bBtn2)

local bBtn2key = frame:CreateFontString(nil, "BACKGROUND")
bBtn2key:SetFontObject("Rexxar_Normal")
bBtn2key:SetPoint("LEFT", bBtn2, "RIGHT", 5, 0)
bBtn2key:SetJustifyH("LEFT")
bBtn2key:SetJustifyV("CENTER")
bBtn2key:SetText("Button 2")

-----------------------------------------------------------------------------
-- SECTION 4: Define object methods
-----------------------------------------------------------------------------
-- Print a line of ordinary text
local function printText(base, text, font, justifyH) -- Only the first two parameters (base and text) are required
 	local m = frame:CreateFontString(nil, "BACKGROUND")
	m:SetFontObject(font or "Rexxar_Normal")
	m:SetPoint("TOPLEFT", page, "TOPLEFT", insets.left, base)
	m:SetPoint("TOPRIGHT", page, "TOPRIGHT", insets.right, base)
	m:SetJustifyH(justifyH or "LEFT")
	m:SetJustifyV("CENTER")
	m:SetText(text)
	return m:GetHeight()
end

-- Print a KPI value
local function printValue(base, spellID)
	local v = tSpells[spellID].fight
	printText(base, format("%d seconds", v), "Rexxar_KPI", "RIGHT")
end

-- Display a separator banner with a sub-heading
local function setSeparator(base, text) -- Parameters are the current value of bookmark (base) and a sub-heading (text)
	local t = frame:CreateTexture(nil, "BACKGROUND")
	t:SetAtlas("GarrMission_RewardsBanner", true)
	t:SetPoint("TOPLEFT", page, "TOPLEFT", insets.left, base + 5)
	t:SetWidth(usableW)
	printText(base - 18, text, nil, "CENTER")
	return t:GetHeight() - 15
end

-- Set up a KPI line, consisting of icon, description and value
local function createKPI(base, spell) -- Parameters are the current value of bookmark (base) and a spellID (spell)
	local w, h = usableW, 52
	local a = h + 6
	local c = 90
	local b = w - (a + c)

	-- Display a (masked) icon for the KPI
	local t = frame:CreateTexture(nil, "BACKGROUND")
	t:SetTexture(tSpells[spell].icon)
	t:SetPoint("TOPLEFT", page, "TOPLEFT", insets.left + 2, base -2)
	t:SetSize(h - 4, h - 4)

	local tm = frame:CreateMaskTexture()
	tm:SetAllPoints(t)
	tm:SetTexture("interface/masks/circlemaskscalable", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	t:AddMaskTexture(tm)

	-- Display a short description of the KPI
	local key = frame:CreateFontString(nil, "BACKGROUND")
	key:SetFontObject("Rexxar_Normal")
	key:SetPoint("TOPLEFT", page, "TOPLEFT", insets.left + a, base)
	key:SetSize(b, h)
	key:SetJustifyH("LEFT")
	key:SetJustifyV("CENTER")
	key:SetText(tSpells[spell].text)
	
	-- Display the value of the KPI
	local value = frame:CreateFontString(nil, "BACKGROUND")
	if (tSpells[spell].state == true) then
		value:SetFontObject("Rexxar_Fail")
	else 
		value:SetFontObject("Rexxar_Pass")
	end
	value:SetPoint("TOPLEFT", page, "TOPLEFT", insets.left + a + b, base)
	value:SetSize(c, h)
	value:SetJustifyH("RIGHT")
	value:SetJustifyV("CENTER")
	value:SetText(format("%d seconds", tSpells[spell].fight))
	return h
end

-----------------------------------------------------------------------------
-- SECTION 5: Implement functionality for non-interactable objects
-----------------------------------------------------------------------------
--[[ Set our screen update handler for the KPIs
frame:SetScript("OnUpdate", function(self, elapsed)
	local start, duration = GetSpellCooldown(spellID[1]) -- GetSpellCooldown(spellID) tracks the spell's CD and the GCD
	if (duration > 0) then 
		local expiry = start + duration - GetTime()
	end
end)--]]

-----------------------------------------------------------------------------
-- SECTION 6: Define and register any OnEvent handlers for the parent frame
-----------------------------------------------------------------------------
function events:ADDON_LOADED(name)
	if (name == addonName) then
		-- Set the portrait (at top-left corner of the frame)
--		frame:GetPortrait():SetTexture(portrait)

		-- Display the header and introductory paragraph
		local bookmark = insets.top
		bookmark = bookmark - printText(bookmark, tText.header, Rexxar_Header, "CENTER")
		bookmark = bookmark - printText(bookmark, tText.intro)
		
		-- Display the KPIs
		bookmark = bookmark - setSeparator(bookmark, "Tracking")
		for i, v in ipairs(iSpells) do
			if (v ~= 61304) then bookmark = bookmark - createKPI(bookmark, v) end
		end

		-- GCD Timer: Display the status bar
		bookmark = bookmark - setSeparator(bookmark, "GCD Timer")
		local GCD = frame:CreateTexture()
		GCD:SetDrawLayer("BACKGROUND", -6)
		GCD:SetAtlas("honorsystem-bar-frame-small", true)
		local ow = GCD:GetWidth()
		GCD:SetPoint("TOP", page, "TOP", 0, bookmark)
		GCD:SetWidth(usableW)
		GCD:SetHeight(GCD:GetHeight() * GCD:GetWidth() / ow)

		-- GCD Timer: Add a (masked) icon to the status bar
		local GCDicon = frame:CreateTexture(nil, "BACKGROUND")
		GCDicon:SetTexture(tSpells[61304].icon)
		GCDicon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
		GCDicon:SetPoint("CENTER", GCD, "LEFT", 17, 2)
		GCDicon:SetSize(23, 22)

		local GCDmask = frame:CreateMaskTexture()
		GCDmask:SetAllPoints(GCDicon)
		GCDmask:SetTexture("interface/masks/circlemaskscalable", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		GCDicon:AddMaskTexture(GCDmask)
		bookmark = bookmark - GCD:GetHeight() - 12

		-- Display the footer
		bookmark = bookmark - printText(10 - usableH, tText.footer, nil, "CENTER")

		frame:UnregisterEvent("ADDON_LOADED")
		print(tText.addonLoaded)
	end
end

function events:PLAYER_LOGOUT()
	frame:UnregisterAllEvents()
	print(tText.playerLogout)
end

-- Register all the events for which we provide a separate handling function (above)
frame:SetScript("OnEvent", function(self, event, ...) events[event](self, ...) end)
for k, v in pairs(events) do frame:RegisterEvent(k) end
