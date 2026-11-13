local ADDON, ns = ...
local UI = ns.UI
local F = ns:NewModule("Features")
local issecret = ns.IsSecret
local T = ns.T

---------------------------------------------------------------------------
-- Font list (only fonts the client can actually load are offered)
---------------------------------------------------------------------------
-- bundled fonts: display name + file names that are accepted
ns.BUNDLED_FONTS = {
    { "Literata", { "Literata.ttf", "Literata-Regular.ttf" } },
    { "Noto", { "front.ttf", "front1.ttf", "NotoSans-Regular.ttf", "Noto.ttf" } },
    { "Roboto", { "Roboto.ttf", "Roboto-Regular.ttf" } },
    { "Open Sans", { "OpenSans.ttf", "OpenSans-Regular.ttf" } },
    { "Merriweather", { "Merriweather.ttf", "Merriweather-Regular.ttf" } },
    { "Caveat", { "Caveat.ttf", "Caveat-Regular.ttf" } },
}

-- the same file in the spellings people tend to end up with (case matters on some systems)
function ns.FontFileVariants(files)
    local out, seen = {}, {}
    for _, f in ipairs(files) do
        local stem = f:gsub("%.[tT][tT][fF]$", "")
        for _, v in ipairs({ f, stem .. ".TTF", f:lower(), stem:lower() .. ".ttf" }) do
            if not seen[v] then seen[v] = true; out[#out + 1] = v end
        end
    end
    return out
end

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
            -- fonts that cannot draw Cyrillic are marked so they are not chosen by mistake
            local label = ns.SupportsCyrillic(path) and name or (name .. " " .. T("(Latin only)"))
            list[#list + 1] = { text = label, value = path }
        end
    end
    local base = "Interface\\AddOns\\" .. ADDON .. "\\"
    add("Friz Quadrata", "Fonts\\FRIZQT__.TTF")
    add("Arial Narrow", "Fonts\\ARIALN.ttf")
    add("Morpheus", "Fonts\\MORPHEUS.ttf")
    add("Skurri", "Fonts\\SKURRI.ttf")
    for _, entry in ipairs(ns.BUNDLED_FONTS) do
        local before = #list
        for _, file in ipairs(ns.FontFileVariants(entry[2])) do
            add(entry[1], ns.FONT_DIR .. file)          -- Interface\AddOns\<addon>\font\
            if #list > before then break end
        end
        if #list == before then                         -- not moved yet: the old location
            for _, file in ipairs(ns.FontFileVariants(entry[2])) do
                add(entry[1], base .. file)
                if #list > before then break end
            end
        end
    end

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
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
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
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf and cf.SetMaxLines then pcall(cf.SetMaxLines, cf, n) end
    end
end

-- Fonts bundled with the addon live in the "font" folder. Saved settings may
-- still point to the addon root (older versions) or to the old addon's folder:
-- move those paths to the new location, or keep the old one if the file has
-- not been moved yet.
local OLD_FOLDER = "interface\\addons\\zamestotv_bubble_scale\\"
local BUNDLED = {
    ["literata.ttf"] = true, ["front.ttf"] = true, ["front1.ttf"] = true, ["roboto.ttf"] = true,
    ["opensans.ttf"] = true, ["merriweather.ttf"] = true, ["caveat.ttf"] = true,
}

-- On 12.0 SetFont raises an error for a missing file instead of returning
-- false, so every call that uses a saved path goes through pcall.
local function TrySetFont(obj, path, size, flags)
    local ok, res = pcall(obj.SetFont, obj, path, size, flags)
    return ok and res ~= false
end

local function CanLoad(path)
    local probe = F.fontProbe
    if not probe then
        probe = UIParent:CreateFontString(nil, "BACKGROUND")
        F.fontProbe = probe
    end
    return TrySetFont(probe, path, 12, "")
end

local function NormalizeFontPath(path)
    if type(path) ~= "string" or path == "DEFAULT" then return path end
    local lower = path:lower()
    local root = "interface\\addons\\" .. ADDON:lower() .. "\\"
    local file = lower:sub(1, #OLD_FOLDER) == OLD_FOLDER and lower:sub(#OLD_FOLDER + 1)
        or (lower:sub(1, #root) == root and lower:sub(#root + 1))
    if file and BUNDLED[file] then
        local name = path:match("([^\\]+)$")
        local new = ns.FONT_DIR .. name
        if CanLoad(new) then return new end
        return "Interface\\AddOns\\" .. ADDON .. "\\" .. name
    end
    if lower:sub(1, #OLD_FOLDER) == OLD_FOLDER then
        return "Interface\\AddOns\\" .. ADDON .. "\\" .. path:sub(#OLD_FOLDER + 1)
    end
    return path
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

    for i = 1, (NUM_CHAT_WINDOWS or 10) do
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

local function Process(text, cf)
    local o = ns.db.chat
    if o.shortChannels then text = Shorten(text) end
    if o.urls then text = Linkify(text) end
    for _, fn in ipairs(ns.processors) do
        local ok, res = pcall(fn, text, cf)
        if ok and type(res) == "string" then text = res end
    end
    return text
end

local function HookFrame(cf)
    if not cf or cf.ztvHooked then return end
    cf.ztvHooked = true
    local orig = cf.AddMessage
    cf.AddMessage = function(self, text, ...)
        if type(text) == "string" and not issecret(text) then
            local ok, res = pcall(Process, text, self)
            if ok and type(res) == "string" then text = res end
        end
        return orig(self, text, ...)
    end
    cf:HookScript("OnHyperlinkClick", function(_, link)
        if type(link) == "string" then
            if link:sub(1, 7) == "ztvurl:" then
                ns:ShowURL(link:sub(8))
            elseif link:sub(1, 7) == "ztvmsg:" and ns.Messenger then
                ns.Messenger:Open(link:sub(8))
            end
        end
    end)
end

function F:HookFrames()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do HookFrame(_G["ChatFrame" .. i]) end
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
        f.title:SetText(T("Copy link"))
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
        f.hint:SetText(T("Press Ctrl+C to copy, then Esc to close."))
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

-- /ztvfonts : shows which bundled font files the game can load
function F:DiagnoseFonts()
    local probe = UIParent:CreateFontString(nil, "BACKGROUND")
    ns:Print("Fonts folder: " .. ns.FONT_DIR)
    local found = 0
    for _, entry in ipairs(ns.BUNDLED_FONTS) do
        local where
        for _, dir in ipairs({ ns.FONT_DIR, "Interface\\AddOns\\" .. ADDON .. "\\" }) do
            for _, file in ipairs(ns.FontFileVariants(entry[2])) do
                local ok, valid = pcall(probe.SetFont, probe, dir .. file, 12, "")
                if ok and valid then where = dir .. file break end
            end
            if where then break end
        end
        if where then found = found + 1 end
        print(string.format("  %s: %s", entry[1], where and ("|cff40ff40OK|r  " .. where) or "|cffff5050not found|r"))
    end
    if found < #ns.BUNDLED_FONTS then
        print("  The game only detects NEW files when it starts: close World of Warcraft completely and start it again (a /reload is not enough).")
        print("  Accepted names: " .. table.concat((function() local t = {} for _, e in ipairs(ns.BUNDLED_FONTS) do t[#t + 1] = e[2][1] end return t end)(), ", "))
    end
end

function F:OnInit()
    -- /ztvcyr : which font the addon uses and whether it can draw Cyrillic
    SLASH_ZTVCYR1 = "/ztvcyr"
    SlashCmdList["ZTVCYR"] = function()
        local chat = _G.ChatFrame1 and select(1, ChatFrame1:GetFont())
        local function yes(p) return ns.SupportsCyrillic(p) and "|cff40ff40Cyrillic OK|r" or "|cffff5050no Cyrillic|r" end
        print("Chat Helper font: " .. tostring(UI.Font()) .. " - " .. yes(UI.Font()))
        print("Game default font: " .. tostring(STANDARD_TEXT_FONT) .. " - " .. yes(STANDARD_TEXT_FONT))
        print("Chat window font: " .. tostring(chat) .. " - " .. yes(chat))
        if chat and not ns.SupportsCyrillic(chat) then
            print("Russian text in the chat window needs another font: Settings > Fonts > Chat window font.")
        end
    end

    SLASH_ZTVFONTS1 = "/ztvfonts"
    SlashCmdList["ZTVFONTS"] = function() F:DiagnoseFonts() end
    for _, e in ipairs(KEYWORD_EVENTS) do ns.AddChatFilter(e, KeywordFilter) end
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
