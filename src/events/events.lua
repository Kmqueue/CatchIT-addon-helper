local _, Addon = ...
local E = Addon:GetModule("Events") ---@class Events

-- ============================================================================
-- CatchIT Events
-- ============================================================================

E.ActiveProfileChanged = "CatchIT_ActiveProfileChanged"
E.AttemptedToDestroyItem = "CatchIT_AttemptedToDestroyItem"
E.BagsUpdated = "CatchIT_BagsUpdated"
E.GameBindingsChanged = "CatchIT_GameBindingsChanged"
E.KeybindingBound = "CatchIT_KeybindingBound"
E.KeybindingListeningChanged = "CatchIT_KeybindingListeningChanged"
E.ListItemCannotBeParsed = "CatchIT_ListItemCannotBeParsed"
E.ListItemFailedToParse = "CatchIT_ListItemFailedToParse"
E.ListItemParsed = "CatchIT_ListItemParsed"
E.StateUpdated = "CatchIT_StateUpdated"
E.StatisticsUpdated = "CatchIT_StatisticsUpdated"
E.StoreCreated = "CatchIT_StoreCreated"

-- ============================================================================
-- WoW Events
-- ============================================================================

E.Wow = {
  BagUpdate = "BAG_UPDATE",
  BagUpdateDelayed = "BAG_UPDATE_DELAYED",
  ItemLocked = "ITEM_LOCKED",
  ItemUnlocked = "ITEM_UNLOCKED",
  PlayerLogin = "PLAYER_LOGIN"
}
