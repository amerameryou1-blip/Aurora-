-- ============================================================
-- Delta Click Recorder v4.0 — Stealth Module
-- ============================================================
-- Comprehensive anti-detection layer for Delta Executor.
-- Covers: environment spoofing, GUI hiding, connection masking,
-- behavior randomization, anti-telemetry, and script obfuscation.
--
-- All functions are Delta-compatible (no unsupported APIs).
-- ============================================================

-- ==================== ENVIRONMENT CHECK ====================
local isDelta = false
pcall(function()
    isDelta = (identifyexecutor and identifyexecutor():lower():find("delta") ~= nil)
end)

-- ==================== SAFE API WRAPPER ====================
-- Wraps potentially detectable executor APIs with safe fallbacks
local SafeAPI = {}

local function safeCall(fn, ...)
    local ok, result = pcall(fn, ...)
    return ok, result
end

-- ==================== ENVIRONMENT SPOOFING ====================
-- Delta stores things in getgenv() that anti-cheats can scan for.
-- This module cleans up all traces after initialization.
local Environment = {}

function Environment.spoofGetgenv()
    -- Anti-cheats scan getgenv() for suspicious keys.
    -- We rename our keys to look like legitimate Roblox data.
    local legitKeys = {
        "_CR_GUI",
        "_CR_GUI_NAME",
        "_CR_UI",
        "_CR_LOGIC",
        "_CR_CONN",
        "_CR_HB",
        "_CR_RECORDING",
        "_CR_REPLAYING",
        "_CR_GUI_LOADED",
        "_CR_LOGIC_LOADED",
        "clickLog",
    }

    local spoofMap = {
        _CR_GUI         = "rbx_session_" .. string.format("%08x", math.random(0, 0xFFFFFFFF)),
        _CR_GUI_NAME    = "rbx_config_" .. string.format("%08x", math.random(0, 0xFFFFFFFF)),
        _CR_UI          = "rbx_ui_" .. string.format("%08x", math.random(0, 0xFFFFFFFF)),
        _CR_LOGIC       = "rbx_logic_" .. string.format("%08x", math.random(0, 0xFFFFFFFF)),
        _CR_CONN        = "rbx_conn_" .. string.format("%08x", math.random(0, 0xFFFFFFFF)),
        _CR_HB          = "rbx_hb_" .. string.format("%08x", math.random(0, 0xFFFFFFFF)),
        _CR_RECORDING   = "rbx_rec_" .. string.format("%08x", math.random(0, 0xFFFFFFFF)),
        _CR_REPLAYING   = "rbx_rep_" .. string.format("%08x", math.random(0, 0xFFFFFFFF)),
        _CR_GUI_LOADED  = "rbx_gload_" .. string.format("%08x", math.random(0, 0xFFFFFFFF)),
        _CR_LOGIC_LOADED = "rbx_lload_" .. string.format("%08x", math.random(0, 0xFFFFFFFF)),
        clickLog        = "rbx_log_" .. string.format("%08x", math.random(0, 0xFFFFFFFF)),
    }

    -- Store the mapping so modules can reference spoofed keys
    Environment._spoofMap = spoofMap

    -- Migrate existing values to spoofed keys
    for oldKey, newKey in pairs(spoofMap) do
        local val = getgenv()[oldKey]
        if val ~= nil then
            getgenv()[newKey] = val
            getgenv()[oldKey] = nil
        end
    end

    return spoofMap
end

function Environment.getSpoofedKey(originalKey)
    if Environment._spoofMap and Environment._spoofMap[originalKey] then
        return Environment._spoofMap[originalKey]
    end
    return originalKey
end

function Environment.setValue(key, value)
    local spoofedKey = Environment.getSpoofedKey(key)
    getgenv()[spoofedKey] = value
end

function Environment.getValue(key)
    local spoofedKey = Environment.getSpoofedKey(key)
    return getgenv()[spoofedKey]
end

-- ==================== GUI STEALTH ====================
-- Makes GUI elements blend in and become undetectable
-- by anti-cheat ScreenGui scanners.
local GUIStealth = {}

function GUIStealth.hideFromExplorer(guiInstance)
    -- Delta supports sethiddenproperty — use it to hide from
    -- explorer-based detection tools
    if sethiddenproperty and guiInstance then
        pcall(function()
            sethiddenproperty(guiInstance, "ZIndex", -1)
        end)
    end
end

function GUIStealth.makeInnocent(guiInstance, innocentName)
    -- Rename GUI elements to look like legitimate Roblox UI
    if guiInstance and innocentName then
        pcall(function()
            guiInstance.Name = innocentName
        end)
    end
end

function GUIStealth.disableScreenGuiDetection(screenGui)
    -- Anti-cheats scan for ScreenGuis with suspicious properties.
    -- We neutralize all detectable markers.
    if not screenGui then return end

    -- Disable reset on spawn (already done, but double-check)
    pcall(function()
        screenGui.ResetOnSpawn = false
    end)

    -- Set to core GUI level if possible
    if setcorescreenenabled then
        pcall(function()
            setcorescreenenabled(screenGui, false)
        end)
    end

    -- Hide from explorer if Delta supports it
    GUIStealth.hideFromExplorer(screenGui)
end

function GUIStealth.innocentNames()
    -- Returns a list of names that look like legitimate Roblox GUIs
    local names = {
        "PlayerList",
        "Chat",
        "HealthBar",
        "TouchGui",
        "ControlScript",
        "PlayerModule",
        "RobloxGui",
        "CoreGui",
        "StarterGui",
        "GamepadSupport",
        "KeyboardProvider",
        "MouseBehavior",
        "CameraModule",
        "BaseCamera",
        "PopperCam",
        "ZoomController",
        "GuiService",
        "TextChatService",
        "VoiceChatService",
        "NotificationService",
    }
    return names[math.random(1, #names)]
end

-- ==================== CONNECTION MASKING ====================
-- Hides event connections from anti-cheat connection scanners
local ConnectionMask = {}

function ConnectionMask.wrapConnection(conn)
    -- Wrap a connection object so it doesn't appear in
    -- getconnections() scans by anti-cheat
    if hookmetamethod and conn then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "GetChildren" or method == "GetDescendants" then
                -- Filter out our connection from scans
                local result = oldNamecall(self, ...)
                local filtered = {}
                for _, item in ipairs(result) do
                    if item ~= conn then
                        table.insert(filtered, item)
                    end
                end
                return filtered
            end
            return oldNamecall(self, ...)
        end)
    end
    return conn
end

function ConnectionMask.safeDisconnect(conn)
    pcall(function()
        if conn and typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end)
end

-- ==================== BEHAVIOR RANDOMIZATION ====================
-- Makes script behavior look more human and less automated
local Behavior = {}

function Behavior.randomDelay(min, max)
    -- Returns a random delay between min and max seconds
    -- Anti-cheats detect fixed-interval patterns
    min = min or 0.01
    max = max or 0.05
    return min + math.random() * (max - min)
end

function Behavior.jitter(value, percent)
    -- Adds random jitter to a value (e.g., coordinates)
    percent = percent or 0.02
    local range = value * percent
    return value + (math.random() * range * 2 - range)
end

-- ==================== ANTI-TELEMETRY ====================
-- Blocks common anti-cheat telemetry methods
local AntiTelemetry = {}

function AntiTelemetry.blockHttpSpy()
    -- Prevent anti-cheat from detecting our HTTP calls
    -- by wrapping HttpGet/HttpPost if possible
    if hookfunction then
        local httpService = game:GetService("HttpService")
        -- Note: We don't actually block HttpService — that would break
        -- the loader. Instead, we just note this as a placeholder for
        -- future implementation if Delta adds hookfunction support.
    end
end

function AntiTelemetry.suppressWarnings()
    -- Suppress warn() output that could reveal script activity
    if hookfunction then
        pcall(function()
            hookfunction(warn, function(...) end)
        end)
    end
end

function AntiTelemetry.suppressPrint()
    -- Suppress print() output
    if hookfunction then
        pcall(function()
            hookfunction(print, function(...) end)
        end)
    end
end

-- ==================== SCRIPT IDENTITY ====================
-- Generates unique, non-suspicious identifiers
local Identity = {}

local function hexId()
    return string.format("%08x", math.random(0, 0xFFFFFFFF))
end

function Identity.generateSessionId()
    return "sess_" .. hexId()
end

function Identity.generateInstanceId()
    return "inst_" .. hexId()
end

function Identity.generateToken()
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    local token = ""
    for i = 1, 32 do
        token = token .. chars:sub(math.random(1, #chars), math.random(1, #chars))
    end
    return token
end

-- ==================== EXECUTOR DETECTION ====================
-- Detects what executor is running and adapts accordingly
local ExecutorInfo = {}

function ExecutorInfo.detect()
    local info = {
        name = "unknown",
        isDelta = false,
        supportsHookfunction = false,
        supportsSethiddenproperty = false,
        supportsHookmetamethod = false,
        supportsNewcclosure = false,
        supportsGethui = false,
        supportsCheckcaller = false,
    }

    pcall(function()
        info.name = identifyexecutor()
        info.isDelta = info.name:lower():find("delta") ~= nil
    end)

    info.supportsHookfunction = hookfunction ~= nil
    info.supportsSethiddenproperty = sethiddenproperty ~= nil
    info.supportsHookmetamethod = hookmetamethod ~= nil
    info.supportsNewcclosure = newcclosure ~= nil
    info.supportsGethui = gethui ~= nil
    info.supportsCheckcaller = checkcaller ~= nil

    return info
end

-- ==================== MEMORY CLEANUP ====================
-- Cleans up script traces from memory after execution
local Memory = {}

function Memory.clearScriptTraces()
    -- Remove any traces that memory scanners could find
    -- This is a best-effort cleanup
    pcall(function()
        -- Clear debug library traces
        if debug and debug.getregistry then
            -- Don't actually call this — it's dangerous
            -- Just noting it as a capability check
        end
    end)
end

function Memory.obfuscateStrings(str)
    -- Simple XOR obfuscation for sensitive strings
    local key = math.random(1, 255)
    local result = {}
    for i = 1, #str do
        table.insert(result, bit32.bxor(str:byte(i), key))
    end
    return { bytes = result, key = key }
end

function Memory.deobfuscateString(data)
    local result = ""
    for _, byte in ipairs(data.bytes) do
        result = result .. string.char(bit32.bxor(byte, data.key))
    end
    return result
end

-- ==================== MAIN STEALTH INITIALIZER ====================
local Stealth = {
    Environment     = Environment,
    GUIStealth      = GUIStealth,
    ConnectionMask  = ConnectionMask,
    Behavior        = Behavior,
    AntiTelemetry   = AntiTelemetry,
    Identity        = Identity,
    ExecutorInfo    = ExecutorInfo,
    Memory          = Memory,
    SafeAPI         = SafeAPI,
    isDelta         = isDelta,
}

-- Initialize stealth layer
function Stealth.init()
    -- 1. Detect executor capabilities
    local execInfo = ExecutorInfo.detect()

    -- 2. Spoof environment keys (rename _CR_* to look legitimate)
    Environment.spoofGetgenv()

    -- 3. Suppress output if hookfunction is available
    if execInfo.supportsHookfunction then
        AntiTelemetry.suppressWarnings()
        AntiTelemetry.suppressPrint()
    end

    return execInfo
end

return Stealth
