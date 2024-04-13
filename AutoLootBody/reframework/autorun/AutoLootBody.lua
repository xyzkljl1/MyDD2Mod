local modname="AutoLootBody"
local configfile=modname..".json"
local myapi = require("_XYZApi/_XYZApi")
local _config={
    {name="Loot",type="mutualbox"},
    {name="range",type="int",default=30,label="Loot Range"},

    {name="LootMessage",type="mutualbox"},
    {name="showLootMessage",type="bool",default=true},
    {name="messageFontsize",type="fontsize",default=30},
}  
local myapi = require("_XYZApi/_XYZApi")
local config= myapi.InitFromFile(_config,configfile)
local msgTime=90
local posDelta=2/(msgTime)
local colorDelta=math.floor(0xff000000/msgTime)&0xff000000

local mainplayer=nil
local waitingBodyControllerList={}
local lootMessageList={}

local font = imgui.load_font("times.ttf", config.messageFontsize)

local function Log(...)
    print(...)
    for k,v in ipairs{...} do
        log.info("["..modname.."]"..tostring(v))
    end
end

local function refreshplayer()
    local player_man=sdk.get_managed_singleton("app.CharacterManager")
    mainplayer=player_man:get_ManualPlayer()
end
sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),nil,
function ()
    refreshplayer()
    waitingBodyControllerList={}
    lootMessageList={}
end
)
refreshplayer()


local function getCharacterPos(char)
    local joint=char:get_GameObject():get_Transform():getJointByName("Head_0")
    local ground_joint=char:get_GameObject():get_Transform():getJointByName("root")
    -- no head enemy
    if joint == nil then
        return ground_joint:get_Position()
    end
    --if head is too tall from ground, return the ground
    if joint:get_Position().y - ground_joint:get_Position().y >2 then
        return ground_joint:get_Position()
    end
    return joint:get_Position()
end

local function Loot(deadBodyController,doit)
    if deadBodyController==nil or (not sdk.is_managed_object(deadBodyController)) or deadBodyController:get_IsEnablePickup()==false then
        waitingBodyControllerList[deadBodyController]=nil
        return
    end
    
    local distance=deadBodyController.InteractiveObject:getDistanceSqFromPlayer(0)
    if distance<config.range*config.range then
        local pos=getCharacterPos(deadBodyController.Chara)
        Log("Start Loot",thread.get_id())
        local ct=0
        --local num=deadBodyController.GatherContext._Num
        --Log("--",deadBodyController.GatherContext._Num,distance,deadBodyController:get_IsDropItemPickuped(),deadBodyController:get_IsDisableInteract(),deadBodyController:isDead(),deadBodyController:isInteractEnable(0),deadBodyController.Chara:get_CharaIDString())
        --item over 99 will be gone and consume loot chance
	    while deadBodyController:get_IsEnablePickup()==true and deadBodyController:isInteractEnable(0) and ct<50 do --prevent infinite loop,shouldn't happen?
            if doit then
    		    deadBodyController:executeInteract(0,mainplayer)
            end
		    ct=ct+1
            --break
	    end
	    Log("End Loot "..ct)

        if config.showLootMessage then
            local lootMsg={
                msg="Loot "..ct,
                pos=pos,
                color=0xffeeeeee
            }
            lootMessageList[lootMsg]=300
        end
        waitingBodyControllerList[deadBodyController]=nil
    else
        -- if a body doesn't go into range for a long time,remove
        waitingBodyControllerList[deadBodyController] = waitingBodyControllerList[deadBodyController]-1
        if waitingBodyControllerList[deadBodyController] < -7200 then
            waitingBodyControllerList[deadBodyController]=nil  
        end
    end
end


--executeInteract throw exception in re.on_frame,why?
local interval=0
sdk.hook(
    sdk.find_type_definition("app.InteractManager"):get_method("onUpdate()"),
    function()
        interval = interval+1
        if interval >30 then
            --Log("startFrameN")
            for k,v in pairs(waitingBodyControllerList) do
                if waitingBodyControllerList[k]<=0 then
                    Loot(k,true)
                else
                    waitingBodyControllerList[k]=waitingBodyControllerList[k]-1
                end
            end
            interval=0
            --Log("endFrameN")
        end
    end,
    nil
)
sdk.hook(
--if do executeInteract in post hook of setupInteractiveObject,the body will be forced to be intractable for once. even if set this&that to disable or destroy the controller,still interactable
--  sdk.find_type_definition("app.SearchDeadBodyInteractController"):get_method("setupInteractiveObject"),
    sdk.find_type_definition("app.SearchDeadBodyInteractController"):get_method("setupInteractiveObject()"),
    function(args)
        local this=sdk.to_managed_object(args[2])
        if this:get_IsEnablePickup() then
            Log("Setup Body",thread.get_id())
            waitingBodyControllerList[this] = 1 -- wait 1*30 frame
        end
    end,
    nil
)

re.on_frame(function()
    --draw loot message
    if config.showLootMessage==true then
        imgui.push_font(font)
        for lootMessage,v in pairs(lootMessageList) do
		    if lootMessage.msg~=nil then
                draw.world_text(lootMessage.msg,lootMessage.pos,lootMessage.color)
            end

            lootMessageList[lootMessage]=lootMessageList[lootMessage]-1
            lootMessage.pos.y=lootMessage.pos.y+posDelta

            lootMessage.color=lootMessage.color-colorDelta
            if lootMessageList[lootMessage] < 0 then
                lootMessageList[lootMessage]=nil
            end    
        end
        imgui.pop_font()
    end
end)

myapi.DrawIt(modname,configfile,_config,config,nil)