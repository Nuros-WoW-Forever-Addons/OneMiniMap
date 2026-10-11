--[[
    OneMiniMap - ButtonCollector.lua
    Organizes minimap buttons into neat, configurable vertical columns
    docked next to the square minimap or freely draggable.
    Includes embedded OneMiniMap Options Button with status tooltip.
    Compatibility: Vanilla 1.12, Turtle WoW 1.16, WotLK 3.3.5, and Modern WoW.
--]]

local addonName, addonTable = ...
local OneMiniMap = _G.OneMiniMap or addonTable

OneMiniMap.ButtonCollector = {}
local BC = OneMiniMap.ButtonCollector

BC.buttons = {}
BC.frame = nil
BC.optionsButton = nil

-------------------------------------------------------------------------------
-- Helper: Safe Backdrop Application across WoW generations
-------------------------------------------------------------------------------
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
-- 1. OneMiniMap Options Button (First Button in Collector Bar)
-------------------------------------------------------------------------------
function BC:CreateOptionsButton()
    if self.optionsButton then return self.optionsButton end

    local btn = CreateFrame("Button", "OneMiniMapOptionsButton", self.frame)
    btn:SetSize(30, 30)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Icon Texture
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    icon:SetTexture("Interface\\Icons\\inv_misc_map02")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    -- Highlight Texture
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(btn)
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")

    -- Border Overlay
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
    if border.SetColorTexture then
        border:SetColorTexture(0.5, 0.5, 0.5, 0.4)
    end

    -- Click Handlers
    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            OneMiniMapDB.locked = not OneMiniMapDB.locked
            local state = OneMiniMapDB.locked and "|cffff2020LOCKED|r" or "|cff20ff20UNLOCKED|r"
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffOneMiniMap|r: Frames are now " .. state .. ".")
        else
            if OneMiniMap.ToggleOptions then
                OneMiniMap:ToggleOptions()
            end
        end
    end)

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("|cff00ccffOneMiniMap|r", 1, 1, 1)
        GameTooltip:AddLine("|cffffd200Left-Click:|r Open Options", 0.8, 0.8, 0.8)
        local lockStatus = (OneMiniMapDB and OneMiniMapDB.locked) and "|cffff2020Locked|r" or "|cff20ff20Unlocked|r"
        GameTooltip:AddLine("|cffffd200Right-Click:|r Lock/Unlock Frames (" .. lockStatus .. ")", 0.8, 0.8, 0.8)
        if not OneMiniMapDB or not OneMiniMapDB.locked then
            GameTooltip:AddLine("|cff00ccffDrag Bar:|r Click & drag bar background", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.optionsButton = btn
    return btn
end

-------------------------------------------------------------------------------
-- 2. Button Collector Container Frame
-------------------------------------------------------------------------------
function BC:CreateFrame()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "OneMiniMapButtonCollector", UIParent, backdropTemplate)
    frame:SetSize(38, 38)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    -- Clean OneSuite Styling: Translucent Base + 1px Silver Edge
    ApplyBackdrop(frame, {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    if frame.SetBackdropColor then
        frame:SetBackdropColor(0.08, 0.08, 0.08, 0.70)
    end
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(0.60, 0.60, 0.60, 0.80)
    end

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

    -- Tooltip on Bar Hover
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

    -- Blizzard Layout & MarkDirty Support
    -- Prevents 'attempt to call a nil value' when reparented frames (e.g. MiniMapMailFrame) call self:GetParent():Layout()
    frame.Layout = function(self)
        if self.isUpdatingLayout then return end
        self.isUpdatingLayout = true
        if OneMiniMap.ButtonCollector and OneMiniMap.ButtonCollector.Update then
            OneMiniMap.ButtonCollector:Update()
        end
        self.isUpdatingLayout = false
    end
    frame.MarkDirty = function(self)
        if self.Layout then self:Layout() end
    end

    -- Event listener for mail and indicators
    frame:RegisterEvent("UPDATE_PENDING_MAIL")
    frame:SetScript("OnEvent", function(self, event)
        if event == "UPDATE_PENDING_MAIL" then
            if self.Layout then self:Layout() end
        end
    end)

    self.frame = frame
    self:CreateOptionsButton()
    return frame
end

-------------------------------------------------------------------------------
-- 3. Specific Button Skinning Helpers
-------------------------------------------------------------------------------
local function SkinTracking(btn)
    if not btn then return end

    -- Hide Blizzard circular border and stray glow/shine textures
    local border = _G["MiniMapTrackingBorder"] or (btn.Border)
    if border and border.Hide then
        border:Hide()
        if border.SetAlpha then border:SetAlpha(0) end
    end
    local shine = _G["MiniMapTrackingShine"] or (btn.Shine)
    if shine and shine.Hide then
        shine:Hide()
        if shine.SetAlpha then shine:SetAlpha(0) end
    end

    -- Ensure Icon is visible; fallback to Spyglass binoculars if no tracking active
    local icon = _G["MiniMapTrackingIcon"] or (btn.Icon)
    if not icon and btn.GetRegions then
        for _, r in ipairs({ btn:GetRegions() }) do
            if r:IsObjectType("Texture") and r ~= border and r ~= shine then
                icon = r
                break
            end
        end
    end

    if icon then
        icon:Show()
        icon:SetAlpha(1.0)
        local currTex = (icon.GetTexture and icon:GetTexture()) or (GetTrackingTexture and GetTrackingTexture())
        if not currTex or currTex == "" or tostring(currTex):lower():find("questionmark") then
            icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")
        end
        if icon.SetTexCoord then
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
    end
end

local function SkinCalendar(btn)
    if not btn then return end

    -- Hide outer glow textures that cause circular halo distortion
    local glowNames = {
        "GameTimeCalendarInvitesTexture",
        "GameTimeCalendarInvitesGlow",
        "GameTimeCalendarEventAlarmTexture",
    }
    for _, name in ipairs(glowNames) do
        local g = _G[name]
        if g and g.Hide then
            g:Hide()
            if g.SetAlpha then g:SetAlpha(0) end
        end
    end

    -- Keep the calendar day text crisp and centered
    if btn.GetRegions then
        for _, r in ipairs({ btn:GetRegions() }) do
            if r:IsObjectType("FontString") then
                r:ClearAllPoints()
                r:SetPoint("CENTER", btn, "CENTER", 0, -2)
            end
        end
    end
end

local function CleanCircularOverlays(btn)
    if not btn or not btn.GetRegions then return end
    for _, r in ipairs({ btn:GetRegions() }) do
        if r:IsObjectType("Texture") then
            local t = tostring(r:GetTexture() or ""):lower()
            if t:find("border") or t:find("trackingborder") or t:find("minimap%-tracking") or t:find("shine") or t:find("glow") or t:find("halo") then
                r:Hide()
                if r.SetAlpha then r:SetAlpha(0) end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- 4. Scan & Layout Buttons
-------------------------------------------------------------------------------
function BC:Update()
    if not self.frame then self:CreateFrame() end

    local collected = {}
    local seen = {}

    -- Always include OneMiniMap's Options button first
    local optBtn = self:CreateOptionsButton()
    table.insert(collected, optBtn)
    seen[optBtn] = true

    local function AddButton(btn, forceInclude)
        if not btn then return end
        if seen[btn] then return end
        local name = btn:GetName() or ""

        -- Ignore internal frames, zoom buttons, and the Minimap itself
        if name:find("^OneMiniMap") or name:find("Zoom") or name == "Minimap" or name == "MinimapCluster" then
            return
        end

        -- Conditional check: only include if forced or already shown
        if not forceInclude and not btn:IsShown() then
            return
        end

        seen[btn] = true
        table.insert(collected, btn)
    end

    -- 1. Standard Blizzard Minimap Buttons across WoW generations
    -- Tracking / Finder (always include)
    local trackingBtn = _G["MiniMapTrackingFrame"] or _G["MiniMapTracking"]
    if not trackingBtn and MinimapCluster and MinimapCluster.Tracking then
        trackingBtn = MinimapCluster.Tracking
    end
    AddButton(trackingBtn, true)

    -- Calendar / Game Time (always include)
    AddButton(_G["GameTimeFrame"], true)

    -- Mail (only include if player actually has pending mail)
    local mailBtn = _G["MiniMapMailFrame"]
    if not mailBtn and MinimapCluster and MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.MailFrame then
        mailBtn = MinimapCluster.IndicatorFrame.MailFrame
    end
    local hasMail = (HasNewMail and HasNewMail()) or (mailBtn and mailBtn:IsShown())
    if mailBtn and hasMail then
        AddButton(mailBtn, true)
    end

    -- Battlefield / PvP
    AddButton(_G["MiniMapBattlefieldFrame"])

    -- LFG / Dungeon Queue
    AddButton(_G["MiniMapLFGFrame"] or _G["QueueStatusMinimapButton"])

    -- Expansion / Garrison Landing Page
    AddButton(_G["ExpansionLandingPageMinimapButton"] or _G["GarrisonLandingPageMinimapButton"])

    -- 2. Scan Minimap Children for third-party addon buttons
    if Minimap and Minimap.GetChildren then
        for _, child in ipairs({ Minimap:GetChildren() }) do
            if child and (child:IsObjectType("Button") or child:IsObjectType("Frame")) then
                local n = child:GetName() or ""
                if n ~= "" and not seen[child] then
                    local ln = n:lower()
                    if ln:find("button") or ln:find("icon") or ln:find("tracking") or ln:find("mail") or ln:find("time") or ln:find("pvp") or ln:find("lfg") then
                        AddButton(child, child:IsShown())
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
                        AddButton(child, child:IsShown())
                    end
                end
            end
        end
    end

    self.buttons = collected

    -- Layout in vertical column(s)
    local buttonSize = 30
    local spacing = 3
    local padding = 4
    local cols = (OneMiniMapDB and OneMiniMapDB.buttonCols) or 1
    local totalButtons = #collected

    local rows = math.ceil(totalButtons / cols)
    if rows < 1 then rows = 1 end

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

        -- Apply tailored skinning
        if btn == trackingBtn then
            SkinTracking(btn)
        elseif btn == _G["GameTimeFrame"] then
            SkinCalendar(btn)
        elseif btn ~= optBtn then
            CleanCircularOverlays(btn)
        end
    end
end

-------------------------------------------------------------------------------
-- 5. Restore & Anchor Position
-------------------------------------------------------------------------------
function BC:RestorePosition()
    if not self.frame then return end

    self.frame:ClearAllPoints()
    if OneMiniMapDB and OneMiniMapDB.buttonCollectorPosition then
        local pos = OneMiniMapDB.buttonCollectorPosition
        self.frame:SetPoint(pos.point or "TOPRIGHT", UIParent, pos.relPoint or "TOPRIGHT", pos.x or -180, pos.y or -60)
    else
        -- Default: Docked flush to the left of the square minimap
        if OneMiniMap.mapFrame then
            self.frame:SetPoint("TOPRIGHT", OneMiniMap.mapFrame, "TOPLEFT", -4, 0)
        else
            self.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -180, -60)
        end
    end
end

-------------------------------------------------------------------------------
-- 6. Initialization
-------------------------------------------------------------------------------
function BC:Initialize()
    self:CreateFrame()
    self:RestorePosition()
    self:Update()
end
