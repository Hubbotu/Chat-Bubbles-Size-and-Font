local ADDON, ns = ...
local P = ns:NewModule("Profiles")

-- Profiles live in an account-wide saved variable, so any character can load them.
-- A profile holds every setting of the addon. It does not hold things that belong
-- to one character or are temporary: the messenger history, one-time migration flags,
-- and the saved state of the instance-bubble feature.
local EXCLUDE = {
    ["migrated"] = true, ["bgReset"] = true, ["skinV2"] = true, ["profileName"] = true,
    ["messenger.history"] = true, ["bubbles.saved"] = true, ["chat._ccApplied"] = true,
}

local function Store()
    ZamestoTVChatProfiles = ZamestoTVChatProfiles or {}
    local s = ZamestoTVChatProfiles
    s.profiles = s.profiles or {}
    return s
end

local function Copy(src, path)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do
        local p = path and (path .. "." .. tostring(k)) or tostring(k)
        if not EXCLUDE[p] then out[k] = Copy(v, p) end
    end
    return out
end

local function Trim(s) return (s or ""):match("^%s*(.-)%s*$") end

function P:Names()
    local out = {}
    for name in pairs(Store().profiles) do out[#out + 1] = name end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

function P:Exists(name)
    return Store().profiles[name] ~= nil
end

-- Describes who saved a profile and when.
function P:Info(name)
    local p = Store().profiles[name]
    if not p then return nil end
    return p.by or "?", p.saved and date("%Y-%m-%d %H:%M", p.saved) or "?"
end

function P:Save(name)
    name = Trim(name)
    if name == "" or #name > 40 then return false end
    local player = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?"):gsub("%s", "")
    Store().profiles[name] = {
        data = Copy(ns.db),
        saved = time(),
        by = player,
        version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version"),
    }
    ns.db.profileName = name
    return true
end

-- Replaces this character's settings with the profile. A reload makes everything take effect.
function P:Apply(name)
    local profile = Store().profiles[name]
    if not profile then return false end

    local keep = {
        history = ns.db.messenger and ns.db.messenger.history,
        saved = ns.db.bubbles and ns.db.bubbles.saved,
        cc = ns.db.chat and ns.db.chat._ccApplied,
    }
    local snap = ns.DeepCopy(profile.data)
    wipe(ns.db)
    for k, v in pairs(snap) do ns.db[k] = v end
    ns.Merge(ns.db, ns.defaults)           -- settings added by newer versions get their defaults
    ns.db.migrated, ns.db.bgReset, ns.db.skinV2 = true, true, true
    ns.db.messenger.history = keep.history or {}
    if keep.saved ~= nil then ns.db.bubbles.saved = keep.saved end
    if keep.cc ~= nil then ns.db.chat._ccApplied = keep.cc end
    ns.db.profileName = name
    return true
end

function P:Delete(name)
    local s = Store()
    s.profiles[name] = nil
    if s.default == name then s.default = nil end
    if ns.db and ns.db.profileName == name then ns.db.profileName = nil end
end

-- profile that characters without any saved settings start with
function P:IsDefault(name) return name ~= nil and Store().default == name end
function P:SetDefault(name) Store().default = name end

-- Called from Core the very first time a character logs in with this addon.
function P:ApplyDefaultToFresh(db)
    local s = ZamestoTVChatProfiles
    local name = s and s.default
    local profile = name and s.profiles and s.profiles[name]
    if not profile then return end
    for k, v in pairs(ns.DeepCopy(profile.data)) do db[k] = v end
    db.migrated, db.bgReset, db.skinV2 = true, true, true
    db.profileName = name
end
