local Addon = select(2, ...) ---@type Addon
local ActionTypes = Addon:GetModule("ActionTypes")
local DefaultStates = Addon:GetModule("DefaultStates")
local Wux = Addon.Wux

--- @class RootReducer
local RootReducer = Addon:GetModule("RootReducer")

--- @class CatchITRootState
--- @field version integer
--- @field global GlobalState
--- @field profiles ProfilesState

-- ============================================================================
-- Local Functions
-- ============================================================================

--- Creates a reducer for `global.points` entries.
--- @generic S
--- @param setActionType string
--- @param resetActionType string
--- @param defaultState S
--- @return WuxReducer<S, any>
local function createPointsReducer(setActionType, resetActionType, defaultState)
  return function(state, action)
    state = Wux:Coalesce(state, defaultState)

    if action.type == setActionType then
      return action.payload
    end

    if action.type == resetActionType then
      return Wux:ShallowCopy(defaultState)
    end

    return state
  end
end

--- @type WuxReducer<ProfileState, any>
local profileReducer = Wux:CombineReducers({
  id = function(state, action) return state end,
  name = function(state, action) return state end,
  settings = Wux:CombineReducers({
    inclusions = Wux:CreatePayloadReducer(ActionTypes.Profile.SET_INCLUSIONS, DefaultStates.Profile.settings.inclusions)
  })
})

-- ============================================================================
-- RootReducer
-- ============================================================================

--- Builds the root reducer for the store.
--- @return WuxReducer<CatchITRootState, any>
function RootReducer:Build()
  return Wux:CombineReducers({
    -- Not dispatched; `version` is set by `Migrations:Migrate()` before store creation.
    version = function(state)
      return Wux:Coalesce(state, DefaultStates.CURRENT_VERSION)
    end,

    --- @type WuxReducer<GlobalState, any>
    global = Wux:CombineReducers({
      chatMessages = Wux:CreatePayloadReducer(ActionTypes.Global.SET_CHAT_MESSAGES, DefaultStates.Global.chatMessages),
      itemTooltips = Wux:CreatePayloadReducer(ActionTypes.Global.SET_ITEM_TOOLTIPS, DefaultStates.Global.itemTooltips),
      sessionPanel = Wux:CreatePayloadReducer(ActionTypes.Global.SET_SESSION_PANEL, DefaultStates.Global.sessionPanel),
      minimapIcon = Wux:CreatePatchReducer(ActionTypes.Global.PATCH_MINIMAP_ICON, DefaultStates.Global.minimapIcon),
      fishing = Wux:CreatePatchReducer(ActionTypes.Global.PATCH_FISHING, DefaultStates.Global.fishing),

      inclusions = Wux:CreatePayloadReducer(ActionTypes.Global.SET_INCLUSIONS, DefaultStates.Global.inclusions),

      keybindings = Wux:CreatePatchReducer(ActionTypes.Global.PATCH_KEYBINDINGS, DefaultStates.Global.keybindings),

      points = Wux:CombineReducers({
        mainWindow = createPointsReducer(
          ActionTypes.Global.SET_MAIN_WINDOW_POINT,
          ActionTypes.Global.RESET_MAIN_WINDOW_POINT,
          DefaultStates.Global.points.mainWindow
        ),
        sessionPanel = createPointsReducer(
          ActionTypes.Global.SET_SESSION_PANEL_POINT,
          ActionTypes.Global.RESET_SESSION_PANEL_POINT,
          DefaultStates.Global.points.sessionPanel
        )
      })
    }),

    --- @type WuxReducer<ProfilesState, any>
    profiles = function(state, action)
      state = Wux:Coalesce(state, DefaultStates.Profiles)

      -- Ensure expected keys are present.
      if state.activeProfileId == nil or state.characterMap == nil or state.profileMap == nil then
        state = Wux:ShallowCopy(state)
        state.activeProfileId = Wux:Coalesce(state.activeProfileId, DefaultStates.DEFAULT_PROFILE_ID)
        state.characterMap = Wux:Coalesce(state.characterMap, DefaultStates.Profiles.characterMap)
        state.profileMap = Wux:Coalesce(state.profileMap, DefaultStates.Profiles.profileMap)
      end

      -- Create profile action.
      if action.type == ActionTypes.Profiles.CREATE_PROFILE then
        --- @cast action WuxPayloadAction<CreateProfilePayload>
        state = Wux:ShallowCopy(state)
        local profile = Wux:DeepCopy(DefaultStates.Profile)
        profile.id = action.payload.profileId
        profile.name = action.payload.profileName
        state.profileMap = Wux:ShallowCopy(state.profileMap)
        state.profileMap[profile.id] = profile
        return state
      end

      -- Assign profile action. Falls through, rather than returning.
      if action.type == ActionTypes.Profiles.ASSIGN_PROFILE then
        --- @cast action WuxPayloadAction<AssignProfilePayload>
        state = Wux:ShallowCopy(state)
        state.activeProfileId = action.payload.profileId
        state.characterMap = Wux:ShallowCopy(state.characterMap)
        state.characterMap[action.payload.characterKey] = action.payload.profileId
      end

      -- Run the profile reducer against the active profile, writing the result back into `profileMap` only if
      -- something changed. A missing active profile is a no-op instead of materializing a phantom profile.
      local profileState = state.profileMap[state.activeProfileId]
      if type(profileState) == "table" then
        local newProfileState = profileReducer(profileState, action)
        if newProfileState ~= profileState then
          state = Wux:ShallowCopy(state)
          state.profileMap = Wux:ShallowCopy(state.profileMap)
          state.profileMap[state.activeProfileId] = newProfileState
        end
      end

      return state
    end
  })
end
