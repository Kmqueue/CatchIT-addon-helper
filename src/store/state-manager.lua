local Addon = select(2, ...) ---@type Addon
local ActionCreators = Addon:GetModule("ActionCreators")
local DefaultStates = Addon:GetModule("DefaultStates")
local E = Addon:GetModule("Events")
local EventManager = Addon:GetModule("EventManager")
local Middlewares = Addon:GetModule("Middlewares")
local Migrations = Addon:GetModule("Migrations")
local RootReducer = Addon:GetModule("RootReducer")
local StateReconciler = Addon:GetModule("StateReconciler")
local Wux = Addon.Wux

---@class StateManager
local StateManager = Addon:GetModule("StateManager")

--- Name of the account-wide saved variable, declared in the TOC.
local SAVED_VARIABLES_KEY = "CatchITDB"

-- ============================================================================
-- Store
-- ============================================================================

--- @type WuxStore<CatchITRootState>
local _Store

-- Create store once the `Wow.PlayerLogin` event fires.
EventManager:Once(E.Wow.PlayerLogin, function()
  --- @type CatchITRootState
  local initialState = Wux:ReadSavedVariables(SAVED_VARIABLES_KEY)
  initialState = Migrations:Migrate(initialState)
  initialState = StateReconciler:Reconcile(initialState)

  -- Every character has its own profile. A character without one gets a new profile right here, before the store
  -- exists, so that no other character's lists are ever shown or used for it.
  local characterKey = Addon:GetCharacterKey()
  local profileId = initialState.profiles.characterMap[characterKey]
  if profileId == nil or initialState.profiles.profileMap[profileId] == nil then
    profileId = Addon:GetShortUID()
    local profile = Wux:DeepCopy(DefaultStates.Profile)
    profile.id = profileId
    profile.name = characterKey
    initialState.profiles.profileMap[profileId] = profile
    initialState.profiles.characterMap[characterKey] = profileId
  end
  initialState.profiles.activeProfileId = profileId

  _Store = Wux:CreateStore(RootReducer:Build(), initialState, Middlewares:Build())

  do -- Wire up saved variables.
    local function write(state)
      state = Wux:ShallowCopy(state)
      state.profiles = Wux:ShallowCopy(state.profiles)
      state.profiles.activeProfileId = nil
      _G[SAVED_VARIABLES_KEY] = state
    end
    write(_Store:GetState())
    _Store:Subscribe(write)
  end

  _Store:Subscribe(function(state)
    EventManager:Fire(E.StateUpdated, state)
  end)

  EventManager:Fire(E.StoreCreated, _Store)
  EventManager:Fire(E.StateUpdated, _Store:GetState())
end)

-- ============================================================================
-- StateManager
-- ============================================================================

--- Returns the underlying Wux store.
--- @return WuxStore<CatchITRootState>
function StateManager:GetStore()
  return _Store
end

--- Convenience method. Equivalent to `StateManager:GetStore():Dispatch()`.
--- @param action WuxAction
function StateManager:Dispatch(action)
  _Store:Dispatch(action)
end

--- Returns the global state.
--- @return GlobalState
function StateManager:GetGlobalState()
  return _Store:GetState().global
end

--- Returns the profile of the current character.
--- @return ProfileState
function StateManager:GetProfileState()
  local state = _Store:GetState()
  return state.profiles.profileMap[state.profiles.activeProfileId] or DefaultStates.Profile
end
