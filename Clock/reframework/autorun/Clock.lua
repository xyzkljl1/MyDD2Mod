local modname="Clock"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
    {name="fontsize",type="int",default=60,min=1,max=250,needrestart=true},
    {name="offset",type="intN",default={50,50},min=-300,max=8000},
    {name="color",type="rgba32",default=0xffEEEEEE},
    {name="showtimeslot",type="bool",default=true},
    {name="useAMPM",type="bool",default=false},
    {name="customFormat",type="string",default="{D}Day {T} {h}:{m}:{s} {a}"},
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
        if config.showtimeslot then
            if tm:isNight() then
                state="Night"
            elseif tm:isDawn() then
                state="Dawn"
            elseif tm:isNoon() then
                state="Noon"
            elseif tm:isDusk() then
                state="Dusk"
            end
        end
        local ampm=""
        if config.useAMPM==true then
            if h<=12 then ampm="AM"
            else ampm="PM" end
            h=h%12
        end

        --2sec for 1min?
        msg=config.customFormat
        msg=string.gsub(msg,"{h}", string.format("%2d",h))
        msg=string.gsub(msg,"{m}", string.format("%2d",m))
        msg=string.gsub(msg,"{s}", string.format("%2d",math.floor(s)%2))

        msg=string.gsub(msg,"{D}", tostring(d))
        msg=string.gsub(msg,"{T}", state)
        msg=string.gsub(msg,"{a}", ampm)

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
