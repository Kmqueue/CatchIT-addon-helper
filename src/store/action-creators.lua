local Addon = select(2, ...) ---@type Addon
local ActionTypes = Addon:GetModule("ActionTypes")
local Wux = Addon.Wux

--- @class ActionCreators
local ActionCreators = Addon:GetModule("ActionCreators")

-- ============================================================================
-- LuaCATS Annotations
-- ============================================================================

--- @class CreateProfilePayload
--- @field profileId string
--- @field profileName string

--- @class AssignProfilePayload
--- @field characterKey string
--- @field profileId string

-- ============================================================================
-- ActionCreators - Global
-- ============================================================================

ActionCreators.Global = {
  --- Action creator for `ActionTypes.Global.SET_CHAT_MESSAGES`.
  --- @type WuxActionCreator<boolean>
  setChatMessages = Wux:CreateActionCreator(ActionTypes.Global.SET_CHAT_MESSAGES),

  --- Action creator for `ActionTypes.Global.SET_ITEM_TOOLTIPS`.
  --- @type WuxActionCreator<boolean>
  setItemTooltips = Wux:CreateActionCreator(ActionTypes.Global.SET_ITEM_TOOLTIPS),

  --- Action creator for `ActionTypes.Global.SET_SESSION_PANEL`.
  --- @type WuxActionCreator<boolean>
  setSessionPanel = Wux:CreateActionCreator(ActionTypes.Global.SET_SESSION_PANEL),

  --- Action creator for `ActionTypes.Global.PATCH_FISHING`.
  --- @type WuxActionCreator<table<string, any>>
  patchFishing = Wux:CreateActionCreator(ActionTypes.Global.PATCH_FISHING),

  --- Action creator for `ActionTypes.Global.PATCH_MINIMAP_ICON`.
  --- @type WuxActionCreator<table<string, any>>
  patchMinimapIcon = Wux:CreateActionCreator(ActionTypes.Global.PATCH_MINIMAP_ICON),

  --- Action creator for `ActionTypes.Global.PATCH_KEYBINDINGS`.
  --- @type WuxActionCreator<table<string, string>>
  patchKeybindings = Wux:CreateActionCreator(ActionTypes.Global.PATCH_KEYBINDINGS),

  --- Action creator for `ActionTypes.Global.SET_INCLUSIONS`.
  --- @type WuxActionCreator<ItemIdMap>
  setInclusions = Wux:CreateActionCreator(ActionTypes.Global.SET_INCLUSIONS),

  points = {
    mainWindow = {
      --- Action creator for `ActionTypes.Global.SET_MAIN_WINDOW_POINT`.
      --- @type WuxActionCreator<table>
      set = Wux:CreateActionCreator(ActionTypes.Global.SET_MAIN_WINDOW_POINT),

      --- Action creator for `ActionTypes.Global.RESET_MAIN_WINDOW_POINT`.
      --- @type fun(): WuxAction
      reset = Wux:CreateActionCreator(ActionTypes.Global.RESET_MAIN_WINDOW_POINT)
    },
    sessionPanel = {
      --- Action creator for `ActionTypes.Global.SET_SESSION_PANEL_POINT`.
      --- @type WuxActionCreator<table>
      set = Wux:CreateActionCreator(ActionTypes.Global.SET_SESSION_PANEL_POINT),

      --- Action creator for `ActionTypes.Global.RESET_SESSION_PANEL_POINT`.
      --- @type fun(): WuxAction
      reset = Wux:CreateActionCreator(ActionTypes.Global.RESET_SESSION_PANEL_POINT)
    }
  }
}

-- ============================================================================
-- ActionCreators - Profiles
-- ============================================================================

ActionCreators.Profiles = {
  --- Action creator for `ActionTypes.Profiles.CREATE_PROFILE`.
  --- @type WuxActionCreator<CreateProfilePayload>
  createProfile = Wux:CreateActionCreator(ActionTypes.Profiles.CREATE_PROFILE),

  --- Action creator for `ActionTypes.Profiles.ASSIGN_PROFILE`.
  --- @type WuxActionCreator<AssignProfilePayload>
  assignProfile = Wux:CreateActionCreator(ActionTypes.Profiles.ASSIGN_PROFILE),
}

-- ============================================================================
-- ActionCreators - Profile
-- ============================================================================

ActionCreators.Profile = {
  --- Action creator for `ActionTypes.Profile.SET_INCLUSIONS`.
  --- @type WuxActionCreator<ItemIdMap>
  setInclusions = Wux:CreateActionCreator(ActionTypes.Profile.SET_INCLUSIONS),
}
