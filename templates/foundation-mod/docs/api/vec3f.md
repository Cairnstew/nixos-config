api:vec3f [Foundation - Modding Documentation]

- [skip to content](#dokuwiki__content)

# [![](/foundation/modding/lib/tpl/dokuwiki/images/logo.png)Foundation - Modding Documentation](/foundation/modding/start "Home [h]")

### User Tools

- [Log In](/foundation/modding/api/vec3f?do=login&sectok= "Log In")

### Site Tools

Search

ToolsShow pagesourceOld revisionsBacklinksRecent ChangesMedia ManagerSitemapLog In>

- [Recent Changes](/foundation/modding/api/vec3f?do=recent "Recent Changes [r]")
- [Media Manager](/foundation/modding/api/vec3f?do=media&ns=api "Media Manager")
- [Sitemap](/foundation/modding/api/vec3f?do=index "Sitemap [x]")

Trace: • [vec3f](/foundation/modding/api/vec3f "api:vec3f")

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

api:vec3f

### Table of Contents

- [vec3f](#vec3f)
    - [Functions](#functions)
        - [add](#add)
        - [almostEquals](#almostequals)
        - [isZero](#iszero)
        - [isNearZero](#isnearzero)
        - [getXY](#getxy)
        - [getXZ](#getxz)
        - [getYZ](#getyz)
        - [set](#set)
        - [setXY](#setxy)
        - [setXZ](#setxz)
        - [setYZ](#setyz)
        - [mod](#mod)
        - [dot](#dot)
        - [cross](#cross)
        - [getOneOrthogonal](#getoneorthogonal)
        - [normalize](#normalize)
        - [normalized](#normalized)
        - [getLength2](#getlength2)
        - [distance2](#distance2)

# vec3f

**Category**: Data structure

## Functions

---

### add

`void **vec3f.add**(*object*, *x*, *y*, *z*)`

Name

Type

Description

*`object`*

`vec3f`

*`x`*

`[float](/foundation/modding/data-types#float "data-types")`

*`y`*

`[float](/foundation/modding/data-types#float "data-types")`

*`z`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### almostEquals

`[boolean](/foundation/modding/data-types#boolean "data-types") **vec3f.almostEquals**(*object*, *vector*, *epsilon*)`

Name

Type

Description

*`object`*

`vec3f`

*`vector`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

*`epsilon`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### isZero

`[boolean](/foundation/modding/data-types#boolean "data-types") **vec3f.isZero**(*object*)`

Name

Type

Description

*`object`*

`vec3f`

---

### isNearZero

`[boolean](/foundation/modding/data-types#boolean "data-types") **vec3f.isNearZero**(*object*)`

Name

Type

Description

*`object`*

`vec3f`

---

### getXY

`[vec2f](/foundation/modding/api/vec2f "api:vec2f") **vec3f.getXY**(*object*)`

Name

Type

Description

*`object`*

`vec3f`

---

### getXZ

`[vec2f](/foundation/modding/api/vec2f "api:vec2f") **vec3f.getXZ**(*object*)`

Name

Type

Description

*`object`*

`vec3f`

---

### getYZ

`[vec2f](/foundation/modding/api/vec2f "api:vec2f") **vec3f.getYZ**(*object*)`

Name

Type

Description

*`object`*

`vec3f`

---

### set

`void **vec3f.set**(*object*, *x*, *y*, *z*)`

Name

Type

Description

*`object`*

`vec3f`

*`x`*

`[float](/foundation/modding/data-types#float "data-types")`

*`y`*

`[float](/foundation/modding/data-types#float "data-types")`

*`z`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### setXY

`void **vec3f.setXY**(*object*, *vec2*)`

Name

Type

Description

*`object`*

`vec3f`

*`vec2`*

`[vec2f](/foundation/modding/api/vec2f "api:vec2f")`

---

### setXZ

`void **vec3f.setXZ**(*object*, *vec2*)`

Name

Type

Description

*`object`*

`vec3f`

*`vec2`*

`[vec2f](/foundation/modding/api/vec2f "api:vec2f")`

---

### setYZ

`void **vec3f.setYZ**(*object*, *vec2*)`

Name

Type

Description

*`object`*

`vec3f`

*`vec2`*

`[vec2f](/foundation/modding/api/vec2f "api:vec2f")`

---

### mod

`[vec3f](/foundation/modding/api/vec3f "api:vec3f") **vec3f.mod**(*object*, *scalar*)`

Name

Type

Description

*`object`*

`vec3f`

*`scalar`*

`[float](/foundation/modding/data-types#float "data-types")`

---

### dot

`[float](/foundation/modding/data-types#float "data-types") **vec3f.dot**(*object*, *vector*)`

Name

Type

Description

*`object`*

`vec3f`

*`vector`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

---

### cross

`[vec3f](/foundation/modding/api/vec3f "api:vec3f") **vec3f.cross**(*object*, *vector*)`

Name

Type

Description

*`object`*

`vec3f`

*`vector`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

---

### getOneOrthogonal

`[vec3f](/foundation/modding/api/vec3f "api:vec3f") **vec3f.getOneOrthogonal**(*object*)`

Name

Type

Description

*`object`*

`vec3f`

---

### normalize

`void **vec3f.normalize**(*object*)`

Name

Type

Description

*`object`*

`vec3f`

---

### normalized

`[vec3f](/foundation/modding/api/vec3f "api:vec3f") **vec3f.normalized**(*object*)`

Name

Type

Description

*`object`*

`vec3f`

---

### getLength2

`[float](/foundation/modding/data-types#float "data-types") **vec3f.getLength2**(*object*)`

Name

Type

Description

*`object`*

`vec3f`

---

### distance2

`[float](/foundation/modding/data-types#float "data-types") **vec3f.distance2**(*object*, *v*)`

Name

Type

Description

*`object`*

`vec3f`

*`v`*

`[vec3f](/foundation/modding/api/vec3f "api:vec3f")`

api/vec3f.txt · Last modified: 2026/04/15 10:34 by 127.0.0.1
