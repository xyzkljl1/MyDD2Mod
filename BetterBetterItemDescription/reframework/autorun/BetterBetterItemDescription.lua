local modname="BetterBetterItemDescription"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
    {name="newlinewidth",type="int",default=20,min=1,max=250},
    {name="ignoreArmorAndWeapon",type="bool",default=false},
    {name="removeOriginalText",type="bool",default=true},
    {name="specifyTransFile",type="string",default="",label="Force using this language(Need reset script)"},
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

--Cache of expaned Item Description
local ItemDescCache={}
local SkillDescCache={}


local function Log(...)
    print(...)
    --log.info(modname..msg)
end

local ItemParamTypes={
    "app.ItemCommonParam",
    "app.ItemDataParam",
    "app.ItemEquipParam",
    "app.ItemWeaponParam",
    "app.ItemArmorParam",

}
local FieldFormat={
    --ItemCommonParam
    _Id={enable=false,type="String",format="Id %s."},
    _SortNo=nil,
    _Category={enable=false,type="Enum",format="Cat %s",
                            map={[1]="Material",
                            [2]="Other",
                            [3]="Equip"}
    },
    _Attr=nil,
    _ModelId=nil,
    _FieldModelId=nil,
    _IconNo=nil,
    _ItemDropId=nil,
    _Weight=nil,
    _BuyPrice={enable=false,type="String",format="BuyPrice %s."},
    _SellPrice={enable=false,type="String",format="SellPrice %s."},
    _StackNum=nil,
    _Material=nil,
    _Worth=nil,
    _Favor=nil,
    _FavoriteAttr=nil,
    _AutoSellPrio=nil,
    _StolenPrio=nil,
    ["<DataType>k__BackingField"]=nil,
    --ItemDataParam
    _SubCategory={enable=false,type="Enum",format="Cat %s",
                            map={[1]="Buff",
                            [2]="Material",
                            [3]="Special",
                            [4]="Quest",
                            [5]="Book",
                            [6]="Arrow",
                            [7]="CustomSkill",
                            [8]="PawnSkill",
                            [9]="MagicBook",
                            [10]="Online"}
    },
    _UseEffect={enable=false,type="Enum",format="Effect %s",map={[1]="Heal",[2]="RecoverStamina",[3]="Status"}},
    _Decay=nil,
    _DecayedItemId=nil,
    _HealWhiteHp="Heal %s HP.",
    _HealBlackHp="Heal %s MAXHP.",
    _HealStamina="Recover %s Stamina",
    _UseAttr=nil,
    _AddStatus=nil,
    _RemoveStatus=nil,--"%s",-- some is in app.StatusConditionDef.StatusConditionEnum,but some are not like id62 Sorbering:32/id70 Allheal:1023
    _FakePrice=nil,
    _FakeItemId=nil,
    
    --app.ItemEquipParam
    _EquipCategory=nil,
    _Lv=nil,
    _Series=nil,
    _Job=nil,
    
    --app.ItemWeaponParam
    _WeaponName=nil,
    _WeaponId=nil,
    _PhysicalAttack="%s ATK",
    _SlashRate=nil,
    _StrikeRate=nil,
    _StrikeStore=nil,
    _MagicAttack="%s MagATK",
    _Element=nil,
    _ElementStore=nil,
    _Shake=nil,
    _Blow=nil,
    _StaminaReduce=nil,
    _ShakeGuard=nil,
    _BlowGuard=nil,
    _PoisonStore=nil,
    _SleepStore=nil,
    _SilentStore=nil,
    _StoneStore=nil,
    _WaterStore=nil,
    _OilStore=nil,

    --app.ItemArmorParam
    _StyleNo=nil,
    _PhysicalDefence="%s PhyDEF",
    _SlashDefenceRate="%s%% Slash Reduce",
    _StrikeDefenceRate="%s%% Strike Reduce",
    _MagicDefence="%s MagDEF",
    _FireDefence="%s%% Fire Damage Reduce",
    _FireResist="%s%% Fire Debuff Resist",
    _IceDefence="%s%% Ice Damage Reduce",
    _IceResist="%s%% Ice Debuff Resist",
    _ThunderDefence="%s%% Thunder Damage Reduce",
    _ThunderResist="%s%% Thunder Debuff Resist",
    _LightDefence="%s%% Light Damage Reduce",
    _DarkDefence="%s%% Dark Debuff Resist",
    _ShakeResistRate="%s%% Shake Resist",
    _BlowResistRate="%s%% Blow Resist",
    _PoisonResist="%s%% Poison Resist",
    _SleepResist="%s%% Sleep Resist",
    _SilentResist="%s%% Silent Resist",
    _StoneResist="%s%% Stone Resist",
    _WaterResist="%s%% Water Resist",
    _OilResist="%s%% Oil Resist",
    --_Special=nil,
    --_SpecialValue=nil,
    --_SpecialValue2=nil,
    --_SpecialValue3=nil,
}

local RingSpecialFormat={
    [1]= {enable= true,format= "+{v1} MaxHP",hint= "(3502,Ring of Acclamation,200,0,0)(3501,Ring of Exultation,100,0,0)"},
    [2]= {enable= true,format= "+{v1} Max Stamina",hint= "(3504,Ring of Momentum,150,0,0)(3503,Ring of Tenacity,90,0,0)"},
    [3]= {enable= true,format= "+{v1} Max Weight",hint= "(3506,Ring of Profusion,10,0,0)(3505,Ring of Accrual,5,0,0)"},
    [4]= {enable= true,format= "+{v1}/{v2}/{v3} Max HP/Max Stamina/Max Weight",hint= "(3507,Ring of Triumph,100,100,5)"},
    [5]= {enable= true,format= "+{v1} ATK",hint= "(3508,Ring of Aggression,30,0,0)"},
    [6]= {enable= true,format= "+{v1} Magic ATK",hint= "(3510,Ring of Percipience,30,0,0)"},
    [7]= {enable= true,format= "+{v1}% EXP Gain",hint= "(3530,Ring of Ambition,50,0,0)"},
    [8]= {enable= true,format= "+{v1}% DCP Gain",hint= "(3531,Ring of Endeavor,50,0,0)"},
    [9]= {enable= true,format= "Heal {v1} HP On Kill",hint= "(3532,Ring of Regeneration,50,0,0)"},
    [10]= {enable= true,format= "{v1}% Faster Cast",hint= "(3533,Ring of Articulacy,15,0,0)"},
    [11]= {enable= true,format= "{v1}% Faster Cast but lose {v2}% Max HP",hint= "(3534,Ring of Recitation,25,20,0)"},
    [12]= {enable= true,format= "+{v1} Robustness",hint= "(3535,Ring of Resolution,100,0,0)"},
    [13]= {enable= true,format= "-{v1}% Stamina Cost",hint= "(3536,Ring of Grit,25,0,0)"},
    [14]= {enable= true,format= "Gain {v1} ATK in {v2} seconds",hint= "(3537,Ring of Requital,15,10,0)"},

    [15]= {enable= false,format= "{v1} {v2} {v3}",hint= "(3538,Ring of Brawn,0,0,0)"},

    [16]= {enable= true,format= "Slight Heal for {v2} seconds when taken damage over {v1}% MaxHP",hint= "(3539,Ring of Benevolence,25,3,0)"},
    [17]= {enable= true,format= "Gain {v2} ATK when under {v1}% HP",hint= "(3540,Ring of Recompense,25,100,0)"},
    [18]= {enable= true,format= "Gain {v2} ATK when HP no less than {v1}%",hint= "(3541,Ring of Predominance,100,10,0)"},
    --容易成为目标
    [20]= {enable= false,format= "{v1} {v2} {v3}",hint= "(3543,Ring of Disfavor,1,0,0)"},

    [21]= {enable= true,format= "+{v1} Stamina Recover",hint= "(3544,Ring of Quickening,10,0,0)"},
    [22]= {enable= true,format= "+{v1} Knockdown Power",hint= "(3545,Ring of Vehemence,100,0,0)"},
    [23]= {enable= false,format= "{v1} {v2} {v3}",hint= "(3548,Ring of Proximity,0,0,0)"},
    
    [24]= {enable= true,format= "+{v1}%/{v2}% Deal/Taken Damage",hint= "(3549,Ring of Gallantry,25,25,0)"},
    [25]= {enable= true,format= "+{v1}% Damage",hint= "(3550,Ring of Skullduggery,20,0,0)"},
    [26]= {enable= true,format= "Gain {v1} DEF in {v2} seconds",hint= "(3551,Ring of Reassurance,50,20,0)"},
    [27]= {enable= true,format= "+{v1}% recover amount",hint= "(3552,Ring of Amplification,10,0,0)"},
    [28]= {enable= false,format= "{v1} {v2} {v3}",hint= "(3553,Turquoise Ring,0,0,0)"},
    [29]= {enable= false,format= "{v1} {v2} {v3}",hint= "(3554,Ring of Derision,0,0,0)"},
    [30]= {enable= true,format= "+{v1}.",hint= "(3555,Eternal Bond,10,0,0)"},
}

local AbilityFormat={
--Fighter 1
[4]={format="x{v1} Mutliplier",hint="固定ヘイト値 * Value(2.000000,0.000000)"},
[5]={format="Gain {v2}%+{v1} DEF",hint="１：固定値　２：割合値(%)(45.000000,30.000000)"},
[6]={format="Gain {v2}%+{v1} Max Weight",hint="最大重量加算値(10.000000,0.000000)"},
[7]={format="Lift up +{v1} seconds.Pin Down +{v2} seconds",hint="1：担ぎ上げ、2：押さえつけ。単位は秒(2.000000,2.000000)"},
[8]={format="{v1} seconds faster from Down.{v2} seconds faster from Crawling",hint="1：ダウン、2：這いずり。単位は秒(0.300000,1.000000)"},
--Archer 2
[9]={format="+{v1} Damage Rate",hint="攻撃倍率加算値(0.100000,0.000000)"},
[10]={format="+{v1} Max Stamina",hint="固定値(150.000000,0.000000)"},
[11]={format="x{v1} Oil Cost/x{v2} Range",hint="1:燃料の消費速度倍率　2:照らす範囲(0.660000,2.000000)"},
[12]={format="+{v1} Damage Rate",hint="攻撃倍率加算値(0.050000,0.000000)"},
[13]={format="cliff:x{v1}/Other:x{v2}",hint="1：段差登り、2：しがみつき・しゃがみ(1.100000,1.100000)"},
--Mage 3
[14]={format="Gain {v2}%+{v1} MagDEF",hint="１：固定値　２：割合値(%)(45.000000,30.000000)"},
[15]={format="+{v1}% Recover Amount",hint="増加回復量(％)(10.000000,0.000000)"},
[16]={format="x{v1} Duration",hint="効果時間倍率(0.700000,0.000000)"},
[17]={format="x{v1} Duration",hint="効果時間倍率(1.200000,0.000000)"},
[18]={format="+{v1} Recover Rate",hint="加算倍率を入力(0.100000,0.000000)"},
--Thief 4
[19]={format="x{v1} Hate Mutliplier",hint="固定ヘイト値 * Value(0.850000,0.000000)"},
[20]={format="Recover {v1}%~{v2}% of Max HP",hint="トドメを指したとき、自身の体力の(Value～Value2)%回復(4.000000,4.000000)"},
[21]={format="x{v1} Stamina Cost Mutliplier",hint="(0.800000,0.000000)"},
[22]={format="x{v1} Stamina Cost Mutliplier",hint="しがみつき＆押さえ付け中のスタミナ持続消費量 * Value(0.850000,0.000000)"},
[23]={format="Gain {v2}%+{v1} Strength",hint="１：固定値　２：割合値(%)(30.000000,0.000000)"},
--Warrior 5
[24]={format="Gain {v2}%+{v1} MaxHP",hint="HPの上限値 + Value(200.000000,0.000000)"},
[25]={format="x{v1} Mutliplier",hint="組み付き時の押し引き力 * Value(1.500000,0.000000)"},
[26]={format="+{v1}% Guard Damage Rate",hint="ガード削り攻撃力 + Value%(30.000000,0.000000)"},
[27]={format="+{v1}% Knockdown power",hint="吹き飛ばし力 + Value%(15.000000,0.000000)"},
[28]={format="x{v1} MaxHP loss",hint="黒ゲージ蓄積量×Value(0.950000,0.000000)"},
--Sorcerer 6
[29]={format="+{v1}% debilitation",hint="状態異常与蓄積値 + Value%(20.000000,0.000000)"},
[30]={format="{v1}/{v2}",hint="(75.000000,90.000000)"},
[31]={format="+{v1}% Knockdown Resist",hint="吹き飛ばし耐性 + Value%(30.000000,0.000000)"},
[32]={format="+{v1}% Damage",hint="弱点属性による与ダメージ + Value%(5.000000,0.000000)"},
[33]={format="{v2}%+{v1} MagATK",hint="１：固定値　２：割合値(%)(30.000000,0.000000)"},
--7
[34]={format="x{v1} Move Speed",hint="持ち上げ、担ぎ上げ時の移動速度xValue(1.100000,0.000000)"},
[35]={format="x{v1} Gold",hint="金貨袋取得時、ゴールド獲得量xValue(1.050000,0.000000)"},
[36]={format="Gain {v2}% ATK in Day(4:00~20:00)\n{v2}% MagATK in Night(18:00~6:00)",hint="日中（4時～20時）、物理攻撃力+ 夜間（18時～6時）、魔法攻撃力+ １：固定値　２：割合値(%)(0.000000,5.000000)"},
[37]={format="x{v1} Amount",hint="リム決勝を入手したときのリム獲得量xValue(1.050000,0.000000)"},
[38]={format="x{v1} Cost",hint="ダッシュ中のスタミナ消費量×Value(0.900000,0.000000)"},
--8
[39]={format="Gain {v2}%+{v1} DEF/MagDEF",hint="ポーンの物理防御力/魔法防御力+ １：固定値　２：割合値(%)(30.000000,0.000000)"},
[40]={format="Recover {v1}% Stamina",hint="敵にトドメを指したとき、スタミナValue%回復(10.000000,0.000000)"},
[41]={format="x{v1} Chance",hint="(1.200000,0.000000)"},
[42]={format="Gain {v2}%+{v1} ATK/MagATK",hint="ポーンの物理攻撃力/魔法攻撃力+ １：固定値　２：割合値(%)(30.000000,0.000000)"},
[43]={format="-{v1} seconds",hint="ポーン蘇生にかかる時間 -Value(秒)(1.000000,0.000000)"},
--9
[44]={format="{v1}",hint="(1.500000,0.000000)"},
[45]={format="{v1}% Trigger",hint="調合時にアイテム作成個数+1個になる確率Value％(15.000000,0.000000)"},
[46]={format="x{v1} Chance to be attacked",hint="襲撃確率 * Value(0.350000,0.000000)"},
[47]={format="x{v1} Enemy Sight Range",hint="敵の視界センサー * Value(0.850000,0.000000)"},
[48]={format="Gain x{v1} Favorability",hint="NPCの好感度が上がるとき、上昇値 * Value(1.100000,0.000000)"},
[49]={format="x{v1} Cost",hint="カスタムスキルのスタミナ消費量xValue(0.950000,0.000000)"},
[50]={format="-{v1} Weight Level When Moving",hint="移動時の重量ランクをValue段階下げる(1.000000,0.000000)"},
}

local function printEnum(enumName)
    local type=sdk.find_type_definition(enumName)
    local fields=type:get_fields()
    for _,field in pairs(fields) do
        if field:get_data()~=nil and field:get_data()>0 then
            print(string.format("[%d]=\"%s\",",field:get_data(),field:get_name()))
        end
    end
end
local function printType(Name)
    local type=sdk.find_type_definition(Name)
    print("--",type:get_full_name())
    local fields=type:get_fields()
    for _,field in pairs(fields) do
       print(string.format("%s=nil,",field:get_name()))
    end
end

local function printAllTypes()
    for _,type in pairs(ItemParamTypes) do
        printType(type)
    end
end

local function printJobAbility()
    local player_man=sdk.get_managed_singleton("app.CharacterManager")
    local player=player_man:get_ManualPlayer()
    local abilityParam=player:get_Human().Parameter.AbilityParam
    local t=abilityParam.JobAbilityParameters
    for i=0,t:get_Count()-1 do
        local x=t[i].Abilities
        for j=0,x:get_Count()-1 do
            local ab=x[j]
            local hint=string.format("%s(%f,%f)",ab.Comment,ab.Value,ab.Value2)
            log.info(string.format("[%d]={hintname=\"%s\",hint=\"%s\"},",ab.AbilityID,ab.AbilityName,hint))
            print(string.format("[%d]={hint=\"%s\"},",ab.AbilityID,hint))
        end
    end
end

local function printRings()
    local im=sdk.get_managed_singleton("app.ItemManager")
    local iter=im._ItemDataDict:GetEnumerator()
    local dup={}
    iter:MoveNext()
    while iter:get_Current():get_Value()~=nil do
        local itemCommonParam=iter:get_Current():get_Value()
        if itemCommonParam:get_type_definition():is_a("app.ItemArmorParam") 
            and itemCommonParam._EquipCategory==sdk.find_type_definition("app.ItemEquipCategory"):get_field("Jewelry"):get_data() then 
            if itemCommonParam._Special>0 then
                if dup[itemCommonParam._Special]==nil then dup[itemCommonParam._Special]={} end
                dup[itemCommonParam._Special][itemCommonParam]=0
            end
        end
        iter:MoveNext()
    end
    for _Special,Params in pairs(dup) do
        local hint=""
        for itemCommonParam,_ in pairs(Params) do
            hint=hint..string.format("(%d,%s,%d,%d,%d)",itemCommonParam._Id,itemCommonParam:get_Name(),itemCommonParam._SpecialValue,itemCommonParam._SpecialValue2,itemCommonParam._SpecialValue3)
        end
        print(string.format("[%d]={enable=true,format=\"{v1} {v2} {v3}\",hint=\"%s\"},",_Special,hint))
    end
end
--[[
[0]="Japanese"
[1]="English",
[2]="French",
[3]="Italian",
[4]="German",
[5]="Spanish",
[6]="Russian",
[7]="Polish",
[8]="Dutch",
[9]="Portuguese",
[10]="PortugueseBr",
[11]="Korean",
[12]="TransitionalChinese",
[13]="SimplelifiedChinese",
[14]="Finnish",
[15]="Swedish",
[16]="Danish",
[17]="Norwegian",
[18]="Czech",
[19]="Hungarian",
[20]="Slovak",
[21]="Arabic",
[22]="Turkish",
[23]="Bulgarian",
[24]="Greek",
[25]="Romanian",
[26]="Thai",
[27]="Ukrainian",
[28]="Vietnamese",
[29]="Indonesian",
[30]="Fiction",
[31]="Hindi",
[32]="LatinAmericanSpanish",
[33]="Max",
[33]="Unknown",
]]--
local prevInitLanguage=""
local function Init()
    local om=sdk.get_managed_singleton("app.OptionManager")
    local optionItem=om._OptionItems:get_Item(sdk.find_type_definition("app.OptionID"):get_field("TextLanguage"):get_data())
    local lng=optionItem:get_FixedValueModel():get_StringValue()
    if lng==prevInitLanguage then
        Log("Ignore dup init")
        return
    end

    local filename=string.format("%s.%s.json",modname,lng)
    if config.specifyTransFile~="" then
        filename=string.format("%s.%s.json",modname,config.specifyTransFile)
    end
    Log("Try Load ",lng)
    local tmp=json.load_file(filename)
    if tmp~=nil and tmp.FieldFormat~=nil then
        FieldFormat=tmp.FieldFormat
        RingSpecialFormat={}
        --convert string key to int
        for k,v in pairs(tmp.RingSpecialFormat) do
            RingSpecialFormat[tonumber(k)]=v
        end

        AbilityFormat={}
        --convert string key to int
        for k,v in pairs(tmp.AbilityFormat) do
            AbilityFormat[tonumber(k)]=v
        end
        Log("Load From",filename)
    else
        Log("Invalid File,Use default")
    end
    prevInitLanguage=lng
    ItemDescCache={}
    SkillDescCache={}
end


--json.dump_file("BetterBetterItemDescription.English.json",{FieldFormat=FieldFormat,RingSpecialFormat=RingSpecialFormat,AbilityFormat=AbilityFormat})
--Init
sdk.hook(sdk.find_type_definition("app.OptionManager"):get_method("app.ISystemSaveData.loadSystemSaveData(app.SaveDataBase)"),nil,Init)
sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),nil,Init)
Init()


--printJobAbility()
--printRings()
--printEnum("app.ItemEquipCategory")
--printEnum("via.Language")

local function TranslateFields(param,paramtype)
    local ret=""
    local tmpLine=""
    --get_fields only return sub class's field,need pass in type to appoint certain type
    local fields=paramtype:get_fields()
    --Iterate fields and convert to string
    for _,field in pairs(fields) do
        --Log(field:get_name(),field:get_data(param),field:get_type():get_full_name())
        local fieldname=field:get_name()
        local format=FieldFormat[fieldname]
        local fieldtype=field:get_type():get_full_name()
        local fieldMsg=""
        --lua don't have fucking continue!
        if format ~=nil then
            --check is zero
            local data=field:get_data(param)
            local isIgnore=true
            if fieldtype=="System.Int16" or fieldtype=="System.Int32" or fieldtype=="System.Int64" or  fieldtype=="System.UInt16" or fieldtype=="System.UInt32" or fieldtype=="System.UInt64" then
                isIgnore=(data==0)
            else
                local tryInt=tonumber(tostring(data), 10)
                --try convert to int(for some enums)
                if tryInt~=nil then
                    isIgnore=(tryInt<=0)
                else
                    Log("Other Type",type)
                end
            end
            --to string
            if not isIgnore then
                if type(format)=="string" then
                    fieldMsg=fieldMsg..string.format(format,tostring(data))
                elseif format.type=="String" and format.enable then
                    fieldMsg=fieldMsg..string.format(format.format,tostring(data))
                elseif format.type=="Enum" and format.enable then
                    local enumstr=format.map[tonumber(data)]
                    fieldMsg=fieldMsg..string.format(format.format,enumstr)
                end
            end
        else
            --Log("Ignore "..fieldname)
            --Log(string.format("%s=nil,",fieldname))
        end
        if fieldMsg~="" then
            if tmpLine~="" then tmpLine=tmpLine.."/" end
            tmpLine=tmpLine..fieldMsg
            if string.len(tmpLine) >config.newlinewidth then 
                ret=ret..tmpLine.."\n" 
                tmpLine=""
            end
        end
    end
    ret=ret..tmpLine
    return ret
end
local function TranslateRingSP(param)
    local sp=param._Special
    if sp==nil or RingSpecialFormat[sp]==nil or RingSpecialFormat[sp].enable==false then return "" end
    local ret=RingSpecialFormat[sp].format
    ret=string.gsub(ret,"{v1}",tostring(param._SpecialValue))
    ret=string.gsub(ret,"{v2}",tostring(param._SpecialValue2))
    ret=string.gsub(ret,"{v3}",tostring(param._SpecialValue3))
    return ret
end

local function isRing(param)
    --[[[1]="Sub",
        [2]="Head",
        [3]="Upper",
        [4]="Lower",
        [5]="Mantle",
        [6]="Jewelry",
        [7]="Visual",
        ]]--
    if param==nil then return false end
    if param:get_type_definition():is_a("app.ItemArmorParam") 
        and param._EquipCategory==sdk.find_type_definition("app.ItemEquipCategory"):get_field("Jewelry"):get_data() then 
        return true
    end
    return false
end
local function isRingOrItem(param)
    if param==nil then return false end
    if param:get_type_definition():is_a("app.ItemDataParam") then return true end
    if isRing()==true then return true end
    return false
end

local function GetItemDetail(itemCommonParam)
    local ret=""
    local itemParam=itemCommonParam:get_ItemParam()
    if config.ignoreArmorAndWeapon and not isRingOrItem(itemCommonParam) then return "" end
    for _,type in pairs(ItemParamTypes) do
        if itemCommonParam:get_type_definition():is_a(type) then
            ret=ret..TranslateFields(itemCommonParam,sdk.find_type_definition(type))
        end
    end
    if isRing(itemCommonParam) then
        ret=ret..TranslateRingSP(itemCommonParam)
    end
    return ret
end

local function GetOrAddItemDesc(originalMessage,itemCommonParam)
    --if tmpStr~=nil then return tmpStr end
    local Id=itemCommonParam._Id
    if ItemDescCache[Id] ==nil then
        Log("Add Item Desc To Cache")
        local appendtext=GetItemDetail(itemCommonParam)
        if config.removeOriginalText then
            if appendtext~="" then
                ItemDescCache[Id]=appendtext
            else
                ItemDescCache[Id]=originalMessage
            end
        else
            ItemDescCache[Id]=string.format("%s\n%s",originalMessage,appendtext)
        end
        Log(ItemDescCache[Id])
    end
    --can't cache managed_string ,causes crash
    --Log(ItemDescCache[Id])
    return sdk.create_managed_string(ItemDescCache[Id])
end

local function float2stringEX(v)
    if v-math.floor(v)<0.0001 then
        return tostring(math.floor(v))
    end
    return string.format("%.2f",v)
end

local function GetAbilityDetail(player,Id)
    local abilityParam=player:get_Human().Parameter.AbilityParam
    local para=abilityParam:getParam(Id)
    --return tostring(para.value).."/"..tostring(value2)
    --para.Comment is comment from dev, thanks devs!
    if AbilityFormat[Id]==nil then return "" end
    local ret=AbilityFormat[Id].format
    ret=string.gsub(ret,"{v1}",float2stringEX(para.Value))
    ret=string.gsub(ret,"{v2}",float2stringEX(para.Value2))
    --return tostring(Id).."/"..ret
    return ret
end



local function GetOrAddSkillDesc(originalMessage,Id)
    --if tmpStr~=nil then return tmpStr end
    if SkillDescCache[Id] ==nil then
        Log("Add Skill Desc To Cache")
        local player_man=sdk.get_managed_singleton("app.CharacterManager")
        local player=player_man:get_ManualPlayer()
        if player~=nil then
            local appendtext=GetAbilityDetail(player,Id)
            if config.removeOriginalText then
                if appendtext~="" then
                    SkillDescCache[Id]=appendtext
                else
                    SkillDescCache[Id]=originalMessage
                end
            else
                SkillDescCache[Id]=string.format("%s\n%s",originalMessage,appendtext)
            end
            Log(SkillDescCache[Id])
        else
            return sdk.create_managed_string(originalMessage)
        end

    end
    --can't cache managed_string ,causes crash
    --Log(SkillDescCache[Id])
    return sdk.create_managed_string(SkillDescCache[Id])
end


local tmpItemWindow=nil
local tmpItem=nil
sdk.hook(
    --sdk.find_type_definition("app.GUIBase.ItemWindowRef"):get_method("setup(app.ItemDefine.StorageData)"),
    sdk.find_type_definition("app.GUIBase.ItemWindowRef"):get_method("setup(app.ItemCommonParam, System.Int32, System.Boolean)"),
    function (args)
        local this=sdk.to_managed_object(args[2])
        local itemCommonParam=sdk.to_managed_object(args[3])
        if itemCommonParam==nil or this ==nil then return end
        tmpItemWindow=this
        tmpItem=itemCommonParam
    end,
    function ()
        if tmpItemWindow~=nil and tmpItem~=nil then
            --print(tmpItemWindow._TxtInfo:get_Message():ToString())
            local message=GetOrAddItemDesc(tmpItemWindow._TxtInfo:get_Message(),tmpItem)
            tmpItemWindow._TxtInfo:set_Message(message)
            tmpItemWindow=nil
            tmpItem=nil
        end
    end
)


local function LogTypeMethods(game_object)
    x=game_object:get_type_definition():get_methods()
    for k,v in pairs(x) do
        Log(v:get_name())
    end
end


local tmpJobWindow=nil
--Job NormalSkill CustomSkill Ability other
local MainContentsInfoKindAbility=sdk.find_type_definition("app.ui040101_00.MainContentsInfo.Kind"):get_field("Ability"):get_data()
local MainContentsInfoKindOther=sdk.find_type_definition("app.ui040101_00.MainContentsInfo.Kind"):get_field("Other"):get_data()

--in Augments tab
sdk.hook(
    --sdk.find_type_definition("app.GUIBase.ItemWindowRef"):get_method("setup(app.ItemDefine.StorageData)"),
    sdk.find_type_definition("app.ui040101_00"):get_method("setupAbilityInfoWindow()"),
    function (args)
        local this=sdk.to_managed_object(args[2])
        tmpJobWindow=this
    end,
    function ()
        if tmpJobWindow~=nil then
            local abilityId=nil
            local cursor=tmpJobWindow._Main_ContentsListCtrl:get_SelectedInfo()
            local rcursor=tmpJobWindow._Ability_EqListCtrl:get_SelectedInfo()
            local rindex=tmpJobWindow._Ability_EqListCtrl:get_SelectedIndex()

            --selecting on left or just turn to right
            --should show info in left
            if rindex==0 then
                if cursor.ContenstsType==MainContentsInfoKindAbility then
                    abilityId=cursor.Ability.AbilityID
                end
            else-- else show info in right
                abilityId=rcursor.AbilityID
            end
            
            if abilityId~=nil and abilityId>0 then
                tmpJobWindow._TxtAbilityInfo:set_Message(GetOrAddSkillDesc(tmpJobWindow._TxtAbilityInfo:get_Message(),abilityId))
            end
            tmpJobWindow=nil
        end
    end
)
--Vocation tab
sdk.hook(
    --sdk.find_type_definition("app.GUIBase.ItemWindowRef"):get_method("setup(app.ItemDefine.StorageData)"),
    sdk.find_type_definition("app.ui040101_00"):get_method("setupJobAbilityInfoWindow()"),
    function (args)
        local this=sdk.to_managed_object(args[2])
        tmpJobWindow=this
    end,
    function ()
        if tmpJobWindow~=nil then
            local abilityId=nil
            local cursor=tmpJobWindow._Job_AbilityListCtrl:get_SelectedInfo()
            -- is selecting ability in left
            if cursor.ContenstsType==MainContentsInfoKindAbility then
                abilityId=cursor.Ability.AbilityID
                if abilityId~=nil and abilityId>0 then
                    tmpJobWindow._TxtJobAbilityInfo:set_Message(GetOrAddSkillDesc(tmpJobWindow._TxtJobAbilityInfo:get_Message(),abilityId))
                end
            end
            tmpJobWindow=nil
        end
    end
)


--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,function() ItemDescCache={} SkillDescCache={} end) end
