local modname="SuperLantern"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
    {name="range",type="int",default=3000,min=1,max=100000},
    {name="light",type="int",default=10,min=0,max=100000},
    {name="blink",type="bool",default=true},
    {name="cone",type="int",default=140,min=1,max=180},
    {name="spotLightColor",type="rgba4f",default={1.0,0.451,0.18}},
    {name="pointLightColor",type="rgba4f",default={1.0,0.451,0.18}},
}

--merge config file to default config
local function recurse_def_settings(tbl, new_tbl)
	for key, value in pairs(new_tbl) do
		if type(tbl[key]) == type(value) then
		    if type(value) == "table" then
			    tbl[key] = recurse_def_settings(tbl[key], value)
            else
    		    tbl[key] = value
            end
		end
	end
	return tbl
end
local config = {} 
for key,para in pairs(_config) do
    config[para.name]=para.default
end

config= recurse_def_settings(config, json.load_file(configfile) or {})
local light_ptr=sdk.float_to_ptr(config.light)

local function Log(msg)
    log.info(modname..msg)
end

local tm=sdk.get_managed_singleton("app.ItemManager")
local player_man=sdk.get_managed_singleton("app.CharacterManager")
local frame=0

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

        if config.blink==true then
            frame=frame+1
            if frame>60 then
                frame=0
            end
            local x=(frame%60)/60.0
            local y=((20+frame)%60)/60.0
            local z=((40+frame)%60)/60.0
            setLightColor(lights[0],config.spotLightColor[1]*1.0*z,config.spotLightColor[2]*1.0*x,config.spotLightColor[3]*1.0*y)
            setLightColor(lights[1],config.pointLightColor[1]*1.0*x,config.pointLightColor[2]*1.0*y,config.pointLightColor[3]*1.0*z)

        else
        setLightColor(lights[0],config.spotLightColor[1]*1.0,config.spotLightColor[2]*1.0,config.spotLightColor[3]*1.0)
        setLightColor(lights[1],config.pointLightColor[1]*1.0,config.pointLightColor[2]*1.0,config.pointLightColor[3]*1.0)
        end

    end
end

sdk.hook(
    sdk.find_type_definition("app.LanternController.LanternLightParam"):get_method("setLightIntensity(System.Single)"),
    function(args) args[3]=light_ptr end,
    nil
)

local function Init()
    SetLightRange()
    SetConsumeNone()    
    light_ptr=sdk.float_to_ptr(config.light)
end
sdk.hook(
    sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),
    nil,
    function()
        Init()
    end
)

re.on_frame(SetLightColorCone)


--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
--On setting Change
local function OnChanged()    
    Init()
end
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,OnChanged) end


--debug
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
        end
    end)
end
