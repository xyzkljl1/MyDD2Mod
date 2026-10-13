local modname="BetterBetterItemDescription"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local dataFileInfo={type="author",name="Data file: Built-in"}
local _config={
    {type="author",version="1.9"},
    dataFileInfo,
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
    if para.name~=nil then config[para.name]=para.default end
end
config= recurse_def_settings(config, json.load_file(configfile) or {})

--Cache of expaned Item Description
local ItemDescCache={}
local SkillDescCache={}
local EquipmentSkillDescCache={}
local WeaponCharaMsgCache={}
local SkillName2Id={}

local guiManager=nil
local characterManager=nil
local messageManager=nil
local initialized=false

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
    _HealBlackStamina="Recover %s MAX Stamina",
    _UseAttr=nil,
    _AddStatus={enable=true,type="Enum",format="Add %s Status",map={[1]="Posion"}},
    _RemoveStatus=nil,
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
    _StrikeStore="%s Unconsicious Store",
    _MagicAttack="%s MagATK",
    _Element={enable=true,type="Enum",format="+%s%% %s Enchant",map={[1]="Fire",[2]="Ice",[3]="Lightning",[4]="Holy"}},
    _ElementStore="%s Element Buildup Enchantment",
    _Shake=nil,
    _Blow="%s Knockdown",
    _StaminaReduce=nil,
    _ShakeGuard=nil,
    _BlowGuard="%s Knockdown Guard",
    _PoisonStore="%s PoisonStore",
    _SleepStore="%s Sleep Store",
    _SilentStore="%s Silent Store",
    _StoneStore="%s Stone Store",
    _WaterStore="%s Water Store",
    _OilStore="%s Oil Store",

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
    _BlowResistRate="+%s Knockdown Resist",
    _PoisonResist="%s%% Poison Resist",
    _SleepResist="%s%% Sleep Resist",
    _SilentResist="%s%% Silent Resist",
    _StoneResist="%s%% Stone Resist",
    _WaterResist="%s%% Water Resist",
    _OilResist="%s%% Oil Resist",
    _ColdResist="%s%% Cold Resist",
    --_Special=nil,
    --_SpecialValue=nil,
    --_SpecialValue2=nil,
    --_SpecialValue3=nil,
}

local ItemBuffFormat={
    ["AttackFactor"]="+%s%% Attack ",
    ["DefenceFactor"]="+%s%% Defense ",
    ["StatusConditionResistFactor"]= "+%s%% Status Resist ",
    ["StaminaRecoverFactor"]= "%s%% Stamina Recover ",
    ["Sec"]= "for %s seconds",
    ["MaxHpDamageFactor"]="-%s%% MaxHP Loss ",
    ["Camp"]="Camp:"
}

local WeaponSpecialFormat={
    [1010]={enable=true,format="+{v1}% BaseATK per hit,no more than +{v2}%",hint="wp00_007_00,龙之信条,每次攻击获得基础攻击倍率"},
    --getMagicAttackFactorByEquip和getWeaponSpecialMagicAttackStatusFactor都里计算了wp08_007_00但是它们俩根本没被调用，实际是在app_PlayerDamageCalculator__calcMagicAttack777763里计算的
    --类似item也是在WeaponAdditionalParameter里的curve
    [1610]={enable=true,curve=true,format="+{v0}~{v1}% BaseMagicATK under {t1}% HP.+{v2}% BaseMagicATK over {t2}% HP",hint="wp08_007_00,封魔大杖,根据血量获得攻击力"},
    [2010]={enable=true,format="+{v1}% BaseATK per hit,no more than +{v2}%",hint="林德蠕龙的尖牙"},
    [1207]={enable=true,format="**+0~10% BaseATK beyond 25% HP. +300% BaseATK under 25% HP",hint="龙之信条大剑,根据(1-ReducedHpRatio)获得基础攻击倍率，参数是1/1实在找不到规律，代码也看不懂，实测是损失(0,75%)血量时获得约(0,0.1),损失75%以上时跃升至4.0"},
    [1804]={enable=true,format="+{v1}% EXP",hint="美杜莎魔弓箭，(300,400),第二个参数不知道干什么用的"},
    [1413]={enable=false,hint="探测匕首,1/1,推测(1,1)的都是实际不使用参数计算？"},
    [1906]={enable=true,format="Take +{v1}% More Damage. Heal {v2} HP per second",hint="圣木魔弓，固定回血，给敌人加DamageRate"},
    [2103]={enable=true,wp10_003=true,format="Gain {v1} Gold per Hit,not exceeding {v2}.A little chance to get {v3} Gold(Ignore cap)",hint="梦想路，50/50,参数意义不明，实际在wp10_003_00Param"},
    [2210]={enable=false,hint="庇佑护盾，200/0,意义不明"},
    ["SpecialEfficacy"]={enable=true,format="+{v1}% Damage Rate to certain enemies",hint="对特定敌人增伤"}
}
local RingSpecialFormat={
    [10201]={enable=true,efficacy=true,format="+{v1}% Damage Rate to certain enemies"},
    [10202]={enable=true,efficacy=true,format="+{v1}% Damage Rate to certain enemies"},
    [31]={enable=true,format="objects +{v1}%, bombs +{v2}%, characters +{v3}%"},
    [35]={enable=true,format="-{v1} HP/s"},
    [36]={enable=true,format="Day -{v1} HP/s, night +{v2} HP/s"},
    [41]={enable=true,format="Restore {v1}% of stamina consumed"},
    [42]={enable=true,format="Stamina recovery when exhausted +{v1}%"},
    [43]={enable=true,format="Incantation speed +{v1}%"},
    [44]={enable=true,format="Base physical attack +{v1}%"},
    [45]={enable=true,format="Base magick attack +{v1}%"},
    [46]={enable=true,format="Dashing stamina cost -{v1}%"},
    [47]={enable=true,format="Physical and magick defense +{v1}%"},
    [48]={enable=true,format="Gold drops +{v1}%, EXP -{v2}%"},
    [49]={enable=true,format="Drop weight +{dr}%, drop times +{dc}"},
    [50]={enable=true,format="Base physical attack +{v1}%"},
    [51]={enable=true,format="Knockdown power +{v1}%"},
    [58]={enable=true,format="Restore stamina equal to factor * motion value. Factor: Fighter{sr1}/Archer{sr2}/Mage{sr3}/Thief{sr4}/Warrior{sr5}/Sorcerer{sr6}/Mystic Spearhand{sr7}/Magick Archer{sr8}/Trickster{sr9}. Cap: {sm4} (Magick Archer/Thief)/{sm1} (others)"},
    [38]={enable=true,format="Main pawn -100%, other pawns -50%"},
    [59]={enable=true,format="Main pawn -100%, other pawns -50%"},
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
    [12]= {enable= true,format= "+{v1} Knockdown Resist",hint= "(3535,Ring of Resolution,100,0,0)"},
    [13]= {enable= true,format= "-{v1}% Stamina Cost",hint= "(3536,Ring of Grit,25,0,0)"},
    [14]= {enable= true,format= "Gain {v1} ATK in {v2} seconds",hint= "(3537,Ring of Requital,15,10,0)"},
    --curve in get_JewelryAdditionalDataDict,
    [15]= {enable= false,format= "+{v1}% BaseAtk under {t1} weight or +{v3}% BaseAtk under {t3} weight.(No effect under 0.0 weight)",hint= "(3538,Ring of Brawn,0,0,0)",curve=true},

    [16]= {enable= true,format= "Slight Heal for {v2} seconds when taken damage over {v1}% MaxHP",hint= "(3539,Ring of Benevolence,25,3,0)"},
    --see app_PlayerDamageCalculator___c__DisplayClass21_0___getJewelryPhysicalAttackStatusFactor_b__0817923
    [17]= {enable= true,format= "+{v2}% BaseATK when under {v1}% HP",hint= "(3540,Ring of Recompense,25,100,0)"},
    [18]= {enable= true,format= "+{v1}% BaseATK when full HP",hint= "(3541,Ring of Predominance,100,10,0), v2 is not used"},
    --容易成为目标
    [20]= {enable= false,format= "{v1} {v2} {v3}",hint= "(3543,Ring of Disfavor,1,0,0)"},

    [21]= {enable= true,format= "+{v1} Stamina Recover",hint= "(3544,Ring of Quickening,10,0,0)"},
    [22]= {enable= true,format= "+{v1} Knockdown Power",hint= "(3545,Ring of Vehemence,100,0,0)"},
    --curve in get_JewelryAdditionalDataDict
    [23]= {enable= false,format= "+{v1} BaseAtk in {t1} distance.+{v3} BaseAtk in {t3} distance.+{v5} BaseAtk in {t5} distance.",hint= "(3548,Ring of Proximity,0,0,0)",curve=true},
    
    [24]= {enable= true,format= "+{v1}%/{v2}% Deal/Taken Damage",hint= "(3549,Ring of Gallantry,25,25,0)"},
    [25]= {enable= true,format= "+{v1}% Damage",hint= "(3550,Ring of Skullduggery,20,0,0)"},
    [26]= {enable= true,format= "Gain {v1} DEF in {v2} seconds",hint= "(3551,Ring of Reassurance,50,20,0)"},
    [27]= {enable= true,format= "+{v1}% recover amount",hint= "(3552,Ring of Amplification,10,0,0)"},
    [28]= {enable= false,format= "{v1} {v2} {v3}",hint= "(3553,Turquoise Ring,0,0,0)"},
    [29]= {enable= false,format= "{v1} {v2} {v3}",hint= "(3554,Ring of Derision,0,0,0)"},
    [30]= {enable= true,format= "Gain +{v1}% Favorability.",hint= "(3555,Eternal Bond,10,0,0)"},
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

local EquipmentAbilityFormat={
    [47]={format="+{iceenc}% ice enchantment, +{v1} ice buildup (greatsword ×{sfenc5}/daggers ×{sfenc4}/bow ×{sfenc2}/duospear ×{sfenc7})",hint="Frosted Edge"},
    [48]={format="{ex1}% chance to heal a base {ex2}% of damage dealt (greatsword ×{ex3}/daggers ×{ex4}/bow ×{ex5}/magick bow ×{ex6}/censer ×{ex7})",hint="Aggressive Recovery",ex1={"RecoverOnAttackHitParam","Probability","ProbabilityBonus"},ex2={"RecoverOnAttackHitParam","BaseFactor","BaseFactorBonus"},ex3={"RecoverOnAttackHitParam","JobDataList.4.MultipleFactor"},ex4={"RecoverOnAttackHitParam","JobDataList.3.MultipleFactor"},ex5={"RecoverOnAttackHitParam","JobDataList.1.MultipleFactor"},ex6={"RecoverOnAttackHitParam","JobDataList.7.MultipleFactor"},ex7={"RecoverOnAttackHitParam","JobDataList.8.MultipleFactor"}},
    [49]={format="Damage dealt +{v1}%; damage taken +{v2}%",hint="Battle Frenzy I"},
    [50]={format="{r49}",hint="Battle Frenzy II"},
    [51]={format="{r49}",hint="Battle Frenzy III"},
    [52]={format="{r49}",hint="Battle Frenzy IV"},
    [53]={format="{ex1} poison buildup (greatsword ×{ex4}/daggers ×{ex5}/bow ×{ex6}/staff ×{ex7}/archistaff ×{ex8}/magick bow ×{ex9}/censer ×{ex10}); {ex2} s cooldown, up to {ex3} activations per target",hint="Blighting Strike",ex1={"PoisonAttackParameter","BaseFactor","BaseFactorBonus"},ex2={"PoisonAttackParameter","IntervalSec","IntervalSecBonus"},ex3={"PoisonAttackParameter","MaxActivationNum"},ex4={"PoisonAttackParameter","JobDataList.4.MultipleFactor"},ex5={"PoisonAttackParameter","JobDataList.3.MultipleFactor"},ex6={"PoisonAttackParameter","JobDataList.1.MultipleFactor"},ex7={"PoisonAttackParameter","JobDataList.2.MultipleFactor"},ex8={"PoisonAttackParameter","JobDataList.5.MultipleFactor"},ex9={"PoisonAttackParameter","JobDataList.7.MultipleFactor"},ex10={"PoisonAttackParameter","JobDataList.8.MultipleFactor"}},
    [54]={format="{ex1}% unconsciousness chance (greatsword ×{ex4}/daggers ×{ex5}/bow ×{ex6}/duospear ×{ex7}/magick bow ×{ex8}/censer ×{ex9}); {ex2} s cooldown, up to {ex3} activations per target",hint="Knockout Strike",ex1={"FaintAttackParameter","BaseFactor","BaseFactorBonus"},ex2={"FaintAttackParameter","IntervalSec","IntervalSecBonus"},ex3={"FaintAttackParameter","MaxActivationNum"},ex4={"FaintAttackParameter","JobDataList.4.MultipleFactor"},ex5={"FaintAttackParameter","JobDataList.3.MultipleFactor"},ex6={"FaintAttackParameter","JobDataList.1.MultipleFactor"},ex7={"FaintAttackParameter","JobDataList.6.MultipleFactor"},ex8={"FaintAttackParameter","JobDataList.7.MultipleFactor"},ex9={"FaintAttackParameter","JobDataList.8.MultipleFactor"}},
    [55]={format="-{v1}% Stamina Cost",hint="Enduring Defense"},
    [56]={format="+{v1}% Counter Damage",hint="Deflected Impact"},
    [58]={format="+{v1}% Damage",hint="Battering Shield"},
    [59]={format="+{v1}% Damage",hint="Demon Counter I"},
    [60]={format="+{v1}% Damage",hint="Demon Counter II"},
    [61]={format="+{v1}% Damage",hint="Demon Counter III"},
    [62]={format="+{v1}% Damage",hint="Abomination Counter I"},
    [63]={format="+{v1}% Damage",hint="Abomination Counter II"},
    [64]={format="+{v1}% Damage",hint="Abomination Counter III"},
    [65]={format="+{v1}% Damage",hint="Humanoid Counter I"},
    [66]={format="+{v1}% Damage",hint="Humanoid Counter II"},
    [67]={format="+{v1}% Damage",hint="Beast Counter I"},
    [68]={format="+{v1}% Damage",hint="Beast Counter II"},
    [69]={format="+{v1}% Damage",hint="Winged Beast Counter I"},
    [70]={format="+{v1}% Damage",hint="Winged Beast Counter II"},
    [71]={format="+{v1}% Damage",hint="Saurian Counter I"},
    [72]={format="+{v1}% Damage",hint="Saurian Counter II"},
    [73]={format="+{v1}% Damage",hint="Spirit Counter I"},
    [74]={format="+{v1}% Damage",hint="Spirit Counter II"},
    [75]={format="+{v1}% Base Max Stamina, -{v2}% Magick/Magick Defense",hint="Gigantus's Vim"},
    [76]={format="+{ex1}% Jump Height; ranged attacks: {ex4}% chance of +{ex5}% damage, airborne attacks: {ex2}% chance of +{ex3}% damage",hint="Enhanced Jump",ex1={"JumpHeightAndJumpAttackUpParam","FactorJumpHeight"},ex2={"JumpHeightAndJumpAttackUpParam","ProbabilityJumpAttackUp","ProbabilityJumpAttackUpBonus"},ex3={"JumpHeightAndJumpAttackUpParam","FactorJumpAttackUp","FactorJumpAttackUpBonus"},ex4={"JumpHeightAndJumpAttackUpParam","ProbabilityPhysicalShellAttackUp","ProbabilityPhysicalShellAttackUpBonus"},ex5={"JumpHeightAndJumpAttackUpParam","FactorPhysicalShellAttackUp","FactorPhysicalShellAttackUpBonus"}},
    [77]={format="Max HP becomes {v2}%, {v1}% chance to nullify damage",hint="Spectral Feint"},
    [79]={format="+{v2}% Ice Magick Damage, +{v1} Defense/Magick Defense",hint="Ice Elemental"},
    [80]={format="-{ex1}% damage taken, +{ex2}% chance to nullify damage, +{ex5}% counterattack damage; reflect {ex3}% of damage taken as ice buildup (minimum {ex4})",hint="Frozen Soul",ex1={"IceCounterReduceDragonDamageNullifyMagicParam","ReduceDamageFactorS"},ex2={"IceCounterReduceDragonDamageNullifyMagicParam","NullifyMagicProbabilityS","NullifyMagicProbabilityBonus"},ex3={"IceCounterReduceDragonDamageNullifyMagicParam","CounterStatusConditionDamageFactor","CounterStatusConditionDamageFactorBonus"},ex4={"IceCounterReduceDragonDamageNullifyMagicParam","CounterMinStatusConditionDamage"},ex5={"IceCounterReduceDragonDamageNullifyMagicParam","CounterDamageFactor"}},
    [81]={format="-{ex1}% damage taken, +{ex2}% chance to nullify damage, +{ex5}% counterattack damage; reflect {ex3}% of damage taken as ice buildup (minimum {ex4})",hint="Frozen Soul",ex1={"IceCounterReduceDragonDamageNullifyMagicParam","ReduceDamageFactorM"},ex2={"IceCounterReduceDragonDamageNullifyMagicParam","NullifyMagicProbabilityS","NullifyMagicProbabilityBonus"},ex3={"IceCounterReduceDragonDamageNullifyMagicParam","CounterStatusConditionDamageFactor","CounterStatusConditionDamageFactorBonus"},ex4={"IceCounterReduceDragonDamageNullifyMagicParam","CounterMinStatusConditionDamage"},ex5={"IceCounterReduceDragonDamageNullifyMagicParam","CounterDamageFactor"}},
    [82]={format="-{ex1}% damage taken, +{ex2}% chance to nullify damage, +{ex5}% counterattack damage; reflect {ex3}% of damage taken as ice buildup (minimum {ex4})",hint="Frozen Soul",ex1={"IceCounterReduceDragonDamageNullifyMagicParam","ReduceDamageFactorL"},ex2={"IceCounterReduceDragonDamageNullifyMagicParam","NullifyMagicProbabilityS","NullifyMagicProbabilityBonus"},ex3={"IceCounterReduceDragonDamageNullifyMagicParam","CounterStatusConditionDamageFactor","CounterStatusConditionDamageFactorBonus"},ex4={"IceCounterReduceDragonDamageNullifyMagicParam","CounterMinStatusConditionDamage"},ex5={"IceCounterReduceDragonDamageNullifyMagicParam","CounterDamageFactor"}},
    [83]={format="-{ex1}% damage taken, +{ex2}% chance to nullify damage, +{ex5}% counterattack damage; reflect {ex3}% of damage taken as ice buildup (minimum {ex4})",hint="Frozen Soul",ex1={"IceCounterReduceDragonDamageNullifyMagicParam","ReduceDamageFactorS"},ex2={"IceCounterReduceDragonDamageNullifyMagicParam","NullifyMagicProbabilityM","NullifyMagicProbabilityBonus"},ex3={"IceCounterReduceDragonDamageNullifyMagicParam","CounterStatusConditionDamageFactor","CounterStatusConditionDamageFactorBonus"},ex4={"IceCounterReduceDragonDamageNullifyMagicParam","CounterMinStatusConditionDamage"},ex5={"IceCounterReduceDragonDamageNullifyMagicParam","CounterDamageFactor"}},
    [84]={format="-{ex1}% damage taken, +{ex2}% chance to nullify damage, +{ex5}% counterattack damage; reflect {ex3}% of damage taken as ice buildup (minimum {ex4})",hint="Frozen Soul",ex1={"IceCounterReduceDragonDamageNullifyMagicParam","ReduceDamageFactorM"},ex2={"IceCounterReduceDragonDamageNullifyMagicParam","NullifyMagicProbabilityM","NullifyMagicProbabilityBonus"},ex3={"IceCounterReduceDragonDamageNullifyMagicParam","CounterStatusConditionDamageFactor","CounterStatusConditionDamageFactorBonus"},ex4={"IceCounterReduceDragonDamageNullifyMagicParam","CounterMinStatusConditionDamage"},ex5={"IceCounterReduceDragonDamageNullifyMagicParam","CounterDamageFactor"}},
    [85]={format="-{ex1}% damage taken, +{ex2}% chance to nullify damage, +{ex5}% counterattack damage; reflect {ex3}% of damage taken as ice buildup (minimum {ex4})",hint="Frozen Soul",ex1={"IceCounterReduceDragonDamageNullifyMagicParam","ReduceDamageFactorL"},ex2={"IceCounterReduceDragonDamageNullifyMagicParam","NullifyMagicProbabilityM","NullifyMagicProbabilityBonus"},ex3={"IceCounterReduceDragonDamageNullifyMagicParam","CounterStatusConditionDamageFactor","CounterStatusConditionDamageFactorBonus"},ex4={"IceCounterReduceDragonDamageNullifyMagicParam","CounterMinStatusConditionDamage"},ex5={"IceCounterReduceDragonDamageNullifyMagicParam","CounterDamageFactor"}},
    [86]={format="-{ex1}% charge time, -{ex2}% damage taken",hint="Wicked Knight",ex1={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeSpeedFactorS"},ex2={"ChargeSpeedUpAndReduceDeamonDamageParam","ReduceDamageFactorS"},ex3={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeDamageFactorBonus"}},
    [87]={format="-{ex1}% charge time, -{ex2}% damage taken",hint="Wicked Knight",ex1={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeSpeedFactorM"},ex2={"ChargeSpeedUpAndReduceDeamonDamageParam","ReduceDamageFactorS"},ex3={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeDamageFactorBonus"}},
    [88]={format="-{ex1}% charge time, -{ex2}% damage taken",hint="Wicked Knight",ex1={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeSpeedFactorL"},ex2={"ChargeSpeedUpAndReduceDeamonDamageParam","ReduceDamageFactorS"},ex3={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeDamageFactorBonus"}},
    [89]={format="-{ex1}% charge time, -{ex2}% damage taken",hint="Wicked Knight",ex1={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeSpeedFactorS"},ex2={"ChargeSpeedUpAndReduceDeamonDamageParam","ReduceDamageFactorM"},ex3={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeDamageFactorBonus"}},
    [90]={format="-{ex1}% charge time, -{ex2}% damage taken",hint="Wicked Knight",ex1={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeSpeedFactorM"},ex2={"ChargeSpeedUpAndReduceDeamonDamageParam","ReduceDamageFactorM"},ex3={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeDamageFactorBonus"}},
    [91]={format="-{ex1}% charge time, -{ex2}% damage taken",hint="Wicked Knight",ex1={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeSpeedFactorL"},ex2={"ChargeSpeedUpAndReduceDeamonDamageParam","ReduceDamageFactorM"},ex3={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeDamageFactorBonus"}},
    [92]={format="-{ex1}% charge time, -{ex2}% damage taken",hint="Wicked Knight",ex1={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeSpeedFactorS"},ex2={"ChargeSpeedUpAndReduceDeamonDamageParam","ReduceDamageFactorL"},ex3={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeDamageFactorBonus"}},
    [93]={format="-{ex1}% charge time, -{ex2}% damage taken",hint="Wicked Knight",ex1={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeSpeedFactorM"},ex2={"ChargeSpeedUpAndReduceDeamonDamageParam","ReduceDamageFactorL"},ex3={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeDamageFactorBonus"}},
    [94]={format="-{ex1}% charge time, -{ex2}% damage taken",hint="Wicked Knight",bonusFormat="-{ex1}% charge time, +{ex3}% charged attack damage, -{ex2}% damage taken",ex1={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeSpeedFactorL"},ex2={"ChargeSpeedUpAndReduceDeamonDamageParam","ReduceDamageFactorL"},ex3={"ChargeSpeedUpAndReduceDeamonDamageParam","ChargeDamageFactorBonus"}},
    [95]={format="+{v1}% Lightning damage taken",hint="Molten Spirit"},
    [96]={format="-{v1}% Fall damage",hint="Cushioned Fall"},
    [98]={format="Heal for {v1}% of sell price (minimum {v2}); allies receive {v3}% of the effect",hint="Adventurous Appetite"},
    [99]={format="-{v1}% magick damage taken",hint="Fiendish Ward I"},
    [100]={format="-{v1}% magick damage taken",hint="Fiendish Ward II"},
    [101]={format="-{v1}% magick damage taken",hint="Fiendish Ward III"},
    [102]={format="+{v1}% recovery",hint="Improved Efficacy"},
    [103]={format="+{v2}% Defense/Magick Defense for {v1} s",hint="Bolstered Outset"},
    [104]={format="+{ex1}% chance of extra drops",hint="Relic Hunter",ex1={"RelicDropRateUpParam","AdditionalProbability","AdditionalProbabilityBonus"}},
    [105]={format="{v2} s",hint="Carnivore"},
    [107]={format="{v1}% chance of +{v2}% damage",hint="Arcane Wisdom"},
    [108]={format="At critical HP: -{v1}% prone/crawling recovery delay",hint="Moribund Recovery"},
    [109]={format="{v1}%",hint="Precipitate Revival"},
    [110]={format="-{v1}% damage taken",hint="Prone Defense"},
    [111]={format="{v2}% chance to recover {v1}% earlier",hint="Imperiled Reflexes"},
    [112]={format="{ex1} poison buildup (greatsword ×{ex4}/daggers ×{ex5}/bow ×{ex6}/staff ×{ex7}/archistaff ×{ex8}/magick bow ×{ex9}/censer ×{ex10}); {ex2} s cooldown, up to {ex3} activations per target",hint="Blighted Retort",ex1={"PoisonAttackParameter","BaseFactorOnPoison","BaseFactorOnPoisonBonus"},ex2={"PoisonAttackParameter","IntervalSec","IntervalSecBonus"},ex3={"PoisonAttackParameter","MaxActivationNum"},ex4={"PoisonAttackParameter","JobDataList.4.MultipleFactor"},ex5={"PoisonAttackParameter","JobDataList.3.MultipleFactor"},ex6={"PoisonAttackParameter","JobDataList.1.MultipleFactor"},ex7={"PoisonAttackParameter","JobDataList.2.MultipleFactor"},ex8={"PoisonAttackParameter","JobDataList.5.MultipleFactor"},ex9={"PoisonAttackParameter","JobDataList.7.MultipleFactor"},ex10={"PoisonAttackParameter","JobDataList.8.MultipleFactor"}},
    [113]={format="+{v2}% Defense/Magick Defense for {v1} s",hint="Siege Hardened"},
    [116]={format="-{v1}% Damage taken",hint="Intact Fortitude"},
    [117]={format="-{v1}% Stamina consumption",hint="Climber's Agility"},
    [118]={format="+{v1}/-{v2} Defense/Magick Defense",hint="Shadowbound"},
    [120]={format="-{v1}% Natural sleep/frozen/unconsciousness duration",hint="Animated Recovery"},
    [121]={format="-{v1}% Uphill stamina consumption/recovery penalties",hint="Hill Strider"},
    [122]={format="-{v1}% Stamina consumption",hint="Enduring Grip"},
    [123]={format="+{v2}% Damage",hint="Wind Rider"},
    [125]={format="+{v1}% Damage",hint="Leaping Strike"},
    [126]={format="+{v1}% base max HP",hint="Health Boost I"},
    [127]={format="+{v1}% base max HP",hint="Health Boost II"},
    [128]={format="+{v1}% base max HP",hint="Health Boost III"},
    [129]={format="+{v1}% base max stamina",hint="Stamina Boost I"},
    [130]={format="+{v1}% base max stamina",hint="Stamina Boost II"},
    [131]={format="+{v1}% base max stamina",hint="Stamina Boost III"},
    [132]={format="+{v1}%",hint="Slashing Resistance I"},
    [133]={format="+{v1}%",hint="Slashing Resistance II"},
    [134]={format="+{v1}%",hint="Striking Resistance I"},
    [135]={format="+{v1}%",hint="Striking Resistance II"},
    [136]={format="+{v1}%",hint="Fire Resistance I"},
    [137]={format="+{v1}%",hint="Fire Resistance II"},
    [138]={format="+{v1}%",hint="Lightning Resistance I"},
    [139]={format="+{v1}%",hint="Lightning Resistance II"},
    [140]={format="+{v1}%",hint="Ice Resistance I"},
    [141]={format="+{v1}%",hint="Ice Resistance II"},
    [142]={format="-{v1}% Stamina consumption",hint="Extended Dash"},
    [143]={format="{ex1}% random status chance (greatsword ×{ex4}/daggers ×{ex5}/bow ×{ex6}/duospear ×{ex7}/magick bow ×{ex8}/censer ×{ex9}); torched/asleep/silenced/frostbite; {ex2} s cooldown, up to {ex3} activations per target",hint="Chaotic Strike",ex1={"RandomStatusOnPhysicalAttackParameter","BaseProbability","BaseProbabilityBonus"},ex2={"RandomStatusOnPhysicalAttackParameter","IntervalSec","IntervalSecBonus"},ex3={"RandomStatusOnPhysicalAttackParameter","MaxActivationNum"},ex4={"RandomStatusOnPhysicalAttackParameter","JobDataList.4.MultipleFactor"},ex5={"RandomStatusOnPhysicalAttackParameter","JobDataList.3.MultipleFactor"},ex6={"RandomStatusOnPhysicalAttackParameter","JobDataList.1.MultipleFactor"},ex7={"RandomStatusOnPhysicalAttackParameter","JobDataList.6.MultipleFactor"},ex8={"RandomStatusOnPhysicalAttackParameter","JobDataList.7.MultipleFactor"},ex9={"RandomStatusOnPhysicalAttackParameter","JobDataList.8.MultipleFactor"}},
    [144]={format="{v1}% chance of +{v2}% damage",hint="Riotous Magick"},
    [145]={format="-{v1}% Melee charge time",hint="Swift Strike I"},
    [146]={format="-{v1}% Melee charge time",hint="Swift Strike II"},
    [147]={format="+{v1}% Damage",hint="Corrupted Foe Counter I"},
    [148]={format="+{v1}% Damage",hint="Corrupted Foe Counter II"},
    [149]={format="+{v1}% Damage",hint="Corrupted Foe Counter III"},
    [150]={format="+{v1}% Damage",hint="Deflect Strike"},
    [151]={format="-{v1} s charge time; +{v2}% damage",hint="Breakneck Toss"},
    [152]={format="+{v1}% Damage",hint="Improved Empale"},
    [153]={format="+{v1}% Damage",hint="Critical Shot"},
    [154]={format="When fully charged: +{v1}% damage",hint="Full Bend"},
    [155]={format="-{v1}% damage taken; +{v2}% Knockdown Resistance",hint="Fortified Invocation"},
    [156]={format="+{v1} s",hint="Extended Recovery"},
    [158]={format="+{v1}% Climbing speed",hint="Nimble Tread"},
    [159]={format="+{v1}% Damage",hint="Piercing Escalade"},
    [160]={format="+{v1} frames input window, +{v3}% combo damage",hint="Mighty Chain"},
    [161]={format="+{v1}% damage; +{v2} m range",hint="Extended Burst"},
    [162]={format="+{v1}% Damage",hint="Vertiginous Strike"},
    [163]={format="+{v1}% Recovery",hint="Restorative Bolts"},
    [164]={format="+{v1}% Torched/frozen/unconsciousness buildup",hint="Debilitating Bolts"},
    [165]={format="+{v1}%",hint="Phantasmal Tome"},
    [166]={format="+{v1}% Simulacrum max HP",hint="Perdurable Illusion"},
    [167]={format="Consecutive hits reduce damage by {ex1}%/{ex2}%/{ex3}%/{ex4}%/{ex5}% in sequence",hint="Equanimity",ex1={"ReduceDamageOnConsecutiveAttacksParam","ReduceDamageFactor.0.m_value"},ex2={"ReduceDamageOnConsecutiveAttacksParam","ReduceDamageFactor.1.m_value"},ex3={"ReduceDamageOnConsecutiveAttacksParam","ReduceDamageFactor.2.m_value"},ex4={"ReduceDamageOnConsecutiveAttacksParam","ReduceDamageFactor.3.m_value"},ex5={"ReduceDamageOnConsecutiveAttacksParam","ReduceDamageFactor.4.m_value"}},
    [168]={format="When near death (HP＜200 or HP＜25%), for {ex1} s: +{ex2}% Strength/Magick; +{ex3}% Defense/Magick Defense\n+{ex4}% Knockdown Power; -{ex5}% stagger/knockdown force taken",hint="Moribund Frenzy",ex1={"StatusUpOnLowHealthParam","DurationSec","BonusDurationSec"},ex2={"StatusUpOnLowHealthParam","Status.Attack"},ex3={"StatusUpOnLowHealthParam","Status.Defence"},ex4={"StatusUpOnLowHealthParam","Status.Blow"},ex5={"StatusUpOnLowHealthParam","Status.BlowResistance"}},
    [169]={format="-{v1}% Loss-gauge buildup",hint="Survival Instinct"},
    [170]={format="-{v1}% Struggle effort required",hint="Elusive"},
    [171]={format="-{v1}% Damage taken; -{v2}% status buildup taken",hint="Breath Resistance"},
    [172]={format="+{v2}% Defense/Magick Defense",hint="Improved Odds"},
    [173]={format="-{v1}% Damage taken",hint="Airborne Reflexes"},
    [175]={format="+{ex1} Knockdown Power",hint="Forceful Strikes",ex1={"BlowUpParam","NormalJobParams.0.AdditionalBlow"}},
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
    -- GetEnumerator/Get_Current/Get_Value not working
    local iter=im._ItemDataDict:call('System.Collections.IEnumerable.GetEnumerator()')
    local dup={}
    iter:MoveNext()
    while iter._current.value~=nil do
        local itemCommonParam=iter._current.value
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
    guiManager=sdk.get_managed_singleton("app.GuiManager")
    characterManager=sdk.get_managed_singleton("app.CharacterManager")    
    messageManager=sdk.get_managed_singleton("app.MessageManager")

    local om=sdk.get_managed_singleton("app.OptionManager")
    if guiManager==nil or characterManager==nil or messageManager==nil or om==nil or om._OptionItems==nil then return end
    local optionID=sdk.find_type_definition("app.OptionID"):get_field("TextLanguage"):get_data()
    if optionID==nil then return end
    if not om._OptionItems:ContainsKey(optionID) then
        Log("Can't find _OptionItems[optionID]")
        return
    end
    local optionItem=om._OptionItems:get_Item(optionID)
    local lng=optionItem:get_FixedValueModel():get_StringValue()

    if lng==prevInitLanguage then
        Log("Ignore dup init")
        return
    end
    initialized=false

    local filename=string.format("%s.%s.json",modname,lng)
    if config.specifyTransFile~="" then
        filename=string.format("%s.%s.json",modname,config.specifyTransFile)
    end
    Log("Try Load ",lng)
    local tmp=json.load_file(filename)
    if tmp~=nil and tmp.FieldFormat~=nil then
        FieldFormat=tmp.FieldFormat
        ItemBuffFormat=tmp.ItemBuffFormat
        WeaponSpecialFormat={}
        --convert string key to int
        for k,v in pairs(tmp.WeaponSpecialFormat or {}) do            
            WeaponSpecialFormat[tonumber(k) or k]=v
        end
        RingSpecialFormat={}
        for k,v in pairs(tmp.RingSpecialFormat or {}) do
            RingSpecialFormat[tonumber(k)]=v
        end
        AbilityFormat={}
        for k,v in pairs(tmp.AbilityFormat or {}) do
            AbilityFormat[tonumber(k)]=v
        end
        EquipmentAbilityFormat={}
        for k,v in pairs(tmp.EquipmentAbilityFormat or {}) do
            EquipmentAbilityFormat[tonumber(k)]=v
        end
        Log("Load From",filename)
        dataFileInfo.name="Data file: "..filename
    else
        Log("Invalid File,Use default")
    end
    ItemDescCache={}
    SkillDescCache={}
    EquipmentSkillDescCache={}
    WeaponCharaMsgCache=nil

    --Init SkillName2Id
    SkillName2Id={}

    local type=sdk.find_type_definition("app.Character.JobEnum")
    local fields=type:get_fields()
    for _,field in pairs(fields) do
        if field:get_data()~=nil and field:get_data()>0 then
            local job=field:get_data()                       
            local abilitys=guiManager:getAbilitySets(job)
            -- GetEnumerator/Get_Current/Get_Value not working
            local iter=abilitys:call('System.Collections.IEnumerable.GetEnumerator()')
            iter:MoveNext()
            while iter._current.value~=nil do
                local ability=iter._current.value
                local skillName= messageManager:getMessage(ability:get_AbilityName())
                SkillName2Id[skillName]=ability:get_AbilityID()
                iter:MoveNext()
            end
        end
    end
    prevInitLanguage=lng
    initialized=true
end


--json.dump_file("BetterBetterItemDescription.English.json",{FieldFormat=FieldFormat,RingSpecialFormat=RingSpecialFormat,AbilityFormat=AbilityFormat})
--Init
sdk.hook(sdk.find_type_definition("app.OptionManager"):get_method("app.ISystemSaveData.loadSystemSaveData(app.SaveDataBase)"),nil,Init)
sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),nil,Init)
--Init()

local function float2stringEX(v)
    if v-math.floor(v)<0.0001 then
        return tostring(math.floor(v))
    end
    return string.format("%.2f",v)
end
--printJobAbility()
--printRings()
--printEnum("app.ItemEquipCategory")
--printEnum("via.Language")
local function Join(...)
    local ret=""
    for k,v in ipairs{...} do
        if ret~="" and v~="" then ret=ret.."/" end
        ret=ret..v
    end
    return ret
end
local equipParamType=sdk.find_type_definition("app.EquipParam")
local setEquipParam=equipParamType:get_method("setParam(app.ItemCommonParam, app.ItemDefine.EnhanceParam, app.ItemDefine.EquipmentAbilityParam)")
local noEnhance=sdk.find_type_definition("app.ItemDefine.EnhanceParam"):get_field("None")
local equipParams={}
local plainAbility=ValueType.new(sdk.find_type_definition("app.ItemDefine.EquipmentAbilityParam"))
local abilityFields={"Slot1","Slot2","Slot3","Slot4","IsAppraised","PhysicalParameter","MagicParameter","BlowParameter","WeightParameter"}
local function GetEquipFields(param,ability,enhance,numbers)
    if equipParams[1]==nil then
        for i=1,4 do
            equipParams[i]=equipParamType:create_instance()
            equipParams[i]:add_ref()
            equipParams[i]:call(".ctor()")
        end
    end
    -- setParam accumulates; reset private objects before each calculation.
    equipParams[1]:copyFrom(equipParams[3])
    setEquipParam:call(equipParams[1],param,noEnhance:get_data(),ability)
    local bonus=ability.Bonus
    if bonus~=0 then
        for _,field in ipairs(abilityFields) do
            plainAbility:set_field(field,ability:get_field(field))
        end
        plainAbility:set_field("Bonus",0)
        equipParams[2]:copyFrom(equipParams[3])
        setEquipParam:call(equipParams[2],param,noEnhance:get_data(),plainAbility)
    end
    local enhanced=enhance._Num~=0
    if enhanced then
        equipParams[4]:copyFrom(equipParams[3])
        setEquipParam:call(equipParams[4],param,enhance,ability)
    end
    local ret={}
    local function stat(field,getter,randomField)
        local base=equipParams[1]:call("get_"..getter)
        local extra=bonus~=0 and (base-equipParams[2]:call("get_"..getter)) or 0
        local value=enhanced and equipParams[4]:call("get_"..getter) or base
        local upgrade=value-base
        local random=randomField and ability:get_field(randomField) or 0
        local format=FieldFormat[field]
        ret[field]=""
        if type(format)=="table" then format=format.enable and format.type=="String" and format.format or nil end
        if value~=0 and format~=nil then
            local details={}
            local unit=format:find("%%",1,true) and "%" or ""
            if random~=0 then details[#details+1]=string.format("%+d",random)..unit end
            if extra~=0 then details[#details+1]=string.format("%+d",extra)..unit end
            if upgrade~=0 then details[#details+1]=string.format("%+d",upgrade)..unit end
            local number=tostring(value)..unit
            if #details>0 then number=number.."("..table.concat(details,",")..")" end
            if numbers~=nil then numbers[field]=number end
            ret[field]=string.format(format:gsub("%%s%%%%","%%s"),number)
        end
    end
    local weapon=param._EquipCategory<=1
    local shield=param._EquipCategory==1
    stat(weapon and "_PhysicalAttack" or "_PhysicalDefence",weapon and (shield and "ShieldAttack" or "PhysicalAttack") or "PhysicalDefence","PhysicalParameter")
    stat(weapon and "_MagicAttack" or "_MagicDefence",weapon and "MagicAttack" or "MagicDefence","MagicParameter")
    stat(weapon and "_Blow" or "_BlowResistRate",weapon and (shield and "ShieldBlow" or "Blow") or "BlowResistRate","BlowParameter")
    if enhanced and weapon then stat("_BlowGuard","BlowGuard") end
    if bonus==2048 or numbers~=nil and not weapon then stat("_SlashDefenceRate","SlashDefenceRate") end
    if bonus==4096 or numbers~=nil and not weapon then stat("_StrikeDefenceRate","StrikeDefenceRate") end
    if bonus==16 or bonus==32 or bonus==64 or bonus==128 then stat("_ElementStore","ElementStore") end
    return ret
end
local function TranslateFields(param,paramtype,equipFields)
    local ret=""
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
        if equipFields~=nil and equipFields[fieldname]~=nil then
            fieldMsg=equipFields[fieldname]
            equipFields[fieldname]=nil
        elseif format ~=nil then
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
                    if enumstr~=nil then
                        if fieldname=="_Element" then
                            local enchantParam=characterManager:get_HumanParam().JobParam.Job03Parameter.EnchantParam
                            local baseData=enchantParam:getBaseData(tonumber(data))
                            fieldMsg=fieldMsg..string.format(format.format,float2stringEX(baseData.PhysicalFactor*100),enumstr)
                        else
                            fieldMsg=fieldMsg..string.format(format.format,enumstr)
                        end
                    end
                end
            end
        else
            --Log("Ignore "..fieldname)
            --Log(string.format("%s=nil,",fieldname))
        end
        ret=Join(ret,fieldMsg)
    end
    return ret
end

--notice sdk.create_instance not work.
local mycampBuffParam=ValueType.new(sdk.find_type_definition("app.HumanSpecialBuffDefine.Camp"))
local function TranslateItemBuff(param)
    if ItemBuffFormat~=nil then
        local player=characterManager:get_ManualPlayer()
        local buffParam=player:get_Human():get_Param().SpecialBuffParam
        local format=ItemBuffFormat
        local itemBuffParam=buffParam:getItemParam(param._Id)
        local msg=""
        if itemBuffParam~=nil then
            if itemBuffParam.AttackFactor~=0 then
                msg=msg..string.format(format.AttackFactor,tostring(itemBuffParam.AttackFactor))
            end
            if itemBuffParam.DefenceFactor~=0 then
                msg=msg..string.format(format.DefenceFactor,tostring(itemBuffParam.DefenceFactor))
            end
            if itemBuffParam.StatusConditionResistFactor~=0 then
                msg=msg..string.format(format.StatusConditionResistFactor,tostring(itemBuffParam.StatusConditionResistFactor))
            end
            if itemBuffParam.StaminaRecoverFactor~=0 then
                msg=msg..string.format(format.StaminaRecoverFactor,tostring(itemBuffParam.StaminaRecoverFactor))
            end
            msg=msg..string.format(format.Sec,float2stringEX(itemBuffParam.Sec))
        end
        local drinkingBuffParam=buffParam:getDrinkingParam(param._Id)
        if drinkingBuffParam~=nil then
            if drinkingBuffParam.AttackFactor~=0 then
                msg=msg..string.format(format.AttackFactor,tostring(drinkingBuffParam.AttackFactor))
            end
            if drinkingBuffParam.DefenceFactor~=0 then
                msg=msg..string.format(format.DefenceFactor,tostring(drinkingBuffParam.DefenceFactor))
            end
            if drinkingBuffParam.StaminaRecoverFactor~=0 then
                msg=msg..string.format(format.StaminaRecoverFactor,tostring(drinkingBuffParam.StaminaRecoverFactor))
            end
            msg=msg..string.format(format.Sec,float2stringEX(drinkingBuffParam.SecBuff))
        end
        --a static method
        local getBuffMethod=sdk.find_type_definition("app.CampDefine"):get_method("tryGetBuff(app.ItemIDEnum, app.HumanSpecialBuffDefine.Camp)")
        local success=getBuffMethod(nil,param._Id,mycampBuffParam)
        if success then
            local campBuff=buffParam:getCampParam(mycampBuffParam.value__)
            if campBuff then
                msg=msg..format.Camp
                if campBuff.AttackFactor~=0 then
                    msg=msg..string.format(format.AttackFactor,tostring(campBuff.AttackFactor))
                end
                if campBuff.DefenceFactor~=0 then
                    msg=msg..string.format(format.DefenceFactor,tostring(campBuff.DefenceFactor))
                end
                if campBuff.StaminaFactor~=0 then
                    msg=msg..string.format(format.StaminaRecoverFactor,tostring(campBuff.StaminaFactor))
                end
                if campBuff.MaxHpDamageFactor~=0 then
                    msg=msg..string.format(format.MaxHpDamageFactor,tostring(campBuff.MaxHpDamageFactor))
                end
            end
        end
        return msg
    end
    return ""
end
local curveWarnings={}
local keyFrameType=sdk.find_type_definition("via.KeyFrame")

-- TDB83 no longer exposes AnimationCurve.getKeys. Read its native KeyFrame
-- array after verifying the complete current NativeArray layout.
local function GetCurveKeys(curve)
    local count=curve:getKeysCount()
    if keyFrameType==nil or keyFrameType:get_valuetype_size()~=0x10 or count<1 or count>256 then
        return nil,"keyFrameSize="..tostring(keyFrameType and keyFrameType:get_valuetype_size())..", count="..tostring(count)
    end
    local size=curve:get_object_size()
    if size~=0x48 or curve:read_dword(0x10)~=count or
       math.abs(curve:read_float(0x18)-curve:get_MaxTime())>=0.0001 or
       math.abs(curve:read_float(0x1C)-curve:get_MinValue())>=0.0001 or
       math.abs(curve:read_float(0x20)-curve:get_MaxValue())>=0.0001 or
       curve:read_dword(0x40)~=count or
       curve:read_dword(0x44)<count or curve:read_dword(0x44)>256 then return nil,"layout validation failed" end
    local keyData=curve:read_qword(0x38)
    if keyData<0x10000 or keyData>=0x800000000000 or keyData%8~=0 then return nil,"invalid key pointer "..tostring(keyData) end
    local keys={}
    for i=0,count-1 do
        local key=sdk.to_valuetype(sdk.to_ptr(keyData+i*0x10),keyFrameType)
        local t=key:call("GetTime")
        local v=key.value
        if t==nil or v==nil or t~=t or v~=v or (i>0 and t<keys[i-1].t) then return nil end
        keys[i]={t=t,v=v}
    end
    if math.abs(keys[0].t-curve:get_MinTime())>=0.0001 or
       math.abs(keys[count-1].t-curve:get_MaxTime())>=0.0001 then return nil end
    return keys
end

local function FormatCurveDescription(template,param,referenceId)
    if not param then return "" end
    local ok,result=pcall(function()
        local keys,curveError=GetCurveKeys(param.Curve)
        if not keys then error("Unsupported AnimationCurve memory layout: "..tostring(curveError)) end
        return (string.gsub(template,"{([tv])(%d+)}",function(component,index)
            local key=keys[tonumber(index)]
            if not key then error("Missing curve key "..index) end
            if component=="t" then return float2stringEX(key.t) end
            return float2stringEX(key.v)
        end))
    end)
    if ok then return result end
    if not curveWarnings[referenceId] then
        log.warn("["..modname.."] "..referenceId..": "..tostring(result))
        curveWarnings[referenceId]=true
    end
    return ""
end

local function TranslateRingSP(param)
    local sp=param._Special
    local format=RingSpecialFormat[param._Id] or RingSpecialFormat[sp]
    if format==nil or format.enable==false then return "" end
    local ret=format.format
    if format.efficacy then
        local params=sdk.get_managed_singleton("app.ItemManager"):get_ArmorSpecialEfficacyParamProp()
        for i=0,params:get_Count()-1 do
            local entry=params[i]
            local ids=entry:get_ItemIDListProp()
            for j=0,ids:get_Count()-1 do
                if ids[j].value__==param._Id then
                    return (string.gsub(ret,"{v1}",tostring(entry:get_AttackRateProp())))
                end
            end
        end
        return ""
    elseif format.curve then
        local additionalData=sdk.get_managed_singleton("app.ItemManager"):get_JewelryAdditionalDataDict()[sp]
        ret=FormatCurveDescription(ret,additionalData,"ring:"..tostring(sp))
    else
        ret=string.gsub(ret,"{v1}",tostring(param._SpecialValue))
        ret=string.gsub(ret,"{v2}",tostring(param._SpecialValue2))
        ret=string.gsub(ret,"{v3}",tostring(param._SpecialValue3))
        ret=string.gsub(ret,"{dr}",function() return tostring(sdk.get_managed_singleton("app.ItemManager"):get_JewelryAdditionalData().DropUpParam:findSetting(param._Id).DropRateUp) end)
        ret=string.gsub(ret,"{dc}",function() return tostring(sdk.get_managed_singleton("app.ItemManager"):get_JewelryAdditionalData().DropUpParam:findSetting(param._Id).DropCountUp) end)
        ret=string.gsub(ret,"{sr(%d+)}",function(job) return string.format("%g",sdk.get_managed_singleton("app.ItemManager"):get_JewelryAdditionalData().RecoverStaminaOnNormalAttackParam:getJobData(tonumber(job)).MultipleFactor) end)
        ret=string.gsub(ret,"{sm(%d+)}",function(job) return string.format("%g",sdk.get_managed_singleton("app.ItemManager"):get_JewelryAdditionalData().RecoverStaminaOnNormalAttackParam:getJobData(tonumber(job)).MaxValue) end)
    end
    return ret
end

local function TranslateWeaponSP(param)
    local ret=""
    if WeaponSpecialFormat and param._Id and WeaponSpecialFormat[param._Id] and WeaponSpecialFormat[param._Id].enable then
        local im=sdk.get_managed_singleton("app.ItemManager")
        local addiParam=im:get_WeaponAdditionalDataDict():get_Item(param._WeaponId)
        if addiParam~=nil then
            local msg=WeaponSpecialFormat[param._Id].format
            if WeaponSpecialFormat[param._Id].curve then--use curve
                msg=FormatCurveDescription(msg,addiParam,"weapon:"..tostring(param._Id))
            elseif WeaponSpecialFormat[param._Id].wp10_003 then--梦想路，                
            --TODO
            else--Use special value
                msg=string.gsub(msg,"{v1}",float2stringEX(addiParam:get_SpecialValue1Prop()))
                msg=string.gsub(msg,"{v2}",float2stringEX(addiParam:get_SpecialValue2Prop()))
            end
            ret=Join(ret,msg)
        end
    end    
    if WeaponSpecialFormat and WeaponSpecialFormat["SpecialEfficacy"] and WeaponSpecialFormat["SpecialEfficacy"].enable then
        local im=sdk.get_managed_singleton("app.ItemManager")
        if weaponCharaDamageMsgCache==nil then
            weaponCharaDamageMsgCache={}
            local weaponCharaParams=im:get_WeaponSpecialEfficacyParamProp()
            for i=0,weaponCharaParams:get_Count()-1 do
                local idlist= weaponCharaParams[i]:get_WeaponIDListProp()
                local msg=WeaponSpecialFormat["SpecialEfficacy"].format
                msg=string.gsub(msg,"{v1}",tostring(weaponCharaParams[i]:get_AttackRateProp()))
                for j=0,idlist:get_Count()-1 do
                    local id=idlist[j].value__
                    weaponCharaDamageMsgCache[id]=Join((weaponCharaDamageMsgCache[id] or ""),msg)
                end
            end
        end
        ret=Join(ret, weaponCharaDamageMsgCache[param._WeaponId] or "")
    end
    return ret
end
local function isWeapon(param)
    if param==nil then return false end
    return param:get_type_definition():is_a("app.ItemWeaponParam") 
end
local function isItem(param)
    if param==nil then return false end
    return param:get_type_definition():is_a("app.ItemDataParam") 
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

local getMessageGuid=sdk.find_type_definition("via.gui.message"):get_method("getGuidByName(System.String)")
local function RemoveLineBreaks(originalMessage)
    for _=1,4 do
        local replaced
        originalMessage,replaced=string.gsub(originalMessage,"<REF%s+([^<>%s]+)%s*>",function(name)
            return messageManager:getMessage(getMessageGuid:call(nil,name))
        end)
        if replaced==0 then break end
    end
    originalMessage=string.gsub(originalMessage,"[\r\n]+"," ")
    return originalMessage
end

local function GetItemDetail(itemCommonParam,ability,enhance,equipFields)
    local ret=""
    local itemParam=itemCommonParam:get_ItemParam()
    equipFields=equipFields or ability and GetEquipFields(itemCommonParam,ability,enhance)
    for _,type in pairs(ItemParamTypes) do
        if itemCommonParam:get_type_definition():is_a(type) then
            ret=ret..TranslateFields(itemCommonParam,sdk.find_type_definition(type),equipFields)
        end
    end
    for _,fieldMsg in pairs(equipFields or {}) do ret=Join(ret,fieldMsg) end
    if isWeapon(itemCommonParam) then
        ret=Join(ret,TranslateWeaponSP(itemCommonParam))
    end
    if isRing(itemCommonParam) then
        ret=Join(ret,TranslateRingSP(itemCommonParam))
    end
    if isItem(itemCommonParam) then
        ret=Join(ret,TranslateItemBuff(itemCommonParam))
    end
    
    return RemoveLineBreaks(ret)
end

local function GetOrAddItemDesc(originalMessage,storageData,equipFields)
    local itemCommonParam=storageData._ItemData
    local ability=storageData._Ability
    local enhance=storageData._Enhance
    local uncached=equipFields~=nil or itemCommonParam:get_IsEquip() and (ability.PhysicalParameter~=0 or ability.MagicParameter~=0
        or ability.BlowParameter~=0 or ability.WeightParameter~=0 or ability.Bonus~=0 or enhance._Num~=0)
    local Id=itemCommonParam._Id
    local text=nil
    if not uncached then text=ItemDescCache[Id] end
    if text==nil then
        local appendtext=GetItemDetail(itemCommonParam,uncached and ability or nil,enhance,equipFields)
        text=string.format("%s\n%s",RemoveLineBreaks(originalMessage),appendtext)
        if not uncached then
            ItemDescCache[Id]=text
            Log("Add Item Desc To Cache")
            Log(text)
        end
    end
    --can't cache managed_string ,causes crash
    return sdk.create_managed_string(text)
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
            SkillDescCache[Id]=string.format("%s\n%s",originalMessage,appendtext)
            Log(SkillDescCache[Id])
        else
            return sdk.create_managed_string(originalMessage)
        end

    end
    --can't cache managed_string ,causes crash
    --Log(SkillDescCache[Id])
    return sdk.create_managed_string(SkillDescCache[Id])
end

local function GetEquipmentAbilityParamValue(para,field)
    for key in string.gmatch(field,"[^.]+") do
        if para==nil then return nil end
        local index=tonumber(key)
        if index~=nil then
            para=para:get_element(index)
        else
            para=para:get_field(key)
        end
    end
    return para
end

local function GetEquipmentAbilityDetail(Id,isBoost)
    local format=EquipmentAbilityFormat[Id]
    if format==nil then return "" end
    local ref=string.match(format.format,"^{r(%d+)}$")
    if ref~=nil then
        format=EquipmentAbilityFormat[tonumber(ref)]
        if format==nil then return "" end
    end
    local itemManager=sdk.get_managed_singleton("app.ItemManager")
    if itemManager==nil then return "" end
    isBoost=isBoost and itemManager:isEquipmentAbilityBonusAvailable(Id)
    local ret=isBoost and format.bonusFormat or format.format
    local missingParam=false
    ret=string.gsub(ret,"{(ex%d+)}",function(key)
        local fields=format[key]
        if fields==nil then missingParam=true; return "" end
        local para=itemManager:get_EquipmentAbilityData()
        para=GetEquipmentAbilityParamValue(para,fields[1])
        local field=isBoost and fields[3] or fields[2]
        local value=GetEquipmentAbilityParamValue(para,field)
        if value==nil then missingParam=true; return "" end
        return float2stringEX(value)
    end)
    if missingParam then return "" end
    local para=nil
    if string.find(ret,"{v%d+}") or string.find(ret,"{sfenc%d+}") then
        local abilityParam=itemManager.EquipmentAbilityFactors
        if abilityParam==nil then return "" end
        para=abilityParam:get_element(Id)
        if para==nil then return "" end
        local prefix=isBoost and "BonusValue" or "Value"
        for i=1,3 do
            local value=para:get_field(prefix..i)
            ret=string.gsub(ret,"{v"..i.."}",float2stringEX(value))
        end
    end
    if string.find(ret,"{iceenc}",1,true) or string.find(ret,"{sfenc%d+}") then
        -- Job03Parameter.EnchantParam stores shared enchant parameters for all jobs.
        local enchantParam=GetEquipmentAbilityParamValue(characterManager:get_HumanParam(),"JobParam.Job03Parameter.EnchantParam")
        if enchantParam==nil then return "" end
        ret=string.gsub(ret,"{iceenc}",function()
            local baseData=enchantParam:getBaseData(2)
            if baseData==nil then missingParam=true; return "" end
            return string.format("%g",baseData.PhysicalFactor*100)
        end)
        ret=string.gsub(ret,"{sfenc(%d+)}",function(job)
            local value=para:get_field(isBoost and "BonusValue1" or "Value1")
            local jobData=enchantParam:getJobData(tonumber(job))
            if jobData==nil or value<=0 then missingParam=true; return "" end
            return string.format("%g",math.floor(value*math.max(jobData.StatusDamageFactor,0))/value)
        end)
        if missingParam then return "" end
    end
    return ret
end

local function GetOrAddEquipmentSkillDesc(originalMessage,Id,isBoost)
    local cache=EquipmentSkillDescCache[Id]
    if cache==nil or cache[isBoost]==nil then
        local appendtext=GetEquipmentAbilityDetail(Id,isBoost)
        if appendtext=="" then return sdk.create_managed_string(originalMessage) end
        if cache==nil then
            cache={}
            EquipmentSkillDescCache[Id]=cache
        end
        cache[isBoost]=Id==47 and appendtext or string.format("%s\n%s",originalMessage,appendtext)
    end
    return sdk.create_managed_string(cache[isBoost])
end

local tmpEquipmentSkillWindow=nil
local tmpEquipmentSkillId=nil
local tmpEquipmentSkillBoost=false
sdk.hook(
    sdk.find_type_definition("app.GUIBase.EquipAbilityInfoRef"):get_method("setInfo(app.EquipmentAbilityID, System.Boolean)"),
    function (args)
        if not initialized then return end
        local Id=sdk.to_int64(args[3])&0xff
        if EquipmentAbilityFormat[Id]==nil then return end
        tmpEquipmentSkillWindow=sdk.to_managed_object(args[2])
        tmpEquipmentSkillId=Id
        tmpEquipmentSkillBoost=(sdk.to_int64(args[4])&0xff)~=0
    end,
    function ()
        if tmpEquipmentSkillWindow~=nil then
            local text=tmpEquipmentSkillWindow.TxtDescription
            local originalMessage=text:get_Message() or messageManager:getMessage(text:get_MessageId())
            if originalMessage~=nil then
                text:set_AutoWrap(true)
                text:set_AutoRegionFit(sdk.find_type_definition("via.gui.RegionFitType"):get_field("Both"):get_data())
                text:set_Message(GetOrAddEquipmentSkillDesc(originalMessage,tmpEquipmentSkillId,tmpEquipmentSkillBoost))
            end
            tmpEquipmentSkillWindow=nil
        end
    end
)

local tmpEquipWindow=nil
local tmpEquipNumbers=nil
local equipStatusFields={
    [0]="_PhysicalAttack",[1]="_PhysicalDefence",[2]="_MagicAttack",[3]="_MagicDefence",
    [4]="_Blow",[5]="_BlowResistRate",[12]="_SlashDefenceRate",[13]="_StrikeDefenceRate",
}
local tmpItemWindow=nil
local tmpItem=nil
sdk.hook(
    sdk.find_type_definition("app.GUIBase.ItemWindowRef"):get_method("setup(app.ItemDefine.StorageData, System.Int32, System.Boolean, System.Boolean)"),
    function (args)
        if not initialized then return end
        local this=sdk.to_managed_object(args[2])
        local storageData=sdk.to_valuetype(args[3],sdk.find_type_definition("app.ItemDefine.StorageData"))
        if storageData._ItemData==nil or this ==nil then return end
        tmpItemWindow=this
        tmpItem=storageData
    end,
    function ()
        if tmpItemWindow~=nil and tmpItem~=nil then
            --print(tmpItemWindow._TxtInfo:get_Message():ToString())
            local equipFields=nil
            if tmpEquipWindow~=nil and tmpEquipWindow.ItemWindow==tmpItemWindow and tmpItem._ItemData:get_IsEquip() and not isRing(tmpItem._ItemData) then
                tmpEquipNumbers={}
                equipFields=GetEquipFields(tmpItem._ItemData,tmpItem._Ability,tmpItem._Enhance,tmpEquipNumbers)
                for _,field in pairs(equipStatusFields) do equipFields[field]="" end
                if tmpItem._ItemData:get_type_definition():is_a("app.ItemArmorParam") then
                    for _,field in pairs({"_FireDefence","_IceDefence","_ThunderDefence","_LightDefence","_DarkDefence",
                        "_FireResist","_IceResist","_ThunderResist","_PoisonResist","_SleepResist","_SilentResist",
                        "_StoneResist","_WaterResist","_OilResist","_FaintResist","_ColdResist"}) do equipFields[field]="" end
                elseif isWeapon(tmpItem._ItemData) then
                    for _,field in pairs({"_PoisonStore","_SleepStore","_SilentStore","_StoneStore","_WaterStore","_OilStore"}) do equipFields[field]="" end
                end
            end
            local message=GetOrAddItemDesc(tmpItemWindow._TxtInfo:get_Message(),tmpItem,equipFields)
            tmpItemWindow._TxtInfo:set_AutoWrap(true)
            tmpItemWindow._TxtInfo:set_AutoRegionFit(sdk.find_type_definition("via.gui.RegionFitType"):get_field("Both"):get_data())
            tmpItemWindow._TxtInfo:set_Message(message)
            tmpItemWindow=nil
            tmpItem=nil
        end
    end
)

local function GetCompareArrow(item)
    local child=item.CompareControl:get_Child()
    while child~=nil do
        if child:get_Name()=="PNL_RArrow_01S" then return child end
        child=child:get_Next()
    end
end

local getStatusName=sdk.find_type_definition("app.GUIBase"):get_method("getStatusName")
for _,type in pairs({"app.ui060301_00","app.ui060401_00"}) do
    sdk.hook(
        sdk.find_type_definition(type):get_method("updateItemInfoDisp"),
        function (args)
            if not initialized then return end
            tmpEquipWindow=sdk.to_managed_object(args[2])
            tmpEquipNumbers=nil
        end,
        function ()
            if tmpEquipWindow~=nil then
                local numbers={}
                for id,field in pairs(equipStatusFields) do
                    numbers[getStatusName:call(nil,id)]=tmpEquipNumbers and tmpEquipNumbers[field]
                end
                local list=tmpEquipWindow.ItemDetail._StatusList
                local count=list.InfoList:get_Count()
                for i=0,count-1 do
                    local number=numbers[list.InfoList:get_Item(i).Name]
                    local item=list:call("getItem(System.Int32)",i)
                    if item~=nil then
                        local text=item.TxtVal
                        local size=text:get_RegionSize()
                        local width=56
                        local extra=tmpEquipNumbers~=nil and width*3 or 0
                        size.w=width+extra
                        text:set_RegionSize(size)
                        local nameSize=item.TxtName:get_RegionSize()
                        nameSize.w=318-extra
                        item.TxtName:set_RegionSize(nameSize)
                        item.TxtName:set_AutoRegionFit(sdk.find_type_definition("via.gui.RegionFitType"):get_field(extra~=0 and "Both" or "Horizontal"):get_data())
                        -- Native ui01350901 positions. Right-anchored text expands left as its region widens.
                        local position=text:get_Position()
                        text:set_Position(Vector3f.new(478,position.y,position.z))
                        local compare=item.CompareControl:get_Position()
                        item.CompareControl:set_Position(Vector3f.new(0,compare.y,compare.z))
                        local left=item.TxtVal0:get_Position()
                        item.TxtVal0:set_Position(Vector3f.new(384-extra,left.y,left.z))
                        local arrow=GetCompareArrow(item)
                        if arrow~=nil then
                            local position=arrow:get_Position()
                            arrow:set_Position(Vector3f.new(406-extra,position.y,position.z))
                        end
                        text:set_AutoRegionFit(sdk.find_type_definition("via.gui.RegionFitType"):get_field(number~=nil and "Both" or "Horizontal"):get_data())
                        if number~=nil then text:set_Message(text:get_Message().."["..number.."]") end
                    end
                end
            end
            tmpEquipWindow=nil
            tmpEquipNumbers=nil
        end
    )
end

local function LogTypeMethods(game_object)
    x=game_object:get_type_definition():get_methods()
    for k,v in pairs(x) do
        Log(v:get_name())
    end
end


local tmpJobWindow=nil
local tmpStatusWindow=nil
local tmpSkillInfo=nil
--Job NormalSkill CustomSkill Ability other
local MainContentsInfoKindAbility=sdk.find_type_definition("app.ui040101_00.MainContentsInfo.Kind"):get_field("Ability"):get_data()
local MainContentsInfoKindOther=sdk.find_type_definition("app.ui040101_00.MainContentsInfo.Kind"):get_field("Other"):get_data()

--in Augments tab
sdk.hook(
    --sdk.find_type_definition("app.GUIBase.ItemWindowRef"):get_method("setup(app.ItemDefine.StorageData)"),
    sdk.find_type_definition("app.ui040101_00"):get_method("setupAbilityInfoWindow()"),
    function (args)
        if not initialized then return end
        local this=sdk.to_managed_object(args[2])
        tmpJobWindow=this
    end,
    function ()
        if tmpJobWindow~=nil then
            local abilityId=nil
            local cursor=tmpJobWindow._Main_ContentsListCtrl:get_SelectedInfo()
            local rcursor=tmpJobWindow._Ability_EqListCtrl:get_SelectedInfo()

            if tmpJobWindow._IsSelectEquipContents then
                abilityId=rcursor and rcursor.AbilityID
            elseif cursor and cursor.ContenstsType==MainContentsInfoKindAbility and cursor.Ability then
                abilityId=cursor.Ability.AbilityID
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
        if not initialized then return end
        local this=sdk.to_managed_object(args[2])
        tmpJobWindow=this
    end,
    function ()
        if tmpJobWindow~=nil then
            local abilityId=nil
            local cursor=tmpJobWindow._Job_AbilityListCtrl:get_SelectedInfo()
            -- is selecting ability in left
            --print("---",abilityId,tmpJobWindow._TxtJobAbilityInfo:get_Message())
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
--Status UI
sdk.hook(sdk.find_type_definition("app.ui060601_01"):get_method("setupSkillDetail(app.ui060601_01.SkillInfo)"),
function(args)
    if not initialized then return end
    tmpStatusWindow=sdk.to_managed_object(args[2])
    tmpSkillInfo=sdk.to_managed_object(args[3])
end,
function()
    if tmpStatusWindow~=nil then
        local originalMessage= messageManager:getMessage(tmpStatusWindow.Movie.TxtDetail:get_MessageId())
        --DispType 1:customskill 2:normal 3:augment
        if tmpSkillInfo.DispType==3 then
            local nameText=messageManager:getMessage(tmpSkillInfo.NameId)
            if SkillName2Id[nameText]~=nil then
                tmpStatusWindow.Movie.TxtDetail:set_Message(GetOrAddSkillDesc(originalMessage,SkillName2Id[nameText]))
            end
        end
        tmpStatusWindow=nil
        tmpSkillInfo=nil
    end
end)

local frame_ct=0
re.on_frame(function()
    if not initialized then
        frame_ct=frame_ct+1
        if frame_ct>=600 then
            frame_ct=0
            Init()
        end
    end
end)

--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,function() ItemDescCache={} SkillDescCache={} EquipmentSkillDescCache={} WeaponCharaMsgCache=nil end) end
