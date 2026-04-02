-- Delta Click Recorder v5.2 - Logic Module
-- Fixes: no duplicated code, proper finger tracking, no double-wait,
-- camera replay, consistent stealth access, mobile touch events,
-- path timing, safe cancel cleanup

local Stealth = nil

if getgenv() and getgenv()._CR_LOGIC_LOADED then
    return getgenv()._CR_LOGIC
end
if getgenv() then getgenv()._CR_LOGIC_LOADED = true end

if getgenv() and getgenv()._CR_CONN then
    pcall(function() getgenv()._CR_CONN:Disconnect() end)
    getgenv()._CR_CONN = nil
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

-- Environment access helpers (consistent stealth or direct)
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

-- Touch tracking: use input object as key to avoid position-hash issues
local activeTouches = {}       -- key = input object, value = {fingerId, startTime, startPos, path}
local fingerIdCounter = 0
local lastCamCFrame = nil
local lastCamTime = 0
local camChangeThreshold = 0.001
local camSampleRate = 1/30

local function correctedPos(x, y)
    return x + correction.X, y + correction.Y
end

local function isOverGui(x, y)
    return gui and gui.isOverRecorderGui(x, y)
end

-- Assign a unique finger ID per simultaneous touch
local function getFingerId()
    fingerIdCounter = fingerIdCounter + 1
    return fingerIdCounter
end

local function recordTouchDown(input, x, y)
    local cx, cy = correctedPos(x, y)
    if isOverGui(cx, cy) then return end

    local t = tick()
    local fingerId = getFingerId()

    activeTouches[input] = {
        fingerId = fingerId,
        startTime = t,
        startPos = Vector2.new(cx, cy),
        path = { { x = cx, y = cy, t = t } },
    }

    local log = getClickLog()
    table.insert(log, {
        type = "down",
        t = t,
        x = cx,
        y = cy,
        finger = fingerId,
    })
    envSet("clickLog", log)

    if gui then
        gui.setStatus("Rec: " .. #log, Color3.fromRGB(220, 60, 60))
    end
end

local function recordTouchUp(input, x, y)
    local cx, cy = correctedPos(x, y)
    local t = tick()

    local track = activeTouches[input]
    local fingerId = 0
    local holdDuration = 0
    local pathData = nil

    if track then
        fingerId = track.fingerId
        holdDuration = t - track.startTime
        pathData = (#track.path > 1) and track.path or nil
        activeTouches[input] = nil
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

    if gui then
        gui.setStatus("Rec: " .. #log, Color3.fromRGB(220, 60, 60))
    end
end

local function recordPathPoint(input, x, y)
    local track = activeTouches[input]
    if not track then return end

    local cx, cy = correctedPos(x, y)
    if isOverGui(cx, cy) then return end

    local t = tick()
    local lastPoint = track.path[#track.path]
    if lastPoint then
        local dx = cx - lastPoint.x
        local dy = cy - lastPoint.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < 3 then return end
    end

    table.insert(track.path, { x = cx, y = cy, t = t })
end

local function recordCameraChange()
    local cam = workspace.CurrentCamera
    if not cam or not _recording then return end

    local now = tick()
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

local function startRecording()
    if _replaying then return end
    _recording = true
    envSet("clickLog", {})
    activeTouches = {}
    fingerIdCounter = 0
    lastCamCFrame = nil
    lastCamTime = 0

    if gui then
        gui.setRecordButtonState("recording")
        gui.setStatus("Recording...", Color3.fromRGB(220, 60, 60))
    end

    _inputConn = UIS.InputBegan:Connect(function(input, gameProcessed)
        if not _recording then return end
        local validType = (input.UserInputType == Enum.UserInputType.MouseButton1)
                       or (input.UserInputType == Enum.UserInputType.Touch)
        if not validType then return end
        if input.UserInputState ~= Enum.UserInputState.Begin then return end
        local pos = input.Position
        recordTouchDown(input, pos.X, pos.Y)
    end)

    _touchConn = UIS.InputEnded:Connect(function(input, gameProcessed)
        if not _recording then return end
        local validType = (input.UserInputType == Enum.UserInputType.MouseButton1)
                       or (input.UserInputType == Enum.UserInputType.Touch)
        if not validType then return end
        local pos = input.Position
        recordTouchUp(input, pos.X, pos.Y)
    end)

    _pathConn = UIS.InputChanged:Connect(function(input, gameProcessed)
        if not _recording then return end
        if input.UserInputType ~= Enum.UserInputType.Touch and
           input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end
        local pos = input.Position
        recordPathPoint(input, pos.X, pos.Y)
    end)

    _cameraConn = RunService.RenderStepped:Connect(function()
        if not _recording then return end
        recordCameraChange()
    end)

    envSet("_CR_CONN", _inputConn)
end

local function stopRecording()
    _recording = false

    if _inputConn then pcall(function() _inputConn:Disconnect() end); _inputConn = nil end
    if _touchConn then pcall(function() _touchConn:Disconnect() end); _touchConn = nil end
    if _pathConn then pcall(function() _pathConn:Disconnect() end); _pathConn = nil end
    if _cameraConn then pcall(function() _cameraConn:Disconnect() end); _cameraConn = nil end
    envSet("_CR_CONN", nil)

    activeTouches = {}
    fingerIdCounter = 0
    lastCamCFrame = nil
    lastCamTime = 0

    if gui then
        gui.setRecordButtonState("idle")
        local n = #getClickLog()
        gui.setStatus(n .. " events saved", Color3.fromRGB(200, 180, 50))
    end
end

-- Replay helpers
local function sendMouseDown(x, y)
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)
end

local function sendMouseUp(x, y)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)
end

local function sendTouchDown(x, y, fingerId)
    pcall(function()
        VIM:SendTouchEvent(fingerId, 0, x, y)
    end)
end

local function sendTouchMove(x, y, fingerId)
    pcall(function()
        VIM:SendTouchEvent(fingerId, 2, x, y)
    end)
end

local function sendTouchUp(x, y, fingerId)
    pcall(function()
        VIM:SendTouchEvent(fingerId, 1, x, y)
    end)
end

local function sendMouseMove(x, y)
    VIM:SendMouseMoveEvent(x, y, game)
end

local function setCameraCFrame(cfData)
    local cam = workspace.CurrentCamera
    if not cam or not cfData then return end
    local pos = Vector3.new(cfData.px, cfData.py, cfData.pz)
    local lookDir = Vector3.new(cfData.lx, cfData.ly, cfData.lz)
    cam.CFrame = CFrame.new(pos, pos + lookDir)
end

local function startReplaying()
    if _recording then return end

    local log = getClickLog()
    if #log == 0 then
        if gui then gui.setStatus("Nothing to replay", Color3.fromRGB(200, 100, 50)) end
        return
    end

    _replaying = true
    envSet("_CR_REPLAYING", true)

    if gui then
        gui.setReplayButtonState("replaying")
        gui.setStatus("Replaying...", Color3.fromRGB(60, 180, 90))
    end

    local lastFingerState = {} -- track finger states for cleanup

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

            if entry.type == "cam" then
                -- Replay camera position
                if entry.cf then
                    setCameraCFrame(entry.cf)
                end

            elseif entry.type == "down" then
                if isMobile then
                    sendTouchDown(entry.x, entry.y, entry.finger or 0)
                    lastFingerState[entry.finger or 0] = "down"
                else
                    sendMouseDown(entry.x, entry.y)
                end

            elseif entry.type == "up" then
                if isMobile then
                    local fid = entry.finger or 0
                    -- Replay path with correct timing
                    if entry.path and #entry.path > 1 then
                        for j, point in ipairs(entry.path) do
                            if not _replaying then break end
                            local prevT = (j > 1) and entry.path[j-1].t or entry.t - entry.hold
                            local waitT = point.t - prevT
                            if waitT > 0.001 then
                                task.wait(waitT)
                            end
                            sendTouchMove(point.x, point.y, fid)
                        end
                    end
                    sendTouchUp(entry.x, entry.y, fid)
                    lastFingerState[entry.finger or 0] = nil
                else
                    -- Replay path with correct timing
                    if entry.path and #entry.path > 1 then
                        for j, point in ipairs(entry.path) do
                            if not _replaying then break end
                            local prevT = (j > 1) and entry.path[j-1].t or entry.t - entry.hold
                            local waitT = point.t - prevT
                            if waitT > 0.001 then
                                task.wait(waitT)
                            end
                            sendMouseMove(point.x, point.y)
                        end
                    end
                    sendMouseUp(entry.x, entry.y)
                end
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

    if _replayThread then
        task.cancel(_replayThread)
        _replayThread = nil
    end

    -- Send mouse-up for any held buttons to prevent phantom state
    sendMouseUp(0, 0)
    -- Release all touch fingers
    for fid, state in pairs(lastFingerState) do
        if state == "down" then
            sendTouchUp(0, 0, fid)
        end
    end

    if gui then
        gui.setReplayButtonState("idle")
        gui.setStatus("Replay stopped", Color3.fromRGB(200, 180, 50))
    end
end

local function onRecordToggle()
    if _replaying then return end
    if not _recording then startRecording() else stopRecording() end
end

local function onReplayToggle()
    if _recording then return end
    if not _replaying then startReplaying() else stopReplaying() end
end

local publicAPI = {

    init = function(guiModule, stealthModule)
        if not guiModule then return false end
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

    isRecording = function() return _recording end,
    isReplaying = function() return _replaying end,
    getClickCount = function() return #getClickLog() end,
    getClickLog = function() return getClickLog() end,

    record = function() startRecording() end,
    stopRecord = function() stopRecording() end,
    replay = function() startReplaying() end,
    stopReplay = function() stopReplaying() end,

    clearLog = function()
        envSet("clickLog", {})
        if gui then gui.setStatus("Log cleared", Color3.fromRGB(130, 130, 150)) end
    end,

    getCorrection = function() return correction end,
    isMobile = function() return isMobile end,
    isDelta = function() return isDelta end,

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
