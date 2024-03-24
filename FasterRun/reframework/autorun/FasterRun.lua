local modname="[BattleInfo]"
log.info(modname.."Start")
local myLog="LogStart\n"
local config = json.load_file("FasterRun.json") or {}
if config.Speed1==nil then config.Speed1=9 end
if config.Speed2==nil then config.Speed2=30 end
if config.Speed3==nil then config.Speed3=30 end
if config.Speed4==nil then config.Speed4=46 end

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
            --6.047/17.71/23.32/26.92
            list[0].BaseSpeed=config.Speed1--ÐìÐÐ(ÇáÍÆÒ¡¸Ë)
            list[1].BaseSpeed=config.Speed2--×ßÂ·£¨ÍÆÒ¡¸Ë£©
            list[2].BaseSpeed=config.Speed3--³Öµ¶³å´Ì
            list[3].BaseSpeed=config.Speed4--ÊÕµ¶³å´Ì
        end
    end
)
