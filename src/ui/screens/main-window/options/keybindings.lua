local Addon = select(2, ...) ---@type Addon
local B = Addon:GetModule("Blizzard")
local Colors = Addon:GetModule("Colors")
local ComponentFactory = Addon:GetModule("ComponentFactory")
local Widgets = Addon:GetModule("Widgets")
local DefaultStates = Addon:GetModule("DefaultStates")
local E = Addon:GetModule("Events")
local EventManager = Addon:GetModule("EventManager")
local Keybindings = Addon:GetModule("Keybindings")
local L = Addon:GetModule("Locale")
local Lists = Addon:GetModule("Lists")
local Lures = Addon:GetModule("Lures")
local ActionCreators = Addon:GetModule("ActionCreators")
local MinimapIcon = Addon:GetModule("MinimapIcon")
local StateManager = Addon:GetModule("StateManager")
local OptionsBuilder = Addon:GetModule("OptionsBuilder")
local TickerManager = Addon:GetModule("TickerManager")

--- @class MainWindowOptions
local MainWindowOptions = Addon:GetModule("MainWindowOptions")

--- Labels of the bindings that have a card, by binding name.
--- @type table<BindingName, string>
local labels = {}

-- ============================================================================
-- Local Functions
-- ============================================================================

--- Adds a card to `group` for the key of a binding.
--- @param group OptionsBuilderGroup
--- @param footer OptionsBuilderMessageFooter
--- @param bindingName BindingName
--- @param labelText string
--- @param descriptionText? string
local function addKeybindingCard(group, footer, bindingName, labelText, descriptionText)
  labels[bindingName] = labelText

  group:AddKeybindingCard({
    labelText = labelText,
    descriptionText = descriptionText,
    get = function()
      local key = Keybindings:GetKey(bindingName)
      if key ~= DefaultStates.UNBOUND_KEY then return B.Bindings:GetKeyText(key) end
    end,
    isListening = function()
      return Keybindings:GetListeningBindingName() == bindingName
    end,
    onClick = function(mouseButton)
      if mouseButton == "LeftButton" then
        if Keybindings:GetListeningBindingName() == bindingName then
          Keybindings:StopListening()
        else
          Keybindings:StartListening(bindingName)
        end
      elseif mouseButton == "RightButton" then
        if Keybindings:GetKey(bindingName) ~= DefaultStates.UNBOUND_KEY then
          Keybindings:RemoveKey(bindingName)
          footer:SetMessage(nil)
        end
      else
        Keybindings:ProcessInput(mouseButton)
      end
    end
  })
end

-- ============================================================================
-- MainWindowOptions - Tabs
-- ============================================================================

--- Creates the panel of fishing settings.
--- @return TitledPanelComponent panel
function MainWindowOptions:CreateFishingPanel()
  local panel, container = OptionsBuilder:CreatePanel({
    titleText = Colors.Blue(L.FISHING),
    titleJustify = "LEFT"
  })

  -- Fishing.
  local fishing = OptionsBuilder:AddGroup(container, L.FISHING)

  --- Patches the fishing settings.
  --- @param patch table<string, any>
  local function patchFishing(patch)
    StateManager:Dispatch(ActionCreators.Global.patchFishing(patch))
  end

  local autoLootCard = fishing:AddOptionCard({
    labelText = L.AUTO_LOOT_TEXT,
    descriptionText = L.AUTO_LOOT_DESCRIPTION,
    get = function() return StateManager:GetGlobalState().fishing.autoLoot end,
    set = function(value) patchFishing({ autoLoot = value }) end
  })

  -- Opens the caught clams and containers, or all containers of the bags, and loots them.
  autoLootCard:AddSettingsBox():AddChoiceLine(
    L.OPEN_CONTAINERS_LINE,
    {
      { value = "off", text = L.OPEN_CONTAINERS_OFF },
      { value = "caught", text = L.OPEN_CONTAINERS_TEXT, tooltipText = L.OPEN_CONTAINERS_DESCRIPTION },
      { value = "all", text = L.OPEN_ALL_CONTAINERS_TEXT, tooltipText = L.OPEN_ALL_CONTAINERS_DESCRIPTION }
    },
    function() return StateManager:GetGlobalState().fishing.openContainers end,
    function(value) patchFishing({ openContainers = value }) end
  )

  local lureCard = fishing:AddOptionCard({
    labelText = L.AUTO_LURE_TEXT,
    descriptionText = L.AUTO_LURE_DESCRIPTION,
    get = function() return StateManager:GetGlobalState().fishing.autoLure end,
    set = function(value) patchFishing({ autoLure = value }) end
  })
  local lureChoices = { { value = "best", text = L.BEST_LURE, tooltipText = L.BEST_LURE_DESCRIPTION } }
  for _, lure in ipairs(Lures.LIST) do
    lureChoices[#lureChoices + 1] = {
      value = tostring(lure.id),
      text = Lures:GetName(lure.id),
      tooltipText = L.LURE_BONUS:format(lure.bonus)
    }
  end
  lureCard:AddSettingsBox():AddChoiceLine(
    L.LURE,
    lureChoices,
    function() return StateManager:GetGlobalState().fishing.lure end,
    function(value) patchFishing({ lure = value }) end
  )

  fishing:AddOptionCard({
    labelText = L.HIDE_NAMEPLATES_TEXT,
    descriptionText = L.HIDE_NAMEPLATES_DESCRIPTION,
    get = function() return StateManager:GetGlobalState().fishing.hideNamePlates end,
    set = function(value) patchFishing({ hideNamePlates = value }) end
  })

  local fishingSoundsCard = fishing:AddOptionCard({
    labelText = L.ENHANCE_SOUNDS_TEXT,
    descriptionText = L.ENHANCE_SOUNDS_DESCRIPTION,
    get = function() return StateManager:GetGlobalState().fishing.enhanceSounds end,
    set = function(value) patchFishing({ enhanceSounds = value }) end
  })
  local soundsBox = fishingSoundsCard:AddSettingsBox()
  soundsBox:AddChoiceLine(
    L.VOLUME,
    {
      { value = 0.25, text = "25%" },
      { value = 0.5, text = "50%" },
      { value = 0.75, text = "75%" },
      { value = 1, text = "100%" }
    },
    function() return StateManager:GetGlobalState().fishing.enhanceSoundsScale end,
    function(value) patchFishing({ enhanceSoundsScale = value }) end
  )

  -- Mutes every sound but the ones of the bobber.
  soundsBox:AddLine(L.KEEP_FISHING_SOUNDS_LINE):AttachComponent(ComponentFactory:CheckChip({
    text = L.KEEP_FISHING_SOUNDS_TEXT,
    get = function() return StateManager:GetGlobalState().fishing.keepOnlyFishingSounds end,
    set = function(value) patchFishing({ keepOnlyFishingSounds = value }) end,
    onUpdateTooltip = function(_, tooltip)
      tooltip:SetText(L.KEEP_FISHING_SOUNDS_TEXT)
      tooltip:AddLine(L.KEEP_FISHING_SOUNDS_DESCRIPTION, 1, 1, 1, true)
    end
  }))

  -- Minutes the sounds stay enhanced after the last cast.
  local delayLine = soundsBox:AddLine(L.SOUND_DELAY_MINUTES)
  local delayInput = delayLine:AttachComponent(ComponentFactory:NumberInput({
    width = 50,
    maxLetters = 3,
    get = function() return StateManager:GetGlobalState().fishing.soundDelayMinutes end,
    set = function(value) patchFishing({ soundDelayMinutes = value }) end
  }))
  delayInput:WhenFrameReady(function(frame) frame:PropagateWhenDisabled(true) end)

  -- Explains the number, next to it, because the label column is narrow.
  local delayHint = delayLine:AttachComponent(ComponentFactory:Text({
    text = L.SOUND_DELAY_HINT,
    fontObject = "GameFontNormalSmall",
    color = Colors.Grey,
    wordWrap = false,
    width = "AUTO"
  }))
  delayHint:SetMarginTop(Widgets.CONTROL_PADDING)

  return panel
end

--- Creates the panel of interface settings.
--- @return TitledPanelComponent panel
function MainWindowOptions:CreateInterfacePanel()
  local panel, container = OptionsBuilder:CreatePanel({
    titleText = Colors.Blue(L.INTERFACE),
    titleJustify = "LEFT"
  })

  -- Interface.
  local interface = OptionsBuilder:AddGroup(container, L.INTERFACE)

  interface:AddOptionCard({
    labelText = L.MINIMAP_ICON_TEXT,
    descriptionText = L.MINIMAP_ICON_DESCRIPTION,
    get = function() return MinimapIcon:IsEnabled() end,
    set = function(value) MinimapIcon:SetEnabled(value) end
  })

  interface:AddOptionCard({
    labelText = L.CHAT_MESSAGES_TEXT,
    descriptionText = L.CHAT_MESSAGES_DESCRIPTION,
    get = function() return StateManager:GetGlobalState().chatMessages end,
    set = function(value) StateManager:Dispatch(ActionCreators.Global.setChatMessages(value)) end
  })

  interface:AddOptionCard({
    labelText = L.BAG_ITEM_TOOLTIPS_TEXT,
    descriptionText = L.BAG_ITEM_TOOLTIPS_DESCRIPTION,
    get = function() return StateManager:GetGlobalState().itemTooltips end,
    set = function(value) StateManager:Dispatch(ActionCreators.Global.setItemTooltips(value)) end
  })

  interface:AddOptionCard({
    labelText = L.SESSION_PANEL_TEXT,
    descriptionText = L.SESSION_PANEL_DESCRIPTION,
    get = function() return StateManager:GetGlobalState().sessionPanel end,
    set = function(value) StateManager:Dispatch(ActionCreators.Global.setSessionPanel(value)) end
  })

  return panel
end

--- Creates the panel of keybindings.
--- @return TitledPanelComponent panel
function MainWindowOptions:CreateKeybindingsPanel()
  local panel, container = OptionsBuilder:CreatePanel({
    titleText = Colors.Blue(L.KEYBINDS),
    titleJustify = "LEFT",
    interceptMouseWheel = function(delta)
      if not Keybindings:GetListeningBindingName() then return false end
      Keybindings:ProcessInput(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
      return true
    end
  })

  -- Footer.
  local footer = OptionsBuilder:AddMessageFooter(panel, { color = Colors.White, defaultMessage = L.KEYBINDINGS_PRIORITY_NOTE })
  footer:SetOrder(1000) -- Position at the end.

  -- Stop listening and reset the footer when hidden. Disable and dim the panel while keybindings cannot be changed.
  panel:WhenFrameReady(function(frame)
    frame:HookScript("OnHide", function()
      Keybindings:StopListening()
      footer:SetMessage(nil)
    end)

    TickerManager:NewTicker(0.1, function()
      local isLocked = Keybindings:IsLocked()
      frame:FireEvent("ENABLED", not isLocked)
      frame:SetAlpha(isLocked and 0.5 or 1)
    end):BindFrame(frame)
  end)

  EventManager:On(E.KeybindingListeningChanged, function(bindingName)
    footer:SetMessage(
      bindingName and
      Colors.Gold(
        B.Strings.ASSIGN_KEY_PROMPT_TEXT:format(
          Colors.White(labels[bindingName]),
          Colors.White(B.Bindings:GetKeyText("ESCAPE"))
        )
      )
      or nil
    )
  end)

  EventManager:On(E.KeybindingBound, function(_, key, replacedBindingName, gameBindingName, isGameBinding)
    local lines = {}

    if replacedBindingName then
      lines[#lines + 1] = Colors.Red(B.Strings.KEY_UNBOUND_ERROR_TEXT:format(Colors.White(labels[replacedBindingName])))
    end

    if gameBindingName then
      lines[#lines + 1] = Colors.Gold(
        (isGameBinding and L.KEY_REPLACED_IN_GAME or L.KEY_ALSO_USED_BY_GAME):format(
          Colors.White(B.Bindings:GetKeyText(key)),
          Colors.White(gameBindingName)
        )
      )
    end

    footer:SetMessage(#lines > 0 and table.concat(lines, "|n") or B.Strings.KEY_BOUND_TEXT)
  end)

  -- Actions. The two cast keys are kept in the key bindings of the game.
  local actions = OptionsBuilder:AddGroup(container, L.ACTIONS)
  addKeybindingCard(actions, footer, "destroyNextItem", L.DESTROY_NEXT_ITEM, L.KEYBIND_DESCRIPTION_DESTROY_NEXT_ITEM)
  addKeybindingCard(actions, footer, "castWithLure", BINDING_NAME_CATCHITCASTKEY, L.KEYBIND_DESCRIPTION_CAST_WITH_LURE)
  addKeybindingCard(actions, footer, "castAndInteract", L.CAST_AND_INTERACT_STANDALONE, L.KEYBIND_DESCRIPTION_CAST_AND_INTERACT)
  addKeybindingCard(actions, footer, "toggleMainWindow", L.TOGGLE_MAIN_WINDOW)

  -- Lists.
  local profileLists = OptionsBuilder:AddGroup(container, L.PROFILE_LISTS)
  local globalLists = OptionsBuilder:AddGroup(container, L.GLOBAL_LISTS)

  for _, entry in ipairs({
    {
      group = globalLists,
      list = Lists.GlobalInclusions,
      addBindingName = "addToGlobalInclusions",
      removeBindingName = "removeFromGlobalInclusions"
    },
    {
      group = profileLists,
      list = Lists.ProfileInclusions,
      addBindingName = "addToProfileInclusions",
      removeBindingName = "removeFromProfileInclusions"
    }
  }) do
    addKeybindingCard(
      entry.group,
      footer,
      entry.addBindingName,
      L.ADD_TO_LIST:format(entry.list.name),
      L.KEYBIND_DESCRIPTION_ADD_TO_LIST
    )

    addKeybindingCard(
      entry.group,
      footer,
      entry.removeBindingName,
      L.REMOVE_FROM_LIST:format(entry.list.name),
      L.KEYBIND_DESCRIPTION_REMOVE_FROM_LIST
    )
  end

  return panel
end
