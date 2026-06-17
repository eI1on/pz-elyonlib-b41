# Elyon Lib ([B41/B42])

Lua utility library for **Project Zomboid Build 41**. Other Workshop mods depend on it so features (HUD toasts, shared menu dock, common net/file/helpers) stay in one maintained place instead of being copy-pasted everywhere.

| Audience | What to do |
| --- | --- |
| **Players** | Subscribe only if a mod you use requires Elyon Lib. In the mod list, place **Elyon Lib above** mods that need it. |
| **Modders** | `require("ElyonLib/…")` shared modules from `media/lua/shared` and client-only UI from `media/lua/client`. See **[GUIDE.md](GUIDE.md)** for behaviour details, contracts, and bigger examples. |

Repository: [github.com/eI1on/pz-elyonlib](https://github.com/eI1on/pz-elyonlib).

---

## Paths

| Area | Directory (under the mod) |
| --- | --- |
| Shared (server + client) | `Contents/mods/ElyonLib/media/lua/shared/ElyonLib/` |
| Client-only | `Contents/mods/ElyonLib/media/lua/client/ElyonLib/` |

---

## Module map

### Core

```lua
local Logger = require("ElyonLib/Core/Logger")
local TimerManager = require("ElyonLib/Core/TimerManager")
local Constants = require("ElyonLib/Core/Constants")
local Globals = require("ElyonLib/Core/Globals")
```

| Module | Role |
| --- | --- |
| `Core/Logger` | Per-mod logger: `new(modID, modVersion)`, levels `ERROR` / `WARNING` / `INFO` / `DEBUG`, `logTable`, `writeLog` (optional client <> server relay via `ElyonLib` commands). |
| `Core/ElyonLibLogger` | Internal logger for Elyon Lib itself. |
| `Core/TimerManager` | `add` / `addSeconds` / `addMinutes`, `remove(id)`, `update()` - wired to `OnTick` (client) or `EveryOneMinute` (server). |
| `Core/Constants` | e.g. `LOG_LEVELS`. |
| `Core/Globals` | `isServer`, `isClient`, `isSingleplayer` snapshot at load (see GUIDE). |

### Utilities (shared)

| Module | Role |
| --- | --- |
| `MathUtils/MathUtils` | `clamp`, `parseNumber`, `lerp`, `easeOutCubic`. |
| `TextUtils/TextUtils` | `trim`, `measureWidth`, `trimToWidth`, `wrapLines`, `fitToWidth`, `sanitizeFileSegment`. |
| `TableUtils/TableUtils` | `deepCopy`, `shallowCopy`, `contains`, `merge`. |
| `TableUtils/TableFormatter` | `format(tbl)` - pretty print, circular refs show as `<Circular Reference>`. |
| `FileUtils/FileUtils` | `readFile`, `writeFile`, `readJson`, `writeJson` with mod vs Lua dir options. |
| `FileUtils/JSON` | `parse` / `stringify`. |
| `ColorUtils/ColorUtils` | HSL <> RGB, `createColor`, `copy`, `lighten`, `darken`. |
| `PlayerUtils/PlayerUtils` | Stable `getPlayerKey`, `getOnlinePlayers`, `getOnlinePlayerByUsername`. |
| `PlayerUtils/AccessLevelUtils` | Normalized access order, `isAtLeast`, `hasAdminAccess`, SP/MP helpers. |
| `ItemUtils/ItemUtils` | Cached `getScriptItem`, `getTexture`, `getTextureName`, `getDisplayName`, `getTextureFromReference`, `clearCache`. |
| `Rewards/GrantUtils` | `findPerk`, `grantItem` (MP uses `sendObjectChange`), `grantXp`. |
| `Net/NetUtils` | Unified local vs networked command dispatch - see GUIDE. |
| `SpritesUtils/Properties` | `setSpriteProperty`, `unsetSpriteProperty`, batch `setOrUnsetSpriteProperties`, `addValuesToPropertyMap`, debug `printPropNamesFromSprite`. |
| `DateTime/DateTimeUtility` | Calendars, offsets, formatting, parsing, date keys vs timestamps - see GUIDE. |
| `DateTime/DateTimeModel` | Small date/time model wrapper (`DateTimeModel.lua`). |
| `UI/Theme/Theme` | Shared palette + `apply*Style` for buttons, fields, lists, panels, combos, tickboxes. |
| `UI/Layout/LayoutUtils` | `setBounds`, `bottom`/`right`, `clampToScreen`, `centreOnScreen`, `defaultWindowGeometry`, visibility groups. |
| `UI/Utils/UIUtils` | Frame delta (`frameMillis` / `frameStep`), UI sounds, hit tests, scrollbar width helpers, `drawWrappedText`. |

### Client UI

Require from `media/lua/client` context only.

| Module | Role |
| --- | --- |
| `UI/MenuDock/MenuDock` | Edge-docked puck + vertical button rail (`registerButton` / `unregisterButton`). **[Full API > GUIDE.md](GUIDE.md#menudock)** |
| `UI/Notifications/HudNotify` | Right-HUD toast stack (`push` / `pop` / `clear`, hooks, TTL). **[API > GUIDE.md](GUIDE.md#hudnotify)** |
| `UI/Calendar/DateTimeSelector` | Date/time picker UI. |
| `UI/Components/ISScrollablePanel` | Scrollable panel. |
| `UI/Components/ISCustomScrollBar` | Custom scrollbar. |

---

## Tiny examples

**Logger**

```lua
local Logger = require("ElyonLib/Core/Logger")
local log = Logger:new("MyMod", "1.0")
log:info("Player %s joined", username)
```

**HudNotify** (client)

```lua
local HudNotify = require("ElyonLib/UI/Notifications/HudNotify")
HudNotify.push({ title = "Knox Net", body = "New message", kind = "message", ttlSeconds = 5 })
```

**MenuDock entry** (client)

```lua
local MenuDock = require("ElyonLib/UI/MenuDock/MenuDock")
MenuDock.registerButton({
    id = "mymod_panel",
    title = "My Mod",
    label = "MM",
    onClick = function(playerNum, entry) -- open UI
    end,
})
```

---
