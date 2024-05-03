local modname="DamageNumber"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
    {name="Style",type="mutualbox"},
    {name="fontsize",type="fontsize",default=60,min=1,max=250,needrestart=true,widthscale=0.4,label="Font Size"},
    {name="",type="sameline"},
    {name="bigfontsize",type="fontsize",default=85,needrestart=true,widthscale=0.4,label="Big Font Size"},
    {name="font",type="font",default="times.ttf",needrestart=true,widthscale=0.4},

    {name="color1",type="rgba32",default=0xffEEEEEE,label="Base Color"},
    {name="",type="sameline"},
    {name="color11",type="rgba32",default=0xffEEEEEE,label="Enemy Taken Damage Color"},
    {name="color3",type="rgba32",default=0xffEEEEEE,label="Big Damage Color"},
    {name="",type="sameline"},
    {name="color2",type="rgba32",default=0xffEEEEEE,label="Player Taken Damage Color"},
    {name="color4",type="rgba32",default=0xff2E9B16,label="DOT&Fall Color"},

    {name="Mode",type="mutualbox"},
    {name="showDamage",type="bool",default=true,label="Show Damage"},
    {name="showKnockdownDamage",type="bool",default=false,label="Show Knockdown Damage!"},
    {name="showDamageReaction",type="bool",default=true,label="Show Shrink/Blown,etc"},

    {name="Form",type="mutualbox"},
    {name="time",type="int",default=120,min=2,max=4000,label="Number Lasting Time"},
    {name="rndoffset",type="float",default=0.2,min=0.0,max=10.0,label="Position Random Offset"},
    
    {name="Damage Format",type="mutualbox"},
    {name="showlefthp",type="bool",default=false,label="Show Left HP"},{name="",type="sameline"},
    {name="showmultiplier",type="bool",default=true,label="Show Multiplier"},{name="",type="sameline"},
    {name="showActionRate",type="bool",default=false,label="Show Action Rate"},
    {name="showDamageType",type="bool",default=false,label="Show Damage Type Flag"},{name="",type="sameline"},
    {name="showDamageComposition",type="bool",default=false,label="Show Original Damage Composition"},{name="",type="sameline"},
    {name="showBigcapPostfix",type="bool",default=true,label="Show ! after big number"},
    {name="precisevalue",type="bool",default=false,label="Show Precise Value"},
    {name="showDamageAtkDefAbsorption",type="bool",default=false,label="Show Final Atk&Def&AbsorptionRate for player's attack"},
    {name="showDamageReactionLevel",type="bool",default=false,label="Show Damage Reaction Level"},
    {name="showHitBodyPart",type="bool",default=false,label="Show Hit Body Part"},

    {name="Damage Filter",type="mutualbox"},
    {name="showenemydamage",type="bool",default=true,label="Show Damage Taken By Enemy"},{name="",type="sameline"},
    {name="showfrienddamage",type="bool",default=true,label="Show Damage Taken By Friend"},
    {name="shownonplayerdealandtakendamage",type="bool",default=true,label="Show Non Player Damage"},{name="",type="sameline"},
    {name="showNonBossEnemyTakenDamage",type="bool",default=true,label="Show Damage Taken By Non-Boss Enemy"},
    {name="showDOT",type="bool",default=true,label="Show Dot&Fall Damage"},
    
    {name="bigcap",type="int",default=1200,min=0,max=1000000,label="Big Cap",widthscale=0.4},
    {name="",type="sameline"},
    {name="ignorecap",type="int",default=-1,min=-1,max=1000000,label="Ignore Cap",widthscale=0.4},

    {name="Other",type="mutualbox"},
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
local damageNumbers={} -- damage number message struct 2 last time
local damageTmpInfos={} -- DamageInfo address 2 middle value struct
local mainplayer=nil
local mainplayerGO=nil
local damageFieldsInDamageInfo={
    ["Slash"]="SlashDamage",
    ["Strike"]="BlowDamage",
    ["Shoot"]="ShootDamage",
    ["Magic"]="MagicDamage",
    ["Enchant"]="EnchantDamage",
    ["NonMagicElement"]="NonMagicElementDamage"
}

local guiManager=sdk.get_managed_singleton("app.GuiManager")

local colorDelta=math.floor(0xff000000/(config.time-1))&0xff000000
local posDelta=2/(config.time-1)

local font = imgui.load_font(config.font, config.fontsize)
local jpfont= nil --load when necessary
local bigfont = imgui.load_font(config.font, config.bigfontsize)

local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end

local function loadJpFont()
    if jpfont==nil then
            jpfont=imgui.load_font("MSMinchoM.TTC",14, {
                                                    0x0020, 0x00FF, -- Basic Latin + Latin Supplement
                                                    0x2000, 0x206F, -- General Punctuation
                                                    0x3000, 0x30FF, -- CJK Symbols and Punctuations, Hiragana, Katakana
                                                    --0xFF00, 0xFFEF, -- Half-width characters
                                                    0x4e00, 0x9FAF, -- CJK Ideograms
                                                    0,
                                                    })
    end
end
loadJpFont()

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
    return tostring(math.floor(float or 0))
end

local function f2s2(float)
    if config.precisevalue then
        return tostring(float)
    end
    return string.format("%.2f",float or 0)
end

local function GetEnumMap(enumName)
    local ret={}
    for _,field in pairs(sdk.find_type_definition(enumName):get_fields()) do
        local value=field:get_data()
        if value~=nil and value >0 then
            --print(field:get_name())
            ret[value]=field:get_name()
        end
    end
    return ret
end

local PhysicsAttrSettingType2Str=GetEnumMap("app.AttackUserData.PhysicsAttrSettingType")
local DamageTypeEnum2Str=GetEnumMap("app.AttackUserData.DamageTypeEnum")
local ElementTypeEnum2Str=GetEnumMap("app.AttackUserData.ElementType")

for k,v in pairs(PhysicsAttrSettingType2Str) do
    if v=="Blow" then PhysicsAttrSettingType2Str[k]="Strike" end
end

local function Common2Message(character,damageInfo,AttackUserData,_msg)
    local msg=_msg
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
        --DamageInfo.DamageActType is passed in CommonDamageReaction and modified by replaceDamageActType(),then decide the damage reaction
        --so final DamageActType is more meaningful than DamageType/DamageTypeLean/DamageTypeBlown in damageinfo or attackuserdata
        --but DamageInfo.DamageActType is setted after updateDamage
        --if damageInfo.DamageActType > 0 then
        --    typeMsg=typeMsg.."/"..DamageTypeEnum2Str[damageInfo.DamageActType]
        --end
        if AttackUserData.DamageTypeLean > 0 then
            typeMsg=typeMsg.."/"..DamageTypeEnum2Str[AttackUserData.DamageTypeLean]
        end
        if AttackUserData.DamageTypeBlown > 0 then
            typeMsg=typeMsg.."/"..DamageTypeEnum2Str[AttackUserData.DamageTypeBlown]
        end

        typeMsg=string.gsub(typeMsg,"^/","")
        if typeMsg~="" then
            msg=msg.." {"..typeMsg.."}"
        end
    end

    if damageInfo.Damage > config.bigcap and config.showBigcapPostfix then
        msg=msg.." ! "
    end

    if config.showHitBodyPart then
        msg=msg.." BodyPart."..tostring(damageInfo.RegionNo).."-"..tostring(damageInfo.RegionStatusNo)
    end
        
    if config.showDamageReactionLevel then
        msg=msg..string.format(" ReactionLv.%d ",damageInfo.DmgReactionLv)
    end
    return msg
end

local function DamageNumber2Message(character,damageInfo,AttackUserData,isPlayerAttackHit)
    local msg=""
    msg=f2s(damageInfo.Damage)

    if config.showDamageComposition then
        local _msg=""
        if damageInfo.SlashDamage > 0 then _msg=_msg.." Slash:"..f2s(damageInfo.SlashDamage) end
        if damageInfo.BlowDamage > 0 then _msg=_msg.." Strike:"..f2s(damageInfo.BlowDamage) end
        if damageInfo.ShootDamage > 0 then _msg=_msg.." Shoot:"..f2s(damageInfo.ShootDamage) end
        if damageInfo.MagicDamage > 0 then _msg=_msg.." Magic:"..f2s(damageInfo.MagicDamage) end
        if damageInfo.EnchantDamage > 0 then _msg=_msg.." Enchant:"..f2s(damageInfo.EnchantDamage).."*"..f2s2(damageInfo.EnchantRate) end
        if damageInfo.NonMagicElementDamage > 0 then _msg=_msg.." NonMagicElement:"..f2s(damageInfo.NonMagicElementDamage) end
        if damageInfo.FixedDamage > 0 then _msg=_msg.." Fixed:"..f2s(damageInfo.FixedDamage) end
        if _msg  ~=nil then
            msg=msg.."/".._msg
        end
    end

    if config.showActionRate and AttackUserData~=nil then
        msg=string.format("%s [%s]",msg, f2s2(AttackUserData.ActionRate))
    end

    -- compare float to 1 seems to be okay?
    if damageInfo.DamageRate ~=1 and config.showmultiplier==true then
        msg=msg.." (x"..f2s2(damageInfo.DamageRate) ..")"
    end

    if config.showDamageAtkDefAbsorption and isPlayerAttackHit then
        local damageTmpInfo=damageTmpInfos[damageInfo:get_address()]
        if damageTmpInfo~=nil then
            for name,field in pairs(damageFieldsInDamageInfo) do
                if damageInfo[field] >0.01 then
                    msg=string.format("%s <%s=(%s-%s)*%s>",msg,name,f2s2(damageTmpInfo[name]),f2s2(damageTmpInfo[name.."_DEF"]),f2s2(damageTmpInfo[name.."_Ab"]))
                end
            end
        end
    end

    msg=Common2Message(character,damageInfo,AttackUserData,msg)

    if config.showlefthp and character:get_Hp() > 0 then
        msg=msg.." -> "..f2s(character:get_Hp()-damageInfo.Damage)
    end
    return msg
end

local function KnockdownNumber2Message(character,damageInfo,AttackUserData,isPlayerAttackHit)
    local msg=""--string.format("(%s/%s/%s)",f2s2(damageInfo.DamageReactionSubBelowThresholdRate),f2s2(damageInfo.DamageReaction),f2s2(AttackUserData.DmgReactionValue))
    local ldamage=damageInfo:get_LeanReaction()
    local bdamage=damageInfo:get_BlownReaction()
    --damage reaction*lean/blownrate is added to enemy in updateDamageReaction,but getReactionDamageType subs the damagereaction*lean/blownrate*DamageReactionSubBelowThresholdRate if this attack doesn't reach knockdown threshold after that.
    --OverThresholdType is set inside getReactionDamageType too
    local postrate=1
    local overthreshold=(damageInfo.OverThresholdType>0)
    if not overthreshold then
        postrate=1-damageInfo.DamageReactionSubBelowThresholdRate
        ldamage=ldamage*postrate
        bdamage=bdamage*postrate
    end

    if ldamage<=config.ignorecap and bdamage<= config.ignorecap then
        return nil
    end

    if ldamage~=bdamage then
        msg=msg..string.format("$L%s/B%s",f2s(ldamage),f2s(bdamage))
    else
        msg=msg..string.format("$%s",f2s(ldamage))
    end

    if config.showActionRate and AttackUserData~=nil then
        msg=string.format("%s [%s]",msg, f2s2(AttackUserData.DmgReactionRate))
    end

    -- compare float to 1 seems to be okay?
    if (damageInfo.LeanReactionRate ~=1 or damageInfo.BlownReactionRate~=1 or postrate~=1) and config.showmultiplier==true then
        if damageInfo.LeanReactionRate==damageInfo.BlownReactionRate then
            msg=msg..string.format(" (x%s)",f2s2(damageInfo.LeanReactionRate))
        else
            msg=msg..string.format(" (Lx%s/Bx%s)",f2s2(damageInfo.LeanReactionRate),f2s2(damageInfo.BlownReactionRate))
        end
        if postrate~=1 then
            msg=msg..string.format(" (ut/x%s)",f2s2(postrate))
        end
    end

    if config.showDamageAtkDefAbsorption and isPlayerAttackHit and mainplayer~=nil then
        local damageTmpInfo=damageTmpInfos[damageInfo:get_address()]
        if damageTmpInfo~=nil and damageTmpInfo["Knockdown_Msg"]~=nil then
            local tmpMsg=damageTmpInfo["Knockdown_Msg"]
            if postrate~=1 then
                tmpMsg=tmpMsg.."xBelowThreshold"..f2s2(postrate)
            end
            msg=string.format("%s <Knockdown=%s>",msg,tmpMsg)
        end
    end
    
    msg=Common2Message(character,damageInfo,AttackUserData,msg)
    return msg
end

local function AddDamageNumber(character,damageInfo,reactionMsg)
    local damageNumber={}
    local AttackUserData=damageInfo["<AttackUserData>k__BackingField"]

    if character==nil then
        Log("No Character,try get from <DamageHitController>k__BackingField")
        character=damageInfo["<DamageHitController>k__BackingField"]:get_CachedCharacter()
    end
    if character==nil then
        --0 damage and nil character appears,why???
        Log("Still No Character,Ignore")
        if damageInfo.Damage~=0 then
            Log("Ignore None Zero Damage!!")
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
    local isEnemy=character:get_EnemyController():get_IsHostileArisen()

    local ofx=(math.random(7)-4)*config.rndoffset
    local ofy=(math.random(7)-4)*config.rndoffset
    damageNumber.pos.x=damageNumber.pos.x+ofx
    damageNumber.pos.y=damageNumber.pos.y+ofy

    if config.showKnockdownDamage then
        damageNumber.pos2=Vector3f.new(damageNumber.pos.x, damageNumber.pos.y+0.3, damageNumber.pos.z)
    end

    damageNumber.finalDamage=damageInfo.Damage    
    damageNumber.bigfont=false

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

    if isEnemy==true and config.showenemydamage==false then return end
    if config.showfrienddamage==false and isEnemy==false then return end

    --Generate damage Message
    if reactionMsg==nil then --damage number
        if config.showDamage then
            damageNumber.msg=DamageNumber2Message(character,damageInfo,AttackUserData,isPlayerAttackHit)
        end
        if config.showKnockdownDamage then
            damageNumber.msg2=KnockdownNumber2Message(character,damageInfo,AttackUserData,isPlayerAttackHit)
        end
    else    --damage reaction Type
        damageNumber.msg=reactionMsg
        damageNumber.pos.y=damageNumber.pos.y+0.6
    end

    --
    if damageInfo.Damage > config.bigcap then
        damageNumber.bigfont=true
    end  
    --Select Color
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
    --BattleLog
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
        if damageNumber.msg~=nil then
            battleLog.text=battleLog.text..log..":"..damageNumber.msg.."\n"
            battleLog.lines=battleLog.lines+1
        end
        if damageNumber.msg2~=nil then
            battleLog.text=battleLog.text..log..":"..damageNumber.msg2.."\n"
            battleLog.lines=battleLog.lines+1
        end

    end

    --should match color disappear time
    damageNumbers[damageNumber]=config.time
    return damageNumber
end

local function AddDamageNumberPost(damageNumber,damageInfo)
    if damageNumber ==nil or damageInfo==nil then return end
    if damageNumber.msg~=nil then
        Log("Add Damage Number "..tostring(damageNumber.finalDamage).."in("..f2s2(damageNumber.pos.x)..","..f2s2(damageNumber.pos.y)..","..f2s2(damageNumber.pos.z).."): ".. damageNumber.msg)
    end
    if damageNumber.msg2~=nil then
        Log("Add Damage Number "..tostring(damageNumber.finalDamage).."in("..f2s2(damageNumber.pos2.x)..","..f2s2(damageNumber.pos2.y)..","..f2s2(damageNumber.pos2.z).."): ".. damageNumber.msg2)
    end
end

local function AddDamageTmpInfoBeforeCalcDef(damageInfo)
    local address=damageInfo:get_address()
    local damageTmpInfo=damageTmpInfos[address] or {lifetime=3}
    damageTmpInfos[address]=damageTmpInfo
    for name,field in pairs(damageFieldsInDamageInfo) do
        damageTmpInfo[name]=damageInfo[field]
    end
end

local function AddDamageTmpInfoAfterCalcDef(damageInfo)
    if damageInfo==nil then return end
    local address=damageInfo:get_address()
    local damageTmpInfo=damageTmpInfos[address]
    if damageTmpInfo==nil then return end
    for name,field in pairs(damageFieldsInDamageInfo) do
        damageTmpInfo[name.."_DEF"]=damageTmpInfo[name]-damageInfo[field]
    end
end

local function AddDamageTmpInfoBeforeCalcAbsorption(damageInfo)
    local address=damageInfo:get_address()
    local damageTmpInfo=damageTmpInfos[address] or {lifetime=3}
    damageTmpInfos[address]=damageTmpInfo
    for name,field in pairs(damageFieldsInDamageInfo) do
        damageTmpInfo[name.."_Ab"]=damageInfo[field]
    end
end

local function AddDamageTmpInfoAfterCalcAbsorption(damageInfo)
    if damageInfo==nil then return end
    local address=damageInfo:get_address()
    local damageTmpInfo=damageTmpInfos[address]
    if damageTmpInfo==nil then return end
    for name,field in pairs(damageFieldsInDamageInfo) do
        damageTmpInfo[name.."_Ab"]=damageInfo[field]/damageTmpInfo[name.."_Ab"]
    end
end


local function AddDamageTmpInfoAfterCalcReactionAttack(playerDamageCalculator,damageInfo)
    if damageInfo==nil then return end
    local address=damageInfo:get_address()
    local damageTmpInfo=damageTmpInfos[address]
    if damageTmpInfo==nil then return end

    local LeftWeapon=sdk.find_type_definition("app.AttackUserData.AttackWeaponTypeEnum"):get_field("LeftWeapon"):get_data()
    local msg=""
    local shellGen=playerDamageCalculator.Human["<ShellInstantiateInfoGenerator>k__BackingField"]
    local playerAttackParameter = nil
    if shellGen ~=nil then
        local humanShellInstantiateInfo =shellGen:getShellInfo(damageInfo)
        playerAttackParameter=humanShellInstantiateInfo and humanShellInstantiateInfo["<AttackParam>k__BackingField"]
    end
    playerAttackParameter = playerAttackParameter or playerDamageCalculator.AttackParam

    local playerAttackDefenceStatus =playerAttackParameter["<Status>k__BackingField"];

    msg="Char"..f2s2(playerAttackDefenceStatus["<Blow>k__BackingField"])
    if playerAttackParameter["<PossessionIncreaseStatus>k__BackingField"] ~= nil then
        msg=msg.."+Possession"..f2s2(playerAttackParameter["<PossessionIncreaseStatus>k__BackingField"]._Blow/10.0)
    end
    if playerAttackDefenceStatus["<ArmorReactionAttack>k__BackingField"] ~=0 then
        msg=msg.."+Armor"..f2s2(playerAttackDefenceStatus["<ArmorReactionAttack>k__BackingField"])
    end

    local attackUserData = damageInfo["<AttackUserData>k__BackingField"]
    local weaponAttack=0
    if attackUserData.AttackWeaponTypeAttackValue < LeftWeapon then
        weaponAttack = playerAttackDefenceStatus["<RightWeaponReactionAttack>k__BackingField"];
    elseif attackUserData.AttackWeaponTypeAttackValue == LeftWeapon then
        weaponAttack = playerAttackDefenceStatus["<LeftWeaponReactionAttack>k__BackingField"];
    end
    if weaponAttack ~=0 then
        msg=msg.."+Weapon"..f2s2(weaponAttack)
    end
    msg=string.format("(%s)",msg)
    local changed=false
    if playerAttackDefenceStatus["<BlowFactor>k__BackingField"]~=1 then
        msg=msg.."xCharAtkMulti"..f2s2(playerAttackDefenceStatus["<BlowFactor>k__BackingField"])
        changed=true
    end
    if attackUserData.ActionDmgReactionValue ~=0 then
        msg=msg.."+ActFix"..f2s2(attackUserData.ActionDmgReactionValue)
        changed=true
    end
    if changed then msg=string.format("(%s)",msg) end
    changed=false

    if attackUserData.DmgReactionRate~=1 then
        msg=msg.."xActionRate"..f2s2(attackUserData.DmgReactionRate)        
    end

    if damageInfo.PhysicsCorrectionRateReaction~=1 then
        msg=msg.."xPhy"..f2s2(damageInfo.PhysicsCorrectionRateReaction)        
    end
    if playerAttackDefenceStatus["<ReactionAttackMultipleFactor>k__BackingField"]~=1 then
        msg=msg.."xCharMulti"..f2s2(playerAttackDefenceStatus["<ReactionAttackMultipleFactor>k__BackingField"])        
    end
    if playerAttackDefenceStatus["<ReactionAttackAddFactor>k__BackingField"]~=0 then
        msg=msg.."+CharAdd"..f2s2(playerAttackDefenceStatus["<ReactionAttackAddFactor>k__BackingField"])        
    end

    damageTmpInfo["Knockdown_Msg"]=msg
    damageTmpInfo["Knockdown_ATK"]=damageInfo.DamageReaction
end

local function AddDamageTmpInfoAfterCalcReaction(damageInfo)
    if damageInfo==nil then return end
    local address=damageInfo:get_address()
    local damageTmpInfo=damageTmpInfos[address]
    if damageTmpInfo==nil then return end
    if damageTmpInfo["Knockdown_ATK"]==nil or damageTmpInfo["Knockdown_ATK"]==0 then return end
    damageTmpInfo["Knockdown_Msg"]=string.format("(%s)xAbsorption%s",damageTmpInfo["Knockdown_Msg"],f2s2(damageInfo.DamageReaction/damageTmpInfo["Knockdown_ATK"]))
end

--app.Character:onCalcDamageEnd 
--onDamageCalcEnd is shit,onDamageHit don't have damage number
--sdk.find_type_definition("app.PlayerDamageCalculator"):get_method("damageCalcEnd(app.HitController.DamageInfo)"),
local tmpUpdateDamageDamageInfo=nil
local tmpUpdateDamageHitController=nil
sdk.hook(
    --contains DOT
    sdk.find_type_definition("app.HitController"):get_method("updateDamage"),
    function(args)
        local this=sdk.to_managed_object(args[2])
        local damageInfo=sdk.to_managed_object(args[3])
        tmpUpdateDamageDamageInfo=damageInfo
        tmpUpdateDamageHitController=this
    end,
    function()
        local tmpUpdateDamageDamageNumber=AddDamageNumber(tmpUpdateDamageHitController:get_CachedCharacter(),tmpUpdateDamageDamageInfo)
        AddDamageNumberPost(tmpUpdateDamageDamageNumber,tmpUpdateDamageDamageInfo)        
        tmpUpdateDamageDamageInfo=nil
        tmpUpdateDamageDamageNumber=nil
    end
)

--(player's) attack is calced in PlayerDamageCalculator and set to DamageInfo.xxdamage,then minused by defence in ExceptPlayerDamageCalculator.calcDamageValueDefence
--thread.get_hook_storage()'s bug is fixed recently.But I don't believe users know how to update.So not using thread.
local tmpDamageInfoArg=nil
sdk.hook(
    sdk.find_type_definition("app.ExceptPlayerDamageCalculator"):get_method("calcDamageValueDefence(app.HitController.DamageInfo)"),
    function(args)
        if config.showDamageAtkDefAbsorption and config.showDamage then
            local damageInfo =sdk.to_managed_object(args[3])
            AddDamageTmpInfoBeforeCalcDef(damageInfo)
            tmpDamageInfoArg=damageInfo
        end
    end,
    function()
        if config.showDamageAtkDefAbsorption and config.showDamage then
            AddDamageTmpInfoAfterCalcDef(tmpDamageInfoArg)
        end
        tmpDamageInfoArg=nil
    end
)

local tmpDamageInfoArg2=nil
local tmpDamageInfoArg2this=nil
sdk.hook(
    sdk.find_type_definition("app.PlayerDamageCalculator"):get_method("calcDamageRactionValueAttack(app.HitController.DamageInfo)"),
    function(args)
        if config.showDamageAtkDefAbsorption and config.showKnockdownDamage then
            tmpDamageInfoArg2=sdk.to_managed_object(args[3])
            tmpDamageInfoArg2this=sdk.to_managed_object(args[2])
        end
    end,
    function()
        if config.showDamageAtkDefAbsorption and config.showKnockdownDamage and tmpDamageInfoArg2 ~=nil then
            AddDamageTmpInfoAfterCalcReactionAttack(tmpDamageInfoArg2this,tmpDamageInfoArg2)
        end
        tmpDamageInfoArg2this=nil
        tmpDamageInfoArg2=nil
end)

local tmpDamageInfoArg3=nil
sdk.hook(
    sdk.find_type_definition("app.HitController"):get_method("calcRegionDamageRate(app.HitController.DamageInfo)"),
    function(args)
        if config.showDamageAtkDefAbsorption then
            local damageInfo =sdk.to_managed_object(args[3])
            AddDamageTmpInfoBeforeCalcAbsorption(damageInfo)
            tmpDamageInfoArg3=damageInfo
        end
    end,
    function()
        if config.showDamageAtkDefAbsorption then
            AddDamageTmpInfoAfterCalcAbsorption(tmpDamageInfoArg3)
        end
        tmpDamageInfoArg3=nil
    end
)
local tmpDamageInfoArg4=nil
sdk.hook(sdk.find_type_definition("app.HitController"):get_method("calcDamageReaction"),
    function(args)
        if config.showDamageAtkDefAbsorption and config.showKnockdownDamage then
            tmpDamageInfoArg4=sdk.to_managed_object(args[3])
        end
    end,
    function ()
        if config.showDamageAtkDefAbsorption and config.showKnockdownDamage and tmpDamageInfoArg4 ~=nil then
            AddDamageTmpInfoAfterCalcReaction(tmpDamageInfoArg4)
        end
        tmpDamageInfoArg4=nil
end)


local function onDamageReactionTriggered(args,msg)
    local this=sdk.to_managed_object(args[2])
    if not config.showDamageReaction then return end
    local damageInfo=this["<DamageInfo>k__BackingField"]
    if damageInfo.DamageType>0 then
        local hitDamageType=DamageTypeEnum2Str[damageInfo.DamageActType]
        hitDamageType=string.gsub(hitDamageType,"Hitback_","")
        hitDamageType=string.gsub(hitDamageType,"Blown_","")
        --hitDamageType=string.gsub(hitDamageType,"Hitdown","")
        
    local AttackUserData=damageInfo["<AttackUserData>k__BackingField"]
        msg =msg.."("..hitDamageType..")!"
    end
    AddDamageNumber(this["<Chara>k__BackingField"],damageInfo,msg)
end

sdk.hook(
    sdk.find_type_definition("app.CommonDamageReaction"):get_method("selectDamageActionShrink"),
    function(args)
        onDamageReactionTriggered(args,"Shrink")
    end,
    nil
)
sdk.hook(
    sdk.find_type_definition("app.CommonDamageReaction"):get_method("selectDamageActionHitdown"),
    function(args)
        onDamageReactionTriggered(args,"Hitdown")
    end,
    nil
)
sdk.hook(
    sdk.find_type_definition("app.CommonDamageReaction"):get_method("selectDamageActionBlown"),
    function(args)
        onDamageReactionTriggered(args,"Blown")
    end,
    nil
)
sdk.hook(
    sdk.find_type_definition("app.CommonDamageReaction"):get_method("selectDamageActionLargeCharaDown"),
    function(args)
        onDamageReactionTriggered(args,"Down")
    end,
    nil
)
local function DrawDamageNumber(damageNumber)
    if damageNumber.msg~=nil then
        draw.world_text(damageNumber.msg,damageNumber.pos,damageNumber.color)
    end
    if damageNumber.msg2~=nil then
        draw.world_text(damageNumber.msg2,damageNumber.pos2,damageNumber.color)
    end
    damageNumbers[damageNumber]=damageNumbers[damageNumber]-1
    damageNumber.pos.y=damageNumber.pos.y+posDelta
    if damageNumber.pos2~=nil then 
        damageNumber.pos2.y=damageNumber.pos2.y+posDelta
    end
    damageNumber.color=damageNumber.color-colorDelta
    if damageNumbers[damageNumber] == 0 then
        --Log("DamageNumber Disappear "..tostring(damageNumber.finalDamage))
        damageNumbers[damageNumber]=nil
    end    
end

local frame_ct=0
re.on_frame(function()
    frame_ct=frame_ct+1
    --draw damage numbers
    imgui.push_font(font)
    for k,v in pairs(damageNumbers) do
        if k.bigfont==nil or k.bigfont==false then
            DrawDamageNumber(k)
        end
    end
    imgui.pop_font()

    imgui.push_font(bigfont)
    for k,v in pairs(damageNumbers) do
        if k.bigfont then            
            DrawDamageNumber(k)
        end
    end
    imgui.pop_font()
    
    --clear damageTmpInfos 
    if frame_ct>30 then
        frame_ct=0
        for k,v in pairs(damageTmpInfos) do
            v.lifetime=v.lifetime-1
            if v.lifetime<0 then damageTmpInfos[k]=nil end
        end
    end

    --Draw battlelog
    if config.showBattleLogOnScreen and battleLog.lines>0 then
        loadJpFont()
        imgui.push_font(jpfont)
        draw.text(battleLog.text,50,50,0xffffffff)
        if battleLog.lines>100 then
            battleLog.text=""
            battleLog.lines=0
        end
        imgui.pop_font(font)
    end
end)

sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),nil,refreshplayer)
refreshplayer()

--try load api and draw ui
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,OnChanged) end

