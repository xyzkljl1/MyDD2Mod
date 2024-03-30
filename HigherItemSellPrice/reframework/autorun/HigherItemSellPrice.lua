local modname="HigherItemSellPrice"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")

--settings
local _config={
    {name="ratio",type="float",default=1.0,min=0.0,max=1000.0},
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
--On setting Change
local function OnChanged()
    local im=sdk.get_managed_singleton("app.ItemManager")
    local iter=im._ItemDataDict:GetEnumerator()
    iter:MoveNext()
    while iter:get_Current():get_Value()~=nil do
        local itemCommonParam=iter:get_Current():get_Value()
        itemCommonParam._SellPrice=math.floor(itemCommonParam._BuyPrice*config.ratio)
        iter:MoveNext()
    end
end

local function Log(msg)
    log.info(msg)
end

OnChanged()

Log("Done")

--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,OnChanged) end
