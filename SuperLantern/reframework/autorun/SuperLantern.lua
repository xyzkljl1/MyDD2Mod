local modname="[SuperLantern]"

log.info(modname.."Start")
local myLog="LogStart\n"

local config = json.load_file("SuperLantern.json") or {}
local fix_msg=""
local fix_msg2=""
config.range=config.range or 3000
config.light=config.light or 10
--140
config.cone=config.cone or 140
--default 1/0.451,0.18
config.spotR=config.spotR or 1.0
config.spotG=config.spotG or 0.451
config.spotB=config.spotB or 0.18
config.pointR=config.pointR or 1
config.pointG=config.pointG or 0.451
config.pointB=config.pointB or 0.18

local light_ptr=sdk.float_to_ptr(config.light)

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

local function setSpotLightDirection(_light,cone)
    local light=_light.LightComp
    --140 cone 120 spread 1 radius
    light:set_Cone(cone)
    --Æðµã£¬ÖÕµã£¬£¿£¬£¿
    --local paras=light:get_LightParameterFloat4()    
end

local function setLightColor(_light,r,g,b)
    local light=_light.LightComp
    local color=light:get_Color()
    color.x=r
    color.y=g
    color.z=b
    light:set_Color(color)
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

local function SetLightColorCone()
    local player=player_man:get_ManualPlayer()
    if player ~=nil and player:get_Human()~=nil then
        local lights=player:get_Human():get_LanternCtrl().LanternLightList
        --0 SpotLight 1 PointLight
        setSpotLightDirection(lights[0],config.cone*1.0)
        setLightColor(lights[0],config.spotR*1.0,config.spotG*1.0,config.spotB*1.0)
        setLightColor(lights[1],config.pointR*1.0,config.pointG*1.0,config.pointB*1.0)
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

re.on_frame(SetLightColorCone)

local function logf(light)
    Log("-")
    Log(tostring(light))
    if light~=nil then
        Log(tostring(light:get_type_definition():get_full_name()))
        Log(tostring(light:get_Enabled()))
        local color=light:get_Color()
        Log(tostring(color.x))
        Log(tostring(color.y))
        Log(tostring(color.z))
        Log(tostring(color))
    end
    Log("--")
end

if false then
    re.on_frame(function()
        Log("This is Debug ouput.If you see this,report a bug plz.")
        local player=player_man:get_ManualPlayer()
        if player~=nil and true then
            local stid=tm:getEquipLanternStorageId(player.CharacterID)
            local lanternInfo=tm:getLanternInfo(stid)
            local player=player_man:get_ManualPlayer()
            local lights=player:get_Human():get_LanternCtrl().LanternLightList

            --SetLightColorCone()

            Log("!!")
            for i=0,lights:get_Count()-1 do
                local light=lights[i]
                Log(tostring(light:get_type_definition():get_full_name()))
                --light.MasterLightIntensity=100
                --Log(tostring(light.MasterLightIntensity))
                --Log(tostring(light.BaseEffectiveRange))
                logf(light.LightComp)
                --logf(light.PointLight)
                --logf(light.SpotLight)
                Log(";;;;;;;;;;;;;;;;;;;")        
            end
            --Log(tostring(player.CharacterID))
            Log(fix_msg)
            Log(fix_msg2)
            ClearLog()
        end
    end)
end

