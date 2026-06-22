api:game_object [Foundation - Modding Documentation]

- [skip to content](#dokuwiki__content)

# [![](/foundation/modding/lib/tpl/dokuwiki/images/logo.png)Foundation - Modding Documentation](/foundation/modding/start "Home [h]")

### User Tools

- [Log In](/foundation/modding/api/game_object?do=login&sectok= "Log In")

### Site Tools

Search

ToolsShow pagesourceOld revisionsBacklinksRecent ChangesMedia ManagerSitemapLog In>

- [Recent Changes](/foundation/modding/api/game_object?do=recent "Recent Changes [r]")
- [Media Manager](/foundation/modding/api/game_object?do=media&ns=api "Media Manager")
- [Sitemap](/foundation/modding/api/game_object?do=index "Sitemap [x]")

Trace: • [game_object](/foundation/modding/api/game_object "api:game_object")

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

api:game_object

### Table of Contents

- [GAME_OBJECT](#game_object)
    - [Properties](#properties)
        - [Position](#position)
        - [Scale](#scale)
        - [Orientation](#orientation)
        - [SkewAlongYRelativeToX](#skewalongyrelativetox)
        - [Name](#name)
        - [Active](#active)
    - [Functions](#functions)
        - [translate](#translate)
        - [move](#move)
        - [resetOrientation](#resetorientation)
        - [lookAt](#lookat)
        - [rotateAround](#rotatearound)
        - [rotate](#rotate)
        - [rotateX](#rotatex)
        - [rotateY](#rotatey)
        - [rotateZ](#rotatez)
        - [setRotationX](#setrotationx)
        - [setRotationY](#setrotationy)
        - [setRotationZ](#setrotationz)
        - [rotateLocal](#rotatelocal)
        - [rotateLocalX](#rotatelocalx)
        - [rotateLocalY](#rotatelocaly)
        - [rotateLocalZ](#rotatelocalz)
        - [setScale](#setscale)
        - [scale](#scale1)
        - [scaleAround](#scalearound)
        - [generateGlobalMatrix](#generateglobalmatrix)
        - [setLocalMatrix](#setlocalmatrix)
        - [setGlobalPosition](#setglobalposition)
        - [setGlobalOrientation](#setglobalorientation)
        - [setGlobalTransform](#setglobaltransform)
        - [setGlobalMatrix](#setglobalmatrix)
        - [setGlobalMatrixIgnoreScale](#setglobalmatrixignorescale)
        - [getGlobalPosition](#getglobalposition)
        - [getGlobalOrientation](#getglobalorientation)
        - [globalLookAt](#globallookat)
        - [getLevel](#getlevel)
        - [destroy](#destroy)
        - [destroyAllChild](#destroyallchild)
        - [getParent](#getparent)
        - [setParent](#setparent)
        - [isParentedTo](#isparentedto)
        - [forEachChild](#foreachchild)
        - [forEachChildRecursive](#foreachchildrecursive)
        - [forEachComponent](#foreachcomponent)
        - [forEachComponentReverse](#foreachcomponentreverse)
        - [buildMinMaxBounding](#buildminmaxbounding)
        - [getId](#getid)
        - [addComponent](#addcomponent)
        - [getOrCreateComponent](#getorcreatecomponent)
        - [transferComponent](#transfercomponent)
        - [getComponent](#getcomponent)
        - [getEnabledComponent](#getenabledcomponent)
        - [removeComponent](#removecomponent)
        - [findFirstParentWithComponent](#findfirstparentwithcomponent)
        - [findFirstObjectWithComponentUp](#findfirstobjectwithcomponentup)
        - [findFirstObjectWithComponentDown](#findfirstobjectwithcomponentdown)

# GAME_OBJECT

*Abstract class*
**Category**: Data

## Properties

---

### Position

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[vec3f](/foundation/modding/api/vec3f "api:vec3f")`
- **Expected**: `vec3f value`

---

### Scale

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[vec3f](/foundation/modding/api/vec3f "api:vec3f")`
- **Expected**: `vec3f value`
- **Default value**: `{ 1, 1, 1 }`

---

### Orientation

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[quaternion](/foundation/modding/api/quaternion "api:quaternion")`
- **Expected**: `quaternion value`

---

### SkewAlongYRelativeToX

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[float](/foundation/modding/data-types#float "data-types")`
- **Expected**: `float value`
- **Default value**: `0.0f`

---

### Name

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### Active

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`

## Functions

---

### translate

`void **translate**(*translation*)`

Name

Type

Description

*`translation`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

---

### move

`void **move**(*direction*)`

Name

Type

Description

*`direction`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

---

### resetOrientation

`void **resetOrientation**()`

---

### lookAt

`void **lookAt**(*target* [, *up* [, *lockOnUpAxis*]])`

Name

Type

Description

*`target`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*`up`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*`lockOnUpAxis`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

`void **lookAt**(*target*, *lockOnUpAxis*)`

Name

Type

Description

*`target`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*`lockOnUpAxis`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

---

### rotateAround

`void **rotateAround**(*pivot*, *rotation*)`

Name

Type

Description

*`pivot`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*`rotation`*

`[quaternion](/foundation/modding/api/quaternion "api:quaternion")`

`void **rotateAround**(*pivot*, *vector*, *angle*)`

Name

Type

Description

*`pivot`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*`vector`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*`angle`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### rotate

`void **rotate**(*quaternion*)`

Name

Type

Description

*`quaternion`*

`[quaternion](/foundation/modding/api/quaternion "api:quaternion")`

---

### rotateX

`void **rotateX**(*ax*)`

Name

Type

Description

*`ax`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### rotateY

`void **rotateY**(*ay*)`

Name

Type

Description

*`ay`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### rotateZ

`void **rotateZ**(*az*)`

Name

Type

Description

*`az`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### setRotationX

`void **setRotationX**(*ax*)`

Name

Type

Description

*`ax`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### setRotationY

`void **setRotationY**(*ay*)`

Name

Type

Description

*`ay`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### setRotationZ

`void **setRotationZ**(*az*)`

Name

Type

Description

*`az`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### rotateLocal

`void **rotateLocal**(*quaternion*)`

Name

Type

Description

*`quaternion`*

`[quaternion](/foundation/modding/api/quaternion "api:quaternion")`

---

### rotateLocalX

`void **rotateLocalX**(*ax*)`

Name

Type

Description

*`ax`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### rotateLocalY

`void **rotateLocalY**(*ay*)`

Name

Type

Description

*`ay`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### rotateLocalZ

`void **rotateLocalZ**(*az*)`

Name

Type

Description

*`az`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### setScale

`void **setScale**(*scale*)`

Name

Type

Description

*`scale`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### scale

`void **scale**(*scale*)`

Name

Type

Description

*`scale`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

`void **scale**(*scale*)`

Name

Type

Description

*`scale`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### scaleAround

`void **scaleAround**(*pivot*, *scale*)`

Name

Type

Description

*`pivot`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*`scale`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

---

### generateGlobalMatrix

`void **generateGlobalMatrix**(*outMatrix*)`

Name

Type

Description

*`outMatrix`*

`[matrix](/foundation/modding/api/matrix "api:matrix")`

*[Out argument](/foundation/modding/annotations#out_argument "annotations")*

---

### setLocalMatrix

`void **setLocalMatrix**(*matrix*)`

Name

Type

Description

*`matrix`*

`[matrix](/foundation/modding/api/matrix "api:matrix")`

---

### setGlobalPosition

`void **setGlobalPosition**(*position*)`

Name

Type

Description

*`position`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

---

### setGlobalOrientation

`void **setGlobalOrientation**(*orientation*)`

Name

Type

Description

*`orientation`*

`[quaternion](/foundation/modding/api/quaternion "api:quaternion")`

---

### setGlobalTransform

`void **setGlobalTransform**(*position*, *orientation*)`

Name

Type

Description

*`position`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*`orientation`*

`[quaternion](/foundation/modding/api/quaternion "api:quaternion")`

`void **setGlobalTransform**(*position*, *orientation*, *scale*)`

Name

Type

Description

*`position`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*`orientation`*

`[quaternion](/foundation/modding/api/quaternion "api:quaternion")`

*`scale`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

---

### setGlobalMatrix

`void **setGlobalMatrix**(*matrix*)`

Name

Type

Description

*`matrix`*

`[matrix](/foundation/modding/api/matrix "api:matrix")`

---

### setGlobalMatrixIgnoreScale

`void **setGlobalMatrixIgnoreScale**(*matrix*)`

Name

Type

Description

*`matrix`*

`[matrix](/foundation/modding/api/matrix "api:matrix")`

---

### getGlobalPosition

`[vec3f](/foundation/modding/api/vec3f "api:vec3f") **getGlobalPosition**()`

---

### getGlobalOrientation

`[quaternion](/foundation/modding/api/quaternion "api:quaternion") **getGlobalOrientation**()`

---

### globalLookAt

`void **globalLookAt**(*target* [, *lockOnUpAxis*])`

Name

Type

Description

*`target`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*`lockOnUpAxis`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

---

### getLevel

`[LEVEL](/foundation/modding/api/level "api:level") **getLevel**()`

---

### destroy

`void **destroy**()`

---

### destroyAllChild

`void **destroyAllChild**()`

---

### getParent

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object") **getParent**()`

---

### setParent

`void **setParent**(*parent* [, *keepWorldTransform*])`

Name

Type

Description

*`parent`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

*`keepWorldTransform`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

---

### isParentedTo

`[boolean](/foundation/modding/data-types#boolean "data-types") **isParentedTo**(*parent*)`

Name

Type

Description

*`parent`*

`[GAME_OBJECT](/foundation/modding/api/game_object "api:game_object")`

---

### forEachChild

`void **forEachChild**(*function*)`

Name

Type

Description

*`function`*

`function<void|[boolean](/foundation/modding/data-types#boolean "data-types")([GAME_OBJECT](/foundation/modding/api/game_object "api:game_object") child)>`

If `false` is returned, the iteration stops. Returns `true` by default.

---

### forEachChildRecursive

`void **forEachChildRecursive**(*function*)`

Name

Type

Description

*`function`*

`function<void|[boolean](/foundation/modding/data-types#boolean "data-types")([GAME_OBJECT](/foundation/modding/api/game_object "api:game_object") child)>`

If `false` is returned, the iteration stops. Returns `true` by default.

---

### forEachComponent

`void **forEachComponent**(*function*)`

Name

Type

Description

*`function`*

`function<void|[boolean](/foundation/modding/data-types#boolean "data-types")([COMPONENT](/foundation/modding/api/component "api:component"))>`

If `false` is returned, the iteration stops. Returns `true` by default.

---

### forEachComponentReverse

`void **forEachComponentReverse**(*function*)`

Name

Type

Description

*`function`*

`function<void|[boolean](/foundation/modding/data-types#boolean "data-types")([COMPONENT](/foundation/modding/api/component "api:component"))>`

If `false` is returned, the iteration stops. Returns `true` by default.

---

### buildMinMaxBounding

`[boolean](/foundation/modding/data-types#boolean "data-types") **buildMinMaxBounding**(*outMin*, *outMax*)`

Name

Type

Description

*`outMin`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*[Out argument](/foundation/modding/annotations#out_argument "annotations")*

*`outMax`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*[Out argument](/foundation/modding/annotations#out_argument "annotations")*

---

### getId

`[guid](/foundation/modding/data-types#guid "data-types") **getId**()`

---

### addComponent

`[COMPONENT](/foundation/modding/api/component "api:component") **addComponent**(*componentType* [, *enabled*])`

Name

Type

Description

*`componentType`*

`[component_type](/foundation/modding/data-types#component_type "data-types")`

*`enabled`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

`[COMPONENT](/foundation/modding/api/component "api:component") **addComponent**(*componentType*, *componentSetuperCallback*)`

Name

Type

Description

*`componentType`*

`[component_type](/foundation/modding/data-types#component_type "data-types")`

*`componentSetuperCallback`*

`function<void([COMPONENT](/foundation/modding/api/component "api:component"))>`

---

### getOrCreateComponent

`[COMPONENT](/foundation/modding/api/component "api:component") **getOrCreateComponent**(*componentType* [, *replaceExistingVariant*])`

Name

Type

Description

*`componentType`*

`[component_type](/foundation/modding/data-types#component_type "data-types")`

*`replaceExistingVariant`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

---

### transferComponent

`[boolean](/foundation/modding/data-types#boolean "data-types") **transferComponent**(*component*)`

Name

Type

Description

*`component`*

`[COMPONENT](/foundation/modding/api/component "api:component")`

---

### getComponent

`[COMPONENT](/foundation/modding/api/component "api:component") **getComponent**(*type*)`

Name

Type

Description

*`type`*

`[component_type](/foundation/modding/data-types#component_type "data-types")`

---

### getEnabledComponent

`[COMPONENT](/foundation/modding/api/component "api:component") **getEnabledComponent**(*type*)`

Name

Type

Description

*`type`*

`[component_type](/foundation/modding/data-types#component_type "data-types")`

---

### removeComponent

`[boolean](/foundation/modding/data-types#boolean "data-types") **removeComponent**(*component*)`

Name

Type

Description

*`component`*

`[COMPONENT](/foundation/modding/api/component "api:component")`

---

### findFirstParentWithComponent

`[COMPONENT](/foundation/modding/api/component "api:component") **findFirstParentWithComponent**(*type*)`

Name

Type

Description

*`type`*

`[component_type](/foundation/modding/data-types#component_type "data-types")`

---

### findFirstObjectWithComponentUp

`[COMPONENT](/foundation/modding/api/component "api:component") **findFirstObjectWithComponentUp**(*type*)`

Name

Type

Description

*`type`*

`[component_type](/foundation/modding/data-types#component_type "data-types")`

---

### findFirstObjectWithComponentDown

`[COMPONENT](/foundation/modding/api/component "api:component") **findFirstObjectWithComponentDown**(*type* [, *ignoreDestroyingObject*])`

Name

Type

Description

*`type`*

`[component_type](/foundation/modding/data-types#component_type "data-types")`

*`ignoreDestroyingObject`*

`[boolean](/foundation/modding/data-types#boolean "data-types")`

api/game_object.txt · Last modified: 2026/04/15 10:34 by 127.0.0.1
