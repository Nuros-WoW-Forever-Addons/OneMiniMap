--[[
    OneMiniMap - Core.lua
    Lightweight Square MiniMap replacement with signature metal frame styling,
    top coordinates, mouse wheel zoom, and position memory.
    Compatibility: Vanilla 1.12, Turtle WoW 1.16, WotLK 3.3.5, and Modern WoW.
--]]

local addonName, addonTable = ...

-- Global Namespace Export
_G.OneMiniMap = _G.OneMiniMap or addonTable
local OneMiniMap = _G.OneMiniMap

OneMiniMap.name = addonName or "OneMiniMap"
OneMiniMap.version = "0.1.0"
OneMiniMap.isInitialized = false

-- Default Database
local defaultDB = {
    locked = false,
    showCoords = true,
    showZone = true,
    scale = 1.0,
    position = nil,
}

-------------------------------------------------------------------------------
-- Helper: Safe Backdrop Application across all WoW client generations
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
-- Square Mask & Shape Override
-------------------------------------------------------------------------------
local function SetupSquareMask()
    -- Apply square mask to circular Minimap
    if Minimap.SetMaskTexture then
        Minimap:SetMaskTexture("Interface\\BUTTONS\\WHITE8X8")
    end

    -- Tell other addons (Gatherer, Questie, TomTom, Cartographer) the map is SQUARE
    -- so edge blip calculations wrap squarely instead of circularly
    function GetMinimapShape()
        return "SQUARE"
    end
end

-------------------------------------------------------------------------------
-- Blizzard Chrome Suppression
-------------------------------------------------------------------------------
local function SuppressBlizzardChrome()
    local framesToHide = {
        "MinimapBorder",
        "MinimapBorderTop",
        "MinimapZoneTextButton",
        "MinimapToggleButton",
        "MinimapZoomIn",
        "MinimapZoomOut",
        "MiniMapWorldMapButton",
    }

    for _, frameName in ipairs(framesToHide) do
        local f = _G[frameName]
        if f then
            f:Hide()
            if f.UnregisterAllEvents then
                f:UnregisterAllEvents()
            end
            f.Show = function() end
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
-- Peripheral Minimap Buttons Alignment
-------------------------------------------------------------------------------
local function RepositionMinimapButtons()
    -- Tracking Icon (Magnifying glass / binoculars)
    local tracking = _G["MiniMapTracking"] or _G["MiniMapTrackingFrame"]
    if tracking then
        tracking:ClearAllPoints()
        tracking:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -2, 2)
        tracking:SetScale(0.85)
    end

    -- Mail Notification Icon
    local mail = _G["MiniMapMailFrame"]
    if mail then
        mail:ClearAllPoints()
        mail:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 2, 2)
        mail:SetScale(0.9)
    end

    -- Calendar / Game Time Frame
    local gameTime = _G["GameTimeFrame"]
    if gameTime then
        gameTime:ClearAllPoints()
        gameTime:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -2, -2)
        gameTime:SetScale(0.7)
    end

    -- Time Manager Clock Button (3.3.5 / Cataclysm / Modern)
    local clock = _G["TimeManagerClockButton"]
    if clock then
        clock:ClearAllPoints()
        clock:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, -2)
    end

    -- Looking For Group / Eye Icon
    local lfg = _G["MiniMapLFGFrame"] or _G["QueueStatusMinimapButton"]
    if lfg then
        lfg:ClearAllPoints()
        lfg:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -2, -2)
        lfg:SetScale(0.85)
    end

    -- Battleground / PvP Queue Icon
    local pvp = _G["MiniMapBattlefieldFrame"]
    if pvp then
        pvp:ClearAllPoints()
        pvp:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 2, -2)
        pvp:SetScale(0.85)
    end
end

-------------------------------------------------------------------------------
-- Master Metal Frame & Top Header Creation
-------------------------------------------------------------------------------
function OneMiniMap:CreateMasterFrame()
    if self.frame then return self.frame end

    local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "OneMiniMapFrame", UIParent, backdropTemplate)
    frame:SetSize(152, 176)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetFrameStrata("LOW")

    -- Metal Frame Styling (Signature OnePanel & OneStorage DialogBox-Border with marble/slate)
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
        frame:SetBackdropBorderColor(0.75, 0.75, 0.75, 1.0) -- Silver / Metal border
    end

    -- Deep Slate Header Background
    local headerBg = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
    headerBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    headerBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    headerBg:SetHeight(23)
    if headerBg.SetColorTexture then
        headerBg:SetColorTexture(0.08, 0.09, 0.12, 0.95)
    else
        headerBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        headerBg:SetVertexColor(0.08, 0.09, 0.12, 0.95)
    end

    -- Metal Header Divider Line
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -27)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -27)
    divider:SetHeight(1)
    if divider.SetColorTexture then
        divider:SetColorTexture(0.5, 0.5, 0.5, 0.6)
    else
        divider:SetTexture("Interface\\Buttons\\WHITE8X8")
        divider:SetVertexColor(0.5, 0.5, 0.5, 0.6)
    end

    ---------------------------------------------------------------------------
    -- Top Header Bar (Houses Zone Text & Top Coordinates)
    ---------------------------------------------------------------------------
    local header = CreateFrame("Button", "OneMiniMapHeader", frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -5)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -5)
    header:SetHeight(22)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")

    -- Top Coordinates Text (Right-aligned, gold coordinates)
    local coordText = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    coordText:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    coordText:SetJustifyH("RIGHT")
    coordText:SetText("|cffffd200--.-, --.-|r")
    self.coordText = coordText

    -- Top Zone Name Text (Left-aligned, automatically truncated before coordinates)
    local zoneText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoneText:SetPoint("LEFT", header, "LEFT", 4, 0)
    zoneText:SetPoint("RIGHT", coordText, "LEFT", -4, 0)
    zoneText:SetJustifyH("LEFT")
    zoneText:SetText(GetZoneText() or "World of Warcraft")
    self.zoneText = zoneText

    -- Left-click Header: Toggle World Map
    header:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if ToggleWorldMap then
                ToggleWorldMap()
            elseif WorldMapFrame then
                ToggleFrame(WorldMapFrame)
            end
        end
    end)

    -- Tooltip on Header hover showing subzone details
    header:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:ClearLines()
        local zone = GetZoneText() or ""
        local subZone = GetSubZoneText() or ""
        GameTooltip:AddLine(zone, 1, 1, 1)
        if subZone ~= "" and subZone ~= zone then
            GameTooltip:AddLine(subZone, 0.8, 0.8, 0.8)
        end
        local pvpType, isSubZonePvP, factionName = GetZonePVPInfo and GetZonePVPInfo()
        if pvpType then
            local r, g, b = GetZoneColor()
            GameTooltip:AddLine(pvpType:upper(), r, g, b)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ccffClick|r to open World Map", 0.7, 0.7, 0.7)
        if not OneMiniMapDB.locked then
            GameTooltip:AddLine("|cff00ccffDrag|r header to move MiniMap", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    header:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Header Dragging
    header:SetScript("OnDragStart", function()
        if not OneMiniMapDB.locked then
            frame:StartMoving()
        end
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        OneMiniMap:SavePosition()
    end)

    ---------------------------------------------------------------------------
    -- Minimap Reparenting & Flush Square Anchoring
    ---------------------------------------------------------------------------
    Minimap:SetParent(frame)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -29)
    Minimap:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    Minimap:SetSize(140, 140)

    -- Alt+Drag on Minimap itself to move when unlocked
    Minimap:EnableMouse(true)
    Minimap:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsAltKeyDown() and not OneMiniMapDB.locked then
            frame:StartMoving()
        end
    end)
    Minimap:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            frame:StopMovingOrSizing()
            OneMiniMap:SavePosition()
        end
    end)

    ---------------------------------------------------------------------------
    -- Throttled Update Ticker: Coordinates & Zone
    ---------------------------------------------------------------------------
    local updateElapsed = 0
    local UPDATE_INTERVAL = 0.15

    frame:SetScript("OnUpdate", function(self, elapsed)
        updateElapsed = updateElapsed + elapsed
        if updateElapsed < UPDATE_INTERVAL then return end
        updateElapsed = 0

        -- Update Live Coordinates
        if OneMiniMapDB.showCoords and OneMiniMap.coordText then
            local x, y = OneMiniMap:GetPlayerCoordinates()
            if x and y then
                OneMiniMap.coordText:SetText(string.format("|cffffd200%.1f, %.1f|r", x, y))
            else
                OneMiniMap.coordText:SetText("|cff777777--.-, --.-|r")
            end
        end

        -- Update Zone Text & PvP Coloring
        if OneMiniMapDB.showZone and OneMiniMap.zoneText then
            local subZone = (GetSubZoneText and GetSubZoneText()) or ""
            local zone = (GetZoneText and GetZoneText()) or ""
            local display = (subZone ~= "" and subZone) or zone
            if display ~= "" then
                local r, g, b = GetZoneColor()
                OneMiniMap.zoneText:SetTextColor(r, g, b)
                OneMiniMap.zoneText:SetText(display)
            end
        end
    end)

    self.frame = frame
    return frame
end

-------------------------------------------------------------------------------
-- Position Persistence
-------------------------------------------------------------------------------
function OneMiniMap:SavePosition()
    if not self.frame then return end
    local point, _, relPoint, xOfs, yOfs = self.frame:GetPoint()
    OneMiniMapDB = OneMiniMapDB or {}
    OneMiniMapDB.position = {
        point = point or "TOPRIGHT",
        relPoint = relPoint or "TOPRIGHT",
        x = math.floor((xOfs or -16) + 0.5),
        y = math.floor((yOfs or -16) + 0.5),
    }
end

function OneMiniMap:RestorePosition()
    if not self.frame then return end
    self.frame:ClearAllPoints()
    if OneMiniMapDB and OneMiniMapDB.position then
        local pos = OneMiniMapDB.position
        self.frame:SetPoint(pos.point or "TOPRIGHT", UIParent, pos.relPoint or "TOPRIGHT", pos.x or -16, pos.y or -16)
    else
        self.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -16)
    end
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

    -- Setup Square MiniMap
    SetupSquareMask()
    SuppressBlizzardChrome()
    SetupMouseWheelZoom()

    -- Create Metal Frame & Header
    self:CreateMasterFrame()
    self:RestorePosition()
    RepositionMinimapButtons()

    if OneMiniMapDB.scale and OneMiniMapDB.scale ~= 1.0 then
        self.frame:SetScale(OneMiniMapDB.scale)
    end

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
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Position is now |cffff2020LOCKED|r.")
    elseif cmd == "unlock" then
        OneMiniMapDB.locked = false
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Position is now |cff20ff20UNLOCKED|r (drag header or Alt+Drag to move).")
    elseif cmd == "coords" then
        OneMiniMapDB.showCoords = not OneMiniMapDB.showCoords
        if OneMiniMap.coordText then
            OneMiniMap.coordText:SetShown(OneMiniMapDB.showCoords)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Coordinates toggled " .. (OneMiniMapDB.showCoords and "|cff20ff20ON|r" or "|cffff2020OFF|r") .. ".")
    elseif cmd == "reset" then
        OneMiniMapDB.position = nil
        OneMiniMap:RestorePosition()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Position reset to top-right.")
    elseif cmd == "scale" and tonumber(arg) then
        local s = tonumber(arg)
        if s and s >= 0.5 and s <= 2.0 then
            OneMiniMapDB.scale = s
            if OneMiniMap.frame then
                OneMiniMap.frame:SetScale(s)
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Scale set to " .. s .. ".")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Scale must be between 0.5 and 2.0.")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm lock|r - Lock minimap position")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm unlock|r - Unlock minimap position (drag header or Alt+Drag)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm coords|r - Toggle top coordinates display")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm scale <number>|r - Set minimap scale (0.5 to 2.0)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffd200/omm reset|r - Reset position to default")
    end
end

-------------------------------------------------------------------------------
-- Event Dispatcher
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "OneMiniMap" then
        OneMiniMap:Initialize()
    elseif event == "PLAYER_LOGIN" then
        if not OneMiniMap.isInitialized then
            OneMiniMap:Initialize()
        end
        RepositionMinimapButtons()
    end
end)
