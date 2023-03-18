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
-------------------------------------------------------------------------------
-- Define some local constants
local addonName = "Rexxar" -- Use this constant wherever possible, to facilitate code re-use)
local width, height = 512, 384	-- Width and height of parent frame (before scaling)
local scale = 1.4 -- Scale multiplier for width and height of parent frame
local insets = { left = 40, right = -40, top = -40, bottom = 40 } -- Insets are relative to the edges of the parent frame
local portrait = 132176 -- This FileDataID references "interface\\icons\\ability_hunter_killcommand"

-- Implement a table for text strings
local tText = {
	"Rexxar's Academy\n\n",
	'I am Rexxar, champion of the Horde, master to the beasts of the wilds, and I instruct you to ... err ... "focus". Or you will be eaten by wild beasts. Mine.',
	"Measures",
	"GCD Timer",
	"I really mean it about the beasts!",
}

-- Implement a table for fonts
local tFonts = { "QuestTitleFont", "QuestTitleFontBlackShadow", }

-- Implement an index and table for spell/aura objects
local iSpells = {	1, 272790, 34026, 19574, 61304 }

local tSpells = {}
	tSpells[1] =  {nil, "Inactive time" } -- spellID --> iconID, spell/aura name
	tSpells[272790] = { 2058007, "Frenzy downtime\n(< 3 stacks)" }
	tSpells[34026] = { 132176, "Kill Command\n(Off-CD time)" }
	tSpells[19574] = { 132127, "Bestial Wrath\n(Off-CD time)" }
	tSpells[61304] = { nil, "Global Cooldown" }

-- Debugging function to recursively print the contents of a table (eg. a frame)
local function DumpTable(tbl, lvl) -- Parameters are the table(tbl) and the recursion level (lvl): initially 0 ie. table (tbl)
	for k, v in pairs(tbl) do 
		print(strrep("-->", lvl), format("[%s] ", k), v) -- Each recursion level is indented relative to the level that called it
		if (type(v) == "table") then 
			DumpTable(v, lvl + 1)
		end
	end
end

-- Debugging function to search the available fonts for a key string (eg. "quest")
local function DumpFonts(key)
	for i, v in ipairs(GetFonts()) do
		if (strmatch(v:lower(), key:lower()) ~= nil) then print(i, v) end -- Search is case-insensitive
	end
end

-- Create the parent frame for our addon (includes a portrait, title bar, close button and event handlers)
local frame, events = CreateFrame("Frame", addonName, UIParent, "PortraitFrameTemplate"), {}
frame:SetPoint("CENTER")
frame:SetSize(1, 1)

-- Import an Atlas texture to use as the background
local t = frame:CreateTexture()
t:SetDrawLayer("BACKGROUND", -5) -- Push down our new texture from ("ARTWORK", 0) to just above the parent frame's background
t:SetPoint("BOTTOM")
t:SetAtlas("UI-Frame-Necrolord-CardParchment", true) -- The "true" resizes our texture (t) to match the imported texture
t:SetSize(scale * t:GetWidth(), scale * (t:GetHeight() + frame.TitleContainer:GetHeight()))
frame:SetWidth(t:GetWidth()) -- Resize the parent frame as well
frame:SetHeight(t:GetHeight() + frame.TitleContainer:GetHeight())

-- Make the parent frame draggable
frame:SetMovable(true)
frame:SetScript("OnMouseDown", function(self, button) self:StartMoving() end)
frame:SetScript("OnMouseUp", function(self, button) self:StopMovingOrSizing() end)

-- Display the mouseover tooltip
frame:SetScript("OnEnter", function(self, motion)
	GameTooltip:SetOwner(self, "ANCHOR_PRESERVE") -- Keeps the tooltip text in its default position
	GameTooltip:AddLine(addonName .. ": Only beasts are above deceit.")
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
_G["SLASH_" .. string.upper(addonName) .. "1"] = "/" .. string.upper(string.sub(addonName, 1, 2))
_G["SLASH_" .. string.upper(addonName) .. "2"] = "/" .. string.lower(string.sub(addonName, 1, 2))
SlashCmdList[string.upper(addonName)] = cbSlash
--[[
-- Set our screen update handler for the statistics
frame:SetScript("OnUpdate", function(self, elapsed)
	local start, duration = GetSpellCooldown(spellID[1]) -- GetSpellCooldown(spellID) tracks the spell's CD and the GCD
	if (duration > 0) then 
		local expiry = start + duration - GetTime()
	end
end)
--]]

-- Disply a line of ordinary text
local function SetText(base, text, iFont, justifyH)
 	local m = frame:CreateFontString(nil, "BACKGROUND", tFonts[iFont])
	m:SetPoint("TOPLEFT", frame, "TOPLEFT", insets.left, base)
	m:SetPoint("TOPRIGHT", frame, "TOPRIGHT", insets.right, base)
	m:SetJustifyH(justifyH)
	m:SetText(text)
	return m:GetHeight()
end

-- Display a line with a monitor
local function CreateMonitor(base, iSpells, iFont)
 	local m = frame:CreateFontString(nil, "BACKGROUND", tFonts[iFont])
	m:SetPoint("TOPLEFT", frame, "TOPLEFT", insets.left, base)
	m:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", insets.right, base - 54)
	m:SetJustifyH("LEFT")
	m:SetJustifyV("CENTER")
	m:SetText(tSpells[iSpells][2])
	return m:GetHeight()
end

local function CreateKPI(base, index)
	local f = frame:CreateFrame("Frame", nil, frame)
	f:SetPoint("TOPLEFT", frame, "TOPLEFT", insets.left, bookmark) 
 end

local function SetSeparator(base, text) -- Parameters are the current value of bookmark (base) and an index into the tText table (index)
	local t = frame:CreateTexture(nil, "BACKGROUND")
	t:SetAtlas("GarrMission_RewardsBanner", true)
	t:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
	t:SetPoint("TOPLEFT", frame, "TOPLEFT", insets.left, base)
	t:SetWidth(frame:GetWidth() + insets.right - insets.left)
	SetText(base - 20, text, 1, "CENTER")
	return t:GetHeight()
end

--[[
	Define and register various OnEvent handlers for our frame
--]]
function events:ADDON_LOADED(name)
	if (name == addonName) then
		-- Set the portrait (at top-left corner of the frame)
		frame:GetPortrait():SetTexture(portrait)

		-- Set the title (at top edge of the frame)
		frame:SetTitleOffsets(0, 0, 0, 0) -- Center the title horizontally in the frame (instead of in the title bar) 
		frame:SetTitle(addonName .. "'s Academy")

		-- Initialise the contents of the frame
		local bookmark = insets.top - frame.TitleContainer:GetHeight()
		bookmark = bookmark - SetText(bookmark, tText[1], 2, "CENTER") -- Header
		bookmark = bookmark - SetText(bookmark, tText[2], 1, "LEFT") -- Introduction
		bookmark = bookmark - SetSeparator(bookmark, tText[3]) -- Separator (Measures = KPIs)

		for i, v in ipairs(iSpells) do -- KPIs
			if (i < #iSpells) then bookmark = bookmark - CreateMonitor(bookmark, v, 1) end
		end

		bookmark = bookmark - SetSeparator(bookmark, tText[4]) -- Separator (GCD Timer)
		bookmark = bookmark - SetText(bookmark, tText[5], 1, "CENTER") -- Footer

DumpTable(GetFontInfo("QuestTitleFont"), 0)

		frame:UnregisterEvent("ADDON_LOADED")
		print(addonName .. ": Addon has loaded")
	end
end

function events:PLAYER_LOGOUT()
	frame:UnregisterAllEvents()
	print(addonName .. ": Time for a break ...")
end

-- Register all the events for which we provide a separate handling function (above)
frame:SetScript("OnEvent", function(self, event, ...) events[event](self, ...) end)
for k, v in pairs(events) do frame:RegisterEvent(k) end
