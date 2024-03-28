local modname="Clock"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
    {name="fontsize",type="int",default=60,min=1,max=250,needrestart=true},
    {name="offset",type="intN",default={50,50},min=-300,max=8000},
    {name="color",type="rgba32",default=0xffEEEEEE},
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
end

local font = imgui.load_font("times.ttf", config.fontsize)
local function Log(msg)
    log.info(modname..msg)
end

re.on_frame(function()
    imgui.push_font()
    local tm=sdk.get_managed_singleton("app.TimeManager")
    if tm~=nil then
        local d=tm:get_InGameDay()
        local h=tm:get_InGameHour()
        local m=tm:get_InGameMinute()
        local s=tm:get_InGameElapsedDaySeconds()
        --local r=tm:get_MinutesRate()
        local state=""
        if tm:isNight() then
            state="Night"
        elseif tm:isDawn() then
            state="Dawn"
        elseif tm:isNoon() then
            state="Noon"
        elseif tm:isDusk() then
            state="Dusk"
        end
        --2sec for 1min?
        local msg=string.format("%dDay %s %d:%d:%d",d,state,h,m,math.floor(s)%2)
        draw.text(msg,config.offset[1],config.offset[2],config.color) 
    end
    imgui.pop_font()
end)



--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,OnChanged) end
