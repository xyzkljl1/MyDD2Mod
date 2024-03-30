local modname="CompletelyRandomChest"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")

local function Log(msg)
    print(modname..msg)
    log.info(modname..msg)
end

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
        if ItemList~=nil then
            local ct=ItemList:get_Count()-1
            for i=0,ct do                
                ItemList[i].ItemId=itemIds[math.random(1,#itemIds)]
                ItemList[i].ItemNum=math.random(1,5)
            end
        end
        --printFields(this)
        Log("Random Drop")
    end,nil
)
