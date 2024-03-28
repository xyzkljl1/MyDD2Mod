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

local CJK_GLYPH_RANGES = {
    0x0020, 0x00FF, -- Basic Latin + Latin Supplement
    0x2000, 0x206F, -- General Punctuation
    --0x3000, 0x30FF, -- CJK Symbols and Punctuations, Hiragana, Katakana
    --0xFF00, 0xFFEF, -- Half-width characters
    0x4e00, 0x9FAF, -- CJK Ideograms
    0,
}
local font = imgui.load_font( "simhei.ttf", 14,CJK_GLYPH_RANGES)
myapi.DrawIt(modname,configfile,_config,config,nil,true,font)

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
