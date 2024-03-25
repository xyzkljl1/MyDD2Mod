local modname="[ShowBossHP]"

log.info(modname.."Start")
local myLog="LogStart\n"
local screen_w=0
local screen_h=0

local config = json.load_file("ShowBossHP.json") or {}
if config.fontsize==nil then config.fontsize=60 end
if config.color1==nil then config.color1=0xffEEEEEE end
if config.color2==nil then config.color2=0x66999999 end
if config.offsetX==nil then config.offsetX=0 end
if config.offsetY==nil then config.offsetY=0 end


local font = imgui.load_font("times.ttf", config.fontsize)

local function Log(msg)
    myLog = myLog .."\n".. msg
    log.info(modname..msg)
end
local function ClearLog()
    draw.text(myLog,50,50,0xffEEEEFE)
    myLog = ""
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
    local optionItem=om._OptionItems:get_Item(93)
    local resolution=optionItem:get_FixedValueModel():get_StringValue()
    for k, v in string.gmatch(resolution, "(%w+)x(%w+)") do
       screen_w=k
       screen_h=v
    end
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

        local x0=screen_w/2-300+config.offsetX
        local y0=100+config.offsetY
        --Log(tostring(x0))
        --Log(tostring(y0))
        imgui.push_font(font)
        draw.text(message,x0,y0,config.color1)
        draw.filled_rect(x0,y0,600,80,config.color2)
        imgui.pop_font()
    end

    ClearLog()
end)


