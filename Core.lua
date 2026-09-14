-- RaidMarkerBarLite
--
-- A raid marker bar with no dependencies: no Ace3, no LibStub, no embedded
-- libraries at all. One file, one saved-variable table, one event frame, no
-- OnUpdate handler anywhere. Everything is event-driven or handled by a secure
-- state driver.
--
-- WHY SECURE ATTRIBUTES AND NOT PLAIN ONCLICK
--
-- Placing a raid target or a world marker is a protected action. A plain
-- button calling SetRaidTarget() works out of combat and silently fails in it,
-- which is precisely when markers matter. So the buttons are
-- SecureActionButtonTemplate driven by macrotext, and visibility runs through
-- a state driver -- Blizzard's own code performs the work, so combat lockdown
-- never applies.
--
-- THE COMBAT RULES THIS FILE KEEPS
--
--   * Buttons are created ONCE and never re-created, re-parented or re-sized
--     in combat. Layout changes arriving in combat set `pending` and complete
--     on PLAYER_REGEN_ENABLED, which is registered up front -- a /reload taken
--     in combat would otherwise defer the first layout with nothing listening
--     to resume it.
--   * SetAlpha is not protected, so the permission dim works in combat.
--   * RegisterStateDriver owns visibility, so the bar can appear and disappear
--     mid-fight without Lua touching it.

local _, ns = ...

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsInGroup, IsInRaid = IsInGroup, IsInRaid
local UnitIsGroupLeader, UnitIsGroupAssistant = UnitIsGroupLeader, UnitIsGroupAssistant
local RegisterStateDriver, UnregisterStateDriver = RegisterStateDriver, UnregisterStateDriver
local SetRaidTargetIconTexture = SetRaidTargetIconTexture
local GameTooltip = GameTooltip
local format = string.format

-- Slash commands and the options panel are two faces of the same table: both
-- write to db and call Apply, neither keeps state of its own.
local SLASH_HELP = {
    "|cff00ff00RaidMarkerBarLite|r",
    "  /rmb config          open the options panel",
    "  /rmb lock            toggle the drag handle",
    "  /rmb size <12-64>    button size",
    "  /rmb spacing <0-20>  gap between buttons",
    "  /rmb vertical        toggle orientation",
    "  /rmb show <always|group|raid>",
    "  /rmb swap            swap plain-click and modifier actions",
    "  /rmb mod <shift|ctrl|alt>",
    "  /rmb extras          toggle ready check and countdown buttons",
    "  /rmb countdown <3-60>  pull timer seconds",
    "  /rmb reset           back to defaults",
    "  /rmb status          why can I not see it",
}

--------------------------------------------------------------------------------
--  Constants
--------------------------------------------------------------------------------

-- SetRaidTargetIconTexture only crops the sheet; it never sets the file. The
-- texture has to be pointed at the sheet or the button comes out blank.
local MARKER_SHEET = [[Interface\TargetingFrame\UI-RaidTargetingIcons]]
local CLEAR_TEXTURE = [[Interface\Buttons\UI-GroupLoot-Pass-Up]]
local READY_TEXTURE = [[Interface\RaidFrame\ReadyCheck-Ready]]
local TIMER_TEXTURE = [[Interface\Icons\INV_Misc_PocketWatch_01]]

local NUM_MARKERS = 8

-- Target marker id -> the world marker of the same colour. Star is yellow and
-- yellow is world marker 5, and so on across the row.
local WORLD_ID = { 5, 6, 3, 2, 7, 1, 4, 8 }

local MODIFIERS = { shift = "shift-", ctrl = "ctrl-", alt = "alt-" }

local TM = SLASH_TARGET_MARKER4 or "/tm"
local WM = SLASH_WORLD_MARKER1 or "/wm"
local CWM = SLASH_CLEAR_WORLD_MARKER1 or "/cwm"

local VISIBILITY = {
    always = "show",
    group = "[group] show; hide",
    raid = "[group:raid] show; hide",
}

local DEFAULTS = {
    size = 28,
    spacing = 4,
    vertical = false,
    show = "group",
    -- "target" = plain click sets the target marker, modifier drops the world
    -- marker. "world" swaps them.
    primary = "target",
    modifier = "shift",
    extras = true,
    countdown = 5,
    locked = true,
    tooltips = true,
    point = { "CENTER", "UIParent", "CENTER", 0, -180 },
}

--------------------------------------------------------------------------------
--  State
--------------------------------------------------------------------------------

local db
local bar, mover, timerButton
local buttons = {}
local pending = false

local function Print(...)
    print("|cff00ff00RaidMarkerBarLite|r:", ...)
end

--------------------------------------------------------------------------------
--  Permission
--
--  In a raid the server refuses markers from anyone without lead or assist. A
--  party has no assistants and anyone may mark, so the gate is raid-only.
--  Dimmed rather than hidden: hiding a protected button needs combat to be
--  over, and a row vanishing mid-pull is worse than a grey row.
--------------------------------------------------------------------------------

local function CanMark()
    if not IsInRaid() then
        return true
    end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

local function UpdatePermission()
    if bar then
        bar:SetAlpha(CanMark() and 1 or 0.35)
    end
end

--------------------------------------------------------------------------------
--  Secure attributes
--
--  Every combination gets its own explicit pair. An unmodified left click
--  resolves "type1", a shift-held one "shift-type1"; the wildcard forms are a
--  fallback whose rules are not worth relying on -- setting only "type*"
--  resolves to nothing and the click silently does nothing at all.
--------------------------------------------------------------------------------

local function MacroPair(id)
    if id == 0 then
        return format("%s 0", TM), format("%s 0", CWM)
    end
    -- Clear the world marker first so a second click moves it rather than
    -- being swallowed as a duplicate placement.
    local world = format("%s %d\n%s %d", CWM, WORLD_ID[id], WM, WORLD_ID[id])
    return format("%s %d", TM, id), world
end

local function ApplyAttributes(button)
    if button.markerID == nil then
        return
    end

    local target, world = MacroPair(button.markerID)
    local primary, secondary = target, world
    if db.primary == "world" then
        primary, secondary = world, target
    end

    local prefix = MODIFIERS[db.modifier] or "shift-"

    for i = 1, 3 do
        button:SetAttribute("type" .. i, "macro")
        button:SetAttribute("macrotext" .. i, primary)
        button:SetAttribute(prefix .. "type" .. i, "macro")
        button:SetAttribute(prefix .. "macrotext" .. i, secondary)
    end

    -- Clear any prefix left over from a previous modifier choice.
    for _, other in pairs(MODIFIERS) do
        if other ~= prefix then
            for i = 1, 3 do
                button:SetAttribute(other .. "type" .. i, nil)
                button:SetAttribute(other .. "macrotext" .. i, nil)
            end
        end
    end
end

--------------------------------------------------------------------------------
--  Buttons
--------------------------------------------------------------------------------

local MARKER_NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }

local function MarkerName(id)
    return _G["RAID_TARGET_" .. id] or MARKER_NAMES[id]
end

local function SetIcon(icon, id)
    if id == 0 then
        icon:SetTexture(CLEAR_TEXTURE)
        icon:SetTexCoord(0, 1, 0, 1)
    else
        icon:SetTexture(MARKER_SHEET)
        SetRaidTargetIconTexture(icon, id)
    end
end

local function Button_OnEnter(self)
    if not db.tooltips or GameTooltip:IsForbidden() then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(self.label)

    if self.markerID then
        local worldFirst = db.primary == "world"
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(worldFirst and WORLD or TARGET, NONE, 0, 1, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(worldFirst and TARGET or WORLD, db.modifier, 0, 1, 0, 1, 1, 1)
    end

    if self.hint then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(self.hint, 1, 1, 1)
    end

    if not CanMark() then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ERR_NOT_LEADER or "You are not the raid leader.", 1, 0.2, 0.2)
    end

    GameTooltip:Show()
end

local function Button_OnLeave()
    GameTooltip:Hide()
end

local function MakeButton(index, secure)
    local name = "RaidMarkerBarButton" .. index
    local button = CreateFrame("Button", name, bar, secure and "SecureActionButtonTemplate" or nil)

    -- On release only. Whether a secure macro fires on press depends on the
    -- ActionButtonUseKeyDown cvar, and registering both press and release runs
    -- the macro twice.
    button:RegisterForClicks("AnyUp")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT")
    icon:SetPoint("BOTTOMRIGHT")
    button.icon = icon

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(1, 1, 1, 0.25)

    button:SetScript("OnEnter", Button_OnEnter)
    button:SetScript("OnLeave", Button_OnLeave)

    return button
end

-- Ready check and countdown are ordinary API, not protected actions, so these
-- two are plain buttons rather than secure ones.
local function MakeExtras()
    local ready = MakeButton(NUM_MARKERS + 2, false)
    ready.label = READY_CHECK or "Ready Check"
    ready.icon:SetTexture(READY_TEXTURE)
    ready:SetScript("OnClick", function()
        if C_PartyInfo and C_PartyInfo.DoReadyCheck then
            C_PartyInfo.DoReadyCheck()
        elseif DoReadyCheck then
            DoReadyCheck()
        end
    end)

    local timer = MakeButton(NUM_MARKERS + 3, false)
    timer.icon:SetTexture(TIMER_TEXTURE)
    timer.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    timer.hint = "Right click cancels."
    timer:SetScript("OnClick", function(_, click)
        if not (C_PartyInfo and C_PartyInfo.DoCountdown) then
            return
        end
        -- Right click cancels a running pull.
        C_PartyInfo.DoCountdown(click == "RightButton" and 0 or db.countdown)
    end)
    timer:RegisterForClicks("AnyUp")

    return ready, timer
end

local function BuildButtons()
    if #buttons > 0 then
        return
    end

    -- Skull first, matching the order most marker bars use.
    for index = 1, NUM_MARKERS do
        local id = NUM_MARKERS + 1 - index
        local button = MakeButton(index, true)
        button.markerID = id
        button.label = MarkerName(id)
        SetIcon(button.icon, id)
        buttons[index] = button
    end

    local clear = MakeButton(NUM_MARKERS + 1, true)
    clear.markerID = 0
    clear.label = CLEAR_ALL or "Clear"
    SetIcon(clear.icon, 0)
    buttons[NUM_MARKERS + 1] = clear

    local ready, timer = MakeExtras()
    buttons[NUM_MARKERS + 2] = ready
    buttons[NUM_MARKERS + 3] = timer
    timerButton = timer
end

--------------------------------------------------------------------------------
--  Layout
--------------------------------------------------------------------------------

local function Layout()
    local size, gap, pad = db.size, db.spacing, 4
    local count = db.extras and (NUM_MARKERS + 3) or (NUM_MARKERS + 1)
    local span = count * size + (count - 1) * gap

    if db.vertical then
        bar:SetSize(size + pad * 2, span + pad * 2)
    else
        bar:SetSize(span + pad * 2, size + pad * 2)
    end

    local previous
    for index = 1, #buttons do
        local button = buttons[index]
        button:SetSize(size, size)
        button:ClearAllPoints()

        if index > count then
            -- Parked, not destroyed: a secure button cannot be recreated in
            -- combat, so the extras stay built even when switched off.
            button:SetPoint("TOPLEFT", bar, "TOPLEFT", pad, -pad)
            button:SetAlpha(0)
            button:EnableMouse(false)
        else
            button:SetAlpha(1)
            button:EnableMouse(true)

            if not previous then
                button:SetPoint("TOPLEFT", bar, "TOPLEFT", pad, -pad)
            elseif db.vertical then
                button:SetPoint("TOP", previous, "BOTTOM", 0, -gap)
            else
                button:SetPoint("LEFT", previous, "RIGHT", gap, 0)
            end
            previous = button
        end
    end

    local p = db.point
    bar:ClearAllPoints()
    bar:SetPoint(p[1], _G[p[2]] or UIParent, p[3], p[4], p[5])

    mover:ClearAllPoints()
    mover:SetAllPoints(bar)
end

--------------------------------------------------------------------------------
--  Frames
--------------------------------------------------------------------------------

-- Fill plus four one-pixel edges. Hand-drawn rather than the Backdrop API so
-- there is no BackdropTemplate dependency and the border stays crisp.
local function Backdrop(frame, r, g, b, a)
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetAllPoints(frame)
    bg:SetColorTexture(r, g, b, a)

    local function Edge(p1, p2, horizontal)
        local line = frame:CreateTexture(nil, "BORDER")
        line:SetColorTexture(0, 0, 0, 1)
        line:SetPoint(p1)
        line:SetPoint(p2)
        if horizontal then
            line:SetHeight(1)
        else
            line:SetWidth(1)
        end
        return line
    end

    Edge("TOPLEFT", "TOPRIGHT", true)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Edge("TOPLEFT", "BOTTOMLEFT", false)
    Edge("TOPRIGHT", "BOTTOMRIGHT", false)

    return bg
end

local function CreateMover()
    mover = CreateFrame("Frame", "RaidMarkerBarMover", UIParent)
    mover:SetFrameStrata("FULLSCREEN_DIALOG")
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()

    local bg = mover:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(mover)
    bg:SetColorTexture(0.1, 0.6, 1, 0.4)

    local label = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText("Raid markers")

    mover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then
            bar:StartMoving()
        end
    end)

    mover:SetScript("OnDragStop", function()
        if InCombatLockdown() then
            return
        end
        bar:StopMovingOrSizing()
        local point, _, relativePoint, x, y = bar:GetPoint()
        db.point = { point, "UIParent", relativePoint, x, y }
        bar:ClearAllPoints()
        bar:SetPoint(point, UIParent, relativePoint, x, y)
    end)
end

local function CreateBar()
    bar = CreateFrame("Frame", "RaidMarkerBar", UIParent, "SecureHandlerStateTemplate")
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    Backdrop(bar, 0.05, 0.05, 0.05, 0.85)

    CreateMover()
    BuildButtons()

    -- Mouseover fade needs no OnUpdate: two scripts and an alpha.
    bar:HookScript("OnHide", function()
        mover:Hide()
    end)
    bar:HookScript("OnShow", function()
        mover:SetShown(not db.locked)
    end)
end

--------------------------------------------------------------------------------
--  Apply
--------------------------------------------------------------------------------

local function Apply()
    if InCombatLockdown() then
        pending = true
        return
    end

    if not bar then
        CreateBar()
    end

    for index = 1, #buttons do
        ApplyAttributes(buttons[index])
    end

    timerButton.label = format("Pull Timer (%ds)", db.countdown)

    Layout()

    UnregisterStateDriver(bar, "visibility")
    if db.locked then
        RegisterStateDriver(bar, "visibility", VISIBILITY[db.show] or VISIBILITY.group)
    else
        -- Unlocked forces the bar on screen; otherwise "show in a group" leaves
        -- nothing to drag while solo.
        bar:Show()
    end

    UpdatePermission()
    mover:SetShown(bar:IsShown() and not db.locked)
end

-- The options panel reads these; it registers itself once db exists.
ns.Apply = Apply
ns.DEFAULTS = DEFAULTS

--------------------------------------------------------------------------------
--  Events
--------------------------------------------------------------------------------

local events = CreateFrame("Frame")
-- Registered up front, not with the bar: a /reload taken in combat defers the
-- first Apply, and there would be nothing listening to resume it.
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PARTY_LEADER_CHANGED")

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        RaidMarkerBarDB = RaidMarkerBarDB or {}
        db = RaidMarkerBarDB
        for key, value in pairs(DEFAULTS) do
            if db[key] == nil then
                db[key] = value
            end
        end
        if ns.SetupOptions then
            ns.SetupOptions(db)
        end
        Apply()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then
            pending = false
            Apply()
        end
    else
        UpdatePermission()
    end
end)

--------------------------------------------------------------------------------
--  Slash commands
--------------------------------------------------------------------------------

SLASH_RAIDMARKERBAR1 = "/rmb"
SLASH_RAIDMARKERBAR2 = "/raidmarkerbar"

SlashCmdList.RAIDMARKERBAR = function(input)
    local cmd, arg = (input or ""):lower():match("^(%S*)%s*(.-)%s*$")

    if cmd == "config" or cmd == "options" then
        -- Guarded like SetupOptions: without it a missing Options.lua turns
        -- the fallback message into an error.
        if not (ns.OpenOptions and ns.OpenOptions()) then
            Print("the options panel is unavailable.")
        end
        return
    elseif cmd == "lock" then
        db.locked = not db.locked
        Print(db.locked and "locked." or "unlocked - drag the handle.")
    elseif cmd == "size" then
        db.size = math.max(12, math.min(64, tonumber(arg) or db.size))
        Print("size", db.size)
    elseif cmd == "spacing" then
        db.spacing = math.max(0, math.min(20, tonumber(arg) or db.spacing))
        Print("spacing", db.spacing)
    elseif cmd == "vertical" then
        db.vertical = not db.vertical
        Print(db.vertical and "vertical." or "horizontal.")
    elseif cmd == "show" and VISIBILITY[arg] then
        db.show = arg
        Print("showing:", arg)
    elseif cmd == "swap" then
        db.primary = db.primary == "target" and "world" or "target"
        Print("plain click places the", db.primary, "marker.")
    elseif cmd == "mod" and MODIFIERS[arg] then
        db.modifier = arg
        Print("modifier:", arg)
    elseif cmd == "countdown" then
        db.countdown = math.max(3, math.min(60, tonumber(arg) or db.countdown))
        Print("pull timer", db.countdown .. "s")
    elseif cmd == "extras" then
        db.extras = not db.extras
        Print(db.extras and "ready check and countdown shown." or "extras hidden.")
    elseif cmd == "status" then
        Print("status")
        Print("  bar built:", bar and "yes" or "|cffff5555NO|r")
        if bar then
            Print(
                "  shown:",
                bar:IsShown() and "yes" or "|cffff5555NO|r",
                "  alpha:",
                bar:GetAlpha(),
                "  size:",
                math.floor(bar:GetWidth() or 0) .. "x" .. math.floor(bar:GetHeight() or 0)
            )
            local p1, _, p3, x, y = bar:GetPoint()
            Print(
                "  anchored:",
                tostring(p1),
                tostring(p3),
                tostring(x),
                tostring(y),
                "  strata:",
                bar:GetFrameStrata()
            )
        end
        Print("  show mode:", db.show, " locked:", tostring(db.locked))
        Print(
            "  in group:",
            tostring(IsInGroup()),
            " in raid:",
            tostring(IsInRaid()),
            " can mark:",
            tostring(CanMark())
        )
        Print("  if shown=no while grouped, run: /rmb show always")
        return
    elseif cmd == "reset" then
        for key, value in pairs(DEFAULTS) do
            db[key] = value
        end
        Print("reset to defaults.")
    else
        for _, line in ipairs(SLASH_HELP) do
            print(line)
        end
        return
    end

    Apply()
end
