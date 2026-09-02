local modname="LargerInventory"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")

sdk.hook(
    sdk.find_type_definition("app.ItemManager"):get_method("countGetEnableNumNoLock(System.Int32, app.CharacterID)"),
    nil,
    function(retval)
        --local x=sdk.to_int64(retval)&0xffffffff
        --print("Hook ",x)
        --return retval
         return sdk.to_ptr(999999)
    end
)
-- warehouse
sdk.hook(
    sdk.find_type_definition("app.ui060301_00"):get_method("checkCanTradeWareHouse(app.CharacterID)"),
    nil,
    function(retval)
        --print("Check",sdk.to_int64(retval)&0x1)
        return sdk.to_ptr(true)
    end
)
-- shop
sdk.hook(
    sdk.find_type_definition("app.ui040601_00"):get_method("checkCanTrade"),
    nil,
    function(retval)
        --print("Check",sdk.to_int64(retval)&0x1)
        return sdk.to_ptr(true)
    end
)
-- fake shop
sdk.hook(
    sdk.find_type_definition("app.ui041002"):get_method("checkCanTradeWareHouse"),
    nil,
    function(retval)
        --print("Check",sdk.to_int64(retval)&0x1)
        return sdk.to_ptr(true)
    end
)


--because countGetEnableNumNoLock is forced to return non-zero,items more than stack limit will disappear.Need to increase stack number
local im=sdk.get_managed_singleton("app.ItemManager")
-- GetEnumerator/Get_Current/Get_Value not working
local iter=im._ItemDataDict:call('System.Collections.IEnumerable.GetEnumerator()')
iter:MoveNext()
while iter._current.value~=nil do
    local itemCommonParam=iter._current.value
    itemCommonParam._StackNum=math.floor(999999)
    iter:MoveNext()
end