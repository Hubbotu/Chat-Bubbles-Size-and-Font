local ADDON, ns = ...
local Key = ns:NewModule("Key")
local issecret = ns.IsSecret

local MYTHIC_KEY_ITEM_ID = 180653

local TRIGGER_WORDS = { ["!key"] = true, ["!keys"] = true }

local CHANNEL_BY_EVENT = {
    CHAT_MSG_PARTY                = "PARTY",
    CHAT_MSG_PARTY_LEADER         = "PARTY",
    CHAT_MSG_RAID                 = "RAID",
    CHAT_MSG_RAID_LEADER          = "RAID",
    CHAT_MSG_GUILD                = "GUILD",
    CHAT_MSG_INSTANCE_CHAT        = "INSTANCE_CHAT",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
}

-- Returns the keystone hyperlink from the player's bags, or nil.
function Key:Locate()
    local last = (NUM_BAG_SLOTS or 4) + 1
    for bag = 0, last do
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots and slots > 0 then
            for slot = 1, slots do
                local id = C_Container.GetContainerItemID(bag, slot)
                local link = C_Container.GetContainerItemLink(bag, slot)
                if link and (id == MYTHIC_KEY_ITEM_ID or link:find("|Hkeystone:", 1, true)) then
                    return link
                end
            end
        end
    end
    return nil
end

-- Best channel for asking the group "!key" (used by the chat bar button).
function Key:GroupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    if IsInGuild() then return "GUILD" end
end

-- Chat bar button: ask the group for keys; answer locally when alone.
function Key:Ask()
    local channel = self:GroupChannel()
    if channel then
        if not ns.SendChat("!key", channel) then
            ns:Print("Chat messages from addons are blocked right now (encounter, Mythic+ or PvP).")
        end
    else
        ns:Print(self:Locate() or "I don't have a key.")
    end
end

local lastReply = 0

local function OnChat(event, text)
    if not ns.db.key.enabled then return end
    if not text or issecret(text) then return end

    local ok, firstWord = pcall(strmatch, text, "^%s*(%S+)")
    if not ok or not firstWord then return end
    if not TRIGGER_WORDS[firstWord:lower()] then return end

    local channel = CHANNEL_BY_EVENT[event]
    if not channel then return end

    -- The same line can trigger several events; answer at most once every few seconds.
    if ns.ChatLocked() then return end
    local now = GetTime()
    if now - lastReply < 3 then return end
    lastReply = now

    -- During an encounter / M+ / PvP the game forbids addon chat; stay silent then.
    ns.SendChat(Key:Locate() or "I don't have a key.", channel)
end

function Key:OnInit()
    local f = CreateFrame("Frame")
    f:SetScript("OnEvent", function(_, event, text) OnChat(event, text) end)
    for event in pairs(CHANNEL_BY_EVENT) do f:RegisterEvent(event) end

    SLASH_ZTVKEY1 = "/key"
    SlashCmdList["ZTVKEY"] = function() Key:Ask() end
end
