std = "max+lua51"
max_line_length = false
codes = true

-- Don't lint vendored libraries
exclude_files = {
    ".release/",
    "Libs/",
}

-- WoW API + addon globals
read_globals = {
    -- Frames / UI
    "CreateFrame", "Minimap", "UIParent", "GameTooltip",
    -- Map / waypoint / supertrack
    "C_Map", "C_SuperTrack", "C_Navigation", "C_Timer", "UiMapPoint",
    -- Player / input
    "GetPlayerFacing", "GetCursorPosition", "GetCVar",
    -- Libs
    "LibStub",
    -- Slash
    "SLASH_SPOTTER1", "SLASH_SPOTTER2", "SLASH_ORE1", "SLASH_ORE2",
    "SlashCmdList",
    -- Misc
    "print", "geterrorhandler",
}

globals = {
    -- SavedVariables + addon namespace
    "SpotterDB",
    "Spotter",
}
