local modname="[CameraDistance]"

local config = json.load_file("CameraDistance.json") or {}
if config.dis==nil then config.dis=1.0 end
if config.enableWheel==nil then config.enableWheel=true end
if config.KeyboardUp==nil then config.KeyboardUp="C" end
if config.KeyboardDown==nil then config.KeyboardDown="Z" end



local hotkeySettings = {
		["KeboardUp"] = config.KeyboardUp,
		["KeboardDown"] =  config.KeyboardDown,
		["WheelUp"] = "LDown",
		["WheelDown"] =  "LUp",
		["WheelUp2"] = "RT (R2)",
		["WheelDown2"] =  "RT (R2)",
}


log.info(modname.."Start")
local myLog="LogStart\n"
local hk = require("Hotkeys/Hotkeys")
hk.setup_hotkeys(hotkeySettings)

local mouse_singleton=sdk.get_native_singleton("via.hid.Mouse")
local mouse_typedef=sdk.find_type_definition("via.hid.Mouse")
local mouse_device

local cm=sdk.get_managed_singleton("app.CameraManager")
cm._DistanceOffset=config.dis


local function Log(msg)
    myLog = myLog .."\n".. msg
    log.info(modname..msg)
end

local function ClearLog()
    draw.text(myLog,50,50,0xffEEEEFE)
    myLog = ""
end

local function ModifyDistance(offset)
	local cm=sdk.get_managed_singleton("app.CameraManager")
    cm._DistanceOffset=cm._DistanceOffset+offset
    Log("to "..tostring(cm._DistanceOffset))    
end


re.on_frame(function()

    if hk.check_hotkey("KeboardUp", true) or (hk.check_hotkey("WheelUp", true) and hk.check_hotkey("WheelUp2", true)) then
        ModifyDistance(0.15)
    end

    if hk.check_hotkey("KeboardDown", true) or (hk.check_hotkey("WheelDown", true) and hk.check_hotkey("WheelDown2", true)) then
        ModifyDistance(-0.15)
    end
    local gm=sdk.get_managed_singleton("app.GuiManager")
	if gm~=nil and gm:get_IsLoadGui()==false 
        and mouse_device~=nil and config.enableWheel==true then
		    local wheel_delta=mouse_device:get_WheelDelta()
		    if wheel_delta~=0 then
			   ModifyDistance(-wheel_delta)
		    end
	end

    ClearLog()    
end)


re.on_application_entry("UpdateHID",
	function()
		mouse_device=sdk.call_native_func(mouse_singleton, mouse_typedef, "get_Device")
	end
)