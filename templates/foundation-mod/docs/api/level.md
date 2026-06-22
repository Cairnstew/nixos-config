api:level [Foundation - Modding Documentation]

- [skip to content](#dokuwiki__content)

# [![](/foundation/modding/lib/tpl/dokuwiki/images/logo.png)Foundation - Modding Documentation](/foundation/modding/start "Home [h]")

### User Tools

- [Log In](/foundation/modding/api/level?do=login&sectok= "Log In")

### Site Tools

Search

ToolsShow pagesourceOld revisionsBacklinksRecent ChangesMedia ManagerSitemapLog In>

- [Recent Changes](/foundation/modding/api/level?do=recent "Recent Changes [r]")
- [Media Manager](/foundation/modding/api/level?do=media&ns=api "Media Manager")
- [Sitemap](/foundation/modding/api/level?do=index "Sitemap [x]")

Trace: • [level](/foundation/modding/api/level "api:level")

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

api:level

### Table of Contents

- [LEVEL](#level)
    - [Functions](#functions)
        - [getGame](#getgame)
        - [createObject](#createobject)
        - [getDeltaTime](#getdeltatime)
        - [getUnscaledDeltaTime](#getunscaleddeltatime)
        - [getEnvironmentDeltaTime](#getenvironmentdeltatime)
        - [getTimeScale](#gettimescale)
        - [getComponentManager](#getcomponentmanager)
        - [find](#find)
        - [createPickingLine](#createpickingline)
        - [pick](#pick)
        - [pickObject](#pickobject)
        - [pickPosition](#pickposition)
        - [worldToScreenCoordinates](#worldtoscreencoordinates)
        - [isVisibleOnScreen](#isvisibleonscreen)
        - [rayCast](#raycast)

# LEVEL

*Abstract class*
**Category**: Data

## Functions

---

### getGame

`[GAME](/foundation/modding/api/game "api:game") **getGame**()`

---

### createObject

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object") **createObject**([*objectSetuperCallback*])`

Name

Type

Description

*`objectSetuperCallback`*

`function<void([GAME_OBJECT](/foundation/modding/api/game_object "api:game_object"))>`

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object") **createObject**(*prefab* [, *position* [, *orientation* [, *objectSetuperCallback*]]])`

Name

Type

Description

*`prefab`*

`[PREFAB](/foundation/modding/api/prefab "api:prefab")`

*`position`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*`orientation`*

`[quaternion](/foundation/modding/api/quaternion "api:quaternion")`

*`objectSetuperCallback`*

`function<void([GAME_OBJECT](/foundation/modding/api/game_object "api:game_object"))>`

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object") **createObject**(*prefab*, *objectSetuperCallback*)`

Name

Type

Description

*`prefab`*

`[PREFAB](/foundation/modding/api/prefab "api:prefab")`

*`objectSetuperCallback`*

`function<void([GAME_OBJECT](/foundation/modding/api/game_object "api:game_object"))>`

---

### getDeltaTime

`[float](/foundation/modding/data-types#float "data-types") **getDeltaTime**()`

---

### getUnscaledDeltaTime

`[float](/foundation/modding/data-types#float "data-types") **getUnscaledDeltaTime**()`

---

### getEnvironmentDeltaTime

`[float](/foundation/modding/data-types#float "data-types") **getEnvironmentDeltaTime**()`

---

### getTimeScale

`[float](/foundation/modding/data-types#float "data-types") **getTimeScale**()`

---

### getComponentManager

`[COMPONENT_MANAGER](/foundation/modding/api/component_manager "api:component_manager") **getComponentManager**(*componentType*)`

Name

Type

Description

*`componentType`*

`[component_type](/foundation/modding/data-types#component_type "data-types")`

---

### find

`[COMPONENT](/foundation/modding/api/component "api:component") **find**(*componentType* [, *enabledOnly*])`

Name

Type

Description

*`componentType`*

`[component_type](/foundation/modding/data-types#component_type "data-types")`

*`enabledOnly`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

`[COMPONENT](/foundation/modding/api/component "api:component") **find**(*id*, *componentType*)`

Name

Type

Description

*`id`*

`[guid](/foundation/modding/data-types#guid "data-types")`

*`componentType`*

`[component_type](/foundation/modding/data-types#component_type "data-types")`

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object") **find**(*id*)`

Name

Type

Description

*`id`*

`[guid](/foundation/modding/data-types#guid "data-types")`

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object") **find**(*name*)`

Name

Type

Description

*`name`*

`[string](/foundation/modding/data-types#string "data-types")`

`void **find**(*name*, *outObjectList*)`

Name

Type

Description

*`name`*

`[string](/foundation/modding/data-types#string "data-types")`

*`outObjectList`*

`[list](/foundation/modding/data-types#list "data-types")<[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")>`

*[Out argument](/foundation/modding/annotations#out_argument "annotations")*

---

### createPickingLine

`[LINE](/foundation/modding/api/line "api:line") **createPickingLine**(*screenPos*)`

Name

Type

Description

*`screenPos`*

`[vec2f](/foundation/modding/api/vec2f "api:vec2f")`

`[LINE](/foundation/modding/api/line "api:line") **createPickingLine**(*screenPos*)`

Name

Type

Description

*`screenPos`*

`[vec2i](/foundation/modding/api/vec2i "api:vec2i")`

---

### pick

`[boolean](/foundation/modding/data-types#boolean "data-types") **pick**(*line*, *outPosition*, *outObject* [, *flag* [, *recursiveFlag* [, *objectToSearchInto*]]])`

Name

Type

Description

*`line`*

`[LINE](/foundation/modding/api/line "api:line")`

*`outPosition`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*[Out argument](/foundation/modding/annotations#out_argument "annotations")*

*`outObject`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

*[Out argument](/foundation/modding/annotations#out_argument "annotations")*

*`flag`*

`[integer_and_unsigned_integer](/foundation/modding/data-types#integer_and_unsigned_integer "data-types")`

*`recursiveFlag`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

*`objectToSearchInto`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

`[boolean](/foundation/modding/data-types#boolean "data-types") **pick**(*screenPosition*, *outPosition*, *outObject* [, *flag* [, *recursiveFlag* [, *objectToSearchInto*]]])`

Name

Type

Description

*`screenPosition`*

`[vec2i](/foundation/modding/api/vec2i "api:vec2i")`

*`outPosition`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*[Out argument](/foundation/modding/annotations#out_argument "annotations")*

*`outObject`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

*[Out argument](/foundation/modding/annotations#out_argument "annotations")*

*`flag`*

`[integer_and_unsigned_integer](/foundation/modding/data-types#integer_and_unsigned_integer "data-types")`

*`recursiveFlag`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

*`objectToSearchInto`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

---

### pickObject

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object") **pickObject**(*line* [, *flag* [, *recursiveFlag* [, *objectToSearchInto*]]])`

Name

Type

Description

*`line`*

`[LINE](/foundation/modding/api/line "api:line")`

*`flag`*

`[integer_and_unsigned_integer](/foundation/modding/data-types#integer_and_unsigned_integer "data-types")`

*`recursiveFlag`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

*`objectToSearchInto`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object") **pickObject**(*screenPosition* [, *flag* [, *recursiveFlag* [, *objectToSearchInto*]]])`

Name

Type

Description

*`screenPosition`*

`[vec2i](/foundation/modding/api/vec2i "api:vec2i")`

*`flag`*

`[integer_and_unsigned_integer](/foundation/modding/data-types#integer_and_unsigned_integer "data-types")`

*`recursiveFlag`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

*`objectToSearchInto`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

---

### pickPosition

`[boolean](/foundation/modding/data-types#boolean "data-types") **pickPosition**(*line*, *outPosition* [, *flag* [, *recursiveFlag* [, *objectToSearchInto*]]])`

Name

Type

Description

*`line`*

`[LINE](/foundation/modding/api/line "api:line")`

*`outPosition`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*[Out argument](/foundation/modding/annotations#out_argument "annotations")*

*`flag`*

`[integer_and_unsigned_integer](/foundation/modding/data-types#integer_and_unsigned_integer "data-types")`

*`recursiveFlag`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

*`objectToSearchInto`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

`[boolean](/foundation/modding/data-types#boolean "data-types") **pickPosition**(*screenPosition*, *outPosition* [, *flag* [, *recursiveFlag* [, *objectToSearchInto*]]])`

Name

Type

Description

*`screenPosition`*

`[vec2i](/foundation/modding/api/vec2i "api:vec2i")`

*`outPosition`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*[Out argument](/foundation/modding/annotations#out_argument "annotations")*

*`flag`*

`[integer_and_unsigned_integer](/foundation/modding/data-types#integer_and_unsigned_integer "data-types")`

*`recursiveFlag`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

*`objectToSearchInto`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

---

### worldToScreenCoordinates

`[boolean](/foundation/modding/data-types#boolean "data-types") **worldToScreenCoordinates**(*worldPosition*, *outScreenPosition*)`

Name

Type

Description

*`worldPosition`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*`outScreenPosition`*

`[vec2f](/foundation/modding/api/vec2f "api:vec2f")`

*[Out argument](/foundation/modding/annotations#out_argument "annotations")`

`[vec2f](/foundation/modding/api/vec2f "api:vec2f") **worldToScreenCoordinates**(*worldPosition*)`

Name

Type

Description

*`worldPosition`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

---

### isVisibleOnScreen

`[boolean](/foundation/modding/data-types#boolean "data-types") **isVisibleOnScreen**(*worldPosition*)`

Name

Type

Description

*`worldPosition`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

---

### rayCast

`[boolean](/foundation/modding/data-types#boolean "data-types") **rayCast**(*screenPosition*, *distance*, *outResult* [, *flag*])`

Name

Type

Description

*`screenPosition`*

`[vec2i](/foundation/modding/api/vec2i "api:vec2i")`

*`distance`*

`[float](/foundation/modding/data-types#float "data-types")`

*`outResult`*

`[PHYSICS_RAY_RESULT](/foundation/modding/api/physics_ray_result "api:physics_ray_result")`

*[Out argument](/foundation/modding/annotations#out_argument "annotations")*

*`flag`*

`[integer_and_unsigned_integer](/foundation/modding/data-types#integer_and_unsigned_integer "data-types")`

`[boolean](/foundation/modding/data-types#boolean "data-types") **rayCast**(*from*, *to*, *outResult* [, *flag*])`

Name

Type

Description

*`from`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*`to`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*`outResult`*

`[PHYSICS_RAY_RESULT](/foundation/modding/api/physics_ray_result "api:physics_ray_result")`

*[Out argument](/foundation/modding/annotations#out_argument "annotations")*

*`flag`*

`[integer_and_unsigned_integer](/foundation/modding/data-types#integer_and_unsigned_integer "data-types")`

api/level.txt · Last modified: 2026/04/15 10:34 by 127.0.0.1
