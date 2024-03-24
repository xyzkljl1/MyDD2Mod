local modname="[AppleRestoreMaxHP]"
log.info(modname.."Start")
local myLog="LogStart\n"

local function Log(msg)
    myLog = myLog .."\n".. msg
    log.info(modname..msg)
end
local function ClearLog()
    draw.text(myLog,50,50,0xffEEEEFE)
    myLog = ""
end

local im=sdk.get_managed_singleton("app.ItemManager")
im:getItemData(1):get_ItemParam()._HealBlackHp=500
im:getItemData(2):get_ItemParam()._HealBlackHp=500
im:getItemData(3):get_ItemParam()._HealBlackHp=500
Log("Done")

--re.on_frame(function()
--    ClearLog()
--end)
