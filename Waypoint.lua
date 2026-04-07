local ADDON_NAME, ns = ...
local Waypoint = {}
ns.Waypoint = Waypoint

local lastMapID, lastX, lastY

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
end

function Waypoint:Clear()
    C_Map.ClearUserWaypoint()
    C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    lastMapID, lastX, lastY = nil, nil, nil
end
