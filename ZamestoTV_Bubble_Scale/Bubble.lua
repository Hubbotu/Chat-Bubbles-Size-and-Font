local addonName, addonTable = ...

-- SavedVariables table
FreeChatDB = FreeChatDB or {}

-- Create the main frame
local frame = CreateFrame("Frame", "FreeChatFrame", UIParent, "UIPanelDialogTemplate")
frame:SetSize(250, 170)
frame:SetPoint("CENTER")
frame:Hide() -- Hidden by default
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

-- Frame title
frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frame.title:SetPoint("TOP", frame, "TOP", 0, -10)
frame.title:SetText("Chat Bubbles Size")

-- Font size input box
local sizeEditBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
sizeEditBox:SetSize(100, 20)
sizeEditBox:SetPoint("TOP", frame.title, "BOTTOM", 0, -20)
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
sizeLabel:SetPoint("BOTTOMLEFT", sizeEditBox, "TOPLEFT", 0, 5)
sizeLabel:SetText("Font Size")

-- Font selection dropdown
local fontDropdown = CreateFrame("Frame", "FreeChatFontDropdown", frame, "UIDropDownMenuTemplate")
fontDropdown:SetPoint("TOP", sizeEditBox, "BOTTOM", 0, -20)
UIDropDownMenu_SetWidth(fontDropdown, 150)

-- Font options
local fontOptions = {
    { text = "Default", value = "default" },
    { text = "Literata", value = "Interface\\AddOns\\"..addonName.."\\Literata.ttf" },
    { text = "Noto", value = "Interface\\AddOns\\"..addonName.."\\front.ttf" }
}

-- Store the default font
local defaultFont, defaultSize, defaultFlags = ChatBubbleFont:GetFont()

-- Initialize dropdown
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

-- Font dropdown label
local fontLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
fontLabel:SetPoint("BOTTOMLEFT", fontDropdown, "TOPLEFT", 16, 5)
fontLabel:SetText("Font")

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
end)