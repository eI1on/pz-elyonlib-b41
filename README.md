# Elyon Lib

Elyon Lib is a Project Zomboid Build 41 utility framework for mods that want shared helpers instead of copying the same small systems into every project.

End users only need Elyon Lib when another mod lists it as a requirement. Modders can require the modules they need directly from the `ElyonLib/...` Lua paths.

## Module Overview

Shared modules live under:

```lua
Contents/mods/ElyonLib/media/lua/shared/ElyonLib
```

Client UI modules live under:

```lua
Contents/mods/ElyonLib/media/lua/client/ElyonLib
```

### Core

```lua
local Logger = require("ElyonLib/Core/Logger")
local TimerManager = require("ElyonLib/Core/TimerManager")
```

Available core helpers:

| Module | Purpose |
| --- | --- |
| `ElyonLib/Core/Logger` | Mod logger with log levels such as `ERROR`, `WARNING`, `INFO`, and `DEBUG`. |
| `ElyonLib/Core/ElyonLibLogger` | Preconfigured logger for Elyon Lib internals. |
| `ElyonLib/Core/TimerManager` | Timer helper for delayed or repeated callbacks. |
| `ElyonLib/Core/Constants` | Shared constants such as log level names. |

### Utility Modules

```lua
local MathUtils = require("ElyonLib/MathUtils/MathUtils")
local TextUtils = require("ElyonLib/TextUtils/TextUtils")
local UIUtils = require("ElyonLib/UI/Utils/UIUtils")
local AccessLevelUtils = require("ElyonLib/PlayerUtils/AccessLevelUtils")
```

Available utility helpers:

| Module | Purpose |
| --- | --- |
| `ElyonLib/MathUtils/MathUtils` | `clamp`, `lerp`, and `easeOutCubic`. |
| `ElyonLib/TextUtils/TextUtils` | Text fitting helpers for compact UI labels. |
| `ElyonLib/UI/Utils/UIUtils` | UI frame-step timing, UI sounds, and screen-point hit checks. |
| `ElyonLib/PlayerUtils/AccessLevelUtils` | Player access-level helpers using the player object, such as `getPlayer():getAccessLevel()`. |
| `ElyonLib/ColorUtils/ColorUtils` | HSL/RGB conversion and color table helpers. |
| `ElyonLib/TableUtils/TableUtils` | Deep copy, shallow copy, contains, and merge helpers. |
| `ElyonLib/TableUtils/TableFormatter` | Debug-friendly table formatting. |
| `ElyonLib/FileUtils/FileUtils` | File read/write helpers and JSON read/write helpers. |
| `ElyonLib/FileUtils/JSON` | JSON parse/stringify implementation. |
| `ElyonLib/SpritesUtils/Properties` | Sprite property helpers. |
| `ElyonLib/DateTime/DateTimeUtility` | Date parsing, formatting, timezone, and comparison helpers. |
| `ElyonLib/DateTime/DateTimeModel` | Date/time model wrapper. |

### UI Modules

```lua
local MenuDock = require("ElyonLib/UI/MenuDock/MenuDock")
```

Available UI helpers:

| Module | Purpose |
| --- | --- |
| `ElyonLib/UI/MenuDock/MenuDock` | Floating edge-docked menu launcher for mod panels and tool entries. |
| `ElyonLib/UI/Calendar/DateTimeSelector` | Date/time selection UI. |
| `ElyonLib/UI/Components/ISScrollablePanel` | Scrollable panel component. |
| `ElyonLib/UI/Components/ISCustomScrollBar` | Custom scrollbar component. |

## MenuDock

`MenuDock` is a floating round tab puck that docks to the left or right screen edge. When collapsed, only half of the puck is visible. Players can drag it, dock it magnetically to an edge, click it to open a vertical button rail, and scroll the rail when more entries are visible.

The dock is meant for mods that need a small entry point to open their own menus or tools without cluttering the player HUD.

### Require Path

```lua
local MenuDock = require("ElyonLib/UI/MenuDock/MenuDock")
```

### Register A Menu Button

```lua
MenuDock.registerButton({
    id = "my_mod_settings",
    title = "My Mod Settings",
    icon = "media/ui/MyMod/ui_settings.png",
    onClick = function(playerNum, entry)
        -- Open your panel here.
    end,
})
```

### Text-Only Button

If a mod does not have an icon, provide a short `label`.

```lua
MenuDock.registerButton({
    id = "my_mod_text_menu",
    title = "My Text Menu",
    label = "TXT",
    onClick = function(playerNum, entry)
        -- Open your panel here.
    end,
})
```

If `label` is missing and there is no icon, MenuDock falls back to `title`, then `id`, and fits the text into the fixed rail button size.

### Replace An Existing Entry

Registering the same `id` again replaces the previous entry.

```lua
MenuDock.registerButton({
    id = "my_mod_settings",
    title = "Updated Settings",
    label = "SET",
    onClick = function(playerNum, entry)
        -- Updated behavior.
    end,
})
```

### Unregister An Entry

```lua
MenuDock.unregisterButton("my_mod_settings")
```

### Entry Options

| Field | Required | Type | Description |
| --- | --- | --- | --- |
| `id` | Yes | `string` | Unique entry id. Registering the same id replaces the old entry. |
| `title` | No | `string` | Tooltip text. If omitted, the `id` is used. |
| `label` | No | `string` | Short text drawn in the rail button when no icon is supplied. Keep it compact, like `ADM`, `CFG`, or `MAP`. |
| `icon` | No | `string` | Texture path loaded with `getTexture`, for example `media/ui/MyMod/ui_settings.png`. |
| `texture` | No | `Texture` | Preloaded texture. If this is supplied, MenuDock uses it instead of loading `icon`. |
| `target` | No | `any` | Optional callback target. When supplied, callbacks receive `target` as their first argument. |
| `onClick` | No | `function` | Called when the button is clicked. |
| `minimumAccessLevel` | No | `string` | Minimum access level required to show the entry. Valid values are `None`, `Observer`, `GM`, `Overseer`, `Moderator`, and `Admin`. |
| `allowSinglePlayer` | No | `boolean` | When `true`, `minimumAccessLevel` is only enforced in multiplayer. |
| `visible` | No | `boolean` | Set to `false` to hide the entry without unregistering it. |
| `visibleWhen` | No | `function` | Custom visibility predicate. Return `true` to show the entry. |

### Click Callback

Without a `target`:

```lua
onClick = function(playerNum, entry)
    -- playerNum is usually 0 in normal play.
end
```

With a `target`:

```lua
local controller = {}

function controller:openMenu(playerNum, entry)
    -- self is controller.
end

MenuDock.registerButton({
    id = "my_mod_controller_menu",
    title = "Controller Menu",
    label = "CTL",
    target = controller,
    onClick = controller.openMenu,
})
```

### Access Levels

MenuDock reads access level from the player object:

```lua
getPlayer():getAccessLevel()
```

Supported access levels are:

```lua
"None"
"Observer"
"GM"
"Overseer"
"Moderator"
"Admin"
```

`minimumAccessLevel` works upward through that order. For example, `minimumAccessLevel = "Moderator"` allows both `Moderator` and `Admin`.

Moderator and above:

```lua
MenuDock.registerButton({
    id = "my_mod_moderator_menu",
    title = "Moderator Menu",
    label = "MOD",
    minimumAccessLevel = "Moderator",
    onClick = function(playerNum, entry)
        -- Moderators and admins can see this.
    end,
})
```

Admin only:

```lua
MenuDock.registerButton({
    id = "my_mod_admin_menu",
    title = "Admin Menu",
    label = "ADM",
    minimumAccessLevel = "Admin",
    onClick = function(playerNum, entry)
        -- Admins can see this.
    end,
})
```

### Singleplayer Allowed, Multiplayer Restricted

Use `allowSinglePlayer = true` when a menu should be available in singleplayer, but restricted by access level in multiplayer.

```lua
MenuDock.registerButton({
    id = "my_mod_tools",
    title = "My Tools",
    label = "TLS",
    minimumAccessLevel = "Admin",
    allowSinglePlayer = true,
    onClick = function(playerNum, entry)
        -- Singleplayer: visible.
        -- Multiplayer: visible only to Admin.
    end,
})
```

### Custom Visibility

Use `visibleWhen` when access level is not enough.

```lua
MenuDock.registerButton({
    id = "my_mod_alive_only",
    title = "Alive Only",
    label = "ALV",
    visibleWhen = function(playerNum, playerObj, entry)
        return playerObj ~= nil and playerObj:isAlive()
    end,
    onClick = function(playerNum, entry)
        -- Only shown while the local player is alive.
    end,
})
```

With a `target`, `visibleWhen` receives the target first:

```lua
local controller = {
    enabled = true,
}

function controller:canShow(playerNum, playerObj, entry)
    return self.enabled == true
end

MenuDock.registerButton({
    id = "my_mod_target_visibility",
    title = "Target Visibility",
    label = "VIS",
    target = controller,
    visibleWhen = controller.canShow,
    onClick = function(target, playerNum, entry)
        -- Open menu.
    end,
})
```

### Temporarily Hide Without Unregistering

```lua
MenuDock.registerButton({
    id = "my_mod_hidden_for_now",
    title = "Hidden For Now",
    label = "HID",
    visible = false,
    onClick = function(playerNum, entry)
        -- Not visible until registered again with visible = true or visible omitted.
    end,
})
```

### Notes For Modders

- Keep labels short. Two or three characters usually works best.
- Prefer icons when you have one, and use text labels as a fallback.
- Register entries on the client side.
- Registering the same `id` replaces the existing entry.
- The dock only shows entries that pass their visibility rules.
