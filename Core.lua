--[[
    OneMiniMap - Core.lua
    Modular Square MiniMap replacement with signature OneSuite metal frame styling,
    separate frameless translucent title bar, draggable clock frame,
    and draggable coordinates frame.
    Compatibility: Vanilla 1.12, Turtle WoW 1.16, WotLK 3.3.5, and Modern WoW.
--]]

local addonName, addonTable = ...

-- Global Namespace Export
_G.OneMiniMap = _G.OneMiniMap or addonTable
local OneMiniMap = _G.OneMiniMap

OneMiniMap.name = addonName or "OneMiniMap"
OneMiniMap.version = "0.2.2"
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
-- Complete Suppression of Native Blizzard Chrome, MinimapBackdrop & Clusters
-------------------------------------------------------------------------------
local hiddenFrame = CreateFrame("Frame")
hiddenFrame:Hide()

local function KillObject(obj)
    if not obj then return end
    pcall(function()
        obj:Hide()
        obj:SetAlpha(0)
        if obj.SetParent then
            obj:SetParent(hiddenFrame)
        end
        if obj.SetTexture then
            obj:SetTexture("")
        end
        if obj.UnregisterAllEvents then
            obj:UnregisterAllEvents()
        end
        obj.Show = function() end
    end)
end

local function SuppressBlizzardChrome()
    -- Known Blizzard Minimap frames and textures (covering all capitalizations & client generations)
    local framesToHide = {
        "MinimapBackdrop",
        "MiniMapBackdrop",
        "MinimapBorder",
        "MiniMapBorder",
        "MinimapBorderTop",
        "MiniMapBorderTop",
        "MinimapZoneTextButton",
        "MiniMapZoneTextButton",
        "MinimapToggleButton",
        "MiniMapToggleButton",
        "MinimapZoomIn",
        "MiniMapZoomIn",
        "MinimapZoomOut",
        "MiniMapZoomOut",
        "MiniMapWorldMapButton",
        "TimeManagerClockButton",
        "MinimapNorthTag",
        "MinimapCompassTexture",
    }

    for _, frameName in ipairs(framesToHide) do
        KillObject(_G[frameName])
    end

    -- Neutralize MinimapBackdrop if present (contains the native circular artwork)
    local mb = _G["MinimapBackdrop"] or _G["MiniMapBackdrop"]
    if mb then
        pcall(function()
            KillObject(mb)
            for _, r in ipairs({ mb:GetRegions() }) do
                KillObject(r)
            end
            for _, c in ipairs({ mb:GetChildren() }) do
                KillObject(c)
            end
        end)
    end

    -- Neutralize MinimapCluster regions & non-essential children
    if MinimapCluster then
        pcall(function()
            for _, region in ipairs({ MinimapCluster:GetRegions() }) do
                KillObject(region)
            end
            for _, child in ipairs({ MinimapCluster:GetChildren() }) do
                if child ~= Minimap and child ~= MiniMapTrackingFrame and child ~= MiniMapMailFrame and child ~= GameTimeFrame then
                    KillObject(child)
                end
            end
            MinimapCluster:SetAlpha(0)
            MinimapCluster:EnableMouse(false)
            MinimapCluster:Hide()
            MinimapCluster.Show = function() end
        end)
    end

    -- Strip any decorative/border textures directly attached to Minimap itself
    pcall(function()
        for _, region in ipairs({ Minimap:GetRegions() }) do
            if region:IsObjectType("Texture") then
                local tex = region:GetTexture()
                if tex then
                    local str = tostring(tex):lower()
                    if str:find("border") or str:find("corner") or str:find("round") or str:find("circle") or str:find("ui%-minimap") or str:find("compass") then
                        KillObject(region)
                    end
                end
            end
        end

        for _, child in ipairs({ Minimap:GetChildren() }) do
            local cname = child:GetName() or ""
            if not cname:find("OneMiniMap") then
                local lname = cname:lower()
                if lname:find("border") or lname:find("backdrop") or lname:find("zoom") or lname:find("compass") or lname:find("tag") then
                    KillObject(child)
                end
            end
        end
    end)
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
    local parent = OneMiniMap.mapFrame or Minimap

    -- Tracking Icon (Binoculars / magnifying glass)
    local tracking = _G["MiniMapTracking"] or _G["MiniMapTrackingFrame"]
    if tracking then
        tracking:ClearAllPoints()
        tracking:SetParent(parent)
        tracking:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -6)
        tracking:SetScale(0.85)
    end

    -- Mail Notification Icon
    local mail = _G["MiniMapMailFrame"]
    if mail then
        mail:ClearAllPoints()
        mail:SetParent(parent)
        mail:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, -6)
        mail:SetScale(0.9)
    end

    -- Calendar / Game Time (Sun/Moon icon)
    local gameTime = _G["GameTimeFrame"]
    if gameTime then
        gameTime:ClearAllPoints()
        gameTime:SetParent(parent)
        gameTime:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 6, 6)
        gameTime:SetScale(0.7)
    end

    -- Looking For Group / Eye Icon
    local lfg = _G["MiniMapLFGFrame"] or _G["QueueStatusMinimapButton"]
    if lfg then
        lfg:ClearAllPoints()
        lfg:SetParent(parent)
        lfg:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 24, 6)
        lfg:SetScale(0.85)
    end

    -- Battleground / PvP Queue Icon
    local pvp = _G["MiniMapBattlefieldFrame"]
    if pvp then
        pvp:ClearAllPoints()
        pvp:SetParent(parent)
        pvp:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -6, 6)
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
    frame:SetSize(152, 152)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetFrameStrata("LOW")
    frame:EnableMouse(true)

    -- Background Marble/Slate Base
    ApplyBackdrop(frame, {
        bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
        tile = true,
        tileSize = 32,
    })
    if frame.SetBackdropColor then
        frame:SetBackdropColor(0.2, 0.2, 0.2, 0.98)
    end

    -- Reparent Minimap securely inside container
    Minimap:SetParent(frame)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    Minimap:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    Minimap:SetSize(140, 140)

    -- Elevated Border Overlay (FrameLevel + 10) matching OnePanel silver dialog border
    local borderOverlay = CreateFrame("Frame", nil, frame, backdropTemplate)
    borderOverlay:SetAllPoints(frame)
    borderOverlay:SetFrameLevel(frame:GetFrameLevel() + 10)
    borderOverlay:EnableMouse(false)

    ApplyBackdrop(borderOverlay, {
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    if borderOverlay.SetBackdropBorderColor then
        borderOverlay:SetBackdropBorderColor(0.75, 0.75, 0.75, 1.0) -- Silver / Metal edge
    end
    frame.BorderOverlay = borderOverlay

    ---------------------------------------------------------------------------
    -- Direct Dragging & Click Handling (Map Frame & Minimap)
    ---------------------------------------------------------------------------
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not OneMiniMapDB.locked then
            self:StartMoving()
            self.isMoving = true
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isMoving = false
        OneMiniMap:SavePositions()
    end)

    -- Allow clicking anywhere on Minimap to drag when unlocked
    Minimap:EnableMouse(true)
    Minimap:RegisterForDrag("LeftButton")
    Minimap:SetScript("OnDragStart", function(self)
        if not OneMiniMapDB.locked then
            frame:StartMoving()
            frame.isMoving = true
        end
    end)
    Minimap:SetScript("OnDragStop", function(self)
        frame:StopMovingOrSizing()
        frame.isMoving = false
        OneMiniMap:SavePositions()
    end)

    Minimap:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not OneMiniMapDB.locked then
            frame:StartMoving()
            frame.isMoving = true
        end
    end)
    Minimap:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and frame.isMoving then
            frame:StopMovingOrSizing()
            frame.isMoving = false
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
    frame:SetSize(152, 20)
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
    frame:SetSize(70, 20)
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
    frame:SetSize(78, 20)
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

    -- 1. Map Frame: Default TOPRIGHT of screen (-25, -50)
    Restore(self.mapFrame, OneMiniMapDB.mapPosition, function(f)
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -25, -50)
    end)

    -- 2. Title Frame: Default directly above Map Frame (0, 4)
    Restore(self.titleFrame, OneMiniMapDB.titlePosition, function(f)
        f:SetPoint("BOTTOM", self.mapFrame, "TOP", 0, 4)
    end)

    -- 3. Clock Frame: Default directly below Map Frame on the Left
    Restore(self.clockFrame, OneMiniMapDB.clockPosition, function(f)
        f:SetPoint("TOPLEFT", self.mapFrame, "BOTTOMLEFT", 0, -4)
    end)

    -- 4. Coordinates Frame: Default directly below Map Frame on the Right
    Restore(self.coordFrame, OneMiniMapDB.coordPosition, function(f)
        f:SetPoint("TOPRIGHT", self.mapFrame, "BOTTOMRIGHT", 0, -4)
    end)
end

-------------------------------------------------------------------------------
-- Diagnostic Inspector (/omm dump)
-------------------------------------------------------------------------------
function OneMiniMap:DumpInspection()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap Inspector Dump:|r")
    local function PrintInfo(prefix, frame)
        if not frame then return end
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  [%s] Name: %s, Shown: %s", prefix, frame:GetName() or "Anon", tostring(frame:IsShown())))
        if frame.GetRegions then
            for i, r in ipairs({ frame:GetRegions() }) do
                local tex = r.GetTexture and r:GetTexture()
                DEFAULT_CHAT_FRAME:AddMessage(string.format("    Region %d (%s): Shown=%s, Tex=%s", i, r:GetObjectType() or "?", tostring(r:IsShown()), tostring(tex)))
            end
        end
        if frame.GetChildren then
            for i, c in ipairs({ frame:GetChildren() }) do
                DEFAULT_CHAT_FRAME:AddMessage(string.format("    Child %d: Name=%s, Shown=%s", i, c:GetName() or "Anon", tostring(c:IsShown())))
            end
        end
    end

    PrintInfo("Minimap", Minimap)
    PrintInfo("MinimapBackdrop", _G["MinimapBackdrop"])
    PrintInfo("MinimapCluster", MinimapCluster)
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
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Frames are now |cff20ff20UNLOCKED|r. You can click & drag anywhere on the Map, Title, Clock, or Coords to move them.")
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
    elseif cmd == "dump" then
        OneMiniMap:DumpInspection()
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
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm dump|r - Print diagnostic frame inspector details")
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
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")

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
    elseif event:find("ZONE_CHANGED") then
        SuppressBlizzardChrome()
    end
end)
