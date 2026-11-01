-- Fishing helper of CatchIT: one key that casts and then interacts with the bobber, a key that only casts (for the
-- CatchIT app), a lure put on the pole before the cast, soft target while fishing, auto loot, and hidden names,
-- enhanced sounds and only the sounds of the bobber while fishing. Written for CatchIT, the idea of the one key comes
-- from BetterFishing by Yuyuli. Settings live in the CatchIT store (`global.fishing`).
local Addon = select(2, ...) ---@type Addon
local Containers = Addon:GetModule("Containers")
local DefaultStates = Addon:GetModule("DefaultStates")
local E = Addon:GetModule("Events")
local EventManager = Addon:GetModule("EventManager")
local Lures = Addon:GetModule("Lures")
local StateManager = Addon:GetModule("StateManager")
local Statistics = Addon:GetModule("Statistics")

--- @class Fishing
local Fishing = Addon:GetModule("Fishing")

BINDING_HEADER_CATCHIT = "CatchIT"
BINDING_NAME_CATCHITFISHINGKEY = "Cast and Interact"
BINDING_NAME_CATCHITCASTKEY = "Cast with Lure"

-- ============================================================================
-- Constants
-- ============================================================================

--- Spells whose channel is fishing: the ranks of the classic clients, the retail spells, Ice and Void fishing.
local FISHING_SPELLS = {
  [7620] = true, [7731] = true, [7732] = true, [18248] = true, [33095] = true, [51294] = true, [88868] = true,
  [110410] = true, [131474] = true, [131476] = true, [131490] = true, [158743] = true, [377895] = true,
  [1224771] = true
}

--- Soft target while fishing: any interactable object up to 60 yd in front of the player, marked with an icon.
local SOFT_TARGET = {
  SoftTargetInteract = "3",
  SoftTargetInteractArc = "2",
  SoftTargetInteractRange = "60",
  SoftTargetIconGameObject = "1",
  SoftTargetIconInteract = "1"
}

--- Nameplates and names hidden while fishing, so they do not cover the bobber. Names of hostile NPCs stay as they are.
local HIDDEN_NAMES = {
  nameplateShowEnemies = "0",
  nameplateShowFriends = "0",
  UnitNameNPC = "0",
  UnitNameNonCombatCreatureName = "0",
  UnitNameInteractiveNPC = "0",
  UnitNameFriendlySpecialNPCName = "0"
}

--- Sound files of the bobber that stay audible with "Keep only fishing sounds".
local FISHING_SOUND_FILES = { [568970] = true, [569044] = true, [569285] = true, [569807] = true, [569816] = true }

--- Highest sound file muted by "Keep only fishing sounds". Files of the newest retail content are above it and stay.
local LAST_SOUND_FILE = 999999

--- Sound files muted or unmuted on one frame, so the game does not freeze.
local SOUND_FILES_PER_FRAME = 50000

-- ============================================================================
-- State
-- ============================================================================

--- `true` while the player channels a fishing spell.
local isFishing = false

--- `true` between an auto loot of fishing loot and the loot window closing.
local isAutoLooting = false

--- `true` once the open loot window is counted in the statistics.
local isLootCounted = false

--- Timer that restores the sounds after the last cast, `nil` while none waits.
local soundTimer = nil

--- `true` while the sound files are muted (or being muted) by "Keep only fishing sounds".
local soundFilesMuted = false

--- `true` while some sound files may still be muted, until an unmute has gone through all of them.
local soundFilesDirty = false

--- Ticker that mutes or unmutes the sound files, `nil` while none runs.
local soundFilesJob = nil

--- What the keys of "Cast and Interact" and "Cast with Lure" are pointed at, so they are only changed when something
--- changes.
local armedKeys = nil

--- Work that cannot run in combat, by name, run when combat ends. A newer entry replaces an older one.
--- @type table<string, function>
local afterCombat = {}

--- Owner of the override bindings of the "Cast and Interact" and "Cast with Lure" keys.
local bindingOwner = CreateFrame("Frame")

--- The button the cast keys click while not fishing: it puts a lure on the pole when one is due, otherwise it casts.
--- Its `lureId` is the lure it uses, `nil` while it casts.
local castButton = CreateFrame("Button", "CatchITCastButton", UIParent, "SecureActionButtonTemplate")
castButton:RegisterForClicks("LeftButtonDown")
castButton:SetAttribute("useOnKeyDown", true)
castButton:HookScript("PostClick", function(self)
  if self.lureId then Lures:Used(self.lureId) end
end)

-- ============================================================================
-- Local Functions
-- ============================================================================

--- Returns the fishing settings, or their defaults while the store does not exist yet.
--- @return FishingState
local function getSettings()
  if StateManager:GetStore() then return StateManager:GetGlobalState().fishing end
  return DefaultStates.Global.fishing
end

--- Runs `func` now, or when combat ends if the player is in combat.
--- @param name string
--- @param func function
local function outOfCombat(name, func)
  if InCombatLockdown() then
    afterCombat[name] = func
  else
    afterCombat[name] = nil
    func()
  end
end

--- Returns the localized name of a spell.
--- @param spellId integer
--- @return string?
local function getSpellName(spellId)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellId) end
  return (GetSpellInfo(spellId))
end

-- CVar groups: a group remembers the values the player had when it was first applied, and puts them back on restore.

--- @class CVarGroup
--- @field saved table<string, string>? Values of the player, `nil` while the group is not applied.

--- @type table<string, CVarGroup>
local groups = { softTarget = {}, names = {}, sounds = {} }

--- Sets the CVars of `values`. CVars the client does not have are skipped.
--- @param group CVarGroup
--- @param values table<string, string>
local function applyGroup(group, values)
  if not group.saved then
    group.saved = {}
    for name in pairs(values) do group.saved[name] = GetCVar(name) end
  end

  for name, value in pairs(values) do
    if group.saved[name] ~= nil then SetCVar(name, value) end
  end
end

--- Puts back the values the player had. Does nothing while the group is not applied.
--- @param group CVarGroup
local function restoreGroup(group)
  if not group.saved then return end
  for name, value in pairs(group.saved) do SetCVar(name, value) end
  group.saved = nil
end

--- Sets the cast button to the lure that is due, or to casting fishing.
local function refreshCastButton()
  outOfCombat("button", function()
    local lureId = Lures:GetLureToApply()
    local spellName = getSpellName(7620) or getSpellName(131474)
    local setting = lureId and ("item:" .. lureId) or spellName
    if castButton.setting == setting then return end
    castButton.setting, castButton.lureId = setting, lureId

    castButton:SetAttribute("type", lureId and "item" or "spell")
    castButton:SetAttribute("item", lureId and setting or nil)
    castButton:SetAttribute("target-slot", lureId and (INVSLOT_MAINHAND or 16) or nil)
    castButton:SetAttribute("spell", not lureId and spellName or nil)
  end)
end

--- Points the keys of "Cast and Interact" and "Cast with Lure" at the cast button, and while fishing the keys of
--- "Cast and Interact" at the soft target. The keys of "Cast with Lure" then do nothing (their own binding runs
--- `CatchIT_Fishing_Run()`), so a second press casts after a lure and does nothing while fishing.
local function armKeys()
  refreshCastButton()
  outOfCombat("keys", function()
    local fishKey1, fishKey2 = GetBindingKey("CATCHITFISHINGKEY")
    local castKey1, castKey2 = GetBindingKey("CATCHITCASTKEY")
    local keys = strjoin(" ", tostring(isFishing), tostring(fishKey1), tostring(fishKey2), tostring(castKey1),
      tostring(castKey2))
    if armedKeys == keys then return end

    ClearOverrideBindings(bindingOwner)
    armedKeys = keys

    for _, key in pairs({ fishKey1, fishKey2 }) do
      if isFishing then
        SetOverrideBinding(bindingOwner, true, key, "INTERACTTARGET")
      else
        SetOverrideBindingClick(bindingOwner, true, key, castButton:GetName(), "LeftButton")
      end
    end

    if isFishing then return end
    for _, key in pairs({ castKey1, castKey2 }) do
      SetOverrideBindingClick(bindingOwner, true, key, castButton:GetName(), "LeftButton")
    end
  end)
end

--- Stops the timer that restores the sounds.
local function cancelSoundTimer()
  if soundTimer then
    soundTimer:Cancel()
    soundTimer = nil
  end
end

--- Mutes (`true`) or unmutes (`false`) every sound file but the ones of the bobber, a part on each frame. A newer call
--- stops an older one. Muted files stay muted through a reload (only a restart of the game clears them), so they are
--- unmuted on logout, see `PLAYER_LOGOUT`.
--- @param mute boolean
local function muteSoundFiles(mute)
  if soundFilesJob then soundFilesJob:Cancel() end
  soundFilesMuted = mute
  if mute then soundFilesDirty = true end

  local setFile = mute and MuteSoundFile or UnmuteSoundFile
  local nextFile = 1
  local job
  job = C_Timer.NewTicker(0, function()
    local lastFile = math.min(nextFile + SOUND_FILES_PER_FRAME - 1, LAST_SOUND_FILE)
    for fileId = nextFile, lastFile do
      if not FISHING_SOUND_FILES[fileId] then setFile(fileId) end
    end
    nextFile = lastFile + 1

    if nextFile > LAST_SOUND_FILE then
      job:Cancel()
      if soundFilesJob == job then soundFilesJob = nil end
      if not mute then soundFilesDirty = false end
    end
  end)
  soundFilesJob = job
end

--- Puts back the sounds of the player: the sound CVars and the muted sound files.
local function restoreSounds()
  restoreGroup(groups.sounds)
  if soundFilesMuted then muteSoundFiles(false) end
end

--- Mutes music, ambience and pets and sets the volume of the effects, so the splash is easy to hear. With "Keep only
--- fishing sounds" every sound file but the ones of the bobber is muted too.
local function enhanceSounds()
  cancelSoundTimer()
  local settings = getSettings()
  if not settings.enhanceSounds then return end
  if settings.keepOnlyFishingSounds and not soundFilesMuted then muteSoundFiles(true) end

  local volume = tostring(settings.enhanceSoundsScale or 1)
  applyGroup(groups.sounds, {
    Sound_EnableAllSound = "1",
    Sound_EnableSFX = "1",
    Sound_EnableSoundWhenGameIsInBG = "1",
    Sound_EnableMusic = "0",
    Sound_EnableAmbience = "0",
    Sound_EnablePetSounds = "0",
    Sound_SFXVolume = volume,
    Sound_MasterVolume = volume
  })
end

--- Restores the sounds `soundDelayMinutes` after the last cast, or right away when it is `0`. The next cast cancels
--- the wait, so the sounds stay enhanced while the player keeps fishing.
local function scheduleSoundRestore()
  cancelSoundTimer()
  local minutes = tonumber(getSettings().soundDelayMinutes) or 0

  if minutes <= 0 then
    restoreSounds()
  else
    soundTimer = C_Timer.NewTimer(minutes * 60, function()
      soundTimer = nil
      restoreSounds()
    end)
  end
end

-- ============================================================================
-- Events
-- ============================================================================

--- @type table<string, function>
local handlers = {}

function handlers.PLAYER_LOGIN()
  armKeys()
end

function handlers.UPDATE_BINDINGS()
  armKeys()
end

function handlers.PLAYER_REGEN_ENABLED()
  local pending = afterCombat
  afterCombat = {}
  for _, func in pairs(pending) do func() end
end

function handlers.UNIT_SPELLCAST_CHANNEL_START(_, _, spellId)
  if not FISHING_SPELLS[spellId] then return end
  isFishing = true
  Statistics:RecordCast()
  Lures:CastStarted()

  applyGroup(groups.softTarget, SOFT_TARGET)
  enhanceSounds()
  if getSettings().hideNamePlates then
    outOfCombat("names", function() applyGroup(groups.names, HIDDEN_NAMES) end)
  end
  armKeys()
end

-- Any end of the channel while fishing ends it, some clients do not pass the spell here.
function handlers.UNIT_SPELLCAST_CHANNEL_STOP()
  if not isFishing then return end
  isFishing = false
  Statistics:RecordCastEnd()

  restoreGroup(groups.softTarget)
  scheduleSoundRestore()
  outOfCombat("names", function() restoreGroup(groups.names) end)
  armKeys()
end

--- Counts the catch in the statistics, once for each loot window.
local function countCatch()
  if isLootCounted or not IsFishingLoot() then return end
  isLootCounted = true
  Statistics:RecordCatch()
  Containers:NoteCatch()
end

--- Loots the whole catch, or a container opened by CatchIT, when the game itself does not loot it automatically.
function handlers.LOOT_READY(gameAutoLoots)
  countCatch()
  if gameAutoLoots or not getSettings().autoLoot then return end
  if not IsFishingLoot() and not Containers:JustOpened() then return end
  isAutoLooting = true
  for slot = GetNumLootItems(), 1, -1 do LootSlot(slot) end
end

function handlers.LOOT_OPENED()
  countCatch()
end

--- Confirms bind on pickup items of the catch, which the older clients ask about.
function handlers.LOOT_BIND_CONFIRM(slot)
  if not isAutoLooting then return end
  ConfirmLootSlot(slot)
  StaticPopup_Hide("LOOT_BIND")
end

function handlers.LOOT_CLOSED()
  isAutoLooting = false
  isLootCounted = false
end

--- Every CVar goes back to the player's value, the game saves them on logout. Logout also runs on a reload, which
--- keeps muted files but not this addon's memory of them, so they are unmuted all at once here.
function handlers.PLAYER_LOGOUT()
  cancelSoundTimer()
  for _, group in pairs(groups) do restoreGroup(group) end

  if soundFilesJob then soundFilesJob:Cancel() end
  if soundFilesDirty then
    for fileId = 1, LAST_SOUND_FILE do UnmuteSoundFile(fileId) end
    soundFilesMuted, soundFilesDirty = false, false
  end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...) handlers[event](...) end)
for event in pairs(handlers) do
  if event:find("^UNIT_") then
    eventFrame:RegisterUnitEvent(event, "player")
  else
    eventFrame:RegisterEvent(event)
  end
end

-- The lure runs out without an event, and bags and the pole change: the cast button follows each second.
C_Timer.NewTicker(1, function()
  Lures:Check()
  refreshCastButton()
end)

-- Turning an option off while it is active restores right away.
EventManager:On(E.StateUpdated, function(state)
  refreshCastButton()
  local settings = state.global.fishing
  if not settings.enhanceSounds then
    cancelSoundTimer()
    restoreSounds()
  elseif not settings.keepOnlyFishingSounds and soundFilesMuted then
    muteSoundFiles(false)
  end
  if not settings.hideNamePlates then
    outOfCombat("names", function() restoreGroup(groups.names) end)
  end
end)

-- ============================================================================
-- Fishing
-- ============================================================================

--- Returns `true` while the player channels a fishing spell.
--- @return boolean
function Fishing:IsFishing()
  return isFishing
end

--- Runs from the "Cast and Interact" and "Cast with Lure" bindings while their keys are not pointed yet (for example
--- right after the key was bound in combat), and from "Cast with Lure" while fishing, where it does nothing more.
--- From then on the keys cast and interact by themselves.
function CatchIT_Fishing_Run()
  armKeys()
end
