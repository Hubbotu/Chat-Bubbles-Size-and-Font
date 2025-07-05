local addonName, addonTable = ...

-- SavedVariables table
FreeChatDB = FreeChatDB or {}

-- Create the main frame
local frame = CreateFrame("Frame", "FreeChatFrame", UIParent, "UIPanelDialogTemplate")
frame:SetSize(360, 450) -- Adjusted frame size to accommodate new buttons and divider
frame:SetPoint("CENTER")
frame:Hide() -- Hidden by default
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

-- Frame title
frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frame.title:SetPoint("TOP", frame, "TOP", 0, -8)
frame.title:SetText("Chat Helper 4.05")

-- Subtitle: Selecting a font and its size
local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
subtitle:SetPoint("TOP", frame.title, "BOTTOM", 0, -10)
subtitle:SetText("Selecting a font and its size:")

-- Font size input box
local sizeEditBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
sizeEditBox:SetSize(80, 20)
sizeEditBox:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 150, -10)
sizeEditBox:SetAutoFocus(false)
sizeEditBox:SetNumeric(true)
sizeEditBox:SetMaxLetters(3)
sizeEditBox:SetScript("OnEnterPressed", function(self)
    local size = tonumber(self:GetText())
    if size and size > 0 then
        local font = FreeChatDB.font or ChatBubbleFont:GetFont()
        ChatBubbleFont:SetFont(font, size, "OUTLINE")
        FreeChatDB.size = size
        self:ClearFocus()
    end
end)
sizeEditBox:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
end)

-- Font size label
local sizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sizeLabel:SetPoint("RIGHT", sizeEditBox, "LEFT", -10, 0)
sizeLabel:SetText("Font Size")

-- Font selection dropdown
local fontDropdown = CreateFrame("Frame", "FreeChatFontDropdown", frame, "UIDropDownMenuTemplate")
fontDropdown:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -40, -10)
UIDropDownMenu_SetWidth(fontDropdown, 80)

-- Font dropdown label
local fontLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
fontLabel:SetPoint("RIGHT", fontDropdown, "LEFT", 10, 5)
fontLabel:SetText("Font")

-- Dividing line
local divider = frame:CreateTexture(nil, "OVERLAY")
divider:SetColorTexture(1, 1, 1, 0.2)
divider:SetSize(338, 2)
divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -90)

-- Chat settings label
local settingsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
settingsLabel:SetPoint("TOP", divider, "BOTTOM", 0, -10)
settingsLabel:SetText("Chat Settings:")

-- S/H button
local showHideButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
showHideButton:SetSize(50, 25)
showHideButton:SetPoint("TOPLEFT", settingsLabel, "BOTTOMLEFT", -100, -10)
showHideButton:SetText("S/H")
showHideButton:SetScript("OnClick", function()
    SlashCmdList["BOOMCHAT"]()
end)

-- Show/Hide chat buttons label
local showHideLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
showHideLabel:SetPoint("LEFT", showHideButton, "RIGHT", 10, 0)
showHideLabel:SetText("- Show/Hide chat buttons.")

-- B/U button
local blockUnblockButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
blockUnblockButton:SetSize(50, 25)
blockUnblockButton:SetPoint("TOPLEFT", showHideButton, "BOTTOMLEFT", 0, -10)
blockUnblockButton:SetText("B/U")
blockUnblockButton:SetScript("OnClick", function()
    SlashCmdList["BOOMLOCK"]()
end)

-- Block/Unblock chat buttons label
local blockUnblockLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
blockUnblockLabel:SetPoint("LEFT", blockUnblockButton, "RIGHT", 10, 0)
blockUnblockLabel:SetText("- Block/Unblock chat buttons.")

-- V/H button
local verticalHorizontalButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
verticalHorizontalButton:SetSize(50, 25)
verticalHorizontalButton:SetPoint("TOPLEFT", blockUnblockButton, "BOTTOMLEFT", 0, -10)
verticalHorizontalButton:SetText("V/H")
verticalHorizontalButton:SetScript("OnClick", function()
    SlashCmdList["BOOMROTATE"]()
end)

-- Vertical/Horizontal chat buttons label
local verticalHorizontalLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
verticalHorizontalLabel:SetPoint("LEFT", verticalHorizontalButton, "RIGHT", 10, 0)
verticalHorizontalLabel:SetText("- Vertical/Horizontal chat buttons.")

-- HINT button
local hintButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
hintButton:SetSize(50, 25)
hintButton:SetPoint("TOPLEFT", verticalHorizontalButton, "BOTTOMLEFT", 0, -10)
hintButton:SetText("HINT")
hintButton:SetScript("OnClick", function()
    SlashCmdList["BOOMTEXT"]()
end)

-- Add hints to chat buttons label
local hintLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hintLabel:SetPoint("LEFT", hintButton, "RIGHT", 10, 0)
hintLabel:SetText("- Add hints to chat buttons.")

-- Reduce/Increase size label
local sizeAdjustLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sizeAdjustLabel:SetPoint("TOPLEFT", hintButton, "BOTTOMLEFT", -1, -10)
sizeAdjustLabel:SetText("Reduce/Enlarge chat buttons:")

-- Plus button
local plusButton = CreateFrame("Button", nil, frame)
plusButton:SetSize(25, 25)
plusButton:SetPoint("LEFT", sizeAdjustLabel, "RIGHT", 10, 0)
plusButton:SetNormalTexture("Interface\\AddOns\\ZamestoTV_Bubble_Scale\\Media\\plus")
plusButton:SetScript("OnClick", function()
    SlashCmdList["BOOMSIZE"]("1")
end)

-- Minus button
local minusButton = CreateFrame("Button", nil, frame)
minusButton:SetSize(25, 25)
minusButton:SetPoint("LEFT", plusButton, "RIGHT", 5, 0)
minusButton:SetNormalTexture("Interface\\AddOns\\ZamestoTV_Bubble_Scale\\Media\\minus")
minusButton:SetScript("OnClick", function()
    SlashCmdList["BOOMSIZE"]("-1")
end)

-- Second dividing line
local divider2 = frame:CreateTexture(nil, "OVERLAY")
divider2:SetColorTexture(1, 1, 1, 0.2)
divider2:SetSize(338, 2)
divider2:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -290)

-- Spam settings label
local spamSettingsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
spamSettingsLabel:SetPoint("TOP", divider2, "BOTTOM", 0, -10)
spamSettingsLabel:SetText("Spam Settings:")

-- Spam button
local spamButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
spamButton:SetSize(50, 25)
spamButton:SetPoint("TOPLEFT", spamSettingsLabel, "BOTTOMLEFT", -100, -10)
spamButton:SetText("Spam")
spamButton:SetScript("OnClick", function()
    SlashCmdList["SPAMFILTER"]()
end)

-- Enable spam settings label
local spamLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
spamLabel:SetPoint("LEFT", spamButton, "RIGHT", 10, 0)
spamLabel:SetText("- Enable spam settings in the chat.")

-- Third dividing line
local divider3 = frame:CreateTexture(nil, "OVERLAY")
divider3:SetColorTexture(1, 1, 1, 0.2)
divider3:SetSize(338, 2)
divider3:SetPoint("TOPLEFT", spamButton, "BOTTOMLEFT", -23, -10)

-- Disable Chat Bubbles in Raids and Dungeons label
local raidDungeonLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
raidDungeonLabel:SetPoint("TOP", divider3, "BOTTOM", 0, -10)
raidDungeonLabel:SetText("Disable Chat Bubbles in Raids and Dungeons:")

-- On button
local onButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
onButton:SetSize(50, 25)
onButton:SetPoint("TOPLEFT", raidDungeonLabel, "BOTTOMLEFT", 50, -10)
onButton:SetText("On")
onButton:SetScript("OnClick", function()
    SlashCmdList["HIDEREIDCHATON"]()
end)

-- Off button
local offButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
offButton:SetSize(50, 25)
offButton:SetPoint("LEFT", onButton, "RIGHT", 60, 0)
offButton:SetText("Off")
offButton:SetScript("OnClick", function()
    SlashCmdList["HIDEREIDCHATOFF"]()
end)

-- Font options
local fontOptions = {
    { text = "Default", value = "default" },
    { text = "Literata", value = "Interface\\AddOns\\"..addonName.."\\Literata.ttf" },
    { text = "Noto", value = "Interface\\AddOns\\"..addonName.."\\front.ttf" },
    { text = "Arial", value = "Fonts\\ARIALN.ttf" },
    { text = "Roboto", value = "Interface\\AddOns\\"..addonName.."\\Roboto.ttf" },
    { text = "Open Sans", value = "Interface\\AddOns\\"..addonName.."\\OpenSans.ttf" },
    { text = "Merriweather", value = "Interface\\AddOns\\"..addonName.."\\Merriweather.ttf" },
    { text = "Caveat", value = "Interface\\AddOns\\"..addonName.."\\Caveat.ttf" }
}

-- Store the default font
local defaultFont, defaultSize, defaultFlags = ChatBubbleFont:GetFont()

-- Initialize_dropdown
UIDropDownMenu_Initialize(fontDropdown, function(self, level)
    for _, option in ipairs(fontOptions) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = option.text
        info.value = option.value
        info.func = function(self)
            local font = self.value
            local size = tonumber(sizeEditBox:GetText()) or FreeChatDB.size or defaultSize
            if font == "default" then
                ChatBubbleFont:SetFont(defaultFont, size, defaultFlags)
                FreeChatDB.font = defaultFont
            else
                ChatBubbleFont:SetFont(font, size, "OUTLINE")
                FreeChatDB.font = font
            end
            FreeChatDB.size = size
            UIDropDownMenu_SetSelectedValue(fontDropdown, font)
        end
        UIDropDownMenu_AddButton(info)
    end
end)

-- Slash command to toggle frame
SLASH_FREECHAT1 = "/freechat"
SlashCmdList["FREECHAT"] = function()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        -- Set current font size in edit box
        local size = FreeChatDB.size or select(2, ChatBubbleFont:GetFont())
        sizeEditBox:SetText(tostring(floor(size)))
        -- Set current font in dropdown
        local font = FreeChatDB.font or defaultFont
        UIDropDownMenu_SetSelectedValue(fontDropdown, font == defaultFont and "default" or font)
    end
end

-- Slash command for spam settings
SLASH_SPAM1 = "/spam"
SlashCmdList["SPAM"] = function()
    FreeChatDB.spamEnabled = not FreeChatDB.spamEnabled
    if FreeChatDB.spamEnabled then
        print("Chat spam settings enabled")
    else
        print("Chat spam settings disabled")
    end
end

-- Event frame to handle PLAYER_ENTERING_WORLD
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event)
    -- Initialize with current or saved font settings
    defaultFont, defaultSize, defaultFlags = ChatBubbleFont:GetFont()
    local font = FreeChatDB.font or defaultFont
    local size = FreeChatDB.size or defaultSize
    ChatBubbleFont:SetFont(font, size, font == defaultFont and defaultFlags or "OUTLINE")
    sizeEditBox:SetText(tostring(floor(size)))
    UIDropDownMenu_SetSelectedValue(fontDropdown, font == defaultFont and "default" or font)
    -- Initialize spam settings
    FreeChatDB.spamEnabled = FreeChatDB.spamEnabled or false
end)