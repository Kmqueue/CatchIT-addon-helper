local ADDON_NAME = ... ---@type string
local Addon = select(2, ...) ---@type Addon
local Commands = Addon:GetModule("Commands")
local L = Addon:GetModule("Locale")
local Widgets = Addon:GetModule("Widgets")

local categoryFrame = Widgets:Frame({ name = "CatchITAddOnCategoryFrame" })

Widgets:Button({
  parent = categoryFrame,
  labelText = L.TOGGLE_MAIN_WINDOW,
  points = {
    { "TOPLEFT", categoryFrame, "TOPLEFT", Widgets:Padding(2), -Widgets:Padding(2) },
    { "TOPRIGHT", categoryFrame, "TOPRIGHT", -Widgets:Padding(2), -Widgets:Padding(2) }
  },
  onClick = Commands.options
})

local category = Settings.RegisterCanvasLayoutCategory(categoryFrame, ADDON_NAME)
category.ID = ADDON_NAME
Settings.RegisterAddOnCategory(category)
