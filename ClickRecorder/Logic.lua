-- ============================================================
-- Delta Click Recorder v4.0 — Logic Module
-- Pure business logic: services, platform detection, coordinate
-- calibration, click recording, and click replaying.
--
-- Zero UI construction — all visual updates are delegated to
-- the GUI module via the public API.
--
-- Usage:
--   local GUI   = loadstring(game:HttpGet("GUI.lua"))()
--   local Logic = loadstring(game:HttpGet("Logic.lua"))()
--   Logic.init(GUI)
-- ============================================================

-- ==================== PREVENT DOUBLE LOAD ====================
if getgenv()._CR_LOGIC_LOADED then
    warn("[ClickRecorder] Logic already loaded. Skipping.")
    return getgenv()._CR_LOGIC
end
getgenv()._CR_LOGIC_LOADED = true

-- ==================== CLEANUP PREVIOUS STATE ====================
if getgenv()._CR_CONN then
    pcall(function() getgenv()._CR_CONN:Disconnect() end)
    getgenv()._CR_CONN = nil
end
if getgenv()._CR_HB then
    pcall(function() getgenv()._CR_HB:Disconnect() end)
    getgenv()._CR_HB = nil
end
getgenv()._CR_REPLAYING = false
getgenv()._CR_RECORDING = false

-- ==================== SHARED STATE ====================
getgenv().clickLog = getgenv().clickLog or {}

-- ==================== SERVICES ====================
local UIS = game:GetService("UserInputService")
local GS  = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

-- ==================== PLATFORM DETECTION ====================
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
local isDelta = false
pcall(function()
    isDelta = (identifyexecutor() == "Delta")
end)

-- ==================== COORDINATE CALIBRATION ====================
-- On mobile, the top bar and screen notch shift the effective
-- click coordinates. This block computes the correction vector
-- that must be added to raw input positions.
local correction = Vector2.new(0, 0)

do
    local guiInset = Vector2.new(0, 0)
    local notchOffset = Vector2.new(0, 0)

    -- Initial inset read
    task.wait(0.2)
    guiInset = GS:GetGuiInset()

    -- Wait for topbar to settle on mobile
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
            -- Fallback: standard mobile top bar height
            guiInset = Vector2.new(0, 58)
        end
    end

    -- Probe for notch offset (horizontal bezel cutout)
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

    -- Combine into final correction vector
    correction = Vector2.new(
        guiInset.X + notchOffset.X,
        guiInset.Y + notchOffset.Y
    )
end

-- ==================== INTERNAL STATE ====================
local _recording = false
local _replaying = false
local _inputConn   = nil
local _replayThread = nil

-- ==================== GUI REFERENCE ====================
-- Populated by init(). All visual updates go through this.
local gui = nil

-- ==================== RECORDING ENGINE ====================
local function startRecording()
    if _replaying then return end
    _recording = true
    getgenv().clickLog = {}

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

        table.insert(getgenv().clickLog, {
            t = tick(),
            x = absX,
            y = absY
        })

        if gui then
            gui.setStatus("Rec: " .. #getgenv().clickLog, Color3.fromRGB(220, 60, 60))
        end
    end)

    getgenv()._CR_CONN = _inputConn
end

local function stopRecording()
    _recording = false

    if _inputConn then
        pcall(function() _inputConn:Disconnect() end)
        _inputConn = nil
    end
    getgenv()._CR_CONN = nil

    if gui then
        gui.setRecordButtonState("idle")
        local n = #getgenv().clickLog
        gui.setStatus(
            n .. " click" .. (n == 1 and "" or "s") .. " saved",
            Color3.fromRGB(200, 180, 50)
        )
    end
end

-- ==================== REPLAY ENGINE ====================
local function startReplaying()
    if _recording then return end

    local log = getgenv().clickLog
    if #log == 0 then
        if gui then
            gui.setStatus("Nothing to replay", Color3.fromRGB(200, 100, 50))
        end
        return
    end

    _replaying = true
    getgenv()._CR_REPLAYING = true

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
        getgenv()._CR_REPLAYING = false

        if gui then
            gui.setReplayButtonState("idle")
            gui.setStatus("Done " .. #log .. " clicks", Color3.fromRGB(100, 200, 130))
        end
    end)
end

local function stopReplaying()
    _replaying = false
    getgenv()._CR_REPLAYING = false

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
-- These are the callbacks registered with the GUI module.
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

    -- ==================== INIT ====================
    -- Call this after loading the GUI module. Registers
    -- callbacks and sets the initial status.
    init = function(guiModule)
        if not guiModule then
            warn("[ClickRecorder] GUI module not provided. Aborting init.")
            return false
        end
        gui = guiModule

        -- Register toggle callbacks with the GUI
        gui.setCallbacks({
            onRecordToggle = onRecordToggle,
            onReplayToggle = onReplayToggle,
        })

        -- Restore status from any pre-existing click log
        local n = #getgenv().clickLog
        if n > 0 then
            gui.setStatus(n .. " clicks loaded", Color3.fromRGB(130, 130, 150))
        end

        return true
    end,

    -- ==================== STATE QUERIES ====================
    isRecording = function()
        return _recording
    end,

    isReplaying = function()
        return _replaying
    end,

    getClickCount = function()
        return #getgenv().clickLog
    end,

    getClickLog = function()
        return getgenv().clickLog
    end,

    -- ==================== MANUAL CONTROL ====================
    -- Bypasses the GUI for programmatic use.
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

    -- ==================== CLEAR LOG ====================
    clearLog = function()
        getgenv().clickLog = {}
        if gui then
            gui.setStatus("Log cleared", Color3.fromRGB(130, 130, 150))
        end
    end,

    -- ==================== CALIBRATION INFO ====================
    getCorrection = function()
        return correction
    end,

    isMobile = function()
        return isMobile
    end,

    isDelta = function()
        return isDelta
    end,

    -- ==================== FULL CLEANUP ====================
    destroy = function()
        stopRecording()
        stopReplaying()
        getgenv().clickLog = {}
        getgenv()._CR_LOGIC = nil
        getgenv()._CR_LOGIC_LOADED = nil
    end,
}

-- Persist globally
getgenv()._CR_LOGIC = publicAPI

return publicAPI
