-- ============================================================
-- Delta Click Recorder v4.0 — Logic Module
-- ============================================================
-- Pure business logic: services, platform detection, coordinate
-- calibration, click recording, and click replaying.
--
-- Integrates with Stealth.lua for anti-detection.
-- Zero UI construction — delegates to GUI module.
-- ============================================================

-- ==================== STEALTH INTEGRATION ====================
-- Stealth module is passed via init(). If not provided,
-- falls back to direct getgenv() access (backward compatible).
local Stealth = nil

-- ==================== PREVENT DOUBLE LOAD ====================
if getgenv() and getgenv()._CR_LOGIC_LOADED then
    return getgenv()._CR_LOGIC
end
if getgenv() then getgenv()._CR_LOGIC_LOADED = true end

-- ==================== CLEANUP PREVIOUS STATE ====================
if getgenv() and getgenv()._CR_CONN then
    pcall(function() getgenv()._CR_CONN:Disconnect() end)
    getgenv()._CR_CONN = nil
end
if getgenv() and getgenv()._CR_HB then
    pcall(function() getgenv()._CR_HB:Disconnect() end)
    getgenv()._CR_HB = nil
end
if getgenv() then
    getgenv()._CR_REPLAYING = false
    getgenv()._CR_RECORDING = false
end

-- ==================== SHARED STATE ====================
if getgenv() then getgenv().clickLog = getgenv().clickLog or {} end

-- ==================== SERVICES ====================
local UIS = game:GetService("UserInputService")
local GS  = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

-- ==================== PLATFORM DETECTION ====================
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
local isDelta = false
pcall(function()
    isDelta = (identifyexecutor():lower():find("delta") ~= nil)
end)

-- ==================== COORDINATE CALIBRATION ====================
local correction = Vector2.new(0, 0)

do
    local guiInset = Vector2.new(0, 0)
    local notchOffset = Vector2.new(0, 0)

    task.wait(0.2)
    guiInset = GS:GetGuiInset()

    if guiInset.Y < 1 and isMobile then
        local signalFired = false
        local conn
        pcall(function()
            conn = GS:GetPropertyChangedSignal("TopbarInset"):Once(function()
                signalFired = true
            end)
        end)

        local elapsed = 0
        while not signalFired and elapsed < 1.5 do
            task.wait(0.05)
            elapsed = elapsed + 0.05
        end
        if conn then pcall(function() conn:Disconnect() end) end

        guiInset = GS:GetGuiInset()
        if guiInset.Y < 1 then
            guiInset = Vector2.new(0, 58)
        end
    end

    if isMobile then
        pcall(function()
            local Players = game:GetService("Players")
            local player = Players.LocalPlayer
            local playerGui = player:WaitForChild("PlayerGui")

            local probeGui = Instance.new("ScreenGui")
            probeGui.Name = "_P" .. math.random(10000, 99999)
            probeGui.ScreenInsets = Enum.ScreenInsets.None
            probeGui.ResetOnSpawn = false

            if gethui then
                pcall(function() probeGui.Parent = gethui() end)
            end
            if not probeGui.Parent then
                probeGui.Parent = playerGui
            end

            local probeFrame = Instance.new("Frame")
            probeFrame.Size = UDim2.new(1, 0, 1, 0)
            probeFrame.BackgroundTransparency = 1
            probeFrame.Parent = probeGui

            RunService.RenderStepped:Wait()
            RunService.RenderStepped:Wait()

            local fullWidth = probeFrame.AbsoluteSize.X
            probeGui:Destroy()

            local cam = workspace.CurrentCamera
            if cam then
                local vpWidth = cam.ViewportSize.X
                local dx = fullWidth - vpWidth
                if dx > 2 then
                    notchOffset = Vector2.new(math.floor(dx / 2), 0)
                end
            end
        end)
    end

    correction = Vector2.new(
        guiInset.X + notchOffset.X,
        guiInset.Y + notchOffset.Y
    )
end

-- ==================== HELPERS ====================
-- Safe getgenv accessor that uses Stealth if available
local function envGet(key)
    if Stealth and Stealth.Environment then
        return Stealth.Environment.getValue(key)
    end
    return getgenv() and getgenv()[key]
end

local function envSet(key, value)
    if Stealth and Stealth.Environment then
        Stealth.Environment.setValue(key, value)
    end
    if getgenv() then getgenv()[key] = value end
end

local function getClickLog()
    return envGet("clickLog") or {}
end

-- ==================== INTERNAL STATE ====================
local _recording = false
local _replaying = false
local _inputConn   = nil
local _replayThread = nil
local gui = nil

-- ==================== RECORDING ENGINE ====================
local function startRecording()
    if _replaying then return end
    _recording = true
    envSet("clickLog", {})

    if gui then
        gui.setRecordButtonState("recording")
        gui.setStatus("Recording...", Color3.fromRGB(220, 60, 60))
    end

    _inputConn = UIS.InputBegan:Connect(function(input, gameProcessed)
        if not _recording then return end

        local validType = (input.UserInputType == Enum.UserInputType.MouseButton1)
                       or (input.UserInputType == Enum.UserInputType.Touch)
        if not validType then return end

        local pos = input.Position
        local absX = pos.X + correction.X
        local absY = pos.Y + correction.Y

        -- Filter out clicks on our own GUI
        if gui and gui.isOverRecorderGui(absX, absY) then
            return
        end

        local log = getClickLog()
        table.insert(log, {
            t = tick(),
            x = absX,
            y = absY
        })
        envSet("clickLog", log)

        if gui then
            gui.setStatus("Rec: " .. #log, Color3.fromRGB(220, 60, 60))
        end
    end)

    envSet("_CR_CONN", _inputConn)
end

local function stopRecording()
    _recording = false

    if _inputConn then
        pcall(function() _inputConn:Disconnect() end)
        _inputConn = nil
    end
    envSet("_CR_CONN", nil)

    if gui then
        gui.setRecordButtonState("idle")
        local n = #getClickLog()
        gui.setStatus(
            n .. " click" .. (n == 1 and "" or "s") .. " saved",
            Color3.fromRGB(200, 180, 50)
        )
    end
end

-- ==================== REPLAY ENGINE ====================
local function startReplaying()
    if _recording then return end

    local log = getClickLog()
    if #log == 0 then
        if gui then
            gui.setStatus("Nothing to replay", Color3.fromRGB(200, 100, 50))
        end
        return
    end

    _replaying = true
    envSet("_CR_REPLAYING", true)

    if gui then
        gui.setReplayButtonState("replaying")
        gui.setStatus("Replaying...", Color3.fromRGB(60, 180, 90))
    end

    _replayThread = task.spawn(function()
        for i, entry in ipairs(log) do
            if not _replaying then break end

            -- Precise inter-click delay using Heartbeat
            if i > 1 then
                local dt = entry.t - log[i - 1].t
                if dt > 0 then
                    local startWait = tick()
                    while (tick() - startWait) < dt do
                        if not _replaying then break end
                        RunService.Heartbeat:Wait()
                    end
                end
            end

            if not _replaying then break end

            -- Send mouse down
            VIM:SendMouseButtonEvent(entry.x, entry.y, 0, true, game, 1)
            task.wait(0.03)
            -- Send mouse up
            VIM:SendMouseButtonEvent(entry.x, entry.y, 0, false, game, 1)

            if gui then
                gui.setStatus("Replay " .. i .. "/" .. #log, Color3.fromRGB(60, 180, 90))
            end
        end

        -- Replay finished naturally
        _replaying = false
        envSet("_CR_REPLAYING", false)

        if gui then
            gui.setReplayButtonState("idle")
            gui.setStatus("Done " .. #log .. " clicks", Color3.fromRGB(100, 200, 130))
        end
    end)
end

local function stopReplaying()
    _replaying = false
    envSet("_CR_REPLAYING", false)

    if _replayThread then
        task.cancel(_replayThread)
        _replayThread = nil
    end

    if gui then
        gui.setReplayButtonState("idle")
        gui.setStatus("Replay stopped", Color3.fromRGB(200, 180, 50))
    end
end

-- ==================== TOGGLE HANDLERS ====================
local function onRecordToggle()
    if _replaying then return end
    if not _recording then
        startRecording()
    else
        stopRecording()
    end
end

local function onReplayToggle()
    if _recording then return end
    if not _replaying then
        startReplaying()
    else
        stopReplaying()
    end
end

-- ==================== PUBLIC API ====================
local publicAPI = {

    init = function(guiModule, stealthModule)
        if not guiModule then
            return false
        end
        gui = guiModule
        Stealth = stealthModule

        -- Apply GUI stealth if available
        if Stealth and Stealth.GUIStealth and gui then
            Stealth.GUIStealth.disableScreenGuiDetection(gui.rootGui)
        end

        -- Register toggle callbacks
        gui.setCallbacks({
            onRecordToggle = onRecordToggle,
            onReplayToggle = onReplayToggle,
        })

        -- Restore status from pre-existing click log
        local n = #getClickLog()
        if n > 0 then
            gui.setStatus(n .. " clicks loaded", Color3.fromRGB(130, 130, 150))
        end

        return true
    end,

    isRecording = function()
        return _recording
    end,

    isReplaying = function()
        return _replaying
    end,

    getClickCount = function()
        return #getClickLog()
    end,

    getClickLog = function()
        return getClickLog()
    end,

    record = function()
        startRecording()
    end,

    stopRecord = function()
        stopRecording()
    end,

    replay = function()
        startReplaying()
    end,

    stopReplay = function()
        stopReplaying()
    end,

    clearLog = function()
        envSet("clickLog", {})
        if gui then
            gui.setStatus("Log cleared", Color3.fromRGB(130, 130, 150))
        end
    end,

    getCorrection = function()
        return correction
    end,

    isMobile = function()
        return isMobile
    end,

    isDelta = function()
        return isDelta
    end,

    destroy = function()
        stopRecording()
        stopReplaying()
        envSet("clickLog", {})
        envSet("_CR_LOGIC", nil)
        envSet("_CR_LOGIC_LOADED", nil)
    end,
}

envSet("_CR_LOGIC", publicAPI)
return publicAPI
