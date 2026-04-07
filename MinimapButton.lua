local ADDON_NAME, ns = ...
local MinimapButton = {}
ns.MinimapButton = MinimapButton

local button

local function UpdatePosition(self)
    local angle = math.rad(SpotterDB.minimap.minimapPos or 220)
    local r = (Minimap:GetWidth() / 2) + 5
    self:ClearAllPoints()
    self:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function OnDragStart(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function(s)
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        local angle = math.deg(math.atan2(py - my, px - mx))
        if angle < 0 then angle = angle + 360 end
        SpotterDB.minimap.minimapPos = angle
        UpdatePosition(s)
    end)
end

local function OnDragStop(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
end

local function OnClick(self, mouseButton)
    if mouseButton == "LeftButton" then
        ns.Spotter:Toggle()
    elseif mouseButton == "RightButton" then
        if ns.Waypoint then ns.Waypoint:Clear() end
        ns.Spotter:Print("waypoint cleared.")
    end
end

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Spotter")
    GameTooltip:AddLine(ns.Spotter.enabled
        and "|cff33ff99Tracking on|r"
        or  "|cffff5555Tracking off|r", 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffaaaaaaLeft-click:|r toggle tracking", 1, 1, 1)
    GameTooltip:AddLine("|cffaaaaaaRight-click:|r clear waypoint", 1, 1, 1)
    GameTooltip:AddLine("|cffaaaaaaDrag:|r reposition", 1, 1, 1)
    GameTooltip:Show()
end

function MinimapButton:Init()
    if button then return end

    button = CreateFrame("Button", "SpotterMinimapButton", Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetSize(31, 31)
    button:SetMovable(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Ore_Mithril_01")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    button.icon = icon

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT")

    button:SetScript("OnClick", OnClick)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", OnDragStart)
    button:SetScript("OnDragStop", OnDragStop)

    UpdatePosition(button)
    if SpotterDB.minimap.hide then button:Hide() else button:Show() end

    self.frame = button
    self:Refresh()
end

function MinimapButton:Refresh()
    if not button or not button.icon then return end
    if ns.Spotter.enabled then
        button.icon:SetVertexColor(1, 1, 1)
    else
        button.icon:SetVertexColor(0.5, 0.5, 0.5)
    end
end
