local modname="EnemyDropFerryStone"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local eachRate={0,0,0,0,0}
local DropListCT=5

local _config={
    {name="item1",type="item",default=80},
    {name="count1",type="int",default=1,min=0,max=99},
    {name="rate1",type="int",default=5,min=0,max=100},

    {name="item2",type="item",default=1},
    {name="count2",type="int",default=1,min=0,max=99},
    {name="rate2",type="int",default=0,min=0,max=100},

    {name="item3",type="item",default=1},
    {name="count3",type="int",default=0,min=0,max=99},
    {name="rate3",type="int",default=0,min=0,max=100},

    {name="item4",type="item",default=1},
    {name="count4",type="int",default=0,min=0,max=99},
    {name="rate4",type="int",default=0,min=0,max=100},

    {name="item5",type="item",default=1},
    {name="count5",type="int",default=0,min=0,max=99},
    {name="rate5",type="int",default=0,min=0,max=100},
}

local myapi = require("_XYZApi/_XYZApi")
local config=myapi.InitFromFile(_config,configfile)

local function Log(...)
    print(...)
    log.info(modname,...)
end

--Must add_ref(),otherwise the object will be released when the game has a chance to do so
local myItem=sdk.create_instance("app.ItemDropParam.Table.Item"):add_ref()
myItem._Id=1
myItem._Num=1
myItem._Rate=1

--getLotItem not seems to have non-nil retval?
sdk.hook(
    sdk.find_type_definition("app.ItemDropParam.Table"):get_method("getLotItemSub"),
    nil,
    function (retval)
        local item=sdk.to_managed_object(retval)
        if item:get_IsOnce()==true or item:get_IsSpecialOnce()==true then 
            Log("Ignore Once Item")
            return retval 
        end
        --roll a dice
        local random= math.random(0,99)
        for i=1,DropListCT do
            if eachRate[i] > random then
                local istr=tostring(i)
                myItem._Id = config['item'..istr]
                myItem._Num = config['count'..istr]
                Log("Rate: ",random," Replace Drop With "..i)
                return sdk.to_ptr(myItem)
            end
        end
        Log("Rate: ",random," No Replace ",item._Id)
        --original
        return retval
    end
)

local function OnChanged()
    for i=1,DropListCT do
        local istr=tostring(i)
        eachRate[i]=eachRate[i-1] or 0
        if config['count'..istr] >0 and config['rate'..istr] >0 then
            eachRate[i]=eachRate[i]+config['rate'..istr]
        end
    end
    Log("OnSettingChanged")
end
OnChanged()

--Should Add this to api
local inited=false
local function Init()
    if not inited then
        local font =myapi.LoadFontIfCJK("simhei.ttf",nil,nil)
        myapi.DrawIt(modname,configfile,_config,config,OnChanged,true,font)
        inited=true
    end
end
sdk.hook(sdk.find_type_definition("app.OptionManager"):get_method("app.ISystemSaveData.loadSystemSaveData(app.SaveDataBase)"),nil,Init)
sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),nil,Init)



