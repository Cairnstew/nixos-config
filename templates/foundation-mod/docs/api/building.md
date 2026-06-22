api:building [Foundation - Modding Documentation]

- [skip to content](#dokuwiki__content)

# [![](/foundation/modding/lib/tpl/dokuwiki/images/logo.png)Foundation - Modding Documentation](/foundation/modding/start "Home [h]")

### User Tools

- [Log In](/foundation/modding/api/building?do=login&sectok= "Log In")

### Site Tools

Search

ToolsShow pagesourceOld revisionsBacklinksRecent ChangesMedia ManagerSitemapLog In>

- [Recent Changes](/foundation/modding/api/building?do=recent "Recent Changes [r]")
- [Media Manager](/foundation/modding/api/building?do=media&ns=api "Media Manager")
- [Sitemap](/foundation/modding/api/building?do=index "Sitemap [x]")

Trace: • [building](/foundation/modding/api/building "api:building")

---

### Sidebar

- [Home](/foundation/modding/start "start")
- [Scripting API](/foundation/modding/api "api")
- [Assets](/foundation/modding/assets "assets")
- [Changelog](/foundation/modding/changelog "changelog")
- [Migration notes](/foundation/modding/migration "migration")
- [Community Guides](/foundation/modding/guides "guides")
- [Community API](/foundation/modding/communityapi "communityapi")
- [Texture Pack](/foundation/modding/texture-pack "texture-pack")

api:building

### Table of Contents

- [BUILDING](#building)
    - [Properties](#properties)
        - [Name](#name)
        - [Description](#description)
        - [OrderId](#orderid)
        - [BuildingType](#buildingtype)
        - [NavMeshLockCategory](#navmeshlockcategory)
        - [HasOwnNavMeshZoneId](#hasownnavmeshzoneid)
        - [IsForceMonument](#isforcemonument)
        - [OptionalSubBuildingIcon](#optionalsubbuildingicon)
        - [AssetCoreBuildingPart](#assetcorebuildingpart)
        - [AssetMiniatureBuildingPart](#assetminiaturebuildingpart)
        - [SubAssetBuildingList](#subassetbuildinglist)
        - [AssetBuildingPartList](#assetbuildingpartlist)
        - [BuildingModel](#buildingmodel)
        - [AssetBuildingFunction](#assetbuildingfunction)
        - [DesirabilityLayer](#desirabilitylayer)
        - [ConstructionCompletedOverrideAudioKey](#constructioncompletedoverrideaudiokey)
        - [IsPickingEnabled](#ispickingenabled)
        - [IsManuallyUnlocked](#ismanuallyunlocked)
        - [IsDestructible](#isdestructible)
        - [IsPartsDestructible](#ispartsdestructible)
        - [IsEditable](#iseditable)
        - [IsHidden](#ishidden)
        - [IsClearTrees](#iscleartrees)
        - [IsUnique](#isunique)
        - [IsAttachable](#isattachable)
        - [IsAllowParentParts](#isallowparentparts)
        - [AssetMaterialSetList](#assetmaterialsetlist)
        - [RequiredPartList](#requiredpartlist)
        - [AssetBuildingConditionConfigList](#assetbuildingconditionconfiglist)
        - [MultiPositionAudioEvent](#multipositionaudioevent)
        - [MultiPositionStopAudioEvent](#multipositionstopaudioevent)

# BUILDING

Deprecated names:

- MONUMENT

**Category**: Asset

Parent class: [ASSET](/foundation/modding/api/asset "api:asset")

[List of BUILDING assets](/foundation/modding/assets/building "assets:building")

## Properties

---

### Name

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### Description

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### OrderId

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[integer_and_unsigned_integer](/foundation/modding/data-types#integer_and_unsigned_integer "data-types")`
- **Expected**: `integer value`
- **Default value**: `0`

---

### BuildingType

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[BUILDING_TYPE](/foundation/modding/api/building_type "api:building_type")`
- **Expected**: `enum value`
- **Default value**: `BUILDING_TYPE.GENERAL`

---

### NavMeshLockCategory

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[NAVMESH_LOCK_CATEGORY](/foundation/modding/api/navmesh_lock_category "api:navmesh_lock_category")`
- **Expected**: `enum value`
- **Default value**: `NAVMESH_LOCK_CATEGORY.NONE`

---

### HasOwnNavMeshZoneId

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### IsForceMonument

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

Forces building to be considered as a monument. For example, this will allow the building to have decorations and masterpieces.

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### OptionalSubBuildingIcon

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[ATLAS_CELL](/foundation/modding/api/atlas_cell "api:atlas_cell")`
- **Expected**: `asset ID`
- **Default value**: `nil`

---

### AssetCoreBuildingPart

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[BUILDING_PART](/foundation/modding/api/building_part "api:building_part")`
- **Expected**: `asset ID`

---

### AssetMiniatureBuildingPart

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[BUILDING_PART](/foundation/modding/api/building_part "api:building_part")`
- **Expected**: `asset ID`
- **Default value**: `nil`

---

### SubAssetBuildingList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[BUILDING](/foundation/modding/api/building "api:building")>`
- **Expected**: `list of asset IDs`

---

### AssetBuildingPartList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[BUILDING_PART](/foundation/modding/api/building_part "api:building_part")>`
- **Expected**: `list of asset IDs`

---

### BuildingModel

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[PREFAB](/foundation/modding/api/prefab "api:prefab")`
- **Expected**: `asset ID`
- **Default value**: `nil`

---

### AssetBuildingFunction

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[BUILDING_FUNCTION](/foundation/modding/api/building_function "api:building_function")`
- **Expected**: `asset ID`
- **Default value**: `nil`

---

### DesirabilityLayer

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[DESIRABILITY](/foundation/modding/api/desirability "api:desirability")`
- **Expected**: `asset ID`
- **Default value**: `nil`

---

### ConstructionCompletedOverrideAudioKey

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### IsPickingEnabled

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### IsManuallyUnlocked

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### IsDestructible

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### IsPartsDestructible

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### IsEditable

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### IsHidden

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### IsClearTrees

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### IsUnique

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### IsAttachable

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### IsAllowParentParts

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### AssetMaterialSetList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

Not used for sub-buildings. Sub-buildings will use material set from parent building.

- **Type**: `[MATERIAL_SET_LIST](/foundation/modding/api/material_set_list "api:material_set_list")`
- **Expected**: `asset ID`
- **Default value**: `nil`

---

### RequiredPartList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[MONUMENT_REQUIRED_PART_PAIR](/foundation/modding/api/monument_required_part_pair "api:monument_required_part_pair")>`
- **Expected**: `list of MONUMENT_REQUIRED_PART_PAIR values`

---

### AssetBuildingConditionConfigList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[BUILDING_GAME_CONDITION_CONFIG](/foundation/modding/api/building_game_condition_config "api:building_game_condition_config")>`
- **Expected**: `list of asset IDs`

---

### MultiPositionAudioEvent

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### MultiPositionStopAudioEvent

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

api/building.txt · Last modified: 2026/04/15 10:33 by 127.0.0.1
