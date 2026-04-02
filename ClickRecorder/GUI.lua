-- Delta Click Recorder v5.1 - GUI Module
-- Premium UI with animations, gradients, and stealth names

local function rndName()
    local prefixes = {"Core", "Sys", "Net", "Input", "Render", "Frame", "View", "Touch", "Event", "Signal"}
    local suffixes = {"Handler", "Manager", "Controller", "Bridge", "Adapter", "Proxy", "Cache", "Pool", "Buffer", "Queue"}
    return prefixes[math.random(1, #prefixes)] .. suffixes[math.random(1, #suffixes)] .. "_" .. string.format("%04x", math.random(0, 0xFFFF))
end

if getgenv()._CR_GUI_LOADED then
    return getgenv()._CR_UI
end
getgenv()._CR_GUI_LOADED = true

if getgenv()._CR_GUI then
    pcall(function() getgenv()._CR_GUI:Destroy() end)
end
getgenv()._CR_GUI = nil
getgenv()._CR_GUI_NAME = nil

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
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

local function tween(obj, props, duration, style)
    duration = duration or 0.2
    style = style or Enum.EasingStyle.Quart
    local info = TweenInfo.new(duration, style, Enum.EasingDirection.Out)
    return TweenService:Create(obj, info, props)
end

local trackedElements = {}

local function track(element)
    if element and typeof(element) == "Instance" then
        table.insert(trackedElements, element)
    end
    return element
end

local C = {
    bgPrimary    = Color3.fromRGB(15, 15, 22),
    bgSecondary  = Color3.fromRGB(22, 22, 32),
    bgTertiary   = Color3.fromRGB(30, 30, 42),
    surface      = Color3.fromRGB(38, 38, 52),
    accent       = Color3.fromRGB(99, 102, 241),
    accentBright = Color3.fromRGB(129, 140, 248),
    accentGlow   = Color3.fromRGB(79, 70, 229),
    record       = Color3.fromRGB(239, 68, 68),
    recordBright = Color3.fromRGB(248, 113, 113),
    recordGlow   = Color3.fromRGB(220, 38, 38),
    replay       = Color3.fromRGB(34, 197, 94),
    replayBright = Color3.fromRGB(74, 222, 128),
    replayGlow   = Color3.fromRGB(22, 163, 74),
    textPrimary  = Color3.fromRGB(248, 250, 252),
    textSecondary= Color3.fromRGB(148, 163, 184),
    textMuted    = Color3.fromRGB(100, 116, 139),
    border       = Color3.fromRGB(51, 51, 71),
    borderLight  = Color3.fromRGB(63, 63, 85),
}

local rootGui = Instance.new("ScreenGui")
rootGui.Name = rndName()
rootGui.ResetOnSpawn = false
rootGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
rootGui.DisplayOrder = 10
rootGui.IgnoreGuiInset = false
safeParent(rootGui)

getgenv()._CR_GUI = rootGui
getgenv()._CR_GUI_NAME = rootGui.Name

local mainFrame = Instance.new("Frame")
mainFrame.Name = rndName()
mainFrame.Size = UDim2.new(0, 280, 0, 160)
mainFrame.Position = UDim2.new(0.5, -140, 0.2, 0)
mainFrame.BackgroundColor3 = C.bgPrimary
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = rootGui
track(mainFrame)

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = C.border
mainStroke.Thickness = 1
mainStroke.Transparency = 0.4
mainStroke.Parent = mainFrame

local glowStroke = Instance.new("UIStroke")
glowStroke.Color = C.accent
glowStroke.Thickness = 0
glowStroke.Transparency = 0.6
glowStroke.Parent = mainFrame

local topBar = Instance.new("Frame")
topBar.Name = rndName()
topBar.Size = UDim2.new(1, 0, 0, 36)
topBar.BackgroundColor3 = C.bgSecondary
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame
track(topBar)

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 14)
topCorner.Parent = topBar

local topLine = Instance.new("Frame")
topLine.Name = rndName()
topLine.Size = UDim2.new(1, 0, 0, 1)
topLine.Position = UDim2.new(0, 0, 1, -1)
topLine.BackgroundColor3 = C.border
topLine.BorderSizePixel = 0
topLine.Parent = topBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = rndName()
titleLabel.Size = UDim2.new(1, -40, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Click Recorder"
titleLabel.TextColor3 = C.textPrimary
titleLabel.TextSize = 13
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar
track(titleLabel)

local statusDot = Instance.new("Frame")
statusDot.Name = rndName()
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(1, -22, 0.5, -4)
statusDot.BackgroundColor3 = C.textMuted
statusDot.BorderSizePixel = 0
statusDot.Parent = topBar
track(statusDot)

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = statusDot

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = rndName()
minimizeBtn.Size = UDim2.new(0, 24, 0, 24)
minimizeBtn.Position = UDim2.new(1, -32, 0.5, -12)
minimizeBtn.BackgroundTransparency = 1
minimizeBtn.Text = "\xE2\x80\x93"
minimizeBtn.TextColor3 = C.textMuted
minimizeBtn.TextSize = 16
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.BorderSizePixel = 0
minimizeBtn.Parent = topBar
track(minimizeBtn)

local contentArea = Instance.new("Frame")
contentArea.Name = rndName()
contentArea.Size = UDim2.new(1, -16, 1, -44)
contentArea.Position = UDim2.new(0, 8, 0, 40)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame
track(contentArea)

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = rndName()
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready"
statusLabel.TextColor3 = C.textSecondary
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.Parent = contentArea
track(statusLabel)

local btnContainer = Instance.new("Frame")
btnContainer.Name = rndName()
btnContainer.Size = UDim2.new(1, 0, 1, -24)
btnContainer.Position = UDim2.new(0, 0, 0, 24)
btnContainer.BackgroundTransparency = 1
btnContainer.Parent = contentArea
track(btnContainer)

-- Button factory: parent, text, x, y, w, h, accent, bright, glow
local function createButton(parent, text, x, y, w, h, accentColor, brightColor, glowColor)
    local container = Instance.new("Frame")
    container.Name = rndName()
    container.Size = UDim2.new(0, w, 0, h)
    container.Position = UDim2.new(0, x, 0, y)
    container.BackgroundTransparency = 1
    container.Parent = parent
    track(container)

    local glow = Instance.new("Frame")
    glow.Name = rndName()
    glow.Size = UDim2.new(1, 6, 1, 6)
    glow.Position = UDim2.new(0, -3, 0, -3)
    glow.BackgroundColor3 = glowColor
    glow.BackgroundTransparency = 0.85
    glow.BorderSizePixel = 0
    glow.ZIndex = 0
    glow.Parent = container

    local glowCorner = Instance.new("UICorner")
    glowCorner.CornerRadius = UDim.new(0, 10)
    glowCorner.Parent = glow

    local btn = Instance.new("TextButton")
    btn.Name = rndName()
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundColor3 = accentColor
    btn.Text = text
    btn.TextColor3 = C.textPrimary
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.ZIndex = 1
    btn.Parent = container
    track(btn)

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 10)
    btnCorner.Parent = btn

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, brightColor),
        ColorSequenceKeypoint.new(0.5, accentColor),
        ColorSequenceKeypoint.new(1, accentColor),
    })
    gradient.Rotation = 135
    gradient.Parent = btn

    local shine = Instance.new("Frame")
    shine.Name = rndName()
    shine.Size = UDim2.new(1, 0, 1, 0)
    shine.BackgroundTransparency = 1
    shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    shine.BorderSizePixel = 0
    shine.ZIndex = 2
    shine.Parent = btn

    local shineCorner = Instance.new("UICorner")
    shineCorner.CornerRadius = UDim.new(0, 10)
    shineCorner.Parent = shine

    btn.MouseEnter:Connect(function()
        tween(btn, { BackgroundTransparency = 0.1 }, 0.15):Play()
        tween(shine, { BackgroundTransparency = 0.85 }, 0.15):Play()
        tween(glow, { BackgroundTransparency = 0.7 }, 0.15):Play()
    end)

    btn.MouseLeave:Connect(function()
        tween(btn, { BackgroundTransparency = 0 }, 0.15):Play()
        tween(shine, { BackgroundTransparency = 1 }, 0.15):Play()
        tween(glow, { BackgroundTransparency = 0.85 }, 0.15):Play()
    end)

    btn.MouseButton1Down:Connect(function()
        tween(btn, { Size = UDim2.new(1, -2, 1, -2) }, 0.08, Enum.EasingStyle.Quad):Play()
    end)

    btn.MouseButton1Up:Connect(function()
        tween(btn, { Size = UDim2.new(1, 0, 1, 0) }, 0.15, Enum.EasingStyle.Quad):Play()
    end)

    return {
        btn = btn,
        glow = glow,
        shine = shine,
        container = container,
        accentColor = accentColor,
        brightColor = brightColor,
        glowColor = glowColor,
    }
end

local recordBtn = createButton(
    btnContainer, "Record", 8, 4, 126, 48,
    C.record, C.recordBright, C.recordGlow
)

local recordIcon = Instance.new("TextLabel")
recordIcon.Name = rndName()
recordIcon.Size = UDim2.new(0, 10, 0, 10)
recordIcon.Position = UDim2.new(0, 14, 0.5, -5)
recordIcon.BackgroundTransparency = 1
recordIcon.Text = "\xE2\x97\x8F"
recordIcon.TextColor3 = C.textPrimary
recordIcon.TextSize = 10
recordIcon.Font = Enum.Font.GothamBold
recordIcon.TextXAlignment = Enum.TextXAlignment.Center
recordIcon.ZIndex = 3
recordIcon.Parent = recordBtn.btn
track(recordIcon)

local recordText = Instance.new("TextLabel")
recordText.Name = rndName()
recordText.Size = UDim2.new(1, -30, 1, 0)
recordText.Position = UDim2.new(0, 28, 0, 0)
recordText.BackgroundTransparency = 1
recordText.Text = "Record"
recordText.TextColor3 = C.textPrimary
recordText.TextSize = 14
recordText.Font = Enum.Font.GothamBold
recordText.TextXAlignment = Enum.TextXAlignment.Center
recordText.ZIndex = 3
recordText.Parent = recordBtn.btn
track(recordText)

local replayBtn = createButton(
    btnContainer, "Replay", 146, 4, 126, 48,
    C.replay, C.replayBright, C.replayGlow
)

local replayIcon = Instance.new("TextLabel")
replayIcon.Name = rndName()
replayIcon.Size = UDim2.new(0, 10, 0, 10)
replayIcon.Position = UDim2.new(0, 14, 0.5, -5)
replayIcon.BackgroundTransparency = 1
replayIcon.Text = "\xE2\x96\xB6"
replayIcon.TextColor3 = C.textPrimary
replayIcon.TextSize = 10
replayIcon.Font = Enum.Font.GothamBold
replayIcon.TextXAlignment = Enum.TextXAlignment.Center
replayIcon.ZIndex = 3
replayIcon.Parent = replayBtn.btn
track(replayIcon)

local replayText = Instance.new("TextLabel")
replayText.Name = rndName()
replayText.Size = UDim2.new(1, -30, 1, 0)
replayText.Position = UDim2.new(0, 28, 0, 0)
replayText.BackgroundTransparency = 1
replayText.Text = "Replay"
replayText.TextColor3 = C.textPrimary
replayText.TextSize = 14
replayText.Font = Enum.Font.GothamBold
replayText.TextXAlignment = Enum.TextXAlignment.Center
replayText.ZIndex = 3
replayText.Parent = replayBtn.btn
track(replayText)

local footer = Instance.new("Frame")
footer.Name = rndName()
footer.Size = UDim2.new(1, 0, 0, 18)
footer.Position = UDim2.new(0, 0, 1, -18)
footer.BackgroundTransparency = 1
footer.Parent = mainFrame
track(footer)

local footerText = Instance.new("TextLabel")
footerText.Name = rndName()
footerText.Size = UDim2.new(1, 0, 1, 0)
footerText.BackgroundTransparency = 1
footerText.Text = "v5.2 \xC2\xB7 Delta"
footerText.TextColor3 = C.textMuted
footerText.TextSize = 9
footerText.Font = Enum.Font.Gotham
footerText.TextXAlignment = Enum.TextXAlignment.Center
footerText.Parent = footer
track(footerText)

local isMinimized = false
local minimizedSize = UDim2.new(0, 280, 0, 36)
local normalSize = UDim2.new(0, 280, 0, 160)

minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        tween(mainFrame, { Size = minimizedSize }, 0.3, Enum.EasingStyle.Quint):Play()
        minimizeBtn.Text = "+"
    else
        tween(mainFrame, { Size = normalSize }, 0.3, Enum.EasingStyle.Quint):Play()
        minimizeBtn.Text = "\xE2\x80\x93"
    end
end)

local pulseTween = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local pulseAnim = TweenService:Create(statusDot, pulseTween, {
    BackgroundTransparency = 0.3,
    Size = UDim2.new(0, 10, 0, 10),
})

local function setDotColor(color)
    pulseAnim:Cancel()
    tween(statusDot, { BackgroundColor3 = color, Size = UDim2.new(0, 8, 0, 8) }, 0.2):Play()
end

local function startPulse(color)
    pulseAnim:Cancel()
    statusDot.BackgroundColor3 = color
    pulseAnim = TweenService:Create(statusDot, pulseTween, {
        BackgroundTransparency = 0.3,
        Size = UDim2.new(0, 10, 0, 10),
    })
    pulseAnim:Play()
end

local defaultStatusColor = C.textSecondary

local function setStatus(text, color)
    if statusLabel then
        statusLabel.Text = text or "Ready"
        statusLabel.TextColor3 = color or defaultStatusColor
    end
    if color then
        setDotColor(color)
    end
end

local function setRecordButtonState(state)
    if state == "recording" then
        tween(recordBtn.btn, { BackgroundColor3 = C.record }, 0.2):Play()
        recordText.Text = "Stop"
        recordIcon.Text = "\xE2\x96\xA0"
        startPulse(C.record)
    else
        tween(recordBtn.btn, { BackgroundColor3 = C.record }, 0.2):Play()
        recordText.Text = "Record"
        recordIcon.Text = "\xE2\x97\x8F"
        setDotColor(C.textMuted)
    end
end

local function setReplayButtonState(state)
    if state == "replaying" then
        tween(replayBtn.btn, { BackgroundColor3 = C.replay }, 0.2):Play()
        replayText.Text = "Stop"
        startPulse(C.replay)
    else
        tween(replayBtn.btn, { BackgroundColor3 = C.replay }, 0.2):Play()
        replayText.Text = "Replay"
        setDotColor(C.textMuted)
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

recordBtn.btn.MouseButton1Click:Connect(function()
    if callbacks.onRecordToggle then
        callbacks.onRecordToggle()
    end
end)

replayBtn.btn.MouseButton1Click:Connect(function()
    if callbacks.onReplayToggle then
        callbacks.onReplayToggle()
    end
end)

mainFrame.Size = UDim2.new(0, 280, 0, 0)
mainFrame.BackgroundTransparency = 1
mainStroke.Transparency = 1

task.spawn(function()
    task.wait(0.1)
    TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 280, 0, 160),
        BackgroundTransparency = 0,
    }):Play()

    task.wait(0.15)
    TweenService:Create(mainStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Transparency = 0.4,
    }):Play()

    for _, child in ipairs(contentArea:GetChildren()) do
        if child:IsA("GuiObject") and child.Name ~= "" then
            child.Position = child.Position + UDim2.new(0, 0, 0, 10)
            child.BackgroundTransparency = 1
            if child:IsA("TextLabel") then
                child.TextTransparency = 1
            end
        end
    end

    task.wait(0.2)
    for i, child in ipairs(contentArea:GetChildren()) do
        if child:IsA("GuiObject") then
            task.wait(0.04)
            tween(child, {
                Position = child.Position - UDim2.new(0, 0, 0, 10),
                BackgroundTransparency = 1,
            }, 0.3):Play()
            if child:IsA("TextLabel") then
                tween(child, { TextTransparency = 0 }, 0.3):Play()
            end
        end
    end
end)

local publicAPI = {
    rootGui       = rootGui,
    mainFrame     = mainFrame,
    statusLabel   = statusLabel,
    btnRecord     = recordBtn.btn,
    btnReplay     = replayBtn.btn,

    setStatus             = setStatus,
    setRecordButtonState  = setRecordButtonState,
    setReplayButtonState  = setReplayButtonState,
    isOverRecorderGui     = function(x, y)
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
    end,
    setCallbacks          = setCallbacks,
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
