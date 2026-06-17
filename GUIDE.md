# Elyon Lib - developer guide

This document explains **how pieces fit together**, **contracts** you must satisfy when calling helpers, and **tables** that would clutter the main README.

---

## Load order & scope

| Rule | Detail |
| --- | --- |
| Players | Enable Elyon Lib **above** any mod that lists it - same as typical library ordering. |
| Shared vs client | Anything under `client/ElyonLib` must only be required from client-loaded scripts (`Client.lua`, ISUI-derived classes, `Events` on client, etc.). `require` in shared/server context will fail if the path is missing on that VM. |
| Server | Dedicated servers never run `HudNotify` or `MenuDock`; guards in those modules assume client UI. |

---

## Globals snapshot

Taken from `ElyonLib/Core/Globals.lua` at library load:

```lua
Globals.isServer = isServer()
Globals.isClient = isClient()
Globals.isSingleplayer = not Globals.isServer and not Globals.isClient
```

`GrantUtils` and other helpers read `Globals.isServer` / `Globals.isClient` exactly as evaluated when `Globals.lua` first loads - not live-updated mid-session.

---

## TimerManager

| Method | Behaviour |
| --- | --- |
| `add(callback, intervalMs, loop)` | Stores timer; returns numeric `id`. |
| `addSeconds` / `addMinutes` | Scale to milliseconds internally. |
| `remove(id)` | Drops timer. |
| Driving event | **Server:** `Events.EveryOneMinute` > `TimerManager:update()` (timers wake at most ~once/minute server-side). **Client:** `Events.OnTick` > `update()` (sub-second accuracy). |

Implications:

- Short TTL HUD timers on dedicated servers are unreliable if you enqueue them only server-side - `HudNotify` already no-ops on `isServer()`.
- For server gameplay logic needing sub-minute precision, use game events (`EveryTenMinutes`, `OnTick` on whichever side owns the simulation) rather than assuming millisecond timers on the server VM.

---

## Logger

### Construction & levels

- `Logger:new(modID, modVersion?)` singleton per `modID` (reuses cached instance).
- Default level: `DEBUG` when `isDebugEnabled()`, else `INFO`.
- Methods: `:setLogLevel`, `:shouldLog`, `:log`, `:error`, `:warning`, `:info`, `:debug`, `:logTable`.

### writeLog relay

`:writeLog(options)` expects `{ logFileMask, logText, logMode }` where `logMode` is `"client"` | `"server"` | `"both"`.

| Side | `"client"` | `"server"` | `"both"` |
| --- | --- | --- | --- |
| Client VM | Writes local log file | N/A typical | Writes local + sends `sendClientCommand` > server writes |
| Server VM | N/A typical | Writes server log | Writes server log + broadcasts to clients via `sendServerCommand` |

Handlers registered in `Logger.lua`:

- Server: `Events.OnClientCommand` for module `ElyonLib`, command `LogToServer`.
- Client: `Events.OnServerCommand` for module `ElyonLib`, command `LogToClient`.

Mods do not register these twice - they reuse the ElyonLib module string.

---

## NetUtils

Unified entry for UI actions that should hit `Server.ServerCommands[name]` regardless of spawn context.

### `executeCommand(moduleName, serverRequirePath, command, args)`

| Runtime | Behaviour |
| --- | --- |
| Pure network client (`isClient()` and not `isServer()`) | `sendClientCommand(playerObj, moduleName, command, args)` - expects your server handlers to mirror the command table. |
| Local / listen-server | `require(serverRequirePath)`, then calls `serverModule.Server.ServerCommands[command](player, args)`. |

Requirements on your server file:

```lua
return {
    Server = {
        ServerCommands = {
            MyAction = function(player, args) end,
        },
    },
}
```

### `executeProcessCommand(moduleName, serverRequirePath, command, args, processFunctionName?)`

Same split client vs local, but invokes `serverModule[processFunctionName or "processCommand"](command, player, args)` instead of a `ServerCommands` table.

---

## GrantUtils

| Function | Notes |
| --- | --- |
| `findPerk(perkName)` | Lookup order: `Perks[name]`, then `Perks.FromString`, then case-insensitive scan. |
| `grantItem(player, itemType, count, summaries[], errors[])` | Validates script item exists. Server path uses `:sendObjectChange("addItemOfType", { type, count })`; client/offline loops `AddItem`. |
| `grantXp(player, perkName, amount, summaries[], errors[])` | Uses `findPerk` + `:getXp():AddXP`. Summary strings appended on success; error strings on failure - caller owns the arrays.

---

## TableUtils & TableFormatter

| TableUtils | Behaviour |
| --- | --- |
| `deepCopy` | Recursive; preserves cyclic graphs by reusing copied nodes (`seen`). Copies metatables. |
| `shallowCopy` | One level only. Non-tables passed through unchanged. |
| `contains(tbl, value)` | `pairs` linear search by `==`. |
| `merge(t1,t2)` | Shallow merges `t2` onto a copy of `t1`; nested tables not deep-merged. |

`TableFormatter.format(tbl, indent?, seen?)` - string output for logs; cyclic tables print `<Circular Reference>`.

---

## FileUtils options

Both `readFile` / `writeFile` accept `options`:

| Field | Meaning |
| --- | --- |
| `isModFile` | `true` uses `getModFileReader` / `getModFileWriter` with `modId`; otherwise `getFileReader` / `getFileWriter`. |
| `createIfNull` | Passed through to reader/writer factory. |
| `append` | Write-only; opens in append mode. |

JSON helpers delegate parsing errors to ElyonLib internal logger via `pcall`.

---

## DateTimeUtility (surface)

Major constants:

- `DateTimeUtility.CALENDAR` - mirrors Java `Calendar` field ids used with `PZCalendar`.
- `DateTimeUtility.FORMAT` - `ISO`, `US`, `EU`, `CUSTOM` + `FORMAT_STRINGS`.

Representative operations (full list matches `DateTimeUtility.lua`):

| Category | Functions |
| --- | --- |
| Calendar / TZ | `getPZCalendarInstance`, `getLocalTimezoneOffset`, `getTimezoneAbbr`, `convertTimezone`, `toUTC`, `toLocalTime` |
| Parse / format | `formatDate`, `parseDate`, `formatShortDate`, `formatTime`, `formatDateTimeWithTZ` |
| Wall clock | `getCurrentLocalDate`, `getCurrentUTCDate`, `getCurrentGameDate` |
| Validation | `isLeapYear`, `getDaysInMonth`, `getFirstDayOfMonth`, `isValidDate` |
| Epoch | `toTimestamp`, `fromTimestamp`, `createUTCDate` |
| Date keys (compact YYYYMMDD-style) | `timestampToDateKey`, `normalizeDateKey`, `dateKeyToDateTable`, `dateTableToDateKey`, `formatDateKey`, `dateKeyToTimestamp`, `addDaysToDateKey`, `daysBetweenDateKeys`, `compareDateKeys` |
| Comparisons | `compareDates`, `isDateBefore` / `After` / `Equal` / variants, timestamp compare helpers, `daysDifference` |

Consult `DateTimeUtility.lua` for exact parameter meanings (several overloads reuse `sec` vs `second` in date tables).

---

## Theme & LayoutUtils

### Theme

- `Theme.colors` - large named palette (`background`, `primary`, `danger`, tiles for reward-style mods, etc.).
- `Theme.standardColors()` returns uppercase aliases mapped to those entries (backward compatible labels like `SECTION`, `WARN`, `BUTTON_PRIMARY`).
- `Theme.applyButtonStyle(btn, variant?)` - `nil` | `"primary"` | `"danger"` | `"success"` | `"warning"`.
- `Theme.applyFieldStyle`, `Theme.applyListStyle`, `Theme.applyComboStyle`, `Theme.applyPanelStyle`, `Theme.applyTickBoxStyle` - assigns `backgroundColor` / `borderColor` copies.
- `Theme.d(color)` > `a, r, g, b` for `drawRect`; `Theme.t(color)` > `r, g, b, a`; `Theme.copy` merges with default white.

### LayoutUtils

Differs slightly from `UIUtils.setBounds` (Layout floors dimensions to ≥1, uses `floor` coercion). Prefer one module per codebase for consistency.

| Function | Returns |
| --- | --- |
| `setBounds(control,x,y,w,h)` | Places control; omit `w`/`h` to move only. |
| `bottom` / `right` | Edge helpers. |
| `clampToScreen(x,y,w,h)` | Clamped coordinates. |
| `centreOnScreen(w,h)` | Centre `(x,y)`. |
| `defaultWindowGeometry(desiredW,desiredH,minW,minH,margin?)` | `x,y,w,h` capped with margin from screen borders. |

---

## MenuDock

Floating puck + vertical rail. Register entries from client scripts during UI setup.

### Entry table

| Field | Required | Description |
| --- | --- | --- |
| `id` | yes | Stable string; registering again replaces prior entry. |
| `title` | no | Tooltip; falls back to `id`. |
| `label` | no | Short rail text when no icon. Falls back through `title` > `id` with width fitting. |
| `icon` | no | Texture path for `getTexture`. |
| `texture` | no | Pre-loaded texture overrides `icon`. |
| `target` | no | If set, `onClick` is invoked as `(target, playerNum, entry)`. If absent, `(playerNum, entry)`. Same split for `visibleWhen` but with `playerObj` before `entry`: `(target, playerNum, playerObj, entry)` vs `(playerNum, playerObj, entry)`. |
| `onClick` | no | Called when the rail button activates. |
| `minimumAccessLevel` | no | Ordered ladder: None < Observer < GM < Overseer < Moderator < Admin. |
| `allowSinglePlayer` | no | When `true`, level gate enforced only where `AccessLevelUtils.isSinglePlayer()` is false. |
| `visible` | no | `false` keeps registration but hides. |
| `visibleWhen` | no | Custom predicate; routed like `runVisibilityPredicate` below. |
| `badge` | no | Overlay spec (Unread counts, icons). Prefer `MenuDock.setEntryBadge` so you do not overwrite the whole entry. |

MenuDock resolves visibility roughly as:

1. Respect `visible == false`.
2. If `minimumAccessLevel` is set (and SP exception does not apply), require `AccessLevelUtils.isPlayerAtLeast`.
3. If `visibleWhen` is set, delegate to predicate with `(target?, playerNum, playerObj, entry)` ordering (see alias lines in `MenuDock.lua`).

### Public API surface

```lua
MenuDock.registerButton(entry)
MenuDock.unregisterButton(idString)
MenuDock.setEntryBadge(entryId, patchTable) -- shallow-merge badge fields on named entry
MenuDock.clearEntryBadge(entryId)
MenuDock.refreshRails()                      -- forcing UI refresh after external entry mutations
MenuDock.runVisibilityPredicate(entry, predicateOrBool, playerNum, playerObj)
MenuDock.isEntryVisible(entry, playerNum)
MenuDock.getVisibleEntries(playerNum)
```

### Badge fields (`badge` table or `setEntryBadge` patch)

| Field | Role |
| --- | --- |
| `texture` / `textureObj` | Icon - `textureObj` wins. |
| `text` | `string | number | function(entry)` centred on the badge circle. |
| `visible` | `boolean | function(entry)` |
| `size` | Diameter px (default library constant ~20). |
| `anchor` | `"topleft"` \| `"topright"` |
| `offsetX`, `offsetY` | Pixel nudge |
| `hideWhenEmpty`, `hideWhenZero` | Omit badge when trivial |
| `maxBeforePlus` | Cap numeric display as `cap+` |
| `font`, `textColor` | Typography |

---

## HudNotify

Right-hand HUD lane aware of Moodle column + right `MenuDock` rail; uses `Theme`, `TimerManager`, `TextUtils.wrapLines`.

**Client only** - `HudNotify.push` returns `nil` on `isServer()`.

### Push options

| Field | Type | Notes |
| --- | --- | --- |
| `title` | string | Trimmed; default card title `"Notice"` if empty. |
| `body` | string | Wrapped to `BODY_MAX_LINES` lines. |
| `type` / `kind` | string | Accent colour map: `"info"` (default blue), `"success"`, `"warning"`, `"error"`, `"message"`. |
| `id` | string | Omit to auto-generate unique id - returned from `push`. |
| `ttlMs` | number | Auto-dismiss timer (exclusive with below). |
| `ttlSeconds` | number | Converted to ms if `ttlMs` absent and > 0. |
| `style` | table | Merged overrides on `HudNotify.defaults` (layout, fonts, paddings, `MAX_STACK`, etc.). |

### Other API

| Call | Purpose |
| --- | --- |
| `HudNotify.pop(id)` | Begin exit animation; returns bool success. |
| `HudNotify.clear()` | Pops entire stack silently. |
| `HudNotify.configure(patch)` | Shallow-merge into `HudNotify.defaults`. |
| `HudNotify.snapshotDefaults()` | Copy for inspection / local branching. |

### Hooks (`HudNotify.hooks`)

| Hook | Behaviour |
| --- | --- |
| `beforePush(opts)` | Return `false` to cancel toast. |
| `afterPush(id, opts)` | Post-create. |
| `beforePop(id, {silent, card})` | Return `false` to cancel removal. |
| `afterPop(id, info)` | Post-pop. |

`apiVersion` field on module is bumped when public layout contract changes across releases.

---

## ItemUtils caches

`_Cache` keyed by normalized full item type caches script item handles, computed display names, and resolved textures. `_TextureReferenceCache` maps arbitrary strings (paths, pseudo `Item_*` icons) once resolved - call `ItemUtils.clearCache()` or clear one type during hot reload/testing.

---

## Sprite Properties

`Properties.setSpriteProperty(props, propertyName, propertyValue, checkIsoFlagType?)` abstracts three engine overloads (`IsoFlagType` userdata vs string/value pairs). Bulk operation `setOrUnsetSpriteProperties(manager, spriteList, setProps, unsetProps)` calls `props:CreateKeySet()` each sprite iteration - appropriate for bootstrap-time tile edits, not hot per-frame churn.

---