local modname="[DamageNumber]"

log.info(modname.."Start")
local myLog="LogStart\n"
local damageNumbers={}
local mainplayer=nil
local mainplayerGO=nil

local config = json.load_file("DamageNumber.json") or {}
if config.fontsize==nil then config.fontsize=60 end
if config.font==nil then config.font="times.ttf" end
if config.color1==nil then config.color1=0xffEEEEEE end
if config.color11==nil then config.color11=0xffEEEEEE end
if config.color2==nil then config.color2=0xff990000 end
if config.color3==nil then config.color3=0xffEEEEEE end
if config.time==nil or config.time<2 then config.time=120 end
if config.showlefthp==nil then config.showlefthp=false end
if config.showmultiplier==nil then config.showmultiplier=true end
if config.showenemydamage==nil then config.showenemydamage=true end
if config.showfrienddamage==nil then config.showfrienddamage=true end
if config.shownonplayerdealandtakendamage==nil then config.shownonplayerdealandtakendamage=true end
if config.bigcap==nil then config.bigcap=1200 end
if config.ignorecap==nil then config.ignorecap=-1 end
if config.rndoffset==nil then config.rndoffset=0.2 end


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
    return tostring(math.floor(float))
end

local function f2s2(float)
    return string.format("%.2f",float)
end

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
    -- compare float to 1 seems to be okay?
    if damageInfo.DamageRate ~=1 and config.showmultiplier==true then
        damageNumber.msg=damageNumber.msg.." (x"..f2s2(damageInfo.DamageRate) ..")"
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

        Log(k.msg.."/"..tostring(v))
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
