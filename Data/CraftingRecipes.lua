--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    CraftingRecipes - Scans profession recipes for reagent quantities
    Exports via desktopExchange for the Tauri desktop app to upload
    to the server. Triggered manually via /lt export crafting.
----------------------------------------------------------------------]]

local _, ns = ...
local Loolib = LibStub("Loolib")
local Loothing = ns.Addon
local time = time
local format = string.format
local print = print

--[[--------------------------------------------------------------------
    CraftingRecipesMixin
----------------------------------------------------------------------]]

local CraftingRecipesMixin = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
ns.CraftingRecipesMixin = CraftingRecipesMixin

local CRAFTING_RECIPES_EVENTS = {
    "OnCraftingRecipesScanned",
}

--- Reagent type enums (Enum.CraftingReagentType)
local REAGENT_TYPE_BASIC = Enum.CraftingReagentType and Enum.CraftingReagentType.Basic or 1
local REAGENT_TYPE_MODIFYING = Enum.CraftingReagentType and Enum.CraftingReagentType.Modifying or 2
local REAGENT_TYPE_FINISHING = Enum.CraftingReagentType and Enum.CraftingReagentType.Finishing or 3

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

function CraftingRecipesMixin:Init()
    Loolib.CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(CRAFTING_RECIPES_EVENTS)
end

--[[--------------------------------------------------------------------
    Scanning
----------------------------------------------------------------------]]

--- Scan all recipes in the currently open profession window.
--- Must be called while a profession window is open.
--- @return boolean success
function CraftingRecipesMixin:ScanCurrentProfession()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetAllRecipeIDs then
        print("|cffff4444[Loothing]|r Crafting APIs not available.")
        return false
    end

    -- Get profession info
    local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    if not profInfo or not profInfo.professionName then
        print("|cffff4444[Loothing]|r Open a profession window first, then run this command.")
        return false
    end

    local profName = profInfo.professionName

    local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
    if not recipeIDs or #recipeIDs == 0 then
        print(format("|cffff4444[Loothing]|r No recipes found for %s.", profName))
        return false
    end

    local recipes = {}
    local count = 0

    for _, recipeID in ipairs(recipeIDs) do
        local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
        if schematic and schematic.reagentSlotSchematics and #schematic.reagentSlotSchematics > 0 then
            local reagentList = {}

            for _, slot in ipairs(schematic.reagentSlotSchematics) do
                local entry = {
                    quantity = slot.quantityRequired or 1,
                }

                if slot.reagentType == REAGENT_TYPE_MODIFYING or slot.reagentType == REAGENT_TYPE_FINISHING then
                    -- Slot reagent (quality-selectable or finishing)
                    entry.reagentType = 2

                    if slot.slotInfo then
                        entry.slotTypeId = slot.slotInfo.mcrSlotID
                        entry.name = slot.slotInfo.slotText or "Unknown"
                    else
                        entry.name = "Unknown"
                    end
                elseif slot.reagentType == REAGENT_TYPE_BASIC then
                    -- Fixed reagent
                    entry.reagentType = 1

                    if slot.reagents and slot.reagents[1] and slot.reagents[1].itemID then
                        entry.itemId = slot.reagents[1].itemID
                        local itemName = C_Item.GetItemNameByID(slot.reagents[1].itemID)
                        entry.name = itemName or ("Item:" .. slot.reagents[1].itemID)
                    else
                        entry.name = "Unknown"
                    end
                end

                if entry.name then
                    reagentList[#reagentList + 1] = entry
                end
            end

            recipes[recipeID] = {
                name = schematic.name or "",
                reagents = reagentList,
            }
            count = count + 1
        end
    end

    if count == 0 then
        print(format("|cffff4444[Loothing]|r No recipes with reagents found for %s.", profName))
        return false
    end

    -- Save to desktopExchange
    self:SaveProfessionData(profName, recipes)

    print(format("|cff00ccff[Loothing]|r Exported %d %s recipes to desktop exchange.", count, profName))

    self:TriggerEvent("OnCraftingRecipesScanned", profName, count)
    return true
end

--[[--------------------------------------------------------------------
    Persistence
----------------------------------------------------------------------]]

--- Save scanned profession data into desktopExchange.craftingRecipes
--- Additive across professions — each profession replaces its own data
function CraftingRecipesMixin:SaveProfessionData(profName, recipes)
    if not Loothing.Settings then return end

    local existing = Loothing.Settings:GetGlobalValue("desktopExchange.craftingRecipes") or {}

    -- Preserve metadata and other professions
    existing.version = 1
    existing.scannedAt = time()

    -- Character info
    local name = UnitName("player")
    local realm = GetNormalizedRealmName() or GetRealmName()
    existing.scannedBy = format("%s-%s", name, realm)

    -- Initialize professions table
    existing.professions = existing.professions or {}

    -- Replace this profession's data
    existing.professions[profName] = {
        recipes = recipes,
    }

    Loothing.Settings:SetGlobalValue("desktopExchange.craftingRecipes", existing)
end
