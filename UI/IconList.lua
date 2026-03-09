--[[--------------------------------------------------------------------
    Loothing - Loot Council Addon for WoW 12.0+
    IconList - Common icons for the response button icon picker
----------------------------------------------------------------------]]

local _, ns = ...
local Loothing = ns.Addon

Loothing.IconList = {
    -- Loot / Group Loot
    { path = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",   label = "Dice" },
    { path = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",   label = "Coin" },
    { path = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",   label = "Pass" },

    -- Checkmark / X / Status
    { path = "Interface\\RaidFrame\\ReadyCheck-Ready",               label = "Check (Green)" },
    { path = "Interface\\RaidFrame\\ReadyCheck-NotReady",            label = "X (Red)" },
    { path = "Interface\\RaidFrame\\ReadyCheck-Waiting",             label = "Question (Yellow)" },
    { path = "Interface\\COMMON\\Indicator-Green",                   label = "Dot Green" },
    { path = "Interface\\COMMON\\Indicator-Yellow",                  label = "Dot Yellow" },
    { path = "Interface\\COMMON\\Indicator-Red",                     label = "Dot Red" },
    { path = "Interface\\COMMON\\Indicator-Gray",                    label = "Dot Gray" },

    -- Arrows / Priority
    { path = "Interface\\Icons\\misc_arrowlup",                      label = "Arrow Up" },
    { path = "Interface\\Icons\\misc_arrowdown",                     label = "Arrow Down" },
    { path = "Interface\\Icons\\misc_arrowleft",                     label = "Arrow Left" },
    { path = "Interface\\Icons\\misc_arrowright",                    label = "Arrow Right" },

    -- Raid Markers / Targets
    { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1",    label = "Star" },
    { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2",    label = "Circle" },
    { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3",    label = "Diamond" },
    { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4",    label = "Triangle" },
    { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5",    label = "Moon" },
    { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6",    label = "Square" },
    { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7",    label = "Cross" },
    { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",    label = "Skull" },

    -- Roles
    { path = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES",      label = "All Roles" },
    { path = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES",              label = "Role Icons" },

    -- Weapons
    { path = "Interface\\Icons\\INV_Sword_04",             label = "Sword" },
    { path = "Interface\\Icons\\INV_Sword_39",             label = "Sword (Epic)" },
    { path = "Interface\\Icons\\INV_Staff_10",             label = "Staff" },
    { path = "Interface\\Icons\\INV_Mace_01",              label = "Mace" },
    { path = "Interface\\Icons\\INV_Axe_04",               label = "Axe" },
    { path = "Interface\\Icons\\INV_Weapon_Bow_07",        label = "Bow" },
    { path = "Interface\\Icons\\INV_Weapon_Rifle_01",      label = "Gun" },
    { path = "Interface\\Icons\\INV_ThrowingKnife_04",     label = "Dagger" },
    { path = "Interface\\Icons\\INV_Weapon_Glaive_01",     label = "Glaive" },
    { path = "Interface\\Icons\\INV_Misc_Orb_01",          label = "Off-Hand" },
    { path = "Interface\\Icons\\INV_Wand_07",              label = "Wand" },

    -- Armor
    { path = "Interface\\Icons\\INV_Shield_06",            label = "Shield" },
    { path = "Interface\\Icons\\INV_Chest_Plate16",        label = "Plate" },
    { path = "Interface\\Icons\\INV_Chest_Chain_15",       label = "Mail" },
    { path = "Interface\\Icons\\INV_Chest_Leather_09",     label = "Leather" },
    { path = "Interface\\Icons\\INV_Chest_Cloth_21",       label = "Cloth" },
    { path = "Interface\\Icons\\INV_Helmet_03",            label = "Helmet" },
    { path = "Interface\\Icons\\INV_Gauntlets_05",         label = "Gloves" },
    { path = "Interface\\Icons\\INV_Belt_13",              label = "Belt" },
    { path = "Interface\\Icons\\INV_Boots_05",             label = "Boots" },
    { path = "Interface\\Icons\\INV_Jewelry_Ring_03",      label = "Ring" },
    { path = "Interface\\Icons\\INV_Jewelry_Necklace_07",  label = "Necklace" },
    { path = "Interface\\Icons\\INV_Jewelry_Trinket_04",   label = "Trinket" },
    { path = "Interface\\Icons\\INV_Misc_Cape_11",         label = "Cloak" },

    -- Gems / Enchants
    { path = "Interface\\Icons\\INV_Jewelcrafting_AmberJewel_01",    label = "Gem (Amber)" },
    { path = "Interface\\Icons\\INV_Jewelcrafting_Jewel_05",         label = "Jewel" },
    { path = "Interface\\Icons\\INV_Misc_Gem_Sapphire_02",          label = "Sapphire" },
    { path = "Interface\\Icons\\INV_Misc_Gem_Ruby_02",              label = "Ruby" },
    { path = "Interface\\Icons\\INV_Misc_Gem_Emerald_02",           label = "Emerald" },
    { path = "Interface\\Icons\\INV_Misc_Gem_Diamond_06",           label = "Diamond" },

    -- Trade / Economy
    { path = "Interface\\Icons\\INV_Misc_Coin_02",                   label = "Gold Coin" },
    { path = "Interface\\Icons\\INV_Misc_Coin_17",                   label = "Silver Coin" },
    { path = "Interface\\Icons\\INV_Misc_Bag_10",                    label = "Bag" },
    { path = "Interface\\Icons\\INV_Misc_Bag_17",                    label = "Backpack" },

    -- Combat / Abilities
    { path = "Interface\\Icons\\Ability_DualWield",        label = "Dual Wield" },
    { path = "Interface\\Icons\\Ability_Warrior_Sunder",   label = "Sunder (Tank)" },
    { path = "Interface\\Icons\\Ability_Warrior_BattleShout",        label = "Battle Shout" },
    { path = "Interface\\Icons\\Ability_Stealth",          label = "Stealth" },
    { path = "Interface\\Icons\\Ability_Rogue_Sprint",               label = "Sprint" },
    { path = "Interface\\Icons\\Ability_Hunter_Pet_Wolf",            label = "Wolf" },
    { path = "Interface\\Icons\\Ability_Marksmanship",               label = "Marksmanship" },

    -- Spells / Magic
    { path = "Interface\\Icons\\Spell_Holy_FlashHeal",               label = "Flash Heal" },
    { path = "Interface\\Icons\\Spell_Holy_HolyBolt",                label = "Holy Bolt" },
    { path = "Interface\\Icons\\Spell_Holy_DivineSpirit",            label = "Divine Spirit" },
    { path = "Interface\\Icons\\Spell_Holy_PowerWordShield",         label = "Power Word: Shield" },
    { path = "Interface\\Icons\\Spell_Nature_Tranquility",           label = "Tranquility" },
    { path = "Interface\\Icons\\Spell_Nature_Lightning",             label = "Lightning" },
    { path = "Interface\\Icons\\Spell_Fire_FireBall02",              label = "Fireball" },
    { path = "Interface\\Icons\\Spell_Frost_FrostNova",              label = "Frost Nova" },
    { path = "Interface\\Icons\\Spell_Shadow_DeathCoil",             label = "Death Coil" },
    { path = "Interface\\Icons\\Spell_Shadow_SacrificialShield",     label = "Dark Shield" },
    { path = "Interface\\Icons\\Spell_Arcane_Blink",                 label = "Blink" },
    { path = "Interface\\Icons\\Spell_ChargePositive",               label = "Plus" },
    { path = "Interface\\Icons\\Spell_ChargeNegative",               label = "Minus" },

    -- Professions
    { path = "Interface\\Icons\\Trade_BlackSmithing",                label = "Blacksmithing" },
    { path = "Interface\\Icons\\Trade_LeatherWorking",               label = "Leatherworking" },
    { path = "Interface\\Icons\\Trade_Tailoring",                    label = "Tailoring" },
    { path = "Interface\\Icons\\Trade_Engraving",                    label = "Enchanting" },
    { path = "Interface\\Icons\\Trade_Alchemy",                      label = "Alchemy" },
    { path = "Interface\\Icons\\Trade_Engineering",                  label = "Engineering" },
    { path = "Interface\\Icons\\Trade_Mining",                       label = "Mining" },
    { path = "Interface\\Icons\\Trade_Herbalism",                    label = "Herbalism" },
    { path = "Interface\\Icons\\INV_Misc_Gem_01",                    label = "Jewelcrafting" },
    { path = "Interface\\Icons\\INV_Inscription_Tradeskill01",       label = "Inscription" },

    -- Class Icons
    { path = "Interface\\Icons\\ClassIcon_Warrior",                  label = "Warrior" },
    { path = "Interface\\Icons\\ClassIcon_Paladin",                  label = "Paladin" },
    { path = "Interface\\Icons\\ClassIcon_Hunter",                   label = "Hunter" },
    { path = "Interface\\Icons\\ClassIcon_Rogue",                    label = "Rogue" },
    { path = "Interface\\Icons\\ClassIcon_Priest",                   label = "Priest" },
    { path = "Interface\\Icons\\ClassIcon_Deathknight",              label = "Death Knight" },
    { path = "Interface\\Icons\\ClassIcon_Shaman",                   label = "Shaman" },
    { path = "Interface\\Icons\\ClassIcon_Mage",                     label = "Mage" },
    { path = "Interface\\Icons\\ClassIcon_Warlock",                  label = "Warlock" },
    { path = "Interface\\Icons\\ClassIcon_Monk",                     label = "Monk" },
    { path = "Interface\\Icons\\ClassIcon_Druid",                    label = "Druid" },
    { path = "Interface\\Icons\\ClassIcon_Demonhunter",              label = "Demon Hunter" },
    { path = "Interface\\Icons\\ClassIcon_Evoker",                   label = "Evoker" },

    -- Achievements / Misc
    { path = "Interface\\Icons\\Achievement_Guildperk_Bountiful",    label = "Bountiful" },
    { path = "Interface\\Icons\\Achievement_Guildperk_WorkingOver",  label = "Working Over" },
    { path = "Interface\\Icons\\INV_Arcane_Orb",                     label = "Arcane Orb" },
    { path = "Interface\\Icons\\INV_Misc_QuestionMark",              label = "Question Mark" },
    { path = "Interface\\Icons\\INV_Misc_Note_01",                   label = "Note" },
    { path = "Interface\\Icons\\INV_Misc_Book_09",                   label = "Book" },
    { path = "Interface\\Icons\\INV_Misc_Gear_01",                   label = "Gear" },
    { path = "Interface\\Icons\\INV_Misc_Key_03",                    label = "Key" },
    { path = "Interface\\Icons\\Racial_Dwarf_FindTreasure",          label = "Treasure" },
    { path = "Interface\\Icons\\INV_Misc_Rune_01",                   label = "Rune" },
    { path = "Interface\\Icons\\INV_Pet_BabyBlizzardBear",           label = "Pet Bear" },
    { path = "Interface\\Icons\\Ability_Mount_RidingHorse",          label = "Mount" },
    { path = "Interface\\Icons\\Achievement_Boss_Ragnaros",          label = "Ragnaros" },
    { path = "Interface\\Icons\\INV_Misc_Herb_Felblossom",           label = "Felblossom" },
    { path = "Interface\\Icons\\Spell_Holy_SurgeOfLight",            label = "Surge of Light" },
    { path = "Interface\\Icons\\Spell_Holy_BorrowedTime",            label = "Borrowed Time" },
    { path = "Interface\\Icons\\INV_Misc_Ticket_Tarot_Heroism",     label = "Heroism Card" },
    { path = "Interface\\Icons\\Spell_Holy_SealOfMight",             label = "Seal of Might" },
    { path = "Interface\\Icons\\INV_Enchant_VoidSphere",             label = "Void Sphere" },
    { path = "Interface\\Icons\\Ability_Paladin_BeaconOfLight",      label = "Beacon" },
}
