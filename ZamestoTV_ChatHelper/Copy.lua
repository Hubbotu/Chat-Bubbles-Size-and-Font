local ADDON, ns = ...
local UI = ns.UI
local C = UI.C
local Copy = ns:NewModule("Copy")
local issecret = ns.IsSecret

local frame
local state = { tab = 1, lines = {}, hidden = 0, search = "" }

local function Clean(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    s = s:gsub("|H.-|h(.-)|h", "%1")
    s = s:gsub("|T.-|t", "")
    s = s:gsub("|A.-|a", "")
    s = s:gsub("||", "|")
    return s
end

-- Collect every stored line of one chat tab. Lines the client marks as
-- restricted (instances / encounters) are counted instead of copied.
local function Collect(index)
    local cf = _G["ChatFrame" .. index]
    local out, hidden = {}, 0
    if not cf then return out, 0 end

    pcall(function()
        for i = 1, cf:GetNumMessages() do
            local text = cf:GetMessageInfo(i)
            if text == nil or issecret(text) then
                hidden = hidden + 1
            else
                out[#out + 1] = text
            end
        end
    end)

    if #out == 0 and cf.visibleLines then
        pcall(function()
            for i = #cf.visibleLines, 1, -1 do
                local line = cf.visibleLines[i]
                local m = line and line.messageInfo and line.messageInfo.message
                if m and not issecret(m) then out[#out + 1] = m end
            end
        end)
    end
    return out, hidden
end

local function Render()
    if not frame then return end
    local strip = ns.db.copy.strip
    local needle = state.search:lower()
    local parts = {}
    for _, line in ipairs(state.lines) do
        local text = strip and Clean(line) or line
        if needle == "" or text:lower():find(needle, 1, true) then
            parts[#parts + 1] = text
        end
    end
    local body = table.concat(parts, "\n")
    if #parts == 0 and #state.lines == 0 then
        body = (state.hidden > 0)
            and "Chat is restricted right now (instance or encounter), so these lines can't be copied."
            or ""
    end
    frame.edit:SetText(body)
    local info = #parts .. " lines"
    if state.hidden > 0 then info = info .. "  |  " .. state.hidden .. " restricted" end
    frame.info:SetText(info)
    C_Timer.After(0, function()
        frame.scroll:SetVerticalScroll(frame.scroll:GetVerticalScrollRange())
    end)
end

local function TabItems()
    local items = {}
    for i = 1, NUM_CHAT_WINDOWS do
        local name, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(i)
        if name and name ~= "" and (shown or docked) then
            items[#items + 1] = { text = name, value = i }
        end
    end
    if #items == 0 then items[1] = { text = "General", value = 1 } end
    return items
end

local function Build()
    local f = CreateFrame("Frame", "ZamestoTVChatCopy", UIParent, "BackdropTemplate")
    f:SetSize(720, 460)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetResizeBounds then f:SetResizeBounds(520, 280, 1400, 1000) end
    UI.Flat(f, C.bg, C.border)
    tinsert(UISpecialFrames, "ZamestoTVChatCopy")

    f.top = f:CreateTexture(nil, "OVERLAY")
    f.top:SetPoint("TOPLEFT", 1, -1)
    f.top:SetPoint("TOPRIGHT", -1, -1)
    f.top:SetHeight(2)

    f.title = UI.Text(f, 14)
    f.title:SetPoint("TOPLEFT", 16, -14)
    f.title:SetText("Copy Chat")

    f.tabs = UI.Dropdown(f, 150, TabItems,
        function() return state.tab end,
        function(v) state.tab = v; Copy:Open("replace") end)
    f.tabs:SetPoint("TOPLEFT", 120, -10)

    f.search = UI.Edit(f, 170, 24)
    f.search:SetPoint("TOPLEFT", f.tabs, "TOPRIGHT", 10, 0)
    f.search:SetScript("OnTextChanged", function(self)
        state.search = self:GetText()
        Render()
    end)
    f.searchHint = UI.Text(f.search, 11, C.muted)
    f.searchHint:SetPoint("LEFT", 8, 0)
    f.searchHint:SetText("Search...")
    f.search:HookScript("OnTextChanged", function(self) f.searchHint:SetShown(self:GetText() == "") end)

    f.close = CreateFrame("Button", nil, f)
    f.close:SetSize(28, 28)
    f.close:SetPoint("TOPRIGHT", -8, -8)
    f.close.text = UI.Text(f.close, 18, C.muted)
    f.close.text:SetPoint("CENTER", 0, 1)
    f.close.text:SetText("×")
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.close:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.35, 0.35) end)
    f.close:SetScript("OnLeave", function(self) self.text:SetTextColor(unpack(C.muted)) end)

    -- Text area
    f.body = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.body:SetPoint("TOPLEFT", 14, -46)
    f.body:SetPoint("BOTTOMRIGHT", -14, 50)
    UI.Flat(f.body, C.field, C.border)

    f.scroll = CreateFrame("ScrollFrame", nil, f.body)
    f.scroll:SetPoint("TOPLEFT", 8, -8)
    f.scroll:SetPoint("BOTTOMRIGHT", -8, 8)
    f.scroll:EnableMouseWheel(true)
    f.scroll:SetScript("OnMouseWheel", function(self, d)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - d * 40)))
    end)

    f.edit = CreateFrame("EditBox", nil, f.scroll)
    f.edit:SetMultiLine(true)
    f.edit:SetAutoFocus(false)
    f.edit:SetFontObject(ChatFontNormal)
    f.edit:SetWidth(660)
    f.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.scroll:SetScrollChild(f.edit)

    -- Footer
    local function Foot(label, w, fn)
        local b = UI.Button(f, label, w, 26, fn)
        return b
    end
    f.refresh = Foot("Refresh", 80, function() Copy:Open("replace") end)
    f.refresh:SetPoint("BOTTOMLEFT", 14, 14)
    f.add = Foot("Add tab", 80, function() Copy:Open("add") end)
    f.add:SetPoint("LEFT", f.refresh, "RIGHT", 6, 0)
    f.clear = Foot("Clear", 70, function() Copy:Open("clear") end)
    f.clear:SetPoint("LEFT", f.add, "RIGHT", 6, 0)
    f.select = Foot("Select all", 90, function()
        f.edit:SetFocus()
        f.edit:HighlightText()
    end, true)
    f.select:SetPoint("LEFT", f.clear, "RIGHT", 6, 0)

    f.strip = UI.Check(f, "Strip colors & links",
        function() return ns.db.copy.strip end,
        function(v) ns.db.copy.strip = v; Render() end, nil, nil, 170)
    f.strip:SetPoint("LEFT", f.select, "RIGHT", 16, 0)

    f.info = UI.Text(f, 11, C.muted)
    f.info:SetPoint("BOTTOMRIGHT", -34, 20)
    f.info:SetJustifyH("RIGHT")

    -- Resize grip
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)
    f:SetScript("OnSizeChanged", function(self, w) self.edit:SetWidth(math.max(100, w - 56)) end)

    ns:OnTheme(function()
        f.top:SetColorTexture(ns:GetAccent())
        f.title:SetTextColor(ns:GetAccent())
    end)
    return f
end

-- mode: nil/"replace" = reload from the selected tab, "add" = append,
--       "clear" = empty, "show" = just open the window as it is
function Copy:Open(mode)
    if not frame then
        frame = Build()
        frame.tabs:Refresh()
    end
    frame:Show()
    if mode == "show" then return end

    if mode == "clear" then
        state.lines, state.hidden = {}, 0
    else
        local lines, hidden = Collect(state.tab)
        if mode == "add" then
            for _, l in ipairs(lines) do state.lines[#state.lines + 1] = l end
            state.hidden = state.hidden + hidden
        else
            state.lines, state.hidden = lines, hidden
        end
    end
    frame.tabs:Refresh()
    Render()
    if mode ~= "clear" then
        frame.edit:SetFocus()
        frame.edit:HighlightText()
    end
end

function Copy:Toggle()
    if frame and frame:IsShown() then frame:Hide() else self:Open() end
end

function Copy:OnInit()
    SLASH_ZTVCOPY1 = "/copy"
    SlashCmdList["ZTVCOPY"] = function(msg)
        msg = (msg or ""):upper()
        if msg == "ADD" then Copy:Open("add")
        elseif msg == "CLEAR" then Copy:Open("clear")
        elseif msg == "SHOW" then Copy:Open("show")
        else Copy:Open("replace") end
    end
end
