local ADDON, ns = ...
local UI = ns.UI
local C = UI.C
local Bar = ns.Bar
local T = ns.T

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
local ROW_H = 26
local MAX_ROWS = 10

---------------------------------------------------------------------------
-- Channel data
---------------------------------------------------------------------------
local function IsBuiltin(name)
    for _, b in ipairs(Bar.BOGUS or {}) do
        if name:find(b, 1, true) then return true end
    end
    return false
end

-- Names of the channels shown in the main chat window, or nil when the game
-- does not tell (zone channels are stored by id, so we never guess for those).
local function Collect(...)
    local out = {}
    for i = 1, select("#", ...), 2 do
        local name = select(i, ...)
        if name == nil then return nil end
        out[#out + 1] = name
    end
    return out
end

local function DisplayedNames()
    if not _G.GetChatWindowChannels then return nil end
    local ok, names = pcall(function() return Collect(GetChatWindowChannels(1)) end)
    if ok and names and #names > 0 then return names end
end

local function ShownInChat(name, names)
    if not names or IsBuiltin(name) then return true end
    local l = name:lower()
    for _, n in ipairs(names) do
        local nl = n:lower()
        if l:find(nl, 1, true) or nl:find(l, 1, true) then return true end
    end
    return false
end

-- Channels you are in: { n = number, name = full name, shown = visible in chat window }
function Bar:ChannelList()
    local names = DisplayedNames()
    local out = {}
    for i = 1, 10 do
        local num, name = GetChannelName(i)
        if num and num ~= 0 and type(name) == "string" then
            out[#out + 1] = { n = num, name = name, shown = ShownInChat(name, names) }
        end
    end
    return out
end

function Bar:HasChannels()
    for i = 1, 10 do
        local num = GetChannelName(i)
        if num and num ~= 0 then return true end
    end
    return false
end

-- true when you are in the channel but it is switched off in the chat window
function Bar:ChannelHidden(n)
    for _, c in ipairs(self:ChannelList()) do
        if c.n == n then return not c.shown end
    end
    return false
end

---------------------------------------------------------------------------
-- Button label, switching
---------------------------------------------------------------------------
local lastChannel

function Bar:ChannelLabel(long)
    local key = self.ActiveKey and self.ActiveKey()
    local n = key and key:match("^CHANNEL(%d+)$")
    if n then
        lastChannel = tonumber(n)
        return long and ("#" .. n) or n
    end
    return long and T("Channels") or "#"
end

function Bar:SelectChannel(n)
    lastChannel = n
    local open = ns.ChatFn("ChatFrame_OpenChat")
    if open then open("/" .. n .. " ", SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME) end
    if self.RefreshActive then self:RefreshActive() end
end

function Bar:WriteInLastChannel()
    local list = self:ChannelList()
    if #list == 0 then return end
    local pick
    for _, c in ipairs(list) do if c.n == lastChannel then pick = c end end
    self:SelectChannel((pick or list[1]).n)
end

-- mouse wheel: previous / next channel you are in
function Bar:CycleChannel(dir)
    local list = self:ChannelList()
    if #list == 0 then return end
    local key = self.ActiveKey and self.ActiveKey()
    local cur = tonumber(key and key:match("^CHANNEL(%d+)$")) or lastChannel
    local idx = 0
    for i, c in ipairs(list) do if c.n == cur then idx = i end end
    idx = idx + (dir < 0 and 1 or -1)          -- wheel down = next
    if idx < 1 then idx = #list elseif idx > #list then idx = 1 end
    self:SelectChannel(list[idx].n)
end

---------------------------------------------------------------------------
-- The menu
---------------------------------------------------------------------------
local menu, catcher
local rows = {}

local function ToggleDisplay(c)
    local fn = ns.ChatFn(c.shown and "ChatFrame_RemoveChannel" or "ChatFrame_AddChannel")
    if fn then
        pcall(fn, DEFAULT_CHAT_FRAME, c.name)
        C_Timer.After(0.15, function() if menu and menu:IsShown() then Bar:FillChannelMenu() end Bar:RefreshActive() end)
    else
        ns:Print("This action is not available on this client version.")
    end
end

local function GetRow(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, menu)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * ROW_H)
    r:SetPoint("TOPRIGHT", -6, -6 - (i - 1) * ROW_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, 0)
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetTexture(MEDIA .. "circle")
    r.dot:SetSize(10, 10)
    r.dot:SetPoint("LEFT", 8, 0)
    r.num = UI.Text(r, 12)
    r.num:SetPoint("LEFT", 26, 0)
    r.num:SetWidth(22)
    r.num:SetJustifyH("LEFT")
    r.name = UI.Text(r, 12)
    r.name:SetPoint("LEFT", 50, 0)
    r.name:SetPoint("RIGHT", -8, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(1, 1, 1, 0.08)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.c.name, 1, 1, 1)
        GameTooltip:AddLine(self.c.shown and T("Shown in the chat window") or T("Hidden in the chat window"),
            self.c.shown and 0.4 or 1, self.c.shown and 1 or 0.7, self.c.shown and 0.5 or 0.2)
        GameTooltip:AddLine(T("Click: write in this channel"), 0.6, 0.6, 0.65)
        GameTooltip:AddLine(T("Right-click: show / hide it in the chat window"), 0.6, 0.6, 0.65)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function(self) self.bg:SetColorTexture(1, 1, 1, 0); GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ToggleDisplay(self.c)
        else
            menu:Hide()
            Bar:SelectChannel(self.c.n)
        end
    end)
    rows[i] = r
    return r
end

function Bar:FillChannelMenu()
    local list = self:ChannelList()
    local key = self.ActiveKey and self.ActiveKey()
    local cur = tonumber(key and key:match("^CHANNEL(%d+)$"))
    local ar, ag, ab = ns:GetAccent()
    for i, c in ipairs(list) do
        if i > MAX_ROWS then break end
        local r = GetRow(i)
        r.c = c
        r.num:SetText(c.n .. ".")
        r.name:SetText(c.name)
        if c.shown then
            r.dot:SetVertexColor(0.3, 0.95, 0.45)
            r.num:SetTextColor(1, 1, 1)
            r.name:SetTextColor(unpack(C.text))
        else
            r.dot:SetVertexColor(1, 0.65, 0.2)
            r.num:SetTextColor(0.6, 0.6, 0.65)
            r.name:SetTextColor(0.55, 0.55, 0.6)
        end
        if cur == c.n then r.name:SetTextColor(ar, ag, ab) end
        r:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    local n = math.min(#list, MAX_ROWS)
    menu.empty:SetShown(n == 0)
    menu:SetHeight(12 + math.max(1, n) * ROW_H + 30)
end

local function BuildMenu()
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:Hide()

    menu = CreateFrame("Frame", "ZamestoTVChannelMenu", UIParent, "BackdropTemplate")
    menu:SetWidth(250)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    UI.Flat(menu, C.bg, C.border)
    menu:Hide()
    tinsert(UISpecialFrames, "ZamestoTVChannelMenu")
    catcher:SetScript("OnClick", function() menu:Hide() end)
    menu:SetScript("OnHide", function() catcher:Hide() end)

    menu.empty = UI.Text(menu, 11, C.muted)
    menu.empty:SetPoint("TOPLEFT", 14, -14)
    menu.empty:SetText(T("You are not in any channel."))
    menu.empty:Hide()

    local legend = UI.Text(menu, 10, C.muted)
    legend:SetPoint("BOTTOMLEFT", 12, 8)
    legend:SetPoint("BOTTOMRIGHT", -12, 8)
    legend:SetJustifyH("LEFT")
    legend:SetText("|cff4de673●|r " .. T("shown") .. "   |cffffa633●|r " .. T("hidden in chat"))
end

function Bar:ToggleChannelMenu(anchor)
    if not menu then BuildMenu() end
    if menu:IsShown() then menu:Hide() return end
    self:FillChannelMenu()
    menu:ClearAllPoints()
    local _, y = anchor:GetCenter()
    local half = UIParent:GetHeight() * UIParent:GetEffectiveScale() / 2
    if y and y * anchor:GetEffectiveScale() < half then
        menu:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 6)
    else
        menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    end
    catcher:Show()
    menu:Show()
end

-- keep labels / dimming up to date when channels or their display change
local ev = CreateFrame("Frame")
for _, e in ipairs({ "CHANNEL_UI_UPDATE", "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER" }) do
    ev:RegisterEvent(e)
end
local refresh = ns.Debounce(function()
    if menu and menu:IsShown() then Bar:FillChannelMenu() end
    if Bar.RefreshActive and Bar.frame then Bar:RefreshActive() end
end, 0.3)
ev:SetScript("OnEvent", function() refresh() end)
