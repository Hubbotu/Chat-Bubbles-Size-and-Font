local ADDON, ns = ...
local UI = {}
ns.UI = UI

local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT

local C = {
    bg     = { 0.055, 0.058, 0.075, 0.98 },
    side   = { 0.075, 0.080, 0.100, 1 },
    panel  = { 0.115, 0.120, 0.150, 1 },
    field  = { 0.045, 0.048, 0.060, 1 },
    border = { 1, 1, 1, 0.09 },
    text   = { 0.92, 0.93, 0.96 },
    muted  = { 0.58, 0.60, 0.67 },
}
UI.C = C

---------------------------------------------------------------------------
-- Basics
---------------------------------------------------------------------------
function UI.Flat(f, bg, border)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(unpack(bg))
    f:SetBackdropBorderColor(unpack(border or C.border))
end

function UI.Text(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(FONT, size or 12, "")
    fs:SetTextColor(unpack(color or C.text))
    fs:SetJustifyH("LEFT")
    return fs
end

function UI.Tip(f, title, text)
    if not title then return end
    f:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if text then GameTooltip:AddLine(text, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    f:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

function UI.Header(parent, text, width)
    local h = CreateFrame("Frame", nil, parent)
    h:SetSize(width or 500, 24)
    h.label = UI.Text(h, 12)
    h.label:SetPoint("TOPLEFT", 0, 0)
    h.label:SetText(text)
    h.line = h:CreateTexture(nil, "ARTWORK")
    h.line:SetColorTexture(1, 1, 1, 0.08)
    h.line:SetPoint("BOTTOMLEFT", 0, 2)
    h.line:SetPoint("BOTTOMRIGHT", 0, 2)
    h.line:SetHeight(1)
    ns:OnTheme(function() h.label:SetTextColor(ns:GetAccent()) end)
    return h
end

-- Vertical layout helper. Widgets are anchored on both sides, so they
-- stretch when the window is resized. side: "L" (left column),
-- "R" (right column) or "F" (full width).
function UI.Stack(parent, side, y)
    local s = { side = side, y = y }
    function s:Add(w, gap)
        w:ClearAllPoints()
        if self.side == "L" then
            w:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -self.y)
            w:SetPoint("TOPRIGHT", parent, "TOP", -12, -self.y)
        elseif self.side == "R" then
            w:SetPoint("TOPLEFT", parent, "TOP", 12, -self.y)
            w:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -24, -self.y)
        else
            w:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -self.y)
            w:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -24, -self.y)
        end
        self.y = self.y + (w:GetHeight() or 0) + (gap or 8)
        return w
    end
    return s
end

---------------------------------------------------------------------------
-- Button
---------------------------------------------------------------------------
function UI.Button(parent, label, w, h, onClick, primary)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    b.text = UI.Text(b, 12)
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    b.primary = primary

    local function Paint()
        local r, g, bl = ns:GetAccent()
        if b.hover then
            UI.Flat(b, { r, g, bl, primary and 0.95 or 0.22 }, { r, g, bl, 1 })
        elseif primary then
            UI.Flat(b, { r, g, bl, 0.75 }, { r, g, bl, 1 })
        else
            UI.Flat(b, C.panel, C.border)
        end
    end
    b:SetScript("OnEnter", function() b.hover = true; Paint() end)
    b:SetScript("OnLeave", function() b.hover = false; Paint() end)
    b:SetScript("OnClick", function(self, ...) if onClick then onClick(self, ...) end end)
    ns:OnTheme(Paint)
    Paint()
    function b:SetLabel(t) self.text:SetText(t) end
    return b
end

---------------------------------------------------------------------------
-- Checkbox
---------------------------------------------------------------------------
function UI.Check(parent, label, getter, setter, tipTitle, tipText, width)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(width or 240, 22)
    c.box = CreateFrame("Frame", nil, c, "BackdropTemplate")
    c.box:SetSize(16, 16)
    c.box:SetPoint("LEFT", 0, 0)
    UI.Flat(c.box, C.field, C.border)
    c.tick = c.box:CreateTexture(nil, "OVERLAY")
    c.tick:SetPoint("TOPLEFT", 3, -3)
    c.tick:SetPoint("BOTTOMRIGHT", -3, 3)
    c.label = UI.Text(c, 12)
    c.label:SetPoint("LEFT", c.box, "RIGHT", 8, 0)
    c.label:SetPoint("RIGHT", 0, 0)
    c.label:SetWordWrap(false)
    c.label:SetText(label)

    function c:Refresh() self.tick:SetShown(getter() and true or false) end
    c:SetScript("OnClick", function(self) setter(not getter()); self:Refresh() end)
    c:SetScript("OnEnter", function(self)
        local r, g, b = ns:GetAccent()
        self.box:SetBackdropBorderColor(r, g, b, 1)
    end)
    c:SetScript("OnLeave", function(self) self.box:SetBackdropBorderColor(unpack(C.border)) end)
    UI.Tip(c, tipTitle, tipText)
    ns:OnTheme(function() c.tick:SetColorTexture(ns:GetAccent()) end)
    c:Refresh()
    return c
end

---------------------------------------------------------------------------
-- Slider
---------------------------------------------------------------------------
function UI.Slider(parent, label, minV, maxV, step, getter, setter, fmt, width)
    width = width or 240
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(width, 40)
    s.label = UI.Text(s, 11, C.muted)
    s.label:SetPoint("TOPLEFT", 0, 0)
    s.label:SetText(label)
    s.value = UI.Text(s, 11)
    s.value:SetPoint("TOPRIGHT", 0, 0)
    s.value:SetJustifyH("RIGHT")

    local sl = CreateFrame("Slider", nil, s, "BackdropTemplate")
    sl:SetOrientation("HORIZONTAL")
    sl:SetHeight(10)
    sl:SetPoint("BOTTOMLEFT", 0, 6)
    sl:SetPoint("BOTTOMRIGHT", 0, 6)
    UI.Flat(sl, C.field, C.border)
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    sl:SetObeyStepOnDrag(true)
    sl:SetThumbTexture(WHITE)
    local thumb = sl:GetThumbTexture()
    thumb:SetSize(8, 16)
    sl.fill = sl:CreateTexture(nil, "ARTWORK")
    sl.fill:SetPoint("TOPLEFT", 1, -1)
    sl.fill:SetPoint("BOTTOMLEFT", 1, 1)

    local refreshing = false
    local cur = minV
    local function Paint(v)
        cur = v
        s.value:SetText(fmt and fmt(v) or tostring(v))
        local frac = (maxV > minV) and ((v - minV) / (maxV - minV)) or 0
        local w = sl:GetWidth()
        if not w or w < 10 then w = width end
        sl.fill:SetWidth(math.max(1, (w - 2) * frac))
    end
    sl:SetScript("OnSizeChanged", function() Paint(cur) end)
    sl:SetScript("OnValueChanged", function(self, v)
        if refreshing then return end
        v = math.floor(v / step + 0.5) * step
        Paint(v)
        setter(v)
    end)
    ns:OnTheme(function()
        local r, g, b = ns:GetAccent()
        sl.fill:SetColorTexture(r, g, b, 0.55)
        thumb:SetColorTexture(r, g, b, 1)
    end)
    function s:Refresh()
        refreshing = true
        local v = getter()
        sl:SetValue(v)
        Paint(v)
        refreshing = false
    end
    s.slider = sl
    s:Refresh()
    return s
end

---------------------------------------------------------------------------
-- Dropdown (shared popup)
---------------------------------------------------------------------------
local popup
local ROWH, MAXROWS = 22, 10

local function GetPopup()
    if popup then return popup end
    popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetFrameStrata("TOOLTIP")
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:EnableMouseWheel(true)
    popup:Hide()
    UI.Flat(popup, C.field, C.border)
    popup.rows = {}

    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:Hide()
    catcher:SetScript("OnClick", function() popup:Hide() end)
    popup:SetScript("OnShow", function() catcher:Show() end)
    popup:SetScript("OnHide", function() catcher:Hide() end)
    popup:SetScript("OnMouseWheel", function(self, d)
        self.offset = math.max(0, math.min(self.maxOffset, self.offset - d))
        self:Render()
    end)

    function popup:Open(owner, items, current, onSelect)
        self.owner, self.items, self.current, self.onSelect = owner, items, current, onSelect
        self.offset = 0
        local n = #items
        self.shown = math.min(n, MAXROWS)
        self.maxOffset = math.max(0, n - self.shown)
        self:SetSize(owner:GetWidth(), self.shown * ROWH + 2)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
        self:Render()
        self:Show()
    end

    function popup:Render()
        for i = 1, self.shown do
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Button", nil, self)
                row:SetHeight(ROWH)
                row:SetPoint("TOPLEFT", 1, -1 - (i - 1) * ROWH)
                row:SetPoint("TOPRIGHT", -1, -1 - (i - 1) * ROWH)
                row.hl = row:CreateTexture(nil, "BACKGROUND")
                row.hl:SetAllPoints()
                row.hl:Hide()
                row.sel = row:CreateTexture(nil, "ARTWORK")
                row.sel:SetPoint("TOPLEFT")
                row.sel:SetPoint("BOTTOMLEFT")
                row.sel:SetWidth(3)
                row.text = UI.Text(row, 12)
                row.text:SetPoint("LEFT", 10, 0)
                row.text:SetPoint("RIGHT", -6, 0)
                row.text:SetWordWrap(false)
                row:SetScript("OnEnter", function(r) r.hl:Show() end)
                row:SetScript("OnLeave", function(r) r.hl:Hide() end)
                row:SetScript("OnClick", function(r)
                    local cb, it = popup.onSelect, r.item
                    popup:Hide()
                    if cb and it then cb(it) end
                end)
                self.rows[i] = row
            end
            local it = self.items[i + self.offset]
            row.item = it
            row.text:SetText(it.text)
            local r, g, b = ns:GetAccent()
            row.hl:SetColorTexture(r, g, b, 0.22)
            row.sel:SetColorTexture(r, g, b, 1)
            row.sel:SetShown(it.value == self.current)
            row:Show()
        end
        for i = self.shown + 1, #self.rows do self.rows[i]:Hide() end
    end
    return popup
end

function UI.Dropdown(parent, width, items, getter, setter)
    local d = CreateFrame("Button", nil, parent, "BackdropTemplate")
    d:SetSize(width, 24)
    UI.Flat(d, C.field, C.border)
    d.text = UI.Text(d, 12)
    d.text:SetPoint("LEFT", 8, 0)
    d.text:SetPoint("RIGHT", -22, 0)
    d.text:SetWordWrap(false)
    d.arrow = d:CreateTexture(nil, "OVERLAY")
    d.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    d.arrow:SetSize(10, 10)
    d.arrow:SetPoint("RIGHT", -7, 0)
    d.arrow:SetRotation(-math.pi / 2)
    d.arrow:SetVertexColor(unpack(C.muted))

    local function GetItems() return type(items) == "function" and items() or items end

    function d:Refresh()
        local v = getter()
        local label = tostring(v)
        for _, it in ipairs(GetItems()) do
            if it.value == v then label = it.text break end
        end
        self.text:SetText(label)
    end
    d:SetScript("OnClick", function(self)
        local p = GetPopup()
        if p:IsShown() and p.owner == self then p:Hide() return end
        p:Open(self, GetItems(), getter(), function(it)
            setter(it.value, it)
            self:Refresh()
        end)
    end)
    d:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(ns:GetAccent()) end)
    d:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    d:Refresh()
    return d
end

---------------------------------------------------------------------------
-- Edit boxes
---------------------------------------------------------------------------
function UI.Edit(parent, w, h, onEnter)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetSize(w, h or 24)
    e:SetAutoFocus(false)
    e:SetFont(FONT, 12, "")
    e:SetTextColor(unpack(C.text))
    e:SetTextInsets(8, 8, 0, 0)
    UI.Flat(e, C.field, C.border)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self)
        if onEnter then onEnter(self) end
        self:ClearFocus()
    end)
    e:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(ns:GetAccent()) end)
    e:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    return e
end

function UI.MultiEdit(parent, w, h, onChange)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(w, h)
    box:EnableMouse(true)
    UI.Flat(box, C.field, C.border)

    local sf = CreateFrame("ScrollFrame", nil, box)
    sf:SetPoint("TOPLEFT", 8, -8)
    sf:SetPoint("BOTTOMRIGHT", -8, 8)
    sf:EnableMouseWheel(true)

    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFont(FONT, 12, "")
    eb:SetTextColor(unpack(C.text))
    eb:SetWidth(w - 16)
    sf:SetScrollChild(eb)
    sf:SetScript("OnSizeChanged", function(_, nw) eb:SetWidth(math.max(20, nw)) end)

    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnTextChanged", function(self, user)
        if user and onChange then onChange(self:GetText()) end
    end)
    eb:SetScript("OnCursorChanged", function(self, x, y, cw, ch)
        local top = sf:GetVerticalScroll()
        local height = sf:GetHeight()
        y = -y
        if y < top then
            sf:SetVerticalScroll(y)
        elseif y + ch > top + height then
            sf:SetVerticalScroll(y + ch - height)
        end
    end)
    eb:SetScript("OnEditFocusGained", function() box:SetBackdropBorderColor(ns:GetAccent()) end)
    eb:SetScript("OnEditFocusLost", function() box:SetBackdropBorderColor(unpack(C.border)) end)
    sf:SetScript("OnMouseWheel", function(self, d)
        local range = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - d * 24)))
    end)
    box:SetScript("OnMouseDown", function() eb:SetFocus() end)

    box.edit, box.scroll = eb, sf
    function box:SetValue(t) eb:SetText(t or "") end
    return box
end

---------------------------------------------------------------------------
-- Color picker
---------------------------------------------------------------------------
function UI.PickColor(r, g, b, onChange)
    local prev = { r, g, b }
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function() onChange(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function() onChange(prev[1], prev[2], prev[3]) end,
        })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.func = function() onChange(ColorPickerFrame:GetColorRGB()) end
        ColorPickerFrame.cancelFunc = function() onChange(prev[1], prev[2], prev[3]) end
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
end

function UI.Swatch(parent, size, getColor, onChange)
    local sw = CreateFrame("Button", nil, parent, "BackdropTemplate")
    sw:SetSize(size, size)
    UI.Flat(sw, { 0, 0, 0, 1 }, C.border)
    sw.tex = sw:CreateTexture(nil, "ARTWORK")
    sw.tex:SetPoint("TOPLEFT", 2, -2)
    sw.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    function sw:Refresh()
        local c = getColor()
        self.tex:SetColorTexture(c[1], c[2], c[3], 1)
    end
    sw:SetScript("OnClick", function(self)
        local c = getColor()
        UI.PickColor(c[1], c[2], c[3], function(r, g, b)
            onChange(r, g, b)
            self:Refresh()
        end)
    end)
    sw:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 1, 1, 0.8) end)
    sw:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    sw:Refresh()
    return sw
end
