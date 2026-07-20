local addonName, addon = ...

-- Create main frame for handling loading events
local frame = CreateFrame("Frame", "NoChatBubblesInInstancesFrame", UIParent)

-- Database for saving settings
NoChatBubblesInInstancesDB = NoChatBubblesInInstancesDB or { enabled = true }

-- Instance types where chat bubbles should be disabled
local instanceTypes = {
    party = true, -- Dungeons
    raid  = true, -- Raids
    pvp   = true, -- Battlegrounds
    arena = true  -- Arenas
}

local function UpdateChatBubblesCVar()
    if not NoChatBubblesInInstancesDB.enabled then 
        if GetCVar("ChatBubbles") ~= "1" then SetCVar("ChatBubbles", 1) end
        return 
    end

    local inInstance, instanceType = IsInInstance()
    
    if inInstance and instanceTypes[instanceType] then
        if GetCVar("ChatBubbles") ~= "0" then
            SetCVar("ChatBubbles", 0)
        end
    else
        if GetCVar("ChatBubbles") ~= "1" then
            SetCVar("ChatBubbles", 1)
        end
    end
end

-- Track loading events
frame:SetScript("OnEvent", function(self, event, ...)
    UpdateChatBubblesCVar()
end)

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("LOADING_SCREEN_DISABLED")

C_Timer.NewTicker(2.0, function()
    if not InCombatLockdown() then
        UpdateChatBubblesCVar()
    end
end)

-- Slash commands
SLASH_HIDEREIDCHATON1 = "/hidereidchaton"
SlashCmdList["HIDEREIDCHATON"] = function(msg)
    NoChatBubblesInInstancesDB.enabled = true
    UpdateChatBubblesCVar()
    print("NoChatBubblesInInstances: Enabled. Chat bubbles will be disabled when entering instances.")
end

SLASH_HIDEREIDCHATOFF1 = "/hidereidchatoff"
SlashCmdList["HIDEREIDCHATOFF"] = function(msg)
    NoChatBubblesInInstancesDB.enabled = false
    SetCVar("ChatBubbles", 1)
    print("NoChatBubblesInInstances: Disabled. Chat bubbles are now permanently enabled.")
end

-- Debug command
SLASH_HIDEREIDCHATDEBUG1 = "/hidereidchatdebug"
SlashCmdList["HIDEREIDCHATDEBUG"] = function(msg)
    local inInst, instType = IsInInstance()
    print("Status: Enabled="..tostring(NoChatBubblesInInstancesDB.enabled)..", CVar="..tostring(GetCVar("ChatBubbles"))..", In Combat="..tostring(InCombatLockdown()))
end