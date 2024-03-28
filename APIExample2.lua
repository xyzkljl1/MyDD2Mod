-------
local modname="ExampleModUsingHotkeyAndInit"
local configfile=modname..".json"
--settings
local _config={
    {name="para1",type="font",default="simsun.ttc"},
    {name="para2",type="fontsize",default=29},
    {name="keyboardKey",type="hotkey",default="Alpha1",actionName="keyboardKey7784"},
    {name="controllerKeyShoulder",type="hotkey",default="RT (R2)",actionName="controllerKeyShoulder7784"},
    {name="controllerKeyNotShoulder",type="hotkey",default="LLeft",actionName="controllerKeyNotShoulder7784"},
}
--Require
--not like the other example,XYZAPI is necessary here.
local myapi = require("_XYZApi/_XYZApi")
local hk = require("Hotkeys/Hotkeys")
local config=myapi.InitFromFile(_config,configfile)

------Mod Implement
re.on_frame(function()
    draw.text("para1="..tostring(config.para1),50,50, 0xffffffff)
    draw.text("para2="..tostring(config.para2),50,80,0xffffffff)
    if hk.check_hotkey("keyboardKey7784",false,true) or ((hk.check_hotkey("controllerKeyShoulder7784",  true,false) and hk.check_hotkey("controllerKeyNotShoulder7784",  false,true))) then
        draw.text("key Triggerer",50,100, 0xffffffff)
    end
    if hk.check_hotkey("keyboardKey7784",true) then
        draw.text("KeyDown",50,120, 0xffffffff)
    end

end)

--Draw UI
myapi.DrawIt(modname,configfile,_config,config,OnChanged)
