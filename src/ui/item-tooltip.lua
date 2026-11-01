local ADDON_NAME = ... ---@type string
local Addon = select(2, ...) ---@type Addon
local Colors = Addon:GetModule("Colors")
local Items = Addon:GetModule("Items")
local JunkFilter = Addon:GetModule("JunkFilter")
local L = Addon:GetModule("Locale")
local StateManager = Addon:GetModule("StateManager")

hooksecurefunc(GameTooltip, "SetBagItem", function(self, bag, slot)
  if not StateManager:GetGlobalState().itemTooltips or Items:IsBagSlotEmpty(bag, slot) then return end

  local item = Items:GetItem(bag, slot)
  if not item then return end

  -- Only items that will be destroyed get a tooltip section.
  local isDestroyJunk, destroyReason = JunkFilter:IsDestroyableJunkItem(item)
  if not isDestroyJunk then return end

  self:AddLine(" ")
  self:AddLine(Colors.Blue(ADDON_NAME))
  self:AddLine(Colors.Grey("  %s:"):format(Colors.Red(L.DESTROYING)))
  self:AddLine(Colors.Grey("  - ") .. Colors.White(destroyReason))

  self:Show()
end)
