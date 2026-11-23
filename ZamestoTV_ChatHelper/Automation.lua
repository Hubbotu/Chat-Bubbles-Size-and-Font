local ADDON, ns = ...
local issecret = ns.IsSecret
local T = ns.T
local Auto = ns:NewModule("Automation")

---------------------------------------------------------------------------
-- Who is a friend?
---------------------------------------------------------------------------
local function IsBNFriend(name, guid)
    -- the game can tell directly from the character's guid
    if guid and C_BattleNet and C_BattleNet.GetAccountInfoByGUID then
        local ok, info = pcall(C_BattleNet.GetAccountInfoByGUID, guid)
        if ok and info then return true end
    end
    -- otherwise compare with the characters the Battle.net friends are playing
    if name and C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends then
        local short = Ambiguate(name, "short"):lower()
        for i = 1, (BNGetNumFriends()) do
            local ok, a = pcall(C_BattleNet.GetFriendAccountInfo, i)
            local g = ok and a and a.gameAccountInfo
            if g and g.isOnline and type(g.characterName) == "string" and g.characterName:lower() == short then
                return true
            end
        end
    end
    return false
end

local function IsGameFriend(name, guid)
    local FL = C_FriendList
    if not FL then return false end
    if guid and FL.IsFriend then
        local ok, v = pcall(FL.IsFriend, guid)
        if ok and v then return true end
    end
    if name and FL.GetNumFriends and FL.GetFriendInfoByIndex then
        local short = Ambiguate(name, "short"):lower()
        for i = 1, FL.GetNumFriends() do
            local fi = FL.GetFriendInfoByIndex(i)
            if fi and fi.name and Ambiguate(fi.name, "short"):lower() == short then return true end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Group invitations
---------------------------------------------------------------------------
local function Accept(name)
    local accept = (C_PartyInfo and C_PartyInfo.AcceptInvite) or _G.AcceptGroup
    if not accept then return false end
    if not pcall(accept) then return false end
    if StaticPopup_Hide then
        StaticPopup_Hide("PARTY_INVITE")
        StaticPopup_Hide("PARTY_INVITE_XREALM")
    end
    ns:Print(string.format(T("Accepted a group invitation from %s."), name))
    return true
end

local function OnInvite(name, _, _, _, _, _, _, guid)
    local o = ns.db.automation
    if not (o.acceptBN or o.acceptFriends) then return end
    if type(name) ~= "string" or issecret(name) then return end
    if guid ~= nil and (issecret(guid) or type(guid) ~= "string") then guid = nil end
    if o.acceptBN and IsBNFriend(name, guid) then Accept(name) return end
    if o.acceptFriends and IsGameFriend(name, guid) then Accept(name) return end
end

function Auto:OnInit()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PARTY_INVITE_REQUEST")
    f:SetScript("OnEvent", function(_, _, ...) OnInvite(...) end)
end
