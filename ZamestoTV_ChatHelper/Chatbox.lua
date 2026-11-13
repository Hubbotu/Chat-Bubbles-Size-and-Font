local ADDON, ns = ...
local UI = ns.UI
local Box = ns:NewModule("Chatbox")
local issecret = ns.IsSecret
local T = ns.T

local WHITE = "Interface\\Buttons\\WHITE8X8"
local EMOJI_DIR = "Interface\\AddOns\\" .. ADDON .. "\\emoji\\"
local EDIT_ROW = 30 -- space reserved for the chat input row when the bar is docked at the bottom

local strlenutf8 = _G.strlenutf8 or string.len

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function Debounced(fn, delay) return ns.Debounce(fn, delay or 0.1) end

-- Makes a Blizzard texture invisible and keeps it that way even when
-- Blizzard code later fades or re-shows it.
local function Suppress(t, on)
    if not t or not t.SetAlpha then return end
    if not on and not t.ztvHooked then return end -- never touched, nothing to restore
    if on and not t.ztvHide then t.ztvOrig = t:GetAlpha() end
    t.ztvHide = on and true or false
    if not t.ztvHooked then
        t.ztvHooked = true
        hooksecurefunc(t, "SetAlpha", function(self, a)
            if self.ztvHide and a ~= 0 and not self.ztvBusy then
                self.ztvBusy = true
                self:SetAlpha(0)
                self.ztvBusy = false
            end
        end)
    end
    t.ztvBusy = true
    t:SetAlpha(on and 0 or (t.ztvOrig or 1))
    t.ztvBusy = false
end

---------------------------------------------------------------------------
-- Geometry: wraps ChatFrame1 (+ its tab strip) and makes room for a docked bar
---------------------------------------------------------------------------
function Box:DockSide()
    local o = ns.db and ns.db.chatbox
    if o and o.enabled and o.dock and o.dock ~= "NONE" and _G.ChatFrame1 then return o.dock end
end

-- Width of Blizzard's own button column (left of the chat), when it is visible.
local function SideButtonsWidth()
    local bf = _G.ChatFrame1ButtonFrame
    if bf and bf:IsShown() and bf:GetWidth() then return bf:GetWidth() end
    return 0
end

Box.SideButtonsWidth = SideButtonsWidth

-- Left panel (emoji / friends / guild): the chatbox grows to the left to hold it.
function Box:RailWidth()
    local o = ns.db and ns.db.chatbox
    if o and o.enabled and o.rail and o.rail.enabled then return o.rail.width or 38 end
    return 0
end

-- Distance between the chat window's left edge and the outside of the panel.
function Box:LeftBase()
    local rw = self:RailWidth()
    if rw > 0 then return rw + SideButtonsWidth() end
    return 0
end

function Box:Anchor()
    local f, cf = self.frame, _G.ChatFrame1
    if not f or not cf then return end
    local o = ns.db.chatbox
    local top = (o.includeTabs and _G.GeneralDockManager) or cf
    local pad = o.padding
    local e = self.ext or { 0, 0, 0, 0 }
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", top, "TOPLEFT", -pad - e[1], pad + e[2])
    f:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", pad + e[3], -pad - e[4])
    local s = cf:GetScale()
    if s and s > 0 and math.abs(f:GetScale() - s) > 0.001 then f:SetScale(s) end
    if self.LayoutRail then self:LayoutRail() end
end

function Box:UpdateDock()
    if not self.frame then return end
    local side = self:DockSide()
    local bar = ns.Bar and ns.Bar.frame
    local e = { self:LeftBase(), 0, 0, 0 } -- left, top, right, bottom extension
    if side and bar and ns.db.bar.visible then
        local k = bar:GetEffectiveScale() / self.frame:GetEffectiveScale()
        local w, h = bar:GetWidth() * k, bar:GetHeight() * k
        if side == "BOTTOM" then e[4] = EDIT_ROW + h
        elseif side == "TOP" then e[2] = h
        elseif side == "LEFT" then e[1] = self:LeftBase() + w + (self:RailWidth() > 0 and 0 or SideButtonsWidth())
        elseif side == "RIGHT" then e[3] = w end
    end
    self.ext = e
    self:Anchor()
    if self.st and self.frame:IsShown() then self:Paint() end
end

-- Space (in the bar's units) the docked bar may use before it wraps.
function Box:DockSpace()
    local cf, bar = _G.ChatFrame1, ns.Bar and ns.Bar.frame
    if not cf then return end
    local k = bar and (cf:GetEffectiveScale() / bar:GetEffectiveScale()) or 1
    return (cf:GetWidth() or 0) * k, (cf:GetHeight() or 0) * k
end

function Box:AnchorBar(bar)
    local cf, o = _G.ChatFrame1, ns.db.chatbox
    local side = self:DockSide()
    if not cf or not side then return false end
    local top = (o.includeTabs and _G.GeneralDockManager) or cf
    local pad = o.padding
    local u = self.frame:GetEffectiveScale() / bar:GetEffectiveScale()
    local ox, oy = (o.dockX or 0) * u, (o.dockY or 0) * u   -- user offset (drag or sliders)
    bar:ClearAllPoints()
    if side == "BOTTOM" then
        bar:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", ox, -(pad + EDIT_ROW) * u + oy)
    elseif side == "TOP" then
        bar:SetPoint("BOTTOMLEFT", top, "TOPLEFT", ox, pad * u + oy)
    elseif side == "LEFT" then
        local off = self:LeftBase() + (self:RailWidth() > 0 and 0 or SideButtonsWidth())
        bar:SetPoint("TOPRIGHT", cf, "TOPLEFT", -(pad + off) * u + ox, oy)
    else
        bar:SetPoint("TOPLEFT", cf, "TOPRIGHT", pad * u + ox, oy)
    end
    return true
end

function Box:SetDock(side)
    ns.db.chatbox.dock = side
    self:Apply()
end

---------------------------------------------------------------------------
-- Blizzard's own chat textures and edit box
---------------------------------------------------------------------------
local FALLBACK_TEXTURES = {
    "Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture",
    "BottomRightTexture", "LeftTexture", "RightTexture", "BottomTexture", "TopTexture",
}
local EDIT_PARTS = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }

function Box:SkinFrames()
    local on = ns.db.chatbox.enabled
    local suffixes = _G.CHAT_FRAME_TEXTURES or FALLBACK_TEXTURES
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf then
            local hide = on and (cf == _G.ChatFrame1 or cf.isDocked) and true or false
            for _, suffix in ipairs(suffixes) do Suppress(_G["ChatFrame" .. i .. suffix], hide) end
            if cf.Background then Suppress(cf.Background, hide) end
        end
    end
    self:PaintEditBoxes()
end

function Box:PaintEditBoxes()
    local o = ns.db.chatbox
    local on = o.enabled and o.skinEdit
    local ar, ag, ab = ns:GetAccent()
    local b = self:EditBorder()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then
            local name = eb:GetName()
            for _, part in ipairs(EDIT_PARTS) do Suppress(_G[name .. part], on and true or false) end
            if on and not eb.ztvBack then
                local back = CreateFrame("Frame", nil, eb, "BackdropTemplate")
                back:SetPoint("TOPLEFT", eb, "TOPLEFT", 2, -3)
                back:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", -2, 3)
                back:SetFrameLevel(math.max(0, eb:GetFrameLevel() - 1))
                back:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
                eb.ztvBack = back
            end
            if eb.ztvBack then
                eb.ztvBack:SetShown(on and true or false)
                if on then
                    local base = o.color or self:StyleColor()
                    eb.ztvBack:SetBackdropColor(base[1] * 0.6, base[2] * 0.6, base[3] * 0.6, math.max(0.6, o.alpha))
                    eb.ztvBack:SetBackdropBorderColor(b[1], b[2], b[3], math.max(0.35, b[4]))
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Timestamps (shares the setting with the Chat page)
---------------------------------------------------------------------------
local function BlizzardStampsOn()
    local c = GetCVar and GetCVar("showTimestamps")
    return c ~= nil and c ~= "none" and c ~= "0" and c ~= ""
end

function Box:TimestampsOn()
    local v = ns.db.chat.timestamps
    if v == "DEFAULT" then return BlizzardStampsOn() end
    return v ~= "none"
end

function Box:SetTimestamps(on)
    local c = ns.db.chat
    if on then
        if c.timestamps == "DEFAULT" and BlizzardStampsOn() then return end
        if c.timestamps == "none" or c.timestamps == "DEFAULT" then c.timestamps = "%H:%M " end
    else
        c.timestamps = "none"
    end
    ns.Features:ApplyTimestamps()
end

---------------------------------------------------------------------------
-- Plain-text walker: runs fn on the parts of a chat line that are not
-- links, colors or textures, and keeps everything else untouched.
---------------------------------------------------------------------------
local function MapPlain(text, fn)
    local out, pos, n = {}, 1, #text
    while pos <= n do
        local bar = text:find("|", pos, true)
        if not bar then
            out[#out + 1] = fn(text:sub(pos))
            break
        end
        if bar > pos then out[#out + 1] = fn(text:sub(pos, bar - 1)) end
        local c = text:sub(bar + 1, bar + 1)
        local stop
        if c == "H" then
            local h1 = text:find("|h", bar + 2, true)
            local h2 = h1 and text:find("|h", h1 + 2, true)
            stop = h2 and (h2 + 1) or n
        elseif c == "c" then
            stop = bar + 9
        elseif c == "T" or c == "A" or c == "K" then
            local t = text:find("|" .. c:lower(), bar + 2, true)
            stop = t and (t + 1) or n
        else
            stop = bar + 1
        end
        out[#out + 1] = text:sub(bar, stop)
        pos = stop + 1
    end
    return table.concat(out)
end

---------------------------------------------------------------------------
-- Emoji
---------------------------------------------------------------------------
-- picker contents: { file name, text inserted into the message }
Box.emojiFaces = {
    { "smile", ":)" }, { "happy", "^_^" }, { "grin", ":D" }, { "laugh", "xD" }, { "wink", ";)" },
    { "sad", ":(" }, { "cry", ":'(" }, { "tongue", ":P" }, { "surprised", ":O" }, { "neutral", ":|" },
    { "confused", ":/" }, { "angry", ">:(" }, { "cool", "B-)" }, { "kiss", ":*" },
    { "sleepy", ":sleepy:" }, { "sweat", ":sweat:" }, { "devil", ":devil:" }, { "angel", ":angel:" },
}
Box.emojiSymbols = {
    { "heart", "<3" }, { "heart_blue", ":heart_blue:" }, { "heart_green", ":heart_green:" },
    { "heart_yellow", ":heart_yellow:" }, { "heart_purple", ":heart_purple:" }, { "broken", "</3" },
    { "star", ":star:" }, { "fire", ":fire:" }, { "skull", ":skull:" }, { "check", ":check:" },
    { "cross", ":cross:" }, { "question", ":question:" }, { "exclaim", ":exclaim:" },
}
local EMOJI_KEYS = {}
for _, list in ipairs({ Box.emojiFaces, Box.emojiSymbols }) do
    for _, e in ipairs(list) do EMOJI_KEYS[e[1]] = true end
end

local EMOTICONS = {
    [":)"] = "smile", [":-)"] = "smile", ["=)"] = "smile", [":]"] = "smile", ["(:"] = "smile",
    ["^_^"] = "happy", ["^^"] = "happy", ["^-^"] = "happy",
    [":D"] = "grin", [":-D"] = "grin", ["=D"] = "grin", [":d"] = "grin",
    ["xD"] = "laugh", ["XD"] = "laugh", ["xd"] = "laugh", ["Xd"] = "laugh",
    [";)"] = "wink", [";-)"] = "wink",
    [":("] = "sad", [":-("] = "sad", ["=("] = "sad", [":["] = "sad", ["):"] = "sad",
    [":'("] = "cry", [";("] = "cry", [";_;"] = "cry", ["T_T"] = "cry", ["T.T"] = "cry",
    [":P"] = "tongue", [":p"] = "tongue", [":-P"] = "tongue", [":-p"] = "tongue", ["=P"] = "tongue",
    [":O"] = "surprised", [":o"] = "surprised", [":-O"] = "surprised", [":0"] = "surprised",
    [":|"] = "neutral", [":-|"] = "neutral", ["-_-"] = "neutral",
    [":/"] = "confused", [":-/"] = "confused", [":\\"] = "confused", [":-\\"] = "confused",
    ["8-)"] = "cool", ["B-)"] = "cool",
    [":*"] = "kiss", [":-*"] = "kiss",
    [">:("] = "angry", [">:-("] = "angry", [":@"] = "angry", [">:["] = "angry",
    ["<3"] = "heart", ["</3"] = "broken",
}
local GLUE_FIRST = { [":"] = true, [";"] = true, ["="] = true, ["<"] = true, [">"] = true }

local function Tag(key)
    local size = ns.db.chatbox.emojiSize
    return "|T" .. EMOJI_DIR .. key .. ".tga:" .. size .. ":" .. size .. "|t"
end

local function Count(s, pat)
    local _, n = s:gsub(pat, "")
    return n
end

local lineDepth = 0 -- open brackets so far in this chat line (color codes split a line into runs)

local function EmojiRun(seg)
    if seg == "" or not seg:find("[%)%(:;=<>%^_%-xXTB%*@]") then return seg end
    local lone = ns.db.chatbox.emojiLone
    local depth = lineDepth
    local res = (seg:gsub("()(%S+)()", function(_, word, after)
        local key = EMOTICONS[word]
        if key then return Tag(key) end
        local code = word:match("^:([%w_]+):$")
        if code and EMOJI_KEYS[code] then return Tag(code) end

        -- stretched forms: :DDD  xDDD  :))))  :(((
        if word:match("^[:=;]%-?[Dd][Dd]+$") then return Tag("grin") end
        if word:match("^[xX][Dd][Dd]+$") then return Tag("laugh") end
        local first = word:sub(1, 1)
        if GLUE_FIRST[first] then
            if word:match("^[:=]%-?%)+$") then return Tag(Count(word, "%)") > 1 and "laugh" or "smile") end
            if word:match("^[:=]%-?%(+$") then return Tag("sad") end
        end

        -- emoticon glued to the end of a word: "thanks:)"
        local base, tail = word:match("^(.-)[:=]%-?(%)+)$")
        if base and base ~= "" then return base .. Tag(#tail > 1 and "laugh" or "smile") end
        base = word:match("^(.-)[:=]%-?%(+$")
        if base and base ~= "" then return base .. Tag("sad") end
        for n = 4, 2, -1 do
            if #word > n then
                local suf = word:sub(-n)
                local k = EMOTICONS[suf]
                if k and GLUE_FIRST[suf:sub(1, 1)] then return word:sub(1, -n - 1) .. Tag(k) end
            end
        end

        -- a lone ")" or "(" at the end of a word: "hello)"  "hello("
        if lone then
            local b, t = word:match("^(.-)(%)+)$")
            if t then
                local d = depth + Count(b, "%(") - Count(b, "%)")
                local marker = b ~= "" and (b:match("^%d+$") or strlenutf8(b) <= 1)
                if d <= 0 and not marker then
                    depth = 0
                    return b .. Tag(#t > 1 and "laugh" or "smile")
                end
                depth = math.max(0, d - #t)
                return nil
            end
            local b2 = word:match("^(.-)%(+$")
            if b2 and depth + Count(b2, "%(") - Count(b2, "%)") <= 0 and not seg:find("%)", after) then
                return b2 .. Tag("sad")
            end
        end
        depth = math.max(0, depth + Count(word, "%(") - Count(word, "%)"))
        return nil
    end))
    lineDepth = depth
    return res
end

function Box:Emojify(text)
    if type(text) ~= "string" or text == "" then return text end
    if not text:find("[%)%(:;=<>%^_%-xXTB%*@]") then return text end
    lineDepth = 0
    return MapPlain(text, EmojiRun)
end

---------------------------------------------------------------------------
-- Who is this player?  (class, faction, friend / guild / group)
---------------------------------------------------------------------------
local RACE_FACTION = {
    Human = "Alliance", Dwarf = "Alliance", NightElf = "Alliance", Gnome = "Alliance",
    Draenei = "Alliance", Worgen = "Alliance", VoidElf = "Alliance", LightforgedDraenei = "Alliance",
    DarkIronDwarf = "Alliance", KulTiran = "Alliance", Mechagnome = "Alliance",
    Orc = "Horde", Scourge = "Horde", Tauren = "Horde", Troll = "Horde", BloodElf = "Horde",
    Goblin = "Horde", Nightborne = "Horde", HighmountainTauren = "Horde", MagharOrc = "Horde",
    ZandalariTroll = "Horde", Vulpera = "Horde",
    -- Pandaren, Dracthyr, Earthen and similar races can be either: resolved some other way
}

Box.RaceFaction = RACE_FACTION

local info, infoCount = {}, 0
local friendSet, custom = {}, {}
local playerShort

local function KeyOf(name)
    return (Ambiguate(name, "none") or name):lower()
end

-- Lines that are not written by a player (loot, currency, system, NPCs ...) are never
-- turned into emoji. A filter on those events raises the flag for the line that follows.
local skipEmoji = false
local function SkipFilter()
    if not skipEmoji then
        skipEmoji = true
        C_Timer.After(0, function() skipEmoji = false end)
    end
    return false
end
local SKIP_EVENTS = {
    "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT", "CHAT_MSG_CURRENCY", "CHAT_MSG_MONEY", "CHAT_MSG_SKILL",
    "CHAT_MSG_TRADESKILLS", "CHAT_MSG_OPENING", "CHAT_MSG_PET_INFO", "CHAT_MSG_COMBAT_XP_GAIN",
    "CHAT_MSG_COMBAT_HONOR_GAIN", "CHAT_MSG_COMBAT_FACTION_CHANGE", "CHAT_MSG_COMBAT_MISC_INFO",
    "CHAT_MSG_COMBAT_GUILD_XP_GAIN", "CHAT_MSG_ACHIEVEMENT", "CHAT_MSG_GUILD_ACHIEVEMENT",
    "CHAT_MSG_TARGETICONS", "CHAT_MSG_BG_SYSTEM_NEUTRAL", "CHAT_MSG_BG_SYSTEM_ALLIANCE",
    "CHAT_MSG_BG_SYSTEM_HORDE", "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE",
    "CHAT_MSG_MONSTER_WHISPER", "CHAT_MSG_MONSTER_PARTY", "CHAT_MSG_RAID_BOSS_EMOTE",
    "CHAT_MSG_RAID_BOSS_WHISPER", "CHAT_MSG_IGNORED", "CHAT_MSG_BN_INLINE_TOAST_ALERT",
}

-- A line that links a game object but has no player in it is a game message, not chat.
local OBJECT_LINKS = {
    currency = true, item = true, spell = true, achievement = true, quest = true, enchant = true,
    talent = true, trade = true, battlepet = true, mount = true, transmogappearance = true,
    transmogillusion = true, azessence = true, conduit = true, garrfollower = true, unit = true,
}
local function IsGameLine(text)
    if text:find("|Hplayer:", 1, true) or text:find("|HBNplayer:", 1, true) then return false end
    for kind in text:gmatch("|H(%a+):") do
        if OBJECT_LINKS[kind] then return true end
    end
    return false
end

local function Learn(self, event, msg, author, ...)
    skipEmoji = false -- a player wrote this one
    if not author or issecret(author) or author == "" then return false end
    local ok, err = pcall(function(...)
        local key = KeyOf(author)
        local e = info[key]
        if not e then
            if infoCount > 600 then wipe(info); infoCount = 0 end
            e = {}
            info[key] = e
            infoCount = infoCount + 1
        end
        local short = Ambiguate(author, "short")
        local guid = select(10, ...)
        if guid and not issecret(guid) and type(guid) == "string" and guid ~= "" then
            if e.guid ~= guid then
                local ok2, _, class, _, race = pcall(GetPlayerInfoByGUID, guid)
                if ok2 and class then
                    e.class = class
                    e.race = race
                    e.faction = RACE_FACTION[race] or e.faction
                end
                e.guid = guid
            end
            if C_FriendList and C_FriendList.IsFriend then
                e.friend = C_FriendList.IsFriend(guid) and true or false
            end
            if IsGuildMember then e.guild = IsGuildMember(guid) and true or false end
        end
        if not e.faction and not e.factionTried then
            e.factionTried = true
            if short:lower() == playerShort then
                e.faction = UnitFactionGroup("player")
            else
                local ok3, f = pcall(UnitFactionGroup, short)
                if ok3 and (f == "Alliance" or f == "Horde") then e.faction = f end
            end
        end
        e.group = (UnitInParty(short) or UnitInRaid(short)) and true or false
    end, ...)
    return false
end

function Box:RebuildFriends()
    wipe(friendSet)
    pcall(function()
        local FL = C_FriendList
        if FL and FL.GetNumFriends and FL.GetFriendInfoByIndex then
            for i = 1, FL.GetNumFriends() do
                local fi = FL.GetFriendInfoByIndex(i)
                if fi and fi.name then friendSet[Ambiguate(fi.name, "short"):lower()] = true end
            end
        end
        if C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends then
            for i = 1, (BNGetNumFriends()) do
                local a = C_BattleNet.GetFriendAccountInfo(i)
                local g = a and a.gameAccountInfo
                if g and g.characterName and g.characterName ~= "" then
                    friendSet[g.characterName:lower()] = true
                end
            end
        end
    end)
end

function Box:RebuildHighlight()
    wipe(custom)
    local h = ns.db.chatbox.highlight
    local def = h.custom.color
    for raw in (h.custom.text or ""):gmatch("[^\n,;]+") do
        local line = raw:match("^%s*(.-)%s*$")
        if line ~= "" then
            local name, hex = line:match("^(.-)%s*[=#%s]%s*#?(%x%x%x%x%x%x)$")
            if not name or name == "" then name, hex = line, nil end
            local color = def
            if hex then
                color = {
                    tonumber(hex:sub(1, 2), 16) / 255,
                    tonumber(hex:sub(3, 4), 16) / 255,
                    tonumber(hex:sub(5, 6), 16) / 255,
                }
            end
            custom[name:lower()] = color
        end
    end
end

local function HighlightColor(name, e)
    local h = ns.db.chatbox.highlight
    if not h.enabled then return end
    local short = Ambiguate(name, "short"):lower()
    if short == playerShort then return end
    local c = custom[KeyOf(name)] or custom[short]
    if c then return c end
    if h.friends.on and ((e and e.friend) or friendSet[short]) then return h.friends.color end
    if h.guild.on and e and e.guild then return h.guild.color end
    if h.group.on and e and e.group then return h.group.color end
end

function Box:HighlightTarget(remove)
    local name = UnitName("target")
    if not name or not UnitIsPlayer("target") then
        ns:Print("Target a player first.")
        return
    end
    local h = ns.db.chatbox.highlight
    local lines, found = {}, false
    for raw in (h.custom.text or ""):gmatch("[^\n,;]+") do
        local line = raw:match("^%s*(.-)%s*$")
        if line ~= "" then
            local n = line:match("^(.-)%s*[=#%s]%s*#?%x%x%x%x%x%x$") or line
            if n:lower() == name:lower() then found = true
            else lines[#lines + 1] = line end
        end
    end
    if remove then
        if not found then ns:Print(string.format(T("%s is not on the highlight list."), name)) return end
    else
        if found then ns:Print(string.format(T("%s is already on the highlight list."), name)) return end
        lines[#lines + 1] = name
        h.enabled = true
    end
    h.custom.text = table.concat(lines, "\n")
    self:RebuildHighlight()
    ns:Print(string.format(remove and T("%s removed from the highlight list.") or T("%s added to the highlight list."), name))
end

---------------------------------------------------------------------------
-- Chat line processing (runs for every line a chat window receives)
---------------------------------------------------------------------------
local function StripNameColors(text)
    if not text:find("|Hplayer:", 1, true) then return text end
    return (text:gsub("(|Hplayer:[^|]*|h)(.-)(|h)", function(a, b, c)
        b = b:gsub("|c%x%x%x%x%x%x%x%x", "")
        b = b:gsub("|r", "")
        return a .. b .. c
    end))
end

local CIRCLE_MISSING = { EVOKER = true } -- not on Blizzard's round icon sheet
local function ClassIcon(class, size, round)
    local t = _G.CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if not t then return "" end
    local file = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
    if round and not CIRCLE_MISSING[class] then file = "Interface\\TargetingFrame\\UI-Classes-Circles" end
    return string.format("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t ", file, size, size,
        math.floor(t[1] * 256 + 0.5), math.floor(t[2] * 256 + 0.5),
        math.floor(t[3] * 256 + 0.5), math.floor(t[4] * 256 + 0.5))
end

local function FactionIcon(faction, size)
    if faction ~= "Alliance" and faction ~= "Horde" then return "" end
    return string.format("|TInterface\\PVPFrame\\PVP-Currency-%s:%d:%d|t ", faction, size, size)
end
Box.ClassIcon, Box.FactionIcon = ClassIcon, FactionIcon

local function Recolor(rest, color)
    local hex = "|cff" .. ns.Hex(color[1], color[2], color[3])
    return hex .. (rest:gsub("|r", "|r" .. hex)) .. "|r"
end

local function Decorate(text, cf)
    local o = ns.db.chatbox
    local s, e, name = text:find("|Hplayer:([^|:]+)")
    if not s then return text end
    local headEnd = text:find("|h", e + 1, true)
    local linkEnd = headEnd and text:find("|h", headEnd + 2, true)
    if not linkEnd then return text end

    local entry = info[KeyOf(name)]
    local icons = ""
    if (o.factionIcons or o.classIcons) and entry then
        local size = 14
        if cf and cf.GetFont then
            local _, fs = cf:GetFont()
            if fs then size = math.max(10, math.floor(fs + 0.5)) end
        end
        if o.factionIcons and entry.faction then icons = FactionIcon(entry.faction, size) end
        if o.classIcons and entry.class then icons = icons .. ClassIcon(entry.class, size, o.classIconsRound) end
    end

    local rest = text:sub(linkEnd + 2)
    local color = HighlightColor(name, entry)
    if color and rest ~= "" then rest = Recolor(rest, color) end

    if icons == "" and not color then return text end
    return text:sub(1, s - 1) .. icons .. text:sub(s, linkEnd + 1) .. rest
end

-- Item level next to every linked piece of gear: [Sword of Truth (489)]
local ilvlCache, ilvlCount = {}, 0
local function ItemLevelOf(data)
    local c = ilvlCache[data]
    if c ~= nil then return c or nil end
    local lvl
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local ok, id, _, _, _, _, classID = pcall(instant, data)
    if not ok or not id then return nil end
    if classID ~= 2 and classID ~= 4 then -- only weapons and armor carry a meaningful level
        ilvlCache[data] = false
        return nil
    end
    local detailed = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
    local ok2, v = pcall(detailed, data)
    if ok2 and type(v) == "number" and v > 1 then
        lvl = math.floor(v + 0.5)
    else
        -- not in the cache yet: ask the server so the next link of this item works
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
        return nil
    end
    if ilvlCount > 400 then wipe(ilvlCache); ilvlCount = 0 end
    ilvlCache[data] = lvl
    ilvlCount = ilvlCount + 1
    return lvl
end

local function AddItemLevels(text)
    if not text:find("|Hitem:", 1, true) then return text end
    return (text:gsub("(|H(item:[^|]+)|h)%[([^%]]-)%]|h", function(head, data, name)
        local lvl = ItemLevelOf(data)
        if not lvl then return nil end
        return head .. "[" .. name .. " (" .. lvl .. ")]|h"
    end))
end
Box.AddItemLevels = AddItemLevels

local function Process(text, cf)
    if cf and cf == _G.COMBATLOG then return text end
    local o = ns.db.chatbox
    if o.noClassColor then text = StripNameColors(text) end
    if o.itemLevel then text = AddItemLevels(text) end
    if o.emoji and not skipEmoji and not IsGameLine(text) then text = Box:Emojify(text) end
    if o.classIcons or o.factionIcons or o.highlight.enabled then
        text = Decorate(text, cf)
    end
    return text
end

---------------------------------------------------------------------------
-- Module hooks
---------------------------------------------------------------------------
local LEARN_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL",
}

function Box:Apply()
    playerShort = (UnitName("player") or ""):lower()
    self:RebuildHighlight()
    self:RebuildFriends()
    if ns.Rail then ns.Rail:Apply() end
    self:SkinFrames()
    self:Paint()
    self:UpdateDock()
    -- the chat bar may need to move into / out of the chatbox
    if ns.Bar and ns.Bar.frame then
        ns.Bar:ApplyPosition()
        ns.Bar:Refresh()
    end
end

function Box:OnInit()
    playerShort = (UnitName("player") or ""):lower()
    self.frame = self:CreateSkin()
    ns.AddProcessor(Process)
    for _, e in ipairs(LEARN_EVENTS) do ns.AddChatFilter(e, Learn) end
    for _, e in ipairs(SKIP_EVENTS) do ns.AddChatFilter(e, SkipFilter) end
    ns:OnTheme(function() Box:Paint() end)

    local reskin = Debounced(function() Box:SkinFrames(); Box:UpdateDock() end, 0.2)
    for _, fn in ipairs({ "FCF_DockFrame", "FCF_UnDockFrame", "FCF_OpenNewWindow",
        "FCF_OpenTemporaryWindow", "FCF_Close" }) do
        ns.SafeHook(fn, reskin)
    end

    local cf = _G.ChatFrame1
    if cf then
        local resize = Debounced(function()
            if Box:DockSide() and ns.Bar and ns.Bar.Refresh then ns.Bar:Refresh() end
        end, 0.15)
        cf:HookScript("OnSizeChanged", resize)
        hooksecurefunc(cf, "SetScale", function() Box:Anchor() end)
    end

    -- border flash for messages that matter (whispers, guild, group)
    local fl = CreateFrame("Frame")
    for _, e in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
        "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" }) do
        fl:RegisterEvent(e)
    end
    fl:SetScript("OnEvent", function(_, _, _, author)
        if author and not issecret(author) then
            local ok, me = pcall(function() return Ambiguate(author, "none") == UnitName("player") end)
            if ok and me then return end
        end
        Box:Flash()
    end)

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "FRIENDLIST_UPDATE", "BN_FRIEND_LIST_SIZE_CHANGED", "BN_FRIEND_INFO_CHANGED",
        "BN_FRIEND_ACCOUNT_ONLINE", "PLAYER_ENTERING_WORLD" }) do
        ev:RegisterEvent(e)
    end
    local friends = Debounced(function() Box:RebuildFriends() end, 1)
    ev:SetScript("OnEvent", function() friends() end)

    SLASH_ZTVCHATBOX1 = "/chatbox"
    SlashCmdList["ZTVCHATBOX"] = function() ns.Config:Open("chatbox") end

    SLASH_ZTVHL1 = "/ztvhl"
    SlashCmdList["ZTVHL"] = function(msg)
        local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
        cmd = cmd:lower()
        local h = ns.db.chatbox.highlight
        if cmd == "target" or cmd == "add" and rest == "" then
            Box:HighlightTarget(false)
        elseif cmd == "add" then
            local lines = {}
            if h.custom.text and h.custom.text ~= "" then lines[1] = h.custom.text end
            lines[#lines + 1] = rest
            h.custom.text = table.concat(lines, "\n")
            h.enabled = true
            Box:RebuildHighlight()
            ns:Print(string.format(T("%s added to the highlight list."), rest))
        elseif cmd == "remove" or cmd == "del" then
            if rest == "" then Box:HighlightTarget(true) return end
            local keep, found = {}, false
            for raw in (h.custom.text or ""):gmatch("[^\n,;]+") do
                local line = raw:match("^%s*(.-)%s*$")
                local n = line:match("^(.-)%s*[=#%s]%s*#?%x%x%x%x%x%x$") or line
                if line ~= "" then
                    if n:lower() == rest:lower() then found = true else keep[#keep + 1] = line end
                end
            end
            h.custom.text = table.concat(keep, "\n")
            Box:RebuildHighlight()
            ns:Print(found and string.format(T("Removed \"%s\"."), rest) or "That name is not in the list.")
        elseif cmd == "list" then
            local t = (h.custom.text or ""):gsub("\n", ", ")
            ns:Print(t ~= "" and string.format(T("Highlighted: %s"), t) or "The highlight list is empty.")
        else
            ns.Config:Open("looks")
        end
    end
end

function Box:OnLogin()
    self:Apply()
    C_Timer.After(2, function() Box:Apply() end)
end
