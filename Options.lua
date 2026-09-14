-- RaidMarkerBar options panel.
--
-- Blizzard's own Settings API, so the addon still carries no libraries. Every
-- control writes straight into the saved-variable table and re-applies the bar,
-- which makes the panel and the slash commands the same settings rather than
-- two copies that can disagree.
--
-- Registered from PLAYER_LOGIN by Core, because a setting needs the table it
-- reads and writes to exist first.

local ADDON, ns = ...

local Settings = Settings

local db
local settings = {}

local function Changed()
    ns.Apply()
end

local function Register(category, key, varType, name, default)
    local variable = "RaidMarkerBar_" .. key
    local setting = Settings.RegisterAddOnSetting(category, variable, key, db, varType, name, default)
    Settings.SetOnValueChangedCallback(variable, Changed)
    settings[key] = setting
    return setting
end

local function Slider(category, key, name, minValue, maxValue, step, tooltip, suffix)
    local setting = Register(category, key, Settings.VarType.Number, name, ns.DEFAULTS[key])
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, suffix and function(value)
        return value .. suffix
    end or nil)
    Settings.CreateSlider(category, setting, options, tooltip)
end

local function Checkbox(category, key, name, tooltip)
    local setting = Register(category, key, Settings.VarType.Boolean, name, ns.DEFAULTS[key])
    Settings.CreateCheckbox(category, setting, tooltip)
end

local function Dropdown(category, key, name, entries, tooltip)
    local setting = Register(category, key, Settings.VarType.String, name, ns.DEFAULTS[key])
    Settings.CreateDropdown(category, setting, function()
        local container = Settings.CreateControlTextContainer()
        for _, entry in ipairs(entries) do
            container:Add(entry[1], entry[2])
        end
        return container:GetData()
    end, tooltip)
end

local function Header(layout, text)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
end

local function Reset()
    for key, setting in pairs(settings) do
        setting:SetValue(ns.DEFAULTS[key])
    end
    -- Copied, not shared: db.point must never alias the defaults table.
    db.point = { unpack(ns.DEFAULTS.point) }
    ns.Apply()
end

function ns.SetupOptions(savedVariables)
    if not (Settings and Settings.RegisterVerticalLayoutCategory) then
        return
    end

    db = savedVariables

    local category, layout = Settings.RegisterVerticalLayoutCategory("RaidMarkerBar")

    Header(layout, "Layout")
    Slider(category, "size", "Button size", 12, 64, 1, "Width and height of each button.")
    Slider(category, "spacing", "Spacing", 0, 20, 1, "Gap between buttons.")
    Checkbox(category, "vertical", "Vertical", "Stack the buttons in a column instead of a row.")
    Checkbox(category, "extras", "Ready check and pull timer", "Show the two buttons after the markers.")
    Checkbox(category, "tooltips", "Tooltips", "Show a tooltip on hover.")
    Checkbox(category, "locked", "Locked", "Hide the drag handle. Unlocking forces the bar on screen so there is something to drag while solo.")
    Dropdown(category, "show", "Show the bar", {
        { "always", "Always" },
        { "group", "In a group" },
        { "raid", "In a raid" },
    }, "When the bar is on screen.")

    Header(layout, "Clicks")
    Dropdown(category, "primary", "Plain click places", {
        { "target", "Target marker" },
        { "world", "World marker" },
    }, "The modifier click places the other one.")
    Dropdown(category, "modifier", "Modifier", {
        { "shift", "Shift" },
        { "ctrl", "Ctrl" },
        { "alt", "Alt" },
    }, "Held to place the other kind of marker.")

    Header(layout, "Pull timer")
    Slider(category, "countdown", "Countdown", 3, 60, 1, "Seconds the pull timer button starts. Right click the button cancels a running one.", "s")

    layout:AddInitializer(CreateSettingsButtonInitializer("", RESET or "Reset", Reset,
        "Restore every setting, including the bar position, to its default.", true))

    Settings.RegisterAddOnCategory(category)
    ns.optionsCategory = category
end

function ns.OpenOptions()
    if ns.optionsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(ns.optionsCategory:GetID())
        return true
    end
    return false
end
