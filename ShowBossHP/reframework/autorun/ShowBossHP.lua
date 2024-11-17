local modname="ShowBossHP"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
    {name="fontsize",type="int",default=60,min=1,max=250,needrestart=true},
    {name="color1",type="rgba32",default=0xffEEEEEE},
    {name="color2",type="rgba32",default=0x66999999},
    {name="offsetX",type="int",default=0,min=-4000,max=4000},
    {name="offsetY",type="int",default=0,min=-4000,max=4000},
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

local screen_w=0
local screen_h=0

local font = imgui.load_font("times.ttf", config.fontsize)

local function Log(msg)
    log.info(modname..msg)
end

local currentHitController=nil
--local currentGaugeUI=nil
local currentGaugeUIGO=nil

sdk.hook(
    sdk.find_type_definition("app.ui020501"):get_method("updateGauge"),
    function(args)
        local this=sdk.to_managed_object(args[2])
        if this.TargetHitCtrl ~=currentHitController then
            currentHitController=this.TargetHitCtrl
        end
        if currentGaugeUIGO ~=this:get_GameObject() then
            currentGaugeUIGO=this:get_GameObject()
        end
    end,
    function()end
)
local function GetScreenSize()
    local om=sdk.get_managed_singleton("app.OptionManager")
    --app.OptionID.Resolution=93
    if not om._OptionItems:ContainsKey(93) then
        Log("Can't find _OptionItems[93].Delay GetScreenSize")
        return 
    end
    local optionItem=om._OptionItems:get_Item(93)
    local resolution=optionItem:get_FixedValueModel():get_StringValue()
    for k, v in string.gmatch(resolution, "(%w+)x(%w+)") do
       screen_w=k
       screen_h=v
    end
    Log("GetScreenSize Done")
end

GetScreenSize()

re.on_frame(function()
    local gm=sdk.get_managed_singleton("app.GuiManager")
    if gm == nil then return end
    if gm:get_IsLoadGui()==true then return end

    if currentHitController~=nil and currentGaugeUIGO~=nil then
        --become invalid after return to tile
        if not currentGaugeUIGO:get_Valid() then
            currentHitController=nil
            currentGaugeUIGO=nil
            return
        end
 
        if currentGaugeUIGO:get_DrawSelf() ==false then return end

        local message= tostring(math.floor(currentHitController:get_Hp())) .. " / " .. tostring(math.floor(currentHitController:get_ReducedMaxHp())) .. " ("..tostring(math.floor(100*(currentHitController:get_ReducedHpRate()))) .."%)"
        --Log(message)
        --Log(d2d.detail.get_max_updaterate())
	if screen_w == 0 then 
		GetScreenSize()
	end

        local x0=screen_w/2-300+config.offsetX
        local y0=100+config.offsetY
        --Log(tostring(x0))
        --Log(tostring(y0))
        imgui.push_font(font)
        draw.text(message,x0,y0,config.color1)
        draw.filled_rect(x0,y0,600,80,config.color2)
        imgui.pop_font()
    end
end)



--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,OnChanged) end
