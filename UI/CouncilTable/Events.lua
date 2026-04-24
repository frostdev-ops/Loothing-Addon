--[[--------------------------------------------------------------------
    Loothing - UI: Council Table Events
    Session and item event handlers with throttled updates
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon

local CouncilTableMixin = ns.CouncilTableMixin or {}
ns.CouncilTableMixin = CouncilTableMixin

local function IsCachedMLObserver()
    return Loothing.mlStateVerified == false
        and Loothing.IsCachedMasterLooterCandidate
        and Loothing:IsCachedMasterLooterCandidate()
        and Loothing.Observer
        and Loothing.Observer:IsMasterLooterObserverModeEnabled()
end

function CouncilTableMixin:RegisterEvents()
    if not Loothing.Session then return end

    Loothing.Session:RegisterCallback("OnSessionStarted", function() self:OnSessionStarted() end, self)
    Loothing.Session:RegisterCallback("OnSessionEnded", function() self:OnSessionEnded() end, self)
    Loothing.Session:RegisterCallback("OnItemAdded", function(_, item) self:OnItemAdded(item) end, self)
    Loothing.Session:RegisterCallback("OnItemRemoved", function(_, item) self:OnItemRemoved(item) end, self)
    Loothing.Session:RegisterCallback("OnItemStateChanged", function(_, item) self:OnItemStateChanged(item) end, self)
    Loothing.Session:RegisterCallback("OnVotingStarted", function(_, item) self:OnVotingStarted(item) end, self)
    Loothing.Session:RegisterCallback("OnVotingEnded", function(_, item) self:OnVotingEnded(item) end, self)
    Loothing.Session:RegisterCallback("OnItemAwarded", function(_, item, winner) self:OnItemAwarded(item, winner) end, self)

    -- Keep candidates live-updating (throttled)
    Loothing.Session:RegisterCallback("OnCandidateAdded", function(_, item, candidate) self:OnCandidateAdded(item, candidate) end, self)
    Loothing.Session:RegisterCallback("OnCandidateUpdated", function(_, item, candidate) self:OnCandidateUpdated(item, candidate) end, self)
    Loothing.Session:RegisterCallback("OnVoteReceived", function(_, item) self:OnVoteReceived(item) end, self)

    -- Refresh when tradability status arrives
    Loothing.Session:RegisterCallback("OnItemTradabilityChanged", function(_, item)
        if self.currentItem and self.currentItem.guid == item.guid then
            self:ThrottledRefresh()
        end
        self:RefreshItemTabs()
    end, self)

    -- Rebuild the "items won (instance/weekly)" counters when a remote award
    -- lands while the voting frame is open. The columns read from a per-refresh
    -- cache (Rows.lua EnrichCandidates -> History:BuildPlayerCountCache); without
    -- this hook, council members saw stale zeros until they clicked a sort header
    -- or switched items.
    if Loothing.History and Loothing.History.RegisterCallback then
        Loothing.History:RegisterCallback("OnHistoryChanged", function()
            if self.ThrottledRefresh then self:ThrottledRefresh() end
        end, self)
    end

    -- Refresh the Intel column when desktop intel arrives. Each row's
    -- button visibility is gated on PlayerIntel:Get(candidate) and so
    -- needs a DoCellUpdate pass whenever the set of intel-bearing
    -- players changes (own desktop sync, `/lt share` merge, etc.).
    if Loothing.PlayerIntel and Loothing.PlayerIntel.RegisterCallback then
        Loothing.PlayerIntel:RegisterCallback("OnPlayerIntelLoaded", function()
            if self.ThrottledRefresh then self:ThrottledRefresh() end
        end, self)
    end
end

function CouncilTableMixin:OnSessionStarted()
    self:RefreshItemTabs()
end

function CouncilTableMixin:OnSessionEnded()
    self:Clear()
end

function CouncilTableMixin:OnItemAdded(item)
    self:RefreshItemTabs()
    if item.candidateManager then
        item.candidateManager:RegisterCallback("OnCandidateAdded", function(_, candidate) self:OnCandidateAdded(item, candidate) end, self)
        item.candidateManager:RegisterCallback("OnCandidateUpdated", function(_, candidate) self:OnCandidateUpdated(item, candidate) end, self)
    end
end

function CouncilTableMixin:OnItemRemoved(item)
    self:RefreshItemTabs()
    if self.currentItem and self.currentItem.guid == item.guid then
        self:SelectFirstItem()
    end
end

function CouncilTableMixin:OnItemStateChanged(item)
    self:RefreshItemTabs()
    if self.currentItem and self.currentItem.guid == item.guid then
        self:UpdateActionButtons()
    end
end

function CouncilTableMixin:OnVotingStarted(item)
    local isCouncil = Loothing.Council and Loothing.Council:IsPlayerCouncilMember()
    local isML = self.HasMasterLooterVisibility and self.HasMasterLooterVisibility()
    local isObserver = Loothing.Observer and Loothing.Observer:IsPlayerObserver()
    local isMLObserver = Loothing.Observer and Loothing.Observer:IsMLObserver()
    if isCouncil or isML or isObserver or isMLObserver or IsCachedMLObserver() then
        self:Show()
        self:SelectItemTab(item.guid)
    end
    if self.currentItem and self.currentItem.guid == item.guid then
        self:UpdateActionButtons()
    end
end

function CouncilTableMixin:OnVotingEnded(item)
    if self.currentItem and self.currentItem.guid == item.guid then
        self:ThrottledRefresh()
        self:UpdateActionButtons()
    end
end

function CouncilTableMixin:OnItemAwarded(item, _winner)
    self:RefreshItemTabs()
    if self.currentItem and self.currentItem.guid == item.guid then
        self:ThrottledRefresh()
        self:UpdateActionButtons()
    end
end

function CouncilTableMixin:OnCandidateAdded(item, _candidate)
    if self.currentItem and self.currentItem.guid == item.guid then
        self:ThrottledRefresh()
    end
end

function CouncilTableMixin:OnCandidateUpdated(item, _candidate)
    if self.currentItem and self.currentItem.guid == item.guid then
        self:ThrottledRefresh()
        self:UpdateVoterProgress()
    end
    self:UpdateItemTabVotedIndicators()
end

function CouncilTableMixin:OnVoteReceived(item)
    if self.currentItem and self.currentItem.guid == item.guid then
        self:ThrottledRefresh()
        self:UpdateVoterProgress()
    end
    self:UpdateItemTabVotedIndicators()
end
