-- Delta Click Recorder v5.2 - Stealth Module

local isDelta = false
pcall(function()
    isDelta = (identifyexecutor and identifyexecutor():lower():find("delta") ~= nil)
end)

local Environment = {}

function Environment.spoofGetgenv()
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
    Environment._spoofMap = spoofMap
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

local GUIStealth = {}

function GUIStealth.hideFromExplorer(guiInstance)
    if sethiddenproperty and guiInstance then
        pcall(function()
            sethiddenproperty(guiInstance, "ZIndex", -1)
        end)
    end
end

function GUIStealth.disableScreenGuiDetection(screenGui)
    if not screenGui then return end
    pcall(function()
        screenGui.ResetOnSpawn = false
    end)
    GUIStealth.hideFromExplorer(screenGui)
end

function GUIStealth.innocentNames()
    local names = {
        "PlayerList", "Chat", "HealthBar", "TouchGui", "ControlScript",
        "PlayerModule", "RobloxGui", "CoreGui", "StarterGui", "GamepadSupport",
        "KeyboardProvider", "MouseBehavior", "CameraModule", "BaseCamera",
        "PopperCam", "ZoomController", "GuiService", "TextChatService",
        "VoiceChatService", "NotificationService",
    }
    return names[math.random(1, #names)]
end

local ConnectionMask = {}

function ConnectionMask.wrapConnection(conn)
    if hookmetamethod and conn then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "GetChildren" or method == "GetDescendants" then
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

local Behavior = {}

function Behavior.randomDelay(min, max)
    min = min or 0.01
    max = max or 0.05
    return min + math.random() * (max - min)
end

function Behavior.jitter(value, percent)
    percent = percent or 0.02
    local range = value * percent
    return value + (math.random() * range * 2 - range)
end

local Identity = {}

local function hexId()
    return string.format("%08x", math.random(0, 0xFFFFFFFF))
end

function Identity.generateSessionId()
    return "sess_" .. hexId()
end

function Identity.generateToken()
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    local token = ""
    for i = 1, 32 do
        token = token .. chars:sub(math.random(1, #chars), math.random(1, #chars))
    end
    return token
end

local ExecutorInfo = {}

function ExecutorInfo.detect()
    local info = {
        name = "unknown",
        isDelta = false,
        supportsHookfunction = hookfunction ~= nil,
        supportsSethiddenproperty = sethiddenproperty ~= nil,
        supportsHookmetamethod = hookmetamethod ~= nil,
        supportsNewcclosure = newcclosure ~= nil,
        supportsGethui = gethui ~= nil,
        supportsCheckcaller = checkcaller ~= nil,
    }
    pcall(function()
        info.name = identifyexecutor()
        info.isDelta = info.name:lower():find("delta") ~= nil
    end)
    return info
end

local Memory = {}

function Memory.obfuscateStrings(str)
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

local Stealth = {
    Environment     = Environment,
    GUIStealth      = GUIStealth,
    ConnectionMask  = ConnectionMask,
    Behavior        = Behavior,
    Identity        = Identity,
    ExecutorInfo    = ExecutorInfo,
    Memory          = Memory,
    isDelta         = isDelta,
}

function Stealth.init()
    local execInfo = ExecutorInfo.detect()
    Environment.spoofGetgenv()
    return execInfo
end

return Stealth
