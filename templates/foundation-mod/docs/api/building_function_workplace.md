api:building_function_workplace [Foundation - Modding Documentation]

- [skip to content](#dokuwiki__content)

# [![](/foundation/modding/lib/tpl/dokuwiki/images/logo.png)Foundation - Modding Documentation](/foundation/modding/start "Home [h]")

### User Tools

- [Log In](/foundation/modding/api/building_function_workplace?do=login&sectok= "Log In")

### Site Tools

Search

ToolsShow pagesourceOld revisionsBacklinksRecent ChangesMedia ManagerSitemapLog In>

- [Recent Changes](/foundation/modding/api/building_function_workplace?do=recent "Recent Changes [r]")
- [Media Manager](/foundation/modding/api/building_function_workplace?do=media&ns=api "Media Manager")
- [Sitemap](/foundation/modding/api/building_function_workplace?do=index "Sitemap [x]")

Trace: • [building_function_workplace](/foundation/modding/api/building_function_workplace "api:building_function_workplace")

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

api:building_function_workplace

### Table of Contents

- [BUILDING_FUNCTION_WORKPLACE](#building_function_workplace)
    - [Properties](#properties)
        - [WorkerCapacity](#workercapacity)
        - [IsInfiniteCapacity](#isinfinitecapacity)
        - [WorkerRatioFromCapacity](#workerratiofromcapacity)
        - [OutputCapacity](#outputcapacity)
        - [StorageRatioFromCapacity](#storageratiofromcapacity)
        - [UpkeepPerWorker](#upkeepperworker)
        - [RelatedJob](#relatedjob)
        - [IsPrivate](#isprivate)
        - [CanAssignWorkerAutomatically](#canassignworkerautomatically)
        - [HasResourceDepot](#hasresourcedepot)
        - [IsPausable](#ispausable)
        - [RandomWorkstationReservation](#randomworkstationreservation)
        - [ShowProgressBar](#showprogressbar)
        - [ProductionCycleDurationInSec](#productioncycledurationinsec)
        - [WorkCycleNeededToProduceOnce](#workcycleneededtoproduceonce)
        - [InputInventoryCapacity](#inputinventorycapacity)
        - [ResourceListNeeded](#resourcelistneeded)
        - [ResourceProduced](#resourceproduced)
        - [DesirabilityLayer](#desirabilitylayer)
        - [AssetNoZoneNotification](#assetnozonenotification)
        - [AssetNoResourceInZoneNotification](#assetnoresourceinzonenotification)
        - [OutputOnlyKeyOverride](#outputonlykeyoverride)
        - [InputOutputKeyOverride](#inputoutputkeyoverride)
        - [IsDisplayInputResourcesInDescription](#isdisplayinputresourcesindescription)
        - [AgentWorkingActivityMessageOverride](#agentworkingactivitymessageoverride)

# BUILDING_FUNCTION_WORKPLACE

**[Extendable](/foundation/modding/custom-classes#extendable_classes "custom-classes")**
**Category**: Asset

Parent class: [BUILDING_FUNCTION](/foundation/modding/api/building_function "api:building_function")
Inherited by:

- [BUILDING_FUNCTION_BAILIFF_OFFICE](/foundation/modding/api/building_function_bailiff_office "api:building_function_bailiff_office")
- [BUILDING_FUNCTION_BUILDER_WORKSHOP](/foundation/modding/api/building_function_builder_workshop "api:building_function_builder_workshop")
- [BUILDING_FUNCTION_CHURCH](/foundation/modding/api/building_function_church "api:building_function_church")
- [BUILDING_FUNCTION_CRAFTING_WORKSHOP](/foundation/modding/api/building_function_crafting_workshop "api:building_function_crafting_workshop")
- [BUILDING_FUNCTION_ENCAMPMENT](/foundation/modding/api/building_function_encampment "api:building_function_encampment")
- [BUILDING_FUNCTION_FARM](/foundation/modding/api/building_function_farm "api:building_function_farm")
- [BUILDING_FUNCTION_FISHING](/foundation/modding/api/building_function_fishing "api:building_function_fishing")
- [BUILDING_FUNCTION_FORESTER](/foundation/modding/api/building_function_forester "api:building_function_forester")
- [BUILDING_FUNCTION_HEALING_HOUSE](/foundation/modding/api/building_function_healing_house "api:building_function_healing_house")
- [BUILDING_FUNCTION_KITCHEN](/foundation/modding/api/building_function_kitchen "api:building_function_kitchen")
- [BUILDING_FUNCTION_LIVESTOCK_FARM](/foundation/modding/api/building_function_livestock_farm "api:building_function_livestock_farm")
- [BUILDING_FUNCTION_LODGING](/foundation/modding/api/building_function_lodging "api:building_function_lodging")
- [BUILDING_FUNCTION_MARKET](/foundation/modding/api/building_function_market "api:building_function_market")
- [BUILDING_FUNCTION_QUARRY](/foundation/modding/api/building_function_quarry "api:building_function_quarry")
- [BUILDING_FUNCTION_TAX_OFFICE](/foundation/modding/api/building_function_tax_office "api:building_function_tax_office")
- [BUILDING_FUNCTION_TREASURY](/foundation/modding/api/building_function_treasury "api:building_function_treasury")
- [BUILDING_FUNCTION_WAREHOUSE](/foundation/modding/api/building_function_warehouse "api:building_function_warehouse")
- [BUILDING_FUNCTION_WORKPLACE_GUARD](/foundation/modding/api/building_function_workplace_guard "api:building_function_workplace_guard")

[List of BUILDING_FUNCTION_WORKPLACE assets](/foundation/modding/assets/building_function#building_function_workplace "assets:building_function")

## Properties

---

### WorkerCapacity

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[integer_and_unsigned_integer](/foundation/modding/data-types#integer_and_unsigned_integer "data-types")`
- **Expected**: `integer value`
- **Default value**: `1`

---

### IsInfiniteCapacity

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### WorkerRatioFromCapacity

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

Will override worker capacity if the value is over 0.

- **Type**: `[float](/foundation/modding/data-types#float "data-types")`
- **Expected**: `float value`
- **Default value**: `0.0f`

---

### OutputCapacity

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[integer_and_unsigned_integer](/foundation/modding/data-types#integer_and_unsigned_integer "data-types")`
- **Expected**: `integer value`
- **Default value**: `50`

---

### StorageRatioFromCapacity

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

Will override output capacity if the value is over 0.

- **Type**: `[float](/foundation/modding/data-types#float "data-types")`
- **Expected**: `float value`
- **Default value**: `0.0f`

---

### UpkeepPerWorker

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[RESOURCE_COLLECTION_VALUE](/foundation/modding/api/resource_collection_value "api:resource_collection_value")`
- **Can also be built from**: `[list](/foundation/modding/data-types#list "data-types")<[RESOURCE_QUANTITY_PAIR](/foundation/modding/api/resource_quantity_pair "api:resource_quantity_pair")>`
- **Expected**: `RESOURCE_COLLECTION_VALUE value` or `list of RESOURCE_QUANTITY_PAIR values`

---

### RelatedJob

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[ASSOCIATION_JOB_BEHAVIOR](/foundation/modding/api/association_job_behavior "api:association_job_behavior")`
- **Expected**: `ASSOCIATION_JOB_BEHAVIOR value`

---

### IsPrivate

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### CanAssignWorkerAutomatically

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

If false, monument like the Monastery, can't automatically assign worker to this workplace

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### HasResourceDepot

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### IsPausable

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### RandomWorkstationReservation

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### ShowProgressBar

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### ProductionCycleDurationInSec

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[float](/foundation/modding/data-types#float "data-types")`
- **Expected**: `float value`
- **Default value**: `20.0f`

---

### WorkCycleNeededToProduceOnce

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[integer_and_unsigned_integer](/foundation/modding/data-types#integer_and_unsigned_integer "data-types")`
- **Expected**: `integer value`
- **Default value**: `1`

---

### InputInventoryCapacity

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[RESOURCE_COLLECTION_VALUE](/foundation/modding/api/resource_collection_value "api:resource_collection_value")`
- **Can also be built from**: `[list](/foundation/modding/data-types#list "data-types")<[RESOURCE_QUANTITY_PAIR](/foundation/modding/api/resource_quantity_pair "api:resource_quantity_pair")>`
- **Expected**: `RESOURCE_COLLECTION_VALUE value` or `list of RESOURCE_QUANTITY_PAIR values`

---

### ResourceListNeeded

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[RESOURCE_COLLECTION_VALUE](/foundation/modding/api/resource_collection_value "api:resource_collection_value")`
- **Can also be built from**: `[list](/foundation/modding/data-types#list "data-types")<[RESOURCE_QUANTITY_PAIR](/foundation/modding/api/resource_quantity_pair "api:resource_quantity_pair")>`
- **Expected**: `RESOURCE_COLLECTION_VALUE value` or `list of RESOURCE_QUANTITY_PAIR values`

---

### ResourceProduced

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[RESOURCE_COLLECTION_VALUE](/foundation/modding/api/resource_collection_value "api:resource_collection_value")`
- **Can also be built from**: `[list](/foundation/modding/data-types#list "data-types")<[RESOURCE_QUANTITY_PAIR](/foundation/modding/api/resource_quantity_pair "api:resource_quantity_pair")>`
- **Expected**: `RESOURCE_COLLECTION_VALUE value` or `list of RESOURCE_QUANTITY_PAIR values`

---

### DesirabilityLayer

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[DESIRABILITY](/foundation/modding/api/desirability "api:desirability")`
- **Expected**: `asset ID`
- **Default value**: `nil`

---

### AssetNoZoneNotification

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[NOTIFICATION](/foundation/modding/api/notification "api:notification")`
- **Expected**: `asset ID`
- **Default value**: `nil`

---

### AssetNoResourceInZoneNotification

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[NOTIFICATION](/foundation/modding/api/notification "api:notification")`
- **Expected**: `asset ID`
- **Default value**: `nil`

---

### OutputOnlyKeyOverride

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### InputOutputKeyOverride

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### IsDisplayInputResourcesInDescription

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

Display input resources in description if workplace has input resources.

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### AgentWorkingActivityMessageOverride

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

If set, will replace the default working activity message used in the behavior

- **Type**: `[WORK_AGENT_ACTIVITY_MESSAGE](/foundation/modding/api/work_agent_activity_message "api:work_agent_activity_message")`
- **Expected**: `WORK_AGENT_ACTIVITY_MESSAGE value`
- **Default value**: `nil`

api/building_function_workplace.txt · Last modified: 2026/04/15 10:33 by 127.0.0.1
