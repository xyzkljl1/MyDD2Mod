local modname="MoreRandomChest"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
   
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

local removeList={
    --"Gm80_000",--可拾取物品
    --"Gm80_000_002",--丢弃的物品
    --"Gm80_000_002",--丢弃的物品
    --"Gm80_002",--tr
    "Gm80_009",--stone
    "Gm80_010",--stone
    "Gm80_103",--沙袋
    "Gm80_109",--tree
    --"Gm80_110",--tree?
    "Gm82_011",--草
    "Gm82_012",--草
    "Gm82_009_01",--草
    "Gm82_009_02",
    "Gm82_009_03",
    "Gm82_009_04",--草
    "Gm82_009_09",--草
    "Gm82_017_10",--废墟堆
    "Gm82_013",--草
    "Gm82_020",--草
    "Gm82_069",--鱼
--    "Gm80_079_10",--篝火
--    "Gm51_574",--箱子
    "Gm50_097",--稻草堆
    "Gm50_013_02",--凳子
    "Gm50_040_10",--木桶
    "Gm51_083",--杂物
    "Gm51_045",--木桶
}
local replaceList={
    ["Gm80_001"]=90,--箱子
    ["Gm82_080"]=3,--甲虫
    ["Gm82_036"]=1,--探求者之证明
}
local function Log(msg)
    log.info(modname..msg)
    print(msg)
end

local function GetEnumMap(enumName)
    local ret={}
    for _,field in pairs(sdk.find_type_definition(enumName):get_fields()) do
        local value=field:get_data()
        if value~=nil and value >0 then
            ret[field:get_name()]=value
        end
    end
    return ret
end

local gimmickName2ID=GetEnumMap("app.GimmickID")

local function EnumListToInt(list)
    local intList={}
    for _,v in pairs(list) do
        local intvalue=gimmickName2ID[v]
        if intvalue~=nil and intvalue>=0 then
            intList[intvalue]=intvalue
        end
    end
    return intList
end
removeList=EnumListToInt(removeList)

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
replaceList=EnumListToInt2(replaceList)


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
                if id~=nil and removeList[id]~=nil then
                    local roll=math.random(0,99)
                    for replaceId,rate in pairs(replaceList) do
                        if roll<rate then
                            rowData._GimmickID=replaceId
                            print("Replace ",id,roll,"Use",replaceId,rate)
                            break
                        end
                    end
                    --print("End",id)
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
            table.insert(itemIds,itemCommonParam._Id)
        end
        iter:MoveNext()
    end
    Log("Init Items")
end
sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),nil,Init)


sdk.hook(
    sdk.find_type_definition("app.gm80_001"):get_method("getItem"),
    function(args)
        local this=sdk.to_managed_object(args[2])
        --app.gm80_001.ItemParam
        local ItemList=this.ItemList
        if ItemList~=nil and ItemList:get_Count()==0 then
            print("Generate Random Drop")
            local myItem=sdk.create_instance("app.gm80_001.ItemParam")
            myItem.ItemId=itemIds[math.random(1,#itemIds)]
            myItem.ItemNum=1
            ItemList:Add(myItem)
        end
    end,nil
)


--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
local myapi = prequire("_XYZApi/_XYZApi")
--if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,OnChanged) end
