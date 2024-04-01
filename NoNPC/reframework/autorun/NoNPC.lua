local modname="NoNPC"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local OnClickFunc=nil
local OnClickEFunc=nil
local _config={
    {name="NPCLimit",type="int",default=0,min=0,max=200},
    {name="RemoveNearbyNPC",type="button",onClick=function() OnClickFunc() end},
    {name="EnemyLimit",type="int",default=0,min=0,max=200},
    {name="RemoveNearbyEnemy",type="button",onClick=function() OnClickEFunc() end},
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
    log.info(modname..msg)
    print(msg)
end

local man=sdk.get_managed_singleton("app.GenerateManager")
re.on_frame(function ()
    man._NPCGenerateLimit=config.NPCLimit
    man._RuleNPCGenerateLimit=config.NPCLimit
    man.DefaultNPCGenerateLimit=config.NPCLimit
    man._RuleEnemyGenerateLimit=config.EnemyLimit
    man.DefaultEnemyGenerateLimit=config.EnemyLimit
end)

OnClickFunc=function() man:requestDestroyAllNPC() end
OnClickEFunc=function() man:requestDestroyAllEnemy() end

--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,nil) end

