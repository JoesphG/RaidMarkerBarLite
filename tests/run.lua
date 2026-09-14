local FILE = "Core.lua"

local Widget = {}
Widget.__index = Widget
local function nop() end
local frames = {}
local function W(kind, name, parent, template)
    local w = setmetatable({
        kind = kind,
        name = name,
        parent = parent,
        template = template,
        attrs = {},
        scripts = {},
        points = {},
        regions = {},
        alpha = 1,
        shown = true,
    }, Widget)
    if name then
        _G[name] = w
    end
    frames[#frames + 1] = w
    return w
end
function Widget:SetAttribute(k, v)
    self.attrs[k] = v
end
function Widget:SetScript(s, f)
    self.scripts[s] = f
end
function Widget:HookScript(s, f)
    self.scripts[s] = f
end
function Widget:RegisterEvent(e)
    self.events = self.events or {}
    self.events[e] = true
end
function Widget:SetPoint(...)
    self.points[#self.points + 1] = { ... }
end
function Widget:ClearAllPoints()
    self.points = {}
end
function Widget:GetPoint()
    return "CENTER", self.parent, "CENTER", 0, 0
end
function Widget:SetSize(w, h)
    self.w, self.h = w, h
end
function Widget:SetShown(v)
    self.shown = v and true or false
end
function Widget:Show()
    self.shown = true
end
function Widget:Hide()
    self.shown = false
end
function Widget:IsShown()
    return self.shown
end
function Widget:SetAlpha(a)
    self.alpha = a
end
function Widget:IsForbidden()
    return false
end
function Widget:RegisterForClicks(...)
    self.clicks = { ... }
end
function Widget:CreateTexture()
    local t = W("Texture")
    self.regions[#self.regions + 1] = t
    return t
end
function Widget:CreateFontString()
    return W("FontString")
end
function Widget:SetTexture(t)
    self.texture = t
end
function Widget:SetTexCoord(...)
    self.coords = { ... }
end
function Widget:GetAlpha()
    return self.alpha
end
function Widget:GetWidth()
    return self.w or 0
end
function Widget:GetHeight()
    return self.h or 0
end
function Widget:GetFrameStrata()
    return "MEDIUM"
end
for _, m in ipairs({
    "SetAllPoints",
    "SetColorTexture",
    "SetHeight",
    "SetWidth",
    "SetText",
    "EnableMouse",
    "RegisterForDrag",
    "SetFrameStrata",
    "SetClampedToScreen",
    "SetMovable",
    "StartMoving",
    "StopMovingOrSizing",
    "SetOwner",
    "AddLine",
    "AddDoubleLine",
}) do
    Widget[m] = nop
end

function CreateFrame(k, n, p, t)
    return W(k, n, p, t)
end
UIParent = W("Frame", "UIParent")
GameTooltip = W("GameTooltip", "GameTooltip")
local inCombat = false
InCombatLockdown = function()
    return inCombat
end
-- Core.lua localises these at file scope, so the stubs must read mutable
-- state rather than be reassigned after load.
local state = { inRaid = false, leader = true, assist = false }
IsInGroup = function()
    return true
end
IsInRaid = function()
    return state.inRaid
end
UnitIsGroupLeader = function()
    return state.leader
end
UnitIsGroupAssistant = function()
    return state.assist
end
local drivers = {}
RegisterStateDriver = function(f, k, v)
    drivers[k] = v
end
UnregisterStateDriver = function(_, k)
    drivers[k] = nil
end
SetRaidTargetIconTexture = function(tex, id)
    tex.markerCoords = id
end
SLASH_TARGET_MARKER4, SLASH_WORLD_MARKER1, SLASH_CLEAR_WORLD_MARKER1 = "/tm", "/wm", "/cwm"
TARGET, WORLD, NONE, CLEAR_ALL, ERR_NOT_LEADER, READY_CHECK = "T", "W", "None", "Clear", "Not leader", "Ready Check"
C_PartyInfo = {
    DoReadyCheck = function()
        _G.__ready = true
    end,
    DoCountdown = function(s)
        _G.__count = s
    end,
}
SlashCmdList = {}
local printed = {}
print = function(...)
    local t = {}
    for i = 1, select("#", ...) do
        t[#t + 1] = tostring((select(i, ...)))
    end
    printed[#printed + 1] = table.concat(t, " ")
end

-- Core takes the addon namespace table as its second vararg; Options.lua reads
-- what it puts there. Loading it with one argument is how this suite broke when
-- the options panel arrived.
local ns = {}
assert(loadfile(FILE))("RaidMarkerBar", ns)

local realprint = io.write
local fails = 0
local function check(n, ok, extra)
    if ok then
        realprint("  ok   " .. n .. "\n")
    else
        fails = fails + 1
        realprint("  FAIL " .. n .. (extra and (" -- " .. tostring(extra)) or "") .. "\n")
    end
end
realprint("RaidMarkerBar test\n")

-- No libraries at all.
check("no LibStub dependency", LibStub == nil)

local ev
for _, f in ipairs(frames) do
    if f.events and f.events.PLAYER_LOGIN then
        ev = f
    end
end
check("event frame registered", ev ~= nil)
check("PLAYER_REGEN_ENABLED registered up front", ev.events.PLAYER_REGEN_ENABLED == true)

ev.scripts.OnEvent(ev, "PLAYER_LOGIN")
check("saved variables seeded", RaidMarkerBarDB and RaidMarkerBarDB.size == 28)

local bar = _G.RaidMarkerBar
check("bar built", bar ~= nil)
check("bar is a secure state handler", bar.template == "SecureHandlerStateTemplate")

local b1 = _G.RaidMarkerBarButton1
check("skull first", b1.markerID == 8, b1.markerID)
check("markers are secure buttons", b1.template == "SecureActionButtonTemplate")
check("clicks on release", b1.clicks[1] == "AnyUp", b1.clicks[1])

-- The bug that silently did nothing: type* alone never resolves.
check("explicit type1", b1.attrs.type1 == "macro")
check("plain click sets the target marker", b1.attrs.macrotext1 == "/tm 8", b1.attrs.macrotext1)
check("modified type present", b1.attrs["shift-type1"] == "macro")
check("shift places the world marker", b1.attrs["shift-macrotext1"] == "/cwm 8\n/wm 8", b1.attrs["shift-macrotext1"])

-- The bug that left every button blank.
check("icon points at the sheet", b1.icon.texture:find("RaidTargetingIcons") ~= nil, b1.icon.texture)
check("icon cropped to its marker", b1.icon.markerCoords == 8)

local star = _G.RaidMarkerBarButton8
check("star maps to world marker 5", star.attrs["shift-macrotext1"] == "/cwm 5\n/wm 5", star.attrs["shift-macrotext1"])

local clear = _G.RaidMarkerBarButton9
check("clear wipes the target marker", clear.attrs.macrotext1 == "/tm 0")
check("shift-clear wipes world markers", clear.attrs["shift-macrotext1"] == "/cwm 0")
check("clear uses the pass icon", clear.icon.texture:find("Pass%-Up") ~= nil)

-- Extras are plain buttons: these are ordinary API, not protected actions.
local ready, timer = _G.RaidMarkerBarButton10, _G.RaidMarkerBarButton11
check("ready check is NOT a secure button", ready.template == nil)
ready.scripts.OnClick()
check("ready check fires", _G.__ready == true)
timer.scripts.OnClick(timer, "LeftButton")
check("pull timer starts at 5", _G.__count == 5, _G.__count)
timer.scripts.OnClick(timer, "RightButton")
check("right click cancels the pull", _G.__count == 0, _G.__count)

-- The options panel is a separate file; Core hands it these and nothing else.
check("Apply exported for the panel", type(ns.Apply) == "function")
check("DEFAULTS exported for the panel", type(ns.DEFAULTS) == "table")
check("countdown has a default", ns.DEFAULTS.countdown == 5, ns.DEFAULTS.countdown)

SlashCmdList.RAIDMARKERBAR("countdown 30")
check("countdown is a setting", RaidMarkerBarDB.countdown == 30, RaidMarkerBarDB.countdown)
timer.scripts.OnClick(timer, "LeftButton")
check("pull timer uses it", _G.__count == 30, _G.__count)
check("the label carries the value", timer.label == "Pull Timer (30s)", timer.label)

SlashCmdList.RAIDMARKERBAR("countdown 999")
check("countdown clamped high", RaidMarkerBarDB.countdown == 60, RaidMarkerBarDB.countdown)
SlashCmdList.RAIDMARKERBAR("countdown 1")
check("countdown clamped low", RaidMarkerBarDB.countdown == 3, RaidMarkerBarDB.countdown)
SlashCmdList.RAIDMARKERBAR("countdown 5")

-- /rmb config reaches the panel when it loaded, and says so when it did not.
local opened = 0
ns.OpenOptions = function()
    opened = opened + 1
    return true
end
SlashCmdList.RAIDMARKERBAR("config")
check("config opens the panel", opened == 1, opened)
ns.OpenOptions = nil
printed = {}
SlashCmdList.RAIDMARKERBAR("config")
check("config says so when the panel is absent", (printed[1] or ""):find("unavailable") ~= nil, printed[1])

-- Locked by default so the drag handle cannot eat clicks.
check("locked by default", RaidMarkerBarDB.locked == true)
check("handle hidden while locked", _G.RaidMarkerBarMover.shown == false)
check("state driver owns visibility", drivers.visibility == "[group] show; hide", drivers.visibility)

-- Layout maths: 11 buttons at 28 with 4 spacing plus 4 padding a side.
check("bar width", bar.w == 11 * 28 + 10 * 4 + 8, bar.w)

SlashCmdList.RAIDMARKERBAR("extras")
check("extras off shrinks the bar", bar.w == 9 * 28 + 8 * 4 + 8, bar.w)
check("parked extras are click-through", ready.alpha == 0)
SlashCmdList.RAIDMARKERBAR("extras")

SlashCmdList.RAIDMARKERBAR("swap")
check("swap moves world to the plain click", b1.attrs.macrotext1 == "/cwm 8\n/wm 8", b1.attrs.macrotext1)
SlashCmdList.RAIDMARKERBAR("swap")

SlashCmdList.RAIDMARKERBAR("mod ctrl")
check("ctrl prefix applied", b1.attrs["ctrl-macrotext1"] ~= nil)
check("stale shift prefix cleared", b1.attrs["shift-macrotext1"] == nil)

SlashCmdList.RAIDMARKERBAR("lock")
check("unlocked drops the driver", drivers.visibility == nil)
check("unlocked shows the handle", _G.RaidMarkerBarMover.shown == true)
SlashCmdList.RAIDMARKERBAR("lock")

SlashCmdList.RAIDMARKERBAR("size 999")
check("size clamped", RaidMarkerBarDB.size == 64, RaidMarkerBarDB.size)

-- Combat defers rather than touching protected frames.
inCombat = true
SlashCmdList.RAIDMARKERBAR("size 20")
check("combat defers the resize", bar.w ~= 11 * 20 + 10 * 4 + 8)
inCombat = false
ev.scripts.OnEvent(ev, "PLAYER_REGEN_ENABLED")
check("resize lands after combat", bar.w == 11 * 20 + 10 * 4 + 8, bar.w)

-- Raid without assist: dim, never hide.
state.inRaid, state.leader, state.assist = true, false, false
ev.scripts.OnEvent(ev, "GROUP_ROSTER_UPDATE")
check("dimmed without assist", bar.alpha == 0.35, bar.alpha)
check("still shown, not hidden", bar.shown == true)

state.assist = true
ev.scripts.OnEvent(ev, "GROUP_ROSTER_UPDATE")
check("assist restores full alpha", bar.alpha == 1, bar.alpha)

-- A party has no assistants, so the gate must not apply there.
state.inRaid, state.leader, state.assist = false, false, false
ev.scripts.OnEvent(ev, "GROUP_ROSTER_UPDATE")
check("party members can always mark", bar.alpha == 1, bar.alpha)

-- The diagnostic must run without erroring and report the real state.
printed = {}
SlashCmdList.RAIDMARKERBAR("status")
local blob = table.concat(printed, "\n")
check("status runs", #printed > 0)
check("status reports shown state", blob:find("shown:") ~= nil)
check("status reports group state", blob:find("in raid:") ~= nil)

realprint(fails == 0 and "\nall checks passed\n" or ("\n" .. fails .. " failed\n"))
os.exit(fails == 0 and 0 or 1)
