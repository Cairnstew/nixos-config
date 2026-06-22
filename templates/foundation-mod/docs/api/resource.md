api:resource [Foundation - Modding Documentation]

- [skip to content](#dokuwiki__content)

# [![](/foundation/modding/lib/tpl/dokuwiki/images/logo.png)Foundation - Modding Documentation](/foundation/modding/start "Home [h]")

### User Tools

- [Log In](/foundation/modding/api/resource?do=login&sectok= "Log In")

### Site Tools

Search

ToolsShow pagesourceOld revisionsBacklinksRecent ChangesMedia ManagerSitemapLog In>

- [Recent Changes](/foundation/modding/api/resource?do=recent "Recent Changes [r]")
- [Media Manager](/foundation/modding/api/resource?do=media&ns=api "Media Manager")
- [Sitemap](/foundation/modding/api/resource?do=index "Sitemap [x]")

Trace: • [resource](/foundation/modding/api/resource "api:resource")

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

api:resource

### Table of Contents

- [RESOURCE](#resource)
    - [Properties](#properties)
        - [ResourceName](#resourcename)
        - [OrderId](#orderid)
        - [Icon](#icon)
        - [ResourceTypeList](#resourcetypelist)
        - [ResourceLayoutType](#resourcelayouttype)
        - [IsUnique](#isunique)
        - [IsTradable](#istradable)
        - [TradeBuyingPrice](#tradebuyingprice)
        - [TradeSellingPrice](#tradesellingprice)
        - [CanGoNegative](#cangonegative)
        - [DisplayInInventory](#displayininventory)
        - [DisplayInToolbar](#displayintoolbar)
        - [DisplayGizmo](#displaygizmo)
        - [IsDisplayContainerTracker](#isdisplaycontainertracker)
        - [DepositSoundEvent](#depositsoundevent)
        - [GatheringSoundEvent](#gatheringsoundevent)
        - [PlantingSoundEvent](#plantingsoundevent)
        - [ResourceVisualPrefabList](#resourcevisualprefablist)
        - [IndividualResourceVisualPrefabList](#individualresourcevisualprefablist)
        - [IsOnWater](#isonwater)
        - [TransportInteractiveLocationSetup](#transportinteractivelocationsetup)

# RESOURCE

**Category**: Asset

Parent class: [ASSET](/foundation/modding/api/asset "api:asset")
Inherited by [BLUEPRINT](/foundation/modding/api/blueprint "api:blueprint")

[List of RESOURCE assets](/foundation/modding/assets/resource "assets:resource")

## Properties

---

### ResourceName

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

### Icon

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[ATLAS_CELL](/foundation/modding/api/atlas_cell "api:atlas_cell")`
- **Expected**: `asset ID`

---

### ResourceTypeList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[RESOURCE_TYPE](/foundation/modding/api/resource_type "api:resource_type")>`
- **Expected**: `list of enum values`

---

### ResourceLayoutType

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[RESOURCE_LAYOUT_TYPE](/foundation/modding/api/resource_layout_type "api:resource_layout_type")`
- **Expected**: `enum value`
- **Default value**: `RESOURCE_LAYOUT_TYPE.CRATES`

---

### IsUnique

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### IsTradable

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### TradeBuyingPrice

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[RESOURCE_COLLECTION_VALUE](/foundation/modding/api/resource_collection_value "api:resource_collection_value")`
- **Can also be built from**: `[list](/foundation/modding/data-types#list "data-types")<[RESOURCE_QUANTITY_PAIR](/foundation/modding/api/resource_quantity_pair "api:resource_quantity_pair")>`
- **Expected**: `RESOURCE_COLLECTION_VALUE value` or `list of RESOURCE_QUANTITY_PAIR values`
- **Default value**: `nil`

---

### TradeSellingPrice

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[RESOURCE_COLLECTION_VALUE](/foundation/modding/api/resource_collection_value "api:resource_collection_value")`
- **Can also be built from**: `[list](/foundation/modding/data-types#list "data-types")<[RESOURCE_QUANTITY_PAIR](/foundation/modding/api/resource_quantity_pair "api:resource_quantity_pair")>`
- **Expected**: `RESOURCE_COLLECTION_VALUE value` or `list of RESOURCE_QUANTITY_PAIR values`
- **Default value**: `nil`

---

### CanGoNegative

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### DisplayInInventory

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### DisplayInToolbar

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### DisplayGizmo

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### IsDisplayContainerTracker

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### DepositSoundEvent

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### GatheringSoundEvent

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### PlantingSoundEvent

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### ResourceVisualPrefabList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

Used for the display of multiple unit of the resource (i.e: for warehouses). If multiple prefab are set, will randomly pick one in the list

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[PREFAB](/foundation/modding/api/prefab "api:prefab")>`
- **Expected**: `list of asset IDs`

---

### IndividualResourceVisualPrefabList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

Used for the display of a single unit of the resource (i.e: for market stand). If multiple prefab are set, will randomly pick one in the list

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[PREFAB](/foundation/modding/api/prefab "api:prefab")>`
- **Expected**: `list of asset IDs`

---

### IsOnWater

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### TransportInteractiveLocationSetup

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[INTERACTIVE_LOCATION_SETUP](/foundation/modding/api/interactive_location_setup "api:interactive_location_setup")`
- **Expected**: `asset ID`
- **Default value**: `nil`

api/resource.txt · Last modified: 2026/04/15 10:34 by 127.0.0.1
