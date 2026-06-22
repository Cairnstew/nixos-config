api:texture [Foundation - Modding Documentation]

- [skip to content](#dokuwiki__content)

# [![](/foundation/modding/lib/tpl/dokuwiki/images/logo.png)Foundation - Modding Documentation](/foundation/modding/start "Home [h]")

### User Tools

- [Log In](/foundation/modding/api/texture?do=login&sectok= "Log In")

### Site Tools

Search

ToolsShow pagesourceOld revisionsBacklinksRecent ChangesMedia ManagerSitemapLog In>

- [Recent Changes](/foundation/modding/api/texture?do=recent "Recent Changes [r]")
- [Media Manager](/foundation/modding/api/texture?do=media&ns=api "Media Manager")
- [Sitemap](/foundation/modding/api/texture?do=index "Sitemap [x]")

Trace: • [texture](/foundation/modding/api/texture "api:texture")

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

api:texture

### Table of Contents

- [TEXTURE](#texture)
    - [Properties](#properties)
        - [WrapMode](#wrapmode)
        - [Filter](#filter)

# TEXTURE

**Category**: Asset

Parent class: [ASSET](/foundation/modding/api/asset "api:asset")

*[Cloneable](/foundation/modding/annotations#cloneable "annotations")*

[List of TEXTURE assets](/foundation/modding/assets/texture "assets:texture")

## Properties

---

### WrapMode

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[TEXTURE_WRAP](/foundation/modding/api/texture_wrap "api:texture_wrap")`
- **Expected**: `enum value`
- **Default value**: `TEXTURE_WRAP.CLAMP`

---

### Filter

*[Serialized](/foundation/modding/annotations#serialized "annotations")*

- **Type**: `[TEXTURE_FILTER](/foundation/modding/api/texture_filter "api:texture_filter")`
- **Expected**: `enum value`
- **Default value**: `TEXTURE_FILTER.LINEAR`

api/texture.txt · Last modified: 2026/04/15 10:34 by 127.0.0.1
