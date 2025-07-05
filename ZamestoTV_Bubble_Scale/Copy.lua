local upper = string.upper
local TheFrame

local Clear, NoReset, Show = 1, 2, 3

local function DisplayText(text, arg1)
    if not TheFrame then
        local backdrop = {
            bgFile = "Interface/BUTTONS/WHITE8X8",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            edgeSize = 7,
            tileSize = 7,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        }

        local f = CreateFrame("Frame", "CopyChatFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
        TheFrame = f
        f:SetBackdrop(backdrop)
        f:SetBackdropColor(0, 0, 0, 1)
        f:SetPoint("CENTER")
        f:SetSize(600, 400)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetClampedToScreen(true)

        f.Close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.Close:SetPoint("TOPRIGHT", -5, -5)
        f.Close:SetScript("OnClick", function() f:Hide() end)

        f.Scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        f.Scroll:SetPoint("TOPLEFT", f, 10, -30)
        f.Scroll:SetPoint("BOTTOMRIGHT", f, -30, 10)

        f.EditBox = CreateFrame("EditBox", nil, f)
        f.EditBox:SetMultiLine(true)
        f.EditBox:SetFontObject(ChatFontNormal)
        f.EditBox:SetWidth(f:GetWidth())
        f.EditBox:SetAutoFocus(false)
        f.EditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        f.Scroll:SetScrollChild(f.EditBox)
    end

    if not TheFrame:IsShown() then
        TheFrame:Show()
    end

    if arg1 == Show then return end
    if arg1 == NoReset then
        TheFrame.EditBox:SetText(TheFrame.EditBox:GetText() .. "\n" .. text)
    elseif arg1 == Clear then
        TheFrame.EditBox:SetText("")
    else
        TheFrame.EditBox:SetText(text)
    end

    TheFrame.EditBox:ClearFocus()
end

SLASH_COPYCHAT1 = "/copy"
SlashCmdList["COPYCHAT"] = function(msg)
    local param
    if upper(msg) == "ADD" then
        param = NoReset
    elseif upper(msg) == "CLEAR" then
        param = Clear
    elseif upper(msg) == "SHOW" then
        param = Show
        DisplayText("", param)
        return
    end

    local text = ""
    for i = #ChatFrame1.visibleLines, 1, -1 do
        local line = ChatFrame1.visibleLines[i]
        if line and line.messageInfo and line.messageInfo.message then
            text = text .. line.messageInfo.message .. "\n"
        end
    end

    DisplayText(text, param)
end
