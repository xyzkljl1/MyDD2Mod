local modname="WeaponInAss"
local configfile=modname..".json"
local defaultOffset={
    ["default"]={
        --[1]={{10.0,0.0,-0.0},{-0,0,0},1.0},
        --fighter shield
        [2]={{-0.2,-0.4,0.1},{0,0,0},1.0}
    },
    --fighter weapon
    ["wp00"]={
        [1]={{0.3,0.25,-0.35},{-60,0,0},1.0}
        --[1]={{0.3,0.55,-0.85},{120,0,0},1.0}
    },
    ["wp01"]={
    },
    --warrior sword
    ["wp02"]={
        [1]={{0.10,-0.35,0.1},{30,90,140},1.0}
    },
    --thief
    ["wp03"]={
        [1]={{0.25,0.45,-0.55},{-120,180,0},1.0},
        [2]={{0.05,-0.15,-0.55},{70,30,0},1.0},
    },
    --archer bow
    ["wp04"]={
        [1]={{-0.5,-0.45,0.05},{0,100,110},1.0}
    },
    --mag archer bow
    ["wp05"]={
        [1]={{-0.0,-0.45,0.15},{0,100,110},1.0}
    },
    ["wp06"]={
        [1]={{0.25,-0.05,-0.35},{70,0,0},1.0},
        [2]={{0.25,-0.05,-0.35},{70,0,0},1.0}
    },
    --mage
    ["wp07"]={
        [1]={{0.25,-0.05,-0.35},{70,0,0},2.0}
    },    
    --sor
    ["wp08"]={
        [1]={{-1,-0.5,0.0},{0,0,100},1.0}
    },
    --Ä§½£Ê¿
    ["wp09"]={
        [1]={{-1.05,-0.5,0.1},{0,0,100},1.0}
    },
    --trickster
    ["wp10"]={
        [1]={{0.2,0.15,-0.25},{-120,0,180},1.0}
    },
    ["wp11_000_00"]={
        [1]={{10.25,-0.05,-0.35},{70,0,0},1.0}
    },
}


local myapi = require("_XYZApi/_XYZApi")
local _config={
--    {name="weaponOffset",type="objectList",default=nil,config=
--        {
--        {name="Pos",type="floatN",default={0.0,0.0,0.0},min=-3,max=3,step=0.05},
        --euler angle
--        {name="Rotation",type="floatN",default={0.0,0.0,0.0},min=-180,max=180,step=0.5},
--        {name="Scale",type="float",default=1.0,min=-10,max=10,step=0.1},
--        }},
    {name="globalScale",type="float",default=1.0,min=0.0,max=10.0}
}
local config= myapi.InitFromFile(_config,configfile)
--local config= myapi.InitFromFile(_config,nil)

local weaponid2name,_=myapi.Enum2Map("app.WeaponID")

function Eu2Quat(vec3)
    --pitch
    local cr=math.cos(math.rad(vec3[1]/2))
    local sr=math.sin(math.rad(vec3[1]/2))
    --roll
    local cp=math.cos(math.rad(vec3[2]/2))
    local sp=math.sin(math.rad(vec3[2]/2))
    --yaw
    local cy=math.cos(math.rad(vec3[3]/2))
    local sy=math.sin(math.rad(vec3[3]/2))
    local q={}
    q[4] = cr * cp * cy + sr * sp * sy
    q[1] = sr * cp * cy - cr * sp * sy
    q[2] = cr * sp * cy + sr * cp * sy
    q[3] = cr * cp * sy - sr * sp * cy
    return q
end

local offsetType=sdk.find_type_definition("app.WeaponSetting.Offset")
local offsetPosOffset=offsetType:get_field("LocalPosition"):get_offset_from_base()
local offsetQuatOffset=offsetType:get_field("LocalRotation"):get_offset_from_base()
local offsetScaleOffset=offsetType:get_field("Scale"):get_offset_from_base()


local function ModifyOffsetSetting(offsetSetting)
    --[[
    default 2
        wp00    1
        wp01    0
        wp02    1
        wp03    2
        wp04    1
        wp05    1
        wp06    2
        wp07    1
        wp08    1
        wp09    1
        wp10    1
        wp11_000_00     0
        wp220000_21_0   1
        wp220000_20_0   1
        wp220000_20_1   1
        wp220000_20_2   1
        wp220001_21_0   1
        wp220001_21_1   1
        wp220001_21_2   1
        wp220001_21_3   1
        wp220001_20_0   1
        wp220001_20_1   1
        wp220002_21_0   1
        wp220002_22_0   1
        wp220000_83_0   1
        wp220000        1
        wp220001        1
        wp220002        1
        wp220003        1
        wp220000_80_0   1
        wp220000_80_1   1
        wp227000_00_0   1
        wp227001_00_0   1
        wp221000_00_0   1
        wp221000_00_1   1
        wp221000_00_4   1
        wp226000_00_0   1
        wp226000_01_0   1
        wp226000_02_0   1
        wp226000_03_0   1
        wp226000_04_0   1
        wp226000_05_0   1
        wp226000_06_0   1
        wp226000_07_0   1
        wp226000_08_0   1
        wp226000_09_0   1
        wp226000_20     0
        wp226000_21     0
        wp226000_22_0   0
        wp255000_00_0   1
    ]]--
    local weapon=weaponid2name[offsetSetting.ID]
    local offsetList=offsetSetting.SheatheSetting
    local targetSetting=defaultOffset[weapon] or defaultOffset["default"]
    if targetSetting==nil then return end

    for i=0,offsetList:get_Count()-1 do
        local offset=offsetList[i]
        if targetSetting[i+1]~=nil then
            local targetOffset=targetSetting[i+1]
            offset:write_float(offsetPosOffset+0x0,targetOffset[1][1])
            offset:write_float(offsetPosOffset+0x4,targetOffset[1][2])
            offset:write_float(offsetPosOffset+0x8,targetOffset[1][3])

            local quat=Eu2Quat(targetOffset[2])
            --print("Conv",quat[1],quat[2],quat[3],quat[4])
            --0.059 0.208 -0.05 0.97
            offset:write_float(offsetQuatOffset+0x0,quat[1])
            offset:write_float(offsetQuatOffset+0x4,quat[2])
            offset:write_float(offsetQuatOffset+0x8,quat[3])
            offset:write_float(offsetQuatOffset+0xc,quat[4])

            offset:write_float(offsetScaleOffset,targetOffset[3]*config.globalScale)
        end
    end

end
local function ModifyWeaponSetting()
    local eqManager=sdk.get_managed_singleton("app.EquipmentManager")
    local offsetSettings=eqManager.WeaponSetting.OffsetSettings
    local ct=offsetSettings:get_Count()-1
    for i=0,ct do
        ModifyOffsetSetting(offsetSettings[i])
    end
    ModifyOffsetSetting(eqManager.WeaponSetting.DefaultSetting)
end
ModifyWeaponSetting()

--to do
myapi.DrawIt(modname,configfile,_config,config,ModifyWeaponSetting)
