api:custom_map [Foundation - Modding Documentation]

- [skip to content](#dokuwiki__content)

# [![](/foundation/modding/lib/tpl/dokuwiki/images/logo.png)Foundation - Modding Documentation](/foundation/modding/start "Home [h]")

### User Tools

- [Log In](/foundation/modding/api/custom_map?do=login&sectok= "Log In")

### Site Tools

Search

ToolsShow pagesourceOld revisionsBacklinksRecent ChangesMedia ManagerSitemapLog In>

- [Recent Changes](/foundation/modding/api/custom_map?do=recent "Recent Changes [r]")
- [Media Manager](/foundation/modding/api/custom_map?do=media&ns=api "Media Manager")
- [Sitemap](/foundation/modding/api/custom_map?do=index "Sitemap [x]")

Trace: • [custom_map](/foundation/modding/api/custom_map "api:custom_map")

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

api:custom_map

### Table of Contents

- [CUSTOM_MAP](#custom_map)
    - [Properties](#properties)
        - [HeightMap](#heightmap)
        - [MinHeight](#minheight)
        - [MaxHeight](#maxheight)
        - [MaterialMask](#materialmask)
        - [MaterialMaskUseBlueChannelForCliff](#materialmaskusebluechannelforcliff)
        - [VillagePathList](#villagepathlist)
        - [SpawnList](#spawnlist)
        - [DensitySpawnList](#densityspawnlist)

# CUSTOM_MAP

**Category**: Asset

Parent class: [ASSET](/foundation/modding/api/asset "api:asset")

[List of CUSTOM_MAP assets](/foundation/modding/assets/custom_map "assets:custom_map")

## Properties

---

### HeightMap

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

A grayscale texture that will be used to generate the map's topography. Best results can be achieved when using an 1024x1024 image with a single 16 bit layer.

- **Type**: `[TEXTURE](/foundation/modding/api/texture "api:texture")`
- **Expected**: `asset ID`

---

### MinHeight

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

The height of a pure black pixel in the HeightMap. Any other pixel is interpolated.

- **Type**: `[float](/foundation/modding/data-types#float "data-types")`
- **Expected**: `float value`
- **Default value**: `5`

---

### MaxHeight

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

The height of a pure white pixel in the HeightMap. Any other pixel is interpolated.

- **Type**: `[float](/foundation/modding/data-types#float "data-types")`
- **Expected**: `float value`
- **Default value**: `100`

---

### MaterialMask

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

An RGB texture that describes the ground's texture. Red is grass, green is sand, blue is ignored by default, but can be used for cliff if MaterialMaskUseBlueChannelForCliff is set to true.

- **Type**: `[TEXTURE](/foundation/modding/api/texture "api:texture")`
- **Expected**: `asset ID`

---

### MaterialMaskUseBlueChannelForCliff

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

Use Blue channel of MaterialMask for cliff mask instead of relying on terrain normals.

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### VillagePathList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

Designates the Entrances of the Newcomers and the Entrances and Exits of the Envoys and Trader. For the best results, make sure the two positions aren't separated by water.

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[MAP_VILLAGE_PATH](/foundation/modding/api/map_village_path "api:map_village_path")>`
- **Expected**: `list of MAP_VILLAGE_PATH values`

---

### SpawnList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

List of prefabs that will be added to the map when it is loaded. Use this list to add resources to the map, such as berries and rocks.

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[MAP_SPAWN_INFO](/foundation/modding/api/map_spawn_info "api:map_spawn_info")>`
- **Expected**: `list of MAP_SPAWN_INFO values`

---

### DensitySpawnList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

Allows you to add objects randomly based on a texture.

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[MAP_DENSITY_SPAWN_INFO](/foundation/modding/api/map_density_spawn_info "api:map_density_spawn_info")>`
- **Expected**: `list of MAP_DENSITY_SPAWN_INFO values`

api/custom_map.txt · Last modified: 2026/04/15 10:33 by 127.0.0.1
