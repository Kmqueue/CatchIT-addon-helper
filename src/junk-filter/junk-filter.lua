local Addon = select(2, ...) ---@type Addon
local Items = Addon:GetModule("Items")
local L = Addon:GetModule("Locale")
local Lists = Addon:GetModule("Lists")

--- @class JunkFilter
local JunkFilter = Addon:GetModule("JunkFilter")

-- ============================================================================
-- Local Functions
-- ============================================================================

--- Comparison function for sorting items by quality and name, so the order of destruction is stable.
--- @param a BagItem
--- @param b BagItem
--- @return boolean
local function itemSortFunc(a, b)
  if a.quality == b.quality then
    if a.name == b.name then
      if a.bag == b.bag then return a.slot < b.slot end
      return a.bag < b.bag
    end
    return a.name < b.name
  end
  return a.quality < b.quality
end

-- ============================================================================
-- JunkFilter
-- ============================================================================

--- Creates or updates an array of the items that will be destroyed. Only items on the global or the profile
--- inclusions list are ever returned.
--- @param items? BagItem[]
--- @return BagItem[] destroyableItems
function JunkFilter:GetDestroyableJunkItems(items)
  items = Items:GetItems(items)

  for i = #items, 1, -1 do
    local isJunk, reason = self:IsDestroyableJunkItem(items[i])

    if isJunk then
      items[i].reason = reason
    else
      table.remove(items, i)
    end
  end

  table.sort(items, itemSortFunc)

  return items
end

do
  local items = {}

  --- Returns the number of items that will be destroyed.
  --- @return integer numDestroyable
  function JunkFilter:GetNumDestroyableJunkItems()
    return #self:GetDestroyableJunkItems(items)
  end

  --- Returns the next item to destroy if one exists.
  --- @return BagItem|nil
  function JunkFilter:GetNextDestroyableJunkItem()
    self:GetDestroyableJunkItems(items)
    return items[1]
  end
end

--- Returns `true` and a reason string if the given `item` is on an inclusions list and can be destroyed. This is
--- the only rule: an item that is on no list is never destroyed.
--- @param item BagItem
--- @return boolean isDestroyableJunk, string? reason
function JunkFilter:IsDestroyableJunkItem(item)
  if not Items:IsItemStillInBags(item) then
    return false
  end

  if not Items:IsItemDestroyable(item) then
    return false, L.ITEM_CANNOT_BE_DESTROYED
  end

  if Items:IsItemLocked(item) then
    return false, L.ITEM_IS_LOCKED
  end

  if Lists.ProfileInclusions:Contains(item.id) then
    return true, L.ITEM_IS_ON_LIST:format(Lists.ProfileInclusions.name)
  end

  if Lists.GlobalInclusions:Contains(item.id) then
    return true, L.ITEM_IS_ON_LIST:format(Lists.GlobalInclusions.name)
  end

  return false, L.ITEM_IS_ON_NO_LIST
end
