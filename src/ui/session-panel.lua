-- A small panel of the current fishing session: shown from the first cast while the session runs, with a button that
-- ends it (so the next cast starts a new one without waiting for the pause of `Statistics.SESSION_GAP`). On and off in
-- the Interface tab (`global.sessionPanel`), dragged anywhere (`global.points.sessionPanel`).
local ADDON_NAME = ... ---@type string
local Addon = select(2, ...) ---@type Addon
local ActionCreators = Addon:GetModule("ActionCreators")
local Colors = Addon:GetModule("Colors")
local E = Addon:GetModule("Events")
local EventManager = Addon:GetModule("EventManager")
local L = Addon:GetModule("Locale")
local StateManager = Addon:GetModule("StateManager")
local Statistics = Addon:GetModule("Statistics")
local Widgets = Addon:GetModule("Widgets")

local WIDTH, HEIGHT = 260, 42

-- ============================================================================
-- Frames
-- ============================================================================

local frame = Widgets:Frame({
  name = ADDON_NAME .. "_SessionPanel",
  enableClickHandling = true,
  enableDragging = true,
  frameStrata = "LOW",
  width = WIDTH,
  height = HEIGHT
})
frame:SetBackdropColor(Colors.Backdrop:GetRGBA(0.85))
frame:Hide()

-- Shift+Right-Click puts it back to its default place.
frame:SetClickHandler("RightButton", "SHIFT", function()
  StateManager:Dispatch(ActionCreators.Global.points.sessionPanel.reset())
end)

Widgets:ConfigureForPointSync({
  frame = frame,
  getPoint = function() return StateManager:GetGlobalState().points.sessionPanel end,
  setPoint = function(point) StateManager:Dispatch(ActionCreators.Global.points.sessionPanel.set(point)) end
})

local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
title:SetPoint("TOPLEFT", Widgets:Padding(), -Widgets:Padding(0.75))
title:SetText(Colors.Blue(ADDON_NAME) .. Colors.Grey("  " .. L.SESSION))

local endButton = Widgets:Button({
  parent = frame,
  labelText = L.END_SESSION,
  labelColor = Colors.Red,
  onClick = function() Statistics:EndSession() end,
  onUpdateTooltip = function(_, tooltip)
    tooltip:SetText(L.END_SESSION)
    tooltip:AddLine(L.END_SESSION_DESCRIPTION, 1, 1, 1, true)
  end
})
endButton.label:SetFontObject("GameFontNormalSmall")
endButton:SetSize(48, 18)
endButton:SetPoint("TOPRIGHT", -Widgets:Padding(0.5), -Widgets:Padding(0.5))

local numbers = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
numbers:SetPoint("TOPLEFT", Widgets:Padding(), -Widgets:Padding(3))
numbers:SetPoint("RIGHT", -Widgets:Padding(), 0)
numbers:SetJustifyH("LEFT")
numbers:SetWordWrap(false)

--- The separator of the numbers: `||` is one `|` in the game, a single one starts an escape sequence.
local SEPARATOR = Colors.Grey("||")

-- ============================================================================
-- Refresh
-- ============================================================================

--- Shows the session that runs now, or hides the panel when none runs or it is turned off.
local function refresh()
  if not StateManager:GetStore() then return end
  local session = StateManager:GetGlobalState().sessionPanel and Statistics:GetCurrentSession()
  if not session then
    frame:Hide()
    return
  end

  local seconds = time() - session.start
  numbers:SetText(table.concat({
    Statistics:FormatDuration(seconds),
    Colors.Gold(session.casts) .. " " .. L.STAT_CASTS:lower(),
    Colors.Gold(session.catches) .. " " .. L.STAT_CATCHES:lower(),
    -- Up to the last cast or catch, like the Statistics tab: a pause at the end does not lower it.
    Statistics:PerHour(session.catches, session.last - session.start) .. " " .. L.STAT_PER_HOUR
  }, "  " .. SEPARATOR .. "  "))
  frame:Show()
end

C_Timer.NewTicker(1, refresh)
EventManager:On(E.StatisticsUpdated, refresh)
EventManager:On(E.StateUpdated, refresh)
