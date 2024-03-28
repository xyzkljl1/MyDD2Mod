local modname="FasterRun"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
    {name="Speed1",type="float",default=9.0,min=0.1,max=1000.0},
    {name="Speed2",type="float",default=24.0,min=0.1,max=1000.0},
    {name="Speed3",type="float",default=30.0,min=0.1,max=1000.0},
    {name="Speed4",type="float",default=39.0,min=0.1,max=1000.0},
    {name="Speed5",type="float",default=24.0,min=0.1,max=1000.0},
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

local function Log(msg)
    log.info(modname..msg)
end

local function getplayer()
    local player_man=sdk.get_managed_singleton("app.CharacterManager")
    local player=player_man:get_ManualPlayer()
    return player
end

--local speedpara=getplayer():get_Human():get_Param():get_Speed()
--local list=speedpara.SpeedDataList
--list[0].BaseSpeed=1
--list[1].BaseSpeed=100

--re.on_frame(function()
--    local speedpara=getplayer():get_Human():get_Param():get_Speed()
--    local list=speedpara.SpeedDataList
--    Log(tostring(#list))
--    for i=0,#list-1 do
--        Log(tostring(list[i].BaseSpeed))
--    end
--    ClearLog()
--end)

local function Init()
    Log("Init Move Speed")
    local player=getplayer()
    if player~=nil then
        Log("Init Move Speed2")
        local speedpara=player:get_Human():get_Param():get_Speed()
        local list=speedpara.SpeedDataList
        --6.047/17.71/23.32/26.92/-/15.98
        list[0].BaseSpeed=config.Speed1--徐行(轻推摇杆)
        list[1].BaseSpeed=config.Speed2--走路（推摇杆）
        list[2].BaseSpeed=config.Speed3--持刀冲刺
        list[3].BaseSpeed=config.Speed4--收刀冲刺
        --4不知道是什么
        list[5].BaseSpeed=config.Speed5--战斗中走路
    end
end

sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),nil,Init)

--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
--On setting Change
local function OnChanged()    
    Init()
end
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,OnChanged) end
