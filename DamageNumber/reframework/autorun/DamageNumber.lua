local modname="DamageNumber"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
    {name="fontsize",type="int",default=60,min=1,max=250,needrestart=true},
    {name="font",type="font",default="times.ttf",needrestart=true},
    {name="color1",type="rgba32",default=0xffEEEEEE},
    {name="color11",type="rgba32",default=0xffEEEEEE},
    {name="color2",type="rgba32",default=0xffEEEEEE},
    {name="color3",type="rgba32",default=0xffEEEEEE},
    {name="time",type="int",default=120,min=2,max=4000},
    {name="showlefthp",type="bool",default=false},
    {name="showmultiplier",type="bool",default=true},
    {name="showenemydamage",type="bool",default=true},
    {name="showfrienddamage",type="bool",default=true},
    {name="shownonplayerdealandtakendamage",type="bool",default=true},
    {name="bigcap",type="int",default=1200,min=0,max=1000000},
    {name="ignorecap",type="int",default=-1,min=-1,max=1000000},
    {name="rndoffset",type="float",default=0.2,min=0.0,max=10.0},
    {name="precisevalue",type="bool",default=false},
    {name="showActionRate",type="bool",default=false},
    {name="showDamageType",type="bool",default=false},
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
--On setting Change
local function OnChanged()
end


local myLog="LogStart\n"
local damageNumbers={}
local mainplayer=nil
local mainplayerGO=nil

local colorDelta=math.floor(0xff000000/(config.time-1))&0xff000000
local posDelta=2/(config.time-1)

local font = imgui.load_font(config.font, config.fontsize)
local bigFont = imgui.load_font(config.font, math.floor(config.fontsize*1.8))

local function Log(msg)
    myLog = myLog .."\n".. msg
    log.info(modname..msg)
end
local function ClearLog()
    --draw.text(myLog,50,50,0xffEEEEFE)
    myLog = ""
end

local function getCharacterPos(char)
    local joint=char:get_GameObject():get_Transform():getJointByName("Head_0")
    local ground_joint=char:get_GameObject():get_Transform():getJointByName("root")
    -- no head enemy
    if joint == nil then
        return ground_joint:get_Position()        
    end
    --if head is too tall from ground, return the ground
    if joint:get_Position().y - ground_joint:get_Position().y >2 then
        return ground_joint:get_Position()
    end
    return joint:get_Position()
end

local function refreshplayer()
    local player_man=sdk.get_managed_singleton("app.CharacterManager")
    mainplayer=player_man:get_ManualPlayer()
    mainplayerGO=nil
    Log(tostring(player))    
    if mainplayer~=nil then
        mainplayerGO=mainplayer:get_GameObject()
        Log("GetMainPlayerDone")
    end
end

local function f2s(float)
    if config.precisevalue then
        return tostring(float)
    end
    return tostring(math.floor(float))
end

local function f2s2(float)
    if config.precisevalue then
        return tostring(float)
    end
    return string.format("%.2f",float)
end

local function GetEnumMap(enumName)
    local ret={}
    for _,field in pairs(sdk.find_type_definition(enumName):get_fields()) do
        local value=field:get_data()
        if value~=nil and value >0 then
            print(field:get_name())
            ret[value]=field:get_name()
        end
    end
    return ret
end

local PhysicsAttrSettingType2Str=GetEnumMap("app.AttackUserData.PhysicsAttrSettingType")
local DamageTypeEnum2Str=GetEnumMap("app.AttackUserData.DamageTypeEnum")
local ElementTypeEnum2Str=GetEnumMap("app.AttackUserData.ElementType")

local function AddDamageNumber(character,damageInfo)
    local damageNumber={}
    --damageNumber.pos=getCharacterPos(character)
    damageNumber.pos=damageInfo:get_Position()
    --learned from SilverEzredes
    local owner_gameobj = damageInfo and damageInfo["<AttackOwnerObject>k__BackingField"]
    local isPlayerAttackHit = (owner_gameobj == mainplayerGO)
    local isPlayerTakenHit = (mainplayer == character)

    local ofx=(math.random(7)-4)*config.rndoffset
    local ofy=(math.random(7)-4)*config.rndoffset
    damageNumber.pos.x=damageNumber.pos.x+ofx
    damageNumber.pos.y=damageNumber.pos.y+ofy

    damageNumber.finalDamage=damageInfo.Damage    
    damageNumber.bigFont=false
    --damageNumber.def=damageInfo.DamageGuard
    --damageNumber.rate=damageInfo.DamageRate
    --damageNumber.rateMaxHP=damageInfo.MaxHpDamageRate

    if damageInfo.Damage < config.ignorecap then return end
    if config.shownonplayerdealandtakendamage==false and isPlayerAttackHit==false and isPlayerTakenHit==false then
        return
    end

    local isEnemy=character:get_EnemyController():get_IsHostileArisen()
    if isEnemy==true and config.showenemydamage==false then return end
    if config.showfrienddamage==false and isEnemy==false then return end

    damageNumber.msg=f2s(damageInfo.Damage)

    local AttackUserData=damageInfo["<AttackUserData>k__BackingField"]
    if config.showActionRate then
        damageNumber.msg=string.format("%s [%s]",damageNumber.msg, f2s2(AttackUserData.ActionRate))
    end

    -- compare float to 1 seems to be okay?
    if damageInfo.DamageRate ~=1 and config.showmultiplier==true then
        damageNumber.msg=damageNumber.msg.." (x"..f2s2(damageInfo.DamageRate) ..")"
    end

    if config.showDamageType then
        local typeMsg=""
        --print(isPlayerAttackHit,damageInfo.Damage,AttackUserData.DamageValue,AttackUserData.ActionAttackValue,AttackUserData.ActionRate,AttackUserData.AttackType)
        if AttackUserData._ElementType > 0 then
            typeMsg=typeMsg.."/"..ElementTypeEnum2Str[AttackUserData._ElementType]
        end
        if AttackUserData._NonMagicElementType > 0 then
            typeMsg=typeMsg.."/phy"..ElementTypeEnum2Str[AttackUserData._NonMagicElementType]
        end
        if AttackUserData.PhysicsAttrSettingTypeValue > 0 then
            typeMsg=typeMsg.."/"..PhysicsAttrSettingType2Str[AttackUserData.PhysicsAttrSettingTypeValue]
        end
        if AttackUserData.DamageType > 0 then
            typeMsg=typeMsg.."/"..DamageTypeEnum2Str[AttackUserData.DamageType]
        end
        typeMsg=string.gsub(typeMsg,"^/","")
        if typeMsg~="" then
            damageNumber.msg=damageNumber.msg.." {"..typeMsg.."}"
        end
    end

    if damageInfo.Damage > config.bigcap then
        damageNumber.bigFont=true
        damageNumber.msg=damageNumber.msg.." ! "
    end

    if config.showlefthp and character:get_Hp() > 0 then
        damageNumber.msg=damageNumber.msg.." -> "..f2s(character:get_Hp()-damageInfo.Damage)
    end

    damageNumber.color=config.color1
    if damageInfo.Damage > config.bigcap then
        damageNumber.color=config.color3
    elseif isPlayerTakenHit then
        damageNumber.color=config.color2
    elseif isEnemy==true then
        damageNumber.color=config.color11    
    end

    --damageNumber.msg=tostring(ofx).."/"..tostring(ofy)


    --should match color disappear time
    damageNumbers[damageNumber]=config.time
    Log("Add Damage Number "..tostring(damageNumber.finalDamage)..":"..f2s(damageNumber.pos.x).."/"..f2s(damageNumber.pos.y).."/"..f2s(damageNumber.pos.z))
end

local function printDamageInfo(di)
    local msg=""
    local t=di:get_type_definition()
    local fields=t:get_fields()
    for i=1,#fields do
        msg=msg.."\n"..fields[i]:get_name()..":"..tostring(fields[i]:get_data(di))
    end
    return msg
end

sdk.hook(
    --onCalcDamageEnd 
    --onDamageCalcEnd is shit,onDamageHit don't have damage number
    sdk.find_type_definition("app.Character"):get_method("onCalcDamageEnd"),
    function(args)
        local this=sdk.to_managed_object(args[2])
        local di=sdk.to_managed_object(args[3])
        AddDamageNumber(this,di)
        --fix_msg=fix_msg.."\n"..tostring(this:get_Hp())
        --fix_msg=fix_msg.."\n"..printDamageInfo(di)            
    end,
    nil
)

re.on_frame(function()

    imgui.push_font(font)
    for k,v in pairs(damageNumbers) do
        --not work
        --if damageNumber.bigFont then
        --    imgui.push_font(bigFont)
        --end
        draw.world_text(k.msg,k.pos,k.color)
        --if damageNumber.bigFont then
        --    imgui.pop_font()
        --end      

        damageNumbers[k]=v-1
        k.pos.y=k.pos.y+posDelta
        k.color=k.color-colorDelta
        if v == 0 then
            damageNumbers[k]=nil
            Log("DamageNumberDisappear "..tostring(damageNumbers.finalDamage))
        end

        --Log(k.msg.."/"..tostring(v))
    end
    imgui.pop_font()
    ClearLog()
end)



sdk.hook(
    sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),
    function() end,
    function()
        refreshplayer()
    end
)


--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,OnChanged) end
