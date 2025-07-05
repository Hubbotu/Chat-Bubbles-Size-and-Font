local addonName, addon = ...

-- Create the main frame for event handling
local frame = CreateFrame("Frame", "NoChatBubblesInInstancesFrame", UIParent)

-- Saved variable to track enabled state
NoChatBubblesInInstancesDB = NoChatBubblesInInstancesDB or { enabled = true }

-- Instance types to disable chat bubbles
local instanceTypes = {
    "party", -- Dungeons
    "raid",  -- Raids
    "pvp",   -- Battlegrounds
    "arena"  -- Arenas
}

-- Check if the player is in a relevant instance
local function IsInRelevantInstance()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        return false
    end
    for _, type in ipairs(instanceTypes) do
        if instanceType == type then
            return true
        end
    end
    return false
end

-- Toggle chat bubbles based on instance status
local function ToggleChatBubbles()
    if NoChatBubblesInInstancesDB.enabled then
        if IsInRelevantInstance() then
            SetCVar("ChatBubbles", 0)
            SetCVar("chatBubbles", 0) -- Fallback for potential CVar naming
        else
            SetCVar("ChatBubbles", 1)
            SetCVar("chatBubbles", 1) -- Fallback for potential CVar naming
        end
    end
end

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "UPDATE_UI_WIDGET" then
        ToggleChatBubbles()
    end
end)

-- Register events
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("UPDATE_UI_WIDGET")

-- Optional UI to mimic WeakAuras icons
local function CreateIcon(name, iconID, x, y, width, height)
    local iconFrame = CreateFrame("Frame", name, UIParent)
    iconFrame:SetSize(width, height)
    iconFrame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    
    local texture = iconFrame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexture(iconID)
    
    local text = iconFrame:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    text:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetText(name == "NoChatBubblesInInstances_Disable" and "Disable" or "Enable")
    
    iconFrame:SetAlpha(0) -- Match WeakAuras alpha setting
end

-- Create icons to mimic WeakAuras (optional, as they are mostly visual)
CreateIcon("NoChatBubblesInInstances_Disable", 2056011, 0, 0, 64, 64)
CreateIcon("NoChatBubblesInInstances_Enable", 2056011, 0, 0, 64, 64)

-- Slash commands to enable/disable the addon
SLASH_HIDEREIDCHATON1 = "/hidereidchaton"
SlashCmdList["HIDEREIDCHATON"] = function(msg)
    NoChatBubblesInInstancesDB.enabled = true
    ToggleChatBubbles()
    print("NoChatBubblesInInstances: Enabled. Chat bubbles are now " .. (IsInRelevantInstance() and "hidden" or "shown") .. " in " .. (IsInRelevantInstance() and "instances" or "open world") .. ".")
end

SLASH_HIDEREIDCHATOFF1 = "/hidereidchatoff"
SlashCmdList["HIDEREIDCHATOFF"] = function(msg)
    NoChatBubblesInInstancesDB.enabled = false
    SetCVar("ChatBubbles", 1)
    SetCVar("chatBubbles", 1) -- Fallback for potential CVar naming
    print("NoChatBubblesInInstances: Disabled. Chat bubbles are now shown.")
end

-- Debug command to check state
SLASH_HIDEREIDCHATDEBUG1 = "/hidereidchatdebug"
SlashCmdList["HIDEREIDCHATDEBUG"] = function(msg)
    local cvarValue = GetCVar("ChatBubbles")
    print("NoChatBubblesInInstances: Enabled = " .. tostring(NoChatBubblesInInstancesDB.enabled) .. ", ChatBubbles CVar = " .. tostring(cvarValue) .. ", In instance = " .. tostring(IsInRelevantInstance()))
end