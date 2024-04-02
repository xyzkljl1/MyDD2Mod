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

local sceneType=nil
local enumfield=sdk.find_type_definition("app.MainFlowManager.SceneType"):get_field("Field"):get_data()
local isInGame=false
sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),
function(args)
    sceneType=sdk.to_int64(args[3])&0xf
end,
function()
    isInGame=(enumfield==sceneType)
    sceneType=nil
end
)

local man=sdk.get_managed_singleton("app.GenerateManager")
re.on_frame(function ()
    if isInGame then
        man._NPCGenerateLimit=config.NPCLimit
        man._RuleNPCGenerateLimit=config.NPCLimit
        man.DefaultNPCGenerateLimit=config.NPCLimit
        man._RuleEnemyGenerateLimit=config.EnemyLimit
        man.DefaultEnemyGenerateLimit=config.EnemyLimit
    else
        --set limit to max to prevent potential issue on loading save
        man._NPCGenerateLimit=2000
        man._RuleNPCGenerateLimit=2000
        man.DefaultNPCGenerateLimit=2000
        man._RuleEnemyGenerateLimit=2000
        man.DefaultEnemyGenerateLimit=2000
    end
    --print(isInGame)
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

