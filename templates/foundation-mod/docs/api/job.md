api:job [Foundation - Modding Documentation]

- [skip to content](#dokuwiki__content)

# [![](/foundation/modding/lib/tpl/dokuwiki/images/logo.png)Foundation - Modding Documentation](/foundation/modding/start "Home [h]")

### User Tools

- [Log In](/foundation/modding/api/job?do=login&sectok= "Log In")

### Site Tools

Search

ToolsShow pagesourceOld revisionsBacklinksRecent ChangesMedia ManagerSitemapLog In>

- [Recent Changes](/foundation/modding/api/job?do=recent "Recent Changes [r]")
- [Media Manager](/foundation/modding/api/job?do=media&ns=api "Media Manager")
- [Sitemap](/foundation/modding/api/job?do=index "Sitemap [x]")

Trace: • [job](/foundation/modding/api/job "api:job")

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

api:job

### Table of Contents

- [JOB](#job)
    - [Properties](#properties)
        - [JobName](#jobname)
        - [JobDescription](#jobdescription)
        - [UseWorkplaceBehavior](#useworkplacebehavior)
        - [DefaultBehavior](#defaultbehavior)
        - [RelatedZone](#relatedzone)
        - [NeededMasteredJobList](#neededmasteredjoblist)
        - [AssetJobProgression](#assetjobprogression)
        - [CharacterSetup](#charactersetup)
        - [Hidden](#hidden)
        - [IsDefinitive](#isdefinitive)
        - [IsLockedByDefault](#islockedbydefault)
        - [AreLowerStatusCompatible](#arelowerstatuscompatible)

# JOB

**Category**: Asset

Parent class: [ASSET](/foundation/modding/api/asset "api:asset")

[List of JOB assets](/foundation/modding/assets/job "assets:job")

## Properties

---

### JobName

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### JobDescription

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[string](/foundation/modding/data-types#string "data-types")`
- **Expected**: `string value`

---

### UseWorkplaceBehavior

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### DefaultBehavior

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[BEHAVIOR_TREE](/foundation/modding/api/behavior_tree "api:behavior_tree")`
- **Expected**: `asset ID`
- **Default value**: `nil`

---

### RelatedZone

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[ZONE](/foundation/modding/api/zone "api:zone")`
- **Expected**: `asset ID`
- **Default value**: `nil`

---

### NeededMasteredJobList

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[list](/foundation/modding/data-types#list "data-types")<[JOB](/foundation/modding/api/job "api:job")>`
- **Expected**: `list of asset IDs`

---

### AssetJobProgression

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[JOB_PROGRESSION](/foundation/modding/api/job_progression "api:job_progression")`
- **Expected**: `asset ID`

---

### CharacterSetup

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[CHARACTER_SETUP](/foundation/modding/api/character_setup "api:character_setup")`
- **Expected**: `CHARACTER_SETUP value`
- **Default value**: `nil`

---

### Hidden

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### IsDefinitive

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

---

### IsLockedByDefault

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `true`

---

### AreLowerStatusCompatible

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

Lower villager statuses will be allowed to work on the workplace with a malus

- **Type**: `[boolean](/foundation/modding/data-types#boolean "data-types")`
- **Expected**: `boolean value`
- **Default value**: `false`

api/job.txt · Last modified: 2026/04/15 10:34 by 127.0.0.1
