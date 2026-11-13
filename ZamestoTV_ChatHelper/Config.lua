local ADDON, ns = ...
local UI = ns.UI
local C = UI.C
local Config = ns:NewModule("Config")
local T = ns.T

local win, content
local pages, order, navs = {}, {}, {}
local current

local KEYS = { appearance = true, bar = true, chatbox = true, effects = true, looks = true, messenger = true, chat = true, spam = true, fonts = true, general = true }
local MIN_W, MIN_H, MAX_W, MAX_H = 640, 460, 1200, 900

---------------------------------------------------------------------------
-- Page helpers. Columns are anchored on both sides, so every page
-- stretches when the window is resized.
---------------------------------------------------------------------------
local function NewPage(key, name, title, sub)
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints(content)
    p:Hide()
    p.widgets = {}
    p.heading = UI.Text(p, 18)
    p.heading:SetPoint("TOPLEFT", 24, -20)
    p.heading:SetText(T(title))
    p.sub = UI.Text(p, 11, C.muted)
    p.sub:SetPoint("TOPLEFT", p.heading, "BOTTOMLEFT", 0, -4)
    p.sub:SetText(T(sub))
    p.L = UI.Stack(p, "L", 76)
    p.R = UI.Stack(p, "R", 76)
    p.F = UI.Stack(p, "F", 76)
    p:SetScript("OnShow", function(self)
        for _, w in ipairs(self.widgets) do
            if w.Refresh then w:Refresh() end
        end
    end)
    pages[key] = p
    order[#order + 1] = { key = key, name = name }
    return p
end

local function Put(p, side, w, gap)
    p[side]:Add(w, gap)
    p.widgets[#p.widgets + 1] = w
    return w
end

local function Sync(p)
    local y = math.max(p.L.y, p.R.y, p.F.y)
    p.L.y, p.R.y, p.F.y = y, y, y
end

local function Header(p, text)
    Put(p, "F", UI.Header(p, text, 100), 8)
    Sync(p)
end

local function Label(p, side, text)
    local fs = UI.Text(p, 11, C.muted)
    fs:SetText(T(text))
    fs:SetHeight(14)
    p[side]:Add(fs, 4)
    return fs
end

local function Note(p, side, text, height)
    local fs = UI.Text(p, 11, C.muted)
    fs:SetWordWrap(true)
    fs:SetJustifyV("TOP")
    fs:SetHeight(height or 40)
    fs:SetText(T(text))
    p[side]:Add(fs, 6)
    return fs
end

local function Check(p, side, label, tbl, key, after, tipTitle, tipText)
    local c = UI.Check(p, label,
        function() return tbl[key] end,
        function(v) tbl[key] = v; if after then after(v) end end,
        tipTitle, tipText)
    return Put(p, side, c, 4)
end

local function Features() ns.Features:Apply() end
local function PercentFmt(v) return string.format("%d%%", math.floor(v + 0.5)) end

---------------------------------------------------------------------------
-- Appearance
---------------------------------------------------------------------------
local function BuildAppearance()
    local p = NewPage("appearance", "Appearance", "Appearance", "Pick an accent color and how the chat bar looks.")

    Header(p, "Accent color")

    local row = CreateFrame("Frame", nil, p)
    row:SetSize(100, 30)
    row.sw = {}
    for i, preset in ipairs(ns.presets) do
        local sw = CreateFrame("Button", nil, row, "BackdropTemplate")
        sw:SetSize(26, 26)
        sw:SetPoint("LEFT", (i - 1) * 32, 0)
        sw:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        sw:SetBackdropColor(preset[2][1], preset[2][2], preset[2][3], 1)
        sw.color = preset[2]
        sw:SetScript("OnClick", function() ns:SetAccent(unpack(preset[2])) end)
        UI.Tip(sw, preset[1])
        row.sw[i] = sw
    end
    local function Mark()
        local a = ns.db.theme.accent
        for _, sw in ipairs(row.sw) do
            local same = math.abs(sw.color[1] - a[1]) < 0.01 and math.abs(sw.color[2] - a[2]) < 0.01
                and math.abs(sw.color[3] - a[3]) < 0.01
            if same then sw:SetBackdropBorderColor(1, 1, 1, 1) else sw:SetBackdropBorderColor(0, 0, 0, 0) end
        end
    end
    row.Refresh = Mark
    ns:OnTheme(Mark)
    local custom = UI.Button(row, "Custom color...", 120, 26, function()
        local r, g, b = ns:GetAccent()
        UI.PickColor(r, g, b, function(nr, ng, nb) ns:SetAccent(nr, ng, nb) end)
    end, true)
    custom:SetPoint("LEFT", #ns.presets * 32 + 8, 0)
    Put(p, "F", row, 16)
    Sync(p)

    Header(p, "Chat bar")

    Label(p, "L", "Button style")
    local items = {}
    for _, s in ipairs(ns.Bar.styles) do items[#items + 1] = { text = s.name, value = s.id } end
    Put(p, "L", UI.Dropdown(p, 100, items,
        function() return ns.db.theme.buttonStyle end,
        function(v) ns.db.theme.buttonStyle = v; ns.Bar:Refresh() end), 10)
    Note(p, "L", "Label, Tag and Text only show full names (Raid, Guild, Party...). Circle, Square, Outline and Accent dot use short letters.", 64)

    Put(p, "R", UI.Slider(p, "Background opacity", 0, 100, 5,
        function() return ns.db.theme.bgAlpha * 100 end,
        function(v) ns.db.theme.bgAlpha = v / 100; ns.Bar:StyleFrame() end,
        PercentFmt, 100), 6)
    Put(p, "R", UI.Slider(p, "Idle opacity (bar fades when the mouse is away)", 20, 100, 5,
        function() return ns.db.bar.fade * 100 end,
        function(v) ns.db.bar.fade = v / 100 end,
        PercentFmt, 100), 6)
    Sync(p)

    local info = UI.Text(p, 11, C.muted)
    info:SetPoint("TOPLEFT", p, "TOPLEFT", 24, -p.L.y - 6)
    info:SetPoint("TOPRIGHT", p, "TOPRIGHT", -24, -p.L.y - 6)
    info:SetWordWrap(true)
    info:SetText("The accent color is also used by this window, the copy window and the link popup. The bar's border is only shown while repositioning.")
end

---------------------------------------------------------------------------
-- Chat bar
---------------------------------------------------------------------------
local function BuildBar()
    local p = NewPage("bar", "Chat Bar", "Chat Bar", "Layout, size and which buttons are shown.")
    local o = ns.db.bar
    local refresh = function() ns.Bar:Refresh() end

    Check(p, "L", "Show chat bar", o, "visible", refresh)
    Check(p, "L", "Horizontal layout", o, "horizontal", refresh)
    Check(p, "L", "Show letters (letter styles)", o, "showText", refresh)

    local mv = UI.Button(p, "Reposition bar", 100, 28, function()
        ns.Bar:SetMoveMode(not ns.Bar.moveMode)
    end, true)
    mv.Refresh = function(self)
        self:SetLabel(ns.Bar.moveMode and "Finish repositioning" or "Reposition bar")
    end
    ns.Bar.onMoveMode = function() mv:Refresh() end
    Put(p, "L", mv, 6)
    Note(p, "L", "Drag the bar to move it, then right-click it to finish. The border is only visible in this mode.", 44)

    Put(p, "R", UI.Slider(p, "Button size", 14, 40, 1, function() return o.size end,
        function(v) o.size = v; ns.Bar:Refresh() end, nil, 100), 6)
    Put(p, "R", UI.Slider(p, "Spacing", 0, 12, 1, function() return o.spacing end,
        function(v) o.spacing = v; ns.Bar:Refresh() end, nil, 100), 6)
    Put(p, "R", UI.Slider(p, "Buttons per row / column", 3, 14, 1, function() return o.perLine end,
        function(v) o.perLine = v; ns.Bar:Refresh() end, nil, 100), 6)
    Put(p, "R", UI.Slider(p, "Scale", 0.6, 1.6, 0.05, function() return o.scale end,
        function(v) o.scale = v; ns.Bar:StyleFrame() end,
        function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end, 100), 6)
    Sync(p)

    Header(p, "Buttons")
    local toggles = ns.Bar.toggles
    local y0 = p.L.y
    for i, t in ipairs(toggles) do
        local col = (i - 1) % 3
        local rowIdx = math.floor((i - 1) / 3)
        local c = UI.Check(p, t.name,
            function() return not o.hidden[t.id] end,
            function(v) o.hidden[t.id] = (not v) or nil; ns.Bar:Refresh() end,
            nil, nil, 160)
        c:SetPoint("TOPLEFT", p, "TOPLEFT", 24 + col * 172, -(y0 + rowIdx * 26))
        p.widgets[#p.widgets + 1] = c
    end
    -- built-in channels: 1 General, 2 Trade, 3 Defense ...
    do
        local i = #toggles + 1
        local c = UI.Check(p, "Include General / Trade / Defense",
            function() return o.builtinChannels ~= false end,
            function(v)
                o.builtinChannels = v
                if ns.Bar.UpdateChannelStates then ns.Bar.UpdateChannelStates() end
                ns.Bar:Refresh()
            end, "Include General / Trade / Defense",
            "Adds buttons for the built-in channels (/1 General, /2 Trade, /3 Defense). They only appear while you are in the channel.", 160)
        c:SetPoint("TOPLEFT", p, "TOPLEFT", 24 + ((i - 1) % 3) * 172, -(y0 + math.floor((i - 1) / 3) * 26))
        p.widgets[#p.widgets + 1] = c
    end
    do
        local i = #toggles + 2
        local c2 = UI.Check(p, "One \"Channels\" button with a menu",
            function() return o.channelMode ~= "BUTTONS" end,
            function(v)
                o.channelMode = v and "MENU" or "BUTTONS"
                ns.Bar:Refresh()
            end, "One \"Channels\" button with a menu",
            "A single button shows the current channel and opens a list of your channels (click). The mouse wheel switches channel, right-click writes in the last one. Turn it off for numbered buttons.", 160)
        c2:SetPoint("TOPLEFT", p, "TOPLEFT", 24 + ((i - 1) % 3) * 172, -(y0 + math.floor((i - 1) / 3) * 26))
        p.widgets[#p.widgets + 1] = c2
    end
    local gridEnd = y0 + math.ceil((#toggles + 2) / 3) * 26 + 8
    local reset = UI.Button(p, "Reset position", 130, 26, function() ns.Bar:ResetPosition() end)
    reset:SetPoint("TOPLEFT", p, "TOPLEFT", 24, -gridEnd)
    local note = UI.Text(p, 11, C.muted)
    note:SetPoint("LEFT", reset, "RIGHT", 12, 0)
    note:SetText("Buttons for channels you are not in are hidden automatically.")
end

---------------------------------------------------------------------------
-- Chat features
---------------------------------------------------------------------------
local function BuildChat()
    local p = NewPage("chat", "Chat", "Chat Features", "Quality-of-life improvements for your chat windows.")
    local o = ns.db.chat
    local k = o.keywords

    Label(p, "L", "Timestamps")
    Put(p, "L", UI.Dropdown(p, 100, {
        { text = "Don't change (Blizzard setting)", value = "DEFAULT" },
        { text = "None", value = "none" },
        { text = "14:32", value = "%H:%M " },
        { text = "14:32:07", value = "%H:%M:%S " },
        { text = "2:32 PM", value = "%I:%M %p " },
        { text = "2:32:07 PM", value = "%I:%M:%S %p " },
    }, function() return o.timestamps end,
        function(v) o.timestamps = v; ns.Features:ApplyTimestamps() end), 12)

    Check(p, "L", "Class-colored names", o, "classColors", Features)
    Check(p, "L", "Clickable links", o, "urls", nil, "Clickable links", "Click a link in chat to copy it.")
    Check(p, "L", "Short channel names", o, "shortChannels", nil, "Short channel names", "[Guild] becomes [G], [3. Trade] becomes [3] and so on. Affects new messages.")
    Check(p, "L", "Hide Blizzard chat buttons", o, "hideButtons", Features, "Hide Blizzard chat buttons", "Menu, channel and voice buttons. Showing them again needs /reload.")
    Check(p, "L", "Arrow keys move the cursor", o, "freeArrows", Features, "Arrow keys move the cursor", "Use the arrow keys in the chat box without holding Alt.")
    Check(p, "L", "Remember last chat channel", o, "sticky", Features, "Remember last chat channel", "The chat box keeps the last channel you used. Turning it off needs /reload.")
    Put(p, "L", UI.Slider(p, "Chat history lines", 0, 2000, 50,
        function() return o.history end,
        function(v) o.history = v; ns.Features:ApplyHistory() end,
        function(v) return v < 128 and "Default" or tostring(v) end, 100), 6)

    Put(p, "R", UI.Header(p, "Keyword highlight", 100), 8)
    Check(p, "R", "Highlight keywords", k, "enabled", function() ns.Features:RebuildKeywords() end)
    Check(p, "R", "Include my character name", k, "name", function() ns.Features:RebuildKeywords() end)
    Check(p, "R", "Play a sound", k, "sound")

    local colorRow = CreateFrame("Frame", nil, p)
    colorRow:SetSize(100, 26)
    local colorLabel = UI.Text(colorRow, 12)
    colorLabel:SetPoint("LEFT", 0, 0)
    colorLabel:SetText("Highlight color")
    local sw = UI.Swatch(colorRow, 22, function() return k.color end, function(r, g, b)
        k.color[1], k.color[2], k.color[3] = r, g, b
        ns.Features:RebuildKeywords()
    end)
    sw:SetPoint("LEFT", 110, 0)
    colorRow.Refresh = function() sw:Refresh() end
    Put(p, "R", colorRow, 8)

    Label(p, "R", "Keywords (comma or line separated)")
    local edit = UI.MultiEdit(p, 100, 96, function(text)
        k.text = text
        ns.Features:RebuildKeywords()
    end)
    edit.Refresh = function(self) self:SetValue(k.text) end
    Put(p, "R", edit, 6)
end


---------------------------------------------------------------------------
-- Chatbox (frame skin + chat bar placement)
---------------------------------------------------------------------------
local function BuildChatbox()
    local p = NewPage("chatbox", "Chatbox", "Chatbox", "A layered frame behind your chat window: style, color, opacity and background.")
    local o = ns.db.chatbox
    local apply = function() ns.Chatbox:Apply() end
    local paint = function() ns.Chatbox:Paint() end

    -- preset colors as clickable chips, plus a free color picker
    local colorRow = CreateFrame("Frame", nil, p)
    colorRow:SetSize(100, 108)
    local lbl = UI.Text(colorRow, 11, C.muted)
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetText(T("Frame color"))
    local chips = {}
    for i, pr in ipairs(ns.Chatbox.presets) do
        local chip = CreateFrame("Button", nil, colorRow, "BackdropTemplate")
        chip:SetSize(24, 24)
        chip:SetPoint("TOPLEFT", ((i - 1) % 6) * 30, -20 - math.floor((i - 1) / 6) * 30)
        UI.Flat(chip, { pr[2][1], pr[2][2], pr[2][3], 1 }, C.border)
        chip.color = pr[2]
        chip:SetScript("OnClick", function()
            o.color = { pr[2][1], pr[2][2], pr[2][3] }
            paint()
            colorRow:Refresh()
        end)
        UI.Tip(chip, pr[1])
        chips[i] = chip
    end
    local sw = UI.Swatch(colorRow, 24, function() return o.color or ns.Chatbox:StyleColor() end,
        function(r, g, b) o.color = { r, g, b }; paint(); colorRow:Refresh() end)
    sw:SetPoint("TOPLEFT", 0, -82)
    UI.Tip(sw, "Custom color...")
    local reset = UI.Button(colorRow, "Style default", 110, 24, function()
        o.color = nil
        paint()
        colorRow:Refresh()
    end)
    reset:SetPoint("LEFT", sw, "RIGHT", 10, 0)
    function colorRow:Refresh()
        local cur = o.color
        for _, chip in ipairs(chips) do
            local c = chip.color
            local sel = cur and math.abs(cur[1] - c[1]) < 0.003 and math.abs(cur[2] - c[2]) < 0.003
                and math.abs(cur[3] - c[3]) < 0.003
            if sel then chip:SetBackdropBorderColor(1, 1, 1, 1) else chip:SetBackdropBorderColor(unpack(C.border)) end
        end
        sw:Refresh()
    end

    Check(p, "L", "Enable chatbox", o, "enabled", apply, "Enable chatbox",
        "Draws a layered frame behind the main chat window and hides Blizzard's own background.")
    Label(p, "L", "Style")
    local styles = {}
    for _, st in ipairs(ns.Chatbox.styles) do styles[#styles + 1] = { text = st.name, value = st.id } end
    Put(p, "L", UI.Dropdown(p, 100, styles, function() return o.style end,
        function(v) o.style = v; o.color = nil; paint(); colorRow:Refresh() end), 10)
    Label(p, "L", "Background")
    Put(p, "L", UI.Dropdown(p, 100, function() return ns.Chatbox:GetBackgrounds() end,
        function() return o.bgTexture end,
        function(v) o.bgTexture = v; paint() end), 10)
    Put(p, "L", UI.Slider(p, "Background pattern strength", 0, 200, 10, function() return (o.bgStrength or 1) * 100 end,
        function(v) o.bgStrength = v / 100; paint() end, PercentFmt, 100), 6)
    Label(p, "L", "Custom texture path (choose \"Custom\" above)")
    local edit = UI.Edit(p, 100, 24, function(self) o.bgCustom = self:GetText(); paint() end)
    edit:HookScript("OnTextChanged", function(self, user)
        if user then o.bgCustom = self:GetText(); paint() end
    end)
    edit.Refresh = function(self) self:SetText(o.bgCustom or "") end
    Put(p, "L", edit, 8)
    Check(p, "L", "Show border and decorations", o, "border", paint)
    Check(p, "R", "Tile the custom texture", o, "bgTile", paint)

    Put(p, "R", UI.Slider(p, "Background opacity", 0, 100, 5, function() return o.alpha * 100 end,
        function(v) o.alpha = v / 100; paint() end, PercentFmt, 100), 6)
    Put(p, "R", UI.Slider(p, "Texture strength (grid, scanlines, grain)", 0, 200, 10, function() return o.texStrength * 100 end,
        function(v) o.texStrength = v / 100; paint() end, PercentFmt, 100), 6)
    Put(p, "R", colorRow, 6)
    Sync(p)

    Header(p, "Parts of the frame")
    Check(p, "L", "Include the tab strip", o, "includeTabs", apply)
    Check(p, "R", "Restyle the chat input box", o, "skinEdit", paint)
    Put(p, "L", UI.Slider(p, "Padding around the chat", 0, 20, 1, function() return o.padding end,
        function(v) o.padding = v; ns.Chatbox:UpdateDock() end, nil, 100), 6)
end

local function BuildEffects()
    local p = NewPage("effects", "Effects & Panel", "Effects & Panel", "Border glow, the left panel with emoji and online counts, and where the chat bar sits.")
    local o = ns.db.chatbox
    local paint = function() ns.Chatbox:Paint() end
    local apply = function() ns.Chatbox:Apply() end

    Label(p, "L", "Border glow")
    Put(p, "L", UI.Dropdown(p, 100, {
        { text = "Off", value = "OFF" },
        { text = "Style default", value = "STYLE" },
        { text = "Accent color", value = "ACCENT" },
        { text = "Rainbow", value = "RGB" },
        { text = "Custom color", value = "CUSTOM" },
    }, function() return o.glowMode end, function(v) o.glowMode = v; paint() end), 10)
    Put(p, "L", UI.Slider(p, "Glow strength", 0, 200, 10, function() return o.glowIntensity * 100 end,
        function(v) o.glowIntensity = v / 100; paint() end, PercentFmt, 100), 6)
    local row = CreateFrame("Frame", nil, p)
    row:SetSize(100, 26)
    local l = UI.Text(row, 12)
    l:SetPoint("LEFT", 0, 0)
    l:SetText(T("Custom glow color"))
    local sw = UI.Swatch(row, 20, function() return o.glowColor end, function(r, g, b)
        o.glowColor = { r, g, b }
        paint()
    end)
    sw:SetPoint("RIGHT", 0, 0)
    row.Refresh = function() sw:Refresh() end
    Put(p, "L", row, 6)
    Check(p, "L", "Pulsing glow", o, "glowPulse", paint)
    Check(p, "L", "Flash on whispers, guild and group messages", o, "flash", nil, "Flash",
        "The glow briefly flares up when a private, guild or group message arrives.")
    Check(p, "L", "Animated style effects", o, "animate", paint, "Animated style effects",
        "For example the scan line in the Cyberpunk style.")

    local rail = o.rail
    Put(p, "R", UI.Header(p, "Left panel", 100), 8)
    Check(p, "R", "Show the left panel", rail, "enabled", apply, "Left panel",
        "A column on the left side of the chatbox with the emoji picker and online counts.")
    Check(p, "R", "Emoji picker button", rail, "emoji", apply)
    Check(p, "R", "Messenger button (unread count)", rail, "dm", apply)
    Check(p, "R", "Friends online", rail, "friends", apply)
    Check(p, "R", "Guild members online", rail, "guild", apply, "Guild members online",
        "Only shown while you are in a guild.")
    Sync(p)

    Header(p, "Chat bar placement")
    Label(p, "L", "Chat bar")
    Put(p, "L", UI.Dropdown(p, 100, {
        { text = "Detached (free-floating)", value = "NONE" },
        { text = "Inside the chatbox: top", value = "TOP" },
        { text = "Inside the chatbox: bottom", value = "BOTTOM" },
        { text = "Inside the chatbox: left", value = "LEFT" },
        { text = "Inside the chatbox: right", value = "RIGHT" },
    }, function() return o.dock end, function(v) ns.Chatbox:SetDock(v) end), 8)
    Note(p, "L", "Docked, the bar wraps to the chat window's size and uses the chatbox as its background. Move it with the sliders or with the reposition button.", 64)

    local function moved() if ns.Chatbox:DockSide() then ns.Chatbox:AnchorBar(ns.Bar.frame) end end
    Put(p, "R", UI.Slider(p, "Docked bar: horizontal offset", -300, 300, 1, function() return o.dockX or 0 end,
        function(v) o.dockX = v; moved() end, nil, 100), 6)
    Put(p, "R", UI.Slider(p, "Docked bar: vertical offset", -300, 300, 1, function() return o.dockY or 0 end,
        function(v) o.dockY = v; moved() end, nil, 100), 8)
    Put(p, "R", UI.Button(p, "Reposition the bar (drag)", 170, 26, function() ns.Bar:SetMoveMode(true) end), 6)
    Put(p, "R", UI.Button(p, "Reset offset", 170, 26, function()
        o.dockX, o.dockY = 0, 0
        moved()
    end), 4)
end

---------------------------------------------------------------------------
-- Chat look (emoji, icons, colors, highlights)
---------------------------------------------------------------------------
local function CheckSwatch(p, side, label, tbl, after)
    local row = CreateFrame("Frame", nil, p)
    row:SetSize(100, 26)
    local c = UI.Check(row, label, function() return tbl.on end,
        function(v) tbl.on = v; after() end, nil, nil, 150)
    c:SetPoint("LEFT", 0, 0)
    local sw = UI.Swatch(row, 20, function() return tbl.color end, function(r, g, b)
        tbl.color[1], tbl.color[2], tbl.color[3] = r, g, b
        after()
    end)
    sw:SetPoint("RIGHT", 0, 0)
    row.Refresh = function() c:Refresh(); sw:Refresh() end
    return Put(p, side, row, 4)
end

local function BuildLooks()
    local p = NewPage("looks", "Chat Look", "Chat Look", "Emoji, icons, colors and highlighted players in your chat windows.")
    local o = ns.db.chatbox
    local h = o.highlight
    local rebuild = function() ns.Chatbox:RebuildHighlight() end

    Check(p, "L", "Emoji for :) ;) :D <3 ...", o, "emoji", nil, "Emoji",
        "Text smileys are replaced by pictures in chat and in the messenger. New messages only.")
    Check(p, "L", "Lone ) and ( count as :) and :(", o, "emojiLone", nil, "Lone brackets",
        "\"hello)\" becomes a smile and \"hello(\" a sad face. Brackets that belong together are left alone.")
    Put(p, "L", UI.Slider(p, "Emoji size", 12, 32, 1, function() return o.emojiSize end,
        function(v) o.emojiSize = v end, nil, 100), 8)
    Put(p, "L", UI.Check(p, "Show timestamps",
        function() return ns.Chatbox:TimestampsOn() end,
        function(v) ns.Chatbox:SetTimestamps(v) end,
        "Timestamps", "Shares the setting of the Chat page, where you can pick the format."), 4)
    Check(p, "L", "Disable class-colored names", o, "noClassColor", nil, "Disable class-colored names",
        "Removes class colors from player names in new messages.")
    Check(p, "L", "Class icons before names", o, "classIcons", nil, "Class icons",
        "Needs the class to be known: it is learned from the player's messages.")
    Check(p, "L", "Class icons in circles", o, "classIconsRound", function()
        if ns.Messenger then ns.Messenger:Refresh() end
    end, "Class icons in circles", "Round icons in chat and in the messenger. Evokers keep the square icon in chat.")
    Check(p, "L", "Item level in item links", o, "itemLevel", nil, "Item level in item links",
        "Shows the item level of linked weapons and armor: [Sword (489)]. Works once the game knows the item.")
    Check(p, "L", "Faction icons (Horde / Alliance)", o, "factionIcons", nil, "Faction icons",
        "Shown only when the faction can be identified (from the player's race).")

    Put(p, "R", UI.Header(p, "Highlight players", 100), 8)
    Check(p, "R", "Highlight messages of chosen players", h, "enabled", rebuild)
    CheckSwatch(p, "R", "Friends", h.friends, rebuild)
    CheckSwatch(p, "R", "Guild members", h.guild, rebuild)
    CheckSwatch(p, "R", "Party / raid members", h.group, rebuild)

    local row = CreateFrame("Frame", nil, p)
    row:SetSize(100, 26)
    local l = UI.Text(row, 12)
    l:SetPoint("LEFT", 0, 0)
    l:SetText("Color for the list below")
    local sw = UI.Swatch(row, 20, function() return h.custom.color end, function(r, g, b)
        h.custom.color[1], h.custom.color[2], h.custom.color[3] = r, g, b
        rebuild()
    end)
    sw:SetPoint("RIGHT", 0, 0)
    row.Refresh = function() sw:Refresh() end
    Put(p, "R", row, 6)

    Label(p, "R", "Players (one per line, optional color: Name #ff8800)")
    local edit = UI.MultiEdit(p, 100, 84, function(text) h.custom.text = text; rebuild() end)
    edit.Refresh = function(self) self:SetValue(h.custom.text) end
    Put(p, "R", edit, 6)
    Put(p, "R", UI.Button(p, "Add my target", 110, 24, function()
        ns.Chatbox:HighlightTarget(false)
        edit:SetValue(h.custom.text)
    end), 4)
end

---------------------------------------------------------------------------
-- Messenger
---------------------------------------------------------------------------
local function BuildMessenger()
    local p = NewPage("messenger", "Messenger", "Messenger", "Whispers and Battle.net chats in a messaging-app window, with saved history.")
    local o = ns.db.messenger
    local barRefresh = function() if ns.Bar and ns.Bar.frame then ns.Bar:Refresh() end end

    Check(p, "L", "Enable messenger", o, "enabled", barRefresh)
    Check(p, "L", "Show whispers here, not in chat", o, "hideInChat", nil, "Show whispers here, not in chat",
        "Private messages are removed from the chat window and only appear in the messenger.")
    Check(p, "L", "Include Battle.net whispers", o, "bnet")
    Check(p, "L", "Open for new whispers / reply key", o, "takeover", nil, "Open for new whispers / reply key",
        "Choosing Whisper on a name, or pressing the reply key, opens the messenger instead of the chat box.")
    Check(p, "L", "Open when a message arrives", o, "autoOpen")
    Check(p, "L", "Play a sound", o, "sound")
    Check(p, "L", "Chat notice with [Open] link", o, "notify", nil, "Chat notice",
        "Shown once per conversation while the messenger is closed.")

    Label(p, "R", "Keep history for")
    Put(p, "R", UI.Dropdown(p, 100, {
        { text = "This session only", value = 0 },
        { text = "1 day", value = 1 },
        { text = "3 days", value = 3 },
        { text = "7 days", value = 7 },
        { text = "14 days", value = 14 },
        { text = "30 days", value = 30 },
        { text = "90 days", value = 90 },
        { text = "Forever", value = 3650 },
    }, function() return o.retention end, function(v) o.retention = v; ns.Messenger:Prune(); ns.Messenger:Refresh() end), 10)
    Put(p, "R", UI.Slider(p, "Messages kept per conversation", 50, 1000, 50, function() return o.maxPerChat end,
        function(v) o.maxPerChat = v; ns.Messenger:Prune() end, nil, 100), 6)
    Put(p, "R", UI.Slider(p, "Message font size", 10, 20, 1, function() return o.fontSize end,
        function(v) o.fontSize = v; ns.Messenger:RenderMessages() end, nil, 100), 8)
    Put(p, "R", UI.Button(p, "Open messenger", 110, 28, function() ns.Messenger:Open() end, true), 6)
    Put(p, "R", UI.Button(p, "Delete all history...", 110, 26, function()
        StaticPopup_Show("ZTVCHAT_CLEARALL")
    end), 8)
    Sync(p)

    local info = UI.Text(p, 11, C.muted)
    info:SetPoint("TOPLEFT", p, "TOPLEFT", 24, -p.L.y - 8)
    info:SetPoint("TOPRIGHT", p, "TOPRIGHT", -24, -p.L.y - 8)
    info:SetWordWrap(true)
    info:SetJustifyV("TOP")
    info:SetText("History is stored as plain text in this character's saved variables. Messages are only collected while the messenger is enabled. In some fights and Mythic+ runs the game hides message text from addons; those messages stay in the normal chat window. Favorite conversations are never cleaned up automatically. Commands: /messenger [name]")
end

---------------------------------------------------------------------------
-- Spam filter
---------------------------------------------------------------------------
local function BuildSpam()
    local p = NewPage("spam", "Spam Filter", "Spam Filter", "Hide messages that contain blocked words or repeat themselves.")
    local o = ns.db.spam

    Check(p, "L", "Enable spam filter", o, "enabled")
    Check(p, "L", "Never filter friends, guild or me", o, "whitelist", nil,
        "Never filter friends, guild or me", "Friends, guildmates and your own messages always get through.")
    Check(p, "L", "Block repeated messages", o, "dedupe", nil,
        "Block repeated messages", "Hides the same message from the same player if it repeats within the time below.")
    Put(p, "L", UI.Slider(p, "Repeat window", 3, 60, 1, function() return o.dedupeSeconds end,
        function(v) o.dedupeSeconds = v end, function(v) return v .. " s" end, 100), 6)

    Label(p, "R", "Blocked this session")
    local count = UI.Text(p, 26)
    count:SetHeight(32)
    p.R:Add(count, 6)
    count.Refresh = function(self) self:SetText(tostring(ns.spamBlocked)) end
    p.widgets[#p.widgets + 1] = count
    local acc = 0
    p:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc > 0.5 then acc = 0; count:SetText(tostring(ns.spamBlocked)) end
    end)
    ns:OnTheme(function() count:SetTextColor(ns:GetAccent()) end)
    Put(p, "R", UI.Button(p, "Clear list", 110, 26, function()
        ns.Spam:SetText("")
        p.edit:SetValue("")
    end), 6)
    Sync(p)

    Header(p, "Blocked words and phrases (comma or line separated)")

    -- The list grows with the window height
    local edit = UI.MultiEdit(p, 100, 100, function(text) ns.Spam:SetText(text) end)
    edit.Refresh = function(self) self:SetValue(o.text) end
    edit:SetPoint("TOPLEFT", p, "TOPLEFT", 24, -p.L.y)
    edit:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -24, 70)
    p.widgets[#p.widgets + 1] = edit
    p.edit = edit

    local note = UI.Text(p, 11, C.muted)
    note:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 24, 16)
    note:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -24, 16)
    note:SetHeight(44)
    note:SetWordWrap(true)
    note:SetJustifyV("TOP")
    note:SetText("Matching ignores capitals and finds the text anywhere in a message. Applies to say, yell, emote, whispers, guild, party, raid, instance and channels. Quick commands: /spam add word, /spam remove word, /spam list.")
end

---------------------------------------------------------------------------
-- Fonts & bubbles
---------------------------------------------------------------------------
local function BuildFonts()
    local p = NewPage("fonts", "Fonts & Bubbles", "Fonts & Bubbles", "Change fonts and control chat bubbles.")
    local o = ns.db.chat
    local b = ns.db.bubbles

    Header(p, "Fonts")

    Label(p, "L", "Chat window font")
    Put(p, "L", UI.Dropdown(p, 100, function() return ns:GetFonts() end,
        function() return o.font end,
        function(v) o.font = v; ns.Features:ApplyChatFont() end), 8)
    Note(p, "L", "Only fonts the game can load are listed. Fonts from LibSharedMedia appear here too.", 44)

    Label(p, "R", "Chat bubble font")
    Put(p, "R", UI.Dropdown(p, 100, function() return ns:GetFonts() end,
        function() return b.font end,
        function(v) b.font = v; ns.Features:ApplyBubbleFont() end), 12)
    Put(p, "R", UI.Slider(p, "Chat bubble font size", 0, 40, 1, function() return b.size end,
        function(v) b.size = v; ns.Features:ApplyBubbleFont() end,
        function(v) return v == 0 and "Default" or tostring(math.max(8, v)) end, 100), 6)
    Sync(p)

    Header(p, "Chat bubbles in instances")
    Check(p, "L", "Hide chat bubbles in instances", b, "disable", function() ns.Instances:Update() end,
        "Hide chat bubbles in instances", "Your own bubble setting is restored when you leave.")
    Note(p, "L", "Choose where bubbles are hidden on the right.", 30)
    Check(p, "R", "Dungeons", b.types, "party", function() ns.Instances:Update() end)
    Check(p, "R", "Raids", b.types, "raid", function() ns.Instances:Update() end)
    Check(p, "R", "Battlegrounds", b.types, "pvp", function() ns.Instances:Update() end)
    Check(p, "R", "Arenas", b.types, "arena", function() ns.Instances:Update() end)
end

---------------------------------------------------------------------------
-- General
---------------------------------------------------------------------------
local function BuildGeneral()
    local p = NewPage("general", "General", "General", "Shortcuts, the !key helper and commands.")

    Put(p, "L", UI.Button(p, "Open copy window", 100, 28, function() ns.Copy:Open() end, true), 8)
    Put(p, "R", UI.Button(p, "Show / hide chat bar", 100, 28, function()
        ns.db.bar.visible = not ns.db.bar.visible
        ns.Bar:Refresh()
    end), 8)
    Sync(p)

    Label(p, "L", "Language")
    Put(p, "L", UI.Dropdown(p, 100, {
        { text = "English", value = "en" },
        { text = "Русский", value = "ru" },
        { text = "Deutsch", value = "de" },
    }, function() return ns.db.language end, function(v)
        ns.db.language = v
        StaticPopup_Show("ZTVCHAT_RELOAD", T("The language changes after reloading the interface. Reload now?"))
    end), 8)
    Sync(p)

    if ns.Key:IsAvailable() then Check(p, "L", "Answer !key requests", ns.db.key, "enabled", nil,
        "Answer !key requests", "When someone types !key in party, raid, guild or instance chat, your keystone is posted back. Nothing is sent while the game locks addon chat (boss fights, Mythic+, PvP).") end
    Put(p, "R", UI.Button(p, "Reset all settings...", 100, 26, function()
        StaticPopup_Show("ZTVCHAT_RESET")
    end), 8)
    Sync(p)

    Header(p, "Commands")
    local cmds = UI.Text(p, 12)
    cmds:SetPoint("TOPLEFT", p, "TOPLEFT", 24, -p.L.y)
    cmds:SetPoint("TOPRIGHT", p, "TOPRIGHT", -24, -p.L.y)
    cmds:SetWordWrap(true)
    cmds:SetJustifyV("TOP")
    cmds:SetSpacing(5)
    local lines = {
        "/ztv  -  open settings (also /chathelper and /freechat)",
        "/ztv reset  -  reset all settings",
        "/chatbox  -  chatbox settings;  /messenger [name]  -  open the messenger",
        "/ztvhl [target | add name | remove name | list]  -  highlighted players",
        "/copy [add | clear | show]  -  copy window",
        "/spam [add word | remove word | list | on | off]  -  spam filter",
        "/key  -  ask the group for keystones",
        "/boommove (or /boomlock)  -  reposition mode for the chat bar",
        "/boomchat /boomrotate /boomtext  -  toggle bar, layout, letters",
        "/boomsize n /boomup n /boomdown n /boomreset  -  size and position",
        "/hidereidchaton /hidereidchatoff  -  bubbles in instances",
    }
    for i, line in ipairs(lines) do lines[i] = T(line) end
    cmds:SetText(table.concat(lines, "\n"))
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function PaintNav(nb)
    local selected = (current == nb.key)
    local r, g, b = ns:GetAccent()
    if selected then
        nb.bg:SetColorTexture(r, g, b, 0.16)
    elseif nb.hover then
        nb.bg:SetColorTexture(1, 1, 1, 0.05)
    else
        nb.bg:SetColorTexture(0, 0, 0, 0)
    end
    nb.bar:SetColorTexture(r, g, b, 1)
    nb.bar:SetShown(selected)
    if selected then nb.text:SetTextColor(1, 1, 1) else nb.text:SetTextColor(unpack(C.muted)) end
end

function Config:ShowPage(key)
    for _, p in pairs(pages) do p:Hide() end
    current = pages[key] and key or "appearance"
    pages[current]:Show()
    for _, nb in ipairs(navs) do PaintNav(nb) end
end

function Config:Build()
    if win then return end
    local ui = ns.db.ui
    win = CreateFrame("Frame", "ZamestoTVChatConfig", UIParent, "BackdropTemplate")
    win:SetSize(math.max(MIN_W, math.min(MAX_W, ui.w)), math.max(MIN_H, math.min(MAX_H, ui.h)))
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:SetResizable(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    if win.SetResizeBounds then
        win:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    elseif win.SetMinResize then
        win:SetMinResize(MIN_W, MIN_H)
        win:SetMaxResize(MAX_W, MAX_H)
    end
    UI.Flat(win, C.bg, C.border)
    tinsert(UISpecialFrames, "ZamestoTVChatConfig")

    win.top = win:CreateTexture(nil, "OVERLAY")
    win.top:SetPoint("TOPLEFT", 1, -1)
    win.top:SetPoint("TOPRIGHT", -1, -1)
    win.top:SetHeight(2)

    local side = CreateFrame("Frame", nil, win, "BackdropTemplate")
    side:SetPoint("TOPLEFT", 1, -3)
    side:SetPoint("BOTTOMLEFT", 1, 1)
    side:SetWidth(170)
    UI.Flat(side, C.side, { 0, 0, 0, 0 })

    local title = UI.Text(side, 16)
    title:SetPoint("TOPLEFT", 18, -20)
    title:SetText("Chat Helper")
    local version = UI.Text(side, 11, C.muted)
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    version:SetText(T("Version") .. " " .. (getMeta and getMeta(ADDON, "Version") or "?"))

    content = CreateFrame("Frame", nil, win)
    content:SetPoint("TOPLEFT", 171, -3)
    content:SetPoint("BOTTOMRIGHT", -1, 1)

    BuildAppearance()
    BuildBar()
    BuildChatbox()
    BuildEffects()
    BuildLooks()
    BuildMessenger()
    BuildChat()
    BuildSpam()
    BuildFonts()
    BuildGeneral()

    for i, entry in ipairs(order) do
        local nb = CreateFrame("Button", nil, side)
        nb:SetSize(168, 32)
        nb:SetPoint("TOPLEFT", 1, -76 - (i - 1) * 34)
        nb.key = entry.key
        nb.bg = nb:CreateTexture(nil, "BACKGROUND")
        nb.bg:SetAllPoints()
        nb.bar = nb:CreateTexture(nil, "OVERLAY")
        nb.bar:SetPoint("TOPLEFT")
        nb.bar:SetPoint("BOTTOMLEFT")
        nb.bar:SetWidth(3)
        nb.text = UI.Text(nb, 13)
        nb.text:SetPoint("LEFT", 18, 0)
        nb.text:SetText(T(entry.name))
        nb:SetScript("OnEnter", function(self) self.hover = true; PaintNav(self) end)
        nb:SetScript("OnLeave", function(self) self.hover = false; PaintNav(self) end)
        nb:SetScript("OnClick", function(self) Config:ShowPage(self.key) end)
        navs[i] = nb
    end

    local close = CreateFrame("Button", nil, win)
    close:SetSize(30, 30)
    close:SetPoint("TOPRIGHT", -8, -8)
    close.text = UI.Text(close, 20, C.muted)
    close.text:SetPoint("CENTER", 0, 1)
    close.text:SetText("×")
    close:SetScript("OnClick", function() win:Hide() end)
    close:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.35, 0.35) end)
    close:SetScript("OnLeave", function(self) self.text:SetTextColor(unpack(C.muted)) end)

    -- Resize grip (bottom-right corner); the size is remembered
    local grip = CreateFrame("Button", nil, win)
    grip:SetSize(18, 18)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel(win:GetFrameLevel() + 20)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetScript("OnMouseDown", function() win:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        win:StopMovingOrSizing()
        ns.db.ui.w, ns.db.ui.h = math.floor(win:GetWidth() + 0.5), math.floor(win:GetHeight() + 0.5)
    end)
    UI.Tip(grip, "Resize", "Drag to resize. Double-click to restore the default size.")
    grip:SetScript("OnDoubleClick", function()
        win:SetSize(ns.defaults.ui.w, ns.defaults.ui.h)
        ns.db.ui.w, ns.db.ui.h = ns.defaults.ui.w, ns.defaults.ui.h
    end)

    ns:OnTheme(function()
        win.top:SetColorTexture(ns:GetAccent())
        title:SetTextColor(ns:GetAccent())
        for _, nb in ipairs(navs) do PaintNav(nb) end
    end)
end

function Config:Open(key)
    self:Build()
    win:Show()
    self:ShowPage(key or current or "appearance")
end

function Config:Toggle()
    if win and win:IsShown() then win:Hide() else self:Open() end
end

function Config:OnInit()
    StaticPopupDialogs["ZTVCHAT_RESET"] = {
        text = T("Reset all Chat Helper settings and reload the UI?"),
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            wipe(ZamestoTVChatDB)
            ZamestoTVChatDB.migrated = true
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopupDialogs["ZTVCHAT_RELOAD"] = {
        text = "%s",
        button1 = YES,
        button2 = NO,
        OnAccept = function() ReloadUI() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    SLASH_ZTVCONFIG1 = "/ztv"
    SLASH_ZTVCONFIG2 = "/chathelper"
    SLASH_ZTVCONFIG3 = "/freechat"
    SlashCmdList["ZTVCONFIG"] = function(msg)
        msg = (msg or ""):lower():match("^%s*(.-)%s*$")
        if msg == "reset" then
            StaticPopup_Show("ZTVCHAT_RESET")
        elseif KEYS[msg] then
            Config:Open(msg)
        else
            Config:Toggle()
        end
    end
end
