-- Foods of CatchIT: which fishing food the "Eat Food" key eats. Eaten for 10 s, each of them makes the player well fed
-- with more fishing skill (for 15 minutes or longer, depending on the legacy points). Settings live in the CatchIT
-- store (`global.fishing.autoFood`, `global.fishing.food`, `global.fishing.wellFedMinutes`).
local Addon = select(2, ...) ---@type Addon
local DefaultStates = Addon:GetModule("DefaultStates")
local StateManager = Addon:GetModule("StateManager")

--- @class Foods
local Foods = Addon:GetModule("Foods")

--- Fishing foods, the best first: `bonus` is the fishing skill of the well fed buff, `level` the level needed to eat
--- it. `name` is shown while the game does not know the item yet.
Foods.LIST = {
  { id = 8957, bonus = 18, level = 45, name = "Spinefin Halibut" },
  { id = 13930, bonus = 18, level = 35, name = "Filet of Redgill" },
  { id = 4594, bonus = 12, level = 25, name = "Rockscale Cod" },
  { id = 4593, bonus = 8, level = 15, name = "Bristle Whisker Catfish" },
  { id = 5476, bonus = 5, level = 5, name = "Fillet of Frenzy" },
  { id = 6316, bonus = 3, level = 5, name = "Loch Frenzy Delight" }
}

--- A "Well Fed" buff, only for its localized name.
local WELL_FED_SPELL_ID = 19705

local GetItemCount = C_Item and C_Item.GetItemCount or GetItemCount
local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo

-- ============================================================================
-- Local Functions
-- ============================================================================

--- @return FishingState
local function getSettings()
  if StateManager:GetStore() then return StateManager:GetGlobalState().fishing end
  return DefaultStates.Global.fishing
end

--- Returns the name and the expiration time (`GetTime()` seconds, 0 when it does not end) of a buff of the player,
--- `nil` past the last one.
--- @param index integer
--- @return string? name
--- @return number? expirationTime
local function getBuff(index)
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
    if aura then return aura.name, aura.expirationTime end
    return nil
  end
  local name, _, _, _, _, expirationTime = UnitBuff("player", index)
  return name, expirationTime
end

-- ============================================================================
-- Foods
-- ============================================================================

--- Returns the name of a food, as the game shows it when it knows the item.
--- @param itemId integer
--- @return string
function Foods:GetName(itemId)
  local name = GetItemInfo(itemId)
  if name then return name end
  for _, food in ipairs(self.LIST) do
    if food.id == itemId then return food.name end
  end
  return tostring(itemId)
end

--- Returns the seconds the player stays well fed (any "Well Fed" buff, also of a food that is not for fishing), `0`
--- when not well fed.
--- @return number
function Foods:GetWellFedSecondsLeft()
  local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(WELL_FED_SPELL_ID)
    or GetSpellInfo and GetSpellInfo(WELL_FED_SPELL_ID)
  local wellFedName = spellName or "Well Fed"
  for index = 1, 40 do
    local name, expirationTime = getBuff(index)
    if not name then break end
    if name == wellFedName then
      if not expirationTime or expirationTime == 0 then return math.huge end
      return math.max(expirationTime - GetTime(), 0)
    end
  end
  return 0
end

--- Returns `true` while the player is well fed for longer than `wellFedMinutes` (a setting, `0` = always eat), so no
--- food is eaten. The CatchIT app eats 30 s before the buff runs out, a pause and a new start do not eat again.
--- @return boolean
function Foods:IsWellFed()
  local minutes = tonumber(getSettings().wellFedMinutes) or 0
  return minutes > 0 and self:GetWellFedSecondsLeft() > minutes * 60
end

--- Returns the item ID of the food the "Eat Food" key eats, or `nil` when it does nothing: "Eat Food" is off, the
--- player is still well fed for a while, or no wanted food the player can eat (level) is in the bags. "Best" takes the
--- highest bonus.
--- @return integer? itemId
function Foods:GetFoodToEat()
  local settings = getSettings()
  if not settings.autoFood or self:IsWellFed() then return nil end

  local wanted = tonumber(settings.food)
  local level = UnitLevel("player") or 0
  for _, food in ipairs(self.LIST) do
    if (not wanted or wanted == food.id) and level >= food.level and (GetItemCount(food.id) or 0) > 0 then
      return food.id
    end
  end
end
