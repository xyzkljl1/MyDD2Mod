local modname="NameOnHead"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
    {name="font",type="font",default="simsun.ttc"},
    {name="fontsize",type="fontsize",default=29},
    {name="color",type="rgba32",default=0xffEEEEEE},
    {name="offsetX",type="int",default=0,min=-300,max=5000},
    {name="offsetY",type="int",default=0,min=-300,max=5000},
    {name="offsetZ",type="int",default=0,min=-300,max=5000},
    {name="keyboardKey",type="hotkey",default="Alpha1",actionName="keyboardKey2728"},
    {name="controllerKeyShoulder",type="hotkey",default="RT (R2)",actionName="controllerKeyShoulder2728"},
    {name="controllerKeyNotShoulder",type="hotkey",default="LLeft",actionName="controllerKeyNotShoulder2728"},
}
local myapi = require("_XYZApi/_XYZApi")
local hk = require("Hotkeys/Hotkeys")
local config=myapi.InitFromFile(_config,configfile)

--thanks to lingsamuel
local CJK_GLYPH_RANGES = {
    0x0020, 0x00FF, -- Basic Latin + Latin Supplement
    0x2000, 0x206F, -- General Punctuation
    0x3000, 0x30FF, -- CJK Symbols and Punctuations, Hiragana, Katakana
    0x31F0, 0x31FF, -- Katakana Phonetic Extensions
    0xFF00, 0xFFEF, -- Half-width characters
    0x4e00, 0x9FAF, -- CJK Ideograms
    0,
}
--必须有CJK_GLYPH_RANGES才能支持中文字符
--字号过大就会崩溃，不同字体支持字号不一样，中文字体支持的字号比较小？
--simsun:约30，times:至少250 MS明朝：60
local font = imgui.load_font( config.font, config.fontsize,CJK_GLYPH_RANGES)

local on=false

local function Log(msg)
    log.info(modname..msg)
end

re.on_frame(function()
    if hk.check_hotkey("keyboardKey2728",false,true) or ((hk.check_hotkey("controllerKeyShoulder2728",  true,false) and hk.check_hotkey("controllerKeyNotShoulder2728",  false,true))) then
        on=not on
    end
    if on then
        local player_listh=sdk.get_managed_singleton("app.CharacterListHolder")
        local npcm=sdk.get_managed_singleton("app.NPCManager")
        local chars=player_listh:getAllCharacters()
        local ct=chars:get_Count()
        --Log(tostring(ct))
        imgui.push_font(font)
        for i=0,ct-1 do
            local char=chars:get_Item(i)
            --Log(tostring(char:get_DistanceSqFromPlayer()))
            local d=npcm:getNPCData(char:get_CharaID())
            if d ~=nil then
                local joint=char:get_GameObject():get_Transform():getJointByName("Head_0")
                local pos=joint:get_Position()
                local text_pos=Vector3f.new(pos.x+config.offsetX, pos.y+config.offsetY+0.2, pos.z+config.offsetZ)
                --LogTypeMethods(d)
                local text=d:get_Name()
                draw.world_text(text,text_pos,config.color)
            end
        end
        imgui.pop_font()
    end
end)

myapi.DrawIt(modname,configfile,_config,config,nil,true)
