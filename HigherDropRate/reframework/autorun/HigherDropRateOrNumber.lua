
local modname="[HigherDropRateOrNumber]"
log.info(modname.."Start")
local myLog="LogStart\n"
local config = json.load_file("HigherDropRateOrNumber.json") or {}
if config.DropNumber==nil then config.DropNumber=1 end


local function Log(msg)
    myLog = myLog .."\n".. msg
    log.info(modname..msg)
end
local function ClearLog()
    draw.text(myLog,50,50,0xffEEEEFE)
    --myLog = ""
end
local function ModifyDropData(itemDropDataDict)
    local datas=itemDropDataDict:get_Values():GetEnumerator()
    Log(tostring(datas:get_type_definition():get_full_name()))

    datas:MoveNext()
    while datas:get_Current()~=nil do
        local lotlist=datas:get_Current()._LotList
        if #lotlist > 1 then
            for i=0,#lotlist-1 do
                if lotlist[i]._Num == 0 then
                    lotlist[i]._Rate = 0
                end
            end
        end
        if config.DropNumber ~=1 then
            for i=0,#lotlist-1 do
                lotlist[i]._Num = math.floor(lotlist[i]._Num * config.DropNumber)
            end
        end

        datas:MoveNext()
    end
end


local im=sdk.get_managed_singleton("app.ItemManager")
ModifyDropData(im.EnemyDefaultItemDropDataDict)
ModifyDropData(im.EnemyItemDropDataDict)
Log("Done")



--re.on_frame(function()
--    ClearLog()
--end)
