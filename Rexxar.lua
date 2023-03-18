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
-- Define the more widely-used local variables
local addonName = "Rexxar" -- Use this variable wherever possible, to facilitate code re-use)
local width, height = 512, 384	-- Width and height of parent frame (before scaling)
local scale = 1.4 -- Scale multiplier for width and height of parent frame
local portrait = 132176 -- This FileDataID references "interface\\icons\\ability_hunter_killcommand"

-- Define a table for text strings
local tText = {
"Rexxar's Academy\n\n",
'I am Rexxar, champion of the Horde, master to the beasts of the wilds, and I instruct you to ... err ... "focus". Or you will be eaten by wild beasts. Mine.',
"Statistics",
"GCD Timer",
"I really mean it about the beasts!",
}

-- Define a table for fonts
local tFonts = { "QuestTitleFont", }

-- Define a table for spell/aura objects
local iSpells = {	3, 272790, 34026, 19574, 61304 }

local tSpells = {}
	tSpells[3] =  {0, "Active time" }
	tSpells[272790] = { 2058007, "Frenzy downtime\n(< 3 stacks)" } -- spellID --> iconID, line text
	tSpells[34026] = { 132176, "Kill Command\n(Off-CD time)" }
	tSpells[19574] = { 132127, "Bestial Wrath\n(Off-CD time)" }
	tSpells[61304] = { 0, "Global Cooldown" }

-- Debugging function to recursively print the contents of a table (eg. a frame)
local function DumpTable(tbl, lvl) -- Parameters are the table(tbl) and the recursion level (lvl): initially 0 ie. table (tbl)
	for k,v in pairs(tbl) do 
		print(strrep("-->", lvl), format("[%s] ", k), v) -- Each recursion level is indented relative to the level that called it
		if (type(v) == "table") then 
			DumpTable(v, lvl + 1)
		end
	end
end

-- Create the parent frame for our addon (includes a portrait, title bar, close button and event handlers)
local frame, events = CreateFrame("Frame", addonName, UIParent, "PortraitFrameTemplate"), {}
frame:SetTitleOffsets(0, 0, 0, 0) -- Center the title horizontally in the frame (instead of in the title bar) 
frame:SetTitle(addonName .. "'s Academy")
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

-- Create a frame for one of our monitors
local inset = CreateFrame("Frame", nil, frame) -- No template: could use "FlatPanelBackgroundTemplate" or "InsetFrameTemplate" here
inset:SetSize(1, 1)

-- Import another Atlas texture
local t = inset:CreateTexture()
t:SetDrawLayer("BACKGROUND", -4)
t:SetAtlas("UI-Frame-Mechagon-Portrait", true)
t:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)	-- Select the entirety of the Atlas texture
t:SetAllPoints() -- Lock the texture (t) to the frame
inset:SetSize(t:GetWidth()/3, t:GetHeight()/2) -- Scaling the frame also scales the texture
inset:SetPoint("TOPRIGHT",frame, "TOPRIGHT", -25, -150) -- Moving the frame also moves the texture

local separator = frame:CreateTexture()
separator:SetDrawLayer("BACKGROUND", -3)
separator:SetAtlas("AnimaChannel-CurrencyBorder", true)
separator:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)	-- Select the entirety of the Atlas texture


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
function CreateText(base, iText, iFont, justifyH)
 	local m = frame:CreateFontString(nil, "BACKGROUND", tFonts[iFont])
	local originX = 40
	m:SetPoint("TOPLEFT", frame, "TOPLEFT", originX, base)
	m:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -originX, base)
	m:SetJustifyH(justifyH)
	m:SetText(tText[iText])
	return m
end

-- Display a line with a monitor
function CreateMonitor(base, iSpells, iFont)
 	local m = frame:CreateFontString(nil, "BACKGROUND", tFonts[iFont])
	local originX = 40
	m:SetPoint("TOPLEFT", frame, "TOPLEFT", originX, base)
	m:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -originX, base - inset:GetHeight())
	m:SetJustifyH("LEFT")
	m:SetJustifyV("CENTER")
	m:SetText(tSpells[iSpells][2])
	return m
end

--[[
	Define and register various OnEvent handlers for our frame
--]]
function events:ADDON_LOADED(name)
	if (name == addonName) then
		-- Set the portrait (at top-left corner of the frame)
		frame:GetPortrait():SetTexture(portrait)

		local bookmark = -frame.TitleContainer:GetHeight() - 50

		local textTitle = CreateText(bookmark, 1, 1, "CENTER")
		bookmark = bookmark - textTitle:GetHeight()

		local textHeader = CreateText(bookmark, 2, 1, "LEFT")
		bookmark = bookmark - textHeader:GetHeight()

		local textSub1 = CreateText(bookmark - 20, 3, 1, "CENTER")

		local sep1 = frame:CreateTexture(nil, "BACKGROUND")
		sep1:SetAtlas("GarrMission_RewardsBanner", true)
		sep1:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)	-- Select the entirety of the Atlas texture
		sep1:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, bookmark)
		sep1:SetWidth(frame:GetWidth() - 80)
		bookmark = bookmark - sep1:GetHeight()

		inset:SetPoint("TOPRIGHT",frame, "TOPRIGHT", -40, bookmark) -- Moving the frame also moves the texture
		for i = 1, #iSpells - 1 do
			CreateMonitor(bookmark, iSpells[i], 1)
			bookmark = bookmark - inset:GetHeight()
		end

		local textSub2 = CreateText(bookmark - 20, 4, 1, "CENTER")

		local sep2 = frame:CreateTexture(nil, "BACKGROUND")
		sep2:SetAtlas("GarrMission_RewardsBanner", true)
		sep2:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)	-- Select the entirety of the Atlas texture
		sep2:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, bookmark)
		sep2:SetWidth(frame:GetWidth() - 80)
		bookmark = bookmark - sep2:GetHeight()

		local textFooter = CreateText(bookmark, 5, 1, "CENTER")
		bookmark = bookmark - textFooter:GetHeight()
		
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
