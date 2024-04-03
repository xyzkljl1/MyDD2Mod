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
    {name="ReplacedStaff",type="boolList",default={
                            --"Gm82_000",--��ʰȡ��Ʒ
                            --"Gm82_000_001",--��Ȼ���ɵ���Ʒ
                            --"Gm82_000_002",--��������Ʒ
                            ["Gm80_008"]="chain",--stone
                            ["Gm80_009"]="stone",--stone
                            ["Gm80_010"]="stone",--stone
                            ["Gm80_103"]="sandbag",--ɳ��
                            ["Gm80_109"]="tree",--tree
                            ["Gm80_110"]="tree",--tree?
                            ["Gm80_241"]="candle&glass?",
                            --["Gm82_001"]="key",
                            --["Gm82_002"]="key",
                            ["Gm82_009_01"]="plant gather point",--��
                            ["Gm82_009_02"]="plant gather point",
                            ["Gm82_009_03"]="plant gather point",
                            ["Gm82_009_04"]="plant gather point",--��
                            ["Gm82_009_05"]="plant gather point",--��
                            ["Gm82_009_06"]="plant gather point",--��
                            ["Gm82_009_10"]="plant gather point?",--��
                            ["Gm82_009_20"]="plant gather point?",--��
                            ["Gm82_016_10"]="bone gather point",--��ͷ
                            ["Gm82_017_10"]="wood gather point",--�����
                            ["Gm82_011"]="plant gather point?",--��
                            ["Gm82_012"]="plant gather point?",--��
                            ["Gm82_013"]="plant gather point?",--��
                            ["Gm82_020"]="potato gather point",--��
                            ["Gm82_069"]="fish gather point",--��
                        --    "Gm80_079_10",--����
                        --    "Gm51_574",--����
                            ["Gm50_097"]="haystack",--���ݶ�
                            ["Gm50_011_00"]="wood",
                            ["Gm50_011_01"]="wood",
                            ["Gm50_011_02"]="wood",
                            ["Gm50_013_01"]="barrel",
                            ["Gm50_013_02"]="barrel",
                            ["Gm50_040_10"]="barrel",--ľͰ
                            ["Gm51_083"]="barrel",
                            --"Gm51_045",--����
                        }
    },
    {name="item",type="item",default=1},
    {name="Get",type="button",onClick=function() print("Clicked") end},
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
