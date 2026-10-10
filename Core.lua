--[[
    OneMiniMap - Core.lua
    Lightweight Square MiniMap replacement with signature metal frame styling,
    separate frameless translucent title bar, draggable clock frame,
    and draggable coordinates frame.
    Compatibility: Vanilla 1.12, Turtle WoW 1.16, WotLK 3.3.5, and Modern WoW.
--]]

local addonName, addonTable = ...

-- Global Namespace Export
_G.OneMiniMap = _G.OneMiniMap or addonTable
local OneMiniMap = _G.OneMiniMap

OneMiniMap.name = addonName or "OneMiniMap"
OneMiniMap.version = "0.2.0"
OneMiniMap.isInitialized = false

-- Default Database Configuration
local defaultDB = {
    locked = false,
    use24h = false,
    showTitle = true,
    showClock = true,
    showCoords = true,
    scale = 1.0,
    mapPosition = nil,
    titlePosition = nil,
    clockPosition = nil,
    coordPosition = nil,
}

-------------------------------------------------------------------------------
-- Helper: Safe Backdrop Application across WoW generations
-------------------------------------------------------------------------------
local function ApplyBackdrop(target, backdropInfo)
    if not target then return end
    if BackdropTemplateMixin and not target.SetBackdrop then
        Mixin(target, BackdropTemplateMixin)
    end
    if target.SetBackdrop then
        target:SetBackdrop(backdropInfo)
    end
end

-------------------------------------------------------------------------------
-- Helper: Universal Player Coordinates
-------------------------------------------------------------------------------
function OneMiniMap:GetPlayerCoordinates()
    -- Modern WoW (8.0+ / Dragonflight / The War Within)
    if C_Map and C_Map.GetBestMapForUnit then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if pos then
                local x, y = pos:GetXY()
                if x and y and (x > 0 or y > 0) then
                    return x * 100, y * 100
                end
            end
        end
    -- Classic / Vanilla 1.12 / Turtle WoW / TBC 2.4 / WotLK 3.3.5
    elseif GetPlayerMapPosition then
        local x, y = GetPlayerMapPosition("player")
        if (not x or not y or (x == 0 and y == 0)) and SetMapToCurrentZone then
            SetMapToCurrentZone()
            x, y = GetPlayerMapPosition("player")
        end
        if x and y and (x > 0 or y > 0) then
            return x * 100, y * 100
        end
    end
    return nil, nil
end

-------------------------------------------------------------------------------
-- Helper: Zone PvP Reaction Color
-------------------------------------------------------------------------------
local function GetZoneColor()
    local pvpType = GetZonePVPInfo and GetZonePVPInfo()
    if pvpType == "sanctuary" then
        return 0.41, 0.8, 0.94   -- Light sanctuary blue
    elseif pvpType == "arena" then
        return 1.0, 0.38, 0.0    -- Vibrant arena orange
    elseif pvpType == "friendly" then
        return 0.1, 1.0, 0.1     -- Green
    elseif pvpType == "hostile" then
        return 1.0, 0.15, 0.15   -- Hostile red
    elseif pvpType == "contested" then
        return 1.0, 0.82, 0.0    -- Contested yellow
    else
        return 1.0, 0.92, 0.65   -- Standard zone tint
    end
end

-------------------------------------------------------------------------------
-- Helper: Translucent Black Background Creator
-------------------------------------------------------------------------------
local function CreateTranslucentBackground(parent, alpha)
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(parent)
    if bg.SetColorTexture then
        bg:SetColorTexture(0, 0, 0, alpha or 0.65)
    else
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(0, 0, 0, alpha or 0.65)
    end
    return bg
end

-------------------------------------------------------------------------------
-- Square Mask & Shape Override
-------------------------------------------------------------------------------
local function SetupSquareMask()
    if Minimap.SetMaskTexture then
        Minimap:SetMaskTexture("Interface\\BUTTONS\\WHITE8X8")
    end

    -- Signal to other addons (Questie, Gatherer, TomTom) that the map is SQUARE
    function GetMinimapShape()
        return "SQUARE"
    end
end

-------------------------------------------------------------------------------
-- Complete Suppression of Native Blizzard Chrome & Stray Clusters
-------------------------------------------------------------------------------
local hiddenFrame = CreateFrame("Frame")
hiddenFrame:Hide()

local function SuppressBlizzardChrome()
    -- 1. Neutralize known Blizzard minimap chrome frames by reparenting to permanently hidden frame
    local framesToHide = {
        "MinimapBorder",
        "MinimapBorderTop",
        "MinimapZoneTextButton",
        "MinimapToggleButton",
        "MinimapZoomIn",
        "MinimapZoomOut",
        "MiniMapWorldMapButton",
        "TimeManagerClockButton",
    }

    for _, frameName in ipairs(framesToHide) do
        local f = _G[frameName]
        if f then
            f:Hide()
            if f.SetParent then
                f:SetParent(hiddenFrame)
            end
            if f.UnregisterAllEvents then
                f:UnregisterAllEvents()
            end
            if f.SetTexture then
                f:SetTexture(nil)
            end
            if f.SetAlpha then
                f:SetAlpha(0)
            end
            f.Show = function() end
        end
    end

    -- 2. Strip all textures and stray FontStrings from MinimapCluster
    if MinimapCluster then
        for _, region in ipairs({ MinimapCluster:GetRegions() }) do
            if region:IsObjectType("Texture") then
                region:SetTexture(nil)
                region:SetAlpha(0)
                region:Hide()
            elseif region:IsObjectType("FontString") then
                region:SetText("")
                region:SetAlpha(0)
                region:Hide()
            end
        end

        -- Check any children of MinimapCluster that might be third-party or client coordinates
        for _, child in ipairs({ MinimapCluster:GetChildren() }) do
            if child ~= Minimap and child ~= MiniMapTrackingFrame and child ~= MiniMapMailFrame and child ~= GameTimeFrame then
                local childName = child:GetName() or ""
                if childName:find("Border") or childName:find("Coord") or childName:find("Zone") or childName:find("Zoom") or childName:find("Clock") then
                    child:Hide()
                    if child.SetParent then
                        child:SetParent(hiddenFrame)
                    end
                end
            end
        end

        MinimapCluster:SetAlpha(0)
        MinimapCluster:EnableMouse(false)
    end

    -- 3. Strip any border textures that might be attached directly to Minimap
    for _, region in ipairs({ Minimap:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local tex = region:GetTexture()
            if tex and (type(tex) == "string" and (tex:find("Border") or tex:find("Corner"))) then
                region:SetTexture(nil)
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Mouse Wheel Zooming
-------------------------------------------------------------------------------
local function SetupMouseWheelZoom()
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            if Minimap_ZoomIn then
                Minimap_ZoomIn()
            else
                local curr = self:GetZoom()
                local maxZoom = (self.GetZoomLevels and self:GetZoomLevels() - 1) or 5
                if curr < maxZoom then
                    self:SetZoom(curr + 1)
                end
            end
        else
            if Minimap_ZoomOut then
                Minimap_ZoomOut()
            else
                local curr = self:GetZoom()
                if curr > 0 then
                    self:SetZoom(curr - 1)
                end
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- Peripheral Minimap Buttons Docking
-------------------------------------------------------------------------------
local function DockMinimapButtons()
    -- Tracking Icon (Binoculars / magnifying glass)
    local tracking = _G["MiniMapTracking"] or _G["MiniMapTrackingFrame"]
    if tracking then
        tracking:ClearAllPoints()
        tracking:SetParent(OneMiniMap.mapFrame or Minimap)
        tracking:SetPoint("TOPLEFT", OneMiniMap.mapFrame or Minimap, "TOPLEFT", 4, -4)
        tracking:SetScale(0.85)
    end

    -- Mail Notification Icon
    local mail = _G["MiniMapMailFrame"]
    if mail then
        mail:ClearAllPoints()
        mail:SetParent(OneMiniMap.mapFrame or Minimap)
        mail:SetPoint("TOPRIGHT", OneMiniMap.mapFrame or Minimap, "TOPRIGHT", -4, -4)
        mail:SetScale(0.9)
    end

    -- Calendar / Game Time (Sun/Moon icon)
    local gameTime = _G["GameTimeFrame"]
    if gameTime then
        gameTime:ClearAllPoints()
        gameTime:SetParent(OneMiniMap.mapFrame or Minimap)
        gameTime:SetPoint("BOTTOMLEFT", OneMiniMap.mapFrame or Minimap, "BOTTOMLEFT", 4, 4)
        gameTime:SetScale(0.7)
    end

    -- Looking For Group / Eye Icon
    local lfg = _G["MiniMapLFGFrame"] or _G["QueueStatusMinimapButton"]
    if lfg then
        lfg:ClearAllPoints()
        lfg:SetParent(OneMiniMap.mapFrame or Minimap)
        lfg:SetPoint("BOTTOMLEFT", OneMiniMap.mapFrame or Minimap, "BOTTOMLEFT", 22, 4)
        lfg:SetScale(0.85)
    end

    -- Battleground / PvP Queue Icon
    local pvp = _G["MiniMapBattlefieldFrame"]
    if pvp then
        pvp:ClearAllPoints()
        pvp:SetParent(OneMiniMap.mapFrame or Minimap)
        pvp:SetPoint("BOTTOMRIGHT", OneMiniMap.mapFrame or Minimap, "BOTTOMRIGHT", -4, 4)
        pvp:SetScale(0.85)
    end
end

-------------------------------------------------------------------------------
-- Frame 1: Square MiniMap Metal Frame Container
-------------------------------------------------------------------------------
function OneMiniMap:CreateMapFrame()
    if self.mapFrame then return self.mapFrame end

    local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "OneMiniMapFrame", UIParent, backdropTemplate)
    frame:SetSize(148, 148)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetFrameStrata("LOW")

    -- Signature OnePanel / OneStorage Metal Border Styling
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
        frame:SetBackdropBorderColor(0.75, 0.75, 0.75, 1.0) -- Silver / Metal edge
    end

    -- Reparent Minimap securely inside metal container
    Minimap:SetParent(frame)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    Minimap:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    Minimap:SetSize(140, 140)

    -- Dragging Map Frame (When unlocked or Alt+Drag)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not OneMiniMapDB.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        OneMiniMap:SavePositions()
    end)

    Minimap:EnableMouse(true)
    Minimap:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsAltKeyDown() and not OneMiniMapDB.locked then
            frame:StartMoving()
        end
    end)
    Minimap:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            frame:StopMovingOrSizing()
            OneMiniMap:SavePositions()
        end
    end)

    self.mapFrame = frame
    return frame
end

-------------------------------------------------------------------------------
-- Frame 2: Separate Frameless Translucent Title Bar (Above MiniMap)
-------------------------------------------------------------------------------
function OneMiniMap:CreateTitleFrame()
    if self.titleFrame then return self.titleFrame end

    local frame = CreateFrame("Button", "OneMiniMapTitleFrame", UIParent)
    frame:SetSize(148, 20)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetFrameStrata("LOW")
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    -- Frameless Translucent Black Background
    CreateTranslucentBackground(frame, 0.65)

    -- Zone Text
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetAllPoints(frame)
    text:SetJustifyH("CENTER")
    text:SetText(GetZoneText() or "World of Warcraft")
    self.zoneText = text

    -- Left-click: Open World Map
    frame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if ToggleWorldMap then
                ToggleWorldMap()
            elseif WorldMapFrame then
                ToggleFrame(WorldMapFrame)
            end
        end
    end)

    -- Tooltip on Hover
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:ClearLines()
        local zone = GetZoneText() or ""
        local subZone = GetSubZoneText() or ""
        GameTooltip:AddLine(zone, 1, 1, 1)
        if subZone ~= "" and subZone ~= zone then
            GameTooltip:AddLine(subZone, 0.8, 0.8, 0.8)
        end
        local pvpType = GetZonePVPInfo and GetZonePVPInfo()
        if pvpType then
            local r, g, b = GetZoneColor()
            GameTooltip:AddLine(pvpType:upper(), r, g, b)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ccffClick|r to open World Map", 0.7, 0.7, 0.7)
        if not OneMiniMapDB.locked then
            GameTooltip:AddLine("|cff00ccffDrag|r to reposition Title Bar", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Dragging
    frame:SetScript("OnDragStart", function(self)
        if not OneMiniMapDB.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        OneMiniMap:SavePositions()
    end)

    self.titleFrame = frame
    return frame
end

-------------------------------------------------------------------------------
-- Frame 3: Separate Frameless Translucent Clock Frame (Draggable)
-------------------------------------------------------------------------------
function OneMiniMap:CreateClockFrame()
    if self.clockFrame then return self.clockFrame end

    local frame = CreateFrame("Button", "OneMiniMapClockFrame", UIParent)
    frame:SetSize(66, 18)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetFrameStrata("LOW")
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    -- Frameless Translucent Black Background
    CreateTranslucentBackground(frame, 0.65)

    -- Clock Text
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetAllPoints(frame)
    text:SetJustifyH("CENTER")
    text:SetText("00:00")
    self.clockText = text

    -- Left-click: Toggle 12h / 24h format
    frame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            OneMiniMapDB.use24h = not OneMiniMapDB.use24h
            OneMiniMap:UpdateClock()
            local mode = OneMiniMapDB.use24h and "24-hour" or "12-hour"
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Clock set to " .. mode .. " mode.")
        end
    end)

    -- Tooltip on Hover
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Clock", 1, 1, 1)
        GameTooltip:AddLine("|cff00ccffClick|r to toggle 12h/24h format", 0.7, 0.7, 0.7)
        if not OneMiniMapDB.locked then
            GameTooltip:AddLine("|cff00ccffDrag|r to reposition Clock", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Dragging
    frame:SetScript("OnDragStart", function(self)
        if not OneMiniMapDB.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        OneMiniMap:SavePositions()
    end)

    self.clockFrame = frame
    return frame
end

-------------------------------------------------------------------------------
-- Frame 4: Separate Frameless Translucent Coordinates Frame (Draggable)
-------------------------------------------------------------------------------
function OneMiniMap:CreateCoordFrame()
    if self.coordFrame then return self.coordFrame end

    local frame = CreateFrame("Button", "OneMiniMapCoordFrame", UIParent)
    frame:SetSize(78, 18)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetFrameStrata("LOW")
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    -- Frameless Translucent Black Background
    CreateTranslucentBackground(frame, 0.65)

    -- Coordinates Text
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetAllPoints(frame)
    text:SetJustifyH("CENTER")
    text:SetText("|cffffd200--.-, --.-|r")
    self.coordText = text

    -- Tooltip on Hover
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Coordinates", 1, 1, 1)
        if not OneMiniMapDB.locked then
            GameTooltip:AddLine("|cff00ccffDrag|r to reposition Coordinates", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Dragging
    frame:SetScript("OnDragStart", function(self)
        if not OneMiniMapDB.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        OneMiniMap:SavePositions()
    end)

    self.coordFrame = frame
    return frame
end

-------------------------------------------------------------------------------
-- Update Routines (Clock, Coordinates, Zone)
-------------------------------------------------------------------------------
function OneMiniMap:UpdateClock()
    if not self.clockText then return end

    local hours, minutes
    if GetGameTime then
        hours, minutes = GetGameTime()
    else
        local d = date("*t")
        hours, minutes = d.hour, d.min
    end

    if OneMiniMapDB.use24h then
        self.clockText:SetText(string.format("%02d:%02d", hours, minutes))
    else
        local suffix = (hours >= 12) and "PM" or "AM"
        local h12 = hours % 12
        if h12 == 0 then h12 = 12 end
        self.clockText:SetText(string.format("%d:%02d %s", h12, minutes, suffix))
    end
end

local function StartUpdateTicker()
    local ticker = CreateFrame("Frame")
    local elapsedTicker = 0
    local clockTicker = 0

    ticker:SetScript("OnUpdate", function(self, elapsed)
        elapsedTicker = elapsedTicker + elapsed
        clockTicker = clockTicker + elapsed

        -- 1. Throttled Coordinates & Zone Update (0.15s)
        if elapsedTicker >= 0.15 then
            elapsedTicker = 0

            -- Update Coordinates
            if OneMiniMapDB.showCoords and OneMiniMap.coordText then
                local x, y = OneMiniMap:GetPlayerCoordinates()
                if x and y then
                    OneMiniMap.coordText:SetText(string.format("|cffffd200%.1f, %.1f|r", x, y))
                else
                    OneMiniMap.coordText:SetText("|cff777777--.-, --.-|r")
                end
            end

            -- Update Zone Text
            if OneMiniMapDB.showTitle and OneMiniMap.zoneText then
                local subZone = (GetSubZoneText and GetSubZoneText()) or ""
                local zone = (GetZoneText and GetZoneText()) or ""
                local display = (subZone ~= "" and subZone) or zone
                if display ~= "" then
                    local r, g, b = GetZoneColor()
                    OneMiniMap.zoneText:SetTextColor(r, g, b)
                    OneMiniMap.zoneText:SetText(display)
                end
            end
        end

        -- 2. Throttled Clock Update (1.0s)
        if clockTicker >= 1.0 then
            clockTicker = 0
            if OneMiniMapDB.showClock then
                OneMiniMap:UpdateClock()
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- Positions Persistence (Map, Title, Clock, Coords)
-------------------------------------------------------------------------------
function OneMiniMap:SavePositions()
    OneMiniMapDB = OneMiniMapDB or {}

    local function Capture(f)
        if not f then return nil end
        local point, _, relPoint, xOfs, yOfs = f:GetPoint()
        return {
            point = point or "TOPRIGHT",
            relPoint = relPoint or "TOPRIGHT",
            x = math.floor((xOfs or 0) + 0.5),
            y = math.floor((yOfs or 0) + 0.5),
        }
    end

    OneMiniMapDB.mapPosition = Capture(self.mapFrame)
    OneMiniMapDB.titlePosition = Capture(self.titleFrame)
    OneMiniMapDB.clockPosition = Capture(self.clockFrame)
    OneMiniMapDB.coordPosition = Capture(self.coordFrame)
end

function OneMiniMap:RestorePositions()
    local function Restore(f, pos, defaultAnchorFn)
        if not f then return end
        f:ClearAllPoints()
        if pos and pos.point and pos.x and pos.y then
            f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
        else
            defaultAnchorFn(f)
        end
    end

    -- 1. Map Frame: Default TOPRIGHT of screen (-16, -26)
    Restore(self.mapFrame, OneMiniMapDB.mapPosition, function(f)
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -26)
    end)

    -- 2. Title Frame: Default directly above Map Frame (0, 3)
    Restore(self.titleFrame, OneMiniMapDB.titlePosition, function(f)
        f:SetPoint("BOTTOMLEFT", self.mapFrame, "TOPLEFT", 0, 3)
        f:SetPoint("BOTTOMRIGHT", self.mapFrame, "TOPRIGHT", 0, 3)
    end)

    -- 3. Clock Frame: Default directly below Map Frame on the Left
    Restore(self.clockFrame, OneMiniMapDB.clockPosition, function(f)
        f:SetPoint("TOPLEFT", self.mapFrame, "BOTTOMLEFT", 0, -3)
    end)

    -- 4. Coordinates Frame: Default directly below Map Frame on the Right
    Restore(self.coordFrame, OneMiniMapDB.coordPosition, function(f)
        f:SetPoint("TOPRIGHT", self.mapFrame, "BOTTOMRIGHT", 0, -3)
    end)
end

-------------------------------------------------------------------------------
-- Initialization Workflow
-------------------------------------------------------------------------------
function OneMiniMap:Initialize()
    if self.isInitialized then return end

    -- Merge Database Defaults
    OneMiniMapDB = OneMiniMapDB or {}
    for k, v in pairs(defaultDB) do
        if OneMiniMapDB[k] == nil then
            OneMiniMapDB[k] = v
        end
    end

    -- Setup Square Mask & Suppress Blizzard Chrome
    SetupSquareMask()
    SuppressBlizzardChrome()
    SetupMouseWheelZoom()

    -- Create Independent Modular Frames
    self:CreateMapFrame()
    self:CreateTitleFrame()
    self:CreateClockFrame()
    self:CreateCoordFrame()

    -- Restore Independent Positions
    self:RestorePositions()
    DockMinimapButtons()

    -- Visibility States
    self.titleFrame:SetShown(OneMiniMapDB.showTitle)
    self.clockFrame:SetShown(OneMiniMapDB.showClock)
    self.coordFrame:SetShown(OneMiniMapDB.showCoords)

    -- Apply Scale
    if OneMiniMapDB.scale and OneMiniMapDB.scale ~= 1.0 then
        self.mapFrame:SetScale(OneMiniMapDB.scale)
        self.titleFrame:SetScale(OneMiniMapDB.scale)
        self.clockFrame:SetScale(OneMiniMapDB.scale)
        self.coordFrame:SetScale(OneMiniMapDB.scale)
    end

    -- Start Update Tickers
    self:UpdateClock()
    StartUpdateTicker()

    self.isInitialized = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r v" .. self.version .. " initialized. Type |cffffd200/omm|r for options.")
end

-------------------------------------------------------------------------------
-- Slash Commands (/omm and /oneminimap)
-------------------------------------------------------------------------------
SLASH_ONEMINIMAP1 = "/oneminimap"
SLASH_ONEMINIMAP2 = "/omm"

SlashCmdList["ONEMINIMAP"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local cmd, arg = msg:match("^(%S+)%s*(.*)$")

    if cmd == "lock" then
        OneMiniMapDB.locked = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Frames are now |cffff2020LOCKED|r.")
    elseif cmd == "unlock" then
        OneMiniMapDB.locked = false
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Frames are now |cff20ff20UNLOCKED|r (drag Map, Title, Clock, or Coords to move).")
    elseif cmd == "coords" then
        OneMiniMapDB.showCoords = not OneMiniMapDB.showCoords
        if OneMiniMap.coordFrame then
            OneMiniMap.coordFrame:SetShown(OneMiniMapDB.showCoords)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Coordinates frame toggled " .. (OneMiniMapDB.showCoords and "|cff20ff20ON|r" or "|cffff2020OFF|r") .. ".")
    elseif cmd == "clock" then
        OneMiniMapDB.showClock = not OneMiniMapDB.showClock
        if OneMiniMap.clockFrame then
            OneMiniMap.clockFrame:SetShown(OneMiniMapDB.showClock)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Clock frame toggled " .. (OneMiniMapDB.showClock and "|cff20ff20ON|r" or "|cffff2020OFF|r") .. ".")
    elseif cmd == "title" then
        OneMiniMapDB.showTitle = not OneMiniMapDB.showTitle
        if OneMiniMap.titleFrame then
            OneMiniMap.titleFrame:SetShown(OneMiniMapDB.showTitle)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Title bar toggled " .. (OneMiniMapDB.showTitle and "|cff20ff20ON|r" or "|cffff2020OFF|r") .. ".")
    elseif cmd == "reset" then
        OneMiniMapDB.mapPosition = nil
        OneMiniMapDB.titlePosition = nil
        OneMiniMapDB.clockPosition = nil
        OneMiniMapDB.coordPosition = nil
        OneMiniMap:RestorePositions()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Positions reset to defaults.")
    elseif cmd == "scale" and tonumber(arg) then
        local s = tonumber(arg)
        if s and s >= 0.5 and s <= 2.0 then
            OneMiniMapDB.scale = s
            if OneMiniMap.mapFrame then OneMiniMap.mapFrame:SetScale(s) end
            if OneMiniMap.titleFrame then OneMiniMap.titleFrame:SetScale(s) end
            if OneMiniMap.clockFrame then OneMiniMap.clockFrame:SetScale(s) end
            if OneMiniMap.coordFrame then OneMiniMap.coordFrame:SetScale(s) end
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Scale set to " .. s .. ".")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Scale must be between 0.5 and 2.0.")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm lock|r - Lock all frame positions")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm unlock|r - Unlock all frames for dragging")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm title|r - Toggle title bar frame")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm clock|r - Toggle clock frame")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm coords|r - Toggle coordinates frame")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm scale <0.5 - 2.0>|r - Adjust scale")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm reset|r - Reset all frames to default positions")
    end
end

-------------------------------------------------------------------------------
-- Event Dispatcher
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "OneMiniMap" then
        OneMiniMap:Initialize()
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if not OneMiniMap.isInitialized then
            OneMiniMap:Initialize()
        else
            SuppressBlizzardChrome()
            DockMinimapButtons()
        end
    end
end)
