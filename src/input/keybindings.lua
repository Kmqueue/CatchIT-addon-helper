local Addon = select(2, ...) ---@type Addon
local ActionCreators = Addon:GetModule("ActionCreators")
local B = Addon:GetModule("Blizzard")
local Commands = Addon:GetModule("Commands")
local DefaultStates = Addon:GetModule("DefaultStates")
local E = Addon:GetModule("Events")
local EventManager = Addon:GetModule("EventManager")
local Lists = Addon:GetModule("Lists")
local StateManager = Addon:GetModule("StateManager")
local TickerManager = Addon:GetModule("TickerManager")

--- @class Keybindings
local Keybindings = Addon:GetModule("Keybindings")

--- The binding waiting for a key, or `nil` while none is.
--- @type BindingName?
Keybindings.listeningBindingName = nil

--- Stops listening once keybindings are locked. Only runs while listening.
Keybindings.lockTicker = TickerManager:NewTicker(0.05, function()
  if Keybindings:IsLocked() then Keybindings:StopListening() end
end)
Keybindings.lockTicker:Cancel()

--- Bindings kept in the key bindings of the game instead of the store, by binding name: their action in Bindings.xml.
--- The game saves them, so they also work for the CatchIT app, which binds Cast with Lure by `/catchit bind cast`.
--- @type table<string, string>
Keybindings.GAME_BINDINGS = { castAndInteract = "CATCHITFISHINGKEY", castWithLure = "CATCHITCASTKEY" }

--- Hidden buttons keyed by binding name.
--- @type table<BindingName, Button>
local buttons = {}

--- Owner of every override binding CatchIT sets. It also receives keyboard
--- input while a binding is waiting for a key.
local BindingFrame = B.Utils:CreateFrame("Frame", nil, UIParent)
BindingFrame:EnableKeyboard(false)
BindingFrame:SetSize(1, 1)
BindingFrame:SetPoint("CENTER")

-- ============================================================================
-- Local Functions
-- ============================================================================

--- Adds the item shown in the game tooltip to a list.
--- @param listKey ListKey
local function addToList(listKey)
  local itemId = B.Tooltip:GetItemId()
  if itemId then Lists[listKey]:Add(itemId) end
end

--- Removes the item shown in the game tooltip from a list.
--- @param listKey ListKey
local function removeFromList(listKey)
  local itemId = B.Tooltip:GetItemId()
  if itemId then Lists[listKey]:Remove(itemId) end
end

--- Runs each binding's command. Mirrors the keys of `DefaultStates.Global.keybindings`.
--- @type table<BindingName, function>
local handlers = {
  toggleMainWindow = Commands.options,
  destroyNextItem = Commands.destroy,
  addToProfileInclusions = function() addToList("ProfileInclusions") end,
  removeFromProfileInclusions = function() removeFromList("ProfileInclusions") end,
  addToGlobalInclusions = function() addToList("GlobalInclusions") end,
  removeFromGlobalInclusions = function() removeFromList("GlobalInclusions") end
}

--- Returns the hidden button for a binding, creating it if needed.
--- @param bindingName BindingName
--- @return Button
local function getButton(bindingName)
  if not buttons[bindingName] then
    local button = B.Utils:CreateFrame("Button", "CatchITKeybinding_" .. bindingName)
    button:SetScript("OnClick", handlers[bindingName])
    buttons[bindingName] = button
  end

  return buttons[bindingName]
end

--- Clears every override binding and sets the saved keys again.
local function refreshOverrides()
  B.Bindings:ClearOverrides(BindingFrame)

  for bindingName, key in pairs(StateManager:GetGlobalState().keybindings) do
    if handlers[bindingName] and key ~= DefaultStates.UNBOUND_KEY then
      B.Bindings:SetClickOverride(BindingFrame, key, getButton(bindingName):GetName())
    end
  end
end

--- Refreshes the overrides once the player is out of combat.
--- @type function
local debounceRefresh
debounceRefresh = TickerManager:NewDebouncer(0.1, function()
  if Keybindings:IsLocked() then return debounceRefresh() end
  refreshOverrides()
end)

-- ============================================================================
-- Keybindings
-- ============================================================================

--- Returns `true` while keybindings cannot be changed.
--- @return boolean
function Keybindings:IsLocked()
  return B.Utils:InCombatLockdown()
end

--- Returns the key saved for a binding, or `UNBOUND_KEY` if it has none.
--- @param bindingName BindingName
--- @return string key
function Keybindings:GetKey(bindingName)
  local action = self.GAME_BINDINGS[bindingName]
  if action then return GetBindingKey(action) or DefaultStates.UNBOUND_KEY end
  return StateManager:GetGlobalState().keybindings[bindingName] or DefaultStates.UNBOUND_KEY
end

--- Unbinds every key of a game binding, without saving.
--- @param action string
local function clearGameBinding(action)
  for _, key in ipairs({ GetBindingKey(action) }) do SetBinding(key) end
end

--- Puts `key` on a game binding as its only key and saves the key bindings of the game. A key of the store that is
--- the same is removed, because it would take priority. Returns the name of a binding that had the key.
--- @param bindingName BindingName
--- @param key string
--- @return BindingName? replacedBindingName
local function setGameKey(bindingName, key)
  local action = Keybindings.GAME_BINDINGS[bindingName]
  local replacedBindingName

  for otherBindingName, otherAction in pairs(Keybindings.GAME_BINDINGS) do
    if otherBindingName ~= bindingName and GetBindingAction(key) == otherAction then replacedBindingName = otherBindingName end
  end

  local patch = {}
  for otherBindingName, otherKey in pairs(StateManager:GetGlobalState().keybindings) do
    if otherKey == key then
      patch[otherBindingName] = DefaultStates.UNBOUND_KEY
      replacedBindingName = otherBindingName
    end
  end
  if next(patch) then StateManager:Dispatch(ActionCreators.Global.patchKeybindings(patch)) end

  -- The game action the key had, unless it was one of these bindings.
  local gameBindingName = not replacedBindingName and GetBindingAction(key) ~= action and B.Bindings:GetGameBindingName(key) or nil

  clearGameBinding(action)
  SetBinding(key, action)
  SaveBindings(GetCurrentBindingSet())
  EventManager:Fire(E.GameBindingsChanged)
  EventManager:Fire(E.KeybindingBound, bindingName, key, replacedBindingName, gameBindingName, true)
  return replacedBindingName
end

--- Saves a key for a binding. Returns the name of an existing binding if one had the
--- key set previously.
--- @param bindingName BindingName
--- @param key string
--- @return BindingName? replacedBindingName
function Keybindings:SetKey(bindingName, key)
  if key == DefaultStates.UNBOUND_KEY then return self:RemoveKey(bindingName) end
  if self.GAME_BINDINGS[bindingName] then return setGameKey(bindingName, key) end

  local patch = { [bindingName] = key }
  local replacedBindingName

  for otherBindingName, otherKey in pairs(StateManager:GetGlobalState().keybindings) do
    if otherBindingName ~= bindingName and otherKey == key then
      patch[otherBindingName] = DefaultStates.UNBOUND_KEY
      replacedBindingName = otherBindingName
    end
  end

  StateManager:Dispatch(ActionCreators.Global.patchKeybindings(patch))
  EventManager:Fire(E.KeybindingBound, bindingName, key, replacedBindingName, B.Bindings:GetGameBindingName(key))
  return replacedBindingName
end

--- Removes the key saved for a binding.
--- @param bindingName BindingName
function Keybindings:RemoveKey(bindingName)
  local action = self.GAME_BINDINGS[bindingName]
  if action then
    clearGameBinding(action)
    SaveBindings(GetCurrentBindingSet())
    EventManager:Fire(E.GameBindingsChanged)
    return
  end
  StateManager:Dispatch(ActionCreators.Global.patchKeybindings({ [bindingName] = DefaultStates.UNBOUND_KEY }))
end

--- Sets the saved keys again, debouncing until lockdown ends if necessary.
function Keybindings:Refresh()
  if self:IsLocked() then
    debounceRefresh()
  else
    refreshOverrides()
  end
end

--- Returns the binding waiting for a key, or `nil` while none is.
--- @return BindingName? bindingName
function Keybindings:GetListeningBindingName()
  return self.listeningBindingName
end

--- Starts waiting for the next input to bind to a binding. Does nothing while locked.
--- @param bindingName BindingName
function Keybindings:StartListening(bindingName)
  if self:IsLocked() then return end
  self:StopListening()

  self.listeningBindingName = bindingName
  EventManager:Fire(E.KeybindingListeningChanged, bindingName)
  BindingFrame:EnableKeyboard(true)
  BindingFrame:SetScript("OnKeyDown", function(_, key) Keybindings:ProcessInput(key) end)
  self.lockTicker:Restart()
end

--- Binds the input to the binding waiting for a key, then stops listening.
--- Escape stops without binding. Does nothing while no binding is waiting.
--- @param input string Key name or mouse button name.
function Keybindings:ProcessInput(input)
  if not self.listeningBindingName then return end

  if input == "ESCAPE" then
    self:StopListening()
    return
  end

  local key = B.Bindings:GetKeyFromInput(input)
  if not key then return end

  self:SetKey(self.listeningBindingName, key)
  self:StopListening()
end

--- Stops waiting for an input.
function Keybindings:StopListening()
  if not self.listeningBindingName then return end

  self.listeningBindingName = nil
  EventManager:Fire(E.KeybindingListeningChanged, nil)
  BindingFrame:EnableKeyboard(false)
  BindingFrame:SetScript("OnKeyDown", nil)
  self.lockTicker:Cancel()
end

-- ============================================================================
-- Events
-- ============================================================================

--- The saved keybindings as of the last refresh.
local keybindings

-- The key bindings of the game also change in the game's own window.
local bindingsFrame = CreateFrame("Frame")
bindingsFrame:RegisterEvent("UPDATE_BINDINGS")
bindingsFrame:SetScript("OnEvent", function() EventManager:Fire(E.GameBindingsChanged) end)

-- Stop listening and refresh when the saved keys change, including the first update after login.
EventManager:On(E.StateUpdated, function(state)
  if state.global.keybindings ~= keybindings then
    keybindings = state.global.keybindings
    Keybindings:StopListening()
    Keybindings:Refresh()
  end
end)
