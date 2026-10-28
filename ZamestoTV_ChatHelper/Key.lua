local ADDON, ns = ...
local Key = ns:NewModule("Key")
local issecret = ns.IsSecret

local MYTHIC_KEY_ITEM_ID = 180653

-- Поддерживаем оба варианта написания триггеров в чате
local TRIGGER_WORDS = {
    ["!key"] = true,
    ["!keys"] = true,
    ["/key"] = true,
    ["/keys"] = true,
}

local CHANNEL_BY_EVENT = {
    CHAT_MSG_PARTY                = "PARTY",
    CHAT_MSG_PARTY_LEADER         = "PARTY",
    CHAT_MSG_RAID                 = "RAID",
    CHAT_MSG_RAID_LEADER          = "RAID",
    CHAT_MSG_GUILD                = "GUILD",
    CHAT_MSG_INSTANCE_CHAT        = "INSTANCE_CHAT",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
}

-- Надежный поиск ключа в сумках
local function LocateMythicKey()
    local totalBags = (NUM_BAG_SLOTS or 4) + (BACKPACK_CONTAINER or 0) + 1

    for containerIndex = 0, totalBags do
        local slotCount = C_Container.GetContainerNumSlots(containerIndex)
        if slotCount and slotCount > 0 then
            for slotIndex = 1, slotCount do
                local itemID = C_Container.GetContainerItemID(containerIndex, slotIndex)
                if itemID == MYTHIC_KEY_ITEM_ID then
                    return C_Container.GetContainerItemLink(containerIndex, slotIndex)
                end
            end
        end
    end

    -- Запасной поиск по ключевым словам в ссылке
    for containerIndex = 0, totalBags do
        local slotCount = C_Container.GetContainerNumSlots(containerIndex)
        if slotCount and slotCount > 0 then
            for slotIndex = 1, slotCount do
                local link = C_Container.GetContainerItemLink(containerIndex, slotIndex)
                if link and (link:find("keystone", 1, true) or link:find("Ключ", 1, true)) then
                    return link
                end
            end
        end
    end

    return nil
end

function Key:Locate()
    return LocateMythicKey()
end

-- Игра запрещает аддонам писать в чат, пока активна блокировка
-- (бой с боссом, М+, PvP). Проверяем только её: в обычной ситуации
-- сообщение отправляется как раньше, а во время блокировки мы молчим,
-- вместо того чтобы получить ADDON_ACTION_BLOCKED.
local function ChatLocked()
    local ci = C_ChatInfo
    if ci and ci.InChatMessagingLockdown then
        local ok, locked = pcall(ci.InChatMessagingLockdown)
        return ok and locked and true or false
    end
    return false
end

local function Send(message, channel)
    if ChatLocked() then return false end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    return pcall(send, message, channel) and true or false
end

-- Определение лучшего канала для отправки
function Key:GroupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    if IsInGuild() then return "GUILD" end
end

-- Кнопка "K" на панели: отправляет ваш ключ в чат группы
function Key:Ask()
    local channel = self:GroupChannel()
    local keyLink = LocateMythicKey() or "У меня нет ключа."

    if channel then
        if not Send(keyLink, channel) then
            ns:Print("Чат заблокирован игрой (бой/М+). Ключ: " .. keyLink)
        end
    else
        ns:Print(keyLink)
    end
end

local lastReply = 0

local function OnChat(event, text)
    if ns.db and ns.db.key and ns.db.key.enabled == false then return end
    if not text or (issecret and issecret(text)) then return end

    local ok, firstWord = pcall(strmatch, text, "^%s*(%S+)")
    if not ok or not firstWord then return end
    if not TRIGGER_WORDS[firstWord:lower()] then return end

    local channel = CHANNEL_BY_EVENT[event]
    if not channel then return end

    -- Защита от спама (не чаще раза в 3 секунды)
    local now = GetTime()
    if now - lastReply < 3 then return end

    local keyLink = LocateMythicKey()
    if not keyLink then
        return -- Если ключа нет в сумках, ничего не отправляем
    end

    if Send(keyLink, channel) then lastReply = now end
end

function Key:OnInit()
    local f = CreateFrame("Frame")
    f:SetScript("OnEvent", function(_, event, text) OnChat(event, text) end)
    for event in pairs(CHANNEL_BY_EVENT) do f:RegisterEvent(event) end

    -- Слэш-команды /key и /keys намеренно НЕ регистрируются: они принадлежат
    -- BigWigs (список ключей группы), и наш аддон, загружаясь позже, перехватывал бы их.
end
