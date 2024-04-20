local modname="Clock"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
    {name="Style",type="mutualbox"},
    {name="fontsize",type="int",default=60,min=1,max=250,needrestart=true},
    {name="offset",type="intN",default={50,50},min=-300,max=8000},
    {name="color",type="rgba32",default=0xffEEEEEE},
    {name="backgroundcolor",type="rgba32",default=0x88777777},

    {name="Format",type="mutualbox"},
    {name="zerofill",type="bool",default=false},
    {name="showbackground",type="bool",default=true},
    {name="showtimeslot",type="bool",default=true},
    {name="useAMPM",type="bool",default=false},
    {name="customFormat",type="string",default="{D}Day {T} {h}:{m}:{s} {a}"},
    
    {name="Enable",type="mutualbox"},
    {name="disableInMenu",type="bool",default=false},
    {name="enable",type="bool",default=true},
    {name="enableHotkey",type="hotkey",default="Alpha3",actionName="ClockEnable8293"},
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
--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end

local hk = prequire("Hotkeys/Hotkeys")
local font = imgui.load_font("times.ttf", config.fontsize)
local guiManager=sdk.get_managed_singleton("app.GuiManager")
local function Log(msg)
    log.info(modname..msg)
end

re.on_frame(function()
    if hk~=nil and hk.check_hotkey("ClockEnable8293",false,true) then
        config.enable=not config.enable
    end
    if not config.enable then return end
    if config.disableInMenu and guiManager:get_IsLoadGui() then return end

    imgui.push_font(font)
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
            if h<12 then ampm="AM"
            else ampm="PM" end
            -- 0:30 PM should be 12:30 PM?
            if h>12 then h=h%12 end
        end

        --2sec for 1min?
        msg=config.customFormat
        local dformat="%2d"
        if config.zerofill then dformat="%02d" end
        msg=string.gsub(msg,"{h}", string.format(dformat,h))
        msg=string.gsub(msg,"{m}", string.format(dformat,m))
        msg=string.gsub(msg,"{s}", string.format(dformat,math.floor(s)%2))

        msg=string.gsub(msg,"{D}", tostring(d))
        msg=string.gsub(msg,"{T}", state)
        msg=string.gsub(msg,"{a}", ampm)

        if config.showbackground ==true then
            local size=imgui.calc_text_size(msg)
            draw.filled_rect(config.offset[1]-5, config.offset[2]-5, size.x +10,size.y+10, config.backgroundcolor)
        end
        draw.text(msg,config.offset[1],config.offset[2],config.color) 
    end
    imgui.pop_font()
end)



local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,OnChanged) end
