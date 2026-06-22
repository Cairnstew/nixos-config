# Level Of Detail

Hurricane supports 5 different levels of detail:

| Level ID | Min distance | Max distance |
|----------|-------------|-------------|
| 0        | 0           | 50          |
| 1        | 50          | 100         |
| 2        | 100         | 200         |
| 3        | 200         | 300         |
| 4        | 300         | ∞           |

## How to

1. Create less detailed versions of your mesh
2. For each level, put meshes in child nodes named `LOD_X`
3. Use a single mesh for multiple levels: name it `LOD_23` for levels 2 and 3
4. To hide a model at long distance, don't use levels past the max rendering distance

### Examples

**Before LOD:**
- RootNode
  - BuildingMesh

**With one mesh per level:**
- RootNode
  - BuildingMesh
    - LOD_0
    - LOD_1
    - LOD_2
    - LOD_3
    - LOD_4

**With one detailed and one simplified mesh:**
- RootNode
  - BuildingMesh
    - LOD_012
    - LOD_34

**Only for close distance:**
- RootNode
  - SmallPropMesh
    - LOD_01

level-of-detail.txt · Last modified: 2020/04/28 18:24 by 127.0.0.1
