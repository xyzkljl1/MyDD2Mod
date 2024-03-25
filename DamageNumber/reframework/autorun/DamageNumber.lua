local modname="[DamageNumber]"

log.info(modname.."Start")
local myLog="LogStart\n"
local damageNumbers={}
local mainplayer=nil

local config = json.load_file("DamageNumber.json") or {}
if config.fontsize==nil then config.fontsize=60 end
if config.color1==nil then config.color1=0xffEEEEEE end
if config.color2==nil then config.color2=0xff990000 end
if config.time==nil or config.time<2 then config.time=120 end
if config.showlefthp==nil then config.showlefthp=false end
if config.bigcap==nil then config.bigcap=1200 end

local colorDelta=math.floor(0xff000000/(config.time-1))&0xff000000
local posDelta=2/(config.time-1)

local font = imgui.load_font("times.ttf", config.fontsize)
local bigFont = imgui.load_font("times.ttf", math.floor(config.fontsize*1.8))

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
    --if head is too tall from ground, return the ground
    if joint:get_Position().y - ground_joint:get_Position().y >2 then
        return ground_joint:get_Position()
    end
    return joint:get_Position()
end

local function getplayer()
    local player_man=sdk.get_managed_singleton("app.CharacterManager")
    local player=player_man:get_ManualPlayer()
    Log(tostring(player))
    return player
end

local function f2s(float)
    return tostring(math.floor(float))
end

local function f2s2(float)
    return string.format("%.2f",float)
end


mainplayer=getplayer()
local function AddDamageNumber(character,damageInfo)
    damageNumber={}
    damageNumber.pos=getCharacterPos(character)
    damageNumber.finalDamage=damageInfo.Damage    
    damageNumber.bigFont=false
    --damageNumber.def=damageInfo.DamageGuard
    --damageNumber.rate=damageInfo.DamageRate
    --damageNumber.rateMaxHP=damageInfo.MaxHpDamageRate

    damageNumber.msg=f2s(damageInfo.Damage)
    -- compare float to 1 seems to be okay?
    if damageInfo.DamageRate ~=1 then
        damageNumber.msg=damageNumber.msg.." (x"..f2s2(damageInfo.DamageRate) ..")"
    end

    if damageInfo.Damage > config.bigcap then
        damageNumber.bigFont=true
        damageNumber.msg=damageNumber.msg.." ! "
    end

    if config.showlefthp then
        damageNumber.msg=damageNumber.msg.." -> "..f2s(character:get_Hp()-damageInfo.Damage)
    end


    damageNumber.color=config.color1
    if mainplayer == character then
        damageNumber.color=config.color2
    end

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

        Log(k.msg.."/"..tostring(v))
    end
    imgui.pop_font()
    ClearLog()
end)



sdk.hook(
    sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),
    function() end,
    function()
        mainplayer=getplayer()
        if mainplayer~=nil then
            Log("GetMainPlayerDone")
        end
    end
)
