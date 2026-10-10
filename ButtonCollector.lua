--[[
    OneMiniMap - ButtonCollector.lua
    Organizes minimap buttons into neat, configurable vertical columns
    docked next to the square minimap or freely draggable.
    Compatibility: Vanilla 1.12, Turtle WoW 1.16, WotLK 3.3.5, and Modern WoW.
--]]

local addonName, addonTable = ...
local OneMiniMap = _G.OneMiniMap or addonTable

OneMiniMap.ButtonCollector = {}
local BC = OneMiniMap.ButtonCollector

BC.buttons = {}
BC.frame = nil

-------------------------------------------------------------------------------
-- Helper: Safe Background Creator
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
-- Create Button Collector Frame
-------------------------------------------------------------------------------
function BC:CreateFrame()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "OneMiniMapButtonCollector", UIParent)
    frame:SetSize(36, 36)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    -- Frameless Translucent Black Background
    CreateTranslucentBackground(frame, 0.65)

    -- Dragging
    frame:SetScript("OnDragStart", function(self)
        if not OneMiniMapDB or not OneMiniMapDB.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if OneMiniMapDB then
            local point, _, relPoint, xOfs, yOfs = self:GetPoint()
            OneMiniMapDB.buttonCollectorPosition = {
                point = point or "TOPRIGHT",
                relPoint = relPoint or "TOPRIGHT",
                x = math.floor((xOfs or 0) + 0.5),
                y = math.floor((yOfs or 0) + 0.5),
            }
        end
    end)

    -- Tooltip on Hover
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Minimap Buttons", 1, 1, 1)
        if not OneMiniMapDB or not OneMiniMapDB.locked then
            GameTooltip:AddLine("|cff00ccffDrag|r to reposition Button Bar", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.frame = frame
    return frame
end

-------------------------------------------------------------------------------
-- Scan & Layout Buttons
-------------------------------------------------------------------------------
function BC:Update()
    if not self.frame then self:CreateFrame() end

    local collected = {}
    local seen = {}

    local function AddButton(btn)
        if not btn then return end
        if seen[btn] then return end
        local name = btn:GetName() or ""

        -- Ignore OneMiniMap's internal frames, zoom buttons, and world map button
        if name:find("^OneMiniMap") or name:find("Zoom") or name == "Minimap" or name == "MinimapCluster" then
            return
        end

        seen[btn] = true
        table.insert(collected, btn)
    end

    -- 1. Standard Blizzard & Client Minimap Buttons
    AddButton(_G["MiniMapTrackingFrame"] or _G["MiniMapTracking"])
    AddButton(_G["GameTimeFrame"])
    AddButton(_G["MiniMapMailFrame"])
    AddButton(_G["MiniMapBattlefieldFrame"])
    AddButton(_G["MiniMapLFGFrame"] or _G["QueueStatusMinimapButton"])

    -- 2. Scan Minimap Children for third-party addon buttons
    if Minimap and Minimap.GetChildren then
        for _, child in ipairs({ Minimap:GetChildren() }) do
            if child and child:IsObjectType("Button") or child:IsObjectType("Frame") then
                local n = child:GetName() or ""
                if n ~= "" and not seen[child] then
                    local ln = n:lower()
                    if ln:find("button") or ln:find("icon") or ln:find("tracking") or ln:find("mail") or ln:find("time") or ln:find("pvp") or ln:find("lfg") then
                        AddButton(child)
                    end
                end
            end
        end
    end

    -- 3. Scan UIParent for LibDBIcon or floating minimap buttons
    if UIParent and UIParent.GetChildren then
        for _, child in ipairs({ UIParent:GetChildren() }) do
            if child and not seen[child] then
                if not child.IsForbidden or not child:IsForbidden() then
                    local n = child:GetName() or ""
                    if n:find("^LibDBIcon10_") or n:find("MinimapButton$") or n:find("MiniMapButton$") then
                        AddButton(child)
                    end
                end
            end
        end
    end

    self.buttons = collected

    -- Layout in vertical column(s)
    local buttonSize = 30
    local spacing = 3
    local padding = 3
    local cols = (OneMiniMapDB and OneMiniMapDB.buttonCols) or 1
    local totalButtons = #collected

    if totalButtons == 0 then
        self.frame:SetSize(buttonSize + padding * 2, buttonSize + padding * 2)
        return
    end

    local rows = math.ceil(totalButtons / cols)
    local totalWidth = (cols * buttonSize) + ((cols - 1) * spacing) + (padding * 2)
    local totalHeight = (rows * buttonSize) + ((rows - 1) * spacing) + (padding * 2)

    self.frame:SetSize(totalWidth, totalHeight)

    for i, btn in ipairs(collected) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)

        local xOfs = padding + (col * (buttonSize + spacing))
        local yOfs = -padding - (row * (buttonSize + spacing))

        btn:SetParent(self.frame)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", xOfs, yOfs)
        btn:SetSize(buttonSize, buttonSize)
        btn:SetScale(1.0)
        btn:SetAlpha(1.0)
        btn:Show()

        -- Restore any clipped textures inside GameTimeFrame / Tracking
        if btn == _G["GameTimeFrame"] then
            btn:SetScale(1.0)
            if btn.GetRegions then
                for _, r in ipairs({ btn:GetRegions() }) do
                    if r.SetAlpha then r:SetAlpha(1.0) end
                    if r.Show then r:Show() end
                end
            end
        end

        if btn == _G["MiniMapTrackingFrame"] or btn == _G["MiniMapTracking"] then
            btn:SetScale(1.0)
            if _G["MiniMapTrackingIcon"] then
                _G["MiniMapTrackingIcon"]:SetAlpha(1.0)
                _G["MiniMapTrackingIcon"]:Show()
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Restore & Anchor Position
-------------------------------------------------------------------------------
function BC:RestorePosition()
    if not self.frame then return end

    self.frame:ClearAllPoints()
    if OneMiniMapDB and OneMiniMapDB.buttonCollectorPosition then
        local pos = OneMiniMapDB.buttonCollectorPosition
        self.frame:SetPoint(pos.point or "TOPRIGHT", UIParent, pos.relPoint or "TOPRIGHT", pos.x or -180, pos.y or -50)
    else
        -- Default: Docked flush to the left of the square minimap
        if OneMiniMap.mapFrame then
            self.frame:SetPoint("TOPRIGHT", OneMiniMap.mapFrame, "TOPLEFT", -4, 0)
        else
            self.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -180, -50)
        end
    end
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------
function BC:Initialize()
    self:CreateFrame()
    self:RestorePosition()
    self:Update()
end
