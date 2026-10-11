--[[
    OneMiniMap - OptionsUI.lua
    Graphical Configuration Panel for OneMiniMap.
    Supports both standalone window and Blizzard Interface Options.
    Compatibility: Vanilla 1.12, Turtle WoW 1.16, WotLK 3.3.5, and Modern WoW.
--]]

local addonName, addonTable = ...
local OneMiniMap = _G.OneMiniMap or addonTable

OneMiniMap.OptionsUI = {}
local OptionsUI = OneMiniMap.OptionsUI

local standaloneWindow = nil
local blizzardOptionsPanel = nil

-- Safe Backdrop Application
local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
local function ApplyBackdrop(frame, backdropInfo)
    if not frame then return end
    if BackdropTemplateMixin and not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end
    if frame.SetBackdrop then
        frame:SetBackdrop(backdropInfo)
    end
end

-------------------------------------------------------------------------------
-- UI Widget Helpers
-------------------------------------------------------------------------------
local function CreateCheckbox(parent, label, getVal, setVal)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    if not cb.text then
        cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    end
    cb.text:SetText(label)

    cb:SetScript("OnShow", function(self)
        self:SetChecked(getVal())
    end)
    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        setVal(checked)
    end)
    return cb
end

local function CreateButton(parent, label, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 140, height or 24)
    btn:SetText(label)
    if onClick then
        btn:SetScript("OnClick", onClick)
    end
    return btn
end

local function CreateSlider(parent, label, minVal, maxVal, step, getVal, setVal)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetWidth(180)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    local title = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
    title:SetText(label)
    slider.title = title

    local valText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valText:SetPoint("LEFT", slider, "RIGHT", 14, 0)
    slider.valText = valText

    local function UpdateDisplay(val)
        valText:SetText(string.format("%.0f%%", val * 100))
    end

    slider:SetScript("OnShow", function(self)
        local val = getVal() or 1.0
        self:SetValue(val)
        UpdateDisplay(val)
    end)

    slider:SetScript("OnValueChanged", function(self, value)
        local rounded = math.floor((value / step) + 0.5) * step
        UpdateDisplay(rounded)
        setVal(rounded)
    end)

    return slider
end

-------------------------------------------------------------------------------
-- Standalone Options Window
-------------------------------------------------------------------------------
function OptionsUI:CreateStandaloneWindow()
    if standaloneWindow then return standaloneWindow end

    local frame = CreateFrame("Frame", "OneMiniMapOptionsFrame", UIParent, backdropTemplate)
    frame:SetSize(360, 420)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    -- Metal Frame Styling (OneSuite signature)
    ApplyBackdrop(frame, {
        bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    if frame.SetBackdropColor then
        frame:SetBackdropColor(0.2, 0.2, 0.2, 0.98)
    end
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(0.75, 0.75, 0.75, 1.0)
    end

    -- Header Icon & Title
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -14)
    icon:SetTexture("Interface\\Icons\\inv_misc_map02")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    title:SetText("|cff00ccffOneMiniMap|r Options")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Divider Line
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -40)
    divider:SetHeight(1)
    if divider.SetColorTexture then
        divider:SetColorTexture(0.5, 0.5, 0.5, 0.6)
    else
        divider:SetTexture("Interface\\Buttons\\WHITE8X8")
        divider:SetVertexColor(0.5, 0.5, 0.5, 0.6)
    end

    -- Checkboxes Stack
    local yOfs = -54
    local spacing = 28

    -- 1. Lock Frames
    local cbLock = CreateCheckbox(frame, "Lock All Frames (Disable Dragging)", 
        function() return OneMiniMapDB and OneMiniMapDB.locked end,
        function(val)
            OneMiniMapDB.locked = val
            local state = val and "|cffff2020LOCKED|r" or "|cff20ff20UNLOCKED|r"
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Frames are now " .. state .. ".")
        end)
    cbLock:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, yOfs)
    yOfs = yOfs - spacing

    -- 2. Show Zone Title Bar
    local cbTitle = CreateCheckbox(frame, "Show Zone Title Bar", 
        function() return OneMiniMapDB and OneMiniMapDB.showTitle end,
        function(val)
            OneMiniMapDB.showTitle = val
            if OneMiniMap.titleFrame then OneMiniMap.titleFrame:SetShown(val) end
        end)
    cbTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, yOfs)
    yOfs = yOfs - spacing

    -- 3. Show Clock
    local cbClock = CreateCheckbox(frame, "Show Clock Frame", 
        function() return OneMiniMapDB and OneMiniMapDB.showClock end,
        function(val)
            OneMiniMapDB.showClock = val
            if OneMiniMap.clockFrame then OneMiniMap.clockFrame:SetShown(val) end
        end)
    cbClock:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, yOfs)
    yOfs = yOfs - spacing

    -- 4. Show Coordinates
    local cbCoords = CreateCheckbox(frame, "Show Coordinates Frame", 
        function() return OneMiniMapDB and OneMiniMapDB.showCoords end,
        function(val)
            OneMiniMapDB.showCoords = val
            if OneMiniMap.coordFrame then OneMiniMap.coordFrame:SetShown(val) end
        end)
    cbCoords:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, yOfs)
    yOfs = yOfs - spacing

    -- 5. 24-Hour Time
    local cb24h = CreateCheckbox(frame, "Use 24-Hour Clock Format", 
        function() return OneMiniMapDB and OneMiniMapDB.use24h end,
        function(val)
            OneMiniMapDB.use24h = val
            if OneMiniMap.UpdateClock then OneMiniMap:UpdateClock() end
        end)
    cb24h:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, yOfs)
    yOfs = yOfs - spacing

    -- 6. Show Button Collector Bar
    local cbButtons = CreateCheckbox(frame, "Show Minimap Button Collector Bar", 
        function() return OneMiniMapDB and OneMiniMapDB.showButtons end,
        function(val)
            OneMiniMapDB.showButtons = val
            if OneMiniMap.ButtonCollector and OneMiniMap.ButtonCollector.frame then
                OneMiniMap.ButtonCollector.frame:SetShown(val)
            end
        end)
    cbButtons:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, yOfs)
    yOfs = yOfs - spacing

    -- 7. 2 Columns for Button Collector
    local cbCols = CreateCheckbox(frame, "Use 2 Columns for Buttons (Default: 1)", 
        function() return OneMiniMapDB and (OneMiniMapDB.buttonCols == 2) end,
        function(val)
            OneMiniMapDB.buttonCols = val and 2 or 1
            if OneMiniMap.ButtonCollector and OneMiniMap.ButtonCollector.Update then
                OneMiniMap.ButtonCollector:Update()
            end
        end)
    cbCols:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, yOfs)
    yOfs = yOfs - 38

    -- 8. Minimap Scale Slider
    local sliderScale = CreateSlider(frame, "Minimap Scale", 0.6, 1.8, 0.05,
        function() return OneMiniMapDB and OneMiniMapDB.scale or 1.0 end,
        function(val)
            if OneMiniMap.SetScale then
                OneMiniMap:SetScale(val)
            end
        end)
    sliderScale:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, yOfs)
    yOfs = yOfs - 36

    -- Action Buttons
    local btnReset = CreateButton(frame, "Reset Positions", 150, 24, function()
        OneMiniMapDB.mapPosition = nil
        OneMiniMapDB.titlePosition = nil
        OneMiniMapDB.clockPosition = nil
        OneMiniMapDB.coordPosition = nil
        OneMiniMapDB.buttonCollectorPosition = nil
        OneMiniMap:RestorePositions()
        if OneMiniMap.ButtonCollector and OneMiniMap.ButtonCollector.Update then
            OneMiniMap.ButtonCollector:Update()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: All frame positions reset to defaults.")
    end)
    btnReset:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, yOfs)

    local btnBar = CreateButton(frame, "Reset Action Bar", 150, 24, function()
        if ChangeActionBarPage then
            ChangeActionBarPage(1)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Action bar reset to Page 1.")
    end)
    btnBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, yOfs)

    -- Esc key closing
    if table and table.insert and UISpecialFrames then
        table.insert(UISpecialFrames, "OneMiniMapOptionsFrame")
    end

    standaloneWindow = frame
    return frame
end

-------------------------------------------------------------------------------
-- Blizzard Interface Options Category Panel
-------------------------------------------------------------------------------
function OptionsUI:RegisterBlizzardPanel()
    if blizzardOptionsPanel then return end

    local panel = CreateFrame("Frame", "OneMiniMapBlizzardOptions", UIParent)
    panel.name = "OneMiniMap"

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    icon:SetTexture("Interface\\Icons\\inv_misc_map02")

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    title:SetText("OneMiniMap")

    local subText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subText:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -8)
    subText:SetText("Modular Square MiniMap with metal frame styling, top coordinates, and button collector.")

    local openBtn = CreateButton(panel, "Open OneMiniMap Settings", 180, 26, function()
        if InterfaceOptionsFrame_Show then
            InterfaceOptionsFrame:Hide()
        end
        OptionsUI:Show()
    end)
    openBtn:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -16)

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, "OneMiniMap")
        if cat and cat.SetIcon then
            pcall(function() cat:SetIcon("Interface\\Icons\\inv_misc_map02") end)
        end
        Settings.RegisterAddOnCategory(cat)
    end

    blizzardOptionsPanel = panel
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------
function OptionsUI:Show()
    local win = self:CreateStandaloneWindow()
    win:Show()
end

function OptionsUI:Hide()
    if standaloneWindow then
        standaloneWindow:Hide()
    end
end

function OptionsUI:Toggle()
    local win = self:CreateStandaloneWindow()
    if win:IsShown() then
        win:Hide()
    else
        win:Show()
    end
end

function OneMiniMap:ToggleOptions()
    OptionsUI:Toggle()
end

-------------------------------------------------------------------------------
-- Initialize
-------------------------------------------------------------------------------
function OptionsUI:Initialize()
    self:RegisterBlizzardPanel()
end
