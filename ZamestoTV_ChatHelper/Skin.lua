local ADDON, ns = ...
local UI = ns.UI
local Box = ns.Chatbox
local T = ns.T

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
Box.MEDIA = MEDIA

---------------------------------------------------------------------------
-- Nine-slice: corners keep their size, edges stretch. Lets one small
-- texture draw a rounded (or chamfered) shape at any frame size.
---------------------------------------------------------------------------
local Slice = {}
Slice.__index = Slice

local function NewSlice(parent, file, layer, sub, frac)
    local s = setmetatable({ parent = parent, p = {} }, Slice)
    local u = { 0, frac, 1 - frac, 1 }
    for row = 1, 3 do
        for col = 1, 3 do
            local t = parent:CreateTexture(nil, layer, nil, sub)
            t:SetTexture(file)
            t:SetTexCoord(u[col], u[col + 1], u[row], u[row + 1])
            s.p[(row - 1) * 3 + col] = t
        end
    end
    return s
end

-- l, t, r, b = insets from the parent's edges (negative = outside)
function Slice:Layout(corner, l, t, r, b)
    l = l or 0; t = t or l; r = r or l; b = b or t
    local P, par = self.p, self.parent
    for _, tex in ipairs(P) do tex:ClearAllPoints() end
    P[1]:SetPoint("TOPLEFT", par, "TOPLEFT", l, -t)
    P[3]:SetPoint("TOPRIGHT", par, "TOPRIGHT", -r, -t)
    P[7]:SetPoint("BOTTOMLEFT", par, "BOTTOMLEFT", l, b)
    P[9]:SetPoint("BOTTOMRIGHT", par, "BOTTOMRIGHT", -r, b)
    for _, i in ipairs({ 1, 3, 7, 9 }) do P[i]:SetSize(corner, corner) end
    P[2]:SetPoint("TOPLEFT", P[1], "TOPRIGHT");     P[2]:SetPoint("BOTTOMRIGHT", P[3], "BOTTOMLEFT")
    P[4]:SetPoint("TOPLEFT", P[1], "BOTTOMLEFT");   P[4]:SetPoint("BOTTOMRIGHT", P[7], "TOPRIGHT")
    P[5]:SetPoint("TOPLEFT", P[1], "BOTTOMRIGHT");  P[5]:SetPoint("BOTTOMRIGHT", P[9], "TOPLEFT")
    P[6]:SetPoint("TOPLEFT", P[3], "BOTTOMLEFT");   P[6]:SetPoint("BOTTOMRIGHT", P[9], "TOPRIGHT")
    P[8]:SetPoint("TOPLEFT", P[7], "TOPRIGHT");     P[8]:SetPoint("BOTTOMRIGHT", P[9], "BOTTOMLEFT")
end

Box.NewSlice = NewSlice

function Slice:SetFile(file, frac)
    local u = { 0, frac, 1 - frac, 1 }
    for row = 1, 3 do
        for col = 1, 3 do
            local t = self.p[(row - 1) * 3 + col]
            t:SetTexture(file)
            t:SetTexCoord(u[col], u[col + 1], u[row], u[row + 1])
        end
    end
end

function Slice:SetColor(r, g, b, a)
    for _, t in ipairs(self.p) do t:SetVertexColor(r, g, b, a) end
end

function Slice:SetShown(v)
    for _, t in ipairs(self.p) do t:SetShown(v) end
    if v and self.noCenter then self.p[5]:Hide() end
end

function Slice:SetBlend(mode)
    for _, t in ipairs(self.p) do t:SetBlendMode(mode) end
end

local function Gradient(tex, orient, r1, g1, b1, a1, r2, g2, b2, a2)
    if CreateColor and tex.SetGradient then
        if pcall(tex.SetGradient, tex, orient, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2)) then return end
    end
    if tex.SetGradientAlpha then
        tex:SetGradientAlpha(orient, r1, g1, b1, a1, r2, g2, b2, a2)
    else
        tex:SetVertexColor(r2, g2, b2, a2)
    end
end

-- top row colour t1/a1, bottom row t2/a2, stretched middle blends between them
function Slice:SetVGradient(t1, a1, t2, a2)
    local P = self.p
    for _, i in ipairs({ 1, 2, 3 }) do P[i]:SetVertexColor(t1[1], t1[2], t1[3], a1) end
    for _, i in ipairs({ 7, 8, 9 }) do P[i]:SetVertexColor(t2[1], t2[2], t2[3], a2) end
    for _, i in ipairs({ 4, 5, 6 }) do
        P[i]:SetVertexColor(1, 1, 1, 1)
        Gradient(P[i], "VERTICAL", t2[1], t2[2], t2[3], a2, t1[1], t1[2], t1[3], a1)
    end
end

---------------------------------------------------------------------------
-- Style recipes.  Every style is a stack of layers (fill, patterns, vignette,
-- shine, header band, rings, accent line, corner ornaments, Blizzard border,
-- glow), so switching styles changes the whole look, not only the color.
--   colors are "accent", "white" or { r, g, b }
---------------------------------------------------------------------------
local CYAN, MAGENTA = { 0.0, 0.95, 1.0 }, { 1.0, 0.12, 0.62 }
local GOLD, GREEN = { 1.0, 0.82, 0.35 }, { 0.25, 1.0, 0.35 }

local STYLES = {
    -- modern ------------------------------------------------------------------
    MODERN = {
        name = "Modern", color = { 0.055, 0.058, 0.075 }, shape = "round", radius = 12, lift = 0.05,
        ring = { "white", 0.14 }, shadow = 0.55,
        pat = { { "noise", 0.035, "ADD" } },
        shine = 0.05, header = { "white", 0.06 }, accentLine = { "top", "accent" },
        glow = { "accent", 0.30 }, edit = { 1, 1, 1, 0.18 },
    },
    AURORA = {
        name = "Aurora (gradient)", color = { 0.08, 0.18, 0.30 }, shape = "round", radius = 14,
        grad = { { 0.10, 0.34, 0.50 }, { 0.22, 0.08, 0.40 } },
        ring = { { 0.55, 0.95, 1.0 }, 0.30 }, shadow = 0.6,
        pat = { { "noise", 0.04, "ADD" } }, shine = 0.12,
        header = { { 0.6, 1.0, 1.0 }, 0.08 }, accentLine = { "top", { 0.55, 0.95, 1.0 } },
        glow = { { 0.45, 0.85, 1.0 }, 0.60 }, edit = { 0.55, 0.9, 1.0, 0.5 },
    },
    GLASS = {
        name = "Glass", color = { 0.10, 0.13, 0.18 }, shape = "round", radius = 14, lift = 0.09,
        ring = { "white", 0.24 }, shadow = 0.7,
        pat = { { "noise", 0.05, "ADD" } }, shine = 0.13,
        glow = { "white", 0.20 }, edit = { 1, 1, 1, 0.26 },
    },
    SOFT = {
        name = "Soft UI", color = { 0.17, 0.18, 0.22 }, shape = "round", radius = 20, lift = 0.07,
        ring = { "white", 0.07 }, ring2 = { "white", 0.05, inset = 3 }, shadow = 0.85,
        shine = 0.09, glow = { "white", 0.12 }, edit = { 1, 1, 1, 0.16 },
    },
    ROBLOX = {
        name = "Studio (Roblox-style)", color = { 0.137, 0.145, 0.153 }, shape = "round", radius = 8, lift = 0.02,
        ring = { "white", 0.20 }, shadow = 0.80,
        header = { "white", 0.09 }, headerLine = { "white", 0.10 }, accentLine = { "top", "accent" },
        glow = { "white", 0 }, edit = { 1, 1, 1, 0.30 },
    },
    CARBON = {
        name = "Carbon (racing)", color = { 0.04, 0.04, 0.045 }, shape = "cut", radius = 8,
        ring = { "white", 0.10 }, shadow = 0.6,
        pat = { { "bg_carbon", 0.55, "ADD", "base" } },
        header = { "accent", 0.12 }, headerLine = { "accent", 0.9 }, accentLine = { "left", "accent" },
        glow = { "accent", 0.30 }, edit = { 1, 1, 1, 0.22 },
    },
    MINIMAL = {
        name = "Minimalist", color = { 0, 0, 0 }, shape = "sq", radius = 4,
        glow = { "white", 0 }, edit = { 1, 1, 1, 0.12 },
    },
    -- classic / fantasy ----------------------------------------------------------
    CLASSIC = {
        name = "Classic", color = { 0.05, 0.05, 0.09 }, shape = "sq", radius = 4,
        pat = { { "paper", 0.09, "ADD" } }, vignette = 0.32, header = { "white", 0.07 },
        headerLine = { "white", 0.16 },
        bd = { edge = "Interface\\Tooltips\\UI-Tooltip-Border", size = 14, tint = { 0.85, 0.85, 0.92, 1 } },
        glow = { "white", 0 }, edit = { 0.85, 0.85, 0.92, 0.55 },
    },
    FOREVER = {
        name = "Forever (bronze)", color = { 0.13, 0.095, 0.06 }, shape = "sq", radius = 4, lift = 0.04,
        ring = { GOLD, 0.45, inset = 6 }, pat = { { "paper", 0.17, "ADD" }, { "dots", 0.04, "ADD", GOLD } },
        vignette = 0.55, header = { GOLD, 0.10 }, headerLine = { GOLD, 0.45 },
        corners = { tex = "c_gold", size = 22, colors = { GOLD } },
        bd = { edge = "Interface\\DialogFrame\\UI-DialogBox-Border", size = 16, tint = { 1, 0.92, 0.75, 1 } },
        glow = { GOLD, 0.22 }, edit = { 1, 0.85, 0.5, 0.6 },
    },
    TYRIA = {
        name = "Tyria (Guild Wars 2-style)", color = { 0.085, 0.060, 0.048 }, shape = "sq", radius = 4,
        ring = { { 0.80, 0.64, 0.36 }, 0.9 }, ring2 = { { 0.62, 0.17, 0.12 }, 0.65, inset = 5 },
        pat = { { "bg_leather", 0.32, "ADD", "base" }, { "bg_parchment", 0.08, "ADD", { 0.9, 0.75, 0.5 } } },
        vignette = 0.5, header = { { 0.80, 0.64, 0.36 }, 0.10 }, headerLine = { { 0.80, 0.64, 0.36 }, 0.65 },
        corners = { tex = "c_gw2", size = 26, colors = { { 0.88, 0.72, 0.42 } } },
        glow = { { 0.88, 0.72, 0.42 }, 0.18 }, edit = { 0.8, 0.64, 0.36, 0.7 },
    },
    GOTHIC = {
        name = "Gothic (Diablo-style)", color = { 0.055, 0.020, 0.022 }, shape = "sq", radius = 4,
        ring = { { 0.56, 0.55, 0.50 }, 0.85 }, ring2 = { { 0.72, 0.08, 0.06 }, 0.75, inset = 4 },
        pat = { { "bg_leather", 0.30, "ADD", { 0.55, 0.18, 0.16 } } },
        vignette = 0.68, header = { { 0.72, 0.08, 0.06 }, 0.15 }, headerLine = { { 0.72, 0.08, 0.06 }, 0.85 },
        accentLine = { "bottom", { 0.72, 0.08, 0.06 } },
        corners = { tex = "c_gothic", size = 26, colors = { { 0.78, 0.77, 0.70 } } },
        glow = { { 0.9, 0.10, 0.08 }, 0.42 }, pulse = true, edit = { 0.85, 0.15, 0.1, 0.7 },
    },
    TAVERN = {
        name = "Tavern (wood and iron)", color = { 0.42, 0.26, 0.12 }, shape = "sq", radius = 4,
        pat = { { "mat_planks", 0.95, "BLEND", "mat" } }, vignette = 0.45,
        ring = { { 0.09, 0.06, 0.035 }, 0.95 },
        bevel = { light = { 1, 0.85, 0.6, 0.35 }, dark = { 0, 0, 0, 0.55 }, size = 2 },
        header = { { 0, 0, 0 }, 0.30 }, headerLine = { { 0, 0, 0 }, 0.6 },
        corners = { tex = "c_iron", size = 20, colors = { { 0.66, 0.68, 0.72 } } },
        glow = { { 1.0, 0.70, 0.30 }, 0.16 }, edit = { 0.9, 0.7, 0.4, 0.6 },
    },
    -- sci-fi / games -------------------------------------------------------------
    CYBERPUNK = {
        name = "Cyberpunk", color = { 0.03, 0.012, 0.07 }, shape = "cut", radius = 14, lift = 0.03,
        ring = { CYAN, 0.9 }, ring2 = { MAGENTA, 0.38, inset = 4 }, shadow = 0.6,
        pat = { { "grid", 0.085, "ADD", CYAN }, { "scan", 0.05, "ADD", "white" } },
        vignette = 0.5, header = { CYAN, 0.10 }, headerLine = { MAGENTA, 0.8 },
        accentLine = { "bottom", MAGENTA },
        corners = { tex = "c_cyber", size = 20, colors = { MAGENTA, CYAN, CYAN, MAGENTA } },
        glow = { CYAN, 0.95 }, pulse = true, sweep = CYAN, edit = { 0.0, 0.95, 1.0, 0.7 },
    },
    TACTICAL = {
        name = "Tactical (shooter HUD)", color = { 0.04, 0.05, 0.06 }, shape = "cut", radius = 10,
        ring = { "accent", 0.9 },
        pat = { { "scan", 0.04, "ADD", "white" }, { "diag", 0.035, "ADD", "white" } },
        vignette = 0.4, header = { "accent", 0.16 }, headerLine = { "accent", 0.9 }, accentLine = { "top", "accent" },
        corners = { tex = "c_cyber", size = 18, colors = { "accent", "white" } },
        glow = { "accent", 0.35 }, edit = { 1, 1, 1, 0.35 },
    },
    TERMINAL = {
        name = "Terminal", color = { 0.0, 0.035, 0.0 }, shape = "sq", radius = 4,
        ring = { GREEN, 0.65 }, pat = { { "scan", 0.13, "ADD", GREEN }, { "noise", 0.03, "ADD", GREEN } },
        vignette = 0.6, header = { GREEN, 0.08 }, headerLine = { GREEN, 0.5 },
        accentLine = { "left", GREEN },
        corners = { tex = "c_term", size = 14, colors = { GREEN } },
        glow = { GREEN, 0.35 }, edit = { 0.25, 1.0, 0.35, 0.65 },
    },
    PIXEL = {
        name = "Pixel (8-bit)", color = { 0.04, 0.05, 0.13 }, shape = "sq", radius = 4,
        ring = { "accent", 1.0 }, ring2 = { "white", 0.12, inset = 4 },
        pat = { { "checker", 0.035, "ADD" }, { "dots", 0.05, "ADD", "accent" } },
        header = { "accent", 0.14 }, headerLine = { "accent", 0.9 }, accentLine = { "bottom", "accent" },
        corners = { tex = "c_pixel", size = 14, colors = { "accent" } },
        glow = { "accent", 0.0 }, edit = { 1, 1, 1, 0.4 },
    },
    RETRO = {
        name = "Retro box (8-bit RPG)", color = { 0, 0, 0 }, shape = "sq", radius = 4,
        bevel = { light = { 1, 1, 1, 1 }, dark = { 1, 1, 1, 1 }, size = 3 },
        glow = { "white", 0 }, edit = { 1, 1, 1, 0.9 },
    },
    BLOCKY = {
        name = "Blocky (Minecraft-style)", color = { 0.44, 0.44, 0.46 }, shape = "sq", radius = 4,
        pat = { { "mat_stone", 0.92, "BLEND", "mat" } },
        ring = { { 0, 0, 0 }, 0.95 },
        bevel = { light = { 1, 1, 1, 0.55 }, dark = { 0, 0, 0, 0.62 }, size = 3 },
        header = { { 0, 0, 0 }, 0.34 }, headerLine = { { 0, 0, 0 }, 0.65 }, shadow = 0.5,
        glow = { "white", 0 }, edit = { 1, 1, 1, 0.55 },
    },
}

Box.styles = {}
for _, id in ipairs({ "MODERN", "AURORA", "GLASS", "SOFT", "ROBLOX", "CARBON", "MINIMAL", "CLASSIC", "FOREVER",
    "TYRIA", "GOTHIC", "TAVERN", "CYBERPUNK", "TACTICAL", "TERMINAL", "PIXEL", "RETRO", "BLOCKY" }) do
    Box.styles[#Box.styles + 1] = { id = id, name = STYLES[id].name }
end
Box.STYLES = STYLES

-- ready-made background colors (the "color" row of the Chatbox page)
Box.presets = {
    { "Midnight", { 0.055, 0.058, 0.075 } }, { "Black", { 0, 0, 0 } },
    { "Graphite", { 0.13, 0.13, 0.15 } },    { "Slate", { 0.20, 0.24, 0.30 } },
    { "Navy", { 0.04, 0.09, 0.22 } },        { "Ocean", { 0.03, 0.16, 0.22 } },
    { "Forest", { 0.03, 0.14, 0.07 } },      { "Wine", { 0.22, 0.04, 0.09 } },
    { "Crimson", { 0.36, 0.05, 0.07 } },     { "Plum", { 0.16, 0.05, 0.24 } },
    { "Brown", { 0.19, 0.11, 0.05 } },       { "Gold", { 0.42, 0.32, 0.08 } },
}

local SHAPES = {
    round = { fill = "round", ring = "ring" },
    cut   = { fill = "cut",   ring = "cut_ring" },
    sq    = { fill = "sq",    ring = "sq_ring" },
}

-- Backgrounds: a handful of bold patterns that change the look at a glance.
local BG_LIST = {
    { text = "None", value = "NONE" },
    { text = "Soft gradient", value = "GRADIENT" },
    { text = "Carbon fiber", value = "carbon" },
    { text = "Diamond mesh", value = "diamond" },
    { text = "Starfield", value = "stars" },
    { text = "Parchment", value = "parchment" },
    { text = "Brushed metal", value = "metal" },
    { text = "Leather", value = "leather" },
    { text = "Custom texture path", value = "CUSTOM" },
}
local BG_FILES = { carbon = true, diamond = true, stars = true, parchment = true, metal = true, leather = true }

function Box:StyleColor()
    return (STYLES[ns.db.chatbox.style] or STYLES.MODERN).color
end

function Box:GetBackgrounds() return BG_LIST end

function Box:EditBorder()
    local st = STYLES[ns.db.chatbox.style] or STYLES.MODERN
    return st.edit or { 1, 1, 1, 0.18 }
end

---------------------------------------------------------------------------
-- Building the layers
---------------------------------------------------------------------------
local function Tiled(tex, path)
    if not pcall(tex.SetTexture, tex, path, "REPEAT", "REPEAT") then tex:SetTexture(path) end
    pcall(tex.SetHorizTile, tex, true)
    pcall(tex.SetVertTile, tex, true)
end

local function RGB(spec)
    if spec == "accent" then return ns:GetAccent() end
    if spec == "white" or spec == nil then return 1, 1, 1 end
    return spec[1], spec[2], spec[3]
end

function Box:CreateSkin()
    local f = CreateFrame("Frame", "ZamestoTVChatbox", UIParent)
    f:SetFrameStrata("BACKGROUND")
    f:SetFrameLevel(1)
    f:EnableMouse(false)

    f.shadow = NewSlice(f, MEDIA .. "shadow", "BACKGROUND", -8, 0.375)
    f.glow = NewSlice(f, MEDIA .. "glow", "BACKGROUND", -7, 0.375)
    f.glow:SetBlend("ADD")
    f.glow.noCenter = true
    f.fill = NewSlice(f, MEDIA .. "round", "BACKGROUND", -6, 0.25)

    f.bgTex = f:CreateTexture(nil, "BACKGROUND", nil, -5)
    f.pat = {}
    for i = 1, 2 do f.pat[i] = f:CreateTexture(nil, "BACKGROUND", nil, -4) end
    f.vig = f:CreateTexture(nil, "BACKGROUND", nil, -3)
    f.vig:SetTexture(MEDIA .. "vignette")
    f.shine = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    f.shine:SetTexture(WHITE)
    f.band = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.band:SetTexture(WHITE)
    f.railBg = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.railBg:SetTexture(WHITE)
    f.railLine = f:CreateTexture(nil, "BORDER", nil, 1)
    f.railLine:SetTexture(WHITE)

    f.ring = NewSlice(f, MEDIA .. "ring", "BORDER", 0, 0.25)
    f.ring2 = NewSlice(f, MEDIA .. "ring", "BORDER", 1, 0.25)
    f.bandLine = f:CreateTexture(nil, "BORDER", nil, 2)
    f.bandLine:SetTexture(WHITE)

    f.accent = {}
    for _, k in ipairs({ "top", "left", "bottom" }) do
        local t = f:CreateTexture(nil, "BORDER", nil, 3)
        t:SetTexture(WHITE)
        f.accent[k] = t
    end

    f.bevel = {}
    for _, k in ipairs({ "top", "left", "bottom", "right" }) do
        local t = f:CreateTexture(nil, "BORDER", nil, 4)
        t:SetTexture(WHITE)
        f.bevel[k] = t
    end

    f.corners = {}
    for i = 1, 4 do f.corners[i] = f:CreateTexture(nil, "ARTWORK", nil, 1) end
    f.sweep = f:CreateTexture(nil, "ARTWORK")
    f.sweep:SetTexture(WHITE)
    f.sweep:SetBlendMode("ADD")

    f.bd = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.bd:SetAllPoints(f)
    f.bd:SetFrameLevel(f:GetFrameLevel() + 1)
    f.bd:Hide()
    return f
end

---------------------------------------------------------------------------
-- Painting
---------------------------------------------------------------------------
local function HeaderHeight(o)
    local dock = o.includeTabs and _G.GeneralDockManager
    local h = dock and dock:GetHeight() or 0
    if not h or h < 4 then return 0 end
    return h + o.padding
end

function Box:Paint()
    local f = self.frame
    if not f then return end
    local o = ns.db.chatbox
    f:SetShown(o.enabled and true or false)
    if not o.enabled then
        self:UpdateDriver()
        return
    end

    local st = STYLES[o.style] or STYLES.MODERN
    self.st = st
    local shape = SHAPES[st.shape] or SHAPES.round
    local radius = st.radius or 12
    local alpha = o.alpha
    local strength = (o.texStrength or 1)
    local deco = o.border and true or false
    local base = o.color or st.color
    local fade = 0.35 + 0.65 * alpha   -- patterns fade out together with the background
    local inset = math.floor(radius * 0.5)

    -- fill ---------------------------------------------------------------
    f.fill:SetFile(MEDIA .. shape.fill, 0.25)
    f.fill:Layout(radius, 0)
    local lift = st.lift or 0
    local bottom = base
    if o.bgTexture == "GRADIENT" then
        lift = 0.16
        bottom = { base[1] * 0.55, base[2] * 0.55, base[3] * 0.55 }
    end
    local top = { math.min(1, base[1] + lift), math.min(1, base[2] + lift), math.min(1, base[3] + lift * 1.2) }
    if st.grad and not o.color then top, bottom = st.grad[1], st.grad[2] end
    f.fill:SetVGradient(top, alpha * 0.9, bottom, alpha)

    -- shadow -------------------------------------------------------------
    local sh = st.shadow or 0
    f.shadow:SetShown(sh > 0 and alpha > 0.05)
    if sh > 0 then
        f.shadow:Layout(36, -26, -18, -26, -34)
        f.shadow:SetColor(0, 0, 0, sh * (0.35 + 0.65 * alpha))
    end

    -- background pattern (ADD: the light parts brighten the frame color, so it always shows) ----
    local bgv = o.bgTexture
    local bgfile, bgblend
    if BG_FILES[bgv] then bgfile, bgblend = MEDIA .. "bg_" .. bgv, "ADD"
    elseif bgv == "CUSTOM" and o.bgCustom and o.bgCustom ~= "" then bgfile, bgblend = o.bgCustom, "BLEND" end
    if bgfile then
        f.bgTex:ClearAllPoints()
        f.bgTex:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
        f.bgTex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
        if bgblend == "ADD" or o.bgTile then Tiled(f.bgTex, bgfile) else
            f.bgTex:SetTexture(bgfile)
            pcall(f.bgTex.SetHorizTile, f.bgTex, false)
            pcall(f.bgTex.SetVertTile, f.bgTex, false)
        end
        f.bgTex:SetBlendMode(bgblend)
        local k = o.bgStrength or 1
        if bgblend == "ADD" then
            local tr, tg, tb = 0.16 + base[1] * 0.9, 0.16 + base[2] * 0.9, 0.16 + base[3] * 0.9
            if bgv == "stars" then tr, tg, tb = 0.9, 0.95, 1 end
            f.bgTex:SetVertexColor(tr, tg, tb, math.min(1, 0.85 * k * (0.5 + 0.5 * alpha)))
        else
            f.bgTex:SetVertexColor(1, 1, 1, math.min(1, 0.9 * k * alpha))
        end
        f.bgTex:Show()
    else
        f.bgTex:Hide()
    end

    -- pattern overlays ---------------------------------------------------
    for i = 1, 2 do
        local p, tex = st.pat and st.pat[i], f.pat[i]
        if p and strength > 0 then
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
            tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
            Tiled(tex, MEDIA .. p[1])  -- (names may be mat_* / bg_* / pattern files)
            tex:SetBlendMode(p[3] or "ADD")
            local r, g, b
            if p[4] == "base" then       -- brighten the frame color (ADD patterns)
                r, g, b = 0.16 + base[1] * 0.9, 0.16 + base[2] * 0.9, 0.16 + base[3] * 0.9
            elseif p[4] == "mat" then    -- material tinted by the frame color (BLEND patterns)
                r, g, b = math.min(1, base[1] * 2), math.min(1, base[2] * 2), math.min(1, base[3] * 2)
            else
                r, g, b = RGB(p[4])
            end
            tex:SetVertexColor(r, g, b, math.min(1, p[2] * strength * (p[3] == "BLEND" and math.min(1, alpha * 1.3) or fade)))
            tex:Show()
        else
            tex:Hide()
        end
    end

    -- vignette / shine / header band --------------------------------------
    if (st.vignette or 0) > 0 and strength > 0 then
        f.vig:ClearAllPoints()
        f.vig:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
        f.vig:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
        f.vig:SetVertexColor(0, 0, 0, math.min(1, st.vignette * strength * fade))
        f.vig:Show()
    else
        f.vig:Hide()
    end

    if (st.shine or 0) > 0 and deco then
        f.shine:ClearAllPoints()
        f.shine:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
        f.shine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -inset, -inset)
        f.shine:SetHeight(48)
        f.shine:SetColorTexture(1, 1, 1, 1)
        Gradient(f.shine, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, st.shine * fade)
        f.shine:Show()
    else
        f.shine:Hide()
    end

    local hh = HeaderHeight(o)
    if st.header and hh > 0 and deco then
        local r, g, b = RGB(st.header[1])
        f.band:ClearAllPoints()
        f.band:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
        f.band:SetPoint("TOPRIGHT", f, "TOPRIGHT", -inset, -inset)
        f.band:SetHeight(math.max(4, hh - inset))
        f.band:SetColorTexture(r, g, b, st.header[2] * (0.4 + 0.6 * alpha))
        f.band:Show()
        if st.headerLine then
            local lr, lg, lb = RGB(st.headerLine[1])
            f.bandLine:ClearAllPoints()
            f.bandLine:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -hh)
            f.bandLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -inset, -hh)
            f.bandLine:SetHeight(1)
            f.bandLine:SetColorTexture(lr, lg, lb, st.headerLine[2])
            f.bandLine:Show()
        else
            f.bandLine:Hide()
        end
    else
        f.band:Hide()
        f.bandLine:Hide()
    end

    -- rings ---------------------------------------------------------------
    if st.ring and deco then
        local rg = st.ring
        local r, g, b = RGB(rg[1])
        local ins = rg.inset or 0
        f.ring:SetFile(MEDIA .. shape.ring, 0.25)
        f.ring:Layout(math.max(4, radius - ins), ins)
        f.ring:SetColor(r, g, b, rg[2])
        f.ring:SetShown(true)
    else
        f.ring:SetShown(false)
    end
    if st.ring2 and deco then
        local rg = st.ring2
        local r, g, b = RGB(rg[1])
        f.ring2:SetFile(MEDIA .. shape.ring, 0.25)
        f.ring2:Layout(math.max(4, radius - rg.inset), rg.inset)
        f.ring2:SetColor(r, g, b, rg[2])
        f.ring2:SetShown(true)
    else
        f.ring2:SetShown(false)
    end

    -- bevel: light top/left, dark bottom/right (blocky / retro / wood styles) --------------
    for _, t in pairs(f.bevel) do t:Hide() end
    if st.bevel and deco then
        local bv, sz = st.bevel, st.bevel.size
        local L, D = bv.light, bv.dark
        local B = f.bevel
        B.top:ClearAllPoints();    B.top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0);       B.top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0);       B.top:SetHeight(sz)
        B.bottom:ClearAllPoints(); B.bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); B.bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0); B.bottom:SetHeight(sz)
        B.left:ClearAllPoints();   B.left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -sz);    B.left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, sz);    B.left:SetWidth(sz)
        B.right:ClearAllPoints();  B.right:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -sz); B.right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, sz); B.right:SetWidth(sz)
        B.top:SetColorTexture(L[1], L[2], L[3], L[4]); B.left:SetColorTexture(L[1], L[2], L[3], L[4])
        B.bottom:SetColorTexture(D[1], D[2], D[3], D[4]); B.right:SetColorTexture(D[1], D[2], D[3], D[4])
        for _, t in pairs(B) do t:Show() end
    end

    -- accent line -------------------------------------------------------------
    for _, t in pairs(f.accent) do t:Hide() end
    if st.accentLine and deco then
        local where, spec = st.accentLine[1], st.accentLine[2]
        local r, g, b = RGB(spec)
        local t = f.accent[where]
        t:ClearAllPoints()
        local m = radius
        if where == "top" then
            t:SetPoint("TOPLEFT", f, "TOPLEFT", m, -1); t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -m, -1); t:SetHeight(2)
        elseif where == "bottom" then
            t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", m, 1); t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -m, 1); t:SetHeight(2)
        else
            t:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -m); t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, m); t:SetWidth(2)
        end
        t:SetColorTexture(r, g, b, 0.95)
        t:Show()
    end

    -- corner ornaments ---------------------------------------------------------
    local cs = st.corners
    local flips = { { 0, 1, 0, 1 }, { 1, 0, 0, 1 }, { 0, 1, 1, 0 }, { 1, 0, 1, 0 } }
    local points = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
    for i = 1, 4 do
        local t = f.corners[i]
        if cs and deco then
            local spec = cs.colors[((i - 1) % #cs.colors) + 1]
            local r, g, b = RGB(spec)
            t:SetTexture(MEDIA .. cs.tex)
            t:SetTexCoord(flips[i][1], flips[i][2], flips[i][3], flips[i][4])
            t:SetSize(cs.size, cs.size)
            t:ClearAllPoints()
            local dx = (i % 2 == 1) and 2 or -2
            local dy = (i <= 2) and -2 or 2
            t:SetPoint(points[i], f, points[i], dx, dy)
            t:SetVertexColor(r, g, b, 1)
            t:Show()
        else
            t:Hide()
        end
    end

    -- Blizzard border (Classic / Forever) -----------------------------------------
    if st.bd and deco then
        f.bd:SetBackdrop({ edgeFile = st.bd.edge, edgeSize = st.bd.size })
        f.bd:SetBackdropBorderColor(unpack(st.bd.tint))
        f.bd:Show()
    else
        f.bd:Hide()
    end

    -- scan sweep (cyberpunk) -------------------------------------------------------
    if st.sweep and o.animate and deco then
        local r, g, b = RGB(st.sweep)
        f.sweep:SetColorTexture(r, g, b, 0.16)
        f.sweep:SetHeight(2)
        f.sweep:Show()
    else
        f.sweep:Hide()
    end

    if self.LayoutRail then self:LayoutRail() end
    self:PaintEditBoxes()
    self:ApplyGlow()
    self:UpdateDriver()
end

---------------------------------------------------------------------------
-- Glow (soft light around the frame) + flash on new messages + animation
---------------------------------------------------------------------------
local FLASH_TIME, FLASH_COLOR = 0.9, { 1.0, 0.12, 0.12 }
local hue, clock, flashLeft, flashF, glowScale = 0, 0, 0, 0, nil

local function HueRGB(h)
    h = (h % 1) * 6
    local i, f = math.floor(h), h - math.floor(h)
    local q = 1 - f
    if i == 0 then return 1, f, 0 elseif i == 1 then return q, 1, 0
    elseif i == 2 then return 0, 1, f elseif i == 3 then return 0, q, 1
    elseif i == 4 then return f, 0, 1 end
    return 1, 0, q
end

local function LayoutGlow(f, scale)
    if scale == glowScale then return end
    glowScale = scale
    f.glow:Layout(36 * scale, -28 * scale)
end

function Box:GlowAnimating()
    local o = ns.db.chatbox
    if not o.enabled then return false end
    local st = self.st or STYLES[o.style] or STYLES.MODERN
    local mode = o.glowMode or "STYLE"
    if mode == "RGB" then return true end
    if mode ~= "OFF" and ((mode == "STYLE" and st.pulse) or o.glowPulse) then return true end
    if o.animate and st.sweep and o.border then return true end
    return flashLeft > 0
end

function Box:ApplyGlow()
    local f = self.frame
    if not f then return end
    local o = ns.db.chatbox
    if not o.enabled then return end
    local st = self.st or STYLES[o.style] or STYLES.MODERN
    local mode = o.glowMode or "STYLE"

    local base, r, g, b = 0, 1, 1, 1
    if mode ~= "OFF" then
        local inten, pulse = 0.7, o.glowPulse
        if mode == "STYLE" then
            r, g, b = RGB(st.glow and st.glow[1])
            inten = st.glow and st.glow[2] or 0
            pulse = pulse or st.pulse
        elseif mode == "ACCENT" then
            r, g, b = ns:GetAccent()
        elseif mode == "CUSTOM" then
            local c = o.glowColor or { 0.4, 0.75, 1 }
            r, g, b = c[1], c[2], c[3]
        else -- RGB
            r, g, b = HueRGB(hue)
        end
        base = inten * (o.glowIntensity or 1)
        if pulse then base = base * (0.55 + 0.45 * (0.5 + 0.5 * math.sin(clock * 2.5))) end
    end

    if base <= 0.01 and flashF <= 0 then
        f.glow:SetShown(false)
        return
    end
    local fl = flashF
    local a = math.min(1, base + (1 - base) * fl)
    r = r + (FLASH_COLOR[1] - r) * fl
    g = g + (FLASH_COLOR[2] - g) * fl
    b = b + (FLASH_COLOR[3] - b) * fl
    LayoutGlow(f, 1 + 1.6 * fl)
    f.glow:SetColor(r, g, b, a)
    f.glow:SetShown(true)
end

function Box:Flash()
    local o = ns.db.chatbox
    if not (o.enabled and o.flash and self.frame and self.frame:IsShown()) then return end
    flashLeft = FLASH_TIME
    self:UpdateDriver()
end

local driver = CreateFrame("Frame")
local acc = 0
local function Tick(_, dt)
    if dt > 0.1 then dt = 0.1 end
    clock = clock + dt
    hue = (hue + dt * 0.12) % 1
    local f = Box.frame
    if not f then return end

    if flashLeft > 0 then
        flashLeft = flashLeft - dt
        local p = 1 - math.max(0, flashLeft) / FLASH_TIME
        if flashLeft <= 0 then flashF = 0
        elseif p < 0.12 then flashF = p / 0.12
        else flashF = (1 - (p - 0.12) / 0.88) ^ 2 end
        Box:ApplyGlow()
        if flashLeft <= 0 then Box:UpdateDriver() end
    else
        acc = acc + dt
        if acc >= 0.033 then
            acc = 0
            Box:ApplyGlow()
        end
    end

    if f.sweep:IsShown() then
        local h = f:GetHeight() or 100
        local y = (clock * 38) % math.max(20, h - 8)
        f.sweep:ClearAllPoints()
        f.sweep:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -4 - y)
        f.sweep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -4 - y)
    end
end

function Box:UpdateDriver()
    if self:GlowAnimating() then
        if not driver:GetScript("OnUpdate") then driver:SetScript("OnUpdate", Tick) end
    else
        driver:SetScript("OnUpdate", nil)
        if self.frame and not self.frame.sweep:IsShown() then self:ApplyGlow() end
    end
end
