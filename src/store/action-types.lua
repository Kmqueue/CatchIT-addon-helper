local Addon = select(2, ...) ---@type Addon

--- @class ActionTypes
local ActionTypes = Addon:GetModule("ActionTypes")

-- ============================================================================
-- ActionTypes - Global
-- ============================================================================

ActionTypes.Global = {
  SET_CHAT_MESSAGES = "global/chatMessages/set",
  SET_ITEM_TOOLTIPS = "global/itemTooltips/set",
  SET_SESSION_PANEL = "global/sessionPanel/set",

  SET_INCLUSIONS = "global/inclusions/set",

  PATCH_FISHING = "global/fishing/patch",
  PATCH_MINIMAP_ICON = "global/minimapIcon/patch",
  PATCH_KEYBINDINGS = "global/keybindings/patch",
  RESET_MAIN_WINDOW_POINT = "global/points/mainWindow/reset",
  SET_MAIN_WINDOW_POINT = "global/points/mainWindow/set",
  RESET_SESSION_PANEL_POINT = "global/points/sessionPanel/reset",
  SET_SESSION_PANEL_POINT = "global/points/sessionPanel/set",
}

-- ============================================================================
-- ActionTypes - Profiles
-- ============================================================================

ActionTypes.Profiles = {
  CREATE_PROFILE = "profiles/create",
  ASSIGN_PROFILE = "profiles/assign",
}

-- ============================================================================
-- ActionTypes - Profile
-- ============================================================================

ActionTypes.Profile = {
  SET_INCLUSIONS = "profile/inclusions/set",
}
