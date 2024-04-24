local modname="LargerInventory"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")

sdk.hook(
    sdk.find_type_definition("app.ItemManager"):get_method("countGetEnableNumNoLock(System.Int32, app.CharacterID)"),
    function()end,
    function(retval)
        --local x=sdk.to_int64(retval)&0xffffffff
        --print("Hook ",x)
        --return retval
         return sdk.to_ptr(999999)
    end
)

--because countGetEnableNumNoLock is forced to return non-zero,items more than stack limit will disappear.Need to increase stack number
local im=sdk.get_managed_singleton("app.ItemManager")
local iter=im._ItemDataDict:GetEnumerator()
iter:MoveNext()
while iter:get_Current():get_Value()~=nil do
    local itemCommonParam=iter:get_Current():get_Value()
    itemCommonParam._StackNum=math.floor(999999)
    iter:MoveNext()
end