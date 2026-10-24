local ADDON, ns = ...
_G.ZamestoTVChat = ns

ns.name = ADDON
ns.modules = {}
ns.themeCallbacks = {}

-- Midnight (12.0) can hand addons "secret" strings in restricted situations.
-- Any string operation on them errors, so every filter checks this first.
ns.IsSecret = _G.issecretvalue or function() return false end

ns.presets = {
    { "Azure",   { 0.20, 0.60, 1.00 } },
    { "Emerald", { 0.20, 0.80, 0.45 } },
    { "Crimson", { 0.90, 0.25, 0.30 } },
    { "Amber",   { 1.00, 0.70, 0.15 } },
    { "Violet",  { 0.65, 0.40, 1.00 } },
    { "Rose",    { 1.00, 0.45, 0.70 } },
    { "Teal",    { 0.15, 0.80, 0.80 } },
    { "Slate",   { 0.65, 0.70, 0.78 } },
}

ns.defaults = {
    theme = {
        accent = { 0.20, 0.60, 1.00 },
        bgAlpha = 0.88,
        buttonStyle = "CIRCLE", -- see Bar.styles in ChatBar.lua
    },
    ui = { w = 720, h = 520 },
    bar = {
        visible = true, horizontal = false, showText = true,
        size = 22, spacing = 4, perLine = 8, scale = 1, fade = 1,
        pos = { point = "CENTER", rel = "CENTER", x = 10, y = 170 },
        hidden = {},
    },
    chat = {
        timestamps = "DEFAULT",
        classColors = true,
        urls = true,
        shortChannels = false,
        hideButtons = false,
        freeArrows = true,
        sticky = false,
        history = 0,
        font = "DEFAULT",
        keywords = { enabled = false, text = "", name = true, sound = true, color = { 1, 0.82, 0 } },
    },
    key = { enabled = true },
    spam = { enabled = true, text = "", words = {}, dedupe = false, dedupeSeconds = 15, whitelist = true },
    bubbles = {
        font = "DEFAULT", size = 0, disable = false,
        types = { party = true, raid = true, pvp = true, arena = true },
    },
    copy = { strip = true },
}

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = DeepCopy(v) end
    return r
end
ns.DeepCopy = DeepCopy

local function Merge(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = DeepCopy(v)
        elseif type(v) == "table" and type(dst[k]) == "table" then
            Merge(dst[k], v)
        end
    end
end

function ns.Hex(r, g, b)
    return string.format("%02x%02x%02x",
        math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5))
end

function ns.Debounce(fn, delay)
    local pending = false
    return function()
        if pending then return end
        pending = true
        C_Timer.After(delay, function() pending = false; fn() end)
    end
end

---------------------------------------------------------------------------
-- Theme
---------------------------------------------------------------------------
function ns:GetAccent()
    local a = (self.db and self.db.theme.accent) or self.defaults.theme.accent
    return a[1], a[2], a[3]
end

function ns:FireTheme()
    for _, fn in ipairs(self.themeCallbacks) do xpcall(fn, geterrorhandler()) end
end

function ns:SetAccent(r, g, b)
    local a = self.db.theme.accent
    a[1], a[2], a[3] = r, g, b
    self:FireTheme()
end

function ns:OnTheme(fn)
    self.themeCallbacks[#self.themeCallbacks + 1] = fn
    if self.db then xpcall(fn, geterrorhandler()) end
end

function ns:Print(msg)
    print("|cff" .. ns.Hex(self:GetAccent()) .. "Chat Helper|r: " .. tostring(msg))
end

function ns:NewModule(name)
    local m = { name = name }
    self.modules[#self.modules + 1] = m
    self[name] = m
    return m
end

---------------------------------------------------------------------------
-- Import settings from the old, separate addons (runs once)
---------------------------------------------------------------------------
local function Migrate(db)
    if db.migrated then return end
    db.migrated = true

    local old = _G.ZamestoTVBubbleScaleDB
    if type(old) == "table" then
        local b = db.bar
        if tonumber(old.size_btn) then b.size = math.max(14, math.min(40, old.size_btn)) end
        if tonumber(old.interval_btn) then b.spacing = math.max(0, math.min(12, old.interval_btn)) end
        if type(old.frame_pos) == "table" and old.frame_pos.x and old.frame_pos.y then
            b.pos = { point = "CENTER", rel = "CENTER", x = old.frame_pos.x, y = old.frame_pos.y }
        end
        if old.frame_visible ~= nil then b.visible = old.frame_visible end
        if old.is_horizontal ~= nil then b.horizontal = old.is_horizontal end
        if old.show_text ~= nil then b.showText = old.show_text end
    end

    local spam = _G.SpamFilterDB
    if type(spam) == "table" then
        if type(spam.inputText) == "string" then db.spam.text = spam.inputText end
        if type(spam.words) == "table" then db.spam.words = DeepCopy(spam.words) end
    end

    local free = _G.FreeChatDB
    if type(free) == "table" then
        if type(free.font) == "string" then db.bubbles.font = free.font end
        if tonumber(free.size) then db.bubbles.size = free.size end
    end

    local hide = _G.NoChatBubblesInInstancesDB
    if type(hide) == "table" and hide.enabled ~= nil then
        db.bubbles.disable = hide.enabled and true or false
    end
end

local function RunModules(method)
    for _, m in ipairs(ns.modules) do
        if m[method] then xpcall(m[method], geterrorhandler(), m) end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        ZamestoTVChatDB = ZamestoTVChatDB or {}
        ns.db = ZamestoTVChatDB
        -- v5.0 stored shape + style separately; fold them into one button style
        local th = ns.db.theme
        if th and th.buttonStyle == nil and (th.shape or th.style) then
            if th.style == "SUBTLE" then th.buttonStyle = "OUTLINE"
            elseif th.style == "ACCENT" then th.buttonStyle = "ACCENT"
            elseif th.shape == "SQUARE" then th.buttonStyle = "SQUARE"
            else th.buttonStyle = "CIRCLE" end
        end
        Merge(ns.db, ns.defaults)
        Migrate(ns.db)
        RunModules("OnInit")
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        RunModules("OnLogin")
    end
end)
