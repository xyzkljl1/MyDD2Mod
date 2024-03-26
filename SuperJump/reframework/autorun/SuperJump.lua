local modname="[SuperJump]"
log.info(modname.."Start")
local myLog="LogStart\n"
local config = json.load_file("SuperJump.json") or {}
if config.para1==nil then config.para1=3 end
if config.para2==nil then config.para2=0.93 end

--doesnt work as literal at all
--does this mod actually work because of bug?
config.maxheight=config.para1
config.animationspeed=config.para2
-- 3/0.93
-- 5/0.9
-- 10/0.8
-- 20/0.7
-- 50/0.6
local currentHuman=nil
local baseHeight=0

local function Log(msg)
    myLog = myLog .."\n".. msg
    log.info(modname..msg)
end
local function ClearLog()
    --draw.text(myLog,50,50,0xffEEEEFE)
    --myLog = ""
end

local function Init()
    local player_man=sdk.get_managed_singleton("app.CharacterManager")
    local player=player_man:get_ManualPlayer()
    if player ~=nil then
        currentHuman=player:get_Human()
        local para=currentHuman:get_Param():get_Action().JumpParam
        --1.0 default
        para.MaxRootHeight=config.maxheight
        --para.AttenuateFactorLeftRight=0
        --para.AttenuateFactorFrontBack=0
        --baseHeight=currentHuman.Hip:get_Position().y
        Log("InitDone")
    end
end

sdk.hook(
    sdk.find_type_definition("app.HumanJumpRootAdjuster"):get_method("update"),
    function(args)       
        local this =sdk.to_managed_object(args[2])
        if this.Human==currentHuman then
            this.ElapsedFrame=this.ElapsedFrame*config.animationspeed
            --Log(tostring(this:get_JumpHeight()))
            --Log(tostring(currentHuman.Hip:get_Position().y-baseHeight))
        end
    end,
    nil
)

sdk.hook(
    sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),
    nil,
    function()
        Init()
    end
)

--Init()
--re.on_frame(function()
--    ClearLog()
--end)
