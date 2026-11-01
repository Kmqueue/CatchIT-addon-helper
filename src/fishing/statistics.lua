-- Fishing statistics of CatchIT: the catches by location and fishing sessions. A
-- session lasts from the first cast to the last cast or catch; a pause of up to `SESSION_GAP` keeps it going. Saved in
-- `CatchITStatsDB`, by character, apart from the settings.
local Addon = select(2, ...) ---@type Addon
local E = Addon:GetModule("Events")
local EventManager = Addon:GetModule("EventManager")

--- @class Statistics
local Statistics = Addon:GetModule("Statistics")

--- Seconds without a cast or a catch after which the next cast starts a new session.
Statistics.SESSION_GAP = 5 * 60

--- Sessions kept for each character, the oldest are dropped.
local MAX_SESSIONS = 300

local LOOT_SLOT_ITEM = Enum.LootSlotType and Enum.LootSlotType.Item or LOOT_SLOT_ITEM or 1

-- ============================================================================
-- LuaCATS Annotations
-- ============================================================================

--- @class StatsSession
--- @field start integer `time()` of the first cast.
--- @field last integer `time()` of the last cast or catch.
--- @field casts integer
--- @field catches integer Loot windows of fishing, one per fish caught.
--- @field items table<string, integer> Quantity by item name.
--- @field ended? boolean Ended by the player (Session Panel), the next cast starts a new session.
--- @field zones table<string, StatsZone> The catches of the session by location, taken off the locations when the
--- session is reset.

--- @class StatsZone
--- @field count integer Catches.
--- @field items table<string, integer> Quantity by item name.

--- @class StatsLocation : StatsZone
--- @field lastAt integer `time()` of the last catch.

--- @class StatsCharacter
--- @field sessions StatsSession[] The oldest first.
--- @field locations table<string, StatsLocation>
--- @field quality table<string, integer> Quality by item name, for the colors.

-- ============================================================================
-- Local Functions
-- ============================================================================

--- Returns the statistics of the current character, created when missing.
--- @return StatsCharacter
local function getCharacter()
  if type(CatchITStatsDB) ~= "table" then CatchITStatsDB = {} end
  CatchITStatsDB.version = 1
  if type(CatchITStatsDB.characters) ~= "table" then CatchITStatsDB.characters = {} end

  local key = Addon:GetCharacterKey()
  local char = CatchITStatsDB.characters[key]
  if type(char) ~= "table" then
    char = {}
    CatchITStatsDB.characters[key] = char
  end
  if type(char.sessions) ~= "table" then char.sessions = {} end
  if type(char.locations) ~= "table" then char.locations = {} end
  if type(char.quality) ~= "table" then char.quality = {} end
  return char
end

--- Returns the location of the player: `"Zone - Subzone"`, or the zone alone.
--- @return string
local function getLocation()
  local zone = GetRealZoneText() or ""
  if zone == "" then zone = GetZoneText() or "" end
  if zone == "" then zone = UNKNOWN or "Unknown" end
  local subzone = GetSubZoneText() or ""
  if subzone ~= "" and subzone ~= zone then return zone .. " - " .. subzone end
  return zone
end

--- Returns the session the cast or catch of now belongs to: the last one, or a new one after a longer pause.
--- @return StatsSession
local function touchSession()
  local sessions = getCharacter().sessions
  local now = time()
  local session = sessions[#sessions]

  if not session or session.ended or now - session.last > Statistics.SESSION_GAP then
    session = { start = now, last = now, casts = 0, catches = 0, items = {}, zones = {} }
    sessions[#sessions + 1] = session
    while #sessions > MAX_SESSIONS do table.remove(sessions, 1) end
  end

  session.last = now
  return session
end

-- ============================================================================
-- Statistics
-- ============================================================================

--- Counts a cast of the fishing spell.
function Statistics:RecordCast()
  local session = touchSession()
  session.casts = session.casts + 1
  EventManager:Fire(E.StatisticsUpdated)
end

--- Keeps the session going at the end of a cast.
function Statistics:RecordCastEnd()
  local sessions = getCharacter().sessions
  local session = sessions[#sessions]
  if session and not session.ended and time() - session.last <= self.SESSION_GAP then session.last = time() end
end

--- Counts the catch in the open loot window of fishing. Call before the window is looted.
function Statistics:RecordCatch()
  local char = getCharacter()
  local session = touchSession()
  local zone = getLocation()

  local location = char.locations[zone]
  if type(location) ~= "table" then
    location = { count = 0, items = {} }
    char.locations[zone] = location
  end

  local sessionZone = session.zones[zone]
  if type(sessionZone) ~= "table" then
    sessionZone = { count = 0, items = {} }
    session.zones[zone] = sessionZone
  end

  session.catches = session.catches + 1
  sessionZone.count = sessionZone.count + 1
  location.count = location.count + 1
  location.lastAt = time()

  for slot = 1, GetNumLootItems() do
    if GetLootSlotType(slot) == LOOT_SLOT_ITEM then
      local _, name, quantity, _, quality = GetLootSlotInfo(slot)
      if type(name) == "string" and name ~= "" then
        quantity = tonumber(quantity) or 1
        session.items[name] = (session.items[name] or 0) + quantity
        sessionZone.items[name] = (sessionZone.items[name] or 0) + quantity
        location.items[name] = (location.items[name] or 0) + quantity
        if quality then char.quality[name] = quality end
      end
    end
  end

  EventManager:Fire(E.StatisticsUpdated)
end

--- Returns the statistics of the current character. Read only.
--- @return StatsCharacter
function Statistics:Get()
  return getCharacter()
end

--- Returns the session that runs now (the last cast or catch is less than `SESSION_GAP` ago), or `nil`.
--- @return StatsSession?
function Statistics:GetCurrentSession()
  local sessions = getCharacter().sessions
  local session = sessions[#sessions]
  if session and not session.ended and time() - session.last <= self.SESSION_GAP then return session end
end

--- Ends the session that runs now, the next cast starts a new one.
function Statistics:EndSession()
  local session = self:GetCurrentSession()
  if not session then return end
  session.ended = true
  EventManager:Fire(E.StatisticsUpdated)
end

--- `3725` -> `"1 h 02 min"`.
--- @param seconds number
--- @return string
function Statistics:FormatDuration(seconds)
  seconds = math.max(0, seconds)
  local hours, minutes = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
  if hours > 0 then return ("%d h %02d min"):format(hours, minutes) end
  return ("%d min"):format(minutes)
end

--- Catches per hour, `"-"` for less than a minute of fishing.
--- @param count integer
--- @param seconds number
--- @return string
function Statistics:PerHour(count, seconds)
  if seconds < 60 then return "-" end
  return tostring(math.floor(count * 3600 / seconds + 0.5))
end

--- The location of a session with the most catches, `"-"` before the first catch.
--- @param session StatsSession
--- @return string
function Statistics:GetMainZone(session)
  local best, bestCount = "-", 0
  for zone, sessionZone in pairs(session.zones) do
    if sessionZone.count > bestCount or (sessionZone.count == bestCount and zone < best) then
      best, bestCount = zone, sessionZone.count
    end
  end
  return best
end

--- Deletes the current session, or the last one, and takes its catches off the locations.
function Statistics:ResetSession()
  local char = getCharacter()
  local session = table.remove(char.sessions)
  if not session then return end

  for zone, sessionZone in pairs(session.zones) do
    local location = char.locations[zone]
    if type(location) == "table" and type(sessionZone) == "table" then
      location.count = location.count - sessionZone.count
      for name, quantity in pairs(sessionZone.items) do
        local left = (location.items[name] or 0) - quantity
        location.items[name] = left > 0 and left or nil
      end
      if location.count <= 0 then char.locations[zone] = nil end
    end
  end

  EventManager:Fire(E.StatisticsUpdated)
end

--- Deletes the statistics of the current character.
function Statistics:Reset()
  getCharacter()
  CatchITStatsDB.characters[Addon:GetCharacterKey()] = nil
  EventManager:Fire(E.StatisticsUpdated)
end
