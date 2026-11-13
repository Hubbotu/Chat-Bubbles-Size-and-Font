local ADDON, ns = ...
local UI = ns.UI
local C = UI.C
local Box = ns.Chatbox
local T = ns.T
local Rail = ns:NewModule("Rail")

local MEDIA = Box.MEDIA
local WHITE = "Interface\\Buttons\\WHITE8X8"
local EMOJI = "Interface\\AddOns\\" .. ADDON .. "\\emoji\\"

---------------------------------------------------------------------------
-- Emoji picker (shared by the left panel and the messenger)
---------------------------------------------------------------------------
local CELL, COLS, ROWS = 36, 6, 3
local picker, catcher
local pickState = { tab = "faces", onPick = nil }
local CODE = {}
for _, list in ipairs({ Box.emojiFaces, Box.emojiSymbols }) do
    for _, e in ipairs(list) do CODE[e[1]] = e[2] end
end

local TABS = {
    { "faces", "Faces" }, { "symbols", "Symbols" }, { "recent", "Recent" },
}

local function PickerItems()
    if pickState.tab == "faces" then return Box.emojiFaces end
    if pickState.tab == "symbols" then return Box.emojiSymbols end
    local out = {}
    for _, key in ipairs(ns.db.chatbox.recentEmoji) do
        if CODE[key] then out[#out + 1] = { key, CODE[key] } end
    end
    return out
end

local function FillPicker()
    local items = PickerItems()
    local ar, ag, ab = ns:GetAccent()
    for i, tb in ipairs(picker.tabs) do
        local on = pickState.tab == TABS[i][1]
        tb.line:SetShown(on)
        tb.line:SetColorTexture(ar, ag, ab, 1)
        tb.text:SetTextColor(on and 1 or 0.6, on and 1 or 0.62, on and 1 or 0.68)
    end
    for i, b in ipairs(picker.cells) do
        local it = items[i]
        if it then
            b.key, b.code = it[1], it[2]
            b.tex:SetTexture(EMOJI .. it[1])
            b:Show()
        else
            b:Hide()
        end
    end
    picker.empty:SetShown(#items == 0)
end

local function Remember(key)
    local list = ns.db.chatbox.recentEmoji
    for i = #list, 1, -1 do if list[i] == key then table.remove(list, i) end end
    table.insert(list, 1, key)
    while #list > COLS * ROWS do list[#list] = nil end
end

local function BuildPicker()
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:Hide()

    picker = CreateFrame("Frame", "ZamestoTVEmojiPicker", UIParent, "BackdropTemplate")
    picker:SetSize(COLS * CELL + 16, 34 + ROWS * CELL + 12)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    UI.Flat(picker, C.bg, C.border)
    picker:Hide()
    tinsert(UISpecialFrames, "ZamestoTVEmojiPicker")
    catcher:SetScript("OnClick", function() picker:Hide() end)
    picker:SetScript("OnHide", function() catcher:Hide(); picker.owner = nil end)

    picker.tabs = {}
    local x = 8
    for i, t in ipairs(TABS) do
        local tb = CreateFrame("Button", nil, picker)
        tb.text = UI.Text(tb, 11)
        tb.text:SetText(T(t[2]))
        tb:SetSize(tb.text:GetStringWidth() + 20, 26)
        tb:SetPoint("TOPLEFT", x, -4)
        tb.text:SetPoint("CENTER")
        tb.line = tb:CreateTexture(nil, "OVERLAY")
        tb.line:SetHeight(2)
        tb.line:SetPoint("BOTTOMLEFT", 6, 0)
        tb.line:SetPoint("BOTTOMRIGHT", -6, 0)
        tb:SetScript("OnClick", function() pickState.tab = t[1]; FillPicker() end)
        picker.tabs[i] = tb
        x = x + tb:GetWidth() + 2
    end
    local sep = picker:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1, 1, 1, 0.08)
    sep:SetPoint("TOPLEFT", 6, -31)
    sep:SetPoint("TOPRIGHT", -6, -31)
    sep:SetHeight(1)

    picker.cells = {}
    for i = 1, COLS * ROWS do
        local b = CreateFrame("Button", nil, picker)
        b:SetSize(CELL - 2, CELL - 2)
        b:SetPoint("TOPLEFT", 9 + ((i - 1) % COLS) * CELL, -38 - math.floor((i - 1) / COLS) * CELL)
        b.hl = b:CreateTexture(nil, "BACKGROUND")
        b.hl:SetTexture(MEDIA .. "circle")
        b.hl:SetAllPoints()
        b.hl:SetVertexColor(1, 1, 1, 0.14)
        b.hl:Hide()
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetSize(26, 26)
        b.tex:SetPoint("CENTER")
        b:SetScript("OnEnter", function(self)
            self.hl:Show()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.code, 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self)
            Remember(self.key)
            local fn = pickState.onPick
            if not IsShiftKeyDown() then picker:Hide() end
            if fn then fn(self.code, self.key) end
        end)
        picker.cells[i] = b
    end

    picker.empty = UI.Text(picker, 11, C.muted)
    picker.empty:SetPoint("CENTER", 0, -10)
    picker.empty:SetText(T("Nothing used yet."))
    picker.empty:Hide()
end

-- point/rel/x/y: where the picker opens relative to the anchor
function Box:ShowPicker(anchor, point, rel, x, y, onPick)
    if not picker then BuildPicker() end
    if picker:IsShown() and picker.owner == anchor then picker:Hide() return end
    picker.owner = anchor
    pickState.onPick = onPick
    picker:ClearAllPoints()
    picker:SetPoint(point, anchor, rel, x, y)
    catcher:Show()
    picker:Show()
    FillPicker()
end

function Box:HidePicker()
    if picker then picker:Hide() end
end

function Box:InsertIntoChat(text)
    local get = ns.ChatFn("ChatEdit_GetActiveWindow")
    local eb = get and get()
    if not eb or not eb:IsShown() then
        local open = ns.ChatFn("ChatFrame_OpenChat")
        if open then open("", SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME) end
        eb = get and get()
    end
    if eb then eb:Insert(text .. " ") end
end

---------------------------------------------------------------------------
-- Online counts
---------------------------------------------------------------------------
local classByLocalized
local function ClassFile(localized)
    if not classByLocalized then
        classByLocalized = {}
        for _, tbl in ipairs({ _G.LOCALIZED_CLASS_NAMES_MALE or {}, _G.LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
            for file, name in pairs(tbl) do classByLocalized[name] = file end
        end
    end
    return classByLocalized[localized]
end

local function ClassHex(file)
    local c = file and _G.RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    if c then return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
    return "|cffffffff"
end

local function FriendCounts()
    local wow, bn = 0, 0
    pcall(function()
        if C_FriendList and C_FriendList.GetNumOnlineFriends then wow = C_FriendList.GetNumOnlineFriends() or 0 end
        if BNGetNumFriends then local _, on = BNGetNumFriends(); bn = on or 0 end
    end)
    return wow, bn
end

local function GuildOnline()
    if not IsInGuild() then return nil end
    local ok, _, online = pcall(GetNumGuildMembers)
    return ok and online or 0
end

function Rail:Refresh()
    local f = self.frame
    if not f or not f:IsShown() then return end
    local wow, bn = FriendCounts()
    local n = wow + bn
    local it = self.items
    it.friends.count:SetText(tostring(n))
    it.friends.count:SetTextColor(n > 0 and 0.4 or 0.55, n > 0 and 1 or 0.57, n > 0 and 0.55 or 0.62)
    local g = GuildOnline()
    it.guild.available = g ~= nil
    if g then
        it.guild.count:SetText(tostring(g))
        it.guild.count:SetTextColor(g > 0 and 0.4 or 0.55, g > 0 and 1 or 0.57, g > 0 and 0.55 or 0.62)
    end
    local unread = ns.Messenger and ns.Messenger:GetUnread() or 0
    it.dm.count:SetText(unread > 0 and (unread > 99 and "99+" or tostring(unread)) or "")
    local ar, ag, ab = ns:GetAccent()
    it.dm.count:SetTextColor(ar, ag, ab)
    self:LayoutItems()
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------
local function FriendsTip(b)
    local wow, bn = FriendCounts()
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetText(string.format(T("Friends online: %d"), wow + bn), 1, 1, 1)
    local shown, limit = 0, 20
    pcall(function()
        local FL = C_FriendList
        if FL and FL.GetNumFriends then
            for i = 1, FL.GetNumFriends() do
                local fi = FL.GetFriendInfoByIndex(i)
                if fi and fi.connected then
                    shown = shown + 1
                    if shown <= limit then
                        GameTooltip:AddDoubleLine(
                            ClassHex(ClassFile(fi.className)) .. fi.name .. "|r  " .. (fi.level or ""),
                            fi.area or "", 1, 1, 1, 0.6, 0.6, 0.65)
                    end
                end
            end
        end
        if C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends then
            for i = 1, (BNGetNumFriends()) do
                local a = C_BattleNet.GetFriendAccountInfo(i)
                local g = a and a.gameAccountInfo
                if g and g.isOnline then
                    shown = shown + 1
                    if shown <= limit then
                        local tag = a.battleTag and a.battleTag:match("^([^#]+)") or a.accountName or "?"
                        local where = (g.characterName and g.characterName ~= "") and g.characterName
                            or g.clientProgram or ""
                        GameTooltip:AddDoubleLine("|cff4da6ff◆|r " .. tag, where, 1, 1, 1, 0.6, 0.6, 0.65)
                    end
                end
            end
        end
    end)
    if shown > limit then GameTooltip:AddLine(string.format(T("... and %d more"), shown - limit), 0.6, 0.6, 0.65) end
    GameTooltip:AddLine(T("Click: open the friends list"), 0.5, 0.5, 0.55)
    GameTooltip:Show()
end

local function GuildTip(b)
    local name = GetGuildInfo("player")
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetText(string.format(T("Guild online: %d"), GuildOnline() or 0), 1, 1, 1)
    if name then GameTooltip:AddLine(name, 0.25, 1, 0.35) end
    local shown, limit = 0, 25
    pcall(function()
        local total = GetNumGuildMembers()
        for i = 1, total do
            local gname, rank, _, level, _, zone, _, _, online, _, classFile = GetGuildRosterInfo(i)
            if online and gname then
                shown = shown + 1
                if shown <= limit then
                    GameTooltip:AddDoubleLine(ClassHex(classFile) .. Ambiguate(gname, "short") .. "|r  " .. (level or ""),
                        zone or "", 1, 1, 1, 0.6, 0.6, 0.65)
                end
            end
        end
    end)
    if shown > limit then GameTooltip:AddLine(string.format(T("... and %d more"), shown - limit), 0.6, 0.6, 0.65) end
    GameTooltip:AddLine(T("Click: open the guild window"), 0.5, 0.5, 0.55)
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- The panel itself
---------------------------------------------------------------------------
local function NewItem(parent, icon, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(30, 30)
    b.hl = b:CreateTexture(nil, "BACKGROUND")
    b.hl:SetTexture(MEDIA .. "circle")
    b.hl:SetAllPoints()
    b.hl:Hide()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexture(icon)
    b.icon:SetSize(size or 18, size or 18)
    b.icon:SetPoint("CENTER")
    b.count = UI.Text(b, 10)
    b.count:SetFont(UI.Font(), 10, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 5, -3)
    b.count:SetJustifyH("RIGHT")
    b:SetScript("OnEnter", function(self)
        local r, g, bl = ns:GetAccent()
        self.hl:SetVertexColor(r, g, bl, 0.28)
        self.hl:Show()
        if self.tip then self.tip(self) end
    end)
    b:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
    return b
end

function Rail:Build()
    local f = CreateFrame("Frame", "ZamestoTVChatRail", UIParent)
    f:SetFrameStrata("LOW")
    f:SetFrameLevel(10)
    self.frame = f

    local it = {}
    it.emoji = NewItem(f, EMOJI .. "smile", 22)
    it.emoji.tip = function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText(T("Emoji"), 1, 1, 1)
        GameTooltip:Show()
    end
    it.emoji:SetScript("OnClick", function(b)
        GameTooltip:Hide()
        Box:ShowPicker(b, "TOPLEFT", "TOPRIGHT", 10, 0, function(code) Box:InsertIntoChat(code) end)
    end)

    it.dm = NewItem(f, MEDIA .. "ico_dm", 18)
    it.dm.tip = function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText(T("Messenger"), 1, 1, 1)
        local n = ns.Messenger and ns.Messenger:GetUnread() or 0
        if n > 0 then GameTooltip:AddLine(string.format(T("%d unread"), n), 1, 0.82, 0) end
        GameTooltip:Show()
    end
    it.dm:SetScript("OnClick", function() if ns.Messenger then ns.Messenger:Toggle() end end)

    it.friends = NewItem(f, MEDIA .. "ico_friends", 18)
    it.friends.tip = FriendsTip
    it.friends:SetScript("OnClick", function()
        local toggle = _G.ToggleFriendsFrame
        if toggle then pcall(toggle, 1) end
    end)

    it.guild = NewItem(f, MEDIA .. "ico_guild", 18)
    it.guild.tip = GuildTip
    it.guild:SetScript("OnClick", function()
        local toggle = _G.ToggleGuildFrame or _G.ToggleCommunitiesFrame
        if toggle then pcall(toggle) end
    end)

    it.gear = NewItem(f, "Interface\\Buttons\\UI-OptionsButton", 14)
    it.gear.tip = function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText(T("Chat Helper settings"), 1, 1, 1)
        GameTooltip:Show()
    end
    it.gear:SetScript("OnClick", function() ns.Config:Open("chatbox") end)

    self.items = it
    f:SetScript("OnSizeChanged", ns.Debounce(function() Rail:LayoutItems() end, 0.1))
    ns:OnTheme(function()
        local r, g, b = ns:GetAccent()
        for _, k in ipairs({ "dm", "friends", "guild" }) do it[k].icon:SetVertexColor(r, g, b) end
    end)
end

-- Items are stacked top to bottom with no gaps: when the chat is short, the slots
-- shrink to fit, and the settings icon is the first thing to give way.
function Rail:LayoutItems()
    local f, o = self.frame, ns.db.chatbox.rail
    if not f then return end
    local it = self.items
    local H = f:GetHeight()
    if not H or H < 40 then H = 150 end

    local shown = {}
    if o.emoji then shown[#shown + 1] = it.emoji end
    if o.dm then shown[#shown + 1] = it.dm end
    if o.friends then shown[#shown + 1] = it.friends end
    if o.guild and it.guild.available then shown[#shown + 1] = it.guild end
    shown[#shown + 1] = it.gear

    local avail = H - 8
    local slot = math.floor(avail / #shown)
    if slot < 24 and #shown > 1 then            -- not enough room: drop the settings icon
        table.remove(shown)
        slot = math.floor(avail / #shown)
    end
    slot = math.max(22, math.min(34, slot))
    local size = math.min(30, slot)

    for _, b in pairs(it) do b:Hide(); b:ClearAllPoints() end
    for i, b in ipairs(shown) do
        b:SetSize(size, size)
        b:SetPoint("TOP", f, "TOP", 0, -4 - (i - 1) * slot)
        b:Show()
    end
end

function Rail:Apply()
    local o = ns.db.chatbox
    local cf = _G.ChatFrame1
    local on = cf and Box:RailWidth() > 0
    if not self.frame then self:Build() end
    local f = self.frame
    f:SetShown(on and true or false)
    if not on then
        if Box.frame then Box:LayoutRail() end
        return
    end
    local sbw = Box.SideButtonsWidth and Box.SideButtonsWidth() or 0
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", cf, "TOPLEFT", -sbw, 0)
    f:SetPoint("BOTTOMRIGHT", cf, "BOTTOMLEFT", -sbw, 0)
    f:SetWidth(Box:RailWidth())
    self:Refresh()
    if Box.frame then Box:LayoutRail() end
end

-- background + divider of the panel, drawn by the chatbox
function Box:LayoutRail()
    local f, rail = self.frame, ns.Rail and ns.Rail.frame
    if not f then return end
    if not (rail and rail:IsShown() and self:RailWidth() > 0 and f:IsShown()) then
        f.railBg:Hide()
        f.railLine:Hide()
        return
    end
    local o = ns.db.chatbox
    local st = self.st or self.STYLES.MODERN
    f.railBg:ClearAllPoints()
    f.railBg:SetPoint("TOPLEFT", rail, "TOPLEFT", -3, 6)
    f.railBg:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", 3, -6)
    f.railBg:SetColorTexture(0, 0, 0, 0.24 * (0.5 + o.alpha))
    f.railBg:Show()

    local r, g, b = 1, 1, 1
    local spec = st.ring and st.ring[1]
    if spec == "accent" then r, g, b = ns:GetAccent()
    elseif type(spec) == "table" then r, g, b = spec[1], spec[2], spec[3] end
    f.railLine:ClearAllPoints()
    f.railLine:SetPoint("TOPLEFT", rail, "TOPRIGHT", 3, 6)
    f.railLine:SetPoint("BOTTOMLEFT", rail, "BOTTOMRIGHT", 3, -6)
    f.railLine:SetWidth(1)
    f.railLine:SetColorTexture(r, g, b, spec and 0.35 or 0.10)
    f.railLine:Show()
end

function Rail:OnInit()
    self:Build()
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "FRIENDLIST_UPDATE", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE",
        "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_LIST_SIZE_CHANGED", "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE",
        "PLAYER_ENTERING_WORLD" }) do
        ev:RegisterEvent(e)
    end
    local refresh = ns.Debounce(function() Rail:Refresh() end, 0.5)
    ev:SetScript("OnEvent", function() refresh() end)

    -- the roster is only sent when asked for
    local function Ask()
        if IsInGuild() then
            if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster()
            elseif _G.GuildRoster then _G.GuildRoster() end
        end
    end
    C_Timer.NewTicker(60, function() Ask(); refresh() end)
    self.ask = Ask

    local bf = _G.ChatFrame1ButtonFrame
    if bf then
        local relayout = ns.Debounce(function() Box:UpdateDock(); Rail:Apply() end, 0.1)
        bf:HookScript("OnShow", relayout)
        bf:HookScript("OnHide", relayout)
    end
end

function Rail:OnLogin()
    self:Apply()
    C_Timer.After(3, function() Rail.ask(); Rail:Apply() end)
end
