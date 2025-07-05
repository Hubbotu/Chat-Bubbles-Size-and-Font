-- Permission definitions
local perms_name = {
    "ALL", "PARTY", "RAID", "RAID_WARNING", "GUILD", "OFFICER", "INSTANCE_CHAT", "CHANNEL",
}
local channels = {} -- Track active custom channels (1-10)
local perms = {
    ["ALL"] = function() return true end,
    ["PARTY"] = function() return UnitExists("party1") end,
    ["RAID"] = function() return IsInRaid() end,
    ["RAID_WARNING"] = function() return IsInRaid() and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) end,
    ["GUILD"] = function() return IsInGuild() end,
    ["OFFICER"] = function() return C_GuildInfo.CanEditOfficerNote() end,
    ["INSTANCE_CHAT"] = function() return IsInInstance() end,
    ["CHANNEL"] = function(channelNum) return channels[channelNum] or false end,
}

-- Special channels to filter (from ChatBar Classic.lua)
local BOGUS_CHANNELS = {
    "General", "Trade", "LocalDefense", "WorldDefense", "GuildRecruitment", "LookingForGroup",
}

-- Default configuration
local defaultConfig = {
    size_btn = 16,
    interval_btn = 2,
    frame_pos = { x = 10, y = 170 },
    frame_visible = true,
    button_flashing = false, -- Flashing is disabled
    is_locked = false,
    is_horizontal = false, -- Flag for horizontal layout
    show_text = true, -- Flag to toggle text display on buttons
    bubbles = {
        { cmd = "/raid", perm = 3, color = {1, 0.5, 0}, desc = "Raid chat" },
        { cmd = "/g", perm = 5, color = {0.25, 1, 0.25}, desc = "Guild chat" },
        { cmd = "/o", perm = 6, color = {0.25, 1, 0.25}, desc = "Officer chat" },
        { cmd = "/p", perm = 2, color = {0.67, 0.67, 1}, desc = "Party chat" },
        { cmd = "/s", perm = 1, color = {1, 1, 1}, desc = "Say chat" },
        { cmd = "/y", perm = 1, color = {1, 0, 0}, desc = "Yell chat" },
        { cmd = "/rw", perm = 4, color = {1, 0.5, 0}, desc = "Raid warning chat" },
        { cmd = "/i", perm = 7, color = {1, 0.5, 0}, desc = "Instance chat" },
        { cmd = "/1", perm = 8, channel = 1, color = {1, 1, 0.75}, desc = "Channel 1" },
        { cmd = "/2", perm = 8, channel = 2, color = {1, 1, 0.75}, desc = "Channel 2" },
        { cmd = "/3", perm = 8, channel = 3, color = {1, 1, 0.75}, desc = "Channel 3" },
        { cmd = "/4", perm = 8, channel = 4, color = {1, 1, 0.75}, desc = "Channel 4" },
        { cmd = "/5", perm = 8, channel = 5, color = {1, 1, 0.75}, desc = "Channel 5" },
        { cmd = "/6", perm = 8, channel = 6, color = {1, 1, 0.75}, desc = "Channel 6" },
        { cmd = "/7", perm = 8, channel = 7, color = {1, 1, 0.75}, desc = "Channel 7" },
        { cmd = "/8", perm = 8, channel = 8, color = {1, 1, 0.75}, desc = "Channel 8" },
        { cmd = "/9", perm = 8, channel = 9, color = {1, 1, 0.75}, desc = "Channel 9" },
        { cmd = "/10", perm = 8, channel = 10, color = {1, 1, 0.75}, desc = "Channel 10" },
        { cmd = "/kd5", perm = 1, color = {1, 0, 1}, desc = "Countdown 5" },
        { cmd = "/kd10", perm = 1, color = {0.75, 0, 1}, desc = "Countdown 10" },
        { cmd = "/rdc", perm = 1, color = {1, 0, 0}, desc = "Ready check" },
        { cmd = "/key", perm = 1, color = {0, 1, 1}, desc = "Keystone information" },
        { cmd = "/copy", perm = 1, color = {1, 1, 0}, desc = "Copy chat" }, -- New Copy button
    },
}

-- Dynamic text replacement
local function Dyg_Variables(str)
    if str:match("#key#") then
        for b = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
            for s = 1, C_Container.GetContainerNumSlots(b) do
                local a = C_Container.GetContainerItemLink(b, s)
                if a and a:find("keystone") then
                    str = str:gsub("#key#", a)
                end
            end
        end
        str = str:gsub("#key#", "0")
    end
    return str
end

-- Helper function to set texture with fallback
local function SetTextureWithFallback(texture, path, fallbackPath)
    local success = texture:SetTexture(path)
    if not success then
        texture:SetTexture(fallbackPath)
        print("ZamestoTV Bubble Scale: Failed to load texture '" .. path .. "', using fallback '" .. fallbackPath .. "'.")
    end
    return success
end

-- Update channel states with special channel filtering
local function UpdateChannelStates()
    for i = 1, 10 do
        local channelNum, channelName = GetChannelName(i)
        if channelNum ~= 0 then
            local isSpecial = false
            if channelName then
                for _, bogusName in ipairs(BOGUS_CHANNELS) do
                    if channelName == bogusName then
                        isSpecial = true
                        break
                    end
                end
            end
            channels[i] = not isSpecial
        else
            channels[i] = false
        end
    end
end

-- Track the currently highlighted button
local currentHighlightedButton = nil

-- Create or update a single bubble button
local function SetBubble(param, frame, config, bubl_it, is_horizontal, index, is_special, total_special, total_chat)
    local permName = perms_name[param.perm]
    if permName == "CHANNEL" and not perms[permName](param.channel) then
        return bubl_it
    elseif permName ~= "CHANNEL" and not perms[permName]() then
        return bubl_it
    end

    if not frame.framedata then frame.framedata = {} end

    if not frame.framedata[bubl_it] then
        frame.framedata[bubl_it] = CreateFrame("Frame", "ZTV_BUBBLE_" .. bubl_it, frame, BackdropTemplateMixin and "BackdropTemplate")
    end

    if not frame.bg then
        frame.bg = CreateFrame("Frame", "ZTV_BUBBLE_BG", frame, BackdropTemplateMixin and "BackdropTemplate")
        frame.bg:SetFrameStrata("BACKGROUND")
        Mixin(frame.bg, BackdropTemplateMixin)
        frame.bg:SetBackdrop({
            bgFile = "Interface\\AddOns\\ZamestoTV_Bubble_Scale\\Media\\BlackBg",
            edgeFile = "Interface\\AddOns\\ZamestoTV_Bubble_Scale\\Media\\Border",
            tile = true,
            tileSize = 8,
            edgeSize = 8,
            insets = { left = 8, right = 8, top = 8, bottom = 8 }
        })
        frame.bg:SetBackdropColor(0, 0, 0, 0.4)
    end

    local bubble = frame.framedata[bubl_it]
    bubble:Show()
    bubble:SetSize(config.size_btn, config.size_btn)

    if is_horizontal then
        local xOffset = (config.size_btn + config.interval_btn) * (index - 1)
        local yOffset = is_special and 0 or -(config.size_btn + config.interval_btn)
        bubble:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", xOffset, yOffset)
    else
        local xOffset = is_special and (config.size_btn + config.interval_btn) or 0
        local row = index - 1
        bubble:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", xOffset, -(config.interval_btn + config.size_btn) * row)
    end

    if not bubble.bgTexture then
        bubble.bgTexture = bubble:CreateTexture(nil, "BACKGROUND")
        SetTextureWithFallback(bubble.bgTexture, "Interface\\AddOns\\ZamestoTV_Bubble_Scale\\Media\\Center", "Interface\\Buttons\\WHITE8x8")
        bubble.bgTexture:SetAllPoints()
    end
    bubble.bgTexture:SetVertexColor(param.r, param.g, param.b, 1)

    if not bubble.mask then
        bubble.mask = bubble:CreateMaskTexture()
        bubble.mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
        bubble.mask:SetSize(config.size_btn, config.size_btn)
        bubble.mask:SetPoint("CENTER")
        bubble.bgTexture:AddMaskTexture(bubble.mask)
    end

    if not bubble.upTexture then
        bubble.upTexture = bubble:CreateTexture(nil, "ARTWORK")
        SetTextureWithFallback(bubble.upTexture, "Interface\\AddOns\\ZamestoTV_Bubble_Scale\\Media\\Up_Spec", "Interface\\Buttons\\UI-Quickslot2")
        bubble.upTexture:SetSize(config.size_btn + 4, config.size_btn + 4)
        bubble.upTexture:SetPoint("CENTER")
        bubble.upTexture:SetAlpha(0.75)
    end
    bubble.upTexture:Show()

    if not bubble.downTexture then
        bubble.downTexture = bubble:CreateTexture(nil, "ARTWORK")
        SetTextureWithFallback(bubble.downTexture, "Interface\\AddOns\\ZamestoTV_Bubble_Scale\\Media\\Down_Spec", "Interface\\Buttons\\UI-Quickslot2")
        bubble.downTexture:SetSize(config.size_btn + 4, config.size_btn + 4)
        bubble.downTexture:SetPoint("CENTER")
        bubble.downTexture:SetAlpha(1)
        bubble.downTexture:Hide()
    end

    -- Add halo texture for chat buttons only
    local isChatButton = not (param.cmd == "/kd5" or param.cmd == "/kd10" or param.cmd == "/rdc" or param.cmd == "/key" or param.cmd == "/copy")
    if isChatButton and not bubble.haloTexture then
        bubble.haloTexture = bubble:CreateTexture(nil, "OVERLAY")
        local success = SetTextureWithFallback(bubble.haloTexture, "Interface\\AddOns\\ZamestoTV_Bubble_Scale\\Media\\Glow_Alpha", "Interface\\Buttons\\UI-Quickslot2")
        if success then
            bubble.haloTexture:SetSize(config.size_btn + 4, config.size_btn + 4)
            bubble.haloTexture:SetPoint("CENTER", bubble, "CENTER")
            bubble.haloTexture:SetBlendMode("ADD")
            bubble.haloTexture:SetVertexColor(0.5, 1, 0.5, 0.8)
            bubble.haloTexture:Hide()
        else
            bubble.haloTexture = nil
        end
    end

    -- Add text to button
    if not bubble.text then
        bubble.text = bubble:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bubble.text:SetPoint("CENTER", bubble, "CENTER", 0, 0)
        bubble.text:SetTextColor(1, 1, 1, 1)
        bubble.text:SetFont("Fonts\\FRIZQT__.TTF", config.size_btn * 0.6, "OUTLINE")
    end

    -- Determine the text to display based on the command
    local displayText
    if param.cmd:match("^/(%d+)$") then
        displayText = param.cmd:match("^/(%d+)$")
    else
        local cmdMap = {
            ["/raid"] = "r",
            ["/g"] = "g",
            ["/o"] = "o",
            ["/p"] = "p",
            ["/s"] = "s",
            ["/y"] = "y",
            ["/rw"] = "w",
            ["/i"] = "i",
            ["/kd5"] = "5",
            ["/kd10"] = "10",
            ["/rdc"] = "rc",
            ["/key"] = "k",
            ["/copy"] = "cp",
        }
        displayText = cmdMap[param.cmd] or param.cmd:sub(2, 2):lower()
    end
    bubble.text:SetText(displayText)
    bubble.text:SetShown(config.show_text)

    local chatType = param.cmd:match("^/(%d+)$") and ("CHANNEL" .. param.channel) or param.cmd

    bubble.color = param.cmd .. " " .. param.r .. " " .. param.g .. " " .. param.b .. " " .. bubl_it
    bubble.desc = param.desc
    bubble.chatType = chatType

    bubble:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.upTexture:Hide()
            self.downTexture:Show()
            if isChatButton and self.haloTexture then
                if currentHighlightedButton and currentHighlightedButton ~= self and currentHighlightedButton.haloTexture then
                    currentHighlightedButton.haloTexture:Hide()
                end
                self.haloTexture:Show()
                currentHighlightedButton = self
            end
            local editBox = ChatEdit_ChooseBoxForSend()
            local chatFrame = editBox.chatFrame
            local cmd = param.cmd
            if cmd:match("^/(%d+)$") then
                local channelNum = tonumber(cmd:match("^/(%d+)$"))
                local channelNumActual, channelName = GetChannelName(channelNum)
                if channelNumActual == 0 then
                    print("ZamestoTV Bubble Scale: Channel " .. channelNum .. " is not available.")
                    return
                end
                ChatEdit_ActivateChat(editBox)
                editBox:SetAttribute("chatType", "CHANNEL")
                editBox:SetAttribute("channelTarget", channelNum)
                ChatEdit_UpdateHeader(editBox)
            elseif cmd == "/kd5" then
                SlashCmdList["KD5"]()
            elseif cmd == "/kd10" then
                SlashCmdList["KD10"]()
            elseif cmd == "/rdc" then
                SlashCmdList["RDC"]()
            elseif cmd == "/key" then
                SlashCmdList["KEY"]()
            elseif cmd == "/copy" then
                SlashCmdList["COPY"]()
            else
                ChatFrame_OpenChat(Dyg_Variables(cmd), chatFrame)
            end
        end
    end)
    bubble:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.upTexture:Show()
            self.downTexture:Hide()
        end
    end)
    bubble:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.desc or "No description", 1, 1, 1)
        GameTooltip:Show()
    end)
    bubble:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    return bubl_it + 1
end

-- Update all bubble buttons
local function UpdateButtons(frame, config)
    local bubl_it = 1
    local firstColumnCount = 0
    local secondColumnCount = 0
    local chatButtonCount = 0
    local specialButtonCount = 0
    frame.chatTypeToButton = frame.chatTypeToButton or {}
    frame.firstColumnCount = 0
    frame.secondColumnCount = 0

    if currentHighlightedButton and currentHighlightedButton.haloTexture then
        currentHighlightedButton.haloTexture:Hide()
    end
    currentHighlightedButton = nil

    if frame.framedata then
        for _, child in ipairs({ frame:GetChildren() }) do
            local name = child:GetName()
            if name and name:find("^ZTV_BUBBLE_") then
                child:Hide()
            end
        end
    end

    frame.chatTypeToButton = {}

    -- Count available chat and special buttons
    for _, value in ipairs(config.bubbles) do
        local chatType = value.cmd:match("^/(%d+)$") and ("CHANNEL" .. value.channel) or value.cmd
        local permName = perms_name[value.perm]
        local isAvailable = permName == "CHANNEL" and perms[permName](value.channel) or perms[permName]()
        if isAvailable then
            if tContains({"/kd5", "/kd10", "/rdc", "/key", "/copy"}, chatType) then
                specialButtonCount = specialButtonCount + 1
            else
                chatButtonCount = chatButtonCount + 1
            end
        end
    end

    local is_horizontal = config.is_horizontal
    local index = 1
    local reservedCommands = { "/kd5", "/kd10", "/rdc", "/key", "/copy" }

    if is_horizontal then
        for _, cmd in ipairs(reservedCommands) do
            for _, value in ipairs(config.bubbles) do
                local chatType = value.cmd:match("^/(%d+)$") and ("CHANNEL" .. value.channel) or value.cmd
                if chatType == cmd then
                    local permName = perms_name[value.perm]
                    if permName and perms[permName] then
                        local isAvailable = permName == "CHANNEL" and perms[permName](value.channel) or perms[permName]()
                        if isAvailable then
                            frame.chatTypeToButton[chatType] = bubl_it
                            bubl_it = SetBubble({
                                cmd = value.cmd,
                                perm = value.perm,
                                channel = value.channel,
                                r = value.color[1],
                                g = value.color[2],
                                b = value.color[3],
                                desc = value.desc,
                            }, frame, config, bubl_it, is_horizontal, index, true, specialButtonCount, chatButtonCount)
                            index = index + 1
                            secondColumnCount = secondColumnCount + 1
                        end
                    end
                end
            end
        end

        index = 1
        for _, value in ipairs(config.bubbles) do
            local chatType = value.cmd:match("^/(%d+)$") and ("CHANNEL" .. value.channel) or value.cmd
            if not tContains(reservedCommands, chatType) then
                local permName = perms_name[value.perm]
                local isAvailable = permName == "CHANNEL" and perms[permName](value.channel) or perms[permName]()
                if isAvailable then
                    frame.chatTypeToButton[chatType] = bubl_it
                    bubl_it = SetBubble({
                        cmd = value.cmd,
                        perm = value.perm,
                        channel = value.channel,
                        r = value.color[1],
                        g = value.color[2],
                        b = value.color[3],
                        desc = value.desc,
                    }, frame, config, bubl_it, is_horizontal, index, false, specialButtonCount, chatButtonCount)
                    index = index + 1
                    firstColumnCount = firstColumnCount + 1
                end
            end
        end
    else
        for _, value in ipairs(config.bubbles) do
            local chatType = value.cmd:match("^/(%d+)$") and ("CHANNEL" .. value.channel) or value.cmd
            if not tContains(reservedCommands, chatType) then
                local permName = perms_name[value.perm]
                local isAvailable = permName == "CHANNEL" and perms[permName](value.channel) or perms[permName]()
                if isAvailable and firstColumnCount < 6 then
                    frame.chatTypeToButton[chatType] = bubl_it
                    bubl_it = SetBubble({
                        cmd = value.cmd,
                        perm = value.perm,
                        channel = value.channel,
                        r = value.color[1],
                        g = value.color[2],
                        b = value.color[3],
                        desc = value.desc,
                    }, frame, config, bubl_it, is_horizontal, index, false, specialButtonCount, chatButtonCount)
                    firstColumnCount = firstColumnCount + 1
                    index = index + 1
                end
            end
        end

        index = 1
        for _, cmd in ipairs(reservedCommands) do
            for _, value in ipairs(config.bubbles) do
                local chatType = value.cmd:match("^/(%d+)$") and ("CHANNEL" .. value.channel) or value.cmd
                if chatType == cmd then
                    local permName = perms_name[value.perm]
                    if permName and perms[permName] then
                        local isAvailable = permName == "CHANNEL" and perms[permName](value.channel) or perms[permName]()
                        if isAvailable then
                            frame.chatTypeToButton[chatType] = bubl_it
                            bubl_it = SetBubble({
                                cmd = value.cmd,
                                perm = value.perm,
                                channel = value.channel,
                                r = value.color[1],
                                g = value.color[2],
                                b = value.color[3],
                                desc = value.desc,
                            }, frame, config, bubl_it, is_horizontal, index, true, specialButtonCount, chatButtonCount)
                            secondColumnCount = secondColumnCount + 1
                            index = index + 1
                        end
                    end
                end
            end
        end
    end

    frame.firstColumnCount = firstColumnCount
    frame.secondColumnCount = secondColumnCount

    if frame.bg then
        if is_horizontal then
            local maxButtons = math.max(firstColumnCount, secondColumnCount)
            local width = (config.size_btn + config.interval_btn) * maxButtons + 16
            local height = (config.size_btn + config.interval_btn) * 2 + 16
            frame.bg:SetSize(width, height)
            frame.bg:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -8, 8)
        else
            local width = (config.size_btn + config.interval_btn) * 2 + 16
            local height = (config.size_btn + config.interval_btn) * math.max(firstColumnCount, secondColumnCount) + 16
            frame.bg:SetSize(width, height)
            frame.bg:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -8, 8)
        end
    end

    if config.frame_visible then
        frame:Show()
    else
        frame:Hide()
    end
end

-- Update button flashing registration (now empty as flashing is removed)
local function UpdateButtonFlashing(frame, config)
    frame:UnregisterEvent("CHAT_MSG_SAY")
    frame:UnregisterEvent("CHAT_MSG_YELL")
    frame:UnregisterEvent("CHAT_MSG_PARTY")
    frame:UnregisterEvent("CHAT_MSG_RAID")
    frame:UnregisterEvent("CHAT_MSG_RAID_WARNING")
    frame:UnregisterEvent("CHAT_MSG_INSTANCE_CHAT")
    frame:UnregisterEvent("CHAT_MSG_GUILD")
    frame:UnregisterEvent("CHAT_MSG_OFFICER")
    frame:UnregisterEvent("CHAT_MSG_CHANNEL")
end

-- Create main frame and initialize
local frame = CreateFrame("Frame", "ZamestoTVBubbleScaleFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
frame:SetPoint("CENTER", UIParent, "CENTER", ZamestoTVBubbleScaleDB and ZamestoTVBubbleScaleDB.frame_pos and ZamestoTVBubbleScaleDB.frame_pos.x or defaultConfig.frame_pos.x, ZamestoTVBubbleScaleDB and ZamestoTVBubbleScaleDB.frame_pos and ZamestoTVBubbleScaleDB.frame_pos.y or defaultConfig.frame_pos.y)
frame:SetSize(100, 100)
frame:SetMovable(true)
frame:EnableMouse(true)

-- Movable frame logic
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self)
    if ZamestoTVBubbleScaleDB and ZamestoTVBubbleScaleDB.is_locked then
        print("ZamestoTV Bubble Scale: Frame is locked. Use /boomlock to unlock.")
        return
    end
    if self:IsMovable() then
        self:StartMoving()
    end
end)
frame:SetScript("OnDragStop", function(self)
    if ZamestoTVBubbleScaleDB and ZamestoTVBubbleScaleDB.is_locked then return end
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint()
    ZamestoTVBubbleScaleDB.frame_pos = { x = x, y = y }
    print("ZamestoTV Bubble Scale: Frame position saved (x=" .. x .. ", y=" .. y .. ").")
end)

-- Register events for chat availability changes
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("CHANNEL_UI_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Event handler to update buttons dynamically
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "GROUP_ROSTER_UPDATE"
        or event == "PLAYER_GUILD_UPDATE"
        or event == "CHANNEL_UI_UPDATE"
        or event == "PLAYER_ENTERING_WORLD" then
        UpdateChannelStates()
        UpdateButtons(self, ZamestoTVBubbleScaleDB)
    elseif event == "ADDON_LOADED" and select(1, ...) == "ZamestoTV_Bubble_Scale" then
        if not ZamestoTVBubbleScaleDB then
            ZamestoTVBubbleScaleDB = CopyTable(defaultConfig)
        end
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", ZamestoTVBubbleScaleDB.frame_pos.x, ZamestoTVBubbleScaleDB.frame_pos.y)
        UpdateChannelStates()
        UpdateButtonFlashing(self, ZamestoTVBubbleScaleDB)
        UpdateButtons(self, ZamestoTVBubbleScaleDB)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Register ADDON_LOADED event
frame:RegisterEvent("ADDON_LOADED")

-- Initialize channel states and buttons on load
UpdateChannelStates()
UpdateButtonFlashing(frame, ZamestoTVBubbleScaleDB or defaultConfig)
UpdateButtons(frame, ZamestoTVBubbleScaleDB or defaultConfig)

-- Slash command to toggle visibility
SLASH_BOOMCHAT1 = "/boomchat"
SlashCmdList["BOOMCHAT"] = function()
    if ZamestoTVBubbleScaleDB then
        ZamestoTVBubbleScaleDB.frame_visible = not ZamestoTVBubbleScaleDB.frame_visible
        UpdateButtons(frame, ZamestoTVBubbleScaleDB)
        print("ZamestoTV Bubble Scale: Frame visibility " .. (ZamestoTVBubbleScaleDB.frame_visible and "enabled" or "disabled") .. ".")
    end
end

-- Slash command to reset position
SLASH_BOOMRESET1 = "/boomreset"
SlashCmdList["BOOMRESET"] = function()
    if ZamestoTVBubbleScaleDB then
        ZamestoTVBubbleScaleDB.frame_pos = { x = defaultConfig.frame_pos.x, y = defaultConfig.frame_pos.y }
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", ZamestoTVBubbleScaleDB.frame_pos.x, ZamestoTVBubbleScaleDB.frame_pos.y)
        UpdateButtons(frame, ZamestoTVBubbleScaleDB)
        print("ZamestoTV Bubble Scale: Position reset to default (x=10, y=170).")
    end
end

-- Slash command to lock/unlock frame
SLASH_BOOMLOCK1 = "/boomlock"
SlashCmdList["BOOMLOCK"] = function()
    if ZamestoTVBubbleScaleDB then
        ZamestoTVBubbleScaleDB.is_locked = not ZamestoTVBubbleScaleDB.is_locked
        print("ZamestoTV Bubble Scale: Frame " .. (ZamestoTVBubbleScaleDB.is_locked and "locked" or "unlocked") .. ".")
    end
end

-- Slash command to raise frame
SLASH_BOOMUP1 = "/boomup"
SlashCmdList["BOOMUP"] = function(msg)
    if ZamestoTVBubbleScaleDB then
        local pixels = tonumber(msg)
        if pixels and pixels > 0 then
            ZamestoTVBubbleScaleDB.frame_pos.y = (ZamestoTVBubbleScaleDB.frame_pos.y or 170) + pixels
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", ZamestoTVBubbleScaleDB.frame_pos.x, ZamestoTVBubbleScaleDB.frame_pos.y)
            UpdateButtons(frame, ZamestoTVBubbleScaleDB)
            print("ZamestoTV Bubble Scale: Frame raised by " .. pixels .. " pixels.")
        else
            print("ZamestoTV Bubble Scale: Please provide a valid number of pixels (e.g., /boomup 10).")
        end
    end
end

-- Slash command to lower frame
SLASH_BOOMDOWN1 = "/boomdown"
SlashCmdList["BOOMDOWN"] = function(msg)
    if ZamestoTVBubbleScaleDB then
        local pixels = tonumber(msg)
        if pixels and pixels > 0 then
            ZamestoTVBubbleScaleDB.frame_pos.y = (ZamestoTVBubbleScaleDB.frame_pos.y or 170) - pixels
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", ZamestoTVBubbleScaleDB.frame_pos.x, ZamestoTVBubbleScaleDB.frame_pos.y)
            UpdateButtons(frame, ZamestoTVBubbleScaleDB)
            print("ZamestoTV Bubble Scale: Frame lowered by " .. pixels .. " pixels.")
        else
            print("ZamestoTV Bubble Scale: Please provide a valid number of pixels (e.g., /boomdown 10).")
        end
    end
end

-- Slash command to toggle button flashing (now obsolete but kept for compatibility)
SLASH_BOOMFLASH1 = "/boomflash"
SlashCmdList["BOOMFLASH"] = function()
    if ZamestoTVBubbleScaleDB then
        ZamestoTVBubbleScaleDB.button_flashing = false
        UpdateButtonFlashing(frame, ZamestoTVBubbleScaleDB)
        print("ZamestoTV Bubble Scale: Button flashing is permanently disabled in this version.")
    end
end

-- Slash command to toggle layout orientation
SLASH_BOOMROTATE1 = "/boomrotate"
SlashCmdList["BOOMROTATE"] = function()
    if ZamestoTVBubbleScaleDB then
        ZamestoTVBubbleScaleDB.is_horizontal = not ZamestoTVBubbleScaleDB.is_horizontal
        UpdateButtons(frame, ZamestoTVBubbleScaleDB)
        print("ZamestoTV Bubble Scale: Layout set to " .. (ZamestoTVBubbleScaleDB.is_horizontal and "horizontal" or "vertical") .. ".")
    end
end

-- Slash command to toggle text display
SLASH_BOOMTEXT1 = "/boomtext"
SlashCmdList["BOOMTEXT"] = function()
    if ZamestoTVBubbleScaleDB then
        ZamestoTVBubbleScaleDB.show_text = not ZamestoTVBubbleScaleDB.show_text
        UpdateButtons(frame, ZamestoTVBubbleScaleDB)
        print("ZamestoTV Bubble Scale: Button text " .. (ZamestoTVBubbleScaleDB.show_text and "enabled" or "disabled") .. ".")
    end
end

-- Slash command to adjust button size
SLASH_BOOMSIZE1 = "/boomsize"
SlashCmdList["BOOMSIZE"] = function(msg)
    if ZamestoTVBubbleScaleDB then
        local delta = tonumber(msg)
        if delta and delta ~= 0 then
            local newSize = ZamestoTVBubbleScaleDB.size_btn + delta
            if newSize >= 8 and newSize <= 64 then
                ZamestoTVBubbleScaleDB.size_btn = newSize
                UpdateButtons(frame, ZamestoTVBubbleScaleDB)
                print("ZamestoTV Bubble Scale: Button size " .. (delta > 0 and "increased" or "decreased") .. " to " .. newSize .. " pixels.")
            else
                print("ZamestoTV Bubble Scale: Button size must be between 8 and 64 pixels.")
            end
        else
            print("ZamestoTV Bubble Scale: Please provide a valid number of pixels (e.g., /boomsize 2 or /boomsize -2).")
        end
    end
end

-- Slash commands for countdown, ready check, keystone, and copy
SLASH_KD5_1 = "/kd5"
SlashCmdList["KD5"] = function()
    ChatFrame1EditBox:SetText("/countdown 5")
    ChatEdit_SendText(ChatFrame1EditBox, 0)
end

SLASH_KD10_1 = "/kd10"
SlashCmdList["KD10"] = function()
    ChatFrame1EditBox:SetText("/countdown 10")
    ChatEdit_SendText(ChatFrame1EditBox, 0)
end

SLASH_RDC_1 = "/rdc"
SlashCmdList["RDC"] = function()
    ChatFrame1EditBox:SetText("/readycheck")
    ChatEdit_SendText(ChatFrame1EditBox, 0)
end

SLASH_KEY_1 = "/key"
SlashCmdList["KEY"] = function()
    ChatFrame1EditBox:SetText("!key")
    ChatEdit_SendText(ChatFrame1EditBox, 0)
end

SLASH_COPY_1 = "/copy"
SlashCmdList["COPY"] = function()
    ChatFrame1EditBox:SetText("/copy")
    ChatEdit_SendText(ChatFrame1EditBox, 0)
end