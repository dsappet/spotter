local ADDON_NAME, ns = ...
local Scanner = {}
ns.Scanner = Scanner

-- Source of truth for ore node positions: GatherMate2's harvested database.
-- We do NOT read minimap tracking blips at all -- those don't have stable
-- world positions (they're edge-clamped, anonymous, and rotation/zoom
-- dependent), so any waypoint computed from them drifts and lies. The
-- GatherMate2 db is millions of player visits aggregated and is exact.
--
-- GatherMate2 encodes coordinates as 10-digit integers: XXXXYYYY00
--   x = floor(coord / 1000000) / 10000
--   y = floor(coord % 1000000 / 100) / 10000
-- The preferred iteration API is :GetNodesForZone(mapID, dbType, ignoreFilter).

local function GetGatherMate()
    if _G.GatherMate2 then return _G.GatherMate2 end
    local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
    if AceAddon and AceAddon.GetAddon then
        local ok, gm = pcall(AceAddon.GetAddon, AceAddon, "GatherMate2", true)
        if ok then return gm end
    end
    return nil
end

function Scanner:HasDataSource()
    local gm = GetGatherMate()
    return gm and gm.GetNodesForZone and true or false
end

function Scanner:Scan()
    local results = {}

    local gm = GetGatherMate()
    if not gm or not gm.GetNodesForZone or not gm.DecodeLoc then return results end

    local HBD = LibStub and LibStub("HereBeDragons-2.0", true)
    if not HBD then return results end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return results end

    local px, py = HBD:GetPlayerWorldPosition()
    if not px or not py then return results end

    for coord, nodeID in gm:GetNodesForZone(mapID, "Mining", true) do
        local zx, zy = gm:DecodeLoc(coord)
        if zx and zy then
            local wx, wy = HBD:GetWorldCoordinatesFromZone(zx, zy, mapID)
            if wx and wy then
                local dx, dy = wx - px, wy - py
                local distance = math.sqrt(dx * dx + dy * dy)
                table.insert(results, {
                    mapID    = mapID,
                    x        = zx,
                    y        = zy,
                    distance = distance,
                    nodeID   = nodeID,
                })
            end
        end
    end

    return results
end
