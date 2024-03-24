local modname="[CameraDistance]"
local hotkeySettings = {
		["KeboardUp"] = "C",
		["KeboardDown"] =  "Z",
		["WheelUp"] = "LDown",
		["WheelDown"] =  "LUp",
		["WheelUp2"] = "RT (R2)",
		["WheelDown2"] =  "RT (R2)",
}

log.info(modname.."Start")
local myLog="LogStart\n"
local hk = require("Hotkeys/Hotkeys")
hk.setup_hotkeys(hotkeySettings)


local function Log(msg)
    myLog = myLog .."\n".. msg
    log.info(modname..msg)
end

local function ClearLog()
    draw.text(myLog,50,50,0xffEEEEFE)
    myLog = ""
end

re.on_frame(function()
    local gm=sdk.get_managed_singleton("app.GuiManager")  

    if hk.check_hotkey("KeboardUp", true) or (hk.check_hotkey("WheelUp", true) and hk.check_hotkey("WheelUp2", true)) then
        local cm=sdk.get_managed_singleton("app.CameraManager")
        cm._DistanceOffset=cm._DistanceOffset+0.15
        Log("WheelUp"..tostring(cm._DistanceOffset))
    end

    if hk.check_hotkey("KeboardDown", true) or (hk.check_hotkey("WheelDown", true) and hk.check_hotkey("WheelDown2", true)) then
        local cm=sdk.get_managed_singleton("app.CameraManager")
        cm._DistanceOffset=cm._DistanceOffset-0.15
        Log("WheelDown"..tostring(cm._DistanceOffset))
    end
    
    ClearLog()    
end)

