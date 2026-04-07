local ADDON_NAME, ns = ...

local Spotter = CreateFrame("Frame", "Spotter")
ns.Spotter = Spotter

Spotter.version = "0.1.0"
Spotter.enabled = false

local defaults = {
    enabled = false,
    updateInterval = 1.0,
    maxDistanceYards = 200,
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
    self:Print("tracking enabled. Make sure |cffffd200Find Minerals|r is active.")
    if ns.MinimapButton then ns.MinimapButton:Refresh() end
end

function Spotter:Stop()
    self.enabled = false
    SpotterDB.enabled = false
    if self.ticker then self.ticker:Cancel(); self.ticker = nil end
    if ns.Waypoint then ns.Waypoint:Clear() end
    self:Print("tracking disabled.")
    if ns.MinimapButton then ns.MinimapButton:Refresh() end
end

function Spotter:Tick()
    if not ns.Scanner or not ns.Waypoint then return end
    local nodes = ns.Scanner:Scan()
    if not nodes or #nodes == 0 then
        return
    end

    local maxDist = SpotterDB.maxDistanceYards or 200
    local best, bestDist
    for _, node in ipairs(nodes) do
        if node.distance <= maxDist and (not bestDist or node.distance < bestDist) then
            best = node
            bestDist = node.distance
        end
    end

    if best then
        ns.Waypoint:SetTo(best.mapID, best.x, best.y)
    end
end

Spotter:RegisterEvent("ADDON_LOADED")
Spotter:RegisterEvent("PLAYER_LOGIN")
Spotter:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        SpotterDB = SpotterDB or {}
        ApplyDefaults(SpotterDB, defaults)
    elseif event == "PLAYER_LOGIN" then
        if ns.MinimapButton then ns.MinimapButton:Init() end
        if SpotterDB.enabled then self:Start() end
        self:Print("v" .. self.version .. " loaded. Use |cffffd200/ore|r to toggle.")
    end
end)

SLASH_SPOTTER1 = "/ore"
SLASH_SPOTTER2 = "/spotter"
SlashCmdList["SPOTTER"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "on" then
        Spotter:Start()
    elseif msg == "off" then
        Spotter:Stop()
    elseif msg == "clear" then
        if ns.Waypoint then ns.Waypoint:Clear() end
        Spotter:Print("waypoint cleared.")
    elseif msg == "scan" then
        local nodes = ns.Scanner and ns.Scanner:Scan() or {}
        Spotter:Print(("found %d candidate blip(s)"):format(#nodes))
        for i, n in ipairs(nodes) do
            Spotter:Print(("  #%d: %.1f yds @ (%.1f, %.1f)"):format(i, n.distance, n.x * 100, n.y * 100))
        end
    else
        Spotter:Toggle()
    end
end
