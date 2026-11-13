local ADDON, ns = ...
local Spam = ns:NewModule("Spam")
local issecret = ns.IsSecret
local T = ns.T

ns.spamBlocked = 0

local EVENTS = {
    "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_WHISPER",
    "CHAT_MSG_GUILD", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
}

local function SplitWords(input)
    local words, seen = {}, {}
    for w in (input or ""):gmatch("[^,\n]+") do
        w = w:match("^%s*(.-)%s*$"):lower()
        if w ~= "" and not seen[w] then
            seen[w] = true
            words[#words + 1] = w
        end
    end
    return words
end

function Spam:SetText(text)
    local o = ns.db.spam
    o.text = text or ""
    o.words = SplitWords(o.text)
end

function Spam:AddWord(word)
    local o = ns.db.spam
    word = (word or ""):match("^%s*(.-)%s*$"):lower()
    if word == "" then return false end
    for _, w in ipairs(o.words) do if w == word then return false end end
    o.words[#o.words + 1] = word
    o.text = table.concat(o.words, ", ")
    return true
end

function Spam:RemoveWord(word)
    local o = ns.db.spam
    word = (word or ""):match("^%s*(.-)%s*$"):lower()
    for i, w in ipairs(o.words) do
        if w == word then
            table.remove(o.words, i)
            o.text = table.concat(o.words, ", ")
            return true
        end
    end
    return false
end

local function IsTrusted(author, guid)
    if author and not issecret(author) and Ambiguate(author, "none") == UnitName("player") then return true end
    if guid and not issecret(guid) then
        if C_FriendList and C_FriendList.IsFriend and C_FriendList.IsFriend(guid) then return true end
        if IsGuildMember and IsGuildMember(guid) then return true end
    end
    return false
end

local seen, seenCount = {}, 0
local lastLine, lastResult

local function Purge(window)
    local now = GetTime()
    for k, t in pairs(seen) do
        if now - t > window then seen[k] = nil end
    end
    seenCount = 0
    for _ in pairs(seen) do seenCount = seenCount + 1 end
end

local function Filter(self, event, msg, author, ...)
    local o = ns.db.spam
    if not o.enabled then return false end
    if issecret(msg) then return false end

    -- Every chat tab runs the filter for the same line; answer consistently.
    local lineID = select(9, ...)
    local useMemo = lineID and not issecret(lineID)
    if useMemo and lineID == lastLine then return lastResult end

    local block = false
    local guid = select(10, ...)
    if not (o.whitelist and IsTrusted(author, guid)) then
        local lower = msg:lower()
        for _, w in ipairs(o.words) do
            if lower:find(w, 1, true) then block = true break end
        end
        if not block and o.dedupe then
            local who = (author and not issecret(author)) and author or "?"
            local key = who .. "\31" .. lower
            local now = GetTime()
            local t = seen[key]
            if t and now - t < o.dedupeSeconds then block = true end
            if not t then seenCount = seenCount + 1 end
            seen[key] = now
            if seenCount > 300 then Purge(o.dedupeSeconds) end
        end
    end

    if block then ns.spamBlocked = ns.spamBlocked + 1 end
    if useMemo then lastLine, lastResult = lineID, block end
    return block
end

function Spam:OnInit()
    for _, e in ipairs(EVENTS) do ns.AddChatFilter(e, Filter) end

    SLASH_ZTVSPAM1 = "/spam"
    SlashCmdList["ZTVSPAM"] = function(msg)
        local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
        cmd = cmd:lower()
        local o = ns.db.spam
        if cmd == "add" then
            ns:Print(Spam:AddWord(rest) and string.format(T("Added \"%s\" to the spam list."), rest) or "Nothing added (empty or already listed).")
        elseif cmd == "remove" or cmd == "del" then
            ns:Print(Spam:RemoveWord(rest) and string.format(T("Removed \"%s\"."), rest) or "That word is not in the list.")
        elseif cmd == "list" then
            ns:Print(#o.words > 0 and string.format(T("Blocked: %s"), table.concat(o.words, ", ")) or "The spam list is empty.")
        elseif cmd == "on" or cmd == "off" then
            o.enabled = (cmd == "on")
            ns:Print(o.enabled and "Spam filter enabled." or "Spam filter disabled.")
        else
            ns.Config:Open("spam")
        end
    end
end
