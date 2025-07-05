local ADDON_NAME = ...
local URL_PATTERN = "([Hh][Tt][Tt][Pp][Ss]?://%S+)"

-- Hook chat frames
local function AddClickableURLs(frame)
    if frame == nil or frame.hasURLHook then return end
    frame.hasURLHook = true

    local originalAddMessage = frame.AddMessage
    frame.AddMessage = function(self, text, ...)
        if type(text) == "string" then
            text = text:gsub(URL_PATTERN, function(url)
                return string.format("|Hurl:%s|h|cff00ccff[%s]|r|h", url, url)
            end)
        end
        return originalAddMessage(self, text, ...)
    end
end

-- Tooltip & copy box
local function ShowCopyBox(url)
    StaticPopupDialogs["COPY_URL_POPUP"] = {
        text = "Copy this URL:",
        button1 = "Close",
        hasEditBox = true,
        hasWideEditBox = true,
        editBoxWidth = 350,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(self)
            self.editBox:SetText(url)
            self.editBox:SetFocus()
            self.editBox:HighlightText()
        end,
    }
    StaticPopup_Show("COPY_URL_POPUP")
end

-- Handle hyperlink clicks
local orig_SetItemRef = SetItemRef
SetItemRef = function(link, text, button, chatFrame)
    local linkType, url = link:match("^(.-):(.+)$")
    if linkType == "url" then
        ShowCopyBox(url)
    else
        orig_SetItemRef(link, text, button, chatFrame)
    end
end

-- Hook all chat windows
for i = 1, NUM_CHAT_WINDOWS do
    AddClickableURLs(_G["ChatFrame"..i])
end

-- Handle new frames (like temporary chat windows)
hooksecurefunc("FCF_OpenTemporaryWindow", function()
    for i = 1, NUM_CHAT_WINDOWS do
        AddClickableURLs(_G["ChatFrame"..i])
    end
end)
