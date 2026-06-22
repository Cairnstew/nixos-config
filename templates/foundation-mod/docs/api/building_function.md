api:building_function [Foundation - Modding Documentation]

- [skip to content](#dokuwiki__content)

# [![](/foundation/modding/lib/tpl/dokuwiki/images/logo.png)Foundation - Modding Documentation](/foundation/modding/start "Home [h]")

### User Tools

- [Log In](/foundation/modding/api/building_function?do=login&sectok= "Log In")

### Site Tools

Search

ToolsShow pagesourceOld revisionsBacklinksRecent ChangesMedia ManagerSitemapLog In>

- [Recent Changes](/foundation/modding/api/building_function?do=recent "Recent Changes [r]")
- [Media Manager](/foundation/modding/api/building_function?do=media&ns=api "Media Manager")
- [Sitemap](/foundation/modding/api/building_function?do=index "Sitemap [x]")

Trace: • [building_function](/foundation/modding/api/building_function "api:building_function")

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

api:building_function

### Table of Contents

- [BUILDING_FUNCTION](#building_function)
    - [Properties](#properties)
        - [Name](#name)
        - [NamePluralKey](#namepluralkey)
        - [Description](#description)
        - [HasMaximumInstance](#hasmaximuminstance)
        - [MaximumInstanceAllowed](#maximuminstanceallowed)
        - [UpkeepPerCapacity](#upkeeppercapacity)
        - [UpkeepPerCapacityMultiplier](#upkeeppercapacitymultiplier)
        - [GameRuleModifierList](#gamerulemodifierlist)
        - [IsDescriptionOverride](#isdescriptionoverride)
        - [ShowNameInTags](#shownameintags)
        - [IsDisplayable](#isdisplayable)
        - [IsCallRemoveBuildingFunctionOnBuildableDestruction](#iscallremovebuildingfunctiononbuildabledestruction)
    - [Functions](#functions)
        - [onBuildingFunctionKnown](#onbuildingfunctionknown)
        - [onBuildingFunctionAvailable](#onbuildingfunctionavailable)
        - [transferTo](#transferto)
        - [generateStats](#generatestats)
        - [activateBuilding](#activatebuilding)
        - [onInit](#oninit)
        - [onSetIsActive](#onsetisactive)
        - [reloadBuildingFunction](#reloadbuildingfunction)
        - [removeBuildingFunction](#removebuildingfunction)

# BUILDING_FUNCTION

**[Extendable](/foundation/modding/custom-classes#extendable_classes "custom-classes")**
**Category**: Asset

Parent class: [ASSET](/foundation/modding/api/asset "api:asset")
Inherited by:

- [BUILDING_FUNCTION_ACCOMMODATION](/foundation/modding/api/building_function_accommodation "api:building_function_accommodation")
- [BUILDING_FUNCTION_ASSIGNABLE](/foundation/modding/api/building_function_assignable "api:building_function_assignable")
- [BUILDING_FUNCTION_BELFRY](/foundation/modding/api/building_function_belfry "api:building_function_belfry")
- [BUILDING_FUNCTION_BRIDGE](/foundation/modding/api/building_function_bridge "api:building_function_bridge")
- [BUILDING_FUNCTION_GREAT_HALL](/foundation/modding/api/building_function_great_hall "api:building_function_great_hall")
- [BUILDING_FUNCTION_HOUSE](/foundation/modding/api/building_function_house "api:building_function_house")
- [BUILDING_FUNCTION_INN](/foundation/modding/api/building_function_inn "api:building_function_inn")
- [BUILDING_FUNCTION_INTERACTIVE_LOCATION](/foundation/modding/api/building_function_interactive_location "api:building_function_interactive_location")
- [BUILDING_FUNCTION_KNIGHT_STATUE](/foundation/modding/api/building_function_knight_statue "api:building_function_knight_statue")
- [BUILDING_FUNCTION_MARKET_TENT](/foundation/modding/api/building_function_market_tent "api:building_function_market_tent")
- [BUILDING_FUNCTION_MONASTERY](/foundation/modding/api/building_function_monastery "api:building_function_monastery")
- [BUILDING_FUNCTION_MUSICAL_PART](/foundation/modding/api/building_function_musical_part "api:building_function_musical_part")
- [BUILDING_FUNCTION_POINT_OF_INTEREST](/foundation/modding/api/building_function_point_of_interest "api:building_function_point_of_interest")
- [BUILDING_FUNCTION_PUBLIC_LOUNGE](/foundation/modding/api/building_function_public_lounge "api:building_function_public_lounge")
- [BUILDING_FUNCTION_PUBLIC_LOUNGE_ROOM](/foundation/modding/api/building_function_public_lounge_room "api:building_function_public_lounge_room")
- [BUILDING_FUNCTION_RESOURCE_DEPOT](/foundation/modding/api/building_function_resource_depot "api:building_function_resource_depot")
- [BUILDING_FUNCTION_RESOURCE_GENERATOR](/foundation/modding/api/building_function_resource_generator "api:building_function_resource_generator")
- [BUILDING_FUNCTION_RESOURCE_STOCKPILE](/foundation/modding/api/building_function_resource_stockpile "api:building_function_resource_stockpile")
- [BUILDING_FUNCTION_TRAINING_SITE](/foundation/modding/api/building_function_training_site "api:building_function_training_site")
- [BUILDING_FUNCTION_UNIQUE_RESOURCE_DEPOT](/foundation/modding/api/building_function_unique_resource_depot "api:building_function_unique_resource_depot")
- [BUILDING_FUNCTION_VILLAGE_CENTER](/foundation/modding/api/building_function_village_center "api:building_function_village_center")
- [BUILDING_FUNCTION_WATCHPOST](/foundation/modding/api/building_function_watchpost "api:building_function_watchpost")
- [BUILDING_FUNCTION_WORKER_CAPACITY_EXTENDER](/foundation/modding/api/building_function_worker_capacity_extender "api:building_function_worker_capacity_extender")
- [BUILDING_FUNCTION_WORKPLACE](/foundation/modding/api/building_function_workplace "api:building_function_workplace")

[List of BUILDING_FUNCTION assets](/foundation/modding/assets/building_function "assets:building_function")

## Properties

---

### Name

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### NamePluralKey

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### Description

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### HasMaximumInstance

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### MaximumInstanceAllowed

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[integer_and_unsigned_integer](/foundation/modding/data-types#integer_and_unsigned_integer "data-types")`
- **Expected**: `integer value`
- **Default value**: `1`

---

### UpkeepPerCapacity

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[RESOURCE_COLLECTION_VALUE](/foundation/modding/api/resource_collection_value "api:resource_collection_value")`
- **Can also be built from**: `[list](/foundation/modding/data-types#list "data-types")<[RESOURCE_QUANTITY_PAIR](/foundation/modding/api/resource_quantity_pair "api:resource_quantity_pair")>`
- **Expected**: `RESOURCE_COLLECTION_VALUE value` or `list of RESOURCE_QUANTITY_PAIR values`

---

### UpkeepPerCapacityMultiplier

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[float](/foundation/modding/data-types#float "data-types")`
- **Expected**: `float value`
- **Default value**: `1.0f`

---

### GameRuleModifierList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[GAME_RULE_MODIFIER](/foundation/modding/api/game_rule_modifier "api:game_rule_modifier")>`
- **Expected**: `list of GAME_RULE_MODIFIER values`

---

### IsDescriptionOverride

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### ShowNameInTags

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### IsDisplayable

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### IsCallRemoveBuildingFunctionOnBuildableDestruction

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

## Functions

---

### onBuildingFunctionKnown

*[Virtual function](/foundation/modding/custom-classes#extendable_classes "custom-classes")*

`void **onBuildingFunctionKnown**(*level*)`

Name

Type

Description

*`level`*

`[LEVEL](/foundation/modding/api/level "api:level")`

---

### onBuildingFunctionAvailable

*[Virtual function](/foundation/modding/custom-classes#extendable_classes "custom-classes")*

`void **onBuildingFunctionAvailable**(*level*)`

Name

Type

Description

*`level`*

`[LEVEL](/foundation/modding/api/level "api:level")`

---

### transferTo

*[Virtual function](/foundation/modding/custom-classes#extendable_classes "custom-classes")*

`void **transferTo**(*buildingPartFrom*, *buildingPartTo*, *outIsForcedUninitialized*)`

Name

Type

Description

*`buildingPartFrom`*

`[COMP_BUILDING_PART](/foundation/modding/api/comp_building_part "api:comp_building_part")`

*`buildingPartTo`*

`[COMP_BUILDING_PART](/foundation/modding/api/comp_building_part "api:comp_building_part")`

*`outIsForcedUninitialized`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

*[Out argument](/foundation/modding/annotations#out_argument "annotations")*

---

### generateStats

*[Virtual function](/foundation/modding/custom-classes#extendable_classes "custom-classes")*

`[BUILDING_FUNCTION_STATS](/foundation/modding/api/building_function_stats "api:building_function_stats") **generateStats**()`

---

### activateBuilding

*[Virtual function](/foundation/modding/custom-classes#extendable_classes "custom-classes"), [Protected function](/foundation/modding/custom-classes#protected "custom-classes")*

`[boolean](/foundation/modding/data-types#boolean "data-types") **activateBuilding**(*object*)`

Deprecated since version 1.9.7; Override onInit instead

Name

Type

Description

*`object`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

---

### onInit

*[Virtual function](/foundation/modding/custom-classes#extendable_classes "custom-classes"), [Protected function](/foundation/modding/custom-classes#protected "custom-classes")*

`[boolean](/foundation/modding/data-types#boolean "data-types") **onInit**(*object*)`

Name

Type

Description

*`object`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

---

### onSetIsActive

*[Virtual function](/foundation/modding/custom-classes#extendable_classes "custom-classes"), [Protected function](/foundation/modding/custom-classes#protected "custom-classes")*

`void **onSetIsActive**(*object*, *isActive*)`

Name

Type

Description

*`object`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

*`isActive`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

---

### reloadBuildingFunction

*[Virtual function](/foundation/modding/custom-classes#extendable_classes "custom-classes"), [Protected function](/foundation/modding/custom-classes#protected "custom-classes")*

`void **reloadBuildingFunction**(*object*)`

Name

Type

Description

*`object`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

---

### removeBuildingFunction

*[Virtual function](/foundation/modding/custom-classes#extendable_classes "custom-classes"), [Protected function](/foundation/modding/custom-classes#protected "custom-classes")*

`void **removeBuildingFunction**(*object*)`

Name

Type

Description

*`object`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

api/building_function.txt · Last modified: 2026/04/15 10:33 by 127.0.0.1
