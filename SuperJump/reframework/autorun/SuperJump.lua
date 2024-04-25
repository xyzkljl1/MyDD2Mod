local modname="SuperJump"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
    {name="para1",type="float",default=3,min=0.1,max=1000.0,needreentry=true,tip="Affect the height"},
    {name="para2",type="float",default=0.93,min=0.1,max=1.2,step=0.001,tip="Affect the airborne time"},
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
--end

local currentHuman=nil
local baseHeight=0

local function Log(msg)
    log.info(modname..msg)
end

local function Init()
    local player_man=sdk.get_managed_singleton("app.CharacterManager")
    local player=player_man:get_ManualPlayer()
    if player ~=nil then
        currentHuman=player:get_Human()
        local para=currentHuman:get_Param():get_Action().JumpParam
        --1.0 default
        para.MaxRootHeight=config.para1
        --para.AttenuateFactorLeftRight=0
        --para.AttenuateFactorFrontBack=0
        --baseHeight=currentHuman.Hip:get_Position().y
        Log("InitDone")
    end
end

sdk.hook(
    sdk.find_type_definition("app.HumanJumpRootAdjuster"):get_method("update"),
    function(args)       
        local this =sdk.to_managed_object(args[2])
        if this.Human==currentHuman then
            this.ElapsedFrame=this.ElapsedFrame*config.para2
            --Log(tostring(this:get_JumpHeight()))
            --Log(tostring(currentHuman.Hip:get_Position().y-baseHeight))
        end
    end,
    nil
)

sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),nil,Init)
Init()
--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,nil) end



--re.on_frame(function()
--    ClearLog()
--end)
