-------
local modname="ExampleModUsingHotkeyAndInit"
local configfile=modname..".json"


local onAddToFavList=nil
local onFavListClick=nil
local onRemoveFromFavList=nil
--settings
local _config={
    {name="para1",type="font",default="simsun.ttc",widthscale=0.4},
    {name="",type="sameline"},-- same line
    {name="para2",type="fontsize",default=29,widthscale=0.4},

    {name="Box1",type="mutualbox"},--box
    {name="keyboardKey",type="hotkey",default="Alpha1",actionName="keyboardKey7784",sameline=true},
    {name="controllerKeyShoulder",type="hotkey",default="RT (R2)",actionName="controllerKeyShoulder7784"},

    --{name="",type="mutualboxend"},--start a new mutualbox will end the prev box automatically
    {name="Box2",type="mutualbox"},
    {name="controllerKeyNotShoulder",type="hotkey",default="LLeft",actionName="controllerKeyNotShoulder7784"},    
    {name="",type="mutualboxend"},
    {name="ReplacedStaff",type="boolList",default={
                            --"Gm82_000",--¿ÉÊ°È¡ÎïÆ·
                            --"Gm82_000_001",--×ÔÈ»Éú³ÉµÄÎïÆ·
                            --"Gm82_000_002",--¶ªÆúµÄÎïÆ·
                            ["Gm80_008"]="chain",--stone
                            ["Gm80_009"]="stone",--stone
                            ["Gm80_010"]="stone",--stone
                            ["Gm80_103"]="sandbag",--É³´ü
                            ["Gm80_109"]="tree",--tree
                            ["Gm80_110"]="tree",--tree?
                            ["Gm80_241"]="candle&glass?",
                            --["Gm82_001"]="key",
                            --["Gm82_002"]="key",
                            ["Gm82_009_01"]="plant gather point",--²Ý
                            ["Gm82_009_02"]="plant gather point",
                            ["Gm82_009_03"]="plant gather point",
                            ["Gm82_009_04"]="plant gather point",--²Ý
                            ["Gm82_009_05"]="plant gather point",--²Ý
                            ["Gm82_009_06"]="plant gather point",--²Ý
                            ["Gm82_009_10"]="plant gather point?",--²Ý
                            ["Gm82_009_20"]="plant gather point?",--²Ý
                            ["Gm82_016_10"]="bone gather point",--¹ÇÍ·
                            ["Gm82_017_10"]="wood gather point",--·ÏÐæ¶Ñ
                            ["Gm82_011"]="plant gather point?",--²Ý
                            ["Gm82_012"]="plant gather point?",--²Ý
                            ["Gm82_013"]="plant gather point?",--²Ý
                            ["Gm82_020"]="potato gather point",--²Ý
                            ["Gm82_069"]="fish gather point",--Óã
                        --    "Gm80_079_10",--óô»ð
                        --    "Gm51_574",--Ïä×Ó
                            ["Gm50_097"]="haystack",--µ¾²Ý¶Ñ
                            ["Gm50_011_00"]="wood",
                            ["Gm50_011_01"]="wood",
                            ["Gm50_011_02"]="wood",
                            ["Gm50_013_01"]="barrel",
                            ["Gm50_013_02"]="barrel",
                            ["Gm50_040_10"]="barrel",--Ä¾Í°
                            ["Gm51_083"]="barrel",
                            --"Gm51_045",--ÔÓÎï
                        }
    },
    {name="item",type="item",default=1},
    {name="Get",type="button",onClick=function() print("Clicked") end},    
    {name="gimmickName",type="stringComboBox",label="ChestModel",default="Gm80_097",list={
            ["Gm80_001"]="Wooden",
            ["Gm80_096"]="Black",
            ["Gm80_097"]="Golden Red",
            ["Gm81_042"]="Sphinx",
            ["Gm80_211"]="Old Golden Red",
            --["Gm81_042_01"]="Super Big",--need key
            ["Gm80_001_10"]="Also Wooden",
            ["Gm80_096_10"]="Also Black",
            }
    },
    {name="AddToFavList",type="button",onClick=function() onAddToFavList() end,sameline=true},
    {name="RemoveFromFavList",type="button",onClick=function() onRemoveFromFavList() end},
    {name="FavList",type="buttonN",onClick=function(...) onFavListClick(...) end,default={}},

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

onAddToFavList=function()
    if config.item==nil then return end
    local itemDict=sdk.get_managed_singleton("app.ItemManager"):get_ItemDataDict()
    local item=itemDict:get_Item(config.item)
    if item~=nil then
        if config.FavList~=nil then
            for _,v in pairs(config.FavList) do
                if v.index==config.item then
                    return
                end
            end
        end
        local favitem={
            index=config.item,
            name=config.item.." / "..item:get_Name()
        }
        config.FavList=config.FavList or {}
        table.insert(config.FavList,favitem)
    end
end

onRemoveFromFavList=function()
    if config.item==nil or config.FavList==nil then return end
    for k,v in pairs(config.FavList) do
        if v.index==config.item then
            config.FavList[k]=nil
        end
    end
end

onFavListClick=function(para)
    if para[1]~=nil then config.item=para[1] end
end

--Draw UI
myapi.DrawIt(modname,configfile,_config,config,OnChanged)
