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
    btn:SetSize(26, 26)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Icon Texture (20x20 centered)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\inv_misc_map02")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    -- Highlight Texture
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(22, 22)
    highlight:SetPoint("CENTER", btn, "CENTER", 0, 0)
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")

    -- Border Overlay
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
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
-- 2. Button Collector Growth & Drag Preview Helpers
-------------------------------------------------------------------------------
BC.previewSlots = {}

function BC:GetGrowthDirection()
    if not self.frame then return "LEFT" end
    local mapFrame = OneMiniMap and OneMiniMap.mapFrame
    if mapFrame and mapFrame.GetLeft and self.frame.GetRight then
        local mLeft = mapFrame:GetLeft()
        local bcRight = self.frame:GetRight()
        if mLeft and bcRight and bcRight <= (mLeft + 25) then
            return "LEFT"
        end
        local mRight = mapFrame:GetRight()
        local bcLeft = self.frame:GetLeft()
        if mRight and bcLeft and bcLeft >= (mRight - 25) then
            return "RIGHT"
        end
    end

    -- Fallback based on screen center
    if self.frame.GetLeft and UIParent and UIParent.GetWidth then
        local bcLeft = self.frame:GetLeft()
        local screenW = UIParent:GetWidth()
        if bcLeft and screenW and bcLeft > (screenW / 2) then
            return "LEFT"
        end
    end

    return "RIGHT"
end

function BC:ShowDragPreview()
    if not self.frame then return end

    local buttonSize = 26
    local spacing = 3
    local padding = 3
    local headerHeight = 14
    local maxRows = 8

    local totalButtons = #(self.buttons or {})
    -- Full-scale preview always shows at least 2 columns (16 slots) so user can see full expansion footprint
    local cols = math.max(2, math.ceil(totalButtons / maxRows))

    local totalSlots = cols * maxRows
    local totalWidth = (cols * buttonSize) + ((cols - 1) * spacing) + (padding * 2)
    local fullHeight = headerHeight + (maxRows * buttonSize) + ((maxRows - 1) * spacing) + (padding * 2)

    self.frame:SetSize(totalWidth, fullHeight)

    local growthDir = self:GetGrowthDirection()

    -- Re-position active real buttons to match the 2-column preview layout
    for i, btn in ipairs(self.buttons or {}) do
        local colIdx = math.floor((i - 1) / maxRows)
        local rowIdx = (i - 1) % maxRows
        local yOfs = -headerHeight - padding - (rowIdx * (buttonSize + spacing))
        local xOfs
        if growthDir == "LEFT" then
            xOfs = totalWidth - padding - buttonSize - (colIdx * (buttonSize + spacing))
        else
            xOfs = padding + (colIdx * (buttonSize + spacing))
        end
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", xOfs, yOfs)
    end

    -- Create & show ghost slots for all unoccupied slots up to 16
    for i = 1, totalSlots do
        local isOccupied = (i <= totalButtons)
        local colIdx = math.floor((i - 1) / maxRows)
        local rowIdx = (i - 1) % maxRows

        local yOfs = -headerHeight - padding - (rowIdx * (buttonSize + spacing))
        local xOfs
        if growthDir == "LEFT" then
            xOfs = totalWidth - padding - buttonSize - (colIdx * (buttonSize + spacing))
        else
            xOfs = padding + (colIdx * (buttonSize + spacing))
        end

        local slot = self.previewSlots[i]
        if not slot then
            slot = CreateFrame("Frame", nil, self.frame)
            slot:SetSize(buttonSize, buttonSize)

            local bg = slot:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(slot)
            if bg.SetColorTexture then
                bg:SetColorTexture(0.18, 0.18, 0.18, 0.45)
            else
                bg:SetTexture("Interface\\Buttons\\WHITE8X8")
                bg:SetVertexColor(0.18, 0.18, 0.18, 0.45)
            end

            local border = slot:CreateTexture(nil, "OVERLAY")
            border:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
            border:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
            if border.SetColorTexture then
                border:SetColorTexture(0.55, 0.55, 0.55, 0.40)
            end

            local text = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("CENTER", slot, "CENTER", 0, 0)
            text:SetText(tostring(i))
            if text.SetTextColor then
                text:SetTextColor(0.65, 0.65, 0.65, 0.70)
            end

            slot.bg = bg
            slot.border = border
            slot.text = text
            self.previewSlots[i] = slot
        end

        slot:ClearAllPoints()
        slot:SetPoint("TOPLEFT", self.frame, "TOPLEFT", xOfs, yOfs)
        if slot.text then
            slot.text:SetText(tostring(i))
        end

        if isOccupied then
            slot:Hide()
        else
            slot:Show()
        end
    end
end

function BC:HideDragPreview()
    if self.previewSlots then
        for _, slot in pairs(self.previewSlots) do
            slot:Hide()
        end
    end
    self:Update()
end

-------------------------------------------------------------------------------
-- 3. Button Collector Container Frame
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

    -- Dragging Helpers
    local function StartMoving()
        if not OneMiniMapDB or not OneMiniMapDB.locked then
            BC:ShowDragPreview()
            frame:StartMoving()
        end
    end
    local function StopMoving()
        frame:StopMovingOrSizing()
        BC:HideDragPreview()
        if OneMiniMapDB then
            local point, _, relPoint, xOfs, yOfs = frame:GetPoint()
            OneMiniMapDB.buttonCollectorPosition = {
                point = point or "TOPRIGHT",
                relPoint = relPoint or "TOPRIGHT",
                x = math.floor((xOfs or 0) + 0.5),
                y = math.floor((yOfs or 0) + 0.5),
            }
        end
    end

    -- Dedicated Drag Header / Grip Handle (14px high)
    local dragHeader = CreateFrame("Frame", nil, frame)
    dragHeader:SetHeight(14)
    dragHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    dragHeader:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    dragHeader:EnableMouse(true)
    dragHeader:RegisterForDrag("LeftButton")

    local grip = dragHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    grip:SetPoint("CENTER", dragHeader, "CENTER", 0, 0)
    grip:SetText("•••")
    if grip.SetTextColor then
        grip:SetTextColor(0.65, 0.65, 0.65, 0.85)
    end
    dragHeader.grip = grip

    dragHeader:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then StartMoving() end
    end)
    dragHeader:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then StopMoving() end
    end)
    dragHeader:SetScript("OnDragStart", StartMoving)
    dragHeader:SetScript("OnDragStop", StopMoving)

    dragHeader:SetScript("OnEnter", function(self)
        if grip.SetTextColor then grip:SetTextColor(1, 0.82, 0, 1) end
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Minimap Buttons", 1, 1, 1)
        if not OneMiniMapDB or not OneMiniMapDB.locked then
            GameTooltip:AddLine("|cff00ccffClick & drag|r to reposition", 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine("Frames are |cffff2020Locked|r", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    dragHeader:SetScript("OnLeave", function(self)
        if grip.SetTextColor then grip:SetTextColor(0.65, 0.65, 0.65, 0.85) end
        GameTooltip:Hide()
    end)
    frame.dragHeader = dragHeader

    -- Also allow dragging from empty background areas of frame
    frame:SetScript("OnDragStart", StartMoving)
    frame:SetScript("OnDragStop", StopMoving)

    -- Tooltip on Bar Hover (background)
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
        icon:ClearAllPoints()
        icon:SetSize(20, 20)
        icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
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

    -- Size and center the calendar icon & day font cleanly inside 26x26 button
    if btn.GetRegions then
        for _, r in ipairs({ btn:GetRegions() }) do
            if r:IsObjectType("Texture") then
                local t = tostring(r:GetTexture() or ""):lower()
                if t:find("border") or t:find("glow") or t:find("shine") or t:find("halo") then
                    r:Hide()
                    if r.SetAlpha then r:SetAlpha(0) end
                elseif t ~= "" then
                    r:ClearAllPoints()
                    r:SetSize(20, 20)
                    r:SetPoint("CENTER", btn, "CENTER", 0, 0)
                    if r.SetTexCoord then
                        r:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    end
                end
            elseif r:IsObjectType("FontString") then
                r:ClearAllPoints()
                r:SetPoint("CENTER", btn, "CENTER", 0, -1)
                if r.SetFont then
                    local font, size, flags = r:GetFont()
                    if font and size and size > 11 then
                        r:SetFont(font, 10, flags or "OUTLINE")
                    end
                end
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
    if mailBtn then
        local p = mailBtn:GetParent()
        if p and not p.Layout then
            p.Layout = function() end
        end
        if p and not p.MarkDirty then
            p.MarkDirty = function() end
        end
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

    -- 4. Test Mode (adds dummy buttons up to 12 slots to preview 2-column wrapping)
    if OneMiniMapDB and OneMiniMapDB.testMode then
        self.testButtons = self.testButtons or {}
        local testIcons = {
            "Interface\\Icons\\INV_Misc_Bag_08",
            "Interface\\Icons\\Spell_Holy_MagicalSentry",
            "Interface\\Icons\\Ability_Rogue_Ambush",
            "Interface\\Icons\\Spell_Frost_FrostBolt02",
            "Interface\\Icons\\INV_Potion_51",
            "Interface\\Icons\\Spell_Nature_HealingTouch",
            "Interface\\Icons\\INV_Sword_04",
            "Interface\\Icons\\Spell_Fire_FlameBlades",
        }
        for idx, iconPath in ipairs(testIcons) do
            local tBtn = self.testButtons[idx]
            if not tBtn then
                tBtn = CreateFrame("Button", "OneMiniMapTestBtn" .. idx, self.frame)
                tBtn:SetSize(26, 26)
                local ic = tBtn:CreateTexture(nil, "ARTWORK")
                ic:SetSize(20, 20)
                ic:SetPoint("CENTER", tBtn, "CENTER", 0, 0)
                ic:SetTexture(iconPath)
                if ic.SetTexCoord then ic:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
                tBtn.icon = ic
                tBtn:SetScript("OnEnter", function(s)
                    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
                    GameTooltip:AddLine("Test Button #" .. (idx + 4), 1, 1, 1)
                    GameTooltip:AddLine("Demonstrating 2-column auto-wrapping (>8 buttons)", 0.7, 0.7, 0.7)
                    GameTooltip:Show()
                end)
                tBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                self.testButtons[idx] = tBtn
            end
            tBtn:Show()
            table.insert(collected, tBtn)
        end
    elseif self.testButtons then
        for _, tBtn in ipairs(self.testButtons) do
            tBtn:Hide()
        end
    end

    self.buttons = collected

    -- Layout in vertical column(s) with max 8 rows per column
    local buttonSize = 26
    local iconSize = 20
    local spacing = 3
    local padding = 3
    local headerHeight = 14
    local maxRows = 8
    local totalButtons = #collected

    -- Add a column for buttons > 8 (or if user forced 2 cols in options)
    local userCols = OneMiniMapDB and OneMiniMapDB.buttonCols
    local cols
    if userCols and userCols > 1 then
        cols = userCols
    else
        cols = math.ceil(totalButtons / maxRows)
        if cols < 1 then cols = 1 end
    end

    local rows = math.min(maxRows, totalButtons)
    if rows < 1 then rows = 1 end

    local totalWidth = (cols * buttonSize) + ((cols - 1) * spacing) + (padding * 2)
    local totalHeight = headerHeight + (rows * buttonSize) + ((rows - 1) * spacing) + (padding * 2)

    self.frame:SetSize(totalWidth, totalHeight)

    local growthDir = self:GetGrowthDirection()

    for i, btn in ipairs(collected) do
        local colIdx = math.floor((i - 1) / maxRows)
        local rowIdx = (i - 1) % maxRows

        local yOfs = -headerHeight - padding - (rowIdx * (buttonSize + spacing))
        local xOfs
        if growthDir == "LEFT" then
            xOfs = totalWidth - padding - buttonSize - (colIdx * (buttonSize + spacing))
        else
            xOfs = padding + (colIdx * (buttonSize + spacing))
        end

        btn:SetParent(self.frame)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", self.frame, "TOPLEFT", xOfs, yOfs)
        btn:SetSize(buttonSize, buttonSize)
        btn:SetScale(1.0)
        btn:SetAlpha(1.0)
        btn:Show()

        -- Normalize icon size for third-party / LibDBIcon buttons
        if btn.icon and btn ~= optBtn then
            btn.icon:ClearAllPoints()
            btn.icon:SetSize(iconSize, iconSize)
            btn.icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
            if btn.icon.SetTexCoord then
                btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
        end

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
