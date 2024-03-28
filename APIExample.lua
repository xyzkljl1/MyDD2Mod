-------
local modname="ExampleMod"
local configfile=modname..".json"
--settings
local _config={
    {name="para1",type="int",default=60,min=1,max=250},
    {name="para2",type="float",default=3.2,min=0.0,max=5.0,step=0.001,needrestart=true},
    {name="para3",type="rgba32",default=0xffEEEEEE},
    {name="para4",type="rgba4f",default={1.0,0.5,0.5,1.0},width=100},
    {name="para5",type="intN",default={20,25},min=1,max=100},
    {name="para6",type="string",default="para6",tip="this is a tip",needreentry=true},
    {name="para7",type="bool",default=true,label="This is label"},
    {name="para8",type="hotkey",default="Z",actionName="HotKeyActionNameThisShouldBeUniqueInAllMods"},
}
------Init Config
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
    print("OnChanged")
end

------Mod Implement
re.on_frame(function()
    draw.text("para1="..tostring(config.para1),50,50,config.para3)
    draw.text("para2="..tostring(config.para2),50,80,config.para3)
    draw.text("para4[1]="..tostring(config.para4[1]),50,110,config.para3)
    draw.text("para4[2]="..tostring(config.para4[2]),50,140,config.para3)
    draw.text("para4[3]="..tostring(config.para4[3]),50,170,config.para3)
    draw.text("para5[1]="..tostring(config.para5[1]),50,200,config.para3)
    draw.text("para5[2]="..tostring(config.para5[2]),50,230,config.para3)
    draw.text("para6="..tostring(config.para6),50,250,config.para3)
    draw.text("para7="..tostring(config.para7),50,270,config.para3)
end)

------Draw UI If api exists
--XYZAPI is optional,still run without api,just no UI.
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,OnChanged) end
