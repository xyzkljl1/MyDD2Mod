local modname="AutoLootBody"
local configfile=modname..".json"
local myapi = require("_XYZApi/_XYZApi")
local _config={
    {name="Loot Settings",type="mutualbox"},
    {name="range",type="int",default=30,label="Loot Range"},
    {name="lootBody",type="bool",default=true,label="Loot Body"},
    {name="lootGatherSpot",type="bool",default=true,label="Loot Gather Point"},
    {name="disableOnBattle",type="bool",default=false,label="Disable During Battle"},

    {name="Loot Message Settings",type="mutualbox"},
    {name="showLootMessage",type="bool",default=true},
    {name="messageFontsize",type="fontsize",default=30},
}  
local myapi = require("_XYZApi/_XYZApi")
local config= myapi.InitFromFile(_config,configfile)
local msgTime=120
local posDelta=2/(msgTime)
local colorDelta=math.floor(0xff000000/msgTime)&0xff000000
local rangeSq=config.range*config.range

local mainplayer=nil
local waitingBodyControllerList={}
local lootMessageList={}
local gimmickManager=sdk.get_managed_singleton("app.GimmickManager")
local battleManager = sdk.get_managed_singleton("app.BattleManager")

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

local function Loot(deadBodyController)
    if deadBodyController==nil or (not sdk.is_managed_object(deadBodyController)) or deadBodyController:get_IsEnablePickup()==false then
        waitingBodyControllerList[deadBodyController]=nil
        return
    end
    
    local distance=deadBodyController.InteractiveObject:getDistanceSqFromPlayer(0)
    if distance<rangeSq then
        local pos=getCharacterPos(deadBodyController.Chara)
        local ct=0

        --限制最大尝试次数，防止超过堆叠上限时不停冒无法获得道具的提示
        local maxNum=deadBodyController.GatherContext._Num
        if deadBodyController.ItemDropInfo~=nil then
            local lotlist=deadBodyController.ItemDropInfo._LotList
            for i=0,lotlist:get_Count()-1 do
                if maxNum<lotlist[i]._Num then
                    maxNum=lotlist[i]._Num
                end
            end
        end
        Log("Start Loot",thread.get_id(),maxNum)
        --Log("--",deadBodyController.GatherContext._Num,distance,deadBodyController:get_IsDropItemPickuped(),deadBodyController:get_IsDisableInteract(),deadBodyController:isDead(),deadBodyController:isInteractEnable(0),deadBodyController.Chara:get_CharaIDString())
        --item over 99 will be gone and consume loot chance sometimes? but not consumeing loot chance sometimes?

	    while deadBodyController:get_IsEnablePickup()==true and deadBodyController:isInteractEnable(0) and ct<50 and ct<maxNum do --prevent infinite loop,shouldn't happen?
    		deadBodyController:executeInteract(0,mainplayer)
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
            lootMessageList[lootMsg]=msgTime
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

local function LootGm82_009(gimmick)
    if gimmick:isInteractEnable(0)==true then
        --gimmick:get_DistanceXZSqFromPlayer and FarDistanceSq/NearDistanceSq for some gimmick are fix value 
        --GM82_009_10 will trigger repeatly and distance is always 0.0
        local distance=gimmick.InteractiveObject:getDistanceSqFromPlayer(0)
        --local distance2=gimmick:get_DistanceXZSqFromPlayer()
        --treat 0.0 disatance as invalid
        if distance~=0.0 and distance<rangeSq then
            --call StartInteract only causes pickup action
            Log("Loot Gimmick",distance,distance2)
            gimmick:onExecuteInteractBase(0,mainplayer)
            if config.showLootMessage then
                local lootMsg={
                    msg="Loot 1",
                    pos=gimmick:get_GameObject():get_Transform():get_Position(),
                    color=0xffeeeeee
                }
                lootMessageList[lootMsg]=msgTime
            end
        end
    end
end

--executeInteract throw exception in re.on_frame,why?
--Check recorded bodies each 30 frame
local interval=0
sdk.hook(
    sdk.find_type_definition("app.InteractManager"):get_method("onUpdate()"),
    function()
        if config.disableOnBattle and battleManager:get_IsBattleMode() then return end
        interval = interval+1
        if interval >30 then
            --Log("startFrameN")
            --iterate body controller
            for k,v in pairs(waitingBodyControllerList) do
                if waitingBodyControllerList[k]<=0 then
                    Loot(k)
                else
                    waitingBodyControllerList[k]=waitingBodyControllerList[k]-1
                end
            end
            --Log("endFrameN")
            interval=0
        end
    end,
    nil
)

--check nearby gimmick instances each 90 frame
local interval2=0
sdk.hook(
    sdk.find_type_definition("app.GimmickManager"):get_method("update()"),
    function()
        --Log(battleManager:get_IsBattleMode())
        if config.disableOnBattle and battleManager:get_IsBattleMode() then return end
        if not config.lootGatherSpot then return end
        
        interval2 = interval2+1
        if interval2 >90 then
            --iterate gimmick82_009(collectable items)
            --only contains nearby gimmicks
            local gimmicks=gimmickManager:get_CollectionGimmicks()
            local g_ct=gimmicks:get_Count()-1
            for i=0,g_ct do
                local gimmick=gimmicks[i]
                LootGm82_009(gimmick)
            end
            interval2=0
        end
    end,
    nil
)


--record body when setup interactive object(when monster die)
sdk.hook(
--if do executeInteract in post hook of setupInteractiveObject,the body will be forced to be intractable for once. even if set this&that to disable or destroy the controller,still interactable
--  sdk.find_type_definition("app.SearchDeadBodyInteractController"):get_method("setupInteractiveObject"),
    sdk.find_type_definition("app.SearchDeadBodyInteractController"):get_method("setupInteractiveObject()"),
    function(args)
        local this=sdk.to_managed_object(args[2])
        if this:get_IsEnablePickup() and config.lootBody then
            Log("Setup Body",thread.get_id())
            waitingBodyControllerList[this] = 1 -- wait 1*30 frame
        end
    end,
    nil
)

--draw loot message
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

myapi.DrawIt(modname,configfile,_config,config,function () 
    rangeSq=config.range*config.range
end)
