local Addon = select(2, ...) ---@type Addon
local Colors = Addon:GetModule("Colors")
local ComponentFactory = Addon:GetModule("ComponentFactory")
local E = Addon:GetModule("Events")
local EventManager = Addon:GetModule("EventManager")
local L = Addon:GetModule("Locale")
local OptionsBuilder = Addon:GetModule("OptionsBuilder")
local Statistics = Addon:GetModule("Statistics")
local Widgets = Addon:GetModule("Widgets")

--- @class MainWindowOptions
local MainWindowOptions = Addon:GetModule("MainWindowOptions")

--- Sessions and locations listed, the newest and the most caught first.
local MAX_ROWS = 15

--- Items named for a session or a location.
local TOP_ITEMS = 3

-- ============================================================================
-- Local Functions
-- ============================================================================

--- @param seconds number
--- @return string
local function formatDuration(seconds)
  return Statistics:FormatDuration(seconds)
end

--- @param count integer
--- @param seconds number
--- @return string
local function perHour(count, seconds)
  return Statistics:PerHour(count, seconds)
end

--- A line `Label: value`.
--- @param label string
--- @param value string|number
--- @return string
local function line(label, value)
  return Colors.Grey(label .. ": ") .. Colors.White(tostring(value))
end

--- Returns the keys of `counts`, the highest count first.
--- @param counts table<string, integer>
--- @return string[]
local function sortedKeys(counts)
  local keys = {}
  for key in pairs(counts) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b)
    if counts[a] ~= counts[b] then return counts[a] > counts[b] end
    return a < b
  end)
  return keys
end

--- The items caught most, in the colors of their quality: `"Raw Brilliant Smallfish x12, ..."`.
--- @param char StatsCharacter
--- @param items table<string, integer>
--- @return string
local function topItems(char, items)
  local parts = {}
  for i, name in ipairs(sortedKeys(items)) do
    if i > TOP_ITEMS then break end
    local color = Colors.ByQuality[char.quality[name] or -1] or Colors.White
    parts[#parts + 1] = color(name) .. Colors.Grey(" x" .. items[name])
  end
  return #parts > 0 and table.concat(parts, Colors.Grey(", ")) or "-"
end

--- The location of a session with the most catches.
--- @param session StatsSession
--- @return string
local function mainZone(session)
  return Statistics:GetMainZone(session)
end

--- The text of the current session, or of the last one.
--- @param char StatsCharacter
--- @return string
local function sessionText(char)
  local session = char.sessions[#char.sessions]
  if not session then return Colors.Grey(L.NO_STATISTICS) end

  local seconds = session.last - session.start
  return table.concat({
    Colors.Gold(Statistics:GetCurrentSession() and L.CURRENT_SESSION or L.LAST_SESSION),
    line(L.STAT_DATE, date("%d %b %Y", session.start)),
    line(L.STAT_TIME, ("%s - %s (%s)"):format(date("%H:%M", session.start), date("%H:%M", session.last),
      formatDuration(seconds))),
    line(L.STAT_CATCHES, ("%d (%s %s)"):format(session.catches, perHour(session.catches, seconds), L.STAT_PER_HOUR)),
    line(L.STAT_CASTS, session.casts),
    line(L.STAT_LOCATION, mainZone(session)),
    line(L.STAT_TOP_ITEMS, topItems(char, session.items))
  }, "|n")
end

--- The text of all sessions together.
--- @param char StatsCharacter
--- @return string
local function allTimeText(char)
  local seconds, catches, casts = 0, 0, 0
  for _, session in ipairs(char.sessions) do
    seconds = seconds + session.last - session.start
    catches = catches + session.catches
    casts = casts + session.casts
  end

  return table.concat({
    line(L.STAT_SESSIONS, #char.sessions),
    line(L.STAT_FISHING_TIME, formatDuration(seconds)),
    line(L.STAT_CATCHES, ("%d (%s %s)"):format(catches, perHour(catches, seconds), L.STAT_PER_HOUR)),
    line(L.STAT_CASTS, casts)
  }, "|n")
end

--- One line for each session, the newest first.
--- @param char StatsCharacter
--- @return string
local function sessionsText(char)
  local lines = {}
  for i = #char.sessions, math.max(1, #char.sessions - MAX_ROWS + 1), -1 do
    local session = char.sessions[i]
    lines[#lines + 1] = ("%s  %s  %s  %s"):format(
      Colors.White(date("%d %b %Y  %H:%M", session.start) .. " - " .. date("%H:%M", session.last)),
      Colors.Grey(formatDuration(session.last - session.start)),
      Colors.Gold(session.catches .. " " .. L.STAT_CATCHES:lower()),
      Colors.Grey(mainZone(session))
    )
  end
  return #lines > 0 and table.concat(lines, "|n") or Colors.Grey(L.NO_STATISTICS)
end

--- One line for each location, the most caught first.
--- @param char StatsCharacter
--- @return string
local function locationsText(char)
  local counts = {}
  for zone, location in pairs(char.locations) do counts[zone] = location.count end

  local lines = {}
  for i, zone in ipairs(sortedKeys(counts)) do
    if i > MAX_ROWS then break end
    lines[#lines + 1] = ("%s  %s  %s"):format(
      Colors.White(zone),
      Colors.Gold(counts[zone] .. " " .. L.STAT_CATCHES:lower()),
      topItems(char, char.locations[zone].items)
    )
  end
  return #lines > 0 and table.concat(lines, "|n") or Colors.Grey(L.NO_STATISTICS)
end

-- Ask before the statistics are deleted.
StaticPopupDialogs.CATCHIT_RESET_SESSION = {
  text = L.RESET_SESSION_CONFIRM,
  button1 = YES,
  button2 = NO,
  OnAccept = function() Statistics:ResetSession() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3
}

StaticPopupDialogs.CATCHIT_RESET_STATISTICS = {
  text = L.RESET_STATISTICS_CONFIRM,
  button1 = YES,
  button2 = NO,
  OnAccept = function() Statistics:Reset() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3
}

-- ============================================================================
-- MainWindowOptions - Tabs
-- ============================================================================

--- Creates the panel of fishing statistics.
--- @return TitledPanelComponent panel
function MainWindowOptions:CreateStatisticsPanel()
  local panel, container = OptionsBuilder:CreatePanel({
    titleText = Colors.Blue(L.STATISTICS),
    titleJustify = "LEFT",
    descriptionText = L.STATISTICS_NOTE
  })

  --- The texts of the groups and what fills them.
  --- @type { text: WaffleFlexComponent, build: fun(char: StatsCharacter): string }[]
  local sections = {}

  --- Adds a group with one text.
  --- @param headingText string
  --- @param build fun(char: StatsCharacter): string
  local function addSection(headingText, build)
    local group = OptionsBuilder:AddGroup(container, headingText)
    sections[#sections + 1] = { text = group:AttachComponent(ComponentFactory:Text({ text = " " })), build = build }
  end

  addSection(L.SESSION, sessionText)
  addSection(L.ALL_TIME, allTimeText)
  addSection(L.SESSIONS, sessionsText)
  addSection(L.LOCATIONS, locationsText)

  -- Below the scrolled statistics: the buttons that delete all of them (left, away from the other one) or the session.
  local footer = panel.Content:AddRow({
    height = "AUTO",
    justify = "SPACE_BETWEEN",
    marginTop = Widgets:Padding()
  })
  for _, reset in ipairs({
    { text = L.RESET_ALL, popup = "CATCHIT_RESET_STATISTICS" },
    { text = L.RESET_SESSION, popup = "CATCHIT_RESET_SESSION" }
  }) do
    footer:AddChild({
      width = 150,
      height = 28,
      frameFactory = function(parent)
        return Widgets:Button({
          parent = parent,
          labelText = reset.text,
          labelColor = Colors.Red,
          onClick = function() StaticPopup_Show(reset.popup) end
        })
      end
    })
  end

  --- Fills the texts again.
  local function refresh()
    local char = Statistics:Get()
    for _, section in ipairs(sections) do
      local text = section.build(char)
      section.text:WhenFrameReady(function(fontString) fontString:SetText(text) end)
      section.text:MarkDirty()
    end
  end

  panel:WhenFrameReady(function(frame)
    frame:HookScript("OnShow", refresh)
    EventManager:On(E.StatisticsUpdated, function()
      if frame:IsVisible() then refresh() end
    end)
  end)

  return panel
end
