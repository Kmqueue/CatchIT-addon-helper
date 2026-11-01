local ADDON_NAME = ... ---@type string
local Addon = select(2, ...) ---@type Addon
local ActionCreators = Addon:GetModule("ActionCreators")
local Colors = Addon:GetModule("Colors")
local ComponentFactory = Addon:GetModule("ComponentFactory")
local E = Addon:GetModule("Events")
local EventManager = Addon:GetModule("EventManager")
local L = Addon:GetModule("Locale")
local Lists = Addon:GetModule("Lists")
local MainWindowOptions = Addon:GetModule("MainWindowOptions")
local StateManager = Addon:GetModule("StateManager")
local Widgets = Addon:GetModule("Widgets")

--- @class MainWindow
local MainWindow = Addon:GetModule("MainWindow")

local NUM_LIST_FRAME_BUTTONS = 8

local Components = {}

-- ============================================================================
-- Controller
-- ============================================================================

local Controller = {
  --- Text the lists are filtered by.
  searchText = "",

  --- Tabs and the panels they show, by key.
  --- @type table<string, { row: SelectableRowComponent, panel: TitledPanelComponent }>
  tabs = {},

  --- Key of the selected tab.
  --- @type string?
  selectedTabKey = nil
}

--- Adds a tab to the tab row. The panel is created hidden.
--- @param options { key: string, labelText: string, createPanel: fun(): TitledPanelComponent }
function Controller:AddTab(options)
  local panel = Components.TabPanels:AttachComponent(options.createPanel())
  panel:SetVisibility("GONE")

  self.tabs[options.key] = {
    panel = panel,
    row = Components.TabRow:AttachComponent(ComponentFactory:SelectableRow({
      labelText = options.labelText,
      onClick = function() self:SelectTab(options.key) end
    })) --[[@as SelectableRowComponent]]
  }
end

--- Selects the tab and shows its panel, hiding the previous one.
--- @param key string
function Controller:SelectTab(key)
  if key == self.selectedTabKey then return end

  local previous = self.tabs[self.selectedTabKey]
  if previous then
    previous.row:SetSelected(false)
    previous.panel:SetVisibility("GONE")
  end

  self.tabs[key].row:SetSelected(true)
  self.tabs[key].panel:SetVisibility("VISIBLE")
  self.selectedTabKey = key
end

-- ============================================================================
-- Root Component
-- ============================================================================

Components.Root = ComponentFactory:Window({
  name = "MainWindow",
  width = 860,
  height = 600,
  titleText = "", -- unused; MainWindow builds its own title-bar content below
  getPoint = function() return StateManager:GetGlobalState().points.mainWindow end,
  setPoint = function(point) StateManager:Dispatch(ActionCreators.Global.points.mainWindow.set(point)) end,
  onResetPoint = function() StateManager:Dispatch(ActionCreators.Global.points.mainWindow.reset()) end,
  refresh = function() Components.Root:Layout() end
})

-- Clear the search whenever the window hides.
Components.Root:WhenFrameReady(function(frame)
  frame:HookScript("OnHide", function() Components.SearchBox:SetText("") end)
end)

-- Window()'s generic title text goes unused in favor of the title bar below.
Components.Root.TitleText:Detach()
Components.Root.TitleText = nil

-- ============================================================================
-- Title Bar Components
-- ============================================================================

Components.TitleBarNameText = Components.Root.TitleRow:AddRow()
Components.TitleBarNameText:AddChild({
  --- @param parent Frame
  frameFactory = function(parent)
    local fontString = parent:CreateFontString("$parent_TitleText", "ARTWORK", "GameFontNormalLarge")
    fontString:SetJustifyH("LEFT")
    fontString:SetText(Colors.Blue(ADDON_NAME))
    return fontString
  end
})

Components.TitleBarVersionText = Components.Root.TitleRow:AddRow({ justify = "CENTER" })
Components.TitleBarVersionText:AddChild({
  --- @param parent Frame
  frameFactory = function(parent)
    local fontString = parent:CreateFontString("$parent_VersionText", "ARTWORK", "GameFontNormalSmall")
    fontString:SetText(Colors.Grey(Addon.VERSION))
    return fontString
  end
})

-- ============================================================================
-- Title Bar Button Components
-- ============================================================================

Components.TitleBarButtonsRow = Components.Root.TitleRow:AddRow({ justify = "END" })

-- Reuse Window()'s close button, just moved into this row.
Components.TitleBarButtonsRow:AttachComponent(Components.Root.CloseButton:Detach())

-- ============================================================================
-- Main Screen Components
-- ============================================================================

Components.MainScreenRow = Components.Root:AddRow({ padding = Widgets:Padding() })

Components.Screen = Components.MainScreenRow:AddColumn({ gap = Widgets:Padding(0.5) })

-- Tabs: one panel is shown at a time, it fills the window below them.
Components.TabRow = Components.Screen:AddRow({ height = "AUTO", gap = Widgets:Padding(0.5) })
Components.TabPanels = Components.Screen:AddColumn()

--- Creates the panel of the Destroy List tab: the search box and the lists of items to destroy.
--- @return TitledPanelComponent panel
local function createDestroyListPanel()
  local panel = ComponentFactory:TitledPanel({ titleText = Colors.Blue(L.DESTROY_LIST), titleJustify = "LEFT" })
  local content = panel.Content
  content:SetGap(Widgets:Padding(0.5))

  -- Search box.
  Components.SearchBox = content:AttachComponent(ComponentFactory:TextInput({
    placeholderText = L.SEARCH_LISTS,
    fontObject = "GameFontNormal",
    onTextChanged = function(text) Controller.searchText = text end
  }))

  -- Escape clears the search.
  Components.SearchBox.Input:WhenFrameReady(function(editBox)
    editBox:SetScript("OnEscapePressed", function(self)
      self:SetText("")
      self:ClearFocus()
    end)
  end)

  -- Search button: clears the search and the focus.
  Components.SearchButton = Components.SearchBox:AttachComponent(ComponentFactory:IconButton({
    icon = Addon:GetAsset("search-icon"),
    highlightColor = Colors.Blue,
    onClick = function()
      Components.SearchBox:SetText("")
      Components.SearchBox.Input:GetFrame():ClearFocus()
    end,
    onUpdateTooltip = function(self, tooltip)
      if not self:GetEventValue("ENABLED") then return end
      tooltip:SetText(L.CLEAR_SEARCH)
    end
  }))

  -- The button follows the box. While the box is empty, the button is disabled and dimmed unless the box has
  -- focus, and the mouse passes through it to the box.
  Components.SearchButton:WhenFrameReady(function(button)
    --- @cast button IconButtonWidget
    button:PropagateWhenDisabled(true)

    Components.SearchBox.Input:WhenFrameReady(function(editBox)
      local box = Components.SearchBox:GetFrame() --- @type FrameWidget

      --- Shows the clear icon and enables the button while the box has text.
      local function refreshText()
        local hasText = editBox:GetText() ~= ""
        Components.SearchButton:SetIcon(Addon:GetAsset(hasText and "ban-icon" or "search-icon"))
        button:FireEvent("ENABLED", hasText)
      end

      --- Dims the button while it is disabled, unless the box has focus.
      local function refreshAlpha()
        local isEnabled = button:GetEventValue("ENABLED")
        button:SetAlpha((isEnabled or box:GetEventValue("FOCUSED")) and 1 or 0.4)
      end

      editBox:HookScript("OnTextChanged", refreshText)
      button:OnEvent("ENABLED", refreshAlpha)
      box:OnEvent("FOCUSED", refreshAlpha)

      refreshText()
    end)
  end)

  -- Lists row: the global list on the left, the list of this character on the right.
  content:AddRow({
    gap = Widgets:Padding(0.5),
    children = {
      {
        frameFactory = function(parent)
          return Widgets:ListFrame({
            parent = parent,
            name = "$parent_GlobalInclusionsFrame",
            numButtons = NUM_LIST_FRAME_BUTTONS,
            list = Lists.GlobalInclusions,
            getSearchText = function() return Controller.searchText end
          })
        end
      },
      {
        frameFactory = function(parent)
          return Widgets:ListFrame({
            parent = parent,
            name = "$parent_ProfileInclusionsFrame",
            numButtons = NUM_LIST_FRAME_BUTTONS,
            list = Lists.ProfileInclusions,
            getSearchText = function() return Controller.searchText end
          })
        end
      }
    }
  })

  return panel
end

Controller:AddTab({ key = "FISHING", labelText = L.FISHING, createPanel = function() return MainWindowOptions:CreateFishingPanel() end })
Controller:AddTab({ key = "INTERFACE", labelText = L.INTERFACE, createPanel = function() return MainWindowOptions:CreateInterfacePanel() end })
Controller:AddTab({ key = "DESTROY_LIST", labelText = L.DESTROY_LIST, createPanel = createDestroyListPanel })
Controller:AddTab({ key = "KEYBINDS", labelText = L.KEYBINDS, createPanel = function() return MainWindowOptions:CreateKeybindingsPanel() end })
Controller:AddTab({ key = "STATISTICS", labelText = L.STATISTICS, createPanel = function() return MainWindowOptions:CreateStatisticsPanel() end })
Controller:SelectTab("FISHING")

-- ============================================================================
-- Footer Components
-- ============================================================================

local footerRow = Components.Root:AddRow({
  height = 28,
  order = 10,
  frameFactory = function(parent)
    local frame = Widgets:Frame({ parent = parent })
    frame:SetBackdropColor(Colors.DarkGrey:GetRGB())
    return frame
  end
})

-- Character the profile list belongs to.
footerRow:AddRow({ paddingLeft = Widgets:Padding() }):AddChild({
  --- @param parent Frame
  frameFactory = function(parent)
    local fontString = parent:CreateFontString("$parent_ActiveProfileLabel", "ARTWORK", "GameFontNormal")
    fontString:SetJustifyH("LEFT")
    fontString:SetText(Colors.Grey(L.PROFILE_LIST_OWNER))
    return fontString
  end
})

footerRow:AddRow({ justify = "END", paddingRight = Widgets:Padding() }):AddChild({
  --- @param parent Frame
  frameFactory = function(parent)
    local fontString = parent:CreateFontString("$parent_ActiveProfileName", "ARTWORK", "GameFontNormal")
    fontString:SetJustifyH("RIGHT")
    fontString:SetText(Addon:GetCharacterKey())
    fontString:SetTextColor(Colors.Yellow:GetRGB())
    return fontString
  end
})

-- ============================================================================
-- MainWindow
-- ============================================================================

function MainWindow:Show()
  Components.Root:SetVisibility("VISIBLE")
  Components.Root:Layout()
end

function MainWindow:Hide()
  Components.Root:SetVisibility("GONE")
  Components.Root:Layout()
end

--- Shows the window with the tab `key` selected.
--- @param key string
function MainWindow:ShowTab(key)
  self:Show()
  Controller:SelectTab(key)
  Components.Root:Layout()
end

function MainWindow:Toggle()
  if Components.Root:IsVisible() then
    self:Hide()
  else
    self:Show()
  end
end

-- ============================================================================
-- Events
-- ============================================================================

-- Some elements of the UI do not appear correctly without an initial load,
-- so we force one here once the Wux store is ready.
EventManager:Once(E.StoreCreated, function()
  MainWindow:Show()
  for key in pairs(Controller.tabs) do
    Controller:SelectTab(key)
    Components.Root:Layout()
  end
  Controller:SelectTab("FISHING")
  MainWindow:Hide()
end)
