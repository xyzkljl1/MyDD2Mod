local modname="MoreRandomChest"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
local myapi = require("_XYZApi/_XYZApi")
--settings
local _config={
    {name="ChanceScale",type="floatPercent",default=50},
    {name="ReplacedStaff",type="boolList",default={
                            --"Gm82_000",--可拾取物品
                            --"Gm82_000_001",--自然生成的物品
                            --"Gm82_000_002",--丢弃的物品
                            ["Gm80_008"]="chain",--stone
                            ["Gm80_009"]="stone",--stone
                            ["Gm80_010"]="stone",--stone
                            ["Gm80_103"]="sandbag",--沙袋
                            ["Gm80_109"]="tree",--tree
                            ["Gm80_110"]="tree",--tree?
                            ["Gm80_241"]="candle&glass?",
                            --["Gm82_001"]="key",
                            --["Gm82_002"]="key",
                            ["Gm82_009_01"]="plant gather point",--草
                            ["Gm82_009_02"]="plant gather point",
                            ["Gm82_009_03"]="plant gather point",
                            ["Gm82_009_04"]="plant gather point",--草
                            ["Gm82_009_05"]="plant gather point",--草
                            ["Gm82_009_06"]="plant gather point",--草
                            ["Gm82_009_10"]="plant gather point",--草
                            ["Gm82_009_20"]="plant gather point",--草
                            ["Gm82_016_10"]="bone gather point",--骨头
                            ["Gm82_017_10"]="wood gather point",--废墟堆
                            ["Gm82_011"]="plant gather point",--草
                            ["Gm82_012"]="plant gather point",--草
                            ["Gm82_013"]="plant gather point",--草
                            ["Gm82_020"]="potato gather point",--草
                            ["Gm82_069"]="fish gather point",--鱼
                        --    "Gm80_079_10",--篝火
                        --    "Gm51_574",--箱子
                            ["Gm50_097"]="haystack",--稻草堆
                            ["Gm50_011_00"]="wood",
                            ["Gm50_011_01"]="wood",
                            ["Gm50_011_02"]="wood",
                            ["Gm50_013_01"]="barrel",
                            ["Gm50_013_02"]="barrel",
                            ["Gm50_040_10"]="barrel",--木桶
                            ["Gm51_083"]="barrel",
                            ["Gm51_009"]="wood rack",
                            ["Gm51_010"]="wood rack",
                            ["Gm51_011"]="wood stick",
                        }
    },
}
local config=myapi.InitFromFile(_config,configfile)

local function Log(msg)
    log.info(modname..msg)
    print(msg)
end

local gimmickID2Name,gimmickName2ID=myapi.Enum2Map("app.GimmickID")

local function EnumListToInt2(list)
    local intList={}
    for v,rate in pairs(list) do
        local intvalue=gimmickName2ID[v]
        if intvalue~=nil and intvalue>=0 then
            intList[intvalue]=rate            
            print(intvalue,rate)
        end
    end
    return intList
end
local replaceList=EnumListToInt2({
    ["Gm80_001"]=32,--箱子
    ["Gm80_096"]=32,--箱子
    ["Gm80_097"]=32,--箱子
    ["Gm82_080"]=3,--甲虫
    ["Gm82_036"]=1,--探求者之证明
})


sdk.hook(
    sdk.find_type_definition("app.GenerateSelector"):get_method("randomSelect")
,    function (args)
        local this=sdk.to_managed_object(args[2])
        local t=this["<Table>k__BackingField"]
        if t~=nil and t._GimmickSetInfo ~=nil then
            local tableRow=t._GimmickSetInfo._BasicRowDatas
            local ct=tableRow:get_Count()-1
            for i=0,ct do
                local rowData=tableRow[i]
                local id=rowData._GimmickID
                --nil 表示不在列表中，false表示没有勾选
                if id~=nil and config.ReplacedStaff[gimmickID2Name[id]]~=nil and config.ReplacedStaff[gimmickID2Name[id]]~=false then
                    local roll=math.random(0,9999)/100.0
                    if roll < config.ChanceScale then
                        --will triggered for the same object when each time it's displayed
                        for replaceId,rate in pairs(replaceList) do
                            if roll<rate then
                                rowData._GimmickID=replaceId
                                print("Replace ",gimmickID2Name[id],roll,"Use",replaceId,rate*config.ChanceScale)
                                break
                            end
                            roll=roll-rate
                        end
                    end
                --else
                    --print("Ignore ",gimmickID2Name[id])
                end
            end
        end
end,nil
)

--新加的箱子是空的，添加一个默认掉落
local itemIds={}
function Init()
    itemIds={}
    local im=sdk.get_managed_singleton("app.ItemManager")
    --可以直接从app.ItemIDEnum取ID,但是里面有invalid物品
    local iter=im._ItemDataDict:GetEnumerator()
    iter:MoveNext()
    while iter:get_Current():get_Value()~=nil do
        local itemCommonParam=iter:get_Current():get_Value()
        local name=itemCommonParam:get_Name()
        if name ~="Invalid" and name~=nil then
            if itemCommonParam._SubCategory==nil or (itemCommonParam._SubCategory ~= CategoryQuest) then
                table.insert(itemIds,itemCommonParam._Id)
            end
        end
        iter:MoveNext()
    end
    Log("Init Items")
end
sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),nil,Init)

--箱子有80_001,80_096,80_097等，都使用app.gm80_001(使用app.gm80_001的都是箱子，使用app.gm82_009的都是采集点)
sdk.hook(
    sdk.find_type_definition("app.gm80_001"):get_method("getItem"),
    function(args)
        local this=sdk.to_managed_object(args[2])
        --app.gm80_001.ItemParam
        local ItemList=this.ItemList
        if ItemList~=nil and ItemList:get_Count()==0 then
            print("Generate Random Drop")
            local myItem=sdk.create_instance("app.gm80_001.ItemParam"):add_ref()
            myItem.ItemId=itemIds[math.random(1,#itemIds)]
            myItem.ItemNum=1
            ItemList:Add(myItem)
        end
    end,nil
)

myapi.DrawIt(modname,configfile,_config,config,nil)