local modname="AutoLootBody"
local configfile=modname..".json"
local myapi = require("_XYZApi/_XYZApi")
local _config={
    {name="Loot Settings",type="mutualbox"},
    {name="range",type="int",default=30,label="Loot Range"},
    {name="lootBody",type="bool",default=true,label="Loot Body"},
    {name="lootBodyPart",type="bool",default=true,label="Loot Body Part"},
    {name="lootDropItem",type="bool",default=true,label="Loot Drop Item"},
    {name="lootDirectItem",type="bool",default=true,label="Loot Non-Drop Item"},
    {name="lootGatherSpot",type="bool",default=true,label="Loot Gather Point"},
    {name="lootSeekerToken",type="bool",default=false,label="Loot Seeker's Token"},
    {name="lootChest",type="bool",default=false,label="Loot Chest"},

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

local function AddMessage(msg,pos)
    Log("Add Message:",msg)
    if config.showLootMessage then
        local lootMsg={
            msg=msg,
            pos=pos,
            color=0xffeeeeee
        }
        lootMessageList[lootMsg]=msgTime
    end
end

local function LootBody(deadBodyController)
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
        Log("Start Loot",maxNum)
        --Log("--",deadBodyController.GatherContext._Num,distance,deadBodyController:get_IsDropItemPickuped(),deadBodyController:get_IsDisableInteract(),deadBodyController:isDead(),deadBodyController:isInteractEnable(0),deadBodyController.Chara:get_CharaIDString())
        --item over 99 will be gone and consume loot chance sometimes? but not consumeing loot chance sometimes?

	    while deadBodyController:get_IsEnablePickup()==true and deadBodyController:isInteractEnable(0) and ct<50 and ct<maxNum do --prevent infinite loop,shouldn't happen?
    		deadBodyController:executeInteract(0,mainplayer)
		    ct=ct+1
            --break
	    end

        AddMessage("Loot "..ct,pos)
        waitingBodyControllerList[deadBodyController]=nil
    end
end


local function DistanceSq(l,r)
    return (l.x-r.x)*(l.x-r.x)
           +(l.y-r.z)*(l.y-r.y)
           +(l.y-r.z)*(l.z-r.z)            
end

local function LootBodyPart(dropPartsController)
    --don't use dropPartsController:get_DropWork():get_IsInteractEnable() 
    if dropPartsController==nil 
        or (not sdk.is_managed_object(dropPartsController)) 
        -- interactiveObject could be nil
        or (not dropPartsController:get_DropObject()) 
        or (not dropPartsController:get__DropPartsContext()) then
        waitingBodyControllerList[dropPartsController]=nil
        return
    end
    
    local interObject=dropPartsController:get_DropObject()

    if dropPartsController.PartsRoot==nil then
        waitingBodyControllerList[dropPartsController]=nil
        return
    end

    --getDistanceSqFromPlayer for some tails is 0,why?
    --local context=dropPartsController:get__DropPartsContext()
    -- context:get_Pos() is via.Positon, joint:get_Position() is via.vec3 ,can't minus; context:get_pos returns strange position
    --local disvec=mainplayer:get_GameObject():get_Transform():getJointByName("root"):get_Position() - dropPartsController.PartsRoot:get_Position()
    --local distance=DistanceSq(mainplayer:get_GameObject():get_Transform():getJointByName("root"):get_Position(),context:get_Pos())
    local distance=DistanceSq(mainplayer:get_GameObject():get_Transform():getJointByName("root"):get_Position(),dropPartsController.PartsRoot:get_Position())

    --Log("2",distance,dropPartsController:getDropItemData().Item1,dropPartsController:getDropItemData().Item2,interObject:getDistanceSqFromPlayer(0),
    --    dropPartsController["<IsDropSetup>k__BackingField"],
    --    "--",dropPartsController.PartsRoot)

    if distance<rangeSq then
        --dropPartsController:startInteract(0,mainplayer)
        --Log("3",distance,dropPartsController:getDropItemData().Item1,dropPartsController:getDropItemData().Item2,interObject:getDistanceSqFromPlayer(0),
        --    interObject:getInteractPointPosition(0).x,interObject:getInteractPointPosition(0).y,interObject:getInteractPointPosition(0).z,
        --    interObject:get_NumInteractPoints())
        local pos=interObject:getInteractPointPosition(0)
        local ct=0

        --DropItemData：<id,num>
        local maxNum=dropPartsController:getDropItemData().Item2
        --local dropItems=dropPartsController.DropPartsData:get_DropItems()
        --local maxNum=context:get_ItemNum()

        Log("Start Loot Body Part",maxNum)
        --interObject:isInteractEnable(0) returns false
	    while ct<20 and ct<maxNum do
    		    dropPartsController:executeInteract(0,mainplayer)
		    ct=ct+1
            --break
	    end
        --executeInteract不会让尾巴变为不可loot状态，不管调用多少次，每次都会获得一个物品，最后尾巴还可以正常loot一次才消失
        --需要调用unregisterInteractiveObject才能让尾巴结束可loot状态，但是如果一次都没调用executeInteract，unregisterInteractiveObject不会生效？
        dropPartsController:unregisterInteractiveObject()

        AddMessage("Loot "..ct,pos)
        waitingBodyControllerList[dropPartsController]=nil
    end
end

local function LootBodyOrBodyPart(controller)
    if controller:get_type_definition():is_a("app.DropPartsController") then
        LootBodyPart(controller)
    elseif controller:get_type_definition():is_a("app.SearchDeadBodyInteractController") then
        LootBody(controller)
    else
        waitingBodyControllerList[controller]=nil
    end
    --If a controller is not removed after call `loot`,means it's not in loot range.Increase the ct to delete trash datas.
    if waitingBodyControllerList[controller]~=nil then
        waitingBodyControllerList[controller] = waitingBodyControllerList[controller]-1
        if waitingBodyControllerList[controller] < -7200 then
            waitingBodyControllerList[controller]=nil  
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
            Log("Loot Gimmick82_009",distance)
            gimmick:onExecuteInteractBase(0,mainplayer)
            AddMessage("Loot 1",gimmick:get_GameObject():get_Transform():get_Position())
        end
    end
end

--丢弃的物品和怪物掉落的物品
local function LootGm82_000_001(gimmick)
    if gimmick:isInteractEnable(0)==true then
        local distance=gimmick.InteractiveObject:getDistanceSqFromPlayer(0)
        --treat 0.0 disatance as invalid
        if distance~=0.0 and distance<rangeSq then
            Log("Loot Gimmick82_000_001",distance,gimmick:getItemId(),gimmick:getItemNum())
            local msg="Loot "..gimmick:getItemNum() -- num became 0 after interact
            --executeInteract do nothing
            gimmick:onStartInteractBase(0,mainplayer)
            AddMessage(msg,gimmick:get_GameObject():get_Transform():get_Position())
        end
    end
end

--本来就在地图上的物品
--not include seeker's token:82_036
local function LootGm82_000(gimmick)
    if gimmick:isInteractEnable(0)==true then
        local distance=gimmick.InteractiveObject:getDistanceSqFromPlayer(0)
        --treat 0.0 disatance as invalid
        if distance~=0.0 and distance<rangeSq then
            Log("Loot Gimmick82_000",distance,gimmick:getItemId(),gimmick:getItemNum())
            local msg="Loot "..gimmick:getItemNum() -- num became 0 after interact
            --gimmick:onStartInteractBase(0,mainplayer)
            --gimmick:onExecuteInteractBase(0,mainplayer)
            --gimmick:onEndInteractBase(0,mainplayer)
            --gimmick:endInteract(0)
            --only this works,but each frame only work for one item?
            gimmick:requestForceInteract(0,mainplayer)
            AddMessage(msg,gimmick:get_GameObject():get_Transform():get_Position())
            return true
        end
    end
    return false
end

--seekers token
local function LootGm82_036(gimmick)
    if gimmick:isInteractEnable(0)==true then
        local distance=gimmick.InteractiveObject:getDistanceSqFromPlayer(0)
        --treat 0.0 disatance as invalid
        if distance~=0.0 and distance<rangeSq then
            Log("Loot Gimmick82_036",distance,gimmick:get_IsGetFreeBit())
            --onEndInteractBase and requestForceInteract both works
            --gimmick:onEndInteractBase(0,mainplayer)
            gimmick:requestForceInteract(0,mainplayer)
            AddMessage("Loot Seeker's Token",gimmick:get_GameObject():get_Transform():get_Position())
            return true
        end
    end
    return false
end

--chest
local function LootGm80_001(gimmick)
    if gimmick:isInteractEnable(0)==true then
        local distance=gimmick.InteractiveObject:getDistanceSqFromPlayer(0)
        --treat 0.0 disatance as invalid
        if distance~=0.0 and distance<rangeSq then
            Log("Loot Chest",distance,gimmick:get_IsOpenedFreeBit())
            --requestForceInteract not work
            --onExecuteInteractBase get the item repeatly without changing chest state
            --onStartInteractBase/open(false,player) force player go to open chest and change chest state without get the Item
            --open(true,player) change chest state
            --gimmick:onStartInteractBase(0,mainplayer)
            gimmick:onExecuteInteractBase(0,mainplayer)
            gimmick:open(true,mainplayer)
            AddMessage("Loot Chest",gimmick:get_GameObject():get_Transform():get_Position())
            return true
        end
    end
    return false
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
                    LootBodyOrBodyPart(k)
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

local getGimmickListMethod=sdk.find_type_definition("app.GimmickManager"):get_method("getGimmickList(app.GimmickID)")
local gimmick82_036=sdk.find_type_definition("app.GimmickID"):get_field("Gm82_036"):get_data(nil)
local gimmick82_000=sdk.find_type_definition("app.GimmickID"):get_field("Gm82_000"):get_data(nil)

--check nearby gimmick instances each 90 frame
local interval2=0
sdk.hook(
    sdk.find_type_definition("app.GimmickManager"):get_method("lateUpdate()"),
    function()
        --Log(battleManager:get_IsBattleMode())
        if config.disableOnBattle and battleManager:get_IsBattleMode() then return end

        interval2 = interval2+1
        if interval2 >90 then
            if config.lootGatherSpot then
                --iterate gimmick82_009(collectable items)
                --only contains nearby gimmicks
                local gimmicks=gimmickManager:get_CollectionGimmicks()
                local g_ct=gimmicks:get_Count()-1
                for i=0,g_ct do
                    LootGm82_009(gimmicks[i])
                end
            end
            if config.lootDropItem then
                --iterate gimmick82_000_001
                local gimmicks=gimmickManager:get_DropItemGimmicks()
                local g_ct=gimmicks:get_Count()-1
                for i=0,g_ct do
                    LootGm82_000_001(gimmicks[i])
                end
            end
            if config.lootDirectItem then
                --iterate gimmick82_000
                --local gimmicks=gimmickManager:get_DirectItemGimmicks()
                local gimmicks=getGimmickListMethod(gimmickManager,gimmick82_000)
                local g_ct=gimmicks:get_Count()-1
                for i=0,g_ct do
                    --requestForceInteract每帧只能捡起一个物品？
                    if LootGm82_000(gimmicks[i]) then
                        break
                    end
                end
            end
            if config.lootSeekerToken then
                --iterate gimmick82_000
                local gimmicks=getGimmickListMethod(gimmickManager,gimmick82_036)
                local g_ct=gimmicks:get_Count()-1
                for i=0,g_ct do
                    if LootGm82_036(gimmicks[i]) then
                        break
                    end
                end
            end
            if config.lootChest then
                local gimmicks=gimmickManager:get_TreasureBoxGimmicks()
                print(gimmicks:get_Count())
                local g_ct=gimmicks:get_Count()-1
                for i=0,g_ct do
                    if LootGm80_001(gimmicks[i]) then
                        break
                    end
                end
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
            Log("Setup Body")
            waitingBodyControllerList[this] = 1 -- wait 1*30 frame
        end
    end,
    nil
)

--Record drop body parts
--新掉落的尾巴有时只会触发OnPartsBroken而不触发setupInteractiveObject？
sdk.hook(
    sdk.find_type_definition("app.DropPartsController"):get_method("onPartsBroken(via.GameObject, System.Boolean)"),
    function(args)
        local this=sdk.to_managed_object(args[2])
        --get_Gimmick returns nil for tail
        --DropItemData: <id,num>
        if config.lootBodyPart and this:getDropItemData().Item2>=0 then
            Log("Setup BodyPart")
            waitingBodyControllerList[this] = 1 -- wait 1*30 frame
        end
    end,
    nil
)
sdk.hook(
    sdk.find_type_definition("app.DropPartsController"):get_method("setupInteractiveObject"),
    function(args)
        local this=sdk.to_managed_object(args[2])
        --get_Gimmick returns nil for tail
        --DropItemData: <id,num>
        if config.lootBodyPart and this:getDropItemData().Item2>=0 then
            Log("Setup BodyPart2")
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
