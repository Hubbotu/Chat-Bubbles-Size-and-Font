local ADDON, ns = ...
local UI = ns.UI
local F = ns:NewModule("Features")
local issecret = ns.IsSecret

---------------------------------------------------------------------------
-- Font list (only fonts the client can actually load are offered)
---------------------------------------------------------------------------
function ns:GetFonts()
    if self.fontList then return self.fontList end
    local test = UIParent:CreateFontString(nil, "BACKGROUND")
    local list = { { text = "Default", value = "DEFAULT" } }
    local seen = {}
    local function add(name, path)
        if not path then return end
        local key = path:lower()
        if seen[key] then return end
        local ok, valid = pcall(test.SetFont, test, path, 12, "")
        if ok and valid then
            seen[key] = true
            list[#list + 1] = { text = name, value = path }
        end
    end
    local base = "Interface\\AddOns\\" .. ADDON .. "\\"
    add("Friz Quadrata", "Fonts\\FRIZQT__.TTF")
    add("Arial Narrow", "Fonts\\ARIALN.ttf")
    add("Morpheus", "Fonts\\MORPHEUS.ttf")
    add("Skurri", "Fonts\\SKURRI.ttf")
    add("Literata", base .. "Literata.ttf")
    add("Noto", base .. "front.ttf")
    add("Roboto", base .. "Roboto.ttf")
    add("Open Sans", base .. "OpenSans.ttf")
    add("Merriweather", base .. "Merriweather.ttf")
    add("Caveat", base .. "Caveat.ttf")

    local LSM = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local names = {}
        for name in pairs(LSM:HashTable("font")) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do add(name, LSM:Fetch("font", name)) end
    end
    test:Hide()
    self.fontList = list
    return list
end

---------------------------------------------------------------------------
-- Timestamps / class colours / misc Blizzard settings
---------------------------------------------------------------------------
local COLOR_TYPES = {
    "SAY", "EMOTE", "YELL", "GUILD", "OFFICER", "GUILD_ACHIEVEMENT", "ACHIEVEMENT",
    "WHISPER", "BN_WHISPER", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER",
    "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
}
for i = 1, 10 do COLOR_TYPES[#COLOR_TYPES + 1] = "CHANNEL" .. i end

local STICKY_TYPES = {
    "SAY", "YELL", "EMOTE", "PARTY", "RAID", "RAID_WARNING", "GUILD", "OFFICER",
    "INSTANCE_CHAT", "CHANNEL", "WHISPER", "BN_WHISPER",
}

local BLIZZ_BUTTONS = {
    "ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton", "QuickJoinToastButton",
}

function F:ApplyTimestamps()
    local v = ns.db.chat.timestamps
    if v == "DEFAULT" then return end
    pcall(SetCVar, "showTimestamps", v)
    _G.CHAT_TIMESTAMP_FORMAT = (v ~= "none") and v or nil
end

function F:ApplyClassColors()
    if not _G.SetChatColorNameByClass then return end
    local o = ns.db.chat
    if not o.classColors and not o._ccApplied then return end
    for _, t in ipairs(COLOR_TYPES) do pcall(SetChatColorNameByClass, t, o.classColors and true or false) end
    o._ccApplied = o.classColors and true or nil
end

function F:ApplyHideButtons()
    local hide = ns.db.chat.hideButtons
    for _, name in ipairs(BLIZZ_BUTTONS) do
        local b = _G[name]
        if b then
            if not b.ztvHooked then
                b.ztvHooked = true
                b:HookScript("OnShow", function(self)
                    if ns.db.chat.hideButtons then self:Hide() end
                end)
            end
            if hide then b:Hide() end
        end
    end
end

function F:ApplyArrows()
    local free = ns.db.chat.freeArrows
    for i = 1, NUM_CHAT_WINDOWS do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then eb:SetAltArrowKeyMode(not free) end
    end
end

function F:ApplySticky()
    if not ns.db.chat.sticky then return end
    for _, t in ipairs(STICKY_TYPES) do
        if ChatTypeInfo[t] then ChatTypeInfo[t].sticky = 1 end
    end
end

function F:ApplyHistory()
    local n = ns.db.chat.history
    if not n or n < 128 then return end
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf and cf.SetMaxLines then pcall(cf.SetMaxLines, cf, n) end
    end
end

-- Settings imported from the old addon point into its old folder. Redirect
-- those paths to this addon's folder.
local OLD_FOLDER = "interface\\addons\\zamestotv_bubble_scale\\"
local function NormalizeFontPath(path)
    if type(path) ~= "string" or path == "DEFAULT" then return path end
    if path:sub(1, #OLD_FOLDER):lower() == OLD_FOLDER then
        return "Interface\\AddOns\\" .. ADDON .. "\\" .. path:sub(#OLD_FOLDER + 1)
    end
    return path
end

-- On 12.0 SetFont raises an error for a missing file instead of returning
-- false, so every call that uses a saved path goes through pcall.
local function TrySetFont(obj, path, size, flags)
    local ok, res = pcall(obj.SetFont, obj, path, size, flags)
    return ok and res ~= false
end

function F:ApplyChatFont()
    local cf1 = _G.ChatFrame1
    if not cf1 then return end
    if not ns.defaultChatFont then ns.defaultChatFont = (cf1:GetFont()) end
    local o = ns.db.chat
    o.font = NormalizeFontPath(o.font)
    local path = o.font
    if not path or path == "DEFAULT" then path = ns.defaultChatFont end

    -- Make sure the saved font can load before touching any chat frame.
    local probe = self.fontProbe
    if not probe then
        probe = UIParent:CreateFontString(nil, "BACKGROUND")
        self.fontProbe = probe
    end
    if not TrySetFont(probe, path, 12, "") then
        o.font = "DEFAULT"
        path = ns.defaultChatFont
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf then
            local _, size, flags = cf:GetFont()
            if size then TrySetFont(cf, path, size, flags) end
        end
    end
end

function F:ApplyBubbleFont()
    if not _G.ChatBubbleFont then return end
    if not ns.defaultBubble then
        local p, s, f = ChatBubbleFont:GetFont()
        ns.defaultBubble = { p, s, f }
    end
    local d, o = ns.defaultBubble, ns.db.bubbles
    o.font = NormalizeFontPath(o.font)
    local path = (o.font and o.font ~= "DEFAULT") and o.font or d[1]
    local size = (o.size and o.size > 0) and math.max(8, o.size) or d[2]
    local flags = (path == d[1]) and d[3] or "OUTLINE"
    if not TrySetFont(ChatBubbleFont, path, size, flags) then
        -- the saved font no longer exists: forget it and use the default
        o.font = "DEFAULT"
        TrySetFont(ChatBubbleFont, d[1], size, d[3])
    end
end

---------------------------------------------------------------------------
-- AddMessage hook: short channel names + clickable URLs
---------------------------------------------------------------------------
local SHORT = {
    GUILD = "G", OFFICER = "O", PARTY = "P", PARTY_LEADER = "PL", RAID = "R",
    RAID_LEADER = "RL", RAID_WARNING = "RW", INSTANCE_CHAT = "I", INSTANCE_CHAT_LEADER = "IL",
}

local function Shorten(text)
    text = text:gsub("|Hchannel:channel:(%d+)|h%[.-%]|h", "|Hchannel:channel:%1|h[%1]|h")
    text = text:gsub("|Hchannel:([%u_]+)|h%[.-%]|h", function(kind)
        local s = SHORT[kind]
        if s then return "|Hchannel:" .. kind .. "|h[" .. s .. "]|h" end
    end)
    return text
end

local URL_CHARS = "[%w%-%._~:/%?#%[%]@!%$&'%(%)%*%+,;=%%]+"

local function WrapURL(pre, url, hex)
    local trail = url:match("[%.,;:!%?%)]+$") or ""
    if trail ~= "" then url = url:sub(1, #url - #trail) end
    return pre .. "|cff" .. hex .. "|Hztvurl:" .. url .. "|h[" .. url .. "]|h|r" .. trail
end

local function Linkify(text)
    if text:find("ztvurl:", 1, true) then return text end
    local hex = ns.Hex(ns:GetAccent())
    local s = " " .. text
    s = s:gsub("([%s%(<])(https?://" .. URL_CHARS .. ")", function(pre, url) return WrapURL(pre, url, hex) end)
    s = s:gsub("([%s%(<])(www%." .. URL_CHARS .. ")", function(pre, url) return WrapURL(pre, url, hex) end)
    return s:sub(2)
end

local function Process(text)
    local o = ns.db.chat
    if o.shortChannels then text = Shorten(text) end
    if o.urls then text = Linkify(text) end
    return text
end

local function HookFrame(cf)
    if not cf or cf.ztvHooked then return end
    cf.ztvHooked = true
    local orig = cf.AddMessage
    cf.AddMessage = function(self, text, ...)
        if type(text) == "string" and not issecret(text) then
            local ok, res = pcall(Process, text)
            if ok and type(res) == "string" then text = res end
        end
        return orig(self, text, ...)
    end
    cf:HookScript("OnHyperlinkClick", function(_, link)
        if type(link) == "string" and link:sub(1, 7) == "ztvurl:" then
            ns:ShowURL(link:sub(8))
        end
    end)
end

function F:HookFrames()
    for i = 1, NUM_CHAT_WINDOWS do HookFrame(_G["ChatFrame" .. i]) end
end

---------------------------------------------------------------------------
-- URL copy popup
---------------------------------------------------------------------------
function ns:ShowURL(url)
    if not url or url == "" then return end
    local f = self.urlFrame
    if not f then
        local C = UI.C
        f = CreateFrame("Frame", "ZamestoTVChatURL", UIParent, "BackdropTemplate")
        f:SetSize(480, 96)
        f:SetPoint("CENTER", 0, 140)
        f:SetFrameStrata("DIALOG")
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        UI.Flat(f, C.bg, C.border)
        tinsert(UISpecialFrames, "ZamestoTVChatURL")

        f.title = UI.Text(f, 12)
        f.title:SetPoint("TOPLEFT", 14, -12)
        f.title:SetText("Copy link")
        ns:OnTheme(function()
            f.title:SetTextColor(ns:GetAccent())
            f:SetBackdropBorderColor(ns:GetAccent())
        end)

        f.edit = UI.Edit(f, 450, 26)
        f.edit:SetPoint("TOPLEFT", 14, -34)
        f.edit:SetScript("OnTextChanged", function(self, user)
            if user and f.url then
                self:SetText(f.url)
                self:HighlightText()
            end
        end)
        f.edit:SetScript("OnKeyUp", function(_, key)
            if IsControlKeyDown() and (key == "C" or key == "X") then f:Hide() end
        end)

        f.hint = UI.Text(f, 11, C.muted)
        f.hint:SetPoint("BOTTOMLEFT", 14, 12)
        f.hint:SetText("Press Ctrl+C to copy, then Esc to close.")
        self.urlFrame = f
    end
    f.url = url
    f:Show()
    f.edit:SetText(url)
    f.edit:SetFocus()
    f.edit:HighlightText()
end

---------------------------------------------------------------------------
-- Keyword highlighting (event filter, so we know who sent the message)
---------------------------------------------------------------------------
local kwList, kwOpen = {}, "|cffffd100"
local lastAlert = 0

function F:RebuildKeywords()
    local k = ns.db.chat.keywords
    local list, seen = {}, {}
    local function add(w)
        w = w:lower()
        if #w >= 2 and not seen[w] then seen[w] = true; list[#list + 1] = w end
    end
    for w in (k.text or ""):gmatch("[^,\n]+") do add(w:match("^%s*(.-)%s*$")) end
    if k.name then
        local n = UnitName("player")
        if n and n ~= "" then add(n) end
    end
    kwList = list
    kwOpen = "|cff" .. ns.Hex(unpack(k.color))
end

local function HighlightPlain(seg, list)
    local lower = seg:lower()
    local marks = {}
    for _, kw in ipairs(list) do
        local init = 1
        while true do
            local s, e = lower:find(kw, init, true)
            if not s then break end
            marks[#marks + 1] = { s, e }
            init = e + 1
        end
    end
    if #marks == 0 then return seg, false end
    table.sort(marks, function(a, b) return a[1] < b[1] end)
    local out, pos = {}, 1
    local curS, curE = marks[1][1], marks[1][2]
    local function flush(s, e)
        out[#out + 1] = seg:sub(pos, s - 1)
        out[#out + 1] = kwOpen .. seg:sub(s, e) .. "|r"
        pos = e + 1
    end
    for i = 2, #marks do
        local m = marks[i]
        if m[1] <= curE then
            if m[2] > curE then curE = m[2] end
        else
            flush(curS, curE)
            curS, curE = m[1], m[2]
        end
    end
    flush(curS, curE)
    out[#out + 1] = seg:sub(pos)
    return table.concat(out), true
end

local function Highlight(msg, list)
    local out, pos, hit = {}, 1, false
    while pos <= #msg do
        local s, e = msg:find("|H.-|h.-|h", pos)
        local seg = s and msg:sub(pos, s - 1) or msg:sub(pos)
        local res, h = HighlightPlain(seg, list)
        out[#out + 1] = res
        hit = hit or h
        if not s then break end
        out[#out + 1] = msg:sub(s, e)
        pos = e + 1
    end
    return table.concat(out), hit
end

local function KeywordFilter(self, event, msg, author, ...)
    local k = ns.db.chat.keywords
    if not k.enabled or #kwList == 0 then return false end
    if issecret(msg) then return false end
    if author and not issecret(author) and Ambiguate(author, "none") == UnitName("player") then return false end
    local ok, new, hit = pcall(Highlight, msg, kwList)
    if not ok or not hit then return false end
    if k.sound then
        local now = GetTime()
        if now - lastAlert > 2 then
            lastAlert = now
            PlaySound(SOUNDKIT.TELL_MESSAGE)
        end
    end
    return false, new, author, ...
end

local KEYWORD_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_CHANNEL",
}

---------------------------------------------------------------------------
-- Module hooks
---------------------------------------------------------------------------
function F:Apply()
    self:RebuildKeywords()
    self:ApplyTimestamps()
    self:ApplyClassColors()
    self:ApplyHideButtons()
    self:ApplyArrows()
    self:ApplySticky()
    self:ApplyHistory()
    self:ApplyChatFont()
    self:ApplyBubbleFont()
    self:HookFrames()
end

function F:OnInit()
    for _, e in ipairs(KEYWORD_EVENTS) do ChatFrame_AddMessageEventFilter(e, KeywordFilter) end
    if _G.FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", function() F:HookFrames(); F:ApplyChatFont(); F:ApplyArrows() end)
    end
    if _G.FCF_SetChatWindowFontSize then
        hooksecurefunc("FCF_SetChatWindowFontSize", function() C_Timer.After(0, function() F:ApplyChatFont() end) end)
    end
    self:HookFrames()
end

function F:OnLogin()
    self:Apply()
    C_Timer.After(2, function() F:Apply() end)
end
