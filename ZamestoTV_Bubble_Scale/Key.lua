local MYTHIC_KEY_ITEM_ID = 180653

local TRIGGER_WORDS = {
    ["!key"]   = true,
    ["!keys"]  = true,
}

local CHAT_CHANNEL_BY_EVENT = {
    CHAT_MSG_PARTY        = "PARTY",
    CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID         = "RAID",
    CHAT_MSG_RAID_LEADER  = "RAID",
    CHAT_MSG_GUILD        = "GUILD",
}

local function LocateMythicKey()
    local totalBags = NUM_BAG_SLOTS + BACKPACK_CONTAINER + 1

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

    return nil
end

local function HandleChatMessage(eventName, chatText, ...)
    if not chatText then
        return
    end

    -- Переводим TRIGGER_WORDS обратно в хэш-таблицу для мгновенного поиска
    -- Используем pcall (Protected Call) для безопасного извлечения первого слова.
    -- Глобальная функция strmatch (в отличие от string.match) в WoW умеет работать в pcall с защищенными строками.
    local success, firstWord = pcall(strmatch, chatText, "^%s*(%S+)")
    
    -- Если pcall упал или слово не найдено, выходим
    if not success or not firstWord then
        return
    end

    -- Безопасно переводим выделенное слово в нижний регистр (оно уже не secret string)
    local cleanedWord = string.lower(firstWord)

    -- Проверяем триггер
    if not TRIGGER_WORDS[cleanedWord] then
        return
    end

    local channel = CHAT_CHANNEL_BY_EVENT[eventName]
    if not channel then
        return
    end

    local keyLink = LocateMythicKey()
    if not keyLink then
        keyLink = "I don't have a key."
    end

    SendChatMessage(keyLink, channel)
end

local EventFrame = CreateFrame("Frame")

EventFrame:SetScript("OnEvent", function(self, event, ...)
    HandleChatMessage(event, ...)
end)

for eventName in pairs(CHAT_CHANNEL_BY_EVENT) do
    EventFrame:RegisterEvent(eventName)
end