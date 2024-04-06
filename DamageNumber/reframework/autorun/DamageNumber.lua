local modname="DamageNumber"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
    {name="fontsize",type="int",default=60,min=1,max=250,needrestart=true},
    {name="font",type="font",default="times.ttf",needrestart=true},
    {name="color1",type="rgba32",default=0xffEEEEEE,label="Base Color"},
    {name="color11",type="rgba32",default=0xffEEEEEE,label="Enemy Taken Damage Color"},
    {name="color2",type="rgba32",default=0xffEEEEEE,label="Player Taken Damage Color"},
    {name="color3",type="rgba32",default=0xffEEEEEE,label="Big Damage Color"},
    {name="color4",type="rgba32",default=0xff2E9B16,label="DOT&Fall Color"},
    {name="time",type="int",default=120,min=2,max=4000,label="Number Lasting Time"},
    {name="showlefthp",type="bool",default=false,label="Show Left HP"},
    {name="showmultiplier",type="bool",default=true,label="Show Multiplier"},
    {name="showenemydamage",type="bool",default=true,label="Show Damage Taken By Enemy"},
    {name="showfrienddamage",type="bool",default=true,label="Show Damage Taken By Friend"},
    {name="shownonplayerdealandtakendamage",type="bool",default=true,label="Show Non Player Damage"},
    {name="showNonBossEnemyTakenDamage",type="bool",default=true},
    {name="bigcap",type="int",default=1200,min=0,max=1000000,label="Big Cap"},
    {name="ignorecap",type="int",default=-1,min=-1,max=1000000,label="Ignore Cap"},
    {name="rndoffset",type="float",default=0.2,min=0.0,max=10.0,label="Position Random Offset"},
    {name="precisevalue",type="bool",default=false,label="Show Precise Value"},
    {name="showActionRate",type="bool",default=false},
    {name="showDamageType",type="bool",default=false},
    {name="showDOT",type="bool",default=true,label="Show Dot&Fall Damage"},
    {name="showDamageComposition",type="bool",default=false,label="Show Original Damage Composition"},
    {name="showBattleLogOnScreen",type="bool",default=false,label="Show BattleLogOnScreen"},
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

local battleLog={text="",lines=0}
local damageNumbers={}
local mainplayer=nil
local mainplayerGO=nil

local colorDelta=math.floor(0xff000000/(config.time-1))&0xff000000
local posDelta=2/(config.time-1)

local font = imgui.load_font(config.font, config.fontsize)
local jpfont= nil --load when necessary
local bigFont = imgui.load_font(config.font, math.floor(config.fontsize*1.5))

local function Log(msg)
    log.info(modname..msg)
    print(msg)
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


local function printDamageInfo(di)
    local t=di:get_type_definition()
    local fields=t:get_fields()
    for i=1,#fields do
        Log(fields[i]:get_name()..":"..tostring(fields[i]:get_data(di)))
    end
end

local function AddDamageNumber(character,damageInfo)
    local damageNumber={}
    local AttackUserData=damageInfo["<AttackUserData>k__BackingField"]

    if character==nil then
        Log("No Character,try get from <DamageHitController>k__BackingField")
        --printDamageInfo(damageInfo)
        character=damageInfo["<DamageHitController>k__BackingField"]:get_CachedCharacter()
    end
    if character==nil then
        --0 damage and nil character appears,why???
        Log("Still No Character,Ignore")
        if damageInfo.Damage~=0 then
            Log("Ignore None Zero Damage!!")
            --printDamageInfo(damageInfo)
        end
        return
    end
    --local ahc=damageInfo["<AttackHitController>k__BackingField"]
    --local chara2= ahc and ahc:get_CachedCharacter()
    --print(character,character2,mainplayer)
    --dot damage pos is 0,0,0
    damageNumber.pos=damageInfo:get_Position()
    if damageNumber.pos.x==0 and damageNumber.pos.y==0 and damageNumber.pos.z==0 
        and character~=nil then
        damageNumber.pos=getCharacterPos(character)
    end
    
    --treat damage withou AttackUserData as Dot
    --Actuall contains DOT,Fall,etc    
    local isDOT=(AttackUserData==nil)
    --learned from SilverEzredes
    local owner_gameobj = damageInfo and damageInfo["<AttackOwnerObject>k__BackingField"]    
    local isPlayerAttackHit = (owner_gameobj == mainplayerGO)
    local isPlayerTakenHit = (mainplayer == character)
    local isBossTakenHit=character:get_IsBoss()

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

    --Dot don't check conditions about player because always fail
    if isDOT then
        if config.showDOT == false then return end
    else
        if config.shownonplayerdealandtakendamage==false and isPlayerAttackHit==false and isPlayerTakenHit==false then
            return
        end    
        if config.showNonBossEnemyTakenDamage==false and isBossTakenHit==false then
            return
        end
    end

    local isEnemy=character:get_EnemyController():get_IsHostileArisen()
    if isEnemy==true and config.showenemydamage==false then return end
    if config.showfrienddamage==false and isEnemy==false then return end

    damageNumber.msg=f2s(damageInfo.Damage)


    if config.showDamageComposition then
        local msg=""
        if damageInfo.SlashDamage > 0 then msg=msg.." Slash:"..f2s(damageInfo.SlashDamage) end
        if damageInfo.BlowDamage > 0 then msg=msg.." Blow:"..f2s(damageInfo.BlowDamage) end
        if damageInfo.ShootDamage > 0 then msg=msg.." Shoot:"..f2s(damageInfo.ShootDamage) end
        if damageInfo.MagicDamage > 0 then msg=msg.." Magic:"..f2s(damageInfo.MagicDamage) end
        if damageInfo.EnchantDamage > 0 then msg=msg.." Enchant:"..f2s(damageInfo.EnchantDamage) end
        if damageInfo.NonMagicElementDamage > 0 then msg=msg.." NonMagicElement:"..f2s(damageInfo.NonMagicElementDamage) end
        if damageInfo.FixedDamage > 0 then msg=msg.." Fixed:"..f2s(damageInfo.FixedDamage) end
        if msg  ~=nil then
            damageNumber.msg=damageNumber.msg.."/"..msg
        end
    end

    if config.showActionRate and AttackUserData~=nil then
        damageNumber.msg=string.format("%s [%s]",damageNumber.msg, f2s2(AttackUserData.ActionRate))
    end

    -- compare float to 1 seems to be okay?
    if damageInfo.DamageRate ~=1 and config.showmultiplier==true then
        damageNumber.msg=damageNumber.msg.." (x"..f2s2(damageInfo.DamageRate) ..")"
    end

    if config.showDamageType and AttackUserData~=nil then
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
    if isDOT then
        damageNumber.color=config.color4
    elseif damageInfo.Damage > config.bigcap then
        damageNumber.color=config.color3
    elseif isPlayerTakenHit then
        damageNumber.color=config.color2
    elseif isEnemy==true then
        damageNumber.color=config.color11    
    end

    --damageNumber.msg=tostring(ofx).."/"..tostring(ofy)
    if config.showBattleLogOnScreen then
        local log=""
        if isPlayerAttackHit==true then
            log=log.."Player-> :"
        elseif isPlayerTakenHit==true then
            log=log.."->Player :"
        end
        if AttackUserData~=nil then
            log=log..AttackUserData:get_Name()
        end
        log=log..":"..damageNumber.msg
        battleLog.text=battleLog.text..log.."\n"
        battleLog.lines=battleLog.lines+1
    end

    --should match color disappear time
    damageNumbers[damageNumber]=config.time
    Log("Add Damage Number "..tostring(damageNumber.finalDamage).."in("..f2s2(damageNumber.pos.x)..","..f2s2(damageNumber.pos.y)..","..f2s2(damageNumber.pos.z).."): "..damageNumber.msg)
end


--app.Character:onCalcDamageEnd 
--onDamageCalcEnd is shit,onDamageHit don't have damage number
--sdk.find_type_definition("app.PlayerDamageCalculator"):get_method("damageCalcEnd(app.HitController.DamageInfo)"),
sdk.hook(
    --contains DOT
    sdk.find_type_definition("app.HitController"):get_method("updateDamage"),
    function(args)
        local this=sdk.to_managed_object(args[2])
        local damageInfo=sdk.to_managed_object(args[3])        
        --local dn=sdk.to_float(args[5])
        --print(dn)
        AddDamageNumber(this:get_CachedCharacter(),damageInfo)
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
            Log("DamageNumber Disappear "..tostring(k .finalDamage))
            damageNumbers[k]=nil
        end
    end
    imgui.pop_font()
    if config.showBattleLogOnScreen and battleLog.lines>0 then
        if jpfont==nil then
            jpfont=imgui.load_font("BIZ-UDGothicR.ttc",14, {
                                                    0x0020, 0x00FF, -- Basic Latin + Latin Supplement
                                                    0x2000, 0x206F, -- General Punctuation
                                                    0x3000, 0x30FF, -- CJK Symbols and Punctuations, Hiragana, Katakana
                                                    --0xFF00, 0xFFEF, -- Half-width characters
                                                    0x4e00, 0x9FAF, -- CJK Ideograms
                                                    0,
                                                    })
        end
        imgui.push_font(jpfont)
        draw.text(battleLog.text,50,50,0xffffffff)
        if battleLog.lines>100 then
            battleLog.text=""
            battleLog.lines=0
        end
        imgui.pop_font(font)
    end
end)

sdk.hook(
    sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),
    function() end,
    function()
        refreshplayer()
    end
)
refreshplayer()

--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,OnChanged) end
