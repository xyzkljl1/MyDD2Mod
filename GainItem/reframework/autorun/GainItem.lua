local modname="GainItem"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local onClickFunc=nil

local _config={
    {name="item",type="item",default=1},
    {name="count",type="int",default=1,min=1,max=99},
    {name="Get",type="button",onClick=function() onClickFunc() end},
}

local myapi = require("_XYZApi/_XYZApi")
local config=myapi.InitFromFile(_config,configfile)

local function Log(msg)
    print(msg)
    log.info(modname..msg)
end

--Should Add this to api
local inited=false
local font=nil
local function Init()
    if font==nil then
        --reload font everytime,in case the font is not right on first init
        font =myapi.LoadFontIfCJK("simhei.ttf",nil,nil)
    end
    if not inited then
        myapi.DrawIt(modname,configfile,_config,config,nil,true,function() return font end)
        inited=true
    end
end
sdk.hook(sdk.find_type_definition("app.OptionManager"):get_method("app.ISystemSaveData.loadSystemSaveData(app.SaveDataBase)"),nil,Init)
sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),nil,Init)
Init()

local Wakestone=77
local WakestoneShards=78

local tmpep=sdk.create_instance("app.ItemDefine.EnhanceParam"):add_ref()
local function AddItem()

    local im=sdk.get_managed_singleton("app.ItemManager")
    local player_man=sdk.get_managed_singleton("app.CharacterManager")
    local player=player_man:get_ManualPlayer()
    if im==nil or player_man==nil or player==nil then return end

    --Gather TreasureBox Talk DeadEnemy
    local type=sdk.find_type_definition("app.ItemManager.GetItemEventType"):get_field("TreasureBox"):get_data()
    --local getItemMethod=im:get_type_definition():get_method("getItem(System.Int32, System.Int32, app.Character, System.Boolean, System.Boolean, System.Boolean, app.ItemManager.GetItemEventType, System.Boolean, System.Boolean)")
    local getItemMethod2=im:get_type_definition():get_method("getItem(System.Int32, System.Int32, app.ItemDefine.EnhanceParam, app.CharacterID, System.Boolean, System.Boolean, System.Boolean, app.ItemManager.GetItemEventType, System.Boolean)")

    --wakestone shards->wakestone causes crash.Can't  fix it.
    -- so just remove shards and give wakestone
    if config.item == WakestoneShards then
        --for funcs has overload ,must use get_method
        local getNumMethod=im:get_type_definition():get_method("getHaveNum(System.Int32, app.Character)")
        local deleteMethod=im:get_type_definition():get_method("deleteItem(System.Int32, System.Int32, app.Character)")
        local ct=getNumMethod:call(im,WakestoneShards,player)
        local total_ct=math.floor(config.count)+ct
        local stone_ct=math.floor(total_ct/3)
        local left_ct=total_ct-stone_ct*3

        if left_ct >ct then
            Log("Add Shards "..tostring(left_ct-ct))
            getItemMethod:call(im,WakestoneShards,left_ct-ct,player,true,false,false,1,false,false)
        elseif left_ct<ct then
            Log("Reduce Shards "..tostring(ct-left_ct))
            deleteMethod:call(im,WakestoneShards,ct-left_ct,player)
        end
        if stone_ct>0 then
            getItemMethod:call(im,Wakestone,stone_ct,player,true,false,false,1,false,false)           
        end
        Log("Modify WakeStoneShards "..ct.."/"..total_ct.."/"..left_ct)
    else
        --getItemMethod:call(im,math.floor(config.item),math.floor(config.count),player,true,false,false,1,false,false)
        getItemMethod2:call(im,math.floor(config.item),math.floor(config.count),tmpep,65535,true,false,false,1,false)
    end
end

onClickFunc=AddItem

