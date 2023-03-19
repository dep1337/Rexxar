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
local width, height = 512, 384	-- Width and height of parent frame (before scaling) 
local scale = 1.4 -- Scale multiplier for width and height of parent frame
local insets = { left = 40, right = -40, top = -40, bottom = 40 } -- Insets are relative to the edges of the parent frame
local portrait = 2031684 -- This FileDataID references "interface\\icons\\inv_rexxar"

-- Define our fonts
CreateFont("Rexxar_Small"):SetFont("Fonts\\skurri.ttf", 8, "") -- Dark Red
Rexxar_Small:SetTextColor(0.25, 0, 0, 1)

CreateFont("Rexxar_Normal"):SetFont("Fonts\\skurri.ttf", 16, "") -- Dark Red
Rexxar_Normal:SetTextColor(0.25, 0, 0, 1)

CreateFont("Rexxar_Header"):SetFont("Fonts\\skurri.ttf", 20, "") -- Larger text in a Darker Red
Rexxar_Header:SetTextColor(0.15, 0, 0, 1)
	
CreateFont("Rexxar_KPI"):SetFont("Fonts\\skurri.ttf", 16, "") -- Black (for passing KPIs)
Rexxar_KPI:SetTextColor(0, 0, 0, 1)

CreateFont("Rexxar_Highlight"):SetFont("Fonts\\skurri.ttf", 16, "") -- Bright Red (for failing KPIs)
Rexxar_Highlight:SetTextColor(1, 0, 0, 1)

-- Implement a table for text strings
local tText = {
	addonName .. ": Only beasts are above deceit.", -- Tooltip text
	addonName .. "'s Academy", -- Title text for tile bar
	"-for-", -- Extra two lines for the title in the frame
	"Wayward Hunters",
	'\nI am Rexxar, champion of the Horde, master to the beasts of the wilds, and I require you to ... err ... "focus" on your studies. Or you will be eaten by wild beasts. Mine.',
	"I really mean it about the beasts!", -- Footer text
}

-- Implement an index and table for spell/aura objects
local iSpells = {	1, 272790, 34026, 19574, 61304 } -- index --> spellID (the key for the Spells table)

local tSpells = {}
	tSpells[1] =  { 236398, "Inactive time" } -- spellID --> iconID, spell/aura name
	tSpells[272790] = { 2058007, "Frenzy downtime\n(< 3 stacks)" }
	tSpells[34026] = { 132176, "Kill Command\n(Off-CD time)" }
	tSpells[19574] = { 132127, "Bestial Wrath\n(Off-CD time)" }
	tSpells[61304] = { nil, "Global Cooldown" }

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

-- Debugging function to search the available fonts for a key string (eg. "quest")
local function dumpFonts(key)
	for i, v in ipairs(GetFonts()) do
		if (strmatch(strlower(v), strlower(key)) ~= nil) then print(i, v) end -- Search is case-insensitive
	end
end

-----------------------------------------------------------------------------
-- SECTION 2: Create the parent frame and implement core functionality
-----------------------------------------------------------------------------
-- Create the parent frame for our addon (includes a portrait, title bar, close button and event handlers)
local frame, events = CreateFrame("Frame", addonName, UIParent, "PortraitFrameTemplate"), {}
frame:SetPoint("CENTER")

-- Import an Atlas texture into the background
local t = frame:CreateTexture()
t:SetDrawLayer("BACKGROUND", -5) -- Push down our new texture from ("ARTWORK", 0) to just above the parent frame's background
t:SetPoint("BOTTOM")
t:SetAtlas("UI-Frame-Necrolord-CardParchment", true) -- The "true" resizes our texture (t) to match the imported texture
t:SetSize(scale * t:GetWidth(), scale * (t:GetHeight() + frame.TitleContainer:GetHeight()) + 50) -- Resize our texture
frame:SetWidth(t:GetWidth()) -- Resize the parent frame as well
frame:SetHeight(t:GetHeight() + frame.TitleContainer:GetHeight())

-- Make the parent frame draggable
frame:SetMovable(true)
frame:SetScript("OnMouseDown", function(self, button) self:StartMoving() end)
frame:SetScript("OnMouseUp", function(self, button) self:StopMovingOrSizing() end)

-- Display the mouseover tooltip
frame:SetScript("OnEnter", function(self, motion)
	GameTooltip:SetOwner(self, "ANCHOR_PRESERVE") -- Keeps the tooltip text in its default position
	GameTooltip:AddLine(tText[1])
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
-- Display a small "exit" button (at top-right)
local bExit = frame:CreateTexture()
bExit:SetDrawLayer("BACKGROUND", -3)
bExit:SetPoint("CENTER", frame, "TOPRIGHT", insets.right, insets.top - frame.TitleContainer:GetHeight())
bExit:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare", true)
bExit:SetSize(scale * bExit:GetWidth(), scale * bExit:GetHeight())
bExit:EnableMouse(true)
--bExit:SetMouseClickEnabled(true)
print("Motion", bExit:IsMouseMotionEnabled())
print("Mouse", bExit:IsMouseEnabled())
print("Click", bExit:IsMouseClickEnabled())
bExit:SetScript("OnMouseDown", function(self, ...) frame:Hide() end)

-- Display a small "close" button (at bottom)
local bClose = frame:CreateTexture()
bClose:SetDrawLayer("BACKGROUND", -3)
bClose:SetPoint("CENTER", frame, "BOTTOM", 0, insets.bottom)
bClose:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-IconRing", true)
bClose:SetSize(scale * bClose:GetWidth(), scale * bClose:GetHeight())

-- Display a second small button (at bottom)
local bBtn1 = frame:CreateTexture()
bBtn1:SetDrawLayer("BACKGROUND", -3)
bBtn1:SetPoint("CENTER", frame, "BOTTOM", -frame:GetWidth()/6, insets.bottom)
bBtn1:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-IconRing", true)
bBtn1:SetSize(scale * bBtn1:GetWidth(), scale * bBtn1:GetHeight())

-- Display a third small button (at bottom)
local bBtn2 = frame:CreateTexture()
bBtn2:SetDrawLayer("BACKGROUND", -3)
bBtn2:SetPoint("CENTER", frame, "BOTTOM", frame:GetWidth()/6, insets.bottom)
bBtn2:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-IconRing", true)
bBtn2:SetSize(scale * bBtn2:GetWidth(), scale * bBtn2:GetHeight())

-----------------------------------------------------------------------------
-- SECTION 4: Define object methods
-----------------------------------------------------------------------------
-- Display a line of ordinary text
local function setText(base, text, font, justifyH) -- Only the first two parameters (base and text) are required
 	local m = frame:CreateFontString(nil, "BACKGROUND")
	m:SetFontObject(font or "Rexxar_Normal")
	m:SetPoint("TOPLEFT", frame, "TOPLEFT", insets.left, base)
	m:SetPoint("TOPRIGHT", frame, "TOPRIGHT", insets.right, base)
	m:SetJustifyH(justifyH or "LEFT")
	m:SetJustifyV("CENTER")
	m:SetText(text) -- This is the *global* function
	return m:GetHeight()
end

-- Display a separator banner with a sub-heading
local function setSeparator(base, text) -- Parameters are the current value of bookmark (base) and a sub-heading (text)
	local t = frame:CreateTexture(nil, "BACKGROUND")
	t:SetAtlas("GarrMission_RewardsBanner", true)
	t:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
	t:SetPoint("TOPLEFT", frame, "TOPLEFT", insets.left, base)
	t:SetWidth(frame:GetWidth() + insets.right - insets.left)
	setText(base - 22, text, Rexxar_Normal, "CENTER")
	return t:GetHeight()
end

-- Set up a KPI line, consisting of icon, description and value
local function createKPI(base, spell) -- Parameters are the current value of bookmark (base) and a spellID (spell)
	local f = CreateFrame("Frame", nil, frame)
	f:SetPoint("TOPLEFT", frame, "TOPLEFT", insets.left, base) 
	f:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", insets.right, base - 56)
	local a = 56
	local c = 90
	local b = f:GetWidth() - (a + c)

	local t = f:CreateTexture()
	t:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
	t:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", a - 4, 4)
	SetPortraitToTexture(t, tSpells[spell][1])

	local key = f:CreateFontString(nil, "BACKGROUND")
	key:SetFontObject("Rexxar_Normal")
	key:SetPoint("TOPLEFT", f, "TOPLEFT", a + 4, 0)
	key:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -c, 0)
	key:SetJustifyH("LEFT")
	key:SetJustifyV("CENTER")
	key:SetText(tSpells[spell][2]) -- This is the *global* function
	
	local value = f:CreateFontString(nil, "BACKGROUND")
	value:SetFontObject("Rexxar_KPI")
	value:SetPoint("TOPLEFT", f, "TOPLEFT", a + b, 0)
	value:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	value:SetJustifyH("RIGHT")
	value:SetJustifyV("CENTER")
	value:SetText(tSpells[spell][2]) -- This is the *global* function
	return f:GetHeight()
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
		frame:GetPortrait():SetTexture(portrait)

		-- Set the title (at top edge of the frame)
		frame:SetTitleOffsets(0, 0, 0, 0) -- Center the title horizontally in the frame (instead of in the title bar) 
		frame:SetTitle(tText[2]) -- Title

		-- Display the header and introductory paragraph
		local bookmark = insets.top - frame.TitleContainer:GetHeight()
		bookmark = bookmark - setText(bookmark, tText[2], Rexxar_Header, "CENTER") -- Title/Header
		bookmark = bookmark - setText(bookmark, tText[3], Rexxar_Normal, "CENTER") -- Header line 2
		bookmark = bookmark - setText(bookmark, tText[4], Rexxar_Header, "CENTER") -- Header line 3
		bookmark = bookmark - setText(bookmark, tText[5]) -- Introductory paragraph
		
		-- Initialise the KPIs
		bookmark = bookmark - setSeparator(bookmark, "Tests")
		for i, v in ipairs(iSpells) do
			if (i < #iSpells) then bookmark = bookmark - createKPI(bookmark, v) end
		end

		-- GCD Timer: Initialise the status bar
		bookmark = bookmark - setSeparator(bookmark, "GCD Timer")
		local GCD = frame:CreateTexture()
		GCD:SetDrawLayer("BACKGROUND", -3)
		GCD:SetPoint("TOP", frame, "TOP", 0, bookmark)
		GCD:SetAtlas("honorsystem-bar-frame-small", true)

		-- GCD Timer: Add an icon to the status bar
		local g = frame:CreateTexture()
		g:SetPoint("CENTER", frame, "TOPLEFT", insets.left, bookmark - 20)
		SetPortraitToTexture(g, tSpells[1][1])
		g:SetSize(24, 24)
		bookmark = bookmark - GCD:GetHeight() - 12

		-- Display the footer
		bookmark = bookmark - setText(bookmark, tText[6], nil, "CENTER")

		frame:UnregisterEvent("ADDON_LOADED")
		print(addonName .. ": What do you ask of Rexxar?")
	end
end

function events:PLAYER_LOGOUT()
	frame:UnregisterAllEvents()
	print(addonName .. ": Time for hibernation ...")
end

-- Register all the events for which we provide a separate handling function (above)
frame:SetScript("OnEvent", function(self, event, ...) events[event](self, ...) end)
for k, v in pairs(events) do frame:RegisterEvent(k) end
