local Globals = {}

---@type boolean
Globals.isServer = isServer()
---@type boolean
Globals.isClient = isClient()
---@type boolean
Globals.isSingleplayer = not Globals.isServer and not Globals.isClient

return Globals
