local ADDON_NAME, ns = ...
local Scanner = {}
ns.Scanner = Scanner

-- Minimap diameter in yards at each zoom level (0..5).
-- These are the canonical values used by Cartographer/Routes/HBD-era addons.
local MINIMAP_YARDS = {
    indoor  = { 300,           240, 180,           120,           80,  50           },
    outdoor = { 466 + 2/3,     400, 333 + 1/3,     266 + 2/3,     200, 133 + 1/3    },
}

local function GetMinimapYardsPerPixel()
    local zoom = Minimap:GetZoom()
    local outdoorZoom = tonumber(GetCVar("minimapZoom")) or 0
    local indoorZoom  = tonumber(GetCVar("minimapInsideZoom")) or 0

    local kind
    if outdoorZoom == indoorZoom then
        -- Ambiguous; assume outdoor.
        kind = "outdoor"
    elseif zoom == indoorZoom then
        kind = "indoor"
    else
        kind = "outdoor"
    end

    local diameter = MINIMAP_YARDS[kind][zoom + 1] or MINIMAP_YARDS.outdoor[1]
    local width = Minimap:GetWidth()
    if not width or width == 0 then return 0 end
    return diameter / width
end

-- Convert a screen-space pixel offset (relative to minimap center) into a
-- world-space (north, west) yard offset, accounting for minimap rotation.
--
-- WoW world coords: +X = north, +Y = west.
-- Non-rotated minimap: screen +y = north, screen +x = east.
-- Rotated minimap: screen +y = direction the player is facing.
local function PixelOffsetToWorldOffset(dx, dy)
    local ypp = GetMinimapYardsPerPixel()
    local sx, sy = dx * ypp, dy * ypp

    local theta = 0
    if GetCVar("rotateMinimap") == "1" then
        theta = GetPlayerFacing() or 0
    end

    local cos, sin = math.cos(theta), math.sin(theta)
    local north = sy * cos + sx * sin
    local west  = sy * sin - sx * cos
    return north, west
end

-- Tracking blips on the minimap are anonymous child Buttons of Minimap.
-- Named children (MinimapBackdrop, MinimapZoomIn, etc.) are UI chrome and
-- should be skipped. The player arrow is a separate frame entirely.
--
-- NOTE: With "Find Minerals" tracking active, the only blips that should
-- show up here are ore nodes (plus the player/group/quest blips, which
-- have names). If the user has multiple tracking types enabled this will
-- include all of them.
local function IsLikelyTrackingBlip(child)
    if not child then return false end
    if child:GetName() then return false end
    if not child.GetObjectType then return false end
    local t = child:GetObjectType()
    if t ~= "Button" and t ~= "Frame" then return false end
    if not child:IsVisible() then return false end
    return true
end

function Scanner:Scan()
    local results = {}

    local HBD = LibStub and LibStub("HereBeDragons-2.0", true)
    if not HBD then
        return results
    end

    local px, py, instanceID = HBD:GetPlayerWorldPosition()
    if not px or not py then return results end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return results end

    local mcx, mcy = Minimap:GetCenter()
    if not mcx or not mcy then return results end

    for i = 1, Minimap:GetNumChildren() do
        local child = select(i, Minimap:GetChildren())
        if IsLikelyTrackingBlip(child) then
            local cx, cy = child:GetCenter()
            if cx and cy then
                local dx, dy = cx - mcx, cy - mcy
                local north, west = PixelOffsetToWorldOffset(dx, dy)

                local wx = px + north
                local wy = py + west

                local zx, zy = HBD:GetZoneCoordinatesFromWorld(wx, wy, mapID, false)
                if zx and zy then
                    local distance = math.sqrt(north * north + west * west)
                    table.insert(results, {
                        mapID    = mapID,
                        x        = zx,
                        y        = zy,
                        distance = distance,
                    })
                end
            end
        end
    end

    return results
end
