local Addon = select(2, ...) ---@type Addon
local Commands = Addon:GetModule("Commands")

--- Referenced via `AddonCompartmentFunc` in the TOC.
CatchIT_OnAddonCompartmentClick = Commands.options
