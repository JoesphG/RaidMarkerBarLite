-- Every WoW global the addon reads is declared here, so real problems stand out.

local wow_api = {
    -- Frames
    "CreateFrame",
    "GameTooltip",
    "UIParent",

    -- Group
    "InCombatLockdown",
    "IsInGroup",
    "IsInRaid",
    "UnitIsGroupAssistant",
    "UnitIsGroupLeader",

    -- Markers
    "SetRaidTargetIconTexture",
    "SLASH_CLEAR_WORLD_MARKER1",
    "SLASH_TARGET_MARKER4",
    "SLASH_WORLD_MARKER1",

    -- Secure state
    "RegisterStateDriver",
    "UnregisterStateDriver",

    -- Ready check and countdown
    "C_PartyInfo",
    "DoReadyCheck",

    -- Settings panel
    "CreateSettingsButtonInitializer",
    "CreateSettingsListSectionHeaderInitializer",
    "MinimalSliderWithSteppersMixin",
    "Settings",

    -- Global strings
    "CLEAR_ALL",
    "ERR_NOT_LEADER",
    "NONE",
    "READY_CHECK",
    "RESET",
    "TARGET",
    "WORLD",
}

std = "lua51"
max_line_length = 120
codes = true
exclude_files = { ".release/" }

globals = {
    "RaidMarkerBarDB", -- SavedVariables
    "SlashCmdList",
    "SLASH_RAIDMARKERBAR1",
    "SLASH_RAIDMARKERBAR2",
}

read_globals = wow_api

-- The stubs define the client API, so there it is writable.
files["tests/"] = {
    globals = wow_api,
    read_globals = { "LibStub" }, -- asserted absent: the addon carries no libraries
    ignore = {
        "212", -- stub signatures mirror Blizzard's, unused args and all
        "121/print", -- replaced to capture the addon's output
    },
}
