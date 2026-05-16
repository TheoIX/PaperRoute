-- PaperRoute
-- TBC 2.5.3 mailbox helper:
-- 1) Adds a Clear All button to the Inbox.
-- 2) Takes money/items from mail, then deletes empty/no-attachment mail.
-- 3) Right-click a tradeable bag item while the Send Mail tab is open to attach it.

local ADDON = "PaperRoute"
local PR = CreateFrame("Frame")
PaperRouteDB = PaperRouteDB or {}

local running = false
local waiting = false
local lastAction = 0
local pass = "collect"
local button
local scanner

local ACTION_DELAY = 0.35
local REFRESH_DELAY = 0.60

local function Msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd200PaperRoute:|r " .. tostring(text))
end

local function IsInboxVisible()
    return MailFrame and MailFrame:IsShown() and InboxFrame and InboxFrame:IsShown()
end

local function IsSendMailVisible()
    return MailFrame and MailFrame:IsShown() and SendMailFrame and SendMailFrame:IsShown()
end

local function GetInboxInfo(i)
    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(i)
    return sender, subject, money or 0, CODAmount or 0, itemCount or 0, wasRead, wasReturned, isGM
end

local function MailHasLockedOrPendingItems(i, itemCount)
    if not itemCount or itemCount <= 0 then return false end
    for slot = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
        local name, texture, count, quality, canUse = GetInboxItem(i, slot)
        if name then
            return true
        end
    end
    return false
end

local function StopRun(reason)
    running = false
    waiting = false
    pass = "collect"
    if button then button:SetText("Clear All") end
    if reason then Msg(reason) end
end

local function RequestRefresh()
    waiting = true
    CheckInbox()
    PR.nextRun = GetTime() + REFRESH_DELAY
end

local function CanAct()
    return GetTime() - lastAction >= ACTION_DELAY
end

local function DoCollectPass()
    local num = GetInboxNumItems()
    if not num or num <= 0 then
        pass = "delete"
        return false
    end

    for i = 1, num do
        local sender, subject, money, cod, itemCount = GetInboxInfo(i)
        if cod and cod > 0 then
            -- Never touch COD mail.
        else
            if money and money > 0 then
                TakeInboxMoney(i)
                lastAction = GetTime()
                RequestRefresh()
                return true
            end

            if itemCount and itemCount > 0 then
                for slot = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
                    local name = GetInboxItem(i, slot)
                    if name then
                        TakeInboxItem(i, slot)
                        lastAction = GetTime()
                        RequestRefresh()
                        return true
                    end
                end
            end
        end
    end

    pass = "delete"
    return false
end

local function DoDeletePass()
    local num = GetInboxNumItems()
    if not num or num <= 0 then
        StopRun("done.")
        return true
    end

    -- Delete from bottom upward so shifting inbox indices are less annoying.
    for i = num, 1, -1 do
        local sender, subject, money, cod, itemCount, wasRead, wasReturned, isGM = GetInboxInfo(i)
        if not isGM and (not cod or cod == 0) then
            local hasMoney = money and money > 0
            local hasItems = itemCount and itemCount > 0 and MailHasLockedOrPendingItems(i, itemCount)
            if not hasMoney and not hasItems then
                DeleteInboxItem(i)
                lastAction = GetTime()
                RequestRefresh()
                return true
            end
        end
    end

    StopRun("done.")
    return true
end

local function RunStep()
    if not running then return end
    if not IsInboxVisible() then
        StopRun("stopped because the inbox is closed.")
        return
    end
    if waiting then return end
    if not CanAct() then return end

    if pass == "collect" then
        DoCollectPass()
    else
        DoDeletePass()
    end
end

PR:SetScript("OnUpdate", function()
    if waiting and PR.nextRun and GetTime() >= PR.nextRun then
        waiting = false
    end
    RunStep()
end)

PR:RegisterEvent("MAIL_INBOX_UPDATE")
PR:RegisterEvent("MAIL_CLOSED")
PR:SetScript("OnEvent", function(self, event)
    if event == "MAIL_CLOSED" then
        if running then StopRun("stopped because mail closed.") end
    elseif event == "MAIL_INBOX_UPDATE" then
        if running then
            waiting = false
            PR.nextRun = nil
        end
    end
end)

local function StartClearAll()
    if running then
        StopRun("stopped.")
        return
    end
    if not IsInboxVisible() then
        Msg("open your mailbox inbox first.")
        return
    end
    running = true
    waiting = false
    pass = "collect"
    lastAction = 0
    if button then button:SetText("Stop") end
    Msg("collecting attachments/gold, then deleting empty mail...")
    CheckInbox()
end

local function CreateButton()
    if button or not InboxFrame then return end

    button = CreateFrame("Button", "PaperRouteClearAllButton", InboxFrame, "UIPanelButtonTemplate")
    button:SetWidth(86)
    button:SetHeight(22)
    button:SetText("Clear All")

    -- v1.0.1: Sit ABOVE Blizzard's Open All button instead of beside it.
    -- Beside it can overlap the Next page arrow on compact 2.5.3/TBC mailbox skins.
    if OpenAllMail then
        button:SetPoint("BOTTOM", OpenAllMail, "TOP", 0, 4)
    elseif OpenAllMailButton then
        button:SetPoint("BOTTOM", OpenAllMailButton, "TOP", 0, 4)
    else
        button:SetPoint("BOTTOM", InboxFrame, "BOTTOM", 58, 48)
    end

    button:SetScript("OnClick", StartClearAll)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("PaperRoute Clear All", 1, 0.82, 0)
        GameTooltip:AddLine("Takes AH gold/items first, then deletes empty mail like sale pending notices.", 1, 1, 1, true)
        GameTooltip:AddLine("COD and GM mail are skipped.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function TooltipHasLine(itemLink, text)
    if not scanner then
        scanner = CreateFrame("GameTooltip", "PaperRouteScannerTooltip", nil, "GameTooltipTemplate")
        scanner:SetOwner(UIParent, "ANCHOR_NONE")
    end
    scanner:ClearLines()
    scanner:SetHyperlink(itemLink)
    for i = 1, scanner:NumLines() do
        local line = _G["PaperRouteScannerTooltipTextLeft" .. i]
        local value = line and line:GetText()
        if value and string.find(value, text) then
            return true
        end
    end
    return false
end

local function IsTradeableBagItem(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then return false end

    local texture, count, locked, quality, readable, lootable = GetContainerItemInfo(bag, slot)
    if locked then return false end

    -- TBC tooltip text check. This skips Soulbound/Conjured/Quest Item/Unique mail weirdness.
    if TooltipHasLine(link, ITEM_SOULBOUND or "Soulbound") then return false end
    if TooltipHasLine(link, "Binds when picked up") then return false end
    if TooltipHasLine(link, ITEM_BIND_QUEST or "Quest Item") then return false end
    if TooltipHasLine(link, "Conjured Item") then return false end

    return true
end

local function FindFreeSendSlot()
    for i = 1, ATTACHMENTS_MAX_SEND or 12 do
        local name = GetSendMailItem(i)
        if not name then return i end
    end
    return nil
end

local function TryAttachItemFromButton(self, mouseButton)
    if mouseButton ~= "RightButton" then return false end
    if not IsSendMailVisible() then return false end
    if CursorHasItem and CursorHasItem() then return false end

    local bag = self and (self:GetParent() and self:GetParent():GetID())
    local slot = self and self:GetID()
    if not bag or not slot then return false end

    if not IsTradeableBagItem(bag, slot) then
        Msg("that item does not look mail-tradeable.")
        return true
    end

    local freeSlot = FindFreeSendSlot()
    if not freeSlot then
        Msg("all send-mail attachment slots are full.")
        return true
    end

    PickupContainerItem(bag, slot)
    ClickSendMailItemButton(freeSlot)
    return true
end

local function HookBagClicks()
    if PaperRoute_BagHooked then return end
    PaperRoute_BagHooked = true

    if ContainerFrameItemButton_OnClick then
        local oldClick = ContainerFrameItemButton_OnClick
        ContainerFrameItemButton_OnClick = function(self, button, ...)
            -- 2.5 style passes self/button. Some old-style calls use global this/arg1.
            local btn = button or arg1
            local obj = self or this
            if TryAttachItemFromButton(obj, btn) then return end
            return oldClick(self, button, ...)
        end
    end

    if ContainerFrameItemButton_OnModifiedClick then
        local oldMod = ContainerFrameItemButton_OnModifiedClick
        ContainerFrameItemButton_OnModifiedClick = function(self, button, ...)
            local btn = button or arg1
            local obj = self or this
            if TryAttachItemFromButton(obj, btn) then return end
            return oldMod(self, button, ...)
        end
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("MAIL_SHOW")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        HookBagClicks()
        SLASH_PAPERROUTE1 = "/paperroute"
        SLASH_PAPERROUTE2 = "/proute"
        SlashCmdList["PAPERROUTE"] = function(msg)
            msg = msg or ""
            if string.find(msg, "clear") then
                StartClearAll()
            else
                Msg("/paperroute clear - run Clear All while your inbox is open.")
                Msg("Right-click a tradeable bag item while the Send Mail tab is open to attach it.")
            end
        end
        Msg("loaded. Open mailbox for Clear All. Right-click bag items on Send Mail to attach.")
    elseif event == "MAIL_SHOW" then
        CreateButton()
    end
end)
