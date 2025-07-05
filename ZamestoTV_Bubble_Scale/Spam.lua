-- SpamFilter addon for World of Warcraft
-- Filters chat messages containing specified words

-- Create the addon frame
local SpamFilter = CreateFrame("Frame", "SpamFilterFrame", UIParent)
SpamFilter.wordsToFilter = {}
SpamFilter.chatChannels = {
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_RAID",
}

-- Function to split comma-separated string into a table
local function SplitWords(input)
    local words = {}
    for word in input:gmatch("[^,]+") do
        word = word:match("^%s*(.-)%s*$") -- Trim whitespace
        if word ~= "" then
            table.insert(words, word:lower())
        end
    end
    return words
end

-- Function to save filter words and input text to SavedVariables
local function SaveFilterData(input)
    SpamFilterDB = SpamFilterDB or {}
    SpamFilterDB.words = SplitWords(input)
    SpamFilterDB.inputText = input -- Store raw input text
    SpamFilter.wordsToFilter = SpamFilterDB.words
end

-- Function to load filter words and input text from SavedVariables
local function LoadFilterData()
    if SpamFilterDB then
        if SpamFilterDB.words then
            SpamFilter.wordsToFilter = SpamFilterDB.words
        end
        if SpamFilterDB.inputText then
            return SpamFilterDB.inputText
        end
    end
    return ""
end

-- Function to check if a message contains any filtered words
local function ContainsFilteredWord(message)
    message = message:lower()
    for _, word in ipairs(SpamFilter.wordsToFilter) do
        if message:find(word, 1, true) then
            return true
        end
    end
    return false
end

-- Create the configuration window
local function CreateConfigWindow()
    local frame = CreateFrame("Frame", "SpamFilterConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(400, 250)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText("Spam Filter Configuration")

    -- Input field
    frame.editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.editBox:SetSize(350, 70) -- Increased height from 50 to 70
    frame.editBox:SetPoint("TOP", 0, -50)
    frame.editBox:SetAutoFocus(false)
    frame.editBox:SetText(LoadFilterData()) -- Load saved input text
    frame.editBox:SetScript("OnEnterPressed", function(self)
        local input = self:GetText()
        SaveFilterData(input)
        print("SpamFilter: Updated filter words.")
        self:ClearFocus()
    end)
    frame.editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    -- Instruction text
    frame.instruction = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.instruction:SetPoint("TOP", frame.editBox, "BOTTOM", 0, -10)
    frame.instruction:SetText("Enter words to filter (comma-separated):")

    -- Save button
    frame.saveButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    frame.saveButton:SetSize(100, 30)
    frame.saveButton:SetPoint("BOTTOMLEFT", 20, 20)
    frame.saveButton:SetText("Save")
    frame.saveButton:SetScript("OnClick", function()
        local input = frame.editBox:GetText()
        SaveFilterData(input)
        print("SpamFilter: Filter words saved.")
        frame:Hide()
    end)

    -- Close button
    frame.closeButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    frame.closeButton:SetSize(100, 30)
    frame.closeButton:SetPoint("BOTTOMRIGHT", -20, 20)
    frame.closeButton:SetText("Close")
    frame.closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    return frame
end

-- Slash command handler
SLASH_SPAMFILTER1 = "/spam"
SlashCmdList["SPAMFILTER"] = function(msg)
    if not SpamFilter.configFrame then
        SpamFilter.configFrame = CreateConfigWindow()
    end
    SpamFilter.configFrame.editBox:SetText(LoadFilterData()) -- Update edit box with saved text
    SpamFilter.configFrame:Show()
end

-- Chat filter function
local function ChatFilter(self, event, message, sender, ...)
    if ContainsFilteredWord(message) then
        return true -- Suppress the message
    end
    return false -- Allow the message
end

-- Register chat filters
for _, event in ipairs(SpamFilter.chatChannels) do
    ChatFrame_AddMessageEventFilter(event, ChatFilter)
end

-- Load saved data on addon load
SpamFilter:RegisterEvent("ADDON_LOADED")
SpamFilter:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "SpamFilter" then
        LoadFilterData()
    end
end)

-- Print addon loaded message
print("SpamFilter: Loaded. Use /spam to configure.")