local modname="[BattleInfo]"
log.info(modname.."Start")
local myLog="LogStart\n"
local config = json.load_file("FasterRun.json") or {}
if config.Speed1==nil then config.Speed1=9 end
if config.Speed2==nil then config.Speed2=30 end
if config.Speed3==nil then config.Speed3=46 end

local function Log(msg)
    --myLog = myLog .."\n".. msg
    log.info(modname..msg)
end
local function ClearLog()
    draw.text(myLog,50,50,0xffEEEEFE)
    myLog = ""
end

local function getplayer()
    local player_man=sdk.get_managed_singleton("app.CharacterManager")
    local player=player_man:get_ManualPlayer()
    return player
end

sdk.hook(
    sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),
    function() end,
    function()
        Log("Init Move Speed")
        local player=getplayer()
        if player~=nil then
            Log("Init Move Speed2")
            local speedpara=player:get_Human():get_Param():get_Speed()
            local list=speedpara.SpeedDataList
            --6.047/17.71/26.92
            list[0].BaseSpeed=config.Speed1--徐行(轻推摇杆)
            list[1].BaseSpeed=config.Speed2--走路（推摇杆）
            --2不知道是什么
            list[3].BaseSpeed=config.Speed3--冲刺      
        end
    end
)
