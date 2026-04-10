local ADDON_NAME, ns = ...
local Verifier = {}
ns.Verifier = Verifier

-- Verifier manages two things:
--
-- 1) Respawn cooldowns. When the player arrives at a target, we mark it on
--    cooldown so we skip it and route to the next-closest node instead.
--
-- 2) A "/ore skip" mechanism so the user can manually reject the current
--    target if they can see it's not there.
--
-- We rely on GatherMate2 for node positions and trust its database. Nodes
-- that turn out to be empty get temporarily suppressed via cooldowns.

local COOLDOWN_SECONDS = 180  -- 3 minutes; typical ore respawn

local cooldowns = {}

local function NodeKey(node)
    return string.format("%d:%.4f:%.4f", node.mapID, node.x, node.y)
end

function Verifier:IsOnCooldown(node)
    local key = NodeKey(node)
    local expiry = cooldowns[key]
    if not expiry then return false end
    if GetTime() >= expiry then
        cooldowns[key] = nil
        return false
    end
    return true
end

function Verifier:MarkMined(node)
    cooldowns[NodeKey(node)] = GetTime() + COOLDOWN_SECONDS
end

function Verifier:ClearCooldowns()
    wipe(cooldowns)
end

-- Pick the closest non-cooldowned candidate within maxDist.
function Verifier:PickTarget(candidates, maxDist)
    local best, bestDist
    for _, node in ipairs(candidates) do
        if not self:IsOnCooldown(node)
           and node.distance <= maxDist
           and (not bestDist or node.distance < bestDist) then
            best, bestDist = node, node.distance
        end
    end
    return best
end
