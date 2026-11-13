local ADDON, ns = ...
local UI = ns.UI
local Bar = ns:NewModule("Bar")

local WHITE = "Interface\\Buttons\\WHITE8X8"
local MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall"
local SETTINGS_ICON = "Interface\\AddOns\\" .. ADDON .. "\\sett.tga"
local PAD = 6
local ART = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
local T = ns.T

---------------------------------------------------------------------------
-- Button styles
--   fill:      color = chat-type color, dark = dark panel, accent = accent
--              color, none = transparent (tinted on hover)
--   text:      short = single letter, long = full name (Raid, Guild, ...)
--   textColor: nil = auto contrast, color = chat-type color, white
---------------------------------------------------------------------------
Bar.styles = {
    { id = "CIRCLE",  name = "Circle",              round = true,  fill = "color",  text = "short" },
    { id = "SQUARE",  name = "Square",              round = false, fill = "color",  text = "short" },
    { id = "OUTLINE", name = "Outline",             round = false, fill = "dark",   text = "short", outline = true, textColor = "color" },
    { id = "ACCENT",  name = "Accent dot",          round = true,  fill = "accent", text = "short" },
    { id = "LABEL",   name = "Label (text)",        round = false, fill = "color",  text = "long" },
    { id = "TAG",     name = "Tag (text + stripe)", round = false, fill = "dark",   text = "long", stripe = true, textColor = "white" },
    { id = "TEXT",    name = "Text only",           round = false, fill = "none",   text = "long", textColor = "color" },
    -- drawn buttons (textures in the media folder): bezel + tinted body
    { id = "ORB",     name = "Orb (glossy)",        art = "orb",   fill = "color", text = "short", gloss = true },
    { id = "GEM",     name = "Gem (faceted)",       art = "gem",   fill = "color", text = "short", gloss = true },
    { id = "NEON",    name = "Neon ring",           art = "neon",  fill = "color", text = "short", textColor = "white", rim = "color" },
    { id = "BADGE",   name = "Badge (gold frame)",  art = "badge", fill = "color", text = "short", gloss = true },
    { id = "PIXEL",   name = "Pixel key (8-bit)",   art = "pixel", fill = "color", text = "short", rim = "dark" },
    -- rectangular drawn buttons: they stretch to the width of the label
    { id = "PLATE",    name = "Plate (metal)",        slice = "plate",    fill = "color", text = "long", corner = 8 },
    { id = "PILL",     name = "Pill (capsule)",       slice = "pill",     fill = "color", text = "long", corner = "half" },
    { id = "SLAB",     name = "Slab (neon, angular)", slice = "slab",     fill = "color", text = "long", textColor = "white", rim = "color", corner = 8 },
    { id = "BLOCK",    name = "Block (blocky)",       slice = "block",    fill = "color", text = "long", corner = 6 },
    { id = "GLASSBAR", name = "Glass bar",            slice = "glassbar", fill = "color", text = "long", textColor = "white", corner = 8 },
}
local styleByID = {}
for _, s in ipairs(Bar.styles) do styleByID[s.id] = s end

local function CurrentStyle()
    return styleByID[ns.db.theme.buttonStyle] or styleByID.CIRCLE
end

---------------------------------------------------------------------------
-- Channel tracking (custom channels only; built-in ones are filtered out)
---------------------------------------------------------------------------
local BOGUS = { "General", "Trade", "LocalDefense", "WorldDefense", "GuildRecruitment", "LookingForGroup" }
for _, g in ipairs({ "GENERAL", "TRADE", "LOCAL_DEFENSE", "WORLD_DEFENSE", "GUILD_RECRUITMENT_CHANNEL", "LOOK_FOR_GROUP" }) do
    local v = _G[g]
    if type(v) == "string" and v ~= "" then BOGUS[#BOGUS + 1] = v end
end
local channels = {}

local function UpdateChannelStates()
    for i = 1, 10 do
        local num, name = GetChannelName(i)
        if num and num ~= 0 then
            local special = false
            -- built-in channels (1 General, 2 Trade, 3 Defense ...) get buttons too, unless switched off
            if name and ns.db.bar.builtinChannels == false then
                for _, b in ipairs(BOGUS) do
                    if name:find(b, 1, true) then special = true break end
                end
            end
            channels[i] = not special
        else
            channels[i] = false
        end
    end
end
Bar.UpdateChannelStates = UpdateChannelStates

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
-- Fallback only: ChatEdit_SendText is a deprecated alias in 12.0.
local function GetActiveEdit()
    local get = ns.ChatFn("ChatEdit_GetActiveWindow")
    return get and get()
end

local function RunSlash(text)
    local eb = ChatFrame1EditBox
    local send = ns.ChatFn("ChatEdit_SendText")
    if not eb or not send then
        ns:Print("This action is not available on this client version.")
        return
    end
    eb:SetText(text)
    send(eb, 0)
    eb:SetText("")
end

local function Countdown(seconds)
    if C_PartyInfo and C_PartyInfo.DoCountdown then
        C_PartyInfo.DoCountdown(seconds)
    else
        RunSlash("/countdown " .. seconds)
    end
end

local function ReadyCheck()
    if _G.DoReadyCheck then
        DoReadyCheck()
    else
        RunSlash("/readycheck")
    end
end

local function CanOfficer()
    if C_GuildInfo and C_GuildInfo.IsGuildOfficer then return C_GuildInfo.IsGuildOfficer() end
    return C_GuildInfo and C_GuildInfo.CanEditOfficerNote and C_GuildInfo.CanEditOfficerNote()
end

local function ActiveKey()
    local eb = GetActiveEdit()
    if eb and eb:IsShown() then
        local t = eb:GetAttribute("chatType")
        if t == "CHANNEL" then return "CHANNEL" .. tostring(eb:GetAttribute("channelTarget")) end
        return t
    end
end

---------------------------------------------------------------------------
-- Button definitions (label = short form, long = full name for text styles)
---------------------------------------------------------------------------
local defs = {
    { id = "raid",     cmd = "/raid", label = "R", long = "Raid",    color = { 1, 0.50, 0 },       desc = "Raid chat",     group = "chat", key = "RAID",          avail = function() return IsInRaid() end },
    { id = "guild",    cmd = "/g",    label = "G", long = "Guild",   color = { 0.25, 1, 0.25 },    desc = "Guild chat",    group = "chat", key = "GUILD",         avail = function() return IsInGuild() end },
    { id = "officer",  cmd = "/o",    label = "O", long = "Officer", color = { 0.25, 0.75, 0.45 }, desc = "Officer chat",  group = "chat", key = "OFFICER",       avail = function() return IsInGuild() and CanOfficer() end },
    { id = "party",    cmd = "/p",    label = "P", long = "Party",   color = { 0.67, 0.67, 1 },    desc = "Party chat",    group = "chat", key = "PARTY",         avail = function() return UnitExists("party1") end },
    { id = "say",      cmd = "/s",    label = "S", long = "Say",     color = { 1, 1, 1 },          desc = "Say",           group = "chat", key = "SAY" },
    { id = "yell",     cmd = "/y",    label = "Y", long = "Yell",    color = { 1, 0.25, 0.25 },    desc = "Yell",          group = "chat", key = "YELL" },
    { id = "rw",       cmd = "/rw",   label = "W", long = "Warn",    color = { 1, 0.62, 0.15 },    desc = "Raid warning",  group = "chat", key = "RAID_WARNING",  avail = function() return IsInRaid() and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) end },
    { id = "instance", cmd = "/i",    label = "I", long = "Inst",    color = { 1, 0.50, 0 },       desc = "Instance chat", group = "chat", key = "INSTANCE_CHAT", avail = function() return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) end },
}

for n = 1, 10 do
    defs[#defs + 1] = {
        id = "chan" .. n, toggle = "channels", cmd = "/" .. n, label = tostring(n), long = tostring(n),
        color = { 1, 1, 0.75 }, group = "chat", key = "CHANNEL" .. n, channel = n,
        desc = "Channel " .. n,
        avail = function() return channels[n] and ns.db.bar.channelMode == "BUTTONS" end,
    }
end

-- one button for all channels: shows the current channel, opens a menu (see ChannelMenu.lua)
defs[#defs + 1] = {
    id = "chanmenu", toggle = "channels", cmd = "/1", label = "#", long = "Channels",
    color = { 1, 1, 0.75 }, group = "chat", desc = "Channels",
    hint = "Click: choose a channel.  Mouse wheel: switch channel.  Right-click: write in the last channel.",
    dynLabel = function(long) return Bar:ChannelLabel(long) end,
    isActive = function() local k = ActiveKey() return k ~= nil and k:find("^CHANNEL") ~= nil end,
    avail = function() return ns.db.bar.channelMode ~= "BUTTONS" and Bar:HasChannels() end,
    action = function(b) Bar:ToggleChannelMenu(b) end,
    rightAction = function() Bar:WriteInLastChannel() end,
    wheel = function(dir) Bar:CycleChannel(dir) end,
}

local tools = {
    { id = "msg",  label = "DM", long = "Chats", color = { 0.35, 0.8, 1 }, desc = "Messenger", hint = "Private and Battle.net conversations",
      badge = function() return ns.Messenger and ns.Messenger:GetUnread() or 0 end,
      avail = function() return ns.db.messenger.enabled end,
      action = function() ns.Messenger:Toggle() end },
    { id = "kd5",  label = "5",  long = "Pull 5",  color = { 1, 0, 1 },         desc = "Countdown 5",  hint = "Starts a 5 second pull timer",  action = function() Countdown(5) end },
    { id = "kd10", label = "10", long = "Pull 10", color = { 0.75, 0, 1 },      desc = "Countdown 10", hint = "Starts a 10 second pull timer", action = function() Countdown(10) end },
    { id = "rc",   label = "RC", long = "Ready",   color = { 1, 0.25, 0.25 },   desc = "Ready check",  hint = "Starts a ready check",          action = function() ReadyCheck() end },
    { id = "key",  label = "K",  long = "Key",     color = { 0, 1, 1 },         desc = "Keystone information", hint = "Posts your keystone in group chat", avail = function() return ns.Key:IsAvailable() end, action = function() ns.Key:Ask() end },
    { id = "copy", label = "CP", long = "Copy",    color = { 1, 1, 0 },         desc = "Copy chat",    hint = "Right-click: open settings",    action = function() ns.Copy:Open() end },
    { id = "roll", label = "RL", long = "Roll",    color = { 0.9, 0.8, 0.5 },   desc = "Roll 1-100",   hint = "Rolls a random number",         action = function() RandomRoll(1, 100) end },
    { id = "cfg",  label = "",   long = "",        color = { 0.7, 0.75, 0.85 }, desc = "Chat Helper settings", icon = SETTINGS_ICON,           action = function() ns.Config:Toggle() end },
}
for _, t in ipairs(tools) do
    t.group = "tools"
    defs[#defs + 1] = t
end
Bar.defs = defs
Bar.BOGUS = BOGUS
Bar.ActiveKey = ActiveKey

-- Entries shown as checkboxes in the settings window.
Bar.toggles = {}
do
    local seen = {}
    for _, d in ipairs(defs) do
        local id = d.toggle or d.id
        if not seen[id] then
            seen[id] = true
            Bar.toggles[#Bar.toggles + 1] = { id = id, name = d.toggle == "channels" and "Channels 1-10" or d.desc }
        end
    end
end

---------------------------------------------------------------------------
-- Button visuals
---------------------------------------------------------------------------
local function Contrast(r, g, b)
    if (0.299 * r + 0.587 * g + 0.114 * b) > 0.62 then return 0.08, 0.08, 0.10 end
    return 1, 1, 1
end

-- Ring (outline) + fill tint for the current hover / active state.
local function UpdateVisual(b)
    local ar, ag, ab = ns:GetAccent()
    local fc = b.fillColor
    local st = b.style

    -- rectangular drawn styles (nine-slice)
    if st and st.slice and not b.noFill then
        local mul = (b.hover or b.active) and 1.15 or 1
        b.ring:Hide(); b.fill:Hide()
        b.fillS:SetColor(math.min(1, fc[1] * mul), math.min(1, fc[2] * mul), math.min(1, fc[3] * mul), 1)
        local c = b.def.color
        local rr, rg, rb = 1, 1, 1
        if st.rim == "color" then rr, rg, rb = c[1], c[2], c[3] end
        if b.active then rr, rg, rb = ar, ag, ab end
        b.ringS:SetColor(rr, rg, rb, 1)
        b.fillS:SetShown(true); b.ringS:SetShown(true)
        b.shine:SetShown(b.hover and true or false)
        b.shine:SetAlpha(0.5)
        return
    end
    if b.fillS then b.fillS:SetShown(false); b.ringS:SetShown(false) end

    -- drawn (textured) styles
    if st and st.art and not b.noFill then
        local mul = (b.hover or b.active) and 1.15 or 1
        b.fill:SetVertexColor(math.min(1, fc[1] * mul), math.min(1, fc[2] * mul), math.min(1, fc[3] * mul), 1)
        local c = b.def.color
        local rr, rg, rb = 1, 1, 1
        if st.rim == "color" then rr, rg, rb = c[1], c[2], c[3]
        elseif st.rim == "dark" then rr, rg, rb = 0.10, 0.11, 0.14 end
        if b.active then rr, rg, rb = ar, ag, ab end
        b.ring:SetVertexColor(rr, rg, rb, 1)
        b.ring:Show()
        b.shine:SetShown(st.gloss or b.hover)
        b.shine:SetAlpha(b.hover and 0.75 or 0.35)
        return
    end
    if b.shine then b.shine:Hide() end

    if b.noFill then
        if b.active then b.fill:SetVertexColor(ar, ag, ab, 0.35)
        elseif b.hover then b.fill:SetVertexColor(ar, ag, ab, 0.18)
        else b.fill:SetVertexColor(ar, ag, ab, 0) end
        b.ring:Hide()
        return
    end

    b.fill:SetVertexColor(fc[1], fc[2], fc[3], 1)
    if b.active then
        b.ring:SetVertexColor(1, 1, 1, 1)
        b.ring:Show()
    elseif b.hover then
        if b.style.fill == "accent" then b.ring:SetVertexColor(1, 1, 1, 0.7)
        else b.ring:SetVertexColor(ar, ag, ab, 1) end
        b.ring:Show()
    elseif b.baseRing then
        b.ring:SetVertexColor(b.baseRing[1], b.baseRing[2], b.baseRing[3], b.baseRing[4])
        b.ring:Show()
    else
        b.ring:Hide()
    end
end

-- Colors, text and natural size. Positioning happens in Layout.
local function StyleButton(b)
    local st, o = CurrentStyle(), ns.db.bar
    local def = b.def
    local size = o.size
    local c = def.color
    local ar, ag, ab = ns:GetAccent()
    local isIcon = def.icon ~= nil
    b.style = st
    b.natH = size

    -- shape
    local round = st.round and not st.art
    if st.art then
        if b.artName ~= st.art then
            b.ring:SetTexture(ART .. st.art .. "_rim")
            b.fill:SetTexture(ART .. st.art .. "_fill")
            b.artName = st.art
        end
    elseif b.artName then
        b.ring:SetTexture(WHITE)
        b.fill:SetTexture(WHITE)
        b.artName = nil
    end
    if st.slice and not b.ringS then
        b.fillS = ns.Chatbox.NewSlice(b, ART .. st.slice .. "_fill", "ARTWORK", 0, 0.25)
        b.ringS = ns.Chatbox.NewSlice(b, ART .. st.slice .. "_rim", "ARTWORK", 1, 0.25)
    end
    if not st.slice then
        b.ring:Show(); b.fill:Show()
    end
    if round and not b.masked then
        b.ring:AddMaskTexture(b.ringMask)
        b.fill:AddMaskTexture(b.fillMask)
        b.masked = true
    elseif not round and b.masked then
        b.ring:RemoveMaskTexture(b.ringMask)
        b.fill:RemoveMaskTexture(b.fillMask)
        b.masked = false
    end

    -- fill
    local fr, fg, fb
    if st.fill == "color" then fr, fg, fb = c[1], c[2], c[3]
    elseif st.fill == "dark" then fr, fg, fb = 0.13, 0.14, 0.17
    else fr, fg, fb = ar, ag, ab end
    b.fillColor = { fr, fg, fb }
    b.noFill = isIcon or st.fill == "none"
    b.baseRing = st.outline and { c[1], c[2], c[3], 0.6 } or nil

    -- text
    local long = st.text == "long"
    local label = long and T(def.long or def.label) or def.label
    if def.dynLabel then
        label = def.dynLabel(long) or label
        b.dynShown = label
    end
    if def.badge then
        local n = def.badge()
        if n and n > 0 then
            if long then label = label .. " " .. n else label = (n > 9) and "9+" or tostring(n) end
        end
    end
    b.text:SetFont(UI.Font(), long and math.max(9, math.floor(size * 0.5)) or math.max(8, math.floor(size * 0.46)), "")
    b.text:SetText(isIcon and "" or label)
    b.text:SetShown((long or o.showText) and not isIcon)
    local tr, tg, tb
    if st.textColor == "color" then tr, tg, tb = c[1], c[2], c[3]
    elseif st.textColor == "white" then tr, tg, tb = 0.95, 0.95, 0.97
    else tr, tg, tb = Contrast(fr, fg, fb) end
    b.text:SetTextColor(tr, tg, tb)

    -- stripe (tag style)
    b.stripe:SetColorTexture(c[1], c[2], c[3], 1)
    b.stripe:SetShown(st.stripe and not isIcon and true or false)

    -- natural width
    local w = size
    if long and not isIcon then
        local padX = math.max(6, math.floor(size * 0.4))
        w = math.max(size, math.ceil(b.text:GetStringWidth()) + padX * 2 + (st.stripe and 4 or 0))
    end
    b.natW = w
    UpdateVisual(b)
end

local function SizeButton(b, w)
    local h = b.natH
    b:SetSize(w, h)
    local grow = b.style.art and 0 or 4
    b.ring:SetSize(w + grow, h + grow)
    b.fill:SetSize(w, h)
    b.shine:SetSize(w, h)
    local sl = b.style.slice
    if sl and b.ringS then
        local corner = b.style.corner == "half" and math.floor(h / 2) or math.min(b.style.corner or 8, math.floor(h / 2))
        corner = math.max(3, corner)
        b.fillS:SetFile(ART .. sl .. "_fill", 0.25)
        b.ringS:SetFile(ART .. sl .. "_rim", 0.25)
        b.fillS:Layout(corner, 0)
        b.ringS:Layout(corner, 0)
    end
    b.stripe:SetSize(3, h)
    if b.icon then b.icon:SetSize(h, h) end
    b.text:ClearAllPoints()
    b.text:SetPoint("CENTER", b.style.stripe and 1.5 or 0, 0)
end

local function CreateButton(def)
    local b = CreateFrame("Button", nil, Bar.frame)
    b.def = def
    def.button = b

    b.ring = b:CreateTexture(nil, "BACKGROUND", nil, 0)
    b.ring:SetTexture(WHITE)
    b.ring:SetPoint("CENTER")
    b.fill = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.fill:SetTexture(WHITE)
    b.fill:SetPoint("CENTER")
    b.ringMask = b:CreateMaskTexture()
    b.ringMask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    b.ringMask:SetAllPoints(b.ring)
    b.fillMask = b:CreateMaskTexture()
    b.fillMask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    b.fillMask:SetAllPoints(b.fill)

    b.shine = b:CreateTexture(nil, "ARTWORK", nil, 2)
    b.shine:SetTexture(ART .. "shine")
    b.shine:SetBlendMode("ADD")
    b.shine:SetPoint("CENTER")
    b.shine:Hide()

    b.stripe = b:CreateTexture(nil, "ARTWORK")
    b.stripe:SetTexture(WHITE)
    b.stripe:SetPoint("LEFT", b, "LEFT", 0, 0)
    b.stripe:Hide()

    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(UI.Font(), 10, "")
    b.text:SetPoint("CENTER")
    b.text:SetShadowColor(0, 0, 0, 0.35)
    b.text:SetShadowOffset(1, -1)

    if def.icon then
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetTexture(def.icon)
        b.icon:SetPoint("CENTER")
    end

    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnEnter", function(self)
        self.hover = true
        UpdateVisual(self)
        GameTooltip:SetOwner(self, ns.db.bar.horizontal and "ANCHOR_TOP" or "ANCHOR_RIGHT")
        local desc = def.desc
        if def.channel then
            local _, name = GetChannelName(def.channel)
            if name then desc = def.channel .. ". " .. name end
        end
        GameTooltip:SetText(T(desc), 1, 1, 1)
        if def.hint then GameTooltip:AddLine(T(def.hint), 0.6, 0.6, 0.65, true) end
        if def.badge then
            local n = def.badge()
            if n and n > 0 then GameTooltip:AddLine(string.format(T("%d unread"), n), 1, 0.82, 0) end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self.hover = false
        UpdateVisual(self)
        GameTooltip:Hide()
    end)
    b:SetScript("OnMouseDown", function(self) self.fill:SetAlpha(0.7) end)
    b:SetScript("OnMouseUp", function(self) self.fill:SetAlpha(1) end)
    if def.wheel then
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", function(_, d) def.wheel(d) end)
    end
    b:SetScript("OnClick", function(self, button)
        if def.rightAction and button == "RightButton" then
            def.rightAction(self)
            return
        end
        if def.id == "copy" and button == "RightButton" then
            ns.Config:Open()
            return
        end
        if def.action then def.action(self) return end
        local eb = GetActiveEdit()
        if eb and eb:IsShown() and ActiveKey() == def.key then
            local off = ns.ChatFn("ChatEdit_DeactivateChat")
            if off then off(eb) end
            return
        end
        local open = ns.ChatFn("ChatFrame_OpenChat")
        if open then open(def.cmd .. " ", SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME) end
    end)

    StyleButton(b)
    SizeButton(b, b.natW)
    return b
end

---------------------------------------------------------------------------
-- Layout (buttons can have different widths for the text styles)
---------------------------------------------------------------------------
local function IsEnabled(def)
    if ns.db.bar.hidden[def.toggle or def.id] then return false end
    if def.avail and not def.avail() then return false end
    return true
end

function Bar:RefreshActive()
    local key = ActiveKey()
    for _, def in ipairs(defs) do
        local b = def.button
        if b then
            local active
            if def.isActive then active = def.isActive() else active = (def.key ~= nil and def.key == key) end
            if b.active ~= active then
                b.active = active
                UpdateVisual(b)
            end
            -- a channel that is hidden in the chat window is shown dimmed
            if def.channel then
                local dim = Bar.ChannelHidden and Bar:ChannelHidden(def.channel)
                b:SetAlpha(dim and 0.45 or 1)
            end
            -- the channel button shows the current channel number
            if def.dynLabel and b.dynShown ~= def.dynLabel(b.style.text == "long") then
                C_Timer.After(0, function() Bar:Refresh() end)
            end
        end
    end
end

function Bar:Layout()
    local o = ns.db.bar
    local size, gap = o.size, o.spacing
    local perLine = math.max(1, o.perLine)
    local f = self.frame

    -- Docked inside the chatbox: the side decides the direction and the
    -- chat window's size decides where the lines wrap.
    local side = ns.Chatbox and ns.Chatbox:DockSide()
    local horizontal = o.horizontal
    local availW, availH
    if side then
        horizontal = (side == "TOP" or side == "BOTTOM")
        local cw, ch = ns.Chatbox:DockSpace()
        availW, availH = (cw or 400) - PAD * 2, (ch or 200) - PAD * 2
    end

    for _, def in ipairs(defs) do
        if def.button then def.button:Hide() end
    end

    -- Split the visible buttons into lines (rows if horizontal, columns if vertical).
    local lines, cur, lastGroup, curLen = {}, nil, nil, 0
    for _, def in ipairs(defs) do
        if IsEnabled(def) then
            local b = def.button or CreateButton(def)
            StyleButton(b)
            local len = horizontal and b.natW or size
            local newLine
            if side then
                newLine = not cur or (#cur > 0 and curLen + gap + len > (horizontal and availW or availH))
            else
                newLine = not cur or def.group ~= lastGroup or #cur >= perLine
            end
            if newLine then
                cur = {}
                lines[#lines + 1] = cur
                curLen = 0
            end
            curLen = curLen + (#cur > 0 and gap or 0) + len
            lastGroup = def.group
            cur[#cur + 1] = b
        end
    end

    local totalW, totalH = 0, 0
    if horizontal then
        local y = 0
        for _, line in ipairs(lines) do
            local x = 0
            for _, b in ipairs(line) do
                SizeButton(b, b.natW)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + x, -(PAD + y))
                b:Show()
                x = x + b.natW + gap
            end
            totalW = math.max(totalW, x - gap)
            y = y + size + gap
        end
        totalH = y - gap
    else
        local x = 0
        for _, line in ipairs(lines) do
            local colW = 0
            for _, b in ipairs(line) do colW = math.max(colW, b.natW) end
            local y = 0
            for _, b in ipairs(line) do
                SizeButton(b, colW)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + x, -(PAD + y))
                b:Show()
                y = y + size + gap
            end
            totalH = math.max(totalH, y - gap)
            x = x + colW + gap
        end
        totalW = x - gap
    end

    if #lines == 0 then totalW, totalH = 40, 10 end
    f:SetSize(totalW + PAD * 2, totalH + PAD * 2)
    self:RefreshActive()
    if ns.Chatbox then ns.Chatbox:UpdateDock() end
end

---------------------------------------------------------------------------
-- Frame styling, reposition mode
---------------------------------------------------------------------------
function Bar:StyleFrame()
    local f, o, t = self.frame, ns.db.bar, ns.db.theme
    local ar, ag, ab = ns:GetAccent()
    local docked = ns.Chatbox and ns.Chatbox:DockSide()
    f:SetBackdropColor(0.055, 0.058, 0.075, docked and 0 or t.bgAlpha)
    -- the border only exists while the bar is being repositioned
    f:SetBackdropBorderColor(ar, ag, ab, self.moveMode and 1 or 0)
    f.mover.tex:SetColorTexture(ar, ag, ab, 0.18)
    f:SetScale(o.scale)
end

function Bar:Refresh()
    if not self.frame then return end
    self:Layout()
    self:StyleFrame()
    self.frame:SetShown(ns.db.bar.visible)
end

function Bar:SetMoveMode(on)
    self.moveMode = on and true or false
    if self.moveMode and not ns.db.bar.visible then
        ns.db.bar.visible = true
        self:Refresh()
    end
    self.frame.mover:SetShown(self.moveMode)
    self:StyleFrame()
    if self.onMoveMode then self.onMoveMode(self.moveMode) end
    if self.moveMode then
        ns:Print("Reposition mode: drag the bar, right-click it to finish.")
    end
end

function Bar:SavePosition()
    local point, _, rel, x, y = self.frame:GetPoint()
    ns.db.bar.pos = { point = point, rel = rel, x = x, y = y }
end

function Bar:ApplyPosition()
    if ns.Chatbox and ns.Chatbox:DockSide() and ns.Chatbox:AnchorBar(self.frame) then return end
    local p = ns.db.bar.pos
    self.frame:ClearAllPoints()
    self.frame:SetPoint(p.point or "CENTER", UIParent, p.rel or "CENTER", p.x or 0, p.y or 0)
end

function Bar:ResetPosition()
    ns.db.bar.pos = ns.DeepCopy(ns.defaults.bar.pos)
    self:ApplyPosition()
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
function Bar:OnInit()
    local f = CreateFrame("Frame", "ZamestoTVChatBar", UIParent, "BackdropTemplate")
    self.frame = f
    f:SetSize(60, 60)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })

    -- Covers the whole bar while repositioning (buttons are inactive then)
    local m = CreateFrame("Frame", nil, f)
    m:SetAllPoints(f)
    m:SetFrameLevel(f:GetFrameLevel() + 50)
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")
    m.tex = m:CreateTexture(nil, "OVERLAY")
    m.tex:SetAllPoints()
    m:SetScript("OnDragStart", function(self)
        if ns.Chatbox and ns.Chatbox:DockSide() then
            -- docked: dragging changes the offset inside the chatbox
            local o = ns.db.chatbox
            local sx, sy = GetCursorPosition()
            local x0, y0 = o.dockX or 0, o.dockY or 0
            self:SetScript("OnUpdate", function()
                local k = ns.Chatbox.frame:GetEffectiveScale()
                local nx, ny = GetCursorPosition()
                o.dockX = math.max(-800, math.min(800, math.floor(x0 + (nx - sx) / k + 0.5)))
                o.dockY = math.max(-800, math.min(800, math.floor(y0 + (ny - sy) / k + 0.5)))
                ns.Chatbox:AnchorBar(f)
            end)
            return
        end
        f:StartMoving()
    end)
    m:SetScript("OnDragStop", function(self)
        if self:GetScript("OnUpdate") then
            self:SetScript("OnUpdate", nil)
            return
        end
        f:StopMovingOrSizing()
        Bar:SavePosition()
    end)
    m:SetScript("OnMouseUp", function(_, btn)
        if btn == "RightButton" then Bar:SetMoveMode(false) end
    end)
    m:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Reposition mode", 1, 1, 1)
        GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.75)
        GameTooltip:AddLine("Right-click to finish", 0.7, 0.7, 0.75)
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m:Hide()
    f.mover = m

    -- Optional fade when idle
    local elapsed = 0
    f:SetScript("OnUpdate", function(self, dt)
        local fade = ns.db.bar.fade
        if fade >= 1 then
            if self:GetAlpha() ~= 1 then self:SetAlpha(1) end
            return
        end
        elapsed = elapsed + dt
        if elapsed < 0.05 then return end
        dt, elapsed = elapsed, 0
        local target = (Bar.moveMode or self:IsMouseOver() or ActiveKey()) and 1 or fade
        local a = self:GetAlpha()
        if math.abs(a - target) < 0.01 then a = target else a = a + (target - a) * math.min(1, dt * 10) end
        self:SetAlpha(a)
    end)

    -- Availability changes
    UpdateChannelStates()
    local refresh = ns.Debounce(function() Bar:Refresh() end, 0.2)
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "CHANNEL_UI_UPDATE",
        "PLAYER_ENTERING_WORLD", "PARTY_LEADER_CHANGED", "PLAYER_ROLES_ASSIGNED",
        "CHAT_MSG_CHANNEL_NOTICE" }) do
        ev:RegisterEvent(e)
    end
    ev:SetScript("OnEvent", function()
        UpdateChannelStates()
        refresh()
    end)

    -- Highlight the button that matches the open chat box
    local active = ns.Debounce(function() Bar:RefreshActive() end, 0.02)
    ns.SafeHook("ChatEdit_UpdateHeader", active)
    ns.SafeHook("ChatEdit_ActivateChat", active)
    ns.SafeHook("ChatEdit_DeactivateChat", active)

    -- Accent color changes only recolor; style changes call Bar:Refresh()
    ns:OnTheme(function()
        Bar:StyleFrame()
        for _, def in ipairs(defs) do
            if def.button then StyleButton(def.button) end
        end
    end)

    self:ApplyPosition()
    self:Refresh()
    self:RegisterSlash()
end

---------------------------------------------------------------------------
-- Slash commands (old names preserved)
---------------------------------------------------------------------------
function Bar:RegisterSlash()
    local function cmd(name, key, fn)
        _G["SLASH_" .. name .. "1"] = key
        SlashCmdList[name] = fn
    end
    local o = ns.db.bar

    cmd("ZTVBOOMCHAT", "/boomchat", function()
        o.visible = not o.visible
        Bar:Refresh()
        ns:Print(o.visible and "Chat bar shown." or "Chat bar hidden.")
    end)
    -- /boomlock used to lock the bar; it now toggles reposition mode
    local function move() Bar:SetMoveMode(not Bar.moveMode) end
    cmd("ZTVBOOMLOCK", "/boomlock", move)
    cmd("ZTVBOOMMOVE", "/boommove", move)
    cmd("ZTVBOOMROTATE", "/boomrotate", function()
        o.horizontal = not o.horizontal
        Bar:Refresh()
    end)
    cmd("ZTVBOOMTEXT", "/boomtext", function()
        o.showText = not o.showText
        Bar:Refresh()
    end)
    cmd("ZTVBOOMSIZE", "/boomsize", function(msg)
        local d = tonumber(msg)
        if not d or d == 0 then ns:Print("Usage: /boomsize 2 or /boomsize -2") return end
        o.size = math.max(14, math.min(40, o.size + d))
        Bar:Refresh()
        ns:Print(string.format(T("Button size: %d"), o.size))
    end)
    cmd("ZTVBOOMRESET", "/boomreset", function()
        Bar:ResetPosition()
        ns:Print("Chat bar position reset.")
    end)
    local function nudge(sign)
        return function(msg)
            local px = tonumber(msg)
            if not px or px <= 0 then ns:Print("Usage: /boomup 10 or /boomdown 10") return end
            local p = o.pos
            p.y = (p.y or 0) + sign * px
            Bar:ApplyPosition()
        end
    end
    cmd("ZTVBOOMUP", "/boomup", nudge(1))
    cmd("ZTVBOOMDOWN", "/boomdown", nudge(-1))

    cmd("ZTVKD5", "/kd5", function() Countdown(5) end)
    cmd("ZTVKD10", "/kd10", function() Countdown(10) end)
    cmd("ZTVRDC", "/rdc", function() ReadyCheck() end)
end
