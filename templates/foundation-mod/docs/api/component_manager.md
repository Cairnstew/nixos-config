api:component_manager [Foundation - Modding Documentation]

- [skip to content](#dokuwiki__content)

# [![](/foundation/modding/lib/tpl/dokuwiki/images/logo.png)Foundation - Modding Documentation](/foundation/modding/start "Home [h]")

### User Tools

- [Log In](/foundation/modding/api/component_manager?do=login&sectok= "Log In")

### Site Tools

Search

ToolsShow pagesourceOld revisionsBacklinksRecent ChangesMedia ManagerSitemapLog In>

- [Recent Changes](/foundation/modding/api/component_manager?do=recent "Recent Changes [r]")
- [Media Manager](/foundation/modding/api/component_manager?do=media&ns=api "Media Manager")
- [Sitemap](/foundation/modding/api/component_manager?do=index "Sitemap [x]")

Trace: • [component_manager](/foundation/modding/api/component_manager "api:component_manager")

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

api:component_manager

### Table of Contents

- [COMPONENT_MANAGER](#component_manager)
    - [Functions](#functions)
        - [getFirst](#getfirst)
        - [getFirstEnabled](#getfirstenabled)
        - [getAllComponent](#getallcomponent)
        - [getAllEnabledComponent](#getallenabledcomponent)
        - [getAllDisabledComponent](#getalldisabledcomponent)
    - [Events](#events)
        - [ON_COMPONENT_INITIALIZED](#on_component_initialized)
        - [ON_COMPONENT_ENABLED](#on_component_enabled)
        - [ON_COMPONENT_DISABLED](#on_component_disabled)
        - [ON_COMPONENT_FINALIZED](#on_component_finalized)
        - [ON_COMPONENT_DESTROYED](#on_component_destroyed)

# COMPONENT_MANAGER

**Category**: Data

## Functions

---

### getFirst

`[COMPONENT](/foundation/modding/api/component "api:component") **getFirst**()`

---

### getFirstEnabled

`[COMPONENT](/foundation/modding/api/component "api:component") **getFirstEnabled**()`

---

### getAllComponent

`[list](/foundation/modding/data-types#list "data-types")<[COMPONENT](/foundation/modding/api/component "api:component")> **getAllComponent**()`

---

### getAllEnabledComponent

`[list](/foundation/modding/data-types#list "data-types")<[COMPONENT](/foundation/modding/api/component "api:component")> **getAllEnabledComponent**()`

---

### getAllDisabledComponent

`[list](/foundation/modding/data-types#list "data-types")<[COMPONENT](/foundation/modding/api/component "api:component")> **getAllDisabledComponent**()`

## Events

---

### ON_COMPONENT_INITIALIZED

`ON_COMPONENT_INITIALIZED([COMPONENT](/foundation/modding/api/component "api:component"))`

---

### ON_COMPONENT_ENABLED

`ON_COMPONENT_ENABLED([COMPONENT](/foundation/modding/api/component "api:component"))`

---

### ON_COMPONENT_DISABLED

`ON_COMPONENT_DISABLED([COMPONENT](/foundation/modding/api/component "api:component"))`

---

### ON_COMPONENT_FINALIZED

`ON_COMPONENT_FINALIZED([COMPONENT](/foundation/modding/api/component "api:component"))`

---

### ON_COMPONENT_DESTROYED

`ON_COMPONENT_DESTROYED([COMPONENT](/foundation/modding/api/component "api:component"))`

api/component_manager.txt · Last modified: 2026/04/15 10:33 by 127.0.0.1
