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

local inited=false
sdk.hook(
    sdk.find_type_definition("app.OptionManager"):get_method("app.ISystemSaveData.loadSystemSaveData(app.SaveDataBase)"),
    nil,
    function ()
        if not inited then
            local font =myapi.LoadFontIfCJK("simhei.ttf",nil,nil)
            myapi.DrawIt(modname,configfile,_config,config,nil,true,font)
            inited=true
        end
    end
)


local function AddItem()

    local im=sdk.get_managed_singleton("app.ItemManager")
    local player_man=sdk.get_managed_singleton("app.CharacterManager")
    local player=player_man:get_ManualPlayer()
    if im==nil or player_man==nil or player==nil then return end

    --Gather TreasureBox Talk DeadEnemy
    local type=sdk.find_type_definition("app.ItemManager.GetItemEventType"):get_field("TreasureBox"):get_data()
    local getItemMethod=im:get_type_definition():get_method("getItem(System.Int32, System.Int32, app.Character, System.Boolean, System.Boolean, System.Boolean, app.ItemManager.GetItemEventType, System.Boolean, System.Boolean)")
    --im:getItem(90,1,player,true,false,false,1,false,false) not work
    getItemMethod:call(im,math.floor(config.item),math.floor(config.count),player,true,false,false,1,false,false)
    --Log("111")
end

onClickFunc=AddItem


