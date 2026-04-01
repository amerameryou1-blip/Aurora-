-- ============================================================
-- Delta Click Recorder v4.0 — GUI Module
-- Pure UI construction, styling, hit detection, and public API.
-- Zero business logic — all recording/replaying is delegated
-- to Logic.lua via callbacks.
--
-- Usage:
--   local GUI = loadstring(game:HttpGet("GUI.lua"))()
--   local Logic = loadstring(game:HttpGet("Logic.lua"))()
--   Logic.init(GUI)
-- ============================================================

-- ==================== PREVENT DOUBLE LOAD ====================
if getgenv()._CR_GUI_LOADED then
    warn("[ClickRecorder] GUI already loaded. Skipping.")
    return getgenv()._CR_UI
end
getgenv()._CR_GUI_LOADED = true

-- ==================== CLEANUP PREVIOUS GUI ====================
if getgenv()._CR_GUI then
    pcall(function() getgenv()._CR_GUI:Destroy() end)
end
getgenv()._CR_GUI = nil
getgenv()._CR_GUI_NAME = nil

-- ==================== SERVICES ====================
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ==================== SAFE PARENT HELPER ====================
local function safeParent(instance)
    if gethui then
        pcall(function()
            instance.Parent = gethui()
        end)
    end
    if not instance.Parent then
        instance.Parent = playerGui
    end
end

-- ==================== GUI ELEMENT TRACKING ====================
-- All interactive/visible elements are registered here so the
-- hit-detection system can ignore clicks that land on the
-- recorder's own GUI.
local trackedElements = {}

local function track(element)
    if element and typeof(element) == "Instance" then
        table.insert(trackedElements, element)
    end
    return element
end

-- ==================== GUI CONSTRUCTION ====================
local guiName = "_G" .. tostring(math.random(100000, 999999))

-- Root ScreenGui
local rootGui = Instance.new("ScreenGui")
rootGui.Name = guiName
rootGui.ResetOnSpawn = false
rootGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
rootGui.DisplayOrder = 999999
safeParent(rootGui)

getgenv()._CR_GUI = rootGui
getgenv()._CR_GUI_NAME = guiName

-- ==================== MAIN FRAME ====================
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

-- Rounded corners
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

-- Border stroke
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(50, 50, 70)
mainStroke.Thickness = 1
mainStroke.Parent = mainFrame

-- ==================== STATUS LABEL ====================
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

-- ==================== BUTTON: RECORD ====================
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

-- ==================== BUTTON: REPLAY ====================
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

-- ==================== HIT DETECTION ====================
-- Determines whether a given screen-space coordinate falls
-- within any of the recorder's tracked GUI elements.
-- Used by Logic.lua to filter out self-clicks.
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

-- ==================== STATUS HELPER ====================
local defaultStatusColor = Color3.fromRGB(130, 130, 150)

local function setStatus(text, color)
    if statusLabel then
        statusLabel.Text = text or "Ready"
        statusLabel.TextColor3 = color or defaultStatusColor
    end
end

-- ==================== BUTTON STATE HELPERS ====================
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

-- ==================== CALLBACK SYSTEM ====================
-- Logic.lua registers its handlers here. The GUI invokes them
-- on button clicks — keeping the GUI completely decoupled.
local callbacks = {
    onRecordToggle = nil,  -- called when Record/Stop Rec is clicked
    onReplayToggle = nil,  -- called when Replay/Stop is clicked
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

-- ==================== BUTTON CONNECTIONS ====================
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

-- ==================== PUBLIC API ====================
-- This table is returned and also stored in getgenv() so
-- Logic.lua can access everything it needs.
local publicAPI = {

    -- References to core GUI elements
    rootGui       = rootGui,
    mainFrame     = mainFrame,
    statusLabel   = statusLabel,
    btnRecord     = btnRecord,
    btnReplay     = btnReplay,

    -- Methods
    setStatus             = setStatus,
    setRecordButtonState  = setRecordButtonState,
    setReplayButtonState  = setReplayButtonState,
    isOverRecorderGui     = isOverRecorderGui,
    setCallbacks          = setCallbacks,

    -- Element count for debugging
    getTrackedCount = function()
        return #trackedElements
    end,

    -- Full cleanup
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

-- Persist globally so Logic.lua can find it
getgenv()._CR_UI = publicAPI

return publicAPI
