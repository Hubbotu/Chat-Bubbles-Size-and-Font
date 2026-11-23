local ADDON, ns = ...
local UI = ns.UI
local C = UI.C
local T = ns.T
local A = ns:NewModule("Avatars")

local DIR = "Interface\\AddOns\\" .. ADDON .. "\\avatars\\"
A.COUNT = 11

-- ids are 1..COUNT; nil means "no custom avatar" (class icon or letter is used)
function A:Path(id)
    if type(id) == "number" and id >= 1 and id <= self.COUNT then
        return DIR .. string.format("avatar%02d", id)
    end
end

-- puts avatar `id` on a texture; returns false when there is none
function A:Apply(tex, id)
    local path = self:Path(id)
    if not path then return false end
    tex:SetTexture(path)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetVertexColor(1, 1, 1)
    return true
end

---------------------------------------------------------------------------
-- Picker: a grid of all avatars, click one to choose it
---------------------------------------------------------------------------
local COLS, CELL = 4, 76
local picker, catcher
local state = { onPick = nil }

local function Refresh(current)
    local ar, ag, ab = ns:GetAccent()
    for i, b in ipairs(picker.cells) do
        local on = (current == i)
        b.ring:SetShown(on)
        b.ring:SetVertexColor(ar, ag, ab)
    end
    picker.none.ring:SetShown(current == nil)
end

local function Build()
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:Hide()

    local rows = math.ceil(A.COUNT / COLS)
    picker = CreateFrame("Frame", "ZamestoTVAvatarPicker", UIParent, "BackdropTemplate")
    picker:SetSize(COLS * CELL + 24, 44 + rows * CELL + 52)
    picker:SetPoint("CENTER", 0, 20)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    UI.Flat(picker, C.bg, C.border)
    picker:Hide()
    tinsert(UISpecialFrames, "ZamestoTVAvatarPicker")
    catcher:SetScript("OnClick", function() picker:Hide() end)
    picker:SetScript("OnHide", function() catcher:Hide() end)

    picker.title = UI.Text(picker, 13)
    picker.title:SetPoint("TOPLEFT", 14, -14)
    picker.title:SetText(T("Choose an avatar"))
    ns:OnTheme(function() picker.title:SetTextColor(ns:GetAccent()) end)

    picker.cells = {}
    for i = 1, A.COUNT do
        local b = CreateFrame("Button", nil, picker)
        b:SetSize(CELL - 6, CELL - 6)
        b:SetPoint("TOPLEFT", 12 + ((i - 1) % COLS) * CELL, -40 - math.floor((i - 1) / COLS) * CELL)
        b.ring = b:CreateTexture(nil, "BACKGROUND")
        b.ring:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\media\\circle")
        b.ring:SetPoint("TOPLEFT", -3, 3)
        b.ring:SetPoint("BOTTOMRIGHT", 3, -3)
        b.ring:Hide()
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        A:Apply(b.tex, i)
        b.hl = b:CreateTexture(nil, "OVERLAY")
        b.hl:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\media\\circle")
        b.hl:SetAllPoints()
        b.hl:SetVertexColor(1, 1, 1, 0.18)
        b.hl:Hide()
        b:SetScript("OnEnter", function(self) self.hl:Show() end)
        b:SetScript("OnLeave", function(self) self.hl:Hide() end)
        b:SetScript("OnClick", function()
            local fn = state.onPick
            picker:Hide()
            if fn then fn(i) end
        end)
        picker.cells[i] = b
    end

    -- "no avatar": go back to the class icon / letter
    local none = UI.Button(picker, "Use the default icon", 170, 26, function()
        local fn = state.onPick
        picker:Hide()
        if fn then fn(nil) end
    end)
    none:SetPoint("BOTTOMLEFT", 12, 12)
    none.ring = none:CreateTexture(nil, "OVERLAY")
    none.ring:Hide()
    picker.none = none

    local close = UI.Button(picker, "Close", 80, 26, function() picker:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -12, 12)
end

-- current: id in use (or nil); onPick(id or nil) is called when the user chooses
function A:Pick(current, onPick)
    if not picker then Build() end
    state.onPick = onPick
    Refresh(current)
    catcher:Show()
    picker:Show()
end
