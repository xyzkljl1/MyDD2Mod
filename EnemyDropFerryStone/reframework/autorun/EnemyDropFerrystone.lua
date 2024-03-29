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

local myItem=sdk.create_instance("app.ItemDropParam.Table.Item")
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

local CJK_GLYPH_RANGES = {
    0x0020, 0x00FF, -- Basic Latin + Latin Supplement
    0x2000, 0x206F, -- General Punctuation
    --0x3000, 0x30FF, -- CJK Symbols and Punctuations, Hiragana, Katakana
    --0xFF00, 0xFFEF, -- Half-width characters
    0x4e00, 0x9FAF, -- CJK Ideograms
    0,
}
local font = imgui.load_font( "simhei.ttf", 14,CJK_GLYPH_RANGES)
myapi.DrawIt(modname,configfile,_config,config,OnChanged,true,font)