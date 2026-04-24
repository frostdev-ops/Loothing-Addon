local _, ns = ...

local Loothing = ns.Addon
local Utils = ns.Utils
local TestRunner = ns.TestRunner
local Assert = ns.Assert

if TestRunner and Assert and Loothing and ns.CreateObserver then
    local saved = {}

    local function SaveGlobals()
        saved.Council = Loothing.Council
        saved.Observer = Loothing.Observer
        saved.Session = Loothing.Session
        saved.Settings = Loothing.Settings
        saved.handleLoot = Loothing.handleLoot
        saved.isMasterLooter = Loothing.isMasterLooter
        saved.masterLooter = Loothing.masterLooter
        saved.IsCanonicalML = Loothing.IsCanonicalML
        saved.mlStateVerified = Loothing.mlStateVerified
        saved.GetPlayerFullName = Utils.GetPlayerFullName
    end

    local function RestoreGlobals()
        Loothing.Council = saved.Council
        Loothing.Observer = saved.Observer
        Loothing.Session = saved.Session
        Loothing.Settings = saved.Settings
        Loothing.handleLoot = saved.handleLoot
        Loothing.isMasterLooter = saved.isMasterLooter
        Loothing.masterLooter = saved.masterLooter
        Loothing.IsCanonicalML = saved.IsCanonicalML
        Loothing.mlStateVerified = saved.mlStateVerified
        Utils.GetPlayerFullName = saved.GetPlayerFullName
    end

    local function RestrictiveSettings()
        return {
            GetObserverList = function() return {} end,
            GetObserverPermissions = function()
                return {
                    seeVoteCounts = false,
                    seeVoterIdentities = false,
                    seeResponses = false,
                    seeNotes = false,
                }
            end,
            GetMLIsObserver = function() return false end,
        }
    end

    TestRunner:Describe("Observer Visibility", function()
        TestRunner:BeforeEach(function()
            SaveGlobals()
            Utils.GetPlayerFullName = function() return "Felbane-Duskwood" end
            Loothing.Council = {
                IsPlayerCouncilMember = function() return false end,
            }
            Loothing.Session = {
                IsMasterLooter = function() return false end,
            }
            Loothing.Settings = RestrictiveSettings()
            Loothing.isMasterLooter = false
            Loothing.masterLooter = nil
            Loothing.handleLoot = false
            Loothing.IsCanonicalML = function() return false end
            Loothing.mlStateVerified = true
        end)

        TestRunner:AfterEach(function()
            RestoreGlobals()
        end)

        TestRunner:It("grants ML visibility when global ML state is true", function()
            Loothing.isMasterLooter = true
            Loothing.handleLoot = true
            Loothing.masterLooter = "Felbane-Duskwood"
            local observer = ns.CreateObserver()

            Assert.IsTrue(observer:HasMasterLooterVisibility(), "Global ML should be treated as ML visibility")
            Assert.IsTrue(observer:CanPlayerSeeResponses(), "ML should always see candidate responses")
            Assert.IsTrue(observer:CanPlayerSeeVoteCounts(), "ML should always see vote counts")
            Assert.IsTrue(observer:CanPlayerSeeVoterIdentities(), "ML should always see voter identities")
            Assert.IsTrue(observer:CanPlayerSeeNotes(), "ML should always see notes")
        end, { category = "unit" })

        TestRunner:It("does not trust cached ML globals before live verification", function()
            Loothing.isMasterLooter = true
            Loothing.handleLoot = true
            Loothing.masterLooter = "Felbane-Duskwood"
            Loothing.mlStateVerified = false
            local observer = ns.CreateObserver()

            Assert.IsFalse(observer:HasMasterLooterVisibility(), "Unverified reconnect globals should not grant ML visibility")
            Assert.IsFalse(observer:CanPlayerSeeVoteCounts(), "Unverified reconnect globals should not reveal vote counts")
            Assert.IsFalse(observer:CanPlayerSeeVoterIdentities(), "Unverified reconnect globals should not reveal voter identities")
        end, { category = "unit" })

        TestRunner:It("grants ML visibility when canonical ML matches current player", function()
            Loothing.masterLooter = "Felbane-duskwood"
            Loothing.IsCanonicalML = function() return true end
            local observer = ns.CreateObserver()

            Assert.IsTrue(observer:HasMasterLooterVisibility(), "Canonical ML should be treated as ML visibility")
            Assert.IsTrue(observer:CanPlayerSeeResponses(), "Canonical ML should see responses despite observer restrictions")
        end, { category = "unit" })

        TestRunner:It("uses remote observer permissions for regular observers", function()
            local observer = ns.CreateObserver()
            observer.remotePrimary = true
            observer.remotePermissions = {
                seeVoteCounts = false,
                seeVoterIdentities = false,
                seeResponses = true,
                seeNotes = true,
            }
            observer.remoteOpenObservation = true
            observer.remoteList["observer-duskwood"] = true

            Assert.IsFalse(observer:HasMasterLooterVisibility(), "Regular observer should not be ML")
            Assert.IsTrue(observer:IsObserver("Observer-Duskwood"), "Remote observer roster should identify observers")
            Assert.IsTrue(observer:CanPlayerSeeResponses(), "Remote permissions should allow responses")
            Assert.IsTrue(observer:CanPlayerSeeNotes(), "Remote permissions should allow notes")
            Assert.IsFalse(observer:CanPlayerSeeVoteCounts(), "Remote permissions should hide vote counts")
            Assert.IsFalse(observer:CanPlayerSeeVoterIdentities(), "Remote permissions should hide voter identities")
        end, { category = "unit" })

        TestRunner:It("keeps ML council visibility but disables voting in ML observer mode", function()
            Loothing.isMasterLooter = true
            Loothing.handleLoot = true
            Loothing.masterLooter = "Felbane-Duskwood"
            Loothing.Settings = {
                GetObserverList = function() return {} end,
                GetObserverPermissions = function()
                    return {
                        seeVoteCounts = false,
                        seeVoterIdentities = false,
                        seeResponses = false,
                        seeNotes = false,
                    }
                end,
                GetMLIsObserver = function() return true end,
            }
            local observer = ns.CreateObserver()
            Loothing.Observer = observer

            local council = {
                IsPlayerCouncilMember = function() return true end,
            }
            setmetatable(council, { __index = ns.CouncilMixin })

            Assert.IsTrue(observer:CanPlayerSeeResponses(), "ML observer should keep full response visibility")
            Assert.IsTrue(observer:CanPlayerSeeVoteCounts(), "ML observer should keep full vote visibility")
            Assert.IsFalse(council:CanPlayerVote(), "ML observer mode should disable ML council voting")
        end, { category = "unit" })
    end)
end
