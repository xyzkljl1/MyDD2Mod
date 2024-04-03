local modname="BetterChest"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
local _config={
    {name="DoubleLootChance",type="int",default=100,min=0,max=100},
    {name="AdditionalLootChance",type="int",default=30,min=0,max=100},
    {name="AdditionalLoot",type="bool",default=true},
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


local function Log(msg)
    print(modname..msg)
    log.info(modname..msg)
end

local tmp=json.load_file("BetterChest.DropList.json")
local additionalItemIds={}

for k,_ in pairs(tmp) do
    table.insert(additionalItemIds,tonumber(k))
end


sdk.hook(
    sdk.find_type_definition("app.gm80_001"):get_method("getItem"),
    function(args)
        local this=sdk.to_managed_object(args[2])
        --app.gm80_001.ItemParam
        local ItemList=this.ItemList
        if ItemList~=nil then   
            local double=(math.random(0,99) < config.DoubleLootChance)
            if double then
                local ct=ItemList:get_Count()-1
                for i=0,ct do
                    ItemList[i].ItemNum = ItemList[i].ItemNum * 2
                end
            end
            if config.AdditionalLoot and (math.random(0,99) < config.AdditionalLootChance) then
                local newItem=sdk.create_instance("app.gm80_001.ItemParam"):add_ref()
                newItem.ItemId=additionalItemIds[math.random(1,#additionalItemIds)]
                newItem.ItemNum=1
                ItemList:Add(newItem)
            end
        end
        --printFields(this)
        Log("Random Drop")
    end,nil
)



--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,nil) end
