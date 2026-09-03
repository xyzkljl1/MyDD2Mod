local modname="[ItemZeroWeight]"
log.info(modname.."Start")
local myLog="LogStart\n"

local function Log(msg)
    myLog = myLog .."\n".. msg
    log.info(modname..msg)
end

local itemManagerType=sdk.find_type_definition("app.ItemManager")
local zeroFloat=sdk.float_to_ptr(0)
local function ReturnZeroFloat(retval)
    return zeroFloat
end
local function ReturnZeroInt(retval)
    return sdk.to_ptr(0)
end

sdk.hook(itemManagerType:get_method("getStorageWeight(app.CharacterID)"),nil,ReturnZeroFloat)
sdk.hook(itemManagerType:get_method("getStorageWeight(app.Character)"),nil,ReturnZeroFloat)
sdk.hook(itemManagerType:get_method("getStorageWeightInt(app.CharacterID)"),nil,ReturnZeroInt)

Log("Done")

