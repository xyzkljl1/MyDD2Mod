local modname="[SuperLantern]"

log.info(modname.."Start")
local myLog="LogStart\n"

local config = json.load_file("SuperLantern.json") or {}
local fix_msg=""
local fix_msg2=""
config.range=config.range or 3000
config.light=config.light or 10
light_ptr=sdk.float_to_ptr(config.light)


local function Log(msg)
    myLog = myLog .."\n".. msg
    log.info(modname..msg)
end
local function ClearLog()
    draw.text(myLog,50,50,0xffEEEEFE)
    myLog = ""
end

local tm=sdk.get_managed_singleton("app.ItemManager")
local player_man=sdk.get_managed_singleton("app.CharacterManager")

local function SetConsumeNone()
    local player=player_man:get_ManualPlayer()
    if player ~=nil then
        currentHuman=player:get_Human()
        local para=currentHuman:get_Param():get_Action().LanternParam
        --0.0125/s total 100
        para.ConsumeOilSecSpeed=0
        --5/1 not work
        --para.OilForBlinking=100
        --para.OilForHighFreqBlinking=100
        Log("InitConsume")
    end
end
local function SetLightRange()
    local player=player_man:get_ManualPlayer()
    if player ~=nil then
        local lights=player:get_Human():get_LanternCtrl().LanternLightList
        local ct=lights:get_Count()-1
        for i=0,ct do
            local light=lights[i]
            --1/30 1/20 
            --light.MasterLightIntensity=100 -- not work
            light.BaseEffectiveRange=config.range
        end
    end
end


sdk.hook(
    sdk.find_type_definition("app.LanternController.LanternLightParam"):get_method("setLightIntensity(System.Single)"),
    function(args)
        args[3]=light_ptr
    end,
    nil
)

SetLightRange()
SetConsumeNone()
sdk.hook(
    sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),
    nil,
    function()
        SetLightRange()
        SetConsumeNone()
    end
)

if false then
    re.on_frame(function()
        Log("This is Debug ouput.If you see this,report a bug plz.")
        local player=player_man:get_ManualPlayer()
        if player~=nil then
            local stid=tm:getEquipLanternStorageId(player.CharacterID)
            local lanternInfo=tm:getLanternInfo(stid)
            if lanternInfo~=nil then
                Log(tostring(lanternInfo.Oil))
            end
            local player=player_man:get_ManualPlayer()
            local lights=player:get_Human():get_LanternCtrl().LanternLightList
            for i=0,lights:get_Count()-1 do
                local light=lights[i]
                Log(tostring(light:get_type_definition():get_full_name()))
                --light.MasterLightIntensity=100
                Log(tostring(light.MasterLightIntensity))
                Log(tostring(light.BaseEffectiveRange))
        
            end

            --Log(tostring(player.CharacterID))
            Log(fix_msg)
            Log(fix_msg2)
            ClearLog()
        end
    end)
end

