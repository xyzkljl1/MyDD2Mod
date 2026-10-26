local modname="AutoLootBody"
local configfile=modname..".json"
local myapi = require("_XYZApi/_XYZApi")
local _config={
    {type="author",version="1.4.15"},
    {name="Loot Settings",type="mutualbox"},
    {name="range",type="int",default=30,label="Loot Range"},
    {name="lootBody",type="bool",default=true,label="Loot Body"},
    {name="lootBodyPart",type="bool",default=true,label="Loot Body Part"},
    {name="lootPlayerDropItem",type="bool",default=false,label="Player Drop Item"},
    {name="lootDropItem",type="bool",default=true,label="Other Drop Item"},
    {name="lootDirectItem",type="bool",default=true,label="Loot Non-Drop Item"},
    {name="lootGatherSpot",type="bool",default=true,label="Loot Gather Point"},
    {name="lootSeekerToken",type="bool",default=false,label="Loot Seeker's Token"},
    {name="lootNorganDucat",type="bool",default=false,label="Loot Norgan Ducat"},
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

local mainplayer=nil -- ÔÝÊ±ÆúÓÃ
local waitingBodyControllerList={}
local lootMessageList={}
local gimmickManager = sdk.get_managed_singleton("app.GimmickManager")
local battleManager = sdk.get_managed_singleton("app.BattleManager")
local playerManager=sdk.get_managed_singleton("app.CharacterManager")

local font = imgui.load_font("times.ttf", config.messageFontsize)

local function Log(...)
    print(...)
    for k,v in ipairs{...} do
        log.info("["..modname.."]"..tostring(v))
    end
end

local function refreshplayer()
    playerManager=sdk.get_managed_singleton("app.CharacterManager")
    mainplayer=playerManager:get_ManualPlayer()
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
        if ground_joint==nil then return char:get_GameObject():get_Transform():get_Position() end
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

local function DistanceSq(r)
    -- mainplayer»áÊ§Ð§?
    local player = playerManager:get_ManualPlayer()
    if player == nil or player:get_GameObject() == nil then 
        return 0
    end
    local l = player:get_GameObject():get_Transform():getJointByName("root"):get_Position()
    return (l.x-r.x)*(l.x-r.x)
           +(l.y-r.y)*(l.y-r.y)
           +(l.z-r.z)*(l.z-r.z)
end

-- interactiveObject:getDistanceSqFromPlayer calc only x-z distance£¬same as gimmick:get_DistanceXZSqFromPlayer
local function DistanceSqGimmick(gimmick)
    -- some gimmic don't have root joint,such as a potato.
    -- return DistanceSq(mainplayer:get_GameObject():get_Transform():getJointByName("root"):get_Position(), gimmick:getJointByName("root"):get_Position())
    return DistanceSq(gimmick:getPos(gimmick:get_GameObject()))
end

-- getDistanceSqFromPlayer for bodies(or maybe for everything) could also be 0.0,meaning invalid.
-- seems it has a cache system.
local function LootBody(deadBodyController)
    if deadBodyController==nil or (not sdk.is_managed_object(deadBodyController)) or deadBodyController:get_IsEnablePickup()==false then
        waitingBodyControllerList[deadBodyController]=nil
        return
    end
    
    local distance=deadBodyController.InteractiveObject:getDistanceSqFromPlayer(0)
    -- havn't found a way to calc x-y-z distance
    -- local p = deadBodyController.InteractiveObject.Works._items[0].ParentJoint:get_Position()
    if distance~=0.0 and distance<rangeSq then
        local success,pos=pcall(getCharacterPos,deadBodyController.Chara)
        if not success or pos==nil then
            waitingBodyControllerList[deadBodyController]=nil
            return
        end
        local ct=0

        --ÏÞÖÆ×î´ó³¢ÊÔ´ÎÊý£¬·ÀÖ¹³¬¹ý¶ÑµþÉÏÏÞÊ±²»Í£Ã°ÎÞ·¨»ñµÃµÀ¾ßµÄÌáÊ¾
        local maxNum=deadBodyController.GatherContext._Num
        if deadBodyController.ItemDropInfo~=nil then
            local lotlist=deadBodyController.ItemDropInfo._LotList
            if lotlist~=nil then
                for i=0,lotlist:get_Count()-1 do
                    if maxNum<lotlist[i]._Num then
                        maxNum=lotlist[i]._Num
                    end
                end
            end
        end
        local additionalItem=deadBodyController.Chara:get_ExtendedGatherContext().HasAdditionalItemByAbility
        if additionalItem._HasValue and additionalItem._Value then
            maxNum=maxNum+1
        end
        Log("Start Loot",maxNum)
        --Log("--",deadBodyController.GatherContext._Num,distance,deadBodyController:get_IsDropItemPickuped(),deadBodyController:get_IsDisableInteract(),deadBodyController:isDead(),deadBodyController:isInteractEnable(0),deadBodyController.Chara:get_CharaIDString())
        --item over 99 will be gone and consume loot chance sometimes? but not consumeing loot chance sometimes?

	    while deadBodyController:get_IsEnablePickup()==true and deadBodyController:isInteractEnable(0) and ct<50 and ct<maxNum do --prevent infinite loop,shouldn't happen?
    		deadBodyController:executeInteract(0, playerManager:get_ManualPlayer())
		    ct=ct+1
            --break
	    end

        AddMessage("Loot "..ct,pos)
        waitingBodyControllerList[deadBodyController]=nil
    end
end




local executeBodyPartInteract=sdk.find_type_definition("app.DropPartsController"):get_method("executeInteract")
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
    local distance=DistanceSq(dropPartsController.PartsRoot:get_Position())

    --Log("2",distance,dropPartsController:getDropItemData().Item1,dropPartsController:getDropItemData().Item2,interObject:getDistanceSqFromPlayer(0),
    --    dropPartsController["<IsDropSetup>k__BackingField"],
    --    "--",dropPartsController.PartsRoot)

    if  distance~=0.0 and distance<rangeSq then
        --dropPartsController:startInteract(0,mainplayer)
        --Log("3",distance,dropPartsController:getDropItemData().Item1,dropPartsController:getDropItemData().Item2,interObject:getDistanceSqFromPlayer(0),
        --    interObject:getInteractPointPosition(0).x,interObject:getInteractPointPosition(0).y,interObject:getInteractPointPosition(0).z,
        --    interObject:get_NumInteractPoints())
        local pos=interObject:getInteractPointPosition(0)
        local ct=0

        --DropItemData£º<id,num>
        local maxNum=dropPartsController:getDropItemData().Item2
        --local dropItems=dropPartsController.DropPartsData:get_DropItems()
        --local maxNum=context:get_ItemNum()

        Log("Start Loot Body Part",maxNum)
        --interObject:isInteractEnable(0) returns false
	    while ct<20 and ct<maxNum do
            executeBodyPartInteract:call(dropPartsController,0,playerManager:get_ManualPlayer())
            if not dropPartsController:get__DropPartsContext():get_IsInteracted() then
                waitingBodyControllerList[dropPartsController]=nil
                return
            end
		    ct=ct+1
            --break
	    end
        --executeInteract²»»áÈÃÎ²°Í±äÎª²»¿Éloot×´Ì¬£¬²»¹Üµ÷ÓÃ¶àÉÙ´Î£¬Ã¿´Î¶¼»á»ñµÃÒ»¸öÎïÆ·£¬×îºóÎ²°Í»¹¿ÉÒÔÕý³£lootÒ»´Î²ÅÏûÊ§
        --ÐèÒªµ÷ÓÃunregisterInteractiveObject²ÅÄÜÈÃÎ²°Í½áÊø¿Éloot×´Ì¬£¬µ«ÊÇÈç¹ûÒ»´Î¶¼Ã»µ÷ÓÃexecuteInteract£¬unregisterInteractiveObject²»»áÉúÐ§£¿
        if maxNum>0 then
            dropPartsController:unregisterInteractiveObject()
        end
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

local pendingGatherEnds={}
local gatherEndFrames=0
local function LootGm82_009(gimmick)
    if gimmick:isInteractEnable(0)==true and gimmick:get_IsEndGather()==false then
        --gimmick:get_DistanceXZSqFromPlayer and FarDistanceSq/NearDistanceSq for some gimmick are fix value 
        --GM82_009_10 will trigger repeatly and distance is always 0.0
        local distance=DistanceSqGimmick(gimmick) -- gimmick.InteractiveObject:getDistanceSqFromPlayer(0)
        --local distance2=gimmick:get_DistanceXZSqFromPlayer()
        --treat 0.0 disatance as invalid
        if distance~=0.0 and distance<rangeSq then
            --call StartInteract only causes pickup action
            Log("Loot Gimmick82_009:"..tostring(gimmick.IsGivedItem).."/"..tostring(gimmick.TurnOn).."/"..tostring(gimmick.IsEnd))
            -- at somepoint, if you don't end it ,it will still be interactable
            -- startInteractSubä¼šå°†ç¼–å·åŠ å…¥nolistè€Œä¸è§¦å‘é‡‡é›†åŠ¨ä½œã€‚
            gimmick:startInteractSub(0, playerManager:get_ManualPlayer())
            pendingGatherEnds[gimmick]=playerManager:get_ManualPlayer()
            gatherEndFrames=1
            gimmick:onExecuteInteractBase(0, playerManager:get_ManualPlayer())
            AddMessage("Loot 1 ", gimmick:get_GameObject():get_Transform():get_Position())
        end
    end
end

--¶ªÆúµÄÎïÆ·ºÍ¹ÖÎïµôÂäµÄÎïÆ·
local function LootGm82_000_001(gimmick)
    if gimmick:isInteractEnable(0)==true then
        if gimmick.MyContext:get_IsPLDumped() then
            if not config.lootPlayerDropItem then return end
        elseif not config.lootDropItem then
            return
        end
        local distance= DistanceSqGimmick(gimmick) --gimmick.InteractiveObject:getDistanceSqFromPlayer(0)
        --treat 0.0 disatance as invalid
        if distance~=0.0 and distance<rangeSq then
            Log("Loot Gimmick82_000_001",distance,gimmick:getItemId(),gimmick:getItemNum())
            local msg="Loot "..gimmick:getItemNum() -- num became 0 after interact
            --executeInteract do nothing
            gimmick:onStartInteractBase(0, playerManager:get_ManualPlayer())
            gimmick:onExecuteInteractBase(0, playerManager:get_ManualPlayer())
            gimmick:onEndInteractBase(0, playerManager:get_ManualPlayer())
            AddMessage(msg,gimmick:get_GameObject():get_Transform():get_Position())
        end
    end
end

--±¾À´¾ÍÔÚµØÍ¼ÉÏµÄÎïÆ·
--not include seeker's token:82_036
local function LootGm82_000(gimmick)
    if gimmick:isInteractEnable(0)==true then
        local distance = DistanceSqGimmick(gimmick) --gimmick.InteractiveObject:getDistanceSqFromPlayer(0)
        --treat 0.0 disatance as invalid
        if distance~=0.0 and distance<rangeSq then
            Log("Loot Gimmick82_000",distance,gimmick:getItemId(),gimmick:getItemNum())
            local msg="Loot "..gimmick:getItemNum() -- num became 0 after interact
            --gimmick:onStartInteractBase(0,mainplayer)
            --gimmick:onExecuteInteractBase(0,mainplayer)
            --gimmick:onEndInteractBase(0,mainplayer)
            --gimmick:endInteract(0)
            --only this works,but each frame only work for one item?
            gimmick:requestForceInteract(0, playerManager:get_ManualPlayer())
            AddMessage(msg,gimmick:get_GameObject():get_Transform():get_Position())
            return true
        end
    end
    return false
end

--seekers token
local function LootGm82_036(gimmick)
    if gimmick:isInteractEnable(0)==true then
        local distance = DistanceSqGimmick(gimmick) --gimmick.InteractiveObject:getDistanceSqFromPlayer(0)
        --treat 0.0 disatance as invalid
        if distance~=0.0 and distance<rangeSq then
            Log("Loot Gimmick82_036",distance,gimmick:get_IsGetFreeBit())
            --onEndInteractBase and requestForceInteract both works
            --gimmick:onEndInteractBase(0,mainplayer)
            gimmick:requestForceInteract(0, playerManager:get_ManualPlayer())
            AddMessage("Loot Seeker's Token",gimmick:get_GameObject():get_Transform():get_Position())
            return true
        end
    end
    return false
end

--norgan ducat
local function LootGm83_169(gimmick)
    if gimmick:isInteractEnable(0)==true then
        local distance = DistanceSqGimmick(gimmick) --gimmick.InteractiveObject:getDistanceSqFromPlayer(0)
        --treat 0.0 disatance as invalid
        if distance~=0.0 and distance<rangeSq then
            Log("Loot Gimmick83_169",distance,gimmick:get_IsGetFreeBit())
            gimmick:requestForceInteract(0, playerManager:get_ManualPlayer())
            AddMessage("Loot Norgan Ducat",gimmick:get_GameObject():get_Transform():get_Position())
            return true
        end
    end
    return false
end

--chest
-- Open immediately only inside AutoLoot's own start interaction.
local autoLootStartingChests={}
sdk.hook(
    sdk.find_type_definition("app.gm80_001"):get_method("open(System.Boolean, app.Character)"),
    function(args)
        local chestAddress=autoLootStartingChests[thread.get_id()]
        if chestAddress and sdk.to_int64(args[2])==chestAddress
            and (sdk.to_int64(args[3])&0xff)==0 then
            args[3]=sdk.to_ptr(1)
        end
    end,
    nil,
    true
)

local function LootGm80_001(gimmick)
    if gimmick:get_type_definition():is_a("app.gm80_097") and gimmick._IsSeal then
        return false
    end
    -- Leave chests requiring keys to manual interaction.
    if gimmick.UnlockItem~=0 then
        return false
    end
    -- Leave the Sunken Spire event chest to the player for its native cutscene sequence.
    if gimmick.GimmickParamId==301001 then
        return false
    end
    if gimmick:isInteractEnable(0)==true then
        local distance = DistanceSqGimmick(gimmick) --gimmick.InteractiveObject:getDistanceSqFromPlayer(0)
        --local dis2 = DistanceSq(mainplayer:get_GameObject():get_Transform():getJointByName("root"):get_Position(),dropPartsController.PartsRoot:get_Position())
        --treat 0.0 disatance as invalid
        --local p =gimmick:getJointByName("root"):get_Position()
        --Log("--", mainplayer:get_GameObject():get_Transform():getJointByName("root"):get_Position().x,mainplayer:get_GameObject():get_Transform():getJointByName("root"):get_Position().y,mainplayer:get_GameObject():get_Transform():getJointByName("root"):get_Position().z," /",distance, "..", DistanceSqGimmick(gimmick))

        if distance~=0.0 and distance<rangeSq then
            Log("Loot Chest",distance,gimmick:get_IsOpenedFreeBit())
            --requestForceInteract not work
            --onExecuteInteractBase get the item repeatly without changing chest state
            --onStartInteractBase/open(false,player) force player go to open chest and change chest state without get the Item
            --open(true,player) change chest state
            local threadId=thread.get_id()
            local previous=autoLootStartingChests[threadId]
            autoLootStartingChests[threadId]=gimmick:get_address()
            local ok,err=pcall(function()
                gimmick:onStartInteractBase(0,mainplayer)
            end)
            autoLootStartingChests[threadId]=previous
            if not ok then error(err,0) end
            gimmick:onExecuteInteractBase(0, playerManager:get_ManualPlayer())
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
            interval=0
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
        end
    end,
    nil
)

local getGimmickListMethod=sdk.find_type_definition("app.GimmickManager"):get_method("getGimmickList(app.GimmickID)")
local gimmick82_036=sdk.find_type_definition("app.GimmickID"):get_field("Gm82_036"):get_data(nil)
local gimmick83_169=sdk.find_type_definition("app.GimmickID"):get_field("Gm83_169"):get_data(nil)
local directItemGimmickIds={
    sdk.find_type_definition("app.GimmickID"):get_field("Gm82_000"):get_data(nil),
    sdk.find_type_definition("app.GimmickID"):get_field("Gm82_000_10"):get_data(nil),
}

--check nearby gimmick instances each 90 frame
--changed from update() to lateUpdate() because update was never called since that version
--changed back to update() becasue now lateupdate is never called
local interval2=0
sdk.hook(
    sdk.find_type_definition("app.GimmickManager"):get_method("update()"),
    function()
        -- gimmickå¼€å§‹äº¤äº’æ—¶ä¼šå°†ç¼–å·å†™å…¥`GimmickBase.InteractNoList` ï¼Œå¿…é¡»åœç•™ä¸€å¸§åŽå†ç§»é™¤ä»»åŠ¡æ‰èƒ½æ£€æµ‹åˆ°æœºå…³è¢«è§¦å‘ã€‚
        if gatherEndFrames>0 then
            gatherEndFrames=gatherEndFrames-1
            if gatherEndFrames==0 then
                for gimmick,player in pairs(pendingGatherEnds) do
                    pendingGatherEnds[gimmick]=nil
                    local ok,err=pcall(function() gimmick:onEndInteractBase(0,player) end)
                    if not ok then Log("Failed to end gathering interaction: "..tostring(err)) end
                end
            end
        end
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
            if config.lootPlayerDropItem or config.lootDropItem then
                --iterate gimmick82_000_001
                local gimmicks=gimmickManager:get_DropItemGimmicks()
                local g_ct=gimmicks:get_Count()-1
                for i=0,g_ct do
                    LootGm82_000_001(gimmicks[i])
                end
            end
            if config.lootDirectItem then
                -- Include fixed-position items; request at most one pickup across both lists.
                local looted=false
                for _,gimmickId in ipairs(directItemGimmickIds) do
                    local gimmicks=getGimmickListMethod(gimmickManager,gimmickId)
                    local g_ct=gimmicks:get_Count()-1
                    for i=0,g_ct do
                        if LootGm82_000(gimmicks[i]) then
                            looted=true
                            break
                        end
                    end
                    if looted then break end
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
            if config.lootNorganDucat then
                --iterate gimmick83_169
                local gimmicks=getGimmickListMethod(gimmickManager,gimmick83_169)
                local g_ct=gimmicks:get_Count()-1
                for i=0,g_ct do
                    if LootGm83_169(gimmicks[i]) then
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
--ÐÂµôÂäµÄÎ²°ÍÓÐÊ±Ö»»á´¥·¢OnPartsBroken¶ø²»´¥·¢setupInteractiveObject£¿
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
