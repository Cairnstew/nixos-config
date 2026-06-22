api:event [Foundation - Modding Documentation]

- [skip to content](#dokuwiki__content)

# [![](/foundation/modding/lib/tpl/dokuwiki/images/logo.png)Foundation - Modding Documentation](/foundation/modding/start "Home [h]")

### User Tools

- [Log In](/foundation/modding/api/event?do=login&sectok= "Log In")

### Site Tools

Search

ToolsShow pagesourceOld revisionsBacklinksRecent ChangesMedia ManagerSitemapLog In>

- [Recent Changes](/foundation/modding/api/event?do=recent "Recent Changes [r]")
- [Media Manager](/foundation/modding/api/event?do=media&ns=api "Media Manager")
- [Sitemap](/foundation/modding/api/event?do=index "Sitemap [x]")

Trace: • [event](/foundation/modding/api/event "api:event")

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

api:event

### Table of Contents

- [EVENT](#event)
    - [Properties](#properties)
        - [Title](#title)
        - [Description](#description)
        - [DaysToFirst](#daystofirst)
        - [DaysBetweenOccurences](#daysbetweenoccurences)
        - [Delay](#delay)
        - [IsRecurrent](#isrecurrent)
        - [IgnoreConditionOnRecurrence](#ignoreconditiononrecurrence)
        - [IsInMainPool](#isinmainpool)
        - [ConditionList](#conditionlist)
        - [ActionList](#actionlist)

# EVENT

**Category**: Asset

Parent class: [ASSET](/foundation/modding/api/asset "api:asset")
Inherited by [MILITARY_CAMPAIGN](/foundation/modding/api/military_campaign "api:military_campaign")

*[Cloneable](/foundation/modding/annotations#cloneable "annotations")*

[List of EVENT assets](/foundation/modding/assets/event "assets:event")

## Properties

---

### Title

*[Serialized](/foundation/modding/annotations#serialized "annotations"), [Savegame](/foundation/modding/annotations#savegame "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### Description

*[Serialized](/foundation/modding/annotations#serialized "annotations"), [Savegame](/foundation/modding/annotations#savegame "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### DaysToFirst

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[integer_and_unsigned_integer](/foundation/modding/data-types#integer_and_unsigned_integer "data-types")`
- **Expected**: `integer value`
- **Default value**: `5`

---

### DaysBetweenOccurences

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[integer_and_unsigned_integer](/foundation/modding/data-types#integer_and_unsigned_integer "data-types")`
- **Expected**: `integer value`
- **Default value**: `40`

---

### Delay

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[float](/foundation/modding/data-types#float "data-types")`
- **Expected**: `float value`
- **Default value**: `0.0f`

---

### IsRecurrent

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### IgnoreConditionOnRecurrence

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

With this setting activated, further recurrence of the event will ignore conditions.

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### IsInMainPool

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### ConditionList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[GAME_CONDITION](/foundation/modding/api/game_condition "api:game_condition")>`
- **Expected**: `list of GAME_CONDITION values`

---

### ActionList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[GAME_ACTION](/foundation/modding/api/game_action "api:game_action")>`
- **Expected**: `list of GAME_ACTION values`

api/event.txt · Last modified: 2026/04/15 10:33 by 127.0.0.1
