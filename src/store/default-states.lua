local Addon = select(2, ...) ---@type Addon

--- @class DefaultStates
local DefaultStates = Addon:GetModule("DefaultStates")

--- Bump whenever a state change requires a migration.
DefaultStates.CURRENT_VERSION = 1

DefaultStates.DEFAULT_PROFILE_ID = "DEFAULT_PROFILE"

--- Saved in place of a key when a binding has none.
DefaultStates.UNBOUND_KEY = ""

-- ============================================================================
-- LuaCATS Annotations
-- ============================================================================

--- Example: `{ ["itemId"] = true, ... }`
--- @alias ItemIdMap table<string, boolean>

--- @class FishingState
--- @field autoLoot boolean Always auto loot fishing loot.
--- @field autoLure boolean The cast keys put a lure on the fishing pole when it has none.
--- @field lure string `"best"`, or the item ID of the lure to use.
--- @field openContainers "off"|"caught"|"all" With `autoLoot`, open the clams and containers caught by fishing, or all
--- containers of the bags, that open without a cast.
--- @field hideNamePlates boolean Hide NPC nameplates and names while fishing.
--- @field enhanceSounds boolean Mute everything but effects while fishing.
--- @field keepOnlyFishingSounds boolean With `enhanceSounds`, also mute every sound file but the sounds of the bobber.
--- @field enhanceSoundsScale number Effects and master volume used while `enhanceSounds` is active, `0` to `1`.
--- @field soundDelayMinutes integer Minutes the sounds stay enhanced after the last cast. `0` restores them right away.

-- ============================================================================
-- DefaultStates - Global
-- ============================================================================

--- Default state for global settings.
--- @class GlobalState
DefaultStates.Global = {
  chatMessages = true,
  itemTooltips = true,
  sessionPanel = true,
  minimapIcon = { hide = false },

  --- @type FishingState
  fishing = {
    autoLoot = true,
    autoLure = true,
    lure = "best",
    openContainers = "caught",
    hideNamePlates = true,
    enhanceSounds = true,
    keepOnlyFishingSounds = true,
    enhanceSoundsScale = 1,
    soundDelayMinutes = 1
  },

  --- Items destroyed on every character.
  --- @type ItemIdMap
  inclusions = {},

  --- Maps binding names to keys.
  --- Example: `{ toggleMainWindow = "CTRL-O", ... }`
  --- @enum (key) BindingName
  keybindings = {
    toggleMainWindow = DefaultStates.UNBOUND_KEY,
    destroyNextItem = DefaultStates.UNBOUND_KEY,
    addToProfileInclusions = DefaultStates.UNBOUND_KEY,
    removeFromProfileInclusions = DefaultStates.UNBOUND_KEY,
    addToGlobalInclusions = DefaultStates.UNBOUND_KEY,
    removeFromGlobalInclusions = DefaultStates.UNBOUND_KEY
  },

  points = {
    mainWindow = { point = "CENTER", relativePoint = "CENTER", offsetX = 0, offsetY = 50 },
    sessionPanel = { point = "TOP", relativePoint = "TOP", offsetX = 0, offsetY = -100 }
  }
}

-- ============================================================================
-- DefaultStates - Profiles
-- ============================================================================

--- A profile belongs to one character. `StateManager` creates it on the character's first login.
--- @class ProfilesState
DefaultStates.Profiles = {
  activeProfileId = DefaultStates.DEFAULT_PROFILE_ID,

  --- Maps player character keys to profile IDs.
  --- Example: `{ ["<character-key>"] = "<profile-id>", ... }`
  --- @type table<string, string>
  characterMap = {},

  --- Maps profile IDs to profiles.
  --- Example: `{ ["<profile-id>"] = <ProfileState>, ... }`
  --- @type table<string, ProfileState>
  profileMap = {}
}

-- ============================================================================
-- DefaultStates - Profile
-- ============================================================================

--- Default state for a new profile.
--- @class ProfileState
DefaultStates.Profile = {
  id = DefaultStates.DEFAULT_PROFILE_ID,
  name = "Default",
  settings = {
    --- Items destroyed on this character.
    --- @type ItemIdMap
    inclusions = {}
  }
}
