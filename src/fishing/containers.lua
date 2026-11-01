-- Opens clams and other containers of the bags that open at once, without a cast, and Auto Loot loots them: only the
-- ones caught by fishing or all of them (`global.fishing.openContainers`, under `autoLoot`). The items caught by fishing are kept in `CatchITStatsDB.fishedItems`, for every character.
local Addon = select(2, ...) ---@type Addon
local Fishing = Addon:GetModule("Fishing")
local StateManager = Addon:GetModule("StateManager")

--- @class Containers
local Containers = Addon:GetModule("Containers")

--- Clams, opened as caught ones also before they were seen in a catch, and when the game does not mark them as
--- lootable.
local CLAMS = {
  [5523] = true, -- Small Barnacled Clam
  [5524] = true, -- Thick-shelled Clam
  [7973] = true, -- Big-mouth Clam
  [15874] = true, -- Soft-shelled Clam
  [24476] = true -- Jaggal Clam
}

--- Seconds a loot window counts as the loot of a container opened here, see `JustOpened()`.
local LOOT_SECONDS = 2

local NUM_BAGS = NUM_BAG_SLOTS or 4
local GetItemSpell = C_Item and C_Item.GetItemSpell or GetItemSpell

--- `true` while a loot window is open.
local isLooting = false

--- When a container was opened last (`GetTime()`).
local openedAt = 0

--- Hidden tooltip that reads whether a container is locked.
local scanTooltip = CreateFrame("GameTooltip", "CatchITScanTooltip", nil, "GameTooltipTemplate")

-- ============================================================================
-- Local Functions
-- ============================================================================

--- Returns `true` when the tooltip of the item says it is locked (a lockbox).
--- @param bag integer
--- @param slot integer
--- @return boolean
local function isLockedBox(bag, slot)
  scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
  scanTooltip:SetBagItem(bag, slot)
  for line = 1, scanTooltip:NumLines() do
    local text = _G["CatchITScanTooltipTextLeft" .. line]
    if text and text:GetText() == LOCKED then
      scanTooltip:Hide()
      return true
    end
  end
  scanTooltip:Hide()
  return false
end

--- Returns the item IDs caught by fishing, created when missing.
--- @return table<integer, boolean>
local function getFishedItems()
  if type(CatchITStatsDB) ~= "table" then CatchITStatsDB = {} end
  if type(CatchITStatsDB.fishedItems) ~= "table" then CatchITStatsDB.fishedItems = {} end
  return CatchITStatsDB.fishedItems
end

--- Returns `true` when the item in the slot can be opened here: a clam, or a lootable item that is not locked and has no
--- use spell (an item with one opens with a cast). With `caughtOnly` only clams and items caught by fishing.
--- @param bag integer
--- @param slot integer
--- @param itemId integer
--- @param caughtOnly boolean
--- @return boolean
local function canOpen(bag, slot, itemId, caughtOnly)
  if CLAMS[itemId] then return true end
  if caughtOnly and not getFishedItems()[itemId] then return false end
  local info = C_Container.GetContainerItemInfo(bag, slot)
  if not info or not info.hasLoot or info.isLocked then return false end
  if GetItemSpell(itemId) then return false end
  return not isLockedBox(bag, slot)
end

--- Returns `true` while the bags have a free slot for the loot.
--- @return boolean
local function hasFreeSlot()
  for bag = 0, NUM_BAGS do
    if (C_Container.GetContainerNumFreeSlots(bag) or 0) > 0 then return true end
  end
  return false
end

--- Opens the first container of the bags. One at a time: the next one opens when the bags change or the loot closes.
local function openNext()
  if not StateManager:GetStore() then return end
  local settings = StateManager:GetGlobalState().fishing
  if not settings.autoLoot or settings.openContainers == "off" then return end
  local caughtOnly = settings.openContainers ~= "all"
  if isLooting or InCombatLockdown() or Fishing:IsFishing() then return end
  if UnitCastingInfo("player") or UnitChannelInfo("player") or not hasFreeSlot() then return end

  for bag = 0, NUM_BAGS do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local itemId = C_Container.GetContainerItemID(bag, slot)
      if itemId and canOpen(bag, slot, itemId, caughtOnly) then
        openedAt = GetTime()
        C_Container.UseContainerItem(bag, slot)
        return
      end
    end
  end
end

-- ============================================================================
-- Events
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event)
  if event == "LOOT_OPENED" then
    isLooting = true
    return
  end
  if event == "LOOT_CLOSED" then isLooting = false end
  -- The loot window closes before the bags change, so the next container waits a moment.
  C_Timer.After(0.3, openNext)
end)

-- ============================================================================
-- Containers
-- ============================================================================

--- Remembers the items of the open loot window of fishing, so they can be opened as caught ones.
function Containers:NoteCatch()
  local fishedItems = getFishedItems()
  for slot = 1, GetNumLootItems() do
    local link = GetLootSlotLink(slot)
    local itemId = link and GetItemInfoFromHyperlink(link)
    if itemId then fishedItems[itemId] = true end
  end
end

--- Returns `true` when the open loot window is the loot of a container opened here.
--- @return boolean
function Containers:JustOpened()
  return GetTime() - openedAt < LOOT_SECONDS
end
