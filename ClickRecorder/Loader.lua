-- Delta Click Recorder v5.0 - Loader
-- Run this one line in Delta. It fetches everything automatically.

local Stealth = loadstring(game:HttpGet("https://raw.githubusercontent.com/amerameryou1-blip/Aurora-/main/ClickRecorder/Stealth.lua"))()
Stealth.init()

local GUI   = loadstring(game:HttpGet("https://raw.githubusercontent.com/amerameryou1-blip/Aurora-/main/ClickRecorder/GUI.lua"))()
local Logic = loadstring(game:HttpGet("https://raw.githubusercontent.com/amerameryou1-blip/Aurora-/main/ClickRecorder/Logic.lua"))()
Logic.init(GUI, Stealth)
