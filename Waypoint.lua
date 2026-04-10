local ADDON_NAME, ns = ...
local Waypoint = {}
ns.Waypoint = Waypoint

local lastMapID, lastX, lastY
local ours = false

local function Approximately(a, b, eps)
    return math.abs(a - b) < (eps or 0.001)
end

-- Set the native WoW user waypoint and enable supertracking so the floating
-- 3D arrow appears. The correct API lives in C_Map (and C_SuperTrack), not
-- C_Navigation -- C_Navigation is for distance/state queries against whatever
-- is currently being supertracked.
function Waypoint:SetTo(mapID, x, y)
    if not mapID or not x or not y then return end

    -- Skip the API call if the target hasn't moved meaningfully.
    if lastMapID == mapID and lastX and lastY
       and Approximately(lastX, x, 0.0005)
       and Approximately(lastY, y, 0.0005) then
        return
    end

    local point = UiMapPoint.CreateFromCoordinates(mapID, x, y)
    C_Map.SetUserWaypoint(point)
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)

    lastMapID, lastX, lastY = mapID, x, y
    ours = true
end

-- True if the currently active user waypoint is the one we set and it hasn't
-- been replaced by the player. We compare against the live waypoint to detect
-- the case where the user manually placed a different one after ours.
function Waypoint:IsOurs()
    if not ours then return false end
    local p = C_Map.GetUserWaypoint()
    if not p then return false end
    if p.uiMapID ~= lastMapID then return false end
    if not Approximately(p.position.x, lastX, 0.0005) then return false end
    if not Approximately(p.position.y, lastY, 0.0005) then return false end
    return true
end

function Waypoint:Clear()
    if not self:IsOurs() then
        -- Don't stomp a player-placed waypoint.
        ours = false
        lastMapID, lastX, lastY = nil, nil, nil
        return
    end
    C_Map.ClearUserWaypoint()
    C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    lastMapID, lastX, lastY = nil, nil, nil
    ours = false
end

-- Force-clear regardless of ownership (used by /ore clear).
function Waypoint:ForceClear()
    C_Map.ClearUserWaypoint()
    C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    lastMapID, lastX, lastY = nil, nil, nil
    ours = false
end
