# Migration Notes

## Foundation 1.9.6

### Trading Village

Simplified TRADING_VILLAGE's list of resources by simply requiring a list of assets.

-- OLD WAY
saltTrader:registerAsset({
    DataType = "TRADING_VILLAGE",
    Id = SaltPrefix .. "_VILLAGE_NANTES",
    BuyingResourceList = {
        {
            ResourceMaxAmount = { Resource = "HONEY", Quantity = 30 },
            ReplenishingAmount = 10,
        },
    },
    SellingResourceList = {
        {
            ResourceMaxAmount = { Resource = CommonResourceSalt, Quantity = 50 },
            ReplenishingAmount = 20,
        }
    },
})

-- NEW WAY
saltTrader:registerAsset({
    DataType = "TRADING_VILLAGE",
    Id = SaltPrefix .. "_VILLAGE_NANTES",
    BuyingResourceList = {
        "HONEY",
        "HERBS"
    },
    SellingResourceList = {
        CommonResourceSalt
    },
})

## Foundation 1.9.3

- Merged Nun and Monk profiles/statuses together, introducing gendered fields based on GENDER_USAGE
- Text fields: if empty in gender, takes GENERIC; if GENERIC empty, takes MASCULINE
- CHARACTER_SETUP_DATA per gender with ALL as fallback
- AGENT_PROFILE, VILLAGER_STATUS, AGENT_PROFILE_FUNCTION now use gendered fields

## Foundation 1.9.0.7

### Sub-buildings and building functions

Buildings can have sub-buildings via BUILDING.SubAssetBuildingList. Each sub-building can have a building function.

### Building part list

BUILDING.BuildingPartSetList replaced with BUILDING.AssetBuildingPartList.

### Unlockables

Unlockables now use prerequisite lists and game actions (GAME_ACTION) instead of direct unlocks.

### Estates and progression

Progress tiers grouped into PROGRESS_PATH assets. Unlockables added directly to PROGRESS_TIER_DATA.

### Quests

Quests reworked with ObjectiveList, FailureConditionList, QuestSuccessActionList, QuestFailActionList using GAME_CONDITION types.

### Events

Events reworked to trigger ActionList instead of single choices. Narrative panels via GAME_ACTION_SHOW_NARRATIVE_PANEL.

## Foundation 1.8.0.0

### Resource bundles

BUILDING_PART_COST.RessourcesNeeded replaced with ResourceNeededList (list of lists of RESOURCE_QUANTITY_PAIR).

## Foundation 1.7.1

### Texture loading

Some TEXTURE properties changed to ATLAS_CELL. registerAssetId now accepts optional type parameter.

## Foundation 1.6.0.0522

### BUILDING and MONUMENT asset types

Monuments merged into BUILDING type. Buildings use AssetCoreBuildingPart. Monuments use core part + BuildingPartSetList.

### Bridge mover

Bridge mover placement changed - now needs mover on start/end parts instead of core part.

### Slope constructor

Bridge end parts need BUILDING_CONSTRUCTOR_SLOPE.

### Building zone and basement

Scalable building parts need non-empty building zone for basement placement.

## Foundation 1.4.5.1009

### Building Part Function

BuildingFunction replaced with AssetBuildingFunction. Building functions must be declared as BUILDING_FUNCTION assets.

### Resource Type List

RESOURCE_TYPE enumeration removed, replaced with plain strings. ResourceType renamed to ResourceTypeList.

## Foundation 1.3.1.0802

### Building Part Sets

BuildingPartList replaced with BuildingPartSetList (list of BUILDING_PART_SET).

### Event Choices

EVENT now has ChoiceList replacing ActionList.

## Foundation 1.2.2.3105

### New mod.json

Foundation requires a mod.json description file.

### createMod() function is simplified

foundation.createMod() takes no parameters.

### GENERAL_DATA asset type has been removed

Moved to BALANCING. Modders can partially override DEFAULT_BALANCING.

migration.txt · Last modified: 2023/09/05 11:21 by 127.0.0.1
