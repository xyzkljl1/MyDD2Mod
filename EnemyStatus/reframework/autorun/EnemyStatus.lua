local modname="EnemyStatus"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
    {name="Style",type="mutualbox"},
    {name="fontsize",type="fontsize",default=30,min=1,max=250,needrestart=true,widthscale=0.4,label="Font Size"},
    {name="font",type="font",default="times.ttf",needrestart=true,widthscale=0.4},
    {name="color",type="rgba32",default=0xffEEEEEE,label="Text Color"},
    {name="backgroundcolor",type="rgba32",default=0x77777777,label="Back Ground Color"},
    {name="Display",type="mutualbox"},
    {name="enable",type="bool",default=true},
    {name="position",type="intN",default={20,500},min=-300,max=8000},

    {name="Filter",type="mutualbox"},
    {name="onlyboss",type="bool",default=false},
    
    {name="Format",type="mutualbox"},
    {name="showWeakpoint",type="bool",default=true},
    {name="showBodyParts",type="bool",default=true},
    {name="showDebuff",type="bool",default=true},
    {name="showATKDEF",type="bool",default=true},
    {name="showPhysicDamageAbsorption",type="bool",default=true},
    {name="showMagicDamageAbsorption",type="bool",default=true},
    {name="showKnockdownAbsorption",type="bool",default=true},
    {name="showPhysicKnockdownAbsorption",type="bool",default=false},
    {name="showMagicKnockdownAbsorption",type="bool",default=false},

    {name="Hotkey",type="mutualbox"},
    {name="switchEnable",type="hotkey",default="Alpha5",actionName="switchEnableEnemyStatus19054u3"},
}  
local hk = require("Hotkeys/Hotkeys")
local myapi = require("_XYZApi/_XYZApi")
local config= myapi.InitFromFile(_config,configfile)

local mainplayer=nil
local mainplayerGO=nil
local enemyCache={count=0}
local lastEnemy=nil
local guiManager=sdk.get_managed_singleton("app.GuiManager")

local font = imgui.load_font(config.font, config.fontsize)

--from shadowcookie
local charaID2EnemyName={
    ["ch221002_00"]="Rattler",
    ["ch224000_00"]="Slime",
    ["ch250000_10"]="Cyclops",
    ["ch250000_02"]="Cyclops",
    ["ch250000_21"]="Cyclops",
    ["ch299003_A_40"]="Ox",
    ["ch253001_00"]="Sphinx",
    ["ch230000"]="Rogue",
    ["ch299030_A_00"]="Pig",
    ["ch223002"]="Blackdog",
    ["ch259000_00"]="Talos",
    ["ch220003_01"]="Knacker",
    ["ch299240"]="Spider",
    ["ch224001"]="Ooze",
    ["ch226003_00"]="Skeleton Lord",
    ["ch299410"]="Crow",
    ["ch253010_00"]="Vermund Purgener",
    ["ch230002_02"]="Lost Mercenary",
    ["ch255011"]="Volcanic Island Purgener",
    ["ch258000_30"]="Dragon",
    ["ch254001"]="Gorechimera",
    ["ch230002_05"]="Lost Mercenary",
    ["ch230002_04"]="Lost Mercenary",
    ["ch224001_00"]="Ooze",
    ["ch258000"]="Dragon",
    ["ch299220_A_00"]="Rooster",
    ["ch230012"]="Coral Snake",
    ["ch226000_00"]="Skeleton",
    ["ch252000_02"]="Golem",
    ["ch299003_A_31"]="Ox",
    ["ch220002_02"]="Chopper",
    ["ch221000_00"]="Saurian",
    ["ch230001_05"]="Lost Mercenary",
    ["ch250000_01"]="Cyclops",
    ["ch299020_B_00"]="Goat",
    ["ch220001_11"]="Hobgoblin",
    ["ch250000"]="Cyclops",
    ["ch220000_10"]="Goblin",
    ["ch230000_03"]="Rogue",
    ["ch226002"]="Skeleton",
    ["ch226003"]="Skeleton Lord",
    ["ch220003"]="Knacker",
    ["ch299031_B_00"]="Wild Boar",
    ["ch222003_20"]="Succubus",
    ["ch230001_06"]="Lost Mercenary",
    ["ch220001_12"]="Hobgoblin",
    ["ch220001_20"]="Hobgoblin",
    ["ch223002_00"]="Blackdog",
    ["ch230012_02"]="Coral Snake",
    ["ch224002"]="Sludge",
    ["ch255000"]="Medusa",
    ["ch253010"]="Vermund Purgener",
    ["ch255011_00"]="Volcanic Island Purgener",
    ["ch230000_01"]="Rogue",
    ["ch220001_23"]="Hobgoblin",
    ["ch226001_03"]="Skeleton",
    ["ch256001_00"]="Goreminotaur",
    ["ch228002_00"]="Stout Undead",
    ["ch299003_A_51"]="Ox",
    ["ch230000_04"]="Rogue",
    ["ch299230_A_00"]="Leapworm",
    ["ch222003"]="Succubus",
    ["ch225002_00"]="Specter",
    ["ch226002_05"]="Skeleton",
    ["ch228002"]="Stout Undead",
    ["ch228000_00"]="Undead",
    ["ch229000_00"]="Dullahan",
    ["ch299221_A_00"]="Chicken",
    ["ch258001"]="Nex",
    ["ch299010"]="Stag",
    ["ch299200_A_00"]="Rabbit",
    ["ch260000_00"]="Garm",
    ["ch258000_00"]="Dragon",
    ["ch257000_00"]="Drake",
    ["ch220000_02"]="Goblin",
    ["ch299003_A_50"]="Ox",
    ["ch299003_A_22"]="Ox",
    ["ch230000_02"]="Rogue",
    ["ch252000"]="Golem",
    ["ch250000_90"]="Cyclops",
    ["ch299430"]="Bird",
    ["ch228000"]="Undead",
    ["ch299003_A_61"]="Ox",
    ["ch230001_01"]="Lost Mercenary",
    ["ch220000_03"]="Goblin",
    ["ch251001"]="Grim Ogre",
    ["ch223001_00"]="Redwolf",
    ["ch254000_00"]="Chimera",
    ["ch226000"]="Skeleton",
    ["ch254000"]="Chimera",
    ["ch252000_03"]="Golem",
    ["ch259000_91"]="Talos",
    ["ch299210"]="Rat",
    ["ch220001_13"]="Hobgoblin",
    ["ch220001_10"]="Hobgoblin",
    ["ch230002_03"]="Lost Mercenary",
    ["ch299210_A_00"]="Rat",
    ["ch250000_11"]="Cyclops",
    ["ch251000_00"]="Ogre",
    ["ch299620"]="Grasshopper",
    ["ch222003_00"]="Succubus",
    ["ch220001"]="Hobgoblin",
    ["ch299610_A_00"]="Butterfly",
    ["ch220001_01"]="Hobgoblin",
    ["ch254100"]="Chimera",
    ["ch260001"]="Warg",
    ["ch250000_00"]="Cyclops",
    ["ch225001_00"]="Phantasm",
    ["ch299240_A_00"]="Spider",
    ["ch222000_00"]="Harpy",
    ["ch260001_00"]="Warg",
    ["ch299003_A_90"]="Ox",
    ["ch220000_04"]="Goblin",
    ["ch228001_00"]="Undead",
    ["ch256000_00"]="Minotaur",
    ["ch227001"]="Wight",
    ["ch220001_21"]="Hobgoblin",
    ["ch299003_A_14"]="Ox",
    ["ch299003_A_12"]="Ox",
    ["ch256001"]="Goreminotaur",
    ["ch230001_04"]="Lost Mercenary",
    ["ch254101_00"]="Gorechimera",
    ["ch299031_A_00"]="Wild Boar",
    ["ch220003_03"]="Knacker",
    ["ch223001_01"]="Redwolf",
    ["ch230002_06"]="Lost Mercenary",
    ["ch220000_91"]="Goblin",
    ["ch250000_22"]="Cyclops",
    ["ch225000_00"]="Phantom",
    ["ch299200_B_00"]="Rabbit",
    ["ch259000_90"]="Talos",
    ["ch230001"]="Lost Mercenary",
    ["ch226001_06"]="Skeleton",
    ["ch222001"]="Venin Harpy",
    ["ch220000_90"]="Goblin",
    ["ch221003"]="Magma Scale",
    ["ch255010"]="Sacred Arbor Purgener",
    ["ch253000_00"]="Griffin",
    ["ch251001_00"]="Grim Ogre",
    ["ch259000"]="Talos",
    ["ch220000_12"]="Goblin",
    ["ch254001_00"]="Gorechimera",
    ["ch260000"]="Garm",
    ["ch299011_A_00"]="Doe",
    ["ch299003_A_00"]="Ox",
    ["ch299031"]="Wild Boar",
    ["ch299221"]="Chicken",
    ["ch299020_A_00"]="Goat",
    ["ch222002"]="Gore Harpy",
    ["ch227000"]="Lich",
    ["ch258001_00"]="Nex",
    ["ch299003"]="Ox",
    ["ch299430_A_00"]="Bird",
    ["ch299420_A_00"]="Seabird",
    ["ch299620_A_00"]="Grasshopper",
    ["ch299003_A_13"]="Ox",
    ["ch226000_01"]="Skeleton",
    ["ch252000_01"]="Golem",
    ["ch299003_A_15"]="Ox",
    ["ch299030"]="Pig",
    ["ch299003_A_20"]="Ox",
    ["ch221004_00"]="Serpent",
    ["ch253011_00"]="Island Encampment Purgener",
    ["ch221001_00"]="Asp",
    ["ch299011"]="Doe",
    ["ch255000_01"]="Medusa",
    ["ch299003_A_10"]="Ox",
    ["ch221003_00"]="Magma Scale",
    ["ch227000_00"]="Lich",
    ["ch299600"]="Fish",
    ["ch299200"]="Rabbit",
    ["ch258000_20"]="Dragon",
    ["ch299003_B_00"]="Ox",
    ["ch254101"]="Gorechimera",
    ["ch255000_90"]="Medusa",
    ["ch254201_00"]="Gorechimera",
    ["ch222000"]="Harpy",
    ["ch220000"]="Goblin",
    ["ch299003_A_21"]="Ox",
    ["ch257001_00"]="Lesser Dragon",
    ["ch240000"]="Battahl Purgener",
    ["ch255010_00"]="Sacred Arbor Purgener",
    ["ch221000"]="Saurian",
    ["ch299410_A_00"]="Crow",
    ["ch250000_20"]="Cyclops",
    ["ch226002_06"]="Skeleton",
    ["ch230001_02"]="Lost Mercenary",
    ["ch220001_03"]="Hobgoblin",
    ["ch223000_00"]="Wolf",
    ["ch230012_04"]="Coral Snake",
    ["ch255000_00"]="Medusa",
    ["ch220001_22"]="Hobgoblin",
    ["ch220000_00"]="Goblin",
    ["ch221002"]="Rattler",
    ["ch254100_00"]="Chimera",
    ["ch299003_A_30"]="Ox",
    ["ch253011"]="Island Encampment Purgener",
    ["ch220003_02"]="Knacker",
    ["ch226002_03"]="Skeleton",
    ["ch220000_01"]="Goblin",
    ["ch299003_A_11"]="Ox",
    ["ch220003_00"]="Knacker",
    ["ch258000_10"]="Dragon",
    ["ch220002_03"]="Chopper",
    ["ch227001_00"]="Wight",
    ["ch229000"]="Dullahan",
    ["ch253000"]="Griffin",
    ["ch252000_00"]="Golem",
    ["ch299600_A_00"]="Fish",
    ["ch220000_13"]="Goblin",
    ["ch226001_01"]="Skeleton",
    ["ch230100"]="Scavenger",
    ["ch299220"]="Rooster",
    ["ch230002"]="Lost Mercenary",
    ["ch250000_12"]="Cyclops",
    ["ch220002_01"]="Chopper",
    ["ch251000"]="Ogre",
    ["ch230002_01"]="Lost Mercenary",
    ["ch299420"]="Seabird",
    ["ch222002_00"]="Gore Harpy",
    ["ch228001"]="Undead",
    ["ch225002"]="Specter",
    ["ch299610"]="Butterfly",
    ["ch226002_01"]="Skeleton",
    ["ch220001_00"]="Hobgoblin",
    ["ch221002_20"]="Rattler",
    ["ch220000_11"]="Goblin",
    ["ch220002"]="Chopper",
    ["ch253001"]="Sphinx",
    ["ch230001_03"]="Lost Mercenary",
    ["ch256000"]="Minotaur",
    ["ch299400"]="Bat",
    ["ch228001_01"]="Undead",
    ["ch223000"]="Wolf",
    ["ch226001"]="Skeleton",
    ["ch222001_00"]="Venin Harpy",
    ["ch226001_05"]="Skeleton",
    ["ch254200_00"]="Chimera",
    ["ch223001"]="Redwolf",
    ["ch225001"]="Phantasm",
    ["ch299400_A_00"]="Bat",
    ["ch299230"]="Leapworm",
    ["ch240000_00"]="Battahl Purgener",
    ["ch299003_A_91"]="Ox",
    ["ch299020"]="Goat",
    ["ch221004"]="Serpent",
    ["ch224000"]="Slime",
    ["ch228000_01"]="Undead",
    ["ch254201"]="Gorechimera",
    ["ch230100_04"]="Scavenger",
    ["ch225000"]="Phantom",
    ["ch220001_02"]="Hobgoblin",
    ["ch257001"]="Lesser Dragon",
    ["ch224002_00"]="Sludge",
    ["ch299003_A_32"]="Ox",
    ["ch299010_A_00"]="Stag",
    ["ch299003_A_52"]="Ox",
    ["ch299003_A_62"]="Ox",
    ["ch257000"]="Drake",
    ["ch220000_14"]="Goblin",
    ["ch254200"]="Chimera",
    ["ch299003_A_60"]="Ox",
    ["ch220002_00"]="Chopper",
    ["ch221001"]="Asp"
}

for k,v in pairs(charaID2EnemyName) do
    local pos=string.find(k,"_")
    --print("find",k,v,pos)
    if pos~=nil then
        charaID2EnemyName[k]=v..string.sub(k,pos,k:len())
        --print("find2",k,string.sub(k,pos,k:len()),pos,k:len()-pos,charaID2EnemyName[k])
    end
end

local function Log(msg)
    log.info(modname..msg)
    print(msg)
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
    return string.format("%.2f",float)
end

local function Enum2Map(typeName,from)
    from=from or 1
    local id2name={}
    local name2id={}
    local fields=sdk.find_type_definition(typeName):get_fields()
    for _,field in pairs(fields) do
        local value=field:get_data()
        if value~=nil and value >= from and id2name[value]==nil then
            id2name[value]=field:get_name()
            name2id[field:get_name()]=value
            --print(field:get_name(),value)
        end
    end
    return id2name,name2id
end
local function GetWeakpointEnumMap()
    local type=sdk.find_type_definition("app.CharacterDamageCalculator.CharacterWeakpointType")
    local enum2str={}
    local max=0
    for _,field in pairs(type:get_fields()) do
        local value=field:get_data()
        if value~=nil and value >0 then
            --print(field:get_name())
            enum2str[value]=field:get_name()
            if max<value then max=value end
        end
    end
    local ret={}
    --8=None,and 0 doesn't have define
    --goblin resist None(8),and take 100% slash damage ,so None can't be "all damage"
    --Skeleton resist 125,containt None/Slash,etc.Take 70% Slash damage.
    --some monster resist 0
    --what the hell does None mean?
    for i=1,math.min(max*2-1,2048) do
        local str=""
        for k,v in pairs(enum2str) do
            if i & k~=0 then
                if str~="" then str=str.."|" end
                str=str..v
            end
        end
        ret[i]=str
    end
    ret[0]="-"
    return ret
end

local ElementTypeEnum2Str,_=Enum2Map("app.AttackUserData.ElementType")
local StatusConditionEnum2Str,_=Enum2Map("app.StatusConditionDef.StatusConditionEnum")
local RegionTypeEnum2Str,_=Enum2Map("app.IntermediateRegionParam.RegionTypeEnum",0)
local DamageTypeEnum2Str,_=Enum2Map("app.AttackUserData.DamageTypeEnum",0)

local WeakpointEnum2Str=GetWeakpointEnumMap()

local function SetEnemyCache(damageCalculator)
    local ch2=damageCalculator:get_Ch2()
    local character=ch2:get_Chara()
    if character==nil or ch2==nil then return end

    local isBossTakenHit=character:get_IsBoss()
    local isEnemy=character:get_EnemyController():get_IsHostileArisen()

    --Record enemy,before ignorecap
    if isEnemy and (isBossTakenHit or not config.onlyboss) then
        Log("SetCache")
        if enemyCache[character] == nil then 
            enemyCache.count=enemyCache.count+1
            if enemyCache.count>2000 then
                enemyCache={count=1}-- clear all,cause this is rare case.
            end
        end
        enemyCache[character]={
            character=character,
            gameobject=character:get_GameObject(),
            hitController=character:get_Hit(),
            calculator=damageCalculator,
        }
    end
end

local function SetEnemy(character,damageInfo)
    if character==nil then return end
    local owner_gameobj =damageInfo and damageInfo["<AttackOwnerObject>k__BackingField"]
    local isPlayerAttackHit = (owner_gameobj == mainplayerGO)

    local isBossTakenHit=character:get_IsBoss()
    local isEnemy=character:get_EnemyController():get_IsHostileArisen()

    --Record enemy,before ignorecap
    if isPlayerAttackHit and isEnemy and (isBossTakenHit or not config.onlyboss)then
        Log("SetEnemy")
        lastEnemy=character
    end
end


sdk.hook(
    sdk.find_type_definition("app.ExceptPlayerDamageCalculator"):get_method("calcDamageValueDefence"),
    function (args)
        local this=sdk.to_managed_object(args[2])
        SetEnemyCache(this)
    end,
    nil
)

sdk.hook(
    --contains DOT
    sdk.find_type_definition("app.HitController"):get_method("updateDamage"),
    function(args)
        local this=sdk.to_managed_object(args[2])
        local damageInfo=sdk.to_managed_object(args[3])
        if damageInfo.Damage >0 then
            SetEnemy(this:get_CachedCharacter(),damageInfo)
        end
    end,
    nil
)

re.on_frame(function()
    if hk.check_hotkey("switchEnableEnemyStatus19054u3",false,true) then
        config.enable=not config.enable
    end
    --Draw meter
    --Dont use get_IsNoDie
    if config.enable and (false or guiManager:get_IsLoadGui()==false) and lastEnemy~=nil and enemyCache[lastEnemy]~=nil then
        local lastEnemyHitController=enemyCache[lastEnemy].hitController
        local lastEnemyGO=enemyCache[lastEnemy].gameobject
        local lastEnemyCalculator=enemyCache[lastEnemy].calculator
        local lastEnemyCharacter=lastEnemy
        if lastEnemyGO~=nil and lastEnemyGO:get_Valid()==true and lastEnemyGO:get_DrawSelf() and lastEnemyHitController:get_IsDie()==false then
            imgui.push_font(font)
            local msg=""
            local bodyparts=lastEnemyHitController.RegionData

            --CharaName HP
            local charaName=lastEnemyCharacter:get_CharaIDString()
            local charaName= charaID2EnemyName[charaName] or charaName
            local hp=lastEnemyCharacter:get_Hp()
            msg=msg..charaName..string.format("    %s/%s\n",f2s(lastEnemyCharacter:get_Hp()),f2s(lastEnemyCharacter:get_ReducedMaxHp()))
            --Weakpoint
            if config.showWeakpoint then
                local weak=WeakpointEnum2Str[lastEnemyCalculator["<WeakPointSettings>k__BackingField"]]
                local resist=WeakpointEnum2Str[lastEnemyCalculator["<ResistSettings>k__BackingField"]]
                local weakmsg=""
                if weak~=nil and weak~="" then 
                    weakmsg=weakmsg.."Weak:"..tostring(weak).."    "
                end
                if resist~=nil and resist~="" then 
                    weakmsg=weakmsg.."Resist:"..tostring(resist)
                end
                if weakmsg~="" then
                    msg=msg.."      "..weakmsg.."\n"
                end
                --msg=msg..tostring(lastEnemyCalculator["<WeakPointSettings>k__BackingField"]).."/"..tostring(lastEnemyCalculator["<ResistSettings>k__BackingField"])
            end
            --ATK/DEF
            if config.showATKDEF then
                msg=msg..string.format("      ATK %s/%s DEF %s/%s\n",f2s(lastEnemyCalculator:get_Attack()),f2s(lastEnemyCalculator:get_MagicAttack()),
                                                            f2s(lastEnemyCalculator:get_Defence()),f2s(lastEnemyCalculator:get_MagicDefence()))
            end
            --enchant
            --msg=msg.."\n"..f2s(lastEnemyCalculator["<EnchantStatusDamageFire>k__BackingField"])..f2s(lastEnemyCalculator["<EnchantStatusDamageIce>k__BackingField"])..f2s(lastEnemyCalculator["<EnchantStatusDamageThunder>k__BackingField"])..f2s(lastEnemyCalculator["<EnchantStatusDamageFire>k__BackingField"])
            --msg=msg.."\n"..f2s(lastEnemyCalculator["<EnchantPhsycalFactor>k__BackingField"])..","..f2s(lastEnemyCalculator["<EnchantMagicalFactor>k__BackingField"]).."...\n"
            --debuff
            if config.showDebuff then
                local debuffmsg=""
                local debuffCtrl=lastEnemyCharacter:get_StatusConditionCtrl()
                local bufflist=debuffCtrl.StatusConditionInfoList
                for i=0,bufflist:get_Count()-1 do
                    local statusConditionInfo=bufflist[i]
                    local name=StatusConditionEnum2Str[statusConditionInfo:get_ParamRes():get_StatusConditionId()]
                    local t=statusConditionInfo:getRemainTimer()
                    local e=statusConditionInfo:getEnduranceValue()
                    if t>0 then
                        debuffmsg=debuffmsg..string.format("      %s:%ss\n",name,f2s(t/60))
                    end
                end
                if debuffmsg~="" then
                    msg=msg..debuffmsg.."\n"
                end
            end
            --
            if bodyparts~=nil and config.showBodyParts then
                local regionStatusCtrl=lastEnemyHitController["<CachedRegionStatusCtrl>k__BackingField"]
                local ct=bodyparts:get_Count()-1
                for i=0,ct do
                    --region means body part
                    local regionStatus=bodyparts[i]
                    local regionNo=regionStatus["<RegionNo>k__BackingField"]
                    local partMsg="Part "..regionNo
                    if regionStatusCtrl~=nil then
                        local interRegionParam=regionStatusCtrl:getActiveRegionParam(regionNo)
                        if interRegionParam~=nil then
                            local regionType=RegionTypeEnum2Str[interRegionParam:get_RegionType()]
                            if regionType~="Other" then
                                partMsg=partMsg.."/"..regionType
                            elseif regionNo==0 then --assume part 0 is always body,Chimera part 0 is other
                                partMsg=partMsg.."/Body"
                            end
                        else--orge part 0 has no param
                            partMsg=partMsg.."/Body"
                        end
                    end
                    partMsg=partMsg..string.format("- HP: %s/%s ",f2s(regionStatus.Hp),f2s(regionStatus.MaxHp))

                    --PerChar.Threshold always 100?
                    local param=regionStatus["DamageReactionThreshold"].PerChar

                    local maxLean=0
                    local maxBlow=0
                    local maxLeanLv=0
                    local maxBlownLv=0
                    local leanLv=regionStatus["<ReactionLeanLevel>k__BackingField"]
                    local blownLv=regionStatus["<ReactionBlownLevel>k__BackingField"]
                    if param.Lean ~=nil and param.Lean:get_Count()>leanLv and leanLv>=0 then
                        maxLean=param.Lean[leanLv].m_value
                    end
                    if param.Lean ~=nil and param.Lean:get_Count()>0 then
                        maxLeanLv=param.Lean:get_Count()-1
                    end

                    if param.Blown ~=nil and param.Blown:get_Count()>blownLv and blownLv>=0 then
                        maxBlow=param.Blown[blownLv].m_value
                    end
                    if param.Blown ~=nil and param.Blown:get_Count()>0 then
                        maxBlownLv=param.Blown:get_Count()-1
                    end

                    if regionStatus.IsRegionReaction then
                        if maxLeanLv>0 or maxBlownLv>0 then
                            partMsg=partMsg..string.format("Lean(Lv%d/%d)- %s/%s ",leanLv,maxLeanLv,f2s(regionStatus["<ReactionLeanPoint>k__BackingField"]),f2s(maxLean or -1))
                            partMsg=partMsg..string.format("Blow(Lv%d/%d)- %s/%s ",blownLv,maxBlownLv,f2s(regionStatus["<ReactionBlownPoint>k__BackingField"]),f2s(maxBlow or -1))
                        else
                            partMsg=partMsg..string.format("Lean- %s/%s ",f2s(regionStatus["<ReactionLeanPoint>k__BackingField"]),f2s(maxLean or -1))
                            partMsg=partMsg..string.format("Blow- %s/%s ",f2s(regionStatus["<ReactionBlownPoint>k__BackingField"]),f2s(maxBlow or -1))
                        end
                    end

                    local continuousReactionCtrl=lastEnemyHitController["<ContinuousReactionCtrl>k__BackingField"]
                    if continuousReactionCtrl~=nil then
                        local prev=continuousReactionCtrl["<ContinuousReactionDmgType>k__BackingField"]
                        if DamageTypeEnum2Str[prev]~=nil then
                            local next=lastEnemyHitController["<CommonHitParamProp>k__BackingField"].ContinuousReactionParam:getNextStageDmgType(prev)
                            partMsg=partMsg..string.format("\nContinuousReaction:%s->%s\n",DamageTypeEnum2Str[prev],DamageTypeEnum2Str[next],continuousReactionCtrl["<ReReactionLv>k__BackingField"])
                        end
                    end

                    if regionStatusCtrl~=nil then
                        local interRegionParam=regionStatusCtrl:getActiveRegionParam(regionStatus["<RegionNo>k__BackingField"])
                        if interRegionParam~=nil then
                            local regionType=RegionTypeEnum2Str[interRegionParam:get_RegionType()]
                            if interRegionParam._DamageAdjustRatePys:get_Count()>=3 and interRegionParam._DamageAdjustRateMgc:get_Count()>=5 then
                                if config.showPhysicDamageAbsorption then
                                    partMsg=partMsg..
                                        string.format("\n\tSlash %.2f Strike %.2f Shoot %.2f\n",
                                            interRegionParam._DamageAdjustRatePys[0].m_value,interRegionParam._DamageAdjustRatePys[1].m_value,interRegionParam._DamageAdjustRatePys[2].m_value)
                                end
                                if  config.showMagicDamageAbsorption then
                                    partMsg=partMsg..
                                        string.format("\tMagic %.2f Fire %.2f Ice %.2f Thunder %.2f Light %.2f\n",
                                            interRegionParam._DamageAdjustRateMgc[0].m_value,interRegionParam._DamageAdjustRateMgc[1].m_value,interRegionParam._DamageAdjustRateMgc[2].m_value,
                                            interRegionParam._DamageAdjustRateMgc[3].m_value,interRegionParam._DamageAdjustRateMgc[4].m_value
                                            )
                                end
                                if config.showKnockdownAbsorption then
                                    partMsg=partMsg..
                                        string.format("\tKnockown:Global %.2f\n",interRegionParam._ReactionRate)                                    
                                end
                                if config.showPhysicKnockdownAbsorption then
                                    partMsg=partMsg..
                                        string.format("\tKnockdown:Slash %.2f Strike %.2f Shoot %.2f\n",
                                            interRegionParam._ReactionAdjustRatePys[0].m_value,interRegionParam._ReactionAdjustRatePys[1].m_value,interRegionParam._ReactionAdjustRatePys[2].m_value)
                                end

                                if  config.showMagicKnockdownAbsorption then
                                    partMsg=partMsg..
                                        string.format("\tKnockdown:Magic %.2f Fire %.2f Ice %.2f Thunder %.2f Light %.2f\n",
                                            interRegionParam._ReactionAdjustRateMgc[0].m_value,interRegionParam._ReactionAdjustRateMgc[1].m_value,interRegionParam._ReactionAdjustRateMgc[2].m_value,
                                            interRegionParam._ReactionAdjustRateMgc[3].m_value,interRegionParam._ReactionAdjustRateMgc[4].m_value
                                            )
                                end

                            end
                        end
                    end
                    msg=msg..partMsg.."\n"
                end
            end
            local size=imgui.calc_text_size(msg)
            draw.filled_rect(config.position[1]-5, config.position[2]-5, size.x +5,size.y+5, config.backgroundcolor)
            draw.text(msg,config.position[1],config.position[2],config.color)
            imgui.pop_font()
        end
    end
end)

sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),nil,refreshplayer)
refreshplayer()

myapi.DrawIt(modname,configfile,_config,config,nil)