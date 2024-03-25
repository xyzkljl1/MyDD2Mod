local modname="[NameOnHead]"
log.info(modname.."Start")
local myLog="LogStart\n"

local config = json.load_file("NameOnHead.json") or {}
if config.fontsize==nil then config.fontsize=60 end
if config.color==nil then config.color=0xffEEEEEE end
if config.offsetX==nil then config.offsetX=0 end
if config.offsetY==nil then config.offsetY=0 end
if config.offsetZ==nil then config.offsetZ=0 end
if config.keyboardKey==nil then config.keyboardKey="Alpha1" end
if config.controllerKeyShoulder==nil then config.controllerKeyShoulder="RT (R2)" end
if config.controllerKeyNotShoulder==nil then config.controllerKeyNotShoulder="LLeft" end

local font = imgui.load_font("times.ttf", config.fontsize)
local hk = require("Hotkeys/Hotkeys")

local hotkeySettings = {
		["Keyboard"] = config.keyboardKey,
		["controllerKeyShoulder"] = config.controllerKeyShoulder,
		["controllerKeyNotShoulder"] = config.controllerKeyNotShoulder,
}
hk.setup_hotkeys(hotkeySettings)
local on=false

local function Log(msg)
    myLog = myLog .."\n".. msg
    log.info(modname..msg)
end
local function ClearLog()
    draw.text(myLog,50,50,0xffEEEEFE)
    --draw.text(myLog,250,-1000,0xffEEEEFE)
    myLog = ""
end

re.on_frame(function()
    if hk.check_hotkey("Keyboard",false,true) or ((hk.check_hotkey("controllerKeyShoulder",  true,false) and hk.check_hotkey("controllerKeyNotShoulder",  false,true))) then
        on=not on
        --Log("Trigger")        
        --ClearLog()
    end
    --ClearLog()
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
                --text="啦啦啦啦"
                draw.world_text(text,text_pos,config.color)
            end
        end

        imgui.pop_font()
        ClearLog()
    end
end)
