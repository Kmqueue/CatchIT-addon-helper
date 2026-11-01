local Addon = select(2, ...) ---@type Addon
local E = Addon:GetModule("Events")
local EventManager = Addon:GetModule("EventManager")
local Items = Addon:GetModule("Items")
local JunkFilter = Addon:GetModule("JunkFilter")
local L = Addon:GetModule("Locale")

--- @class Destroyer
local Destroyer = Addon:GetModule("Destroyer")

-- ============================================================================
-- Local Functions
-- ============================================================================

--- Destroys `item` without asking, as if Safe Destroy was always off. Does nothing if `item` is no longer in the
--- bags, is locked, or is not on an inclusions list, so nothing outside the lists can ever be destroyed.
--- @param item BagItem
local function destroy(item)
  if not Items:IsItemStillInBags(item) then return end
  if Items:IsItemLocked(item) then return end
  if not JunkFilter:IsDestroyableJunkItem(item) then return end

  ClearCursor()
  C_Container.PickupContainerItem(item.bag, item.slot)
  DeleteCursorItem()
  EventManager:Fire(E.AttemptedToDestroyItem, item)
end

-- ============================================================================
-- Destroyer
-- ============================================================================

--- Destroys the next item on an inclusions list found in the bags.
function Destroyer:Start()
  local item = JunkFilter:GetNextDestroyableJunkItem()
  if not item then return Addon:Print(L.NO_JUNK_ITEMS_TO_DESTROY) end
  destroy(item)
end
