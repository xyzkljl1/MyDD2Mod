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
    local iter=shopDatas:GetEnumerator()
    iter:MoveNext()
    while iter:get_Current()~=nil do
        local shopData=iter:get_Current()
        local typeshopData=shopData:get_type_definition()
        if typeshopData:get_full_name() == "app.NpcShopInnParam" then
            shopData._Cost=0
        end
        iter:MoveNext()
    end    
end

local tm=sdk.get_managed_singleton("app.TalkEventManager")
local iter=tm._ShopTalkEventDataCatalog:GetEnumerator()
iter:MoveNext()
while iter:get_Current():get_Value()~=nil do
    local shopDatas=iter:get_Current():get_Value()._CharacterShopData
    --Log(tostring(shopDatas))
    DoShopDatas(shopDatas)
    iter:MoveNext()
end

Log("Done")

--re.on_frame(function()
--    ClearLog()
--end)
