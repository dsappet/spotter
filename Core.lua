local ADDON_NAME, ns = ...

local Spotter = CreateFrame("Frame", "Spotter")
ns.Spotter = Spotter

Spotter.version = "0.2.0"
Spotter.enabled = false

local defaults = {
    enabled = false,
    updateInterval = 1.0,
    maxDistanceYards = 200,
    arrivalYards = 15,
    minimap = { hide = false, minimapPos = 220 },
}

local function deepcopy(t)
    local r = {}
    for k, v in pairs(t) do
        r[k] = type(v) == "table" and deepcopy(v) or v
    end
    return r
end

local function ApplyDefaults(db, defs)
    for k, v in pairs(defs) do
        if db[k] == nil then
            db[k] = type(v) == "table" and deepcopy(v) or v
        elseif type(v) == "table" then
            ApplyDefaults(db[k], v)
        end
    end
end

function Spotter:Print(...)
    print("|cff33ff99Spotter|r:", ...)
end

function Spotter:Toggle()
    if self.enabled then self:Stop() else self:Start() end
end

function Spotter:Start()
    self.enabled = true
    SpotterDB.enabled = true
    if self.ticker then self.ticker:Cancel() end
    self.ticker = C_Timer.NewTicker(SpotterDB.updateInterval, function()
        Spotter:Tick()
    end)
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:Print("tracking enabled.")
    if ns.Scanner and not ns.Scanner:HasDataSource() then
        self:Print("|cffff5555GatherMate2 not detected.|r Install GatherMate2 + GatherMate2_Data so Spotter has node positions to route to.")
    end
    if ns.MinimapButton then ns.MinimapButton:Refresh() end
end

function Spotter:Stop()
    self.enabled = false
    SpotterDB.enabled = false
    if self.ticker then self.ticker:Cancel(); self.ticker = nil end
    self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self.currentTarget = nil
    if ns.Waypoint then ns.Waypoint:Clear() end
    self:Print("tracking disabled.")
    if ns.MinimapButton then ns.MinimapButton:Refresh() end
end

-- Yards between the player and a target expressed in zone (0..1) coords.
local function PlayerDistanceTo(target)
    if not target then return nil end
    local HBD = LibStub and LibStub("HereBeDragons-2.0", true)
    if not HBD then return nil end
    local px, py = HBD:GetPlayerWorldPosition()
    if not px or not py then return nil end
    local wx, wy = HBD:GetWorldCoordinatesFromZone(target.x, target.y, target.mapID)
    if not wx or not wy then return nil end
    local dx, dy = wx - px, wy - py
    return math.sqrt(dx * dx + dy * dy)
end

local SWITCH_RATIO = 0.7  -- switch target only if new one is 30%+ closer

function Spotter:Tick()
    if not ns.Scanner or not ns.Waypoint or not ns.Verifier then return end

    local maxDist = SpotterDB.maxDistanceYards or 200
    local arrivalDist = SpotterDB.arrivalYards or 15

    -- Arrival: when we get close, cooldown the node and move on.
    if self.currentTarget then
        local d = PlayerDistanceTo(self.currentTarget)
        if d then
            if d <= arrivalDist then
                ns.Verifier:MarkMined(self.currentTarget)
                self.currentTarget = nil
                ns.Waypoint:Clear()
            elseif d > maxDist * 1.25 then
                self.currentTarget = nil
                ns.Waypoint:Clear()
            end
        end
    end

    local nodes = ns.Scanner:Scan() or {}
    if #nodes == 0 then
        if self.currentTarget then
            self.currentTarget = nil
            ns.Waypoint:Clear()
        end
        return
    end

    local best = ns.Verifier:PickTarget(nodes, maxDist)
    if not best then return end

    if self.currentTarget then
        local curDist = PlayerDistanceTo(self.currentTarget)
        if curDist and best.distance < curDist * SWITCH_RATIO then
            self.currentTarget = best
            ns.Waypoint:SetTo(best.mapID, best.x, best.y)
        end
    else
        self.currentTarget = best
        ns.Waypoint:SetTo(best.mapID, best.x, best.y)
    end
end

-- When the player successfully casts a mining spell, cooldown the nearest
-- GM2 node so we immediately route to the next one.
local MINING_SPELL_IDS = {
    [2575]  = true,  -- Mining (Apprentice)
    [2576]  = true,  -- Mining (Journeyman)
    [3564]  = true,  -- Mining (Expert)
    [10248] = true,  -- Mining (Artisan)
    [29354] = true,  -- Mining (Master)
    [50310] = true,  -- Mining (Grand Master)
    [74517] = true,  -- Mining (Illustrious)
    [102161] = true, -- Mining (Zen)
    [158754] = true, -- Mining (Draenor)
    [195122] = true, -- Mining (Legion)
    [253337] = true, -- Mining (Kul Tiran / Zandalari)
    [366260] = true, -- Mining (Dragon Isles)
    [423393] = true, -- Mining (Khaz Algar)
}

function Spotter:OnMiningSuccess()
    if not self.currentTarget or not ns.Verifier then return end
    -- Cooldown the current target (we just mined it or something near it)
    ns.Verifier:MarkMined(self.currentTarget)
    self.currentTarget = nil
    if ns.Waypoint then ns.Waypoint:Clear() end
end

-- Events
Spotter:RegisterEvent("ADDON_LOADED")
Spotter:RegisterEvent("PLAYER_LOGIN")
Spotter:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        SpotterDB = SpotterDB or {}
        ApplyDefaults(SpotterDB, defaults)
    elseif event == "PLAYER_LOGIN" then
        if ns.MinimapButton then ns.MinimapButton:Init() end
        if SpotterDB.enabled then self:Start() end
        self:Print("v" .. self.version .. " loaded. Use |cffffd200/ore|r to toggle.")
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- arg1 = unit, arg2 = castGUID, arg3 = spellID
        if arg1 == "player" and MINING_SPELL_IDS[arg3] then
            self:OnMiningSuccess()
        end
    end
end)

-- Slash commands
SLASH_SPOTTER1 = "/ore"
SLASH_SPOTTER2 = "/spotter"
SlashCmdList["SPOTTER"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "on" then
        Spotter:Start()
    elseif msg == "off" then
        Spotter:Stop()
    elseif msg == "clear" then
        Spotter.currentTarget = nil
        if ns.Waypoint then ns.Waypoint:ForceClear() end
        Spotter:Print("waypoint cleared.")
    elseif msg == "skip" then
        if Spotter.currentTarget and ns.Verifier then
            ns.Verifier:MarkMined(Spotter.currentTarget)
            Spotter:Print("skipped — node on cooldown for 3 min.")
            Spotter.currentTarget = nil
            if ns.Waypoint then ns.Waypoint:Clear() end
            Spotter:Tick()
        else
            Spotter:Print("no active target to skip.")
        end
    elseif msg == "scan" then
        local nodes = ns.Scanner and ns.Scanner:Scan() or {}
        Spotter:Print(("found %d known ore node(s) in this zone"):format(#nodes))
        table.sort(nodes, function(a, b) return a.distance < b.distance end)
        for i = 1, math.min(5, #nodes) do
            local n = nodes[i]
            Spotter:Print(("  #%d: %.1f yds @ (%.1f, %.1f)"):format(i, n.distance, n.x * 100, n.y * 100))
        end
    else
        Spotter:Toggle()
    end
end
