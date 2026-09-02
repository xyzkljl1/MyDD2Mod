local modname="[FreeInn]"
log.info(modname.."Start")
local myLog="LogStart\n"

local function Log(msg)
    myLog = myLog .."\n".. msg
    log.info(modname..msg)
end
local function ClearLog()
    draw.text(myLog,50,50,0xffEEEEFE)
    --myLog = ""
end

local function DoShopDatas(shopDatas)
    -- GetEnumerator/Get_Current/Get_Value not working
    local iter=shopDatas:call('System.Collections.IEnumerable.GetEnumerator()')
    iter:MoveNext()
    while iter._current~=nil do
        local shopData=iter._current
        local typeshopData=shopData:get_type_definition()
        if typeshopData:get_full_name() == "app.NpcShopInnParam" then
            shopData._Cost=0
        end
        iter:MoveNext()
    end    
end

--re.on_frame(function()
--    ClearLog()
--end)

sdk.hook(
    sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),
    nil,
    function()
        --data reseted when return to title
        local tm=sdk.get_managed_singleton("app.TalkEventManager")
        -- GetEnumerator/Get_Current/Get_Value not working
        local iter=tm._ShopTalkEventDataCatalog:call('System.Collections.IEnumerable.GetEnumerator()')
        iter:MoveNext()
        while iter._current.value~=nil do
            local shopDatas=iter._current.value._CharacterShopData
            --Log(tostring(shopDatas))
            DoShopDatas(shopDatas)
            iter:MoveNext()
        end	
        Log("Done")
    end
)

