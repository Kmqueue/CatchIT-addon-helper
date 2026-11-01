-- Lures of CatchIT: which lure the cast keys put on the fishing pole before they cast. Settings live in the CatchIT
-- store (`global.fishing.autoLure`, `global.fishing.lure`).
local Addon = select(2, ...) ---@type Addon
local DefaultStates = Addon:GetModule("DefaultStates")
local StateManager = Addon:GetModule("StateManager")

--- @class Lures
local Lures = Addon:GetModule("Lures")

--- Lures of the classic clients, the best first. `name` is shown while the game does not know the item yet.
Lures.LIST = {
  { id = 6533, bonus = 100, name = "Aquadynamic Fish Attractor" },
  { id = 34861, bonus = 100, name = "Sharpened Fish Hook" },
  { id = 46006, bonus = 100, name = "Glow Worm" },
  { id = 6532, bonus = 75, name = "Bright Baubles" },
  { id = 7307, bonus = 75, name = "Flesh Eating Worm" },
  { id = 6530, bonus = 50, name = "Nightcrawlers" },
  { id = 6811, bonus = 50, name = "Aquadynamic Fish Lens" },
  { id = 6529, bonus = 25, name = "Shiny Bauble" }
}

--- Seconds after a lure was used until it must be on the pole or being put on (its cast), otherwise it did not get on:
--- the player stopped it, or it cannot be used (for example it needs more fishing skill).
local APPLY_SECONDS = 2

local GetItemCount = C_Item and C_Item.GetItemCount or GetItemCount
local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant

--- `true` after a lure did not get on the pole: the next press casts without one, and the cast after it tries the lure
--- again (see `CastStarted()`), so a lure never keeps the keys from casting.
local skipOnce = false

--- The lure used last, until it is on the pole or skipped.
--- @type { id: integer, at: number }?
local pending = nil

-- ============================================================================
-- Local Functions
-- ============================================================================

--- @return FishingState
local function getSettings()
  if StateManager:GetStore() then return StateManager:GetGlobalState().fishing end
  return DefaultStates.Global.fishing
end

--- Returns `true` while a lure (any enchant) is on the main hand.
--- @return boolean
local function hasLure()
  return GetWeaponEnchantInfo() and true or false
end

-- ============================================================================
-- Lures
-- ============================================================================

--- Returns the name of a lure, as the game shows it when it knows the item.
--- @param itemId integer
--- @return string
function Lures:GetName(itemId)
  local name = GetItemInfo(itemId)
  if name then return name end
  for _, lure in ipairs(self.LIST) do
    if lure.id == itemId then return lure.name end
  end
  return tostring(itemId)
end

--- Returns `true` while a fishing pole is in the main hand. Retail has no lures on the pole, it never has one there.
--- @return boolean
function Lures:IsPoleEquipped()
  local itemId = GetInventoryItemID("player", INVSLOT_MAINHAND or 16)
  if not itemId then return false end
  local _, _, _, _, _, classId, subclassId = GetItemInfoInstant(itemId)
  return classId == 2 and subclassId == 20 -- Weapon, Fishing Pole
end

--- Returns the item ID of the lure the next cast key press puts on the pole, or `nil` when it casts: "Apply Lure" is
--- off, a lure is already on, no pole is equipped, or no wanted lure is in the bags.
--- @return integer? itemId
function Lures:GetLureToApply()
  local settings = getSettings()
  if skipOnce or not settings.autoLure or not self:IsPoleEquipped() or hasLure() then return nil end

  local wanted = tonumber(settings.lure)
  for _, lure in ipairs(self.LIST) do
    if (not wanted or wanted == lure.id) and (GetItemCount(lure.id) or 0) > 0 then
      return lure.id
    end
  end
end

--- Remembers that a lure was used by a cast key, see `Check()`.
--- @param itemId integer
function Lures:Used(itemId)
  pending = { id = itemId, at = GetTime() }
end

--- Checks the lure used last: done once it is on the pole; when it is not there in time and not being put on, the
--- next press casts without it. Returns `true` when something changed, so the cast button is set again.
--- @return boolean
function Lures:Check()
  if not pending then return false end
  if hasLure() then
    pending = nil
    return true
  end
  if GetTime() - pending.at < APPLY_SECONDS or UnitCastingInfo("player") then return false end

  skipOnce = true
  pending = nil
  return true
end

--- A fishing cast started: the next cast puts the lure on again when one is due.
function Lures:CastStarted()
  skipOnce = false
end
