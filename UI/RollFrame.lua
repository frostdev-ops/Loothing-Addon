--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    RollFrame - Popup UI for raid members to respond to loot
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local Protocol = ns.Protocol

--[[--------------------------------------------------------------------
    RollFrameMixin
----------------------------------------------------------------------]]

local RollFrameMixin = ns.RollFrameMixin or Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.RollFrameMixin = RollFrameMixin

local ROLLFRAME_EVENTS = {
    "OnResponseSubmitted",
    "OnRollCompleted",
    "OnFrameClosed",
}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize the roll frame
function RollFrameMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(ROLLFRAME_EVENTS)

    -- Current item state
    self.item = nil
    self.selectedResponse = nil
    self.note = ""

    -- Per-item roll storage (keyed by item GUID)
    self.itemRolls = {}           -- { [guid] = { roll=N, min=1, max=100 } }
    self.pendingRollGUID = nil    -- GUID of item we're currently rolling for
    self.pendingRollStarted = {}  -- { [guid] = startTime }

    -- Per-item response tracking (keyed by item GUID)
    self.itemResponses = {}       -- { [guid] = { response=id, note=str, submitted=bool } }
    self.responseAckTimers = {}   -- { [guid] = timer }

    -- Multi-item session support
    self.items = {}               -- Array of session items
    self.currentItemIndex = 1     -- Index of currently displayed item
    self.sessionButtons = {}      -- UI button references for item switching
    self.sessionButtonFrame = nil -- Container frame for session buttons

    -- Create UI
    self:CreateFrame()
    self:CreateElements()

    -- Register for session events
    self:RegisterSessionEvents()

    -- Register for roll capture
    self:RegisterRollCapture()
end

--- Register for session events to auto-show
-- Event handling moved to UI/RollFrame/Events.lua

-- Frame creation moved to UI/RollFrame/UI.lua

--[[--------------------------------------------------------------------
    Session Button Frame (Multi-Item Support)
----------------------------------------------------------------------]]

-- Session buttons and navigation moved to UI/RollFrame/UI.lua

--[[--------------------------------------------------------------------
    Dynamic Layout System
----------------------------------------------------------------------]]

-- Dynamic layout helpers moved to UI/RollFrame/UI.lua

--[[--------------------------------------------------------------------
    Item Display Section
----------------------------------------------------------------------]]

-- UI construction moved to UI/RollFrame/UI.lua

--[[--------------------------------------------------------------------
    Item Binding
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
    Roll Tracking Methods
----------------------------------------------------------------------]]

--- Store a roll result for an item
-- @param itemGUID string
-- @param roll number
-- @param minRoll number
-- @param maxRoll number
function RollFrameMixin:SetItemRoll(itemGUID, roll, minRoll, maxRoll)
    self.itemRolls[itemGUID] = { roll = roll, min = minRoll or 1, max = maxRoll or 100 }
end

--- Get stored roll for an item
-- @param itemGUID string
-- @return number|nil, number|nil, number|nil - roll, min, max
function RollFrameMixin:GetItemRoll(itemGUID)
    local data = self.itemRolls[itemGUID]
    if data then return data.roll, data.min, data.max end
    return nil, nil, nil
end

--- Update the roll display text for the current item
function RollFrameMixin:UpdateRollDisplay()
    if not self.rollText then return end
    local itemGUID = self.item and self.item.guid
    if itemGUID then
        local roll = self:GetItemRoll(itemGUID)
        self.rollText:SetText(roll and tostring(roll) or "")
    else
        self.rollText:SetText("")
    end
end

--- Trigger auto-roll for the current item if settings allow it
function RollFrameMixin:TriggerAutoRoll()
    local autoRoll = Loothing.Settings and Loothing.Settings:Get("rollFrame.autoRollOnSubmit")
    if not autoRoll then return end
    if not self.item then return end
    local existing = self:GetItemRoll(self.item.guid)
    if existing then return end -- already rolled
    self:DoRoll()
end

--- Execute a /roll command for the current item
function RollFrameMixin:DoRoll()
    if not self.item then return end
    local rollSettings = Loothing.Settings and Loothing.Settings:Get("rollFrame.rollRange")
    local minRoll = rollSettings and rollSettings.min or 1
    local maxRoll = rollSettings and rollSettings.max or 100
    self.pendingRollGUID = self.item.guid
    self.pendingRollStarted[self.item.guid] = GetTime()
    RandomRoll(minRoll, maxRoll)
end

--[[--------------------------------------------------------------------
    Item Management
----------------------------------------------------------------------]]

--- Set multiple items for the session
-- @param items table - Array of LoothingItem instances
function RollFrameMixin:SetItems(items)
    self.items = items or {}
    self.currentItemIndex = 1

    -- Clear response tracking for new session
    self.itemResponses = {}
    self.itemRolls = {}
    self.sessionButtonWarningShown = nil

    if #self.items == 0 then
        self:Hide()
        return
    end

    -- Display first item
    self:DisplayItem(self.items[1])

    -- Update session buttons
    self:UpdateSessionButtons()

    self:Show()
end

--- Add an item to the current session
-- @param item table - LoothingItem instance
function RollFrameMixin:AddItem(item)
    table.insert(self.items, item)
    self:UpdateSessionButtons()

    -- If this is the first item, display it
    if #self.items == 1 then
        self:DisplayItem(item)
        self:Show()
    end
end

--- Get the currently displayed item
-- @return table|nil
function RollFrameMixin:GetCurrentItem()
    return self.items[self.currentItemIndex]
end

--- Set a single item (backward compatible, wraps SetItems)
-- @param item table - LoothingItem instance
function RollFrameMixin:SetItem(item)
    if item then
        self:SetItems({ item })
    else
        self:SetItems({})
    end
end

--- Display a specific item (internal, called by SwitchToItem and SetItems)
-- @param item table - LoothingItem to display
function RollFrameMixin:DisplayItem(item)
    self.item = item
    self.selectedResponse = nil
    self.note = ""
    self.requireNotesForResponse = false

    if not item then return end

    -- Check if we've already responded to this item
    local previousResponse = self:GetItemResponse(item.guid)
    local alreadyResponded = previousResponse and previousResponse.submitted

    -- Update item display
    local texture = item.texture or C_Item.GetItemIconByID(item.itemID or 0)
    self.itemIcon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")

    local quality = item.quality or 1
    local r, g, b = C_Item.GetItemQualityColor(quality)
    self.itemIconBorder:SetVertexColor(r, g, b)
    if self.itemGlow then
        self.itemGlow:SetVertexColor(r, g, b, 1)
    end
    self.itemName:SetTextColor(r, g, b)
    self.itemName:SetText(item.name or item.itemLink or "Unknown Item")

    -- Item level and slot info
    local infoText = ""
    if item.itemLevel and item.itemLevel > 0 then
        infoText = string.format("ilvl %d", item.itemLevel)
    end
    if item.equipSlot and item.equipSlot ~= "" then
        local slotName = _G[item.equipSlot] or item.equipSlot:gsub("INVTYPE_", "")
        if infoText ~= "" then
            infoText = infoText .. " - " .. slotName
        else
            infoText = slotName
        end
    end

    -- Add "Responded" indicator if already submitted
    if alreadyResponded then
        infoText = infoText .. " |cff00ff00(Responded)|r"
    end
    self.itemInfo:SetText(infoText)

    -- Update gear comparison
    self:UpdateGearComparison()

    -- Show roll buttons or response buttons based on item type
    if item.isRoll then
        self:ShowRollButtons()
    else
        self:ShowResponseButtons()
        -- Refresh response buttons (also triggers UpdateLayout)
        self:RefreshResponseButtons()
    end

    -- Reset UI state (or restore previous response)
    self:ResetUIState(previousResponse)

    -- Start timer
    self:StartTimer()

    -- Auto-roll if rolls are enabled (roll happens immediately when frame shows)
    self:TriggerAutoRoll()

    -- Guarantee layout is correct regardless of RefreshResponseButtons path
    self:UpdateLayout()
end

--- Reset UI state
-- @param previousResponse table|nil - Previous response data if item was already responded to
function RollFrameMixin:ResetUIState(previousResponse)
    local alreadyResponded = previousResponse and previousResponse.submitted
    local isPending = previousResponse and previousResponse.pending

    -- Clear or restore note
    if self.noteEditBox then
        if alreadyResponded then
            self.noteEditBox:SetText(previousResponse.note or "")
            self.noteEditBox:Disable()
        elseif isPending then
            self.noteEditBox:SetText(previousResponse.note or "")
            self.noteEditBox:Disable()
        else
            self.noteEditBox:SetText("")
            self.noteEditBox:Enable()
        end
    end

    -- Restore or clear response button selection
    for _, btn in pairs(self.responseButtons) do
        if btn.selectedGlow then btn.selectedGlow:Hide() end
        if alreadyResponded or isPending then
            btn:Disable()
        else
            btn:Enable()
        end
    end

    -- If already responded, show the previous selection
    if (alreadyResponded or isPending) and previousResponse.response then
        self.selectedResponse = previousResponse.response
        local btn = self.responseButtons[previousResponse.response]
        if btn then
            if btn.selectedGlow then btn.selectedGlow:Show() end
        end
    else
        self.selectedResponse = nil
    end

    -- Update roll display (shows existing roll or "...")
    self:UpdateRollDisplay()

    -- Update submit button (delegates to UpdateSubmitButton for visual state)
    self:UpdateSubmitButton()
end

--- Update gear comparison display
function RollFrameMixin:UpdateGearComparison()
    if not self.item then
        self.gearContainer:Hide()
        return
    end

    local showComparison = true
    if Loothing.Settings then
        showComparison = Loothing.Settings:Get("rollFrame.showGearComparison", true) ~= false
    end

    if not showComparison then
        self.gearContainer:Hide()
        return
    end

    self.gearContainer:Show()

    -- Get equipped slots for this item type
    local slot1, slot2 = self:GetEquipSlotsForItem()

    -- If no equip slot could be determined, show message and return
    if not slot1 then
        self.gear1Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        self.gear1Level:SetText("N/A")
        self.gear1Icon:Show()
        self.gear1Level:Show()
        self.gear2Icon:Hide()
        self.gear2Level:Hide()
        self.upgradeText:SetText("|cff888888Unknown slot|r")
        return
    end

    if slot1 then
        local item1 = GetInventoryItemLink("player", slot1)
        if item1 then
            local _, _, q1, ilvl = C_Item.GetItemInfo(item1)
            local texture = GetInventoryItemTexture("player", slot1)
            self.gear1Icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            self.gear1Level:SetText(ilvl and tostring(ilvl) or "?")
            self.gear1Icon:Show()
            self.gear1Level:Show()
            if self.gear1Btn then
                self.gear1Btn.itemLink = item1
                self.gear1Btn:Show()
            end
            if self.gear1Border and q1 then
                local r, g, b = C_Item.GetItemQualityColor(q1)
                self.gear1Border:SetVertexColor(r, g, b)
            end
        else
            self.gear1Icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
            self.gear1Level:SetText("Empty")
            self.gear1Icon:Show()
            self.gear1Level:Show()
            if self.gear1Btn then self.gear1Btn.itemLink = nil end
        end
    else
        self.gear1Icon:Hide()
        self.gear1Level:Hide()
        if self.gear1Btn then self.gear1Btn:Hide() end
    end

    if slot2 then
        local item2 = GetInventoryItemLink("player", slot2)
        if item2 then
            local _, _, q2, ilvl = C_Item.GetItemInfo(item2)
            local texture = GetInventoryItemTexture("player", slot2)
            self.gear2Icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            self.gear2Level:SetText(ilvl and tostring(ilvl) or "?")
            self.gear2Icon:Show()
            self.gear2Level:Show()
            if self.gear2Btn then
                self.gear2Btn.itemLink = item2
                self.gear2Btn:Show()
            end
            if self.gear2Border and q2 then
                local r, g, b = C_Item.GetItemQualityColor(q2)
                self.gear2Border:SetVertexColor(r, g, b)
            end
        else
            self.gear2Icon:Hide()
            self.gear2Level:Hide()
            if self.gear2Btn then self.gear2Btn:Hide() end
        end
    else
        self.gear2Icon:Hide()
        self.gear2Level:Hide()
        if self.gear2Btn then self.gear2Btn:Hide() end
    end

    -- Calculate upgrade value
    self:UpdateUpgradeIndicator(slot1, slot2)
end

--- Get inventory slot IDs for item's equip slot
-- @return number, number|nil - Primary slot, secondary slot (for rings/trinkets/weapons)
function RollFrameMixin:GetEquipSlotsForItem()
    if not self.item or not self.item.equipSlot then
        return nil, nil
    end

    local equipSlot = self.item.equipSlot

    -- Map equip slot to inventory slot IDs
    local slotMap = {
        INVTYPE_HEAD = { INVSLOT_HEAD },
        INVTYPE_NECK = { INVSLOT_NECK },
        INVTYPE_SHOULDER = { INVSLOT_SHOULDER },
        INVTYPE_CLOAK = { INVSLOT_BACK },
        INVTYPE_CHEST = { INVSLOT_CHEST },
        INVTYPE_ROBE = { INVSLOT_CHEST },
        INVTYPE_WRIST = { INVSLOT_WRIST },
        INVTYPE_HAND = { INVSLOT_HAND },
        INVTYPE_WAIST = { INVSLOT_WAIST },
        INVTYPE_LEGS = { INVSLOT_LEGS },
        INVTYPE_FEET = { INVSLOT_FEET },
        INVTYPE_FINGER = { INVSLOT_FINGER1, INVSLOT_FINGER2 },
        INVTYPE_TRINKET = { INVSLOT_TRINKET1, INVSLOT_TRINKET2 },
        INVTYPE_WEAPON = { INVSLOT_MAINHAND, INVSLOT_OFFHAND },
        INVTYPE_WEAPONMAINHAND = { INVSLOT_MAINHAND },
        INVTYPE_WEAPONOFFHAND = { INVSLOT_OFFHAND },
        INVTYPE_2HWEAPON = { INVSLOT_MAINHAND },
        INVTYPE_HOLDABLE = { INVSLOT_OFFHAND },
        INVTYPE_SHIELD = { INVSLOT_OFFHAND },
        INVTYPE_RANGED = { INVSLOT_MAINHAND },
        INVTYPE_RANGEDRIGHT = { INVSLOT_MAINHAND },
    }

    local slots = slotMap[equipSlot]
    if slots then
        return slots[1], slots[2]
    end

    return nil, nil
end

--- Update upgrade indicator text
-- @param slot1 number
-- @param slot2 number|nil
function RollFrameMixin:UpdateUpgradeIndicator(slot1, slot2)
    if not self.item or not self.item.itemLevel then
        self.upgradeText:SetText("")
        return
    end

    local newIlvl = self.item.itemLevel
    local lowestEquipped = nil

    if slot1 then
        local link1 = GetInventoryItemLink("player", slot1)
        if link1 then
            local _, _, _, ilvl = C_Item.GetItemInfo(link1)
            if ilvl then
                lowestEquipped = ilvl
            end
        else
            lowestEquipped = 0  -- Empty slot
        end
    end

    if slot2 then
        local link2 = GetInventoryItemLink("player", slot2)
        if link2 then
            local _, _, _, ilvl = C_Item.GetItemInfo(link2)
            if ilvl and (not lowestEquipped or ilvl < lowestEquipped) then
                lowestEquipped = ilvl
            end
        elseif not lowestEquipped then
            lowestEquipped = 0
        end
    end

    if lowestEquipped then
        local diff = newIlvl - lowestEquipped
        if diff > 0 then
            self.upgradeText:SetText(string.format("+%d ilvl", diff))
            self.upgradeText:SetTextColor(0.2, 1, 0.2)
            if self.upgradeBadge then
                self.upgradeBadge:SetBackdropColor(0.05, 0.25, 0.05, 0.9)
                self.upgradeBadge:Show()
            end
        elseif diff < 0 then
            self.upgradeText:SetText(string.format("%d ilvl", diff))
            self.upgradeText:SetTextColor(1, 0.3, 0.3)
            if self.upgradeBadge then
                self.upgradeBadge:SetBackdropColor(0.25, 0.05, 0.05, 0.9)
                self.upgradeBadge:Show()
            end
        else
            self.upgradeText:SetText("Same ilvl")
            self.upgradeText:SetTextColor(1, 1, 0.4)
            if self.upgradeBadge then
                self.upgradeBadge:SetBackdropColor(0.2, 0.2, 0.05, 0.9)
                self.upgradeBadge:Show()
            end
        end
    else
        self.upgradeText:SetText("")
        if self.upgradeBadge then self.upgradeBadge:Hide() end
    end
end

-- Roll handling moved to UI/RollFrame/Events.lua

--[[--------------------------------------------------------------------
    Timer
----------------------------------------------------------------------]]

--- Start the timer display
function RollFrameMixin:StartTimer()
    if self.ticker then
        self.ticker:Cancel()
    end

    -- Check if timeout is enabled
    local timeoutEnabled = true
    if Loothing.Settings then
        timeoutEnabled = Loothing.Settings:GetRollFrameTimeoutEnabled()
    end

    -- Also treat duration=0 as "no timeout"
    local timeoutDuration = Loothing.Settings and Loothing.Settings:GetRollFrameTimeoutDuration() or 30
    if timeoutDuration == 0 then
        timeoutEnabled = false
    end

    if not timeoutEnabled then
        -- Timer disabled - hide the bar and don't start ticker
        if self.timerContainer then
            self.timerContainer:Hide()
        end
        return
    end

    -- Show timer bar
    if self.timerContainer then
        self.timerContainer:Show()
    end

    self.ticker = C_Timer.NewTicker(0.1, function()
        self:UpdateTimer()
    end)

    self:UpdateTimer()
end

--- Stop the timer
function RollFrameMixin:StopTimer()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    self:StopTimerFlash()
end

--- Update timer display
function RollFrameMixin:UpdateTimer()
    if not self.item then
        self.timerText:SetText("")
        return
    end

    -- Check if timeout is enabled
    local timeoutEnabled = true
    if Loothing.Settings then
        timeoutEnabled = Loothing.Settings:GetRollFrameTimeoutEnabled()
    end

    if not timeoutEnabled then
        -- Timer disabled - no auto-close behavior
        self.timerContainer:Hide()
        return
    end

    local remaining = 0
    if self.item.GetTimeRemaining then
        remaining = self.item:GetTimeRemaining() or 0
    end
    local isVoting = self.item.IsVoting and self.item:IsVoting()
    local L = Loothing.Locale

    -- No-timeout mode: hide timer, never auto-close
    if remaining == math.huge then
        self.timerContainer:Hide()
        return
    end

    if remaining <= 0 then
        if isVoting then
            self.timerText:SetText(L["TIME_EXPIRED"] or "Time expired")
            self.timerBar:SetValue(0)
            self.timerBar:SetStatusBarColor(0.6, 0.2, 0.2, 1)

            -- Auto-close after a delay (deduplicated: only one pending timer at a time)
            if not self.autoCloseTimer then
                self.autoCloseTimer = C_Timer.NewTimer(1.5, function()
                    self.autoCloseTimer = nil
                    local itemRemaining = self.frame:IsShown() and self.item and
                        self.item.GetTimeRemaining and self.item:GetTimeRemaining() or 0
                    if itemRemaining ~= math.huge and (itemRemaining or 0) <= 0 then
                        self:Close(false)
                    end
                end)
            end
        else
            self.timerText:SetText("")
            if self.timerBar then
                self.timerBar:SetValue(0)
            end
        end
        return
    end

    -- Calculate progress using configurable timeout duration
    local timeout = self.responseTimeout or Loothing.Timing.DEFAULT_VOTE_TIMEOUT or 30
    if Loothing.Settings then
        timeout = Loothing.Settings:GetRollFrameTimeoutDuration() or timeout
    end
    local progress = (timeout > 0) and (remaining / timeout) or 1

    -- Update StatusBar value (0-1 range)
    self.timerBar:SetValue(math.max(0, math.min(1, progress)))

    -- Color and flash based on time remaining
    if remaining <= 5 then
        self.timerBar:SetStatusBarColor(0.8, 0.2, 0.2, 1)  -- Red

        -- Flash effect at <5s
        if not self.timerFlashing then
            self.timerFlashing = true
            self:StartTimerFlash()
        end
    elseif remaining <= 10 then
        self.timerBar:SetStatusBarColor(0.8, 0.6, 0.2, 1)  -- Yellow
        self:StopTimerFlash()
    else
        self.timerBar:SetStatusBarColor(0.2, 0.6, 0.2, 1)  -- Green
        self:StopTimerFlash()
    end

    -- Update text
    self.timerText:SetText(string.format("%d", math.ceil(remaining)))
end

--- Start flashing the timer bar when <5s remaining
function RollFrameMixin:StartTimerFlash()
    if self.flashAnim then return end
    if not self.timerContainer then return end

    -- Create a flash overlay if not exists
    if not self.timerFlashOverlay then
        self.timerFlashOverlay = self.timerContainer:CreateTexture(nil, "OVERLAY")
        self.timerFlashOverlay:SetAllPoints()
        self.timerFlashOverlay:SetColorTexture(1, 0, 0, 0.3)
    end
    self.timerFlashOverlay:Show()

    -- Reuse existing animation group if available; create only once per overlay
    local ag = self.timerFlashOverlay._flashAG
    if not ag then
        ag = self.timerFlashOverlay:CreateAnimationGroup()
        local alpha = ag:CreateAnimation("Alpha")
        alpha:SetFromAlpha(0)
        alpha:SetToAlpha(0.4)
        alpha:SetDuration(0.3)
        alpha:SetSmoothing("IN_OUT")
        ag:SetLooping("BOUNCE")
        self.timerFlashOverlay._flashAG = ag
    end
    ag:Play()
    self.flashAnim = ag
end

--- Stop flashing
function RollFrameMixin:StopTimerFlash()
    self.timerFlashing = false
    if self.flashAnim then
        self.flashAnim:Stop()
        self.flashAnim = nil
    end
    if self.timerFlashOverlay then
        self.timerFlashOverlay:Hide()
    end
end

--[[--------------------------------------------------------------------
    Submit Button State
----------------------------------------------------------------------]]

--- Update submit button enabled state
function RollFrameMixin:UpdateSubmitButton()
    local canSubmit = self.selectedResponse ~= nil
    local current = self.item and self:GetItemResponse(self.item.guid) or nil
    if current and current.pending then
        canSubmit = false
    end

    -- Check if notes are required (global setting or per-button)
    local requireNote = Loothing.Settings and Loothing.Settings:Get("rollFrame.requireNote", false)
    local noteText = self.noteEditBox and self.noteEditBox:GetText() or ""
    local noteMissing = (requireNote or self.requireNotesForResponse) and noteText:len() == 0

    if noteMissing and self.selectedResponse then
        canSubmit = false
    end

    if self.submitButton then
        self.submitButton:SetEnabled(canSubmit)

        -- Determine button label
        local btnText
        if noteMissing and self.selectedResponse then
            btnText = "Note Required"
        elseif current and current.submitted then
            btnText = "Already Submitted"
        elseif current and current.pending then
            btnText = "Sending..."
        else
            local L = Loothing.Locale
            btnText = L["SUBMIT_RESPONSE"] or "Submit Response"
        end

        -- Update label FontString (custom button uses .label, not SetText)
        if self.submitButton.label then
            self.submitButton.label:SetText(btnText)
        else
            self.submitButton:SetText(btnText)
        end

        -- Update visual enabled/disabled state for custom button
        if canSubmit then
            self.submitButton:SetBackdropColor(0.15, 0.35, 0.15, 0.95)
            self.submitButton:SetBackdropBorderColor(0.3, 0.6, 0.3, 1)
            if self.submitButton.label then
                self.submitButton.label:SetTextColor(0.9, 1, 0.9)
            end
        else
            self.submitButton:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
            self.submitButton:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.8)
            if self.submitButton.label then
                self.submitButton.label:SetTextColor(0.45, 0.45, 0.45)
            end
        end
    end

    -- Highlight note input when required but empty (skip if focused, let focus style take over)
    if self.noteEditBox and not self.noteEditBox:HasFocus() then
        if noteMissing and self.selectedResponse then
            self.noteEditBox:SetBackdropBorderColor(0.8, 0.3, 0.3, 1)
        else
            self.noteEditBox:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
        end
    end
end

--[[--------------------------------------------------------------------
    Submit Response
----------------------------------------------------------------------]]

--- Submit the player's response
function RollFrameMixin:Submit()
    if not self.selectedResponse then return end
    if not self.item then return end
    -- Prevent double-submit while pending
    local existing = self:GetItemResponse(self.item.guid)
    if existing and existing.pending then
        return
    end

    -- For roll-type items, trigger /roll if the response is ROLL
    if self.item.isRoll and self.selectedResponse == "ROLL" then
        self:DoRoll()
    end

    -- Get note text
    local note = self.noteEditBox and self.noteEditBox:GetText() or ""

    -- Roll already happened when frame opened (if enabled)
    -- Just send the response with whatever roll we have
    self:SendResponse(note)
end

--- Send the response to master looter
-- @param note string
function RollFrameMixin:SendResponse(note)
    if not self.item or not self.selectedResponse then return end

    -- Build response message
    local itemGUID = self.item.guid
    local response = self.selectedResponse

    -- Get roll for this specific item
    local roll, rollMin, rollMax = self:GetItemRoll(itemGUID)

    -- Always include a roll — generate silently if no explicit /roll was done
    if not roll then
        local rollSettings = Loothing.Settings and Loothing.Settings:Get("rollFrame.rollRange")
        rollMin = rollSettings and rollSettings.min or 1
        rollMax = rollSettings and rollSettings.max or 100
        roll = math.random(rollMin, rollMax)
    end

    -- Use passed note or get from edit box
    note = note or (self.noteEditBox and self.noteEditBox:GetText()) or ""

    -- Send via Comm system first (requires ML target)
    local ml = Loothing.Session and Loothing.Session:GetMasterLooter()
    if not (Loothing.Comm and Protocol and ml) then
        Loothing:Error("Cannot send response: master looter unavailable or comm offline")
        return
    end

    local ok = pcall(function()
        Loothing.Comm:SendPlayerResponse(
            itemGUID,
            response,
            note,
            roll,
            rollMin,
            rollMax,
            ml,
            Loothing.Session and Loothing.Session:GetSessionID()
        )
    end)

    if not ok then
        Loothing:Error("Failed to send response; please try again")
        return
    end

    -- Track pending ack (do not mark submitted yet)
    self:SetItemResponse(itemGUID, response, note, false, true)

    -- Fire event
    self:TriggerEvent("OnResponseSubmitted", self.item, response, note, roll)

    -- Print response to chat if enabled
    self:PrintResponseToChat(self.item, response, note)

    -- Update session buttons to show this item as pending
    self:UpdateSessionButtons()
end

--- Print response to chat for personal reference
-- @param item table
-- @param response any
-- @param note string
function RollFrameMixin:PrintResponseToChat(item, response, note)
    if not Loothing.Settings then return end
    if not Loothing.Settings:Get("rollFrame.printResponseToChat", false) then return end

    local responseInfo = response and Loothing.ResponseInfo[response]
    local responseName = responseInfo and responseInfo.name or tostring(response)
    local itemName = item and (item.name or item.itemLink or "Unknown") or "Unknown"

    local msg = string.format("Responded %s for %s", responseName, itemName)
    if note and note ~= "" then
        msg = msg .. string.format(' (Note: "%s")', note)
    end

    Loothing:Print(msg)
end

--- Check if an item has been responded to
-- @param itemGUID string
-- @return boolean
function RollFrameMixin:HasRespondedToItem(itemGUID)
    return self.itemResponses[itemGUID] and self.itemResponses[itemGUID].submitted
end

--- Get the response for an item
-- @param itemGUID string
-- @return table|nil - { response, note, submitted }
function RollFrameMixin:GetItemResponse(itemGUID)
    return self.itemResponses[itemGUID]
end

--- Set the response for an item
-- @param itemGUID string
-- @param response any - Response ID
-- @param note string
function RollFrameMixin:SetItemResponse(itemGUID, response, note, submitted, pending)
    self.itemResponses[itemGUID] = {
        response = response,
        note = note or "",
        submitted = submitted == true,
        pending = pending == true,
    }

    if pending then
        self:StartAckTimeout(itemGUID)
    else
        self:ClearAckTimeout(itemGUID)
    end
end

--- Start an ack timeout to prevent stuck pending states
-- @param itemGUID string
function RollFrameMixin:StartAckTimeout(itemGUID)
    if not itemGUID then return end

    self:ClearAckTimeout(itemGUID)

    local timeout = (Loothing.Timing and Loothing.Timing.DEFAULT_VOTE_TIMEOUT) or 30
    timeout = math.min(timeout, 10) -- keep UI responsive even if vote timeout is long

    self.responseAckTimers[itemGUID] = C_Timer.NewTimer(timeout, function()
        self.responseAckTimers[itemGUID] = nil

        local responseData = self.itemResponses[itemGUID]
        if responseData and responseData.pending then
            -- Clear pending state and allow resubmission
            self.itemResponses[itemGUID] = nil
            Loothing:Error("No response from master looter. Please resubmit.")

            if self.item and self.item.guid == itemGUID then
                self:ResetUIState(nil)
                self:UpdateSessionButtons()
            end
        end
    end)
end

--- Clear pending ack timer
-- @param itemGUID string
function RollFrameMixin:ClearAckTimeout(itemGUID)
    local timer = itemGUID and self.responseAckTimers[itemGUID]
    if timer then
        timer:Cancel()
        self.responseAckTimers[itemGUID] = nil
    end
end

--- Handle ack from master looter for a submitted response
-- @param itemGUID string
-- @param success boolean
function RollFrameMixin:OnPlayerResponseAck(itemGUID, success, sessionID)
    if not itemGUID then
        return
    end

    -- Ignore acks for stale sessions
    if sessionID and Loothing.Session and not Loothing.Session:IsCurrentSession(sessionID) then
        return
    end

    local responseData = self:GetItemResponse(itemGUID)
    if not responseData then
        return
    end

    self:ClearAckTimeout(itemGUID)

    if not success then
        -- Clear pending state and allow resubmission
        self.itemResponses[itemGUID] = nil
        Loothing:Error("Response not accepted. Please try again.")

        if self.item and self.item.guid == itemGUID then
            self:ResetUIState(nil)
            self:UpdateSessionButtons()
        end
        return
    end

    -- Mark as submitted
    self:SetItemResponse(itemGUID, responseData.response, responseData.note, true, false)

    -- Update UI if this is the current item
    if self.item and self.item.guid == itemGUID then
        self:ResetUIState(self:GetItemResponse(itemGUID))
        self:UpdateSessionButtons()

        -- Move to next if possible, otherwise close
        if not self:SwitchToNextUnrespondedItem() then
            self:Close(true)
        end
    else
        self:UpdateSessionButtons()
    end
end

--- Switch to the next item matching a filter function (wraps around)
-- @param filterFn function - Called with item, returns true if item is a valid target
-- @return boolean - True if switched to a matching item, false if none found
function RollFrameMixin:SwitchToNextItem(filterFn)
    for i = self.currentItemIndex + 1, #self.items do
        local item = self.items[i]
        if item and filterFn(item) then
            self:SwitchToItem(i)
            return true
        end
    end

    for i = 1, self.currentItemIndex do
        local item = self.items[i]
        if item and filterFn(item) then
            self:SwitchToItem(i)
            return true
        end
    end

    return false
end

--- Switch to the next item the player has not yet responded to
-- @return boolean - True if switched, false if all items responded
function RollFrameMixin:SwitchToNextUnrespondedItem()
    return self:SwitchToNextItem(function(item)
        return not self:HasRespondedToItem(item.guid)
    end)
end

--- Switch to the next non-awarded item, or close the frame if none remain
function RollFrameMixin:SwitchToNextPendingItem()
    if not self:SwitchToNextItem(function(item)
        return item.state ~= Loothing.ItemState.AWARDED
    end) then
        self:Close(false)
    end
end

--- Get count of unresponded items
-- @return number
function RollFrameMixin:GetUnrespondedCount()
    local count = 0
    for _, item in ipairs(self.items) do
        if not self:HasRespondedToItem(item.guid) then
            count = count + 1
        end
    end
    return count
end

--[[--------------------------------------------------------------------
    Session Event Handlers
----------------------------------------------------------------------]]

--- Handle voting ended event
-- @param itemGUID string
function RollFrameMixin:OnVotingEnded(itemGUID)
    if self.item and self.item.guid == itemGUID then
        self:Close(false)
    end
end

--[[--------------------------------------------------------------------
    Visibility Control
----------------------------------------------------------------------]]

--- Show the frame
function RollFrameMixin:Show()
    self:RestorePosition()
    self.frame:Show()
end

--- Hide the frame
function RollFrameMixin:Hide()
    self:StopTimer()
    self:UnregisterRollCapture()
    self.frame:Hide()
end

--- Toggle visibility
function RollFrameMixin:Toggle()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

--- Check if shown
-- @return boolean
function RollFrameMixin:IsShown()
    return self.frame:IsShown()
end

--- Close the frame
-- @param submitted boolean - True if response was submitted
function RollFrameMixin:Close(submitted)
    self:StopTimer()
    self:SavePosition()
    self.frame:Hide()

    if not submitted then
        self:TriggerEvent("OnFrameClosed", self.item)
    end

    -- Clear all state
    self.item = nil
    self.selectedResponse = nil
    self.roll = nil

    -- Clear multi-item session state
    self.items = {}
    self.currentItemIndex = 1
    self.itemRolls = {}
    self.itemResponses = {}
    for guid, timer in pairs(self.responseAckTimers or {}) do
        timer:Cancel()
        self.responseAckTimers[guid] = nil
    end
    self.pendingRollStarted = {}
    self.sessionButtonWarningShown = nil
end

--[[--------------------------------------------------------------------
    Position Persistence
----------------------------------------------------------------------]]

--- Save current position
function RollFrameMixin:SavePosition()
    if not Loothing.Settings then return end

    local point, _, _, x, y = self.frame:GetPoint()
    Loothing.Settings:Set("rollFrame.position", {
        point = point,
        x = x,
        y = y,
    })
end

--- Restore saved position
function RollFrameMixin:RestorePosition()
    if not Loothing.Settings then return end

    local pos = Loothing.Settings:Get("rollFrame.position")
    if pos and pos.point then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    end
end

--[[--------------------------------------------------------------------
    Factory
----------------------------------------------------------------------]]

--- Create a new RollFrame instance
-- @return table - RollFrameMixin instance
local function CreateRollFrame()
    local frame = Loolib.CreateFromMixins(RollFrameMixin)
    if not frame then
        return nil
    end
    frame:Init()
    return frame
end

ns.CreateRollFrame = CreateRollFrame
