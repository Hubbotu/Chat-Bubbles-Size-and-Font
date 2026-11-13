local ADDON, ns = ...
local Inst = ns:NewModule("Instances")

-- Turns chat bubbles off inside the chosen instance types and puts the
-- player's own setting back afterwards. Only runs on zone changes, so it
-- never fights a manual change to the option.
function Inst:Update()
    local o = ns.db.bubbles
    local inInstance, kind = IsInInstance()
    local wantOff = o.disable and inInstance and o.types[kind]

    if wantOff then
        local cur = GetCVar("chatBubbles")
        if cur ~= "0" then
            o.saved = cur
            pcall(SetCVar, "chatBubbles", 0)
        end
    elseif o.saved ~= nil then
        pcall(SetCVar, "chatBubbles", o.saved)
        o.saved = nil
    end
end

function Inst:OnInit()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("LOADING_SCREEN_DISABLED")
    f:SetScript("OnEvent", function() Inst:Update() end)

    -- Old command names kept so existing macros keep working.
    SLASH_ZTVHIDEON1 = "/hidereidchaton"
    SlashCmdList["ZTVHIDEON"] = function()
        ns.db.bubbles.disable = true
        Inst:Update()
        ns:Print("Chat bubbles will be disabled in the selected instance types.")
    end
    SLASH_ZTVHIDEOFF1 = "/hidereidchatoff"
    SlashCmdList["ZTVHIDEOFF"] = function()
        ns.db.bubbles.disable = false
        Inst:Update()
        ns:Print("Chat bubbles are no longer disabled in instances.")
    end
end
