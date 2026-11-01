local Addon = select(2, ...) ---@type Addon
local Colors = Addon:GetModule("Colors")
local Destroyer = Addon:GetModule("Destroyer")
local E = Addon:GetModule("Events")
local EventManager = Addon:GetModule("EventManager")
local L = Addon:GetModule("Locale")
local Keybindings = Addon:GetModule("Keybindings")
local MainWindow = Addon:GetModule("MainWindow")
local Statistics = Addon:GetModule("Statistics")

--- @class Commands
local Commands = Addon:GetModule("Commands")

-- ============================================================================
-- Events
-- ============================================================================

-- Register the slash command on login.
EventManager:Once(E.Wow.PlayerLogin, function()
  SLASH_CATCHIT1 = "/catchit"
  SlashCmdList.CATCHIT = function(msg)
    msg = strlower(msg or "")

    -- Split message into args.
    local args = {}
    for arg in msg:gmatch("%S+") do args[#args + 1] = strlower(arg) end

    -- First arg is command name.
    local key = table.remove(args, 1) or "options"
    key = type(Commands[key]) == "function" and key or "help"
    Commands[key](SafeUnpack(args))
  end
end)

-- ============================================================================
-- Local Functions
-- ============================================================================

--- Prints a `/catchit <suffix>` line followed by its description.
--- @param suffix string
--- @param description string
local function printCommand(suffix, description)
  local cmd = suffix ~= "" and ("/catchit " .. suffix) or "/catchit"
  Addon:ForcePrint(Colors.Gold("  " .. cmd), Colors.Grey("-"), description)
end

-- ============================================================================
-- Commands
-- ============================================================================

--- Prints a list of commands.
function Commands.help()
  Addon:ForcePrint(L.COMMANDS .. ":")
  printCommand("", L.COMMAND_DESCRIPTION_OPTIONS)
  printCommand("destroy", L.COMMAND_DESCRIPTION_DESTROY)
  printCommand("bind cast KEY catch KEY destroy KEY", L.COMMAND_DESCRIPTION_BIND)
  printCommand("stats", L.COMMAND_DESCRIPTION_STATS)
  printCommand("help", L.COMMAND_DESCRIPTION_HELP)
end

--- Toggles the `MainWindow`.
function Commands.options()
  MainWindow:Toggle()
end

--- Starts the `Destroyer`.
function Commands.destroy()
  Destroyer:Start()
end

--- Shows the statistics. `/catchit stats reset` deletes the ones of this character, `/catchit stats reset session`
--- only the current or last session.
--- @param action? string
--- @param what? string
function Commands.stats(action, what)
  if action == "reset" and what == "session" then
    Statistics:ResetSession()
    Addon:ForcePrint(L.SESSION_RESET)
    return
  end
  if action == "reset" then
    Statistics:Reset()
    Addon:ForcePrint(L.STATISTICS_RESET)
    return
  end
  MainWindow:ShowTab("STATISTICS")
end

--- Bindings that `bind` can set, by the name used in the command: `binding` of `Keybindings`, or `action` of the game.
--- @type table<string, { binding?: BindingName, action?: string, label: fun(): string }>
local bindNames = {
  cast = { binding = "castWithLure", label = function() return L.CAST_WITH_LURE end },
  catch = { action = "INTERACTMOUSEOVER", label = function() return GetBindingName("INTERACTMOUSEOVER") end },
  destroy = { binding = "destroyNextItem", label = function() return L.DESTROY_NEXT_ITEM end }
}

--- Puts a key on a binding. Nothing is printed when the key is already set.
--- @param name string
--- @param key string
local function bindKey(name, key)
  local bind = bindNames[name]
  if bind.binding then
    if Keybindings:GetKey(bind.binding) == key then return end
    Keybindings:SetKey(bind.binding, key)
  else
    if GetBindingAction(key) == bind.action then return end
    SetBinding(key, bind.action)
    SaveBindings(GetCurrentBindingSet())
  end
  Addon:ForcePrint(L.KEY_BOUND_BY_COMMAND:format(Colors.Gold(bind.label()), Colors.Gold(key)))
end

--- Sets the keys of bindings, typed by the button "Set keys in WoW" of the CatchIT app in one line:
--- `/catchit bind cast , catch . destroy NUMPAD9`. Each key is a WoW key name. Cast goes to Cast with Lure, catch to
--- Interact with Mouseover of the game, destroy to Destroy Next Item.
--- @param ... string Pairs of a name and a key.
function Commands.bind(...)
  local args = { ... }
  if #args == 0 or #args % 2 ~= 0 then return Commands.help() end
  for i = 1, #args, 2 do
    if not bindNames[args[i]] then return Commands.help() end
  end
  if Keybindings:IsLocked() then return Addon:ForcePrint(L.BIND_IN_COMBAT) end

  for i = 1, #args, 2 do bindKey(args[i], strupper(args[i + 1])) end
end
