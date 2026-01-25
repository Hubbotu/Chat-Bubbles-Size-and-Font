local ADDON_NAME = ...
local URL_PATTERN = "([Hh][Tt][Tt][Pp][Ss]?://%S+)"

---------------------------------------------------------
-- Safety helpers
---------------------------------------------------------
local function _SafeCall(fn, ...)
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return true, a, b, c, d end
    return false
end

local function _CanTreatAsString(v)
    if type(v) ~= "string" then return false end
    return _SafeCall(function(s) return #s end, v)
end

---------------------------------------------------------
-- URL formatting
---------------------------------------------------------
local function formatURL(url)
    url = tostring(url or "")
    url = url:gsub("%|", "||")
    return "|cff149bfd|Hurl:" .. url .. "|h[" .. url .. "]|h|r "
end

---------------------------------------------------------
-- Hook chat frames
---------------------------------------------------------
local function AddClickableURLs(frame)
    if frame == nil or frame.hasURLHook then return end
    frame.hasURLHook = true

    local originalAddMessage = frame.AddMessage
    frame.AddMessage = function(self, text, ...)
        if _CanTreatAsString(text) then
            text = text:gsub(URL_PATTERN, function(url)
                return formatURL(url)
            end)
        end
        return originalAddMessage(self, text, ...)
    end
end

---------------------------------------------------------
-- Popup dialog
---------------------------------------------------------
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
        local editBox = _G[self:GetName() .. "EditBox"]
        if editBox then
            editBox:SetText("")
            if self.data and self.data.url then
                editBox:SetText(self.data.url)
                editBox:HighlightText()
                editBox:SetFocus()
            end
        end
    end,
}

---------------------------------------------------------
-- Show popup and set URL
---------------------------------------------------------
local function ShowCopyBox(url)
    if not url or url == "" then return end

    local dialog = StaticPopup_Show("COPY_URL_POPUP", nil, nil, { url = url })

    if dialog then
        dialog.data = { url = url }
    end

    C_Timer.After(0, function()
        if dialog then
            local editBox = _G[dialog:GetName() .. "EditBox"]
            if editBox then
                editBox:SetText(url)
                editBox:HighlightText()
                editBox:SetFocus()
            end
        end
    end)
end

---------------------------------------------------------
-- Handle hyperlink clicks
---------------------------------------------------------
local orig_SetItemRef = SetItemRef
SetItemRef = function(link, text, button, chatFrame)
    local linkType, url = link:match("^([^:]+):(.*)$")

    if linkType and (linkType:lower() == "hurl" or linkType:lower() == "url") then
        ShowCopyBox(url)
        return
    end

    orig_SetItemRef(link, text, button, chatFrame)
end

---------------------------------------------------------
-- Hook all chat windows
---------------------------------------------------------
for i = 1, NUM_CHAT_WINDOWS do
    AddClickableURLs(_G["ChatFrame"..i])
end

---------------------------------------------------------
-- Handle new frames
---------------------------------------------------------
hooksecurefunc("FCF_OpenTemporaryWindow", function()
    for i = 1, NUM_CHAT_WINDOWS do
        AddClickableURLs(_G["ChatFrame"..i])
    end
end)
