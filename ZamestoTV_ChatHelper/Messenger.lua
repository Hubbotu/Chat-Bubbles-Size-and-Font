local ADDON, ns = ...
local UI = ns.UI
local C = UI.C
local M = ns:NewModule("Messenger")
local issecret = ns.IsSecret
local T = ns.T
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
local CIRCLE = "Interface\\AddOns\\" .. ADDON .. "\\media\\circle"

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CLASS_TEX = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local SIDE_W = 210
local ROW_H = 50
local MAX_SHOWN = 150 -- bubbles drawn per conversation

local frame
local state = { key = nil }
local notified = {}   -- conversations that already produced a chat notice
local lastSound = 0

local function DB() return ns.db.messenger end

local function Short(name) return Ambiguate(name, "none") or name end

local function Plain(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    return (s:gsub("||", "|"))
end

local function ChatLocked()
    local ci = C_ChatInfo
    if ci and ci.InChatMessagingLockdown then
        local ok, locked = pcall(ci.InChatMessagingLockdown)
        return ok and locked and true or false
    end
    return false
end

local function Contrast(r, g, b)
    if (0.299 * r + 0.587 * g + 0.114 * b) > 0.62 then return 0.08, 0.08, 0.10 end
    return 1, 1, 1
end

local refreshBar = ns.Debounce(function()
    if ns.Bar and ns.Bar.frame then ns.Bar:Refresh() end
end, 0.3)

---------------------------------------------------------------------------
-- Class / faction helpers
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

local function NormFaction(f)
    if f == "Alliance" or f == _G.FACTION_ALLIANCE then return "Alliance" end
    if f == "Horde" or f == _G.FACTION_HORDE then return "Horde" end
end

local function PlainName(s)
    return type(s) == "string" and not issecret(s) and s ~= "" and not s:find("|K", 1, true)
end

---------------------------------------------------------------------------
-- Conversations (stored per character in ns.db.messenger.history)
---------------------------------------------------------------------------
function M:GetConv(key, create, kind, name)
    local h = DB().history
    local c = h[key]
    if not c and create then
        c = { key = key, kind = kind, name = name, last = time(), unread = 0, msgs = {} }
        h[key] = c
    end
    return c
end

function M:Current()
    return state.key and DB().history[state.key] or nil
end

function M:GetUnread()
    local n = 0
    local h = ns.db and ns.db.messenger and ns.db.messenger.history
    if h then for _, c in pairs(h) do n = n + (c.unread or 0) end end
    return n
end

function M:Add(conv, out, text)
    local msgs, now = conv.msgs, time()
    msgs[#msgs + 1] = { t = now, o = out and true or nil, m = text }
    local max = math.max(20, DB().maxPerChat)
    while #msgs > max do table.remove(msgs, 1) end
    conv.last = now
end

function M:Prune()
    local o = DB()
    if o.retention == 0 then
        for k, c in pairs(o.history) do if not c.fav then o.history[k] = nil end end
        return
    end
    local cutoff = time() - o.retention * 86400
    local max = math.max(20, o.maxPerChat)
    for key, c in pairs(o.history) do
        local keep = {}
        for _, m in ipairs(c.msgs) do
            if c.fav or m.t >= cutoff then keep[#keep + 1] = m end   -- favorites are never aged out
        end
        while #keep > max do table.remove(keep, 1) end
        if #keep == 0 and not c.fav then
            o.history[key] = nil
        else
            c.msgs = keep
        end
    end
end

function M:Delete(key)
    DB().history[key] = nil
    notified[key] = nil
    if state.key == key then state.key = nil end
    self:Refresh()
    refreshBar()
end

function M:ClearAll()
    local h = DB().history
    for k, c in pairs(h) do if not c.fav then h[k] = nil end end   -- favorites stay
    wipe(notified)
    state.key = nil
    self:Refresh()
    refreshBar()
end

---------------------------------------------------------------------------
-- Battle.net helpers
---------------------------------------------------------------------------
local function BNAccountByID(id)
    if id and not issecret(id) and C_BattleNet and C_BattleNet.GetAccountInfoByID then
        local ok, a = pcall(C_BattleNet.GetAccountInfoByID, id)
        if ok then return a end
    end
end

local function UpdateBNInfo(c, acct)
    local g = acct and acct.gameAccountInfo
    if not g then return end
    c.online = g.isOnline and true or false
    if PlainName(g.characterName) then c.char = g.characterName end
    if g.className and g.className ~= "" then c.class = ClassFile(g.className) or c.class end
    c.faction = NormFaction(g.factionName) or c.faction
    c.game = g.clientProgram
    c.presence = PlainName(g.richPresence) and g.richPresence or nil
end

-- Presence ids only live for one session, so find the friend again by BattleTag.
local function ResolveBN(conv)
    local id = conv.bnID
    if id then
        local a = BNAccountByID(id)
        if a and (not conv.battletag or a.battleTag == conv.battletag) then return id, a end
    end
    if conv.battletag and C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends then
        for i = 1, (BNGetNumFriends()) do
            local ok, a = pcall(C_BattleNet.GetFriendAccountInfo, i)
            if ok and a and a.battleTag == conv.battletag then
                conv.bnID = a.bnetAccountID
                return a.bnetAccountID, a
            end
        end
    end
end

local function FindBNByName(target)
    if not (C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends) then return end
    for i = 1, (BNGetNumFriends()) do
        local ok, a = pcall(C_BattleNet.GetFriendAccountInfo, i)
        if ok and a then
            if a.accountName == target or a.battleTag == target
                or (a.gameAccountInfo and a.gameAccountInfo.characterName == target) then
                return a.bnetAccountID
            end
        end
    end
end

function M:ConvForBN(bnID, author)
    local acct = BNAccountByID(bnID)
    local tag = acct and acct.battleTag
    if tag and (issecret(tag) or tag == "") then tag = nil end
    local key = tag and ("bn:" .. tag:lower()) or ("bn:id" .. tostring(bnID or author or "?"))
    local name = (tag and tag:match("^([^#]+)"))
        or (acct and PlainName(acct.accountName) and acct.accountName)
        or (PlainName(author) and author)
        or "Battle.net friend"
    local c = self:GetConv(key, true, "BN", name)
    c.name = name
    c.battletag = tag or c.battletag
    if bnID and not issecret(bnID) then c.bnID = bnID end
    UpdateBNInfo(c, acct)
    return c
end

function M:ConvForWhisper(author, guid)
    local name = Short(author)
    local c = self:GetConv("w:" .. name:lower(), true, "W", name)
    c.name = name
    if guid and not issecret(guid) and type(guid) == "string" and guid ~= "" then
        local ok, _, class, _, race, _, gname = pcall(GetPlayerInfoByGUID, guid)
        local base = name:match("^[^-]+") or name
        -- the guid of an outgoing whisper may be ours: only accept a matching name
        if ok and class and gname and gname:lower() == base:lower() then
            c.class = class
            local rf = ns.Chatbox and ns.Chatbox.RaceFaction
            c.faction = (rf and rf[race]) or c.faction
        end
    end
    return c
end

---------------------------------------------------------------------------
-- Incoming / outgoing messages
---------------------------------------------------------------------------
function M:Notify(conv, out)
    local o = DB()
    local visible = frame and frame:IsShown() and state.key == conv.key
    if out then
        self:Refresh()
        return
    end
    if not visible then conv.unread = (conv.unread or 0) + 1 end

    if o.sound and GetTime() - lastSound > 1 then
        lastSound = GetTime()
        pcall(PlaySound, SOUNDKIT.TELL_MESSAGE)
    end

    if o.autoOpen and not visible then
        self:Open(conv.key)
    else
        if o.notify and not visible and not notified[conv.key] then
            notified[conv.key] = true
            ns:Print(string.format(T("New message from %s") .. "  |cff%s|Hztvmsg:%s|h[%s]|h|r",
                conv.name, ns.Hex(ns:GetAccent()), conv.key, T("Open")))
        end
        self:Refresh()
    end
    refreshBar()
end

function M:OnMessage(event, msg, author, guid, bnID)
    local o = DB()
    if not o.enabled then return end
    if type(msg) ~= "string" or issecret(msg) then return end
    if author ~= nil and issecret(author) then return end
    local out = event:find("INFORM", 1, true) ~= nil
    local conv

    if event:find("BN_", 1, true) then
        if not o.bnet then return end
        conv = self:ConvForBN(bnID, author)
        if not out and PlainName(author) then
            local setLast = ns.ChatFn("ChatEdit_SetLastTellTarget")
            if setLast then pcall(setLast, author, "BN_WHISPER") end
        end
    else
        if type(author) ~= "string" or author == "" then return end
        conv = self:ConvForWhisper(author, guid)
        if not out then
            local setLast = ns.ChatFn("ChatEdit_SetLastTellTarget")
            if setLast then pcall(setLast, author, "WHISPER") end
        end
    end
    if not conv then return end

    self:Add(conv, out, msg)
    self:Notify(conv, out)
end

---------------------------------------------------------------------------
-- Opening conversations
---------------------------------------------------------------------------
local function MostRecent()
    local best
    for _, c in pairs(DB().history) do
        if not best or (c.last or 0) > (best.last or 0) then best = c end
    end
    return best and best.key
end

function M:Select(key)
    local c = key and DB().history[key]
    state.key = c and key or nil
    if c then
        c.unread = 0
        notified[key] = nil
        if c.kind == "BN" then
            local _, a = ResolveBN(c)
            UpdateBNInfo(c, a)
        end
    end
    self:Refresh()
    refreshBar()
    if frame and c then frame.input:SetFocus() end
end

function M:Open(key)
    if not DB().enabled then
        ns:Print(T("The messenger is turned off in the settings."))
        return
    end
    if not frame then frame = self:Build() end
    frame:Show()
    local h = DB().history
    if key and h[key] then
        self:Select(key)
    elseif state.key and h[state.key] then
        self:Select(state.key)
    else
        self:Select(MostRecent())
    end
end

function M:Toggle()
    if frame and frame:IsShown() then frame:Hide() else self:Open() end
end

function M:OpenWhisper(name)
    if not name or name == "" then return end
    local short = Short(name)
    local c = self:GetConv("w:" .. short:lower(), true, "W", short)
    c.name = short
    self:Open(c.key)
end

function M:OpenBN(bnID)
    local c = self:ConvForBN(bnID, nil)
    self:Open(c.key)
end

---------------------------------------------------------------------------
-- Actions on the open conversation: invite, ignore, favorite
---------------------------------------------------------------------------
local function IsIgnoredName(name)
    local fn = (C_FriendList and C_FriendList.IsIgnored) or _G.IsIgnored
    if not fn or not name then return false end
    local ok, v = pcall(fn, name)
    return ok and v and true or false
end

-- name the game understands for invites: the character of a Battle.net friend
local function InviteName(conv)
    if conv.kind ~= "BN" then return conv.name end
    local _, a = ResolveBN(conv)
    UpdateBNInfo(conv, a)
    local g = a and a.gameAccountInfo
    if g and g.isOnline and PlainName(g.characterName) and (g.clientProgram == nil or g.clientProgram == "WoW") then
        local name, realm = g.characterName, g.realmName
        if PlainName(realm) and realm ~= GetRealmName() then name = name .. "-" .. realm:gsub("%s", "") end
        return name
    end
end

function M:Invite(conv)
    local name = InviteName(conv)
    if not name then
        ns:Print(T("This friend is not playing WoW right now."))
        return
    end
    local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or _G.InviteUnit
    if invite and pcall(invite, name) then
        ns:Print(string.format(T("Invited %s to the group."), name))
    else
        ns:Print(T("The invitation could not be sent."))
    end
end

function M:ToggleIgnore(conv)
    if conv.kind == "BN" then
        ns:Print(T("Ignoring is not available for Battle.net chats."))
        return
    end
    local was = IsIgnoredName(conv.name)
    local toggle = (C_FriendList and C_FriendList.AddOrDelIgnore) or _G.AddOrDelIgnore
    if toggle and pcall(toggle, conv.name) then
        ns:Print(string.format(was and T("%s is no longer ignored.") or T("%s is now ignored."), conv.name))
    end
    self:Refresh()
end

function M:ToggleFavorite(conv)
    conv.fav = (not conv.fav) or nil
    self:Refresh()
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
local function SendInput()
    local conv = M:Current()
    if not conv or not frame then return end
    local text = (frame.input:GetText() or ""):match("^%s*(.-)%s*$")
    if text == "" then return end
    if ChatLocked() then
        ns:Print(T("The game is blocking addon chat right now (boss fight, Mythic+ or PvP)."))
        return
    end
    local ok
    if conv.kind == "BN" then
        local id = ResolveBN(conv)
        if not id then
            ns:Print(T("This Battle.net friend was not found or is offline."))
            return
        end
        local send = (C_BattleNet and C_BattleNet.SendWhisper) or _G.BNSendWhisper
        ok = send and pcall(send, id, text)
    else
        local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
        ok = pcall(send, text, "WHISPER", nil, conv.name)
    end
    if ok then frame.input:SetText("") else ns:Print(T("The message could not be sent.")) end
    frame.input:SetFocus()
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local PALETTE = {
    { 0.90, 0.45, 0.35 }, { 0.35, 0.65, 0.95 }, { 0.55, 0.80, 0.40 }, { 0.80, 0.55, 0.90 },
    { 0.95, 0.75, 0.30 }, { 0.35, 0.80, 0.75 }, { 0.95, 0.55, 0.70 }, { 0.60, 0.65, 0.95 },
}

local function NewAvatar(parent, size)
    local av = CreateFrame("Frame", nil, parent)
    av:SetSize(size, size)
    av.tex = av:CreateTexture(nil, "ARTWORK")
    av.tex:SetAllPoints()
    av.mask = av:CreateMaskTexture()
    av.mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    av.mask:SetAllPoints(av.tex)
    av.letter = UI.Text(av, math.floor(size * 0.5), { 1, 1, 1 })
    av.letter:SetPoint("CENTER", 0, 0)
    av.letter:SetJustifyH("CENTER")
    return av
end

local function PaintAvatar(av, conv)
    local round = ns.db.chatbox.classIconsRound
    if round and not av.masked then av.tex:AddMaskTexture(av.mask); av.masked = true
    elseif not round and av.masked then av.tex:RemoveMaskTexture(av.mask); av.masked = false end
    local t = conv.class and _G.CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[conv.class]
    if t then
        av.tex:SetTexture(CLASS_TEX)
        av.tex:SetTexCoord(t[1], t[2], t[3], t[4])
        av.tex:SetVertexColor(1, 1, 1)
        av.letter:SetText("")
    else
        local h = 0
        for i = 1, #conv.name do h = (h * 31 + conv.name:byte(i)) % 997 end
        local p = (conv.kind == "BN") and { 0.30, 0.60, 1.00 } or PALETTE[h % #PALETTE + 1]
        av.tex:SetTexture(WHITE)
        av.tex:SetTexCoord(0, 1, 0, 1)
        av.tex:SetVertexColor(p[1], p[2], p[3])
        av.letter:SetText((conv.name:match("[%z\1-\127\194-\244][\128-\191]*") or "?"):upper())
    end
end

local function NameColor(conv)
    local cc = conv.class and _G.RAID_CLASS_COLORS and RAID_CLASS_COLORS[conv.class]
    if cc then return cc.r, cc.g, cc.b end
    return unpack(C.text)
end

local function DayKey(t) return date("%Y%j", t) end

local function FormatListTime(t)
    local now = time()
    if DayKey(t) == DayKey(now) then return date("%H:%M", t) end
    if DayKey(t) == DayKey(now - 86400) then return T("Yesterday") end
    return date("%d.%m", t)
end

local function DayLabel(t)
    local now = time()
    if DayKey(t) == DayKey(now) then return T("Today") end
    if DayKey(t) == DayKey(now - 86400) then return T("Yesterday") end
    return date("%d.%m.%Y", t)
end

local function FontPath()
    local p = _G.ChatFrame1 and select(1, ChatFrame1:GetFont())
    return UI.FontFor(p)   -- the chat font, unless it cannot draw Cyrillic
end

local rows, bubbles, seps = {}, {}, {}

local function GetRow(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, frame.listContent)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    r:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bar = r:CreateTexture(nil, "OVERLAY")
    r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(3)
    r.av = NewAvatar(r, 34)
    r.av:SetPoint("LEFT", 12, 0)
    r.fav = r:CreateTexture(nil, "OVERLAY")
    r.fav:SetTexture(MEDIA .. "ico_star")
    r.fav:SetSize(13, 13)
    r.fav:SetPoint("TOPLEFT", r.av, "TOPLEFT", -4, 4)
    r.fav:SetVertexColor(1, 0.82, 0.2)
    r.fav:Hide()
    r.name = UI.Text(r, 12)
    r.name:SetPoint("TOPLEFT", r.av, "TOPRIGHT", 9, -2)
    r.name:SetPoint("RIGHT", r, "RIGHT", -52, 0)
    r.name:SetWordWrap(false)
    r.prev = UI.Text(r, 11, C.muted)
    r.prev:SetPoint("BOTTOMLEFT", r.av, "BOTTOMRIGHT", 9, 1)
    r.prev:SetPoint("RIGHT", r, "RIGHT", -34, 0)
    r.prev:SetWordWrap(false)
    r.time = UI.Text(r, 10, C.muted)
    r.time:SetPoint("TOPRIGHT", -8, -9)
    r.time:SetJustifyH("RIGHT")
    r.badge = r:CreateTexture(nil, "ARTWORK")
    r.badge:SetTexture(WHITE)
    r.badge:SetSize(20, 16)
    r.badge:SetPoint("BOTTOMRIGHT", -8, 9)
    r.count = UI.Text(r, 10, { 1, 1, 1 })
    r.count:SetPoint("CENTER", r.badge, "CENTER", 0, 0)
    r.count:SetJustifyH("CENTER")
    r.del = CreateFrame("Button", nil, r)
    r.del:SetSize(18, 18)
    r.del:SetPoint("TOPRIGHT", -4, -4)
    r.del.t = UI.Text(r.del, 14, C.muted)
    r.del.t:SetPoint("CENTER", 0, 1)
    r.del.t:SetText("×")
    r.del:Hide()
    r.del:SetScript("OnEnter", function(self) self.t:SetTextColor(1, 0.35, 0.35); r.hover = true end)
    r.del:SetScript("OnLeave", function(self) self.t:SetTextColor(unpack(C.muted)) end)
    r.del:SetScript("OnClick", function()
        local c = r.conv
        if c then StaticPopup_Show("ZTVCHAT_DELCONV", c.name, nil, c.key) end
    end)
    r:SetScript("OnEnter", function(self) self.hover = true; M:PaintRow(self) end)
    r:SetScript("OnLeave", function(self)
        if not self:IsMouseOver() then self.hover = false; M:PaintRow(self) end
    end)
    r:SetScript("OnClick", function(self, btn)
        if not self.conv then return end
        if btn == "RightButton" then
            StaticPopup_Show("ZTVCHAT_DELCONV", self.conv.name, nil, self.conv.key)
        else
            M:Select(self.conv.key)
        end
    end)
    rows[i] = r
    return r
end

function M:PaintRow(r)
    local c = r.conv
    if not c then return end
    local ar, ag, ab = ns:GetAccent()
    local selected = state.key == c.key
    if selected then r.bg:SetColorTexture(ar, ag, ab, 0.16)
    elseif r.hover then r.bg:SetColorTexture(1, 1, 1, 0.05)
    else r.bg:SetColorTexture(0, 0, 0, 0) end
    r.bar:SetColorTexture(ar, ag, ab, 1)
    r.bar:SetShown(selected)
    r.badge:SetColorTexture(ar, ag, ab, 1)
    r.del:SetShown(r.hover and true or false)
end

function M:RefreshList()
    if not frame then return end
    local list = {}
    for _, c in pairs(DB().history) do
        if c.fav or not state.favOnly then list[#list + 1] = c end
    end
    table.sort(list, function(a, b)
        local fa, fb = a.fav and 1 or 0, b.fav and 1 or 0
        if fa ~= fb then return fa > fb end
        return (a.last or 0) > (b.last or 0)
    end)
    frame.noList:SetText(state.favOnly and T("No favorite conversations yet.")
        or T("No conversations yet. Whispers and Battle.net messages will show up here."))
    frame.favFilter.icon:SetTexture(MEDIA .. (state.favOnly and "ico_star" or "ico_star_line"))
    frame.favFilter.icon:SetVertexColor(state.favOnly and 1 or 0.6, state.favOnly and 0.82 or 0.62, state.favOnly and 0.2 or 0.68)

    frame.listContent:SetHeight(math.max(1, #list * ROW_H))
    frame.noList:SetShown(#list == 0)
    for i, c in ipairs(list) do
        local r = GetRow(i)
        r.conv = c
        PaintAvatar(r.av, c)
        r.name:SetText((c.kind == "BN" and "|cff4da6ff◆|r " or "") .. c.name)
        r.name:SetTextColor(NameColor(c))
        r.fav:SetShown(c.fav and true or false)
        local last = c.msgs[#c.msgs]
        local prev = last and Plain(last.m) or ""
        r.prev:SetText(last and (last.o and (T("You:") .. " " .. prev) or prev) or "")
        r.time:SetText(last and FormatListTime(last.t) or "")
        local n = c.unread or 0
        r.badge:SetShown(n > 0)
        r.count:SetText(n > 99 and "99+" or tostring(n))
        r.count:SetShown(n > 0)
        r.hover = r:IsMouseOver()
        self:PaintRow(r)
        r:Show()
    end
    for i = #list + 1, #rows do rows[i].conv = nil; rows[i]:Hide() end
end

function M:RenderHeader()
    if not frame then return end
    local c = self:Current()
    local h = frame.head
    h:SetShown(c ~= nil)
    frame.input:SetShown(c ~= nil)
    frame.send:SetShown(c ~= nil)
    frame.emoji:SetShown(c ~= nil)
    if not c then ns.Chatbox:HidePicker() return end

    PaintAvatar(h.av, c)
    h.name:SetText(c.name)
    h.name:SetTextColor(NameColor(c))

    local parts = {}
    local className = c.class and _G.LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.class]
    if c.kind == "BN" then
        parts[#parts + 1] = "Battle.net"
        if c.online == false then parts[#parts + 1] = T("offline")
        else
            if c.char then parts[#parts + 1] = c.char end
            if className then parts[#parts + 1] = className end
            if c.presence then parts[#parts + 1] = c.presence end
        end
    else
        if className then parts[#parts + 1] = className end
        if c.faction then parts[#parts + 1] = c.faction end
        if #parts == 0 then parts[1] = T("Whisper") end
    end
    local ignored = c.kind ~= "BN" and IsIgnoredName(c.name)
    if ignored then parts[#parts + 1] = T("ignored") end
    h.sub:SetText(table.concat(parts, "  ·  "))

    -- action buttons
    h.fav.icon:SetTexture(MEDIA .. (c.fav and "ico_star" or "ico_star_line"))
    if c.fav then h.fav.icon:SetVertexColor(1, 0.82, 0.2) else h.fav.icon:SetVertexColor(0.7, 0.72, 0.78) end
    if ignored then h.block.icon:SetVertexColor(1, 0.35, 0.35) else h.block.icon:SetVertexColor(0.7, 0.72, 0.78) end
    h.block.icon:SetAlpha(c.kind == "BN" and 0.35 or 1)
    local ar, ag, ab = ns:GetAccent()
    h.invite.icon:SetVertexColor(ar, ag, ab)

    local fac = c.faction
    if fac == "Alliance" or fac == "Horde" then
        h.faction:SetTexture("Interface\\PVPFrame\\PVP-Currency-" .. fac)
        h.faction:Show()
    else
        h.faction:Hide()
    end
end

local function GetBubble(i)
    local b = bubbles[i]
    if b then return b end
    b = CreateFrame("Button", nil, frame.content, "BackdropTemplate")
    b:RegisterForClicks("LeftButtonUp")
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetJustifyH("LEFT")
    b.text:SetJustifyV("TOP")
    b.text:SetWordWrap(true)
    b.text:SetPoint("TOPLEFT", 10, -7)
    b.time = b:CreateFontString(nil, "OVERLAY")
    b.time:SetFont(UI.Font(), 10, "")
    b.time:SetPoint("BOTTOMRIGHT", -8, 4)
    b:SetScript("OnClick", function(self)
        local raw = self.raw
        if not raw then return end
        local link = raw:match("|H([^|]+)|h")
        if link then
            pcall(SetItemRef, link, raw, "LeftButton")
            return
        end
        local url = raw:match("(https?://[^%s]+)") or raw:match("(www%.[^%s]+)")
        if url then ns:ShowURL(url) end
    end)
    b:SetScript("OnEnter", function(self)
        local link = self.raw and self.raw:match("|H([^|]+)|h")
        if link and link:find("^item:") or link and (link:find("^spell:") or link:find("^achievement:")
            or link:find("^currency:") or link:find("^enchant:")) then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then GameTooltip:Show() end
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bubbles[i] = b
    return b
end

local function GetSep(i)
    local s = seps[i]
    if s then return s end
    s = UI.Text(frame.content, 10, C.muted)
    s:SetJustifyH("CENTER")
    seps[i] = s
    return s
end

function M:RenderMessages()
    if not frame then return end
    local conv = self:Current()
    local content = frame.content
    for _, b in ipairs(bubbles) do b:Hide() end
    for _, s in ipairs(seps) do s:Hide() end
    frame.empty:SetShown(conv == nil)
    if not conv then content:SetHeight(1) return end

    local o = DB()
    local width = frame.msgScroll:GetWidth()
    if not width or width < 120 then width = 420 end
    content:SetWidth(width)

    local path, size = FontPath(), o.fontSize
    local maxText = math.floor(width * 0.72) - 22
    local ar, ag, ab = ns:GetAccent()
    local tr, tg, tb = Contrast(ar, ag, ab)
    local emoji = ns.db.chatbox.emoji and ns.Chatbox
    local msgs = conv.msgs
    local first = math.max(1, #msgs - MAX_SHOWN + 1)

    local y, lastDay, nb, nsep = 10, nil, 0, 0
    for i = first, #msgs do
        local m = msgs[i]
        local day = DayKey(m.t)
        if day ~= lastDay then
            lastDay = day
            nsep = nsep + 1
            local s = GetSep(nsep)
            s:SetText(DayLabel(m.t))
            s:ClearAllPoints()
            s:SetPoint("TOP", content, "TOP", 0, -y)
            s:Show()
            y = y + 22
        end

        nb = nb + 1
        local b = GetBubble(nb)
        if not pcall(b.text.SetFont, b.text, path, size, "") then b.text:SetFont(UI.Font(), size, "") end
        b.text:SetWidth(0)
        local shown = m.m
        if ns.db.chatbox.itemLevel then shown = ns.Chatbox.AddItemLevels(shown) end
        if emoji then shown = ns.Chatbox:Emojify(shown) end
        b.text:SetText(shown)
        local w = math.min(b.text:GetStringWidth(), maxText)
        b.text:SetWidth(math.max(10, w + 2))
        local th = b.text:GetStringHeight()
        b.time:SetText(date("%H:%M", m.t))
        local bw = math.max(w + 2, b.time:GetStringWidth() + 4) + 20
        local bh = th + 7 + 17
        b:SetSize(bw, bh)
        b.raw = m.m

        local out = m.o
        b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        if out then
            b:SetBackdropColor(ar, ag, ab, 0.88)
            b:SetBackdropBorderColor(ar, ag, ab, 1)
            b.text:SetTextColor(tr, tg, tb)
            b.time:SetTextColor(tr, tg, tb, 0.7)
        else
            b:SetBackdropColor(unpack(C.panel))
            b:SetBackdropBorderColor(unpack(C.border))
            b.text:SetTextColor(unpack(C.text))
            b.time:SetTextColor(unpack(C.muted))
        end
        b:ClearAllPoints()
        if out then b:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, -y)
        else b:SetPoint("TOPLEFT", content, "TOPLEFT", 12, -y) end
        b:Show()
        y = y + bh + 5
    end
    content:SetHeight(y + 10)
    C_Timer.After(0, function()
        if frame and frame.msgScroll then
            frame.msgScroll:SetVerticalScroll(frame.msgScroll:GetVerticalScrollRange())
        end
    end)
end

function M:Refresh()
    if not frame or not frame:IsShown() then return end
    local c = self:Current()
    if c and (c.unread or 0) > 0 then c.unread = 0; refreshBar() end
    self:RefreshList()
    self:RenderHeader()
    self:RenderMessages()
end

function M:Build()
    local o = DB()
    local f = CreateFrame("Frame", "ZamestoTVMessenger", UIParent, "BackdropTemplate")
    f:SetSize(math.max(520, math.min(1100, o.ui.w)), math.max(320, math.min(800, o.ui.h)))
    f:SetPoint("CENTER", 0, 20)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetResizeBounds then f:SetResizeBounds(520, 320, 1100, 800)
    elseif f.SetMinResize then f:SetMinResize(520, 320) end
    UI.Flat(f, C.bg, C.border)
    tinsert(UISpecialFrames, "ZamestoTVMessenger")

    f.top = f:CreateTexture(nil, "OVERLAY")
    f.top:SetPoint("TOPLEFT", 1, -1)
    f.top:SetPoint("TOPRIGHT", -1, -1)
    f.top:SetHeight(2)

    -- left: conversation list ------------------------------------------------
    local side = CreateFrame("Frame", nil, f, "BackdropTemplate")
    side:SetPoint("TOPLEFT", 1, -3)
    side:SetPoint("BOTTOMLEFT", 1, 1)
    side:SetWidth(SIDE_W)
    UI.Flat(side, C.side, { 0, 0, 0, 0 })
    f.side = side

    f.title = UI.Text(side, 15)
    f.title:SetPoint("TOPLEFT", 14, -14)
    f.title:SetText(T("Messages"))

    f.favFilter = CreateFrame("Button", nil, side)
    f.favFilter:SetSize(24, 24)
    f.favFilter:SetPoint("TOPRIGHT", -10, -12)
    f.favFilter.icon = f.favFilter:CreateTexture(nil, "ARTWORK")
    f.favFilter.icon:SetTexture(MEDIA .. "ico_star_line")
    f.favFilter.icon:SetSize(16, 16)
    f.favFilter.icon:SetPoint("CENTER")
    f.favFilter:SetScript("OnClick", function() state.favOnly = not state.favOnly; M:RefreshList() end)
    f.favFilter:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(state.favOnly and T("Show all conversations") or T("Show favorites only"), 1, 1, 1)
        GameTooltip:Show()
    end)
    f.favFilter:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.new = UI.Edit(side, 100, 24, function(self)
        local t = self:GetText()
        self:SetText("")
        if t and t:match("%S") then M:OpenWhisper(t:match("^%s*(.-)%s*$")) end
    end)
    f.new:SetPoint("TOPLEFT", 10, -42)
    f.new:SetPoint("TOPRIGHT", -10, -42)
    f.new:SetMaxLetters(48)
    f.newHint = UI.Text(f.new, 11, C.muted)
    f.newHint:SetPoint("LEFT", 8, 0)
    f.newHint:SetText(T("New whisper: name + Enter"))
    f.new:HookScript("OnTextChanged", function(self) f.newHint:SetShown(self:GetText() == "") end)
    f.new:HookScript("OnEditFocusGained", function() f.newHint:Hide() end)
    f.new:HookScript("OnEditFocusLost", function(self) f.newHint:SetShown(self:GetText() == "") end)

    f.list = CreateFrame("ScrollFrame", nil, side)
    f.list:SetPoint("TOPLEFT", 0, -76)
    f.list:SetPoint("BOTTOMRIGHT", 0, 42)
    f.list:EnableMouseWheel(true)
    f.list:SetScript("OnMouseWheel", function(self, d)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - d * 40)))
    end)
    f.listContent = CreateFrame("Frame", nil, f.list)
    f.listContent:SetSize(SIDE_W, 1)
    f.list:SetScrollChild(f.listContent)

    f.noList = UI.Text(side, 11, C.muted)
    f.noList:SetPoint("TOPLEFT", 16, -96)
    f.noList:SetPoint("TOPRIGHT", -16, -96)
    f.noList:SetWordWrap(true)
    f.noList:SetJustifyV("TOP")
    f.noList:SetText(T("No conversations yet. Whispers and Battle.net messages will show up here."))

    f.clear = UI.Button(side, "Clear all", 80, 24, function()
        StaticPopup_Show("ZTVCHAT_CLEARALL")
    end)
    f.clear:SetPoint("BOTTOMLEFT", 10, 10)
    f.settings = UI.Button(side, "Settings", 80, 24, function() ns.Config:Open("messenger") end)
    f.settings:SetPoint("BOTTOMRIGHT", -10, 10)

    -- right: header -------------------------------------------------------------
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, 0)
    head:SetPoint("TOPRIGHT", f, "TOPRIGHT", -44, -3)
    head:SetHeight(54)
    head.av = NewAvatar(head, 36)
    head.av:SetPoint("LEFT", 14, 0)
    head.name = UI.Text(head, 15)
    head.name:SetPoint("TOPLEFT", head.av, "TOPRIGHT", 10, -1)
    head.faction = head:CreateTexture(nil, "ARTWORK")
    head.faction:SetSize(18, 18)
    head.faction:SetPoint("LEFT", head.name, "RIGHT", 8, 0)
    head.sub = UI.Text(head, 11, C.muted)
    head.sub:SetPoint("BOTTOMLEFT", head.av, "BOTTOMRIGHT", 10, 0)
    head.sub:SetPoint("RIGHT", head, "RIGHT", -104, 0)
    head.sub:SetWordWrap(false)
    local function Action(icon, tip, onClick)
        local b = CreateFrame("Button", nil, head)
        b:SetSize(30, 30)
        b.hl = b:CreateTexture(nil, "BACKGROUND")
        b.hl:SetTexture(CIRCLE)
        b.hl:SetAllPoints()
        b.hl:SetVertexColor(1, 1, 1, 0.12)
        b.hl:Hide()
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetTexture(MEDIA .. icon)
        b.icon:SetSize(17, 17)
        b.icon:SetPoint("CENTER")
        b:SetScript("OnEnter", function(self)
            self.hl:Show()
            local c = M:Current()
            if not c then return end
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(tip(c), 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
        b:SetScript("OnClick", function()
            local c = M:Current()
            if c then onClick(c) end
        end)
        return b
    end
    head.fav = Action("ico_star_line", function(c)
        return c.fav and T("Remove from favorites") or T("Add to favorites")
    end, function(c) M:ToggleFavorite(c) end)
    head.fav:SetPoint("RIGHT", head, "RIGHT", -4, 0)
    head.block = Action("ico_block", function(c)
        if c.kind == "BN" then return T("Ignoring is not available for Battle.net chats.") end
        return IsIgnoredName(c.name) and T("Stop ignoring this player") or T("Ignore this player")
    end, function(c) M:ToggleIgnore(c) end)
    head.block:SetPoint("RIGHT", head.fav, "LEFT", -2, 0)
    head.invite = Action("ico_invite", function() return T("Invite to group") end, function(c) M:Invite(c) end)
    head.invite:SetPoint("RIGHT", head.block, "LEFT", -2, 0)

    head.line = f:CreateTexture(nil, "ARTWORK")
    head.line:SetColorTexture(1, 1, 1, 0.08)
    head.line:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, -57)
    head.line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -57)
    head.line:SetHeight(1)
    f.head = head

    f.close = CreateFrame("Button", nil, f)
    f.close:SetSize(28, 28)
    f.close:SetPoint("TOPRIGHT", -8, -8)
    f.close.text = UI.Text(f.close, 18, C.muted)
    f.close.text:SetPoint("CENTER", 0, 1)
    f.close.text:SetText("×")
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.close:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.35, 0.35) end)
    f.close:SetScript("OnLeave", function(self) self.text:SetTextColor(unpack(C.muted)) end)

    -- right: messages -------------------------------------------------------------
    f.msgScroll = CreateFrame("ScrollFrame", nil, f)
    f.msgScroll:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, -58)
    f.msgScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 56)
    f.msgScroll:EnableMouseWheel(true)
    f.msgScroll:SetScript("OnMouseWheel", function(self, d)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - d * 50)))
    end)
    f.content = CreateFrame("Frame", nil, f.msgScroll)
    f.content:SetSize(400, 1)
    f.msgScroll:SetScrollChild(f.content)
    local relayout = ns.Debounce(function() M:RenderMessages() end, 0.05)
    f.msgScroll:SetScript("OnSizeChanged", relayout)

    f.empty = UI.Text(f, 12, C.muted)
    f.empty:SetPoint("CENTER", f.msgScroll, "CENTER", 0, 0)
    f.empty:SetWidth(300)
    f.empty:SetJustifyH("CENTER")
    f.empty:SetWordWrap(true)
    f.empty:SetText(T("Select a conversation, or type a name on the left to start a new whisper."))

    -- right: input ------------------------------------------------------------------
    f.send = UI.Button(f, "Send", 64, 28, function() SendInput() end, true)
    f.send:SetPoint("BOTTOMRIGHT", -12, 14)

    f.emoji = CreateFrame("Button", nil, f, "BackdropTemplate")
    f.emoji:SetSize(28, 28)
    f.emoji:SetPoint("RIGHT", f.send, "LEFT", -6, 0)
    UI.Flat(f.emoji, C.panel, C.border)
    f.emoji.tex = f.emoji:CreateTexture(nil, "ARTWORK")
    f.emoji.tex:SetPoint("TOPLEFT", 4, -4)
    f.emoji.tex:SetPoint("BOTTOMRIGHT", -4, 4)
    f.emoji.tex:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\emoji\\smile")
    f.emoji:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(ns:GetAccent()) end)
    f.emoji:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    UI.Tip(f.emoji, "Emoji")

    f.input = UI.Edit(f, 100, 28)
    f.input:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT", 12, 14)
    f.input:SetPoint("RIGHT", f.emoji, "LEFT", -6, 0)
    f.input:SetMaxLetters(255)
    f.input:SetScript("OnEnterPressed", function() SendInput() end)

    -- emoji picker (shared with the left panel)
    f.emoji:SetScript("OnClick", function(btn)
        ns.Chatbox:ShowPicker(btn, "BOTTOMRIGHT", "TOPRIGHT", 0, 6, function(code)
            f.input:Insert(code .. " ")
            f.input:SetFocus()
        end)
    end)

    -- resize grip
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(f:GetFrameLevel() + 20)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        o.ui.w, o.ui.h = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
    end)

    f:SetScript("OnShow", function() M:Refresh() end)
    f:SetScript("OnHide", function() ns.Chatbox:HidePicker() end)

    ns:OnTheme(function()
        f.top:SetColorTexture(ns:GetAccent())
        f.title:SetTextColor(ns:GetAccent())
        if frame then M:Refresh() end
    end)
    return f
end

---------------------------------------------------------------------------
-- Module hooks
---------------------------------------------------------------------------
local EVENTS = {
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
}

-- Whispers that the messenger shows are removed from the chat window.
local function HideFilter(self, event, msg, author)
    local o = DB()
    if not (o.enabled and o.hideInChat) then return false end
    if type(msg) ~= "string" or issecret(msg) then return false end
    if author ~= nil and issecret(author) then return false end
    if event:find("BN_", 1, true) and not o.bnet then return false end
    return true
end

-- "Whisper" menu entries and the reply key open the chat box; swap it for the messenger.
local function Takeover()
    local o = DB()
    if not (o.enabled and o.takeover) then return end
    local get = ns.ChatFn("ChatEdit_GetActiveWindow")
    local eb = get and get()
    if not eb or not eb:IsShown() then return end
    local kind = eb:GetAttribute("chatType")
    local target = eb:GetAttribute("tellTarget")
    if type(target) ~= "string" or target == "" or issecret(target) then return end
    local off = ns.ChatFn("ChatEdit_DeactivateChat")
    if kind == "WHISPER" then
        if off then off(eb) end
        M:OpenWhisper(target)
    elseif kind == "BN_WHISPER" and o.bnet then
        local id = FindBNByName(target)
        if id then
            if off then off(eb) end
            M:OpenBN(id)
        end
    end
end

local function HookTell(short, fn)
    local util = _G.ChatFrameUtil
    if util and type(util[short]) == "function" then hooksecurefunc(util, short, fn) end
    local g = "ChatFrame_" .. short
    if type(_G[g]) == "function" then hooksecurefunc(g, fn) end
end

function M:OnInit()
    StaticPopupDialogs["ZTVCHAT_DELCONV"] = {
        text = T("Delete the conversation with %s?"),
        button1 = YES, button2 = NO,
        OnAccept = function(_, data) M:Delete(data) end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["ZTVCHAT_CLEARALL"] = {
        text = T("Delete all saved conversations? Favorites are kept."),
        button1 = YES, button2 = NO,
        OnAccept = function() M:ClearAll() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    local ev = CreateFrame("Frame")
    for _, e in ipairs(EVENTS) do ev:RegisterEvent(e) end
    ev:RegisterEvent("PLAYER_LOGOUT")
    ev:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_LOGOUT" then
            if DB().retention == 0 then
                local h = DB().history
                for k, c in pairs(h) do if not c.fav then h[k] = nil end end
            end
            return
        end
        local msg, author = ...
        local guid, bnID = select(12, ...), select(13, ...)
        xpcall(M.OnMessage, geterrorhandler(), M, event, msg, author, guid, bnID)
    end)
    for _, e in ipairs(EVENTS) do ns.AddChatFilter(e, HideFilter) end

    local ign = CreateFrame("Frame")
    ign:RegisterEvent("IGNORELIST_UPDATE")
    local refresh = ns.Debounce(function() M:Refresh() end, 0.2)
    ign:SetScript("OnEvent", function() refresh() end)

    local take = ns.Debounce(Takeover, 0)
    for _, name in ipairs({ "SendTell", "ReplyTell", "ReplyTell2", "SendBNetTell" }) do HookTell(name, take) end

    SLASH_ZTVMSGR1 = "/messenger"
    SLASH_ZTVMSGR2 = "/msgr"
    SlashCmdList["ZTVMSGR"] = function(msg)
        msg = (msg or ""):match("^%s*(.-)%s*$")
        if msg == "" then M:Toggle() else M:OpenWhisper(msg) end
    end
end

function M:OnLogin()
    self:Prune()
    refreshBar()
end
