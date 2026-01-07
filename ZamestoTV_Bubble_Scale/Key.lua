local MYTHIC_KEY_ITEM_ID = 180653

local TRIGGER_WORDS = {
	["!key"] = true,
	["!keys"] = true,
}

local CHAT_CHANNEL_BY_EVENT = {
	CHAT_MSG_PARTY = "PARTY",
	CHAT_MSG_PARTY_LEADER = "PARTY",
	CHAT_MSG_RAID = "RAID",
	CHAT_MSG_RAID_LEADER = "RAID",
	CHAT_MSG_GUILD = "GUILD",
}

local function NormalizeText(text)
	if type(text) ~= "string" then
		return ""
	end
	return text:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

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

local function IsTriggerMessage(text)
	return TRIGGER_WORDS[NormalizeText(text)] == true
end

local function HandleChatMessage(eventName, chatText)
	if InCombatLockdown() then
		return
	end

	if not IsTriggerMessage(chatText) then
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

EventFrame:SetScript("OnEvent", function(_, event, ...)
	local messageText = ...
	HandleChatMessage(event, messageText)
end)

for eventName in pairs(CHAT_CHANNEL_BY_EVENT) do
	EventFrame:RegisterEvent(eventName)
end
