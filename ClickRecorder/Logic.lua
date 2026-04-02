-- Delta Click Recorder v5.0 - Logic Module
-- Features: timestamps, hold duration, path recording, multi-finger, camera tracking

local Stealth = nil

if getgenv() and getgenv()._CR_LOGIC_LOADED then
    return getgenv()._CR_LOGIC
end
if getgenv() then getgenv()._CR_LOGIC_LOADED = true end

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
if getgenv() then getgenv().clickLog = getgenv().clickLog or {} end

local UIS = game:GetService("UserInputService")
local GS  = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
local isDelta = false
pcall(function()
    isDelta = (identifyexecutor():lower():find("delta") ~= nil)
end)

-- Coordinate calibration
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

-- Helpers for environment access
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

-- Internal state
local _recording = false
local _replaying = false
local _inputConn   = nil
local _touchConn   = nil
local _pathConn    = nil
local _cameraConn  = nil
local _replayThread = nil
local gui = nil

-- Active touch tracking for multi-finger and hold duration
local activeTouches = {}
local touchStartTime = {}
local touchStartPos = {}
local touchPath = {}
local lastRecordTime = 0

-- Camera tracking state
local lastCamCFrame = nil
local lastCamTime = 0
local camChangeThreshold = 0.001
local camSampleRate = 1/30

-- Camera tracking state
local lastCamCFrame = nil
local lastCamTime = 0
local camChangeThreshold = 0.001
local camSampleRate = 1/30

-- Apply correction to a position
local function correctedPos(x, y)
    return x + correction.X, y + correction.Y
end

-- Check if position is over recorder GUI
local function isOverGui(x, y)
    return gui and gui.isOverRecorderGui(x, y)
end

-- Record a touch event
local function recordTouchDown(touch, x, y, fingerId)
    local cx, cy = correctedPos(x, y)
    if isOverGui(cx, cy) then return end

    local t = tick()
    lastRecordTime = t

    -- Track active touch
    activeTouches[fingerId] = { x = cx, y = cy, down = true }
    touchStartTime[fingerId] = t
    touchStartPos[fingerId] = Vector2.new(cx, cy)
    touchPath[fingerId] = { { x = cx, y = cy, t = t } }

    local log = getClickLog()
    table.insert(log, {
        type = "down",
        t = t,
        x = cx,
        y = cy,
        finger = fingerId,
        hold = 0,
        path = nil,
    })
    envSet("clickLog", log)

    if gui then
        gui.setStatus("Rec: " .. #log, Color3.fromRGB(220, 60, 60))
    end
end

-- Record a touch release
local function recordTouchUp(touch, x, y, fingerId)
    local cx, cy = correctedPos(x, y)
    local t = tick()
    lastRecordTime = t

    -- Calculate hold duration
    local holdDuration = 0
    if touchStartTime[fingerId] then
        holdDuration = t - touchStartTime[fingerId]
    end

    -- Get path data
    local pathData = nil
    if touchPath[fingerId] and #touchPath[fingerId] > 1 then
        pathData = touchPath[fingerId]
    end

    local log = getClickLog()
    table.insert(log, {
        type = "up",
        t = t,
        x = cx,
        y = cy,
        finger = fingerId,
        hold = holdDuration,
        path = pathData,
    })
    envSet("clickLog", log)

    -- Clean up tracking
    activeTouches[fingerId] = nil
    touchStartTime[fingerId] = nil
    touchStartPos[fingerId] = nil
    touchPath[fingerId] = nil

    if gui then
        gui.setStatus("Rec: " .. #log, Color3.fromRGB(220, 60, 60))
    end
end

-- Record a path point during drag
local function recordPathPoint(fingerId, x, y)
    local cx, cy = correctedPos(x, y)
    if isOverGui(cx, cy) then return end

    if not touchPath[fingerId] then return end

    local t = tick()
    local lastPoint = touchPath[fingerId][#touchPath[fingerId]]
    if lastPoint then
        local dx = cx - lastPoint.x
        local dy = cy - lastPoint.y
        local dist = math.sqrt(dx * dx + dy * dy)
        -- Only record if moved enough pixels to avoid spam
        if dist < 3 then return end
    end

    table.insert(touchPath[fingerId], { x = cx, y = cy, t = t })
end

-- Camera rotation recording
local function recordCameraChange()
    local cam = workspace.CurrentCamera
    if not cam or not _recording then return end

    local t = tick()
    local now = t
    if now - lastCamTime < camSampleRate then return end

    local cf = cam.CFrame
    if not lastCamCFrame then
        lastCamCFrame = cf
        lastCamTime = now
        return
    end

    local dx = cf.Position.X - lastCamCFrame.Position.X
    local dy = cf.Position.Y - lastCamCFrame.Position.Y
    local dz = cf.Position.Z - lastCamCFrame.Position.Z
    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)

    if dist < camChangeThreshold then return end

    local log = getClickLog()
    table.insert(log, {
        type = "cam",
        t = now,
        cf = {
            px = cf.Position.X, py = cf.Position.Y, pz = cf.Position.Z,
            lx = cf.LookVector.X, ly = cf.LookVector.Y, lz = cf.LookVector.Z,
        },
    })
    envSet("clickLog", log)

    lastCamCFrame = cf
    lastCamTime = now
end

-- Recording engine
local function startRecording()
    if _replaying then return end
    _recording = true
    envSet("clickLog", {})
    activeTouches = {}
    touchStartTime = {}
    touchStartPos = {}
    touchPath = {}
    lastRecordTime = 0
    lastCamCFrame = nil
    lastCamTime = 0

    if gui then
        gui.setRecordButtonState("recording")
        gui.setStatus("Recording...", Color3.fromRGB(220, 60, 60))
    end

    -- Mouse/touch down detection
    _inputConn = UIS.InputBegan:Connect(function(input, gameProcessed)
        if not _recording then return end

        local validType = (input.UserInputType == Enum.UserInputType.MouseButton1)
                       or (input.UserInputType == Enum.UserInputType.Touch)
        if not validType then return end

        local pos = input.Position
        local fingerId = 0
        if input.UserInputType == Enum.UserInputType.Touch and input.UserInputState == Enum.UserInputState.Begin then
            fingerId = input.UserInputState and 1 or 0
            -- Use a unique finger ID based on position hash
            fingerId = math.floor(pos.X * 1000 + pos.Y) % 100
        end

        recordTouchDown(input, pos.X, pos.Y, fingerId)
    end)

    -- Mouse/touch up detection
    _touchConn = UIS.InputEnded:Connect(function(input, gameProcessed)
        if not _recording then return end

        local validType = (input.UserInputType == Enum.UserInputType.MouseButton1)
                       or (input.UserInputType == Enum.UserInputType.Touch)
        if not validType then return end

        local pos = input.Position
        local fingerId = 0
        if input.UserInputType == Enum.UserInputType.Touch then
            fingerId = math.floor(pos.X * 1000 + pos.Y) % 100
        end

        recordTouchUp(input, pos.X, pos.Y, fingerId)
    end)

    -- Path tracking during movement
    _pathConn = UIS.InputChanged:Connect(function(input, gameProcessed)
        if not _recording then return end
        if input.UserInputType ~= Enum.UserInputType.Touch and
           input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local pos = input.Position
        local fingerId = 0
        if input.UserInputType == Enum.UserInputType.Touch then
            fingerId = math.floor(pos.X * 1000 + pos.Y) % 100
        else
            -- For mouse, track finger 0
            fingerId = 0
        end

        if activeTouches[fingerId] then
            recordPathPoint(fingerId, pos.X, pos.Y)
            activeTouches[fingerId].x = pos.X + correction.X
            activeTouches[fingerId].y = pos.Y + correction.Y
        end
    end)

    -- Camera rotation tracking
    _cameraConn = RunService.RenderStepped:Connect(function()
        if not _recording then return end
        recordCameraChange()
    end)

    envSet("_CR_CONN", _inputConn)
end

    -- Mouse/touch down detection
    _inputConn = UIS.InputBegan:Connect(function(input, gameProcessed)
        if not _recording then return end

        local validType = (input.UserInputType == Enum.UserInputType.MouseButton1)
                       or (input.UserInputType == Enum.UserInputType.Touch)
        if not validType then return end

        local pos = input.Position
        local fingerId = 0
        if input.UserInputType == Enum.UserInputType.Touch and input.UserInputState == Enum.UserInputState.Begin then
            fingerId = input.UserInputState and 1 or 0
            -- Use a unique finger ID based on position hash
            fingerId = math.floor(pos.X * 1000 + pos.Y) % 100
        end

        recordTouchDown(input, pos.X, pos.Y, fingerId)
    end)

    -- Mouse/touch up detection
    _touchConn = UIS.InputEnded:Connect(function(input, gameProcessed)
        if not _recording then return end

        local validType = (input.UserInputType == Enum.UserInputType.MouseButton1)
                       or (input.UserInputType == Enum.UserInputType.Touch)
        if not validType then return end

        local pos = input.Position
        local fingerId = 0
        if input.UserInputType == Enum.UserInputType.Touch then
            fingerId = math.floor(pos.X * 1000 + pos.Y) % 100
        end

        recordTouchUp(input, pos.X, pos.Y, fingerId)
    end)

    -- Path tracking during movement
    _pathConn = UIS.InputChanged:Connect(function(input, gameProcessed)
        if not _recording then return end
        if input.UserInputType ~= Enum.UserInputType.Touch and
           input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local pos = input.Position
        local fingerId = 0
        if input.UserInputType == Enum.UserInputType.Touch then
            fingerId = math.floor(pos.X * 1000 + pos.Y) % 100
        else
            -- For mouse, track finger 0
            fingerId = 0
        end

        if activeTouches[fingerId] then
            recordPathPoint(fingerId, pos.X, pos.Y)
            activeTouches[fingerId].x = pos.X + correction.X
            activeTouches[fingerId].y = pos.Y + correction.Y
        end
    end)

    -- Camera rotation tracking
    _cameraConn = RunService.RenderStepped:Connect(function()
        if not _recording then return end
        recordCameraChange()
    end)

    envSet("_CR_CONN", _inputConn)
end

local function stopRecording()
    _recording = false

    if _inputConn then
        pcall(function() _inputConn:Disconnect() end)
        _inputConn = nil
    end
    if _touchConn then
        pcall(function() _touchConn:Disconnect() end)
        _touchConn = nil
    end
    if _pathConn then
        pcall(function() _pathConn:Disconnect() end)
        _pathConn = nil
    end
    if _cameraConn then
        pcall(function() _cameraConn:Disconnect() end)
        _cameraConn = nil
    end
    envSet("_CR_CONN", nil)

    activeTouches = {}
    touchStartTime = {}
    touchStartPos = {}
    touchPath = {}
    lastCamCFrame = nil
    lastCamTime = 0

    if gui then
        gui.setRecordButtonState("idle")
        local n = #getClickLog()
        gui.setStatus(
            n .. " events saved",
            Color3.fromRGB(200, 180, 50)
        )
    end
end
    if _touchConn then
        pcall(function() _touchConn:Disconnect() end)
        _touchConn = nil
    end
    if _pathConn then
        pcall(function() _pathConn:Disconnect() end)
        _pathConn = nil
    end
    if _cameraConn then
        pcall(function() _cameraConn:Disconnect() end)
        _cameraConn = nil
    end
    envSet("_CR_CONN", nil)

    activeTouches = {}
    touchStartTime = {}
    touchStartPos = {}
    touchPath = {}
    lastCamCFrame = nil
    lastCamTime = 0

    if gui then
        gui.setRecordButtonState("idle")
        local n = #getClickLog()
        gui.setStatus(
            n .. " events saved",
            Color3.fromRGB(200, 180, 50)
        )
    end
end

-- Replay engine
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

            -- Wait exact time delta from previous event
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

            if entry.type == "down" then
                VIM:SendMouseButtonEvent(entry.x, entry.y, 0, true, game, 1)
            elseif entry.type == "up" then
                -- If hold duration exists, wait for it
                if entry.hold and entry.hold > 0 then
                    task.wait(entry.hold)
                else
                    task.wait(0.05)
                end

                -- Replay path if recorded
                if entry.path and #entry.path > 1 then
                    for _, point in ipairs(entry.path) do
                        if not _replaying then break end
                        VIM:SendMouseMoveEvent(point.x, point.y, game)
                        task.wait(0.005)
                    end
                end

                VIM:SendMouseButtonEvent(entry.x, entry.y, 0, false, game, 1)
            end

            if gui then
                gui.setStatus("Replay " .. i .. "/" .. #log, Color3.fromRGB(60, 180, 90))
            end
        end

        _replaying = false
        envSet("_CR_REPLAYING", false)

        if gui then
            gui.setReplayButtonState("idle")
            gui.setStatus("Done " .. #log .. " events", Color3.fromRGB(100, 200, 130))
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

-- Toggle handlers
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

-- Public API
local publicAPI = {

    init = function(guiModule, stealthModule)
        if not guiModule then
            return false
        end
        gui = guiModule
        Stealth = stealthModule

        if Stealth and Stealth.GUIStealth and gui then
            Stealth.GUIStealth.disableScreenGuiDetection(gui.rootGui)
        end

        gui.setCallbacks({
            onRecordToggle = onRecordToggle,
            onReplayToggle = onReplayToggle,
        })

        local n = #getClickLog()
        if n > 0 then
            gui.setStatus(n .. " events loaded", Color3.fromRGB(130, 130, 150))
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
