-- ============================================================
-- Delta Click Recorder v4.0 — Loader / Entry Point
--
-- This is the single script you execute. It loads GUI.lua first,
-- then Logic.lua, then wires them together via Logic.init(GUI).
--
-- If you are pasting into an executor, paste THIS file.
-- If you are using loadstring from a remote host, point it here.
-- ============================================================

-- ==================== FULL CLEANUP ====================
-- Tear down any previous instance of the recorder before
-- loading a fresh copy. This prevents ghost GUIs and
-- duplicate connections.
do
    -- Disconnect input connections
    if getgenv()._CR_CONN then
        pcall(function() getgenv()._CR_CONN:Disconnect() end)
        getgenv()._CR_CONN = nil
    end
    if getgenv()._CR_HB then
        pcall(function() getgenv()._CR_HB:Disconnect() end)
        getgenv()._CR_HB = nil
    end

    -- Destroy previous GUI
    if getgenv()._CR_GUI then
        pcall(function() getgenv()._CR_GUI:Destroy() end)
        getgenv()._CR_GUI = nil
    end

    -- Reset state flags
    getgenv()._CR_REPLAYING = false
    getgenv()._CR_RECORDING = false

    -- Clear module load guards so a re-run works
    getgenv()._CR_GUI_LOADED  = nil
    getgenv()._CR_LOGIC_LOADED = nil
    getgenv()._CR_UI          = nil
    getgenv()._CR_LOGIC       = nil
    getgenv()._CR_GUI_NAME    = nil
end

-- ==================== LOAD MODULES ====================
-- IMPORTANT: Replace these placeholder paths with your actual
-- hosting URLs when distributing. For local testing, you can
-- paste GUI.lua and Logic.lua contents directly above this
-- loader and replace the loadstring calls with require().

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- OPTION A: loadstring from remote URLs (production)
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

-- local GUI_URL   = "https://your-host.com/ClickRecorder/GUI.lua"
-- local LOGIC_URL = "https://your-host.com/ClickRecorder/Logic.lua"
--
-- local GUI   = loadstring(game:HttpGet(GUI_URL))()
-- local Logic = loadstring(game:HttpGet(LOGIC_URL))()
-- Logic.init(GUI)

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- OPTION B: Inline modules (paste & run — no hosting needed)
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

-- Paste the full contents of GUI.lua here, wrapped in a function:
local GUI = (function()
    -- ============================================================
    -- Delta Click Recorder v4.0 — GUI Module (inlined)
    -- ============================================================

    if getgenv()._CR_GUI_LOADED then
        warn("[ClickRecorder] GUI already loaded. Skipping.")
        return getgenv()._CR_UI
    end
    getgenv()._CR_GUI_LOADED = true

    if getgenv()._CR_GUI then
        pcall(function() getgenv()._CR_GUI:Destroy() end)
    end
    getgenv()._CR_GUI = nil
    getgenv()._CR_GUI_NAME = nil

    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local function safeParent(instance)
        if gethui then
            pcall(function() instance.Parent = gethui() end)
        end
        if not instance.Parent then
            instance.Parent = playerGui
        end
    end

    local trackedElements = {}
    local function track(element)
        if element and typeof(element) == "Instance" then
            table.insert(trackedElements, element)
        end
        return element
    end

    local guiName = "_G" .. tostring(math.random(100000, 999999))
    local rootGui = Instance.new("ScreenGui")
    rootGui.Name = guiName
    rootGui.ResetOnSpawn = false
    rootGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    rootGui.DisplayOrder = 999999
    safeParent(rootGui)
    getgenv()._CR_GUI = rootGui
    getgenv()._CR_GUI_NAME = guiName

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "M" .. math.random(1000, 9999)
    mainFrame.Size = UDim2.new(0, 220, 0, 82)
    mainFrame.Position = UDim2.new(0.5, -110, 0.15, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = rootGui
    track(mainFrame)

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(50, 50, 70)
    mainStroke.Thickness = 1
    mainStroke.Parent = mainFrame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "S" .. math.random(1000, 9999)
    statusLabel.Size = UDim2.new(1, -16, 0, 18)
    statusLabel.Position = UDim2.new(0, 8, 0, 6)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Ready"
    statusLabel.TextColor3 = Color3.fromRGB(130, 130, 150)
    statusLabel.TextSize = 12
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.Parent = mainFrame
    track(statusLabel)

    local btnRecord = Instance.new("TextButton")
    btnRecord.Name = "R" .. math.random(1000, 9999)
    btnRecord.Size = UDim2.new(0.5, -12, 0, 48)
    btnRecord.Position = UDim2.new(0, 8, 0, 28)
    btnRecord.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    btnRecord.Text = "Record"
    btnRecord.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnRecord.TextSize = 15
    btnRecord.Font = Enum.Font.GothamBold
    btnRecord.BorderSizePixel = 0
    btnRecord.AutoButtonColor = true
    btnRecord.Parent = mainFrame
    track(btnRecord)

    local btnRecordCorner = Instance.new("UICorner")
    btnRecordCorner.CornerRadius = UDim.new(0, 8)
    btnRecordCorner.Parent = btnRecord

    local btnReplay = Instance.new("TextButton")
    btnReplay.Name = "P" .. math.random(1000, 9999)
    btnReplay.Size = UDim2.new(0.5, -12, 0, 48)
    btnReplay.Position = UDim2.new(0.5, 4, 0, 28)
    btnReplay.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    btnReplay.Text = "Replay"
    btnReplay.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnReplay.TextSize = 15
    btnReplay.Font = Enum.Font.GothamBold
    btnReplay.BorderSizePixel = 0
    btnReplay.AutoButtonColor = true
    btnReplay.Parent = mainFrame
    track(btnReplay)

    local btnReplayCorner = Instance.new("UICorner")
    btnReplayCorner.CornerRadius = UDim.new(0, 8)
    btnReplayCorner.Parent = btnReplay

    local function isOverRecorderGui(x, y)
        for _, element in ipairs(trackedElements) do
            if element and element.Parent then
                local absPos = element.AbsolutePosition
                local absSize = element.AbsoluteSize
                if x >= absPos.X and x <= absPos.X + absSize.X and
                   y >= absPos.Y and y <= absPos.Y + absSize.Y then
                    return true
                end
            end
        end
        return false
    end

    local defaultStatusColor = Color3.fromRGB(130, 130, 150)
    local function setStatus(text, color)
        if statusLabel then
            statusLabel.Text = text or "Ready"
            statusLabel.TextColor3 = color or defaultStatusColor
        end
    end

    local function setRecordButtonState(state)
        if not btnRecord then return end
        if state == "recording" then
            btnRecord.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
            btnRecord.Text = "Stop Rec"
        else
            btnRecord.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
            btnRecord.Text = "Record"
        end
    end

    local function setReplayButtonState(state)
        if not btnReplay then return end
        if state == "replaying" then
            btnReplay.BackgroundColor3 = Color3.fromRGB(35, 140, 60)
            btnReplay.Text = "Stop"
        else
            btnReplay.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
            btnReplay.Text = "Replay"
        end
    end

    local callbacks = {
        onRecordToggle = nil,
        onReplayToggle = nil,
    }

    local function setCallbacks(newCallbacks)
        if type(newCallbacks) == "table" then
            if newCallbacks.onRecordToggle then
                callbacks.onRecordToggle = newCallbacks.onRecordToggle
            end
            if newCallbacks.onReplayToggle then
                callbacks.onReplayToggle = newCallbacks.onReplayToggle
            end
        end
    end

    btnRecord.MouseButton1Click:Connect(function()
        if callbacks.onRecordToggle then
            callbacks.onRecordToggle()
        end
    end)

    btnReplay.MouseButton1Click:Connect(function()
        if callbacks.onReplayToggle then
            callbacks.onReplayToggle()
        end
    end)

    local publicAPI = {
        rootGui              = rootGui,
        mainFrame            = mainFrame,
        statusLabel          = statusLabel,
        btnRecord            = btnRecord,
        btnReplay            = btnReplay,
        setStatus            = setStatus,
        setRecordButtonState = setRecordButtonState,
        setReplayButtonState = setReplayButtonState,
        isOverRecorderGui    = isOverRecorderGui,
        setCallbacks         = setCallbacks,
        getTrackedCount = function()
            return #trackedElements
        end,
        destroy = function()
            if rootGui then
                pcall(function() rootGui:Destroy() end)
            end
            getgenv()._CR_GUI = nil
            getgenv()._CR_GUI_NAME = nil
            getgenv()._CR_UI = nil
            getgenv()._CR_GUI_LOADED = nil
        end,
    }

    getgenv()._CR_UI = publicAPI
    return publicAPI
end)()

-- Paste the full contents of Logic.lua here, wrapped in a function:
local Logic = (function()
    -- ============================================================
    -- Delta Click Recorder v4.0 — Logic Module (inlined)
    -- ============================================================

    if getgenv()._CR_LOGIC_LOADED then
        warn("[ClickRecorder] Logic already loaded. Skipping.")
        return getgenv()._CR_LOGIC
    end
    getgenv()._CR_LOGIC_LOADED = true

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

    getgenv().clickLog = getgenv().clickLog or {}

    local UIS = game:GetService("UserInputService")
    local GS  = game:GetService("GuiService")
    local VIM = game:GetService("VirtualInputManager")
    local RunService = game:GetService("RunService")

    local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
    local isDelta = false
    pcall(function()
        isDelta = (identifyexecutor() == "Delta")
    end)

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

    local _recording = false
    local _replaying = false
    local _inputConn  = nil
    local _replayThread = nil
    local gui = nil

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

                VIM:SendMouseButtonEvent(entry.x, entry.y, 0, true, game, 1)
                task.wait(0.03)
                VIM:SendMouseButtonEvent(entry.x, entry.y, 0, false, game, 1)

                if gui then
                    gui.setStatus("Replay " .. i .. "/" .. #log, Color3.fromRGB(60, 180, 90))
                end
            end

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

    local publicAPI = {
        init = function(guiModule)
            if not guiModule then
                warn("[ClickRecorder] GUI module not provided. Aborting init.")
                return false
            end
            gui = guiModule

            gui.setCallbacks({
                onRecordToggle = onRecordToggle,
                onReplayToggle = onReplayToggle,
            })

            local n = #getgenv().clickLog
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
            return #getgenv().clickLog
        end,

        getClickLog = function()
            return getgenv().clickLog
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
            getgenv().clickLog = {}
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
            getgenv().clickLog = {}
            getgenv()._CR_LOGIC = nil
            getgenv()._CR_LOGIC_LOADED = nil
        end,
    }

    getgenv()._CR_LOGIC = publicAPI
    return publicAPI
end)()

-- ==================== INITIALIZE ====================
Logic.init(GUI)
