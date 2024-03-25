local modname="[Clock]"
log.info(modname.."Start")
local myLog="LogStart\n"

local config = json.load_file("Clock.json") or {}
if config.fontsize==nil then config.fontsize=60 end
if config.color==nil then config.color=0xffEEEEEE end
if config.offsetX==nil then config.offsetX=50 end
if config.offsetY==nil then config.offsetY=50 end

local font = imgui.load_font("times.ttf", config.fontsize)
local function Log(msg)
    myLog = myLog .."\n".. msg
    log.info(modname..msg)
end
local function ClearLog()
    --draw.text(myLog,50,50,0xffEEEEFE)
    myLog = ""
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
        elseif tm:isDask() then
            state="Dask"
        end
        --2sec for 1min?
        local msg=string.format("%dDay %s %d:%d:%d",d,state,h,m,math.floor(s)%2)
        draw.text(msg,config.offsetX,config.offsetY,config.color) 
    end
    imgui.pop_font()
    ClearLog()
end)
