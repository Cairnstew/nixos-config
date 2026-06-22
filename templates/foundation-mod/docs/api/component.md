api:component [Foundation - Modding Documentation]

- [skip to content](#dokuwiki__content)

# [![](/foundation/modding/lib/tpl/dokuwiki/images/logo.png)Foundation - Modding Documentation](/foundation/modding/start "Home [h]")

### User Tools

- [Log In](/foundation/modding/api/component?do=login&sectok= "Log In")

### Site Tools

Search

ToolsShow pagesourceOld revisionsBacklinksRecent ChangesMedia ManagerSitemapLog In>

- [Recent Changes](/foundation/modding/api/component?do=recent "Recent Changes [r]")
- [Media Manager](/foundation/modding/api/component?do=media&ns=api "Media Manager")
- [Sitemap](/foundation/modding/api/component?do=index "Sitemap [x]")

Trace: • [component](/foundation/modding/api/component "api:component")

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

api:component

### Table of Contents

- [COMPONENT](#component)
    - [Properties](#properties)
        - [Enabled](#enabled)
    - [Functions](#functions)
        - [getOwner](#getowner)
        - [getLevel](#getlevel)
        - [isPreInitialized](#ispreinitialized)
        - [isInitialized](#isinitialized)
        - [isEnabled](#isenabled)
        - [hasEnabledFlag](#hasenabledflag)
        - [init](#init)
        - [onFinalize](#onfinalize)
        - [onDestroy](#ondestroy)
        - [onEnabled](#onenabled)
        - [onDisabled](#ondisabled)
        - [onOwnerChanged](#onownerchanged)
        - [getComponentType](#getcomponenttype)

# COMPONENT

**[Extendable](/foundation/modding/custom-classes#extendable_classes "custom-classes")**
**Category**: Data

Inherited by:

- [COMP_ABSTRACT_BUILDABLE](/foundation/modding/api/comp_abstract_buildable "api:comp_abstract_buildable")
- [COMP_ACCOMMODATION](/foundation/modding/api/comp_accommodation "api:comp_accommodation")
- [COMP_AGENT](/foundation/modding/api/comp_agent "api:comp_agent")
- [COMP_AGENT_NEED_PROCESSOR](/foundation/modding/api/comp_agent_need_processor "api:comp_agent_need_processor")
- [COMP_BELFRY](/foundation/modding/api/comp_belfry "api:comp_belfry")
- [COMP_BUILDING_ATTACH_NODE](/foundation/modding/api/comp_building_attach_node "api:comp_building_attach_node")
- [COMP_BUILDING_MANAGER](/foundation/modding/api/comp_building_manager "api:comp_building_manager")
- [COMP_BUILDING_ZONE](/foundation/modding/api/comp_building_zone "api:comp_building_zone")
- [COMP_CHARACTER_SETUPER](/foundation/modding/api/comp_character_setuper "api:comp_character_setuper")
- [COMP_CONSTRUCTION_STEPS_VISUAL](/foundation/modding/api/comp_construction_steps_visual "api:comp_construction_steps_visual")
- [COMP_CROP_FIELD_ELEMENT](/foundation/modding/api/comp_crop_field_element "api:comp_crop_field_element")
- [COMP_DIRT_CIRCLE](/foundation/modding/api/comp_dirt_circle "api:comp_dirt_circle")
- [COMP_DIRT_RECTANGLE](/foundation/modding/api/comp_dirt_rectangle "api:comp_dirt_rectangle")
- [COMP_ENVIRONMENT_SYSTEM](/foundation/modding/api/comp_environment_system "api:comp_environment_system")
- [COMP_FALLING_TREE](/foundation/modding/api/comp_falling_tree "api:comp_falling_tree")
- [COMP_GROUNDED](/foundation/modding/api/comp_grounded "api:comp_grounded")
- [COMP_GUEST](/foundation/modding/api/comp_guest "api:comp_guest")
- [COMP_HAPPINESS_GIVER](/foundation/modding/api/comp_happiness_giver "api:comp_happiness_giver")
- [COMP_IMMIGRATION_MANAGER](/foundation/modding/api/comp_immigration_manager "api:comp_immigration_manager")
- [COMP_INTERACTIVE_LOCATION](/foundation/modding/api/comp_interactive_location "api:comp_interactive_location")
- [COMP_INVENTORY](/foundation/modding/api/comp_inventory "api:comp_inventory")
- [COMP_KNIGHT_STATUE](/foundation/modding/api/comp_knight_statue "api:comp_knight_statue")
- [COMP_LIVESTOCK](/foundation/modding/api/comp_livestock "api:comp_livestock")
- [COMP_MAIN_GAME_LOOP](/foundation/modding/api/comp_main_game_loop "api:comp_main_game_loop")
- [COMP_MANDATE_MANAGER](/foundation/modding/api/comp_mandate_manager "api:comp_mandate_manager")
- [COMP_MANDATE_OFFICE](/foundation/modding/api/comp_mandate_office "api:comp_mandate_office")
- [COMP_MARKET_TENT](/foundation/modding/api/comp_market_tent "api:comp_market_tent")
- [COMP_PARTICLE_EMITTER](/foundation/modding/api/comp_particle_emitter "api:comp_particle_emitter")
- [COMP_PARTICLE_EMITTER_TOGGLE](/foundation/modding/api/comp_particle_emitter_toggle "api:comp_particle_emitter_toggle")
- [COMP_PATROL_WATCHPOST](/foundation/modding/api/comp_patrol_watchpost "api:comp_patrol_watchpost")
- [COMP_PLANTABLE](/foundation/modding/api/comp_plantable "api:comp_plantable")
- [COMP_QUOTABLE](/foundation/modding/api/comp_quotable "api:comp_quotable")
- [COMP_RESOURCE_CONTAINER](/foundation/modding/api/comp_resource_container "api:comp_resource_container")
- [COMP_RESOURCE_CONTAINER_DEPLETER](/foundation/modding/api/comp_resource_container_depleter "api:comp_resource_container_depleter")
- [COMP_RESOURCE_DEPOT](/foundation/modding/api/comp_resource_depot "api:comp_resource_depot")
- [COMP_RESOURCE_GENERATOR](/foundation/modding/api/comp_resource_generator "api:comp_resource_generator")
- [COMP_RESOURCE_STOCKPILE](/foundation/modding/api/comp_resource_stockpile "api:comp_resource_stockpile")
- [COMP_RESOURCE_TO_PICKUP](/foundation/modding/api/comp_resource_to_pickup "api:comp_resource_to_pickup")
- [COMP_RIGID_BODY](/foundation/modding/api/comp_rigid_body "api:comp_rigid_body")
- [COMP_SELF_DESTROY](/foundation/modding/api/comp_self_destroy "api:comp_self_destroy")
- [COMP_SOLDIER](/foundation/modding/api/comp_soldier "api:comp_soldier")
- [COMP_TAXATION_MANAGER](/foundation/modding/api/comp_taxation_manager "api:comp_taxation_manager")
- [COMP_TAX_COLLECTABLE](/foundation/modding/api/comp_tax_collectable "api:comp_tax_collectable")
- [COMP_TRADER](/foundation/modding/api/comp_trader "api:comp_trader")
- [COMP_TREE](/foundation/modding/api/comp_tree "api:comp_tree")
- [COMP_VEHICLE](/foundation/modding/api/comp_vehicle "api:comp_vehicle")
- [COMP_VILLAGER](/foundation/modding/api/comp_villager "api:comp_villager")
- [COMP_VILLAGER_MANAGER](/foundation/modding/api/comp_villager_manager "api:comp_villager_manager")
- [COMP_VISITOR](/foundation/modding/api/comp_visitor "api:comp_visitor")
- [COMP_WAREHOUSE_SETUPER](/foundation/modding/api/comp_warehouse_setuper "api:comp_warehouse_setuper")
- [COMP_WORKPLACE](/foundation/modding/api/comp_workplace "api:comp_workplace")

## Properties

---

### Enabled

*[Runtime only](/foundation/modding/annotations#runtime_only "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`

## Functions

---

### getOwner

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object") **getOwner**()`

---

### getLevel

`[LEVEL](/foundation/modding/api/level "api:level") **getLevel**()`

---

### isPreInitialized

`[boolean](/foundation/modding/data-types#boolean "data-types") **isPreInitialized**()`

---

### isInitialized

`[boolean](/foundation/modding/data-types#boolean "data-types") **isInitialized**()`

---

### isEnabled

`[boolean](/foundation/modding/data-types#boolean "data-types") **isEnabled**()`

Deprecated since version 1.8.1; use Enabled property instead

---

### hasEnabledFlag

`[boolean](/foundation/modding/data-types#boolean "data-types") **hasEnabledFlag**()`

---

### init

*[Virtual function](/foundation/modding/custom-classes#extendable_classes "custom-classes"), [Protected function](/foundation/modding/custom-classes#protected "custom-classes")*

`void **init**()`

---

### onFinalize

*[Virtual function](/foundation/modding/custom-classes#extendable_classes "custom-classes"), [Protected function](/foundation/modding/custom-classes#protected "custom-classes")*

`void **onFinalize**(*isClearingLevel*)`

Name

Type

Description

*`isClearingLevel`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

---

### onDestroy

*[Virtual function](/foundation/modding/custom-classes#extendable_classes "custom-classes"), [Protected function](/foundation/modding/custom-classes#protected "custom-classes")*

`void **onDestroy**(*isClearingLevel*)`

Name

Type

Description

*`isClearingLevel`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

---

### onEnabled

*[Virtual function](/foundation/modding/custom-classes#extendable_classes "custom-classes"), [Protected function](/foundation/modding/custom-classes#protected "custom-classes")*

`void **onEnabled**()`

---

### onDisabled

*[Virtual function](/foundation/modding/custom-classes#extendable_classes "custom-classes"), [Protected function](/foundation/modding/custom-classes#protected "custom-classes")*

`void **onDisabled**()`

---

### onOwnerChanged

*[Virtual function](/foundation/modding/custom-classes#extendable_classes "custom-classes"), [Protected function](/foundation/modding/custom-classes#protected "custom-classes")*

`void **onOwnerChanged**(*previousOwner*, *newOwner*)`

Name

Type

Description

*`previousOwner`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

*`newOwner`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

---

### getComponentType

`[component_type](/foundation/modding/data-types#component_type "data-types") **getComponentType**()`

api/component.txt · Last modified: 2026/04/15 10:33 by 127.0.0.1
