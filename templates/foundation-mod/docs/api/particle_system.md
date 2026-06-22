api:particle_system [Foundation - Modding Documentation]

- [skip to content](#dokuwiki__content)

# [![](/foundation/modding/lib/tpl/dokuwiki/images/logo.png)Foundation - Modding Documentation](/foundation/modding/start "Home [h]")

### User Tools

- [Log In](/foundation/modding/api/particle_system?do=login&sectok= "Log In")

### Site Tools

Search

ToolsShow pagesourceOld revisionsBacklinksRecent ChangesMedia ManagerSitemapLog In>

- [Recent Changes](/foundation/modding/api/particle_system?do=recent "Recent Changes [r]")
- [Media Manager](/foundation/modding/api/particle_system?do=media&ns=api "Media Manager")
- [Sitemap](/foundation/modding/api/particle_system?do=index "Sitemap [x]")

Trace: • [particle_system](/foundation/modding/api/particle_system "api:particle_system")

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

api:particle_system

### Table of Contents

- [PARTICLE_SYSTEM](#particle_system)
    - [Properties](#properties)
        - [Visual](#visual)
        - [Material](#material)
        - [SpriteSheetCellCount](#spritesheetcellcount)
        - [BillboardBehavior](#billboardbehavior)
        - [Space](#space)
        - [MaxVisibleDistance](#maxvisibledistance)
        - [MinimumQuality](#minimumquality)
        - [TimeScaleType](#timescaletype)
        - [Duration](#duration)
        - [Looping](#looping)
        - [Delay](#delay)
        - [LifeTime](#lifetime)
        - [StartSpeed](#startspeed)
        - [StartSize](#startsize)
        - [AspectRatio](#aspectratio)
        - [StartRotation](#startrotation)
        - [StartColor](#startcolor)
        - [GravityModifier](#gravitymodifier)
        - [RateOverTime](#rateovertime)
        - [RateOverTimeRandom](#rateovertimerandom)
        - [BurstList](#burstlist)
        - [SubEmitterList](#subemitterlist)
        - [Shape](#shape)
        - [LinearVelocity](#linearvelocity)
        - [ColorOverLifeTime](#coloroverlifetime)
        - [SizeOverLifetime](#sizeoverlifetime)
        - [RotationOverLifetime](#rotationoverlifetime)
        - [AlignWithVelocity](#alignwithvelocity)

# PARTICLE_SYSTEM

**Category**: Asset

Parent class: [ASSET](/foundation/modding/api/asset "api:asset")

[List of PARTICLE_SYSTEM assets](/foundation/modding/assets/particle_system "assets:particle_system")

## Properties

---

### Visual

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[PARTICLE_VISUAL](/foundation/modding/api/particle_visual "api:particle_visual")`
- **Expected**: `PARTICLE_VISUAL value`

---

### Material

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[MATERIAL](/foundation/modding/api/material "api:material")`
- **Expected**: `asset ID`

---

### SpriteSheetCellCount

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[vec2i](/foundation/modding/api/vec2i "api:vec2i")`
- **Expected**: `vec2i value`
- **Default value**: `{ 1, 1 }`

---

### BillboardBehavior

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[PARTICLE_BILLBOARD_BEHAVIOR](/foundation/modding/api/particle_billboard_behavior "api:particle_billboard_behavior")`
- **Expected**: `enum value`
- **Default value**: `PARTICLE_BILLBOARD_BEHAVIOR.FACE_CAMERA`

---

### Space

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[PARTICLE_SPACE](/foundation/modding/api/particle_space "api:particle_space")`
- **Expected**: `enum value`
- **Default value**: `PARTICLE_SPACE.LOCAL`

---

### MaxVisibleDistance

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[vec2f](/foundation/modding/api/vec2f "api:vec2f")`
- **Expected**: `vec2f value`

---

### MinimumQuality

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[PARTICLE_QUALITY](/foundation/modding/api/particle_quality "api:particle_quality")`
- **Expected**: `enum value`
- **Default value**: `PARTICLE_QUALITY.MEDIUM`

---

### TimeScaleType

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[PARTICLE_TIME_SCALE_TYPE](/foundation/modding/api/particle_time_scale_type "api:particle_time_scale_type")`
- **Expected**: `enum value`
- **Default value**: `PARTICLE_TIME_SCALE_TYPE.DEFAULT`

---

### Duration

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[float](/foundation/modding/data-types#float "data-types")`
- **Expected**: `float value`
- **Default value**: `1.0f`

---

### Looping

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### Delay

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[vec2f](/foundation/modding/api/vec2f "api:vec2f")`
- **Expected**: `vec2f value`

---

### LifeTime

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[float](/foundation/modding/data-types#float "data-types")`
- **Expected**: `float value`
- **Default value**: `1.0f`

---

### StartSpeed

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[vec2f](/foundation/modding/api/vec2f "api:vec2f")`
- **Expected**: `vec2f value`
- **Default value**: `{ 1, 1 }`

---

### StartSize

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[vec2f](/foundation/modding/api/vec2f "api:vec2f")`
- **Expected**: `vec2f value`
- **Default value**: `{ 1, 1 }`

---

### AspectRatio

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[float](/foundation/modding/data-types#float "data-types")`
- **Expected**: `float value`
- **Default value**: `1.0f`

---

### StartRotation

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[vec2f](/foundation/modding/api/vec2f "api:vec2f")`
- **Expected**: `vec2f value`

---

### StartColor

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[color](/foundation/modding/api/color "api:color")`
- **Expected**: `color value`
- **Default value**: `COL_WHITE`

---

### GravityModifier

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[float](/foundation/modding/data-types#float "data-types")`
- **Expected**: `float value`
- **Default value**: `0.0`

---

### RateOverTime

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

The number of particles emitted per seconds.

- **Type**: `[float](/foundation/modding/data-types#float "data-types")`
- **Expected**: `float value`
- **Default value**: `10`

---

### RateOverTimeRandom

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[float](/foundation/modding/data-types#float "data-types")`
- **Expected**: `float value`
- **Default value**: `0`

---

### BurstList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[PARTICLE_BURST_DATA](/foundation/modding/api/particle_burst_data "api:particle_burst_data")>`
- **Expected**: `list of PARTICLE_BURST_DATA values`

---

### SubEmitterList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[PARTICLE_SUB_EMITTER_DATA](/foundation/modding/api/particle_sub_emitter_data "api:particle_sub_emitter_data")>`
- **Expected**: `list of PARTICLE_SUB_EMITTER_DATA values`

---

### Shape

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[PARTICLE_EMITTER_SHAPE](/foundation/modding/api/particle_emitter_shape "api:particle_emitter_shape")`
- **Expected**: `PARTICLE_EMITTER_SHAPE value`
- **Default value**: `nil`

---

### LinearVelocity

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[PARTICLE_FLOAT3_VALUE](/foundation/modding/api/particle_float3_value "api:particle_float3_value")`
- **Expected**: `PARTICLE_FLOAT3_VALUE value`

---

### ColorOverLifeTime

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[GRADIENT](/foundation/modding/api/gradient "api:gradient")`
- **Expected**: `GRADIENT value`

---

### SizeOverLifetime

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[CURVE_FLOAT](/foundation/modding/api/curve_float "api:curve_float")`
- **Can also be built from**: `[list](/foundation/modding/data-types#list "data-types")<[CURVE_VALUE](/foundation/modding/api/curve_value "api:curve_value")>`
- **Expected**: `CURVE_FLOAT value` or `list of CURVE_VALUE values`

---

### RotationOverLifetime

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[vec2f](/foundation/modding/api/vec2f "api:vec2f")`
- **Expected**: `vec2f value`

---

### AlignWithVelocity

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

api/particle_system.txt · Last modified: 2026/04/15 10:34 by 127.0.0.1
