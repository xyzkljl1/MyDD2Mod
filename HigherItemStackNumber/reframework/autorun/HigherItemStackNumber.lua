local modname="[HigherItemStackNumber]"
log.info(modname.."Start")
local myLog="LogStart\n"

local config = json.load_file("HigherItemStackNumber.json") or {}
if config.Num==nil then config.Num=999 end

local function Log(msg)
    myLog = myLog .."\n".. msg
    log.info(modname..msg)
end
local function ClearLog()
    draw.text(myLog,50,50,0xffEEEEFE)
    myLog = ""
end

local im=sdk.get_managed_singleton("app.ItemManager")
local iter=im._ItemDataDict:GetEnumerator()
iter:MoveNext()
while iter:get_Current():get_Value()~=nil do
    local itemCommonParam=iter:get_Current():get_Value()
    itemCommonParam._StackNum=math.floor(config.Num)
    --itemCommonParam._BuyPrice=1
    iter:MoveNext()
end

Log("Done")

--re.on_frame(function()
--    ClearLog()
--end)
