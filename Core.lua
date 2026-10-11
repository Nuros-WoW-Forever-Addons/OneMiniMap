--[[
    OneMiniMap - Core.lua
    Modular Square MiniMap replacement with signature OneSuite metal frame styling,
    separate frameless translucent title bar, draggable clock frame,
    draggable coordinates frame, and button collector integration.
    Compatibility: Vanilla 1.12, Turtle WoW 1.16, WotLK 3.3.5, and Modern WoW.
--]]

local addonName, addonTable = ...

-- Global Namespace Export
_G.OneMiniMap = _G.OneMiniMap or addonTable
local OneMiniMap = _G.OneMiniMap

OneMiniMap.name = addonName or "OneMiniMap"
OneMiniMap.version = "0.3.8"
OneMiniMap.isInitialized = false

-- Default Database Configuration
local defaultDB = {
    locked = false,
    use24h = false,
    useServerTime = false,
    showTitle = true,
    showClock = true,
    showCoords = true,
    showButtons = true,
    buttonCols = 1,
    scale = 1.0,
    mapPosition = nil,
    titlePosition = nil,
    clockPosition = nil,
    coordPosition = nil,
    buttonCollectorPosition = nil,
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
-------------------------------------------------------------------------------
-- Direct Minimap Zoom Handling (Wheel & Clicks)
-------------------------------------------------------------------------------
local function UpdateZoomButtonStates()
    if not Minimap or not Minimap.GetZoom then return end
    local curr = Minimap:GetZoom() or 0
    local maxZoom = (Minimap.GetZoomLevels and Minimap:GetZoomLevels() - 1) or 5
    local zIn = (Minimap and Minimap.ZoomIn) or _G["MinimapZoomIn"]
    local zOut = (Minimap and Minimap.ZoomOut) or _G["MinimapZoomOut"]
    if zIn and zIn.Enable and zIn.Disable then
        if curr >= maxZoom then zIn:Disable() else zIn:Enable() end
    end
    if zOut and zOut.Enable and zOut.Disable then
        if curr <= 0 then zOut:Disable() else zOut:Enable() end
    end
end

local function DoZoom(delta)
    if not Minimap or not Minimap.GetZoom then return end
    local curr = Minimap:GetZoom() or 0
    local maxZoom = (Minimap.GetZoomLevels and Minimap:GetZoomLevels() - 1) or 5

    if delta > 0 then
        if curr < maxZoom then
            Minimap:SetZoom(curr + 1)
        end
    elseif delta < 0 then
        if curr > 0 then
            Minimap:SetZoom(curr - 1)
        end
    end
    UpdateZoomButtonStates()
end

local function SetupZoomHandling()
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(self, delta)
        DoZoom(delta)
    end)

    if OneMiniMap.mapFrame then
        OneMiniMap.mapFrame:EnableMouseWheel(true)
        OneMiniMap.mapFrame:SetScript("OnMouseWheel", function(self, delta)
            DoZoom(delta)
        end)
    end

    -- Global zoom function overrides
    Minimap_ZoomIn = function() DoZoom(1) end
    Minimap_ZoomOut = function() DoZoom(-1) end
    Minimap_ZoomInClick = function() DoZoom(1) end
    Minimap_ZoomOutClick = function() DoZoom(-1) end
end

-------------------------------------------------------------------------------
-- Action Bar Paging Protection
-------------------------------------------------------------------------------
local function ProtectActionBars()
    -- Disable mouse wheel paging on MainMenuBar to prevent accidental page flipping
    if MainMenuBar and MainMenuBar.EnableMouseWheel then
        MainMenuBar:EnableMouseWheel(false)
    end

    -- If the player's action bar was accidentally paged, reset it to page 1
    if CURRENT_ACTIONBAR_PAGE and CURRENT_ACTIONBAR_PAGE ~= 1 and ChangeActionBarPage then
        ChangeActionBarPage(1)
    end
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
    -- Known Blizzard Minimap frames and textures (covering all capitalizations)
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
        "MiniMapWorldMapButton",
        "TimeManagerClockButton",
        "MinimapNorthTag",
        "MinimapCompassTexture",
        "MinimapZoomIn",
        "MinimapZoomOut",
        "MiniMapZoomIn",
        "MiniMapZoomOut",
    }

    for _, frameName in ipairs(framesToHide) do
        KillObject(_G[frameName])
    end

    if Minimap then
        KillObject(Minimap.ZoomIn)
        KillObject(Minimap.ZoomOut)
    end
    if MinimapCluster then
        KillObject(MinimapCluster.ZoomIn)
        KillObject(MinimapCluster.ZoomOut)
    end

    -- Neutralize MinimapBackdrop
    local mb = _G["MinimapBackdrop"] or _G["MiniMapBackdrop"]
    if mb then
        pcall(function()
            KillObject(mb)
            for _, r in ipairs({ mb:GetRegions() }) do KillObject(r) end
            for _, c in ipairs({ mb:GetChildren() }) do KillObject(c) end
        end)
    end

    -- Neutralize MinimapCluster regions & non-essential children
    if MinimapCluster then
        pcall(function()
            for _, region in ipairs({ MinimapCluster:GetRegions() }) do KillObject(region) end
            for _, child in ipairs({ MinimapCluster:GetChildren() }) do
                local cname = (child.GetName and child:GetName()) or ""
                local isEssential = (child == Minimap)
                    or (child == MiniMapTrackingFrame)
                    or (child == _G["MiniMapTracking"])
                    or (MinimapCluster.Tracking and child == MinimapCluster.Tracking)
                    or (child == MiniMapMailFrame)
                    or (MinimapCluster.IndicatorFrame and child == MinimapCluster.IndicatorFrame)
                    or (child == GameTimeFrame)
                    or (child == _G["QueueStatusMinimapButton"])
                    or (cname:find("^OneMiniMap") ~= nil)
                if not isEssential then
                    KillObject(child)
                end
            end
            MinimapCluster:SetAlpha(0)
            MinimapCluster:EnableMouse(false)
            MinimapCluster:Hide()
            MinimapCluster.Show = function() end
        end)
    end

    -- Strip decorative/border textures directly attached to Minimap itself
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
            if not cname:find("^OneMiniMap") then
                local lname = cname:lower()
                if lname:find("border") or lname:find("backdrop") or lname:find("compass") or lname:find("tag") then
                    KillObject(child)
                end
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- Frame 1: Square MiniMap Metal Frame Container
-------------------------------------------------------------------------------
function OneMiniMap:CreateMapFrame()
    if self.mapFrame then return self.mapFrame end

    local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "OneMiniMapFrame", UIParent, backdropTemplate)
    frame:SetSize(222, 222)
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
    Minimap:SetSize(210, 210)

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
        OneMiniMap:SaveMapPosition()
    end)

    -- Capture original Minimap click / mouseup handler (for pings)
    local orig_Minimap_OnMouseUp = Minimap:GetScript("OnMouseUp")
    local isDraggingMap = false

    local function PingMinimap(mapSelf)
        local x, y = GetCursorPosition()
        local scale = mapSelf:GetEffectiveScale()
        if scale and scale > 0 then
            x = x / scale
            y = y / scale
        end
        local cx, cy = mapSelf:GetCenter()
        if not cx or not cy then return end

        local ox = CURSOR_OFFSET_X or 0
        local oy = CURSOR_OFFSET_Y or 0
        x = x + ox - cx
        y = y + oy - cy

        -- Square minimap boundary check
        local halfW = (mapSelf:GetWidth() or 210) / 2
        local halfH = (mapSelf:GetHeight() or 210) / 2
        if math.abs(x) <= halfW and math.abs(y) <= halfH then
            if mapSelf.PingLocation then
                mapSelf:PingLocation(x, y)
            elseif Minimap.PingLocation then
                Minimap:PingLocation(x, y)
            elseif orig_Minimap_OnMouseUp then
                orig_Minimap_OnMouseUp(mapSelf, "LeftButton")
            elseif Minimap_OnClick then
                Minimap_OnClick(mapSelf)
            end
        end
    end

    -- Allow dragging anywhere on Minimap when unlocked, pinging on stationary left-click
    Minimap:EnableMouse(true)
    Minimap:RegisterForDrag("LeftButton")
    Minimap:SetScript("OnDragStart", function(self)
        if not OneMiniMapDB.locked then
            frame:StartMoving()
            isDraggingMap = true
        end
    end)
    Minimap:SetScript("OnDragStop", function(self)
        if isDraggingMap then
            frame:StopMovingOrSizing()
            isDraggingMap = false
            OneMiniMap:SaveMapPosition()
        end
    end)

    Minimap:SetScript("OnMouseDown", function(self, button)
        isDraggingMap = false
    end)
    Minimap:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            if isDraggingMap then
                frame:StopMovingOrSizing()
                isDraggingMap = false
                OneMiniMap:SaveMapPosition()
            else
                -- Stationary click: drop map ping at clicked coordinates!
                PingMinimap(self)
            end
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
    frame:SetSize(222, 22)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetFrameStrata("MEDIUM")
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
        local point, _, relPoint, xOfs, yOfs = self:GetPoint()
        OneMiniMapDB.titlePosition = {
            point = point or "TOPRIGHT",
            relPoint = relPoint or "TOPRIGHT",
            x = math.floor((xOfs or 0) + 0.5),
            y = math.floor((yOfs or 0) + 0.5),
        }
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
    frame:SetSize(109, 22)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetFrameStrata("MEDIUM")
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

    -- Clicks: Left-Click toggles 12h/24h (or Shift-Click opens Time Manager), Right-Click toggles Local/Server time
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            local newMode = not OneMiniMapDB.useServerTime
            OneMiniMap:SetServerTime(newMode)
            local modeStr = newMode and "Server Time" or "Local Time"
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Clock set to " .. modeStr .. ".")
        else
            if IsShiftKeyDown and IsShiftKeyDown() and ToggleTimeManager then
                ToggleTimeManager()
            else
                local new24 = not OneMiniMapDB.use24h
                OneMiniMap:Set24Hour(new24)
                local modeStr = new24 and "24-hour" or "12-hour"
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Clock set to " .. modeStr .. " mode.")
            end
        end
    end)

    -- Tooltip on Hover
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(TIMEMANAGER_TOOLTIP_TITLE or "Clock", 1, 1, 1)

        local fmtTime = function(h, m)
            if OneMiniMapDB.use24h then
                return string.format("%02d:%02d", h, m)
            else
                local suffix = (h >= 12) and "PM" or "AM"
                local h12 = h % 12
                if h12 == 0 then h12 = 12 end
                return string.format("%d:%02d %s", h12, m, suffix)
            end
        end

        local d = date("*t")
        local localH, localM = d.hour, d.min
        local srvH, srvM
        if GetGameTime then
            srvH, srvM = GetGameTime()
        end
        if not srvH or not srvM then
            srvH, srvM = localH, localM
        end

        local isServer = OneMiniMapDB.useServerTime
        local localTag = isServer and "" or " |cff20ff20(Active)|r"
        local serverTag = isServer and " |cff20ff20(Active)|r" or ""

        local localLabel = TIMEMANAGER_TOOLTIP_LOCALTIME or "Local Time:"
        local serverLabel = TIMEMANAGER_TOOLTIP_REALMTIME or "Server Time:"

        GameTooltip:AddDoubleLine(localLabel, fmtTime(localH, localM) .. localTag, 1, 1, 1, 0.9, 0.9, 0.9)
        GameTooltip:AddDoubleLine(serverLabel, fmtTime(srvH, srvM) .. serverTag, 1, 1, 1, 0.9, 0.9, 0.9)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ccffLeft-Click|r: Toggle 12h / 24h format", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("|cff00ccffRight-Click|r: Toggle Local / Server time", 0.7, 0.7, 0.7)
        if ToggleTimeManager then
            GameTooltip:AddLine("|cff00ccffShift-Click|r: Open Game Time Manager", 0.7, 0.7, 0.7)
        end
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
        local point, _, relPoint, xOfs, yOfs = self:GetPoint()
        OneMiniMapDB.clockPosition = {
            point = point or "TOPRIGHT",
            relPoint = relPoint or "TOPRIGHT",
            x = math.floor((xOfs or 0) + 0.5),
            y = math.floor((yOfs or 0) + 0.5),
        }
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
    frame:SetSize(109, 22)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetFrameStrata("MEDIUM")
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
        local point, _, relPoint, xOfs, yOfs = self:GetPoint()
        OneMiniMapDB.coordPosition = {
            point = point or "TOPRIGHT",
            relPoint = relPoint or "TOPRIGHT",
            x = math.floor((xOfs or 0) + 0.5),
            y = math.floor((yOfs or 0) + 0.5),
        }
    end)

    self.coordFrame = frame
    return frame
end

-------------------------------------------------------------------------------
-- Helper: Clock & Time Settings (Blizzard CVar Sync)
-------------------------------------------------------------------------------
function OneMiniMap:SetServerTime(useServer)
    OneMiniMapDB = OneMiniMapDB or {}
    OneMiniMapDB.useServerTime = useServer and true or false
    if SetCVar and GetCVar and GetCVar("timeMgrUseLocalTime") ~= nil then
        pcall(SetCVar, "timeMgrUseLocalTime", OneMiniMapDB.useServerTime and "0" or "1")
    end
    self:UpdateClock()
end

function OneMiniMap:Set24Hour(use24h)
    OneMiniMapDB = OneMiniMapDB or {}
    OneMiniMapDB.use24h = use24h and true or false
    if SetCVar and GetCVar and GetCVar("timeMgrUseMilitaryTime") ~= nil then
        pcall(SetCVar, "timeMgrUseMilitaryTime", OneMiniMapDB.use24h and "1" or "0")
    end
    self:UpdateClock()
end

-------------------------------------------------------------------------------
-- Update Routines (Clock, Coordinates, Zone)
-------------------------------------------------------------------------------
function OneMiniMap:UpdateClock()
    if not self.clockText then return end

    local hours, minutes
    if OneMiniMapDB.useServerTime and GetGameTime then
        hours, minutes = GetGameTime()
    end
    if not hours or not minutes then
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
function OneMiniMap:SaveMapPosition()
    if not self.mapFrame then return end
    local point, _, relPoint, xOfs, yOfs = self.mapFrame:GetPoint()
    OneMiniMapDB = OneMiniMapDB or {}
    OneMiniMapDB.mapPosition = {
        point = point or "TOPRIGHT",
        relPoint = relPoint or "TOPRIGHT",
        x = math.floor((xOfs or 0) + 0.5),
        y = math.floor((yOfs or 0) + 0.5),
    }
end

function OneMiniMap:RestorePositions()
    -- 1. Map Frame: Default TOPRIGHT of screen (-25, -70)
    self.mapFrame:ClearAllPoints()
    if OneMiniMapDB.mapPosition then
        local pos = OneMiniMapDB.mapPosition
        self.mapFrame:SetPoint(pos.point or "TOPRIGHT", UIParent, pos.relPoint or "TOPRIGHT", pos.x or -25, pos.y or -70)
    else
        self.mapFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -25, -70)
    end

    -- 2. Title Frame: Attached directly above Map Frame unless independently moved
    self.titleFrame:ClearAllPoints()
    if OneMiniMapDB.titlePosition then
        local pos = OneMiniMapDB.titlePosition
        self.titleFrame:SetPoint(pos.point or "TOPRIGHT", UIParent, pos.relPoint or "TOPRIGHT", pos.x, pos.y)
    else
        self.titleFrame:SetPoint("BOTTOM", self.mapFrame, "TOP", 0, 4)
    end

    -- 3. Clock Frame: Attached above Title Frame on the Left unless independently moved
    self.clockFrame:ClearAllPoints()
    if OneMiniMapDB.clockPosition then
        local pos = OneMiniMapDB.clockPosition
        self.clockFrame:SetPoint(pos.point or "TOPRIGHT", UIParent, pos.relPoint or "TOPRIGHT", pos.x, pos.y)
    else
        self.clockFrame:SetPoint("BOTTOMLEFT", self.titleFrame, "TOPLEFT", 0, 4)
    end

    -- 4. Coordinates Frame: Attached above Title Frame on the Right unless independently moved
    self.coordFrame:ClearAllPoints()
    if OneMiniMapDB.coordPosition then
        local pos = OneMiniMapDB.coordPosition
        self.coordFrame:SetPoint(pos.point or "TOPRIGHT", UIParent, pos.relPoint or "TOPRIGHT", pos.x, pos.y)
    else
        self.coordFrame:SetPoint("BOTTOMRIGHT", self.titleFrame, "TOPRIGHT", 0, 4)
    end

    -- 5. Button Collector
    if self.ButtonCollector and self.ButtonCollector.RestorePosition then
        self.ButtonCollector:RestorePosition()
    end

    -- 6. Options Window
    if self.OptionsUI and self.OptionsUI.RestorePosition then
        self.OptionsUI:RestorePosition()
    end
end

-------------------------------------------------------------------------------
-- Dynamic Scale Controller
-------------------------------------------------------------------------------
function OneMiniMap:SetScale(s)
    s = tonumber(s) or 1.0
    if s < 0.5 then s = 0.5 end
    if s > 2.0 then s = 2.0 end
    OneMiniMapDB = OneMiniMapDB or {}
    OneMiniMapDB.scale = s
    if self.mapFrame then self.mapFrame:SetScale(s) end
    if self.titleFrame then self.titleFrame:SetScale(s) end
    if self.clockFrame then self.clockFrame:SetScale(s) end
    if self.coordFrame then self.coordFrame:SetScale(s) end
    if self.ButtonCollector and self.ButtonCollector.frame then
        self.ButtonCollector.frame:SetScale(s)
    end
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
            if k == "useServerTime" and GetCVar and GetCVar("timeMgrUseLocalTime") ~= nil then
                OneMiniMapDB.useServerTime = (GetCVar("timeMgrUseLocalTime") == "0")
            elseif k == "use24h" and GetCVar and GetCVar("timeMgrUseMilitaryTime") ~= nil then
                OneMiniMapDB.use24h = (GetCVar("timeMgrUseMilitaryTime") == "1")
            else
                OneMiniMapDB[k] = v
            end
        end
    end

    -- Setup Square Mask & Suppress Blizzard Chrome
    SetupSquareMask()
    SuppressBlizzardChrome()
    SetupZoomHandling()
    ProtectActionBars()

    -- Create Independent Modular Frames
    self:CreateMapFrame()
    self:CreateTitleFrame()
    self:CreateClockFrame()
    self:CreateCoordFrame()

    -- Ensure Zoom Handling is fully wired to Map Frame
    SetupZoomHandling()

    -- Initialize Button Collector
    if self.ButtonCollector and self.ButtonCollector.Initialize then
        self.ButtonCollector:Initialize()
    end

    -- Initialize Options UI
    if self.OptionsUI and self.OptionsUI.Initialize then
        self.OptionsUI:Initialize()
    end

    -- Restore Independent Positions
    self:RestorePositions()

    -- Visibility States
    self.titleFrame:SetShown(OneMiniMapDB.showTitle)
    self.clockFrame:SetShown(OneMiniMapDB.showClock)
    self.coordFrame:SetShown(OneMiniMapDB.showCoords)

    -- Apply Scale
    self:SetScale(OneMiniMapDB.scale or 1.0)

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
    cmd = cmd or ""

    if cmd == "" or cmd == "options" or cmd == "opt" or cmd == "config" or cmd == "ui" then
        if OneMiniMap.ToggleOptions then
            OneMiniMap:ToggleOptions()
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Type |cffffd200/omm help|r for command list.")
        end
    elseif cmd == "lock" then
        OneMiniMapDB.locked = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Frames are now |cffff2020LOCKED|r.")
    elseif cmd == "unlock" then
        OneMiniMapDB.locked = false
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Frames are now |cff20ff20UNLOCKED|r. You can click & drag anywhere on the Map, Title, Clock, Coords, or Button Bar to move them.")
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
    elseif cmd == "time" or cmd == "servertime" or cmd == "localtime" then
        local newMode = not OneMiniMapDB.useServerTime
        OneMiniMap:SetServerTime(newMode)
        local modeStr = newMode and "Server Time" or "Local Time"
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Clock set to " .. modeStr .. ".")
    elseif cmd == "title" then
        OneMiniMapDB.showTitle = not OneMiniMapDB.showTitle
        if OneMiniMap.titleFrame then
            OneMiniMap.titleFrame:SetShown(OneMiniMapDB.showTitle)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Title bar toggled " .. (OneMiniMapDB.showTitle and "|cff20ff20ON|r" or "|cffff2020OFF|r") .. ".")
    elseif cmd == "buttons" or cmd == "bar" then
        if OneMiniMap.ButtonCollector and OneMiniMap.ButtonCollector.frame then
            local isShown = OneMiniMap.ButtonCollector.frame:IsShown()
            OneMiniMap.ButtonCollector.frame:SetShown(not isShown)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Button Collector toggled " .. (not isShown and "|cff20ff20ON|r" or "|cffff2020OFF|r") .. ".")
        end
    elseif cmd == "page1" or cmd == "resetbars" then
        if ChangeActionBarPage then
            ChangeActionBarPage(1)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Action bar reset to Page 1.")
    elseif cmd == "dump" then
        OneMiniMap:DumpInspection()
    elseif cmd == "reset" then
        OneMiniMapDB.mapPosition = nil
        OneMiniMapDB.titlePosition = nil
        OneMiniMapDB.clockPosition = nil
        OneMiniMapDB.coordPosition = nil
        OneMiniMapDB.buttonCollectorPosition = nil
        OneMiniMapDB.optionsPosition = nil
        OneMiniMap:RestorePositions()
        if OneMiniMap.ButtonCollector and OneMiniMap.ButtonCollector.Update then
            OneMiniMap.ButtonCollector:Update()
        end
        if OneMiniMap.OptionsUI and OneMiniMap.OptionsUI.RestorePosition then
            OneMiniMap.OptionsUI:RestorePosition()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: All positions reset to defaults.")
    elseif cmd == "scale" and tonumber(arg) then
        local s = tonumber(arg)
        if s and s >= 0.5 and s <= 2.0 then
            OneMiniMap:SetScale(s)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Scale set to " .. string.format("%.0f%%", s * 100) .. ".")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Scale must be between 0.5 and 2.0.")
        end
    elseif cmd == "test" or cmd == "testbuttons" then
        OneMiniMapDB.testMode = not OneMiniMapDB.testMode
        if OneMiniMap.ButtonCollector and OneMiniMap.ButtonCollector.Update then
            OneMiniMap.ButtonCollector:Update()
        end
        local st = OneMiniMapDB.testMode and "|cff20ff20ON (12 buttons, 2 columns)|r" or "|cffff2020OFF|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Test mode " .. st .. ".")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm lock|r - Lock all frame positions")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm unlock|r - Unlock all frames for dragging")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm title|r - Toggle title bar frame")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm clock|r - Toggle clock frame")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm time|r - Toggle Local vs Server time")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm coords|r - Toggle coordinates frame")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm buttons|r - Toggle button collector frame")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm page1|r - Reset action bar back to Page 1")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm dump|r - Print diagnostic frame inspector details")
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
eventFrame:RegisterEvent("CVAR_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "OneMiniMap" then
        OneMiniMap:Initialize()
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if not OneMiniMap.isInitialized then
            OneMiniMap:Initialize()
        else
            SuppressBlizzardChrome()
            SetupZoomHandling()
            ProtectActionBars()
            if OneMiniMap.ButtonCollector and OneMiniMap.ButtonCollector.Update then
                OneMiniMap.ButtonCollector:Update()
            end
        end
    elseif event == "CVAR_UPDATE" then
        if arg1 == "timeMgrUseLocalTime" or arg1 == "TIME_MGR_USE_LOCAL_TIME" then
            if GetCVar then
                local val = GetCVar("timeMgrUseLocalTime")
                if val ~= nil then
                    OneMiniMapDB.useServerTime = (val == "0")
                    OneMiniMap:UpdateClock()
                end
            end
        elseif arg1 == "timeMgrUseMilitaryTime" or arg1 == "TIME_MGR_USE_MILITARY_TIME" then
            if GetCVar then
                local val = GetCVar("timeMgrUseMilitaryTime")
                if val ~= nil then
                    OneMiniMapDB.use24h = (val == "1")
                    OneMiniMap:UpdateClock()
                end
            end
        end
    elseif event:find("ZONE_CHANGED") then
        SuppressBlizzardChrome()
        if SetMapToCurrentZone then
            SetMapToCurrentZone()
        end
    end
end)
