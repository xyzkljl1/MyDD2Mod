local modname="GainItem"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local onClickFunc=nil
local onAddToFavList=nil
local onFavListClick=nil
local onRemoveFromFavList=nil

local relicSourceOption={name="RelicSource",label="Relic: Source Variant",type="stringComboBox",list={},hide=true}
local relicJobOption={name="RelicJob",label="Relic: Vocation",type="stringComboBox",list={},hide=true}
local _config={
    {name="item",type="item",default=1},
    {name="count",type="int",default=1,min=1,max=99},
    relicSourceOption,
    relicJobOption,
    {name="Add or Remove Item",type="mutualbox"},
    {name="SendToPlayer",type="button",onClick=function() onClickFunc("Player") end,sameline=true},
    {name="SendToStorage",type="button",onClick=function() onClickFunc("Storage") end},
    {name="SendToPawn1",type="button",onClick=function() onClickFunc("Pawn",0) end,sameline=true},
    {name="SendToPawn2",type="button",onClick=function() onClickFunc("Pawn",1) end,sameline=true},
    {name="SendToPawn3",type="button",onClick=function() onClickFunc("Pawn",2) end},
    {name="RemoveFromPlayer",type="button",onClick=function() onClickFunc("Player",nil,true) end},
    {name="Favourite List",type="mutualbox"},
    {name="AddToFavList",type="button",onClick=function() onAddToFavList() end,sameline=true},
    {name="RemoveFromFavList",type="button",onClick=function() onRemoveFromFavList() end},
    {name="FavList",type="buttonN",onClick=function(...) onFavListClick(...) end,default={}},
    {type="mutualboxend"},
    {type="author",version="1.4.6"}
}

local myapi = require("_XYZApi/_XYZApi")
local config=myapi.InitFromFile(_config,configfile)
local favKeys=nil
setmetatable(config.FavList,{__pairs=function(list)
    if favKeys==nil then
        favKeys={}
        for key in next,list do favKeys[#favKeys+1]=key end
        table.sort(favKeys,function(a,b) return list[a].index<list[b].index end)
    end
    local keys=favKeys
    local i=0
    return function()
        i=i+1
        local key=keys[i]
        if key~=nil then return key,list[key] end
    end
end})

local function Log(msg)
    print(msg)
    log.info(modname..msg)
end

local itemDefine=sdk.find_type_definition("app.ItemDefine")
local appraisalDefine=sdk.find_type_definition("app.GUIAppraisalDefine")
local getFakeItemId=itemDefine:get_method("getFakeItemId(System.Int32)")
local isFakeAppraisal=itemDefine:get_method("isFakeAppraisalItemId(System.Int32)")
local isAppraisal=appraisalDefine:get_method("isAppraisalItem(System.Int32)")
local getJobName=sdk.find_type_definition("app.GUIBase"):get_method("getJobName(System.Int32)")
local messageType=sdk.find_type_definition("via.gui.message")
local getMessageId=messageType:get_method("getGuidByName(System.String)")
local getMessage=messageType:get_method("get(System.Guid, via.Language)")
local japanese=sdk.find_type_definition("via.Language"):get_field("Japanese"):get_data()
local relicItemId=nil
local relicSources={}
local relicSelected=false
config.RelicJob=config.RelicJob or 9

local function RefreshRelicOptions()
    local id=math.floor(config.item)
    local isFake=isFakeAppraisal:call(nil,id)
    relicSelected=id~=654 and id~=655 and (isFake or isAppraisal:call(nil,id))
    relicSourceOption.hide=true
    relicJobOption.hide=true
    if id~=relicItemId then
        relicItemId=id
        relicSources={}
        relicSourceOption.list={}
        relicSourceOption.tmp_List=nil
    end
    if not relicSelected then return end

    if next(relicSources)==nil then
        local am=sdk.get_managed_singleton("app.ItemAppraisalManager")
        local fixed=am and am:get_field("FixedItemSettingDict")
        if fixed and fixed:call("ContainsKey",id) then
            -- Fixed appraisal items are granted directly without source/vocation metadata.
            relicSelected=false
            return
        end
        local settings=am and am:get_field("ItemSettingDict")
        if settings==nil then return end
        local iter=settings:call("System.Collections.IEnumerable.GetEnumerator()")
        while iter:MoveNext() do
            local data=iter._current.value:get_field("data")
            if data~=nil then
                local source=data:get_field("itemId")
                if getFakeItemId:call(nil,source)==id or (source==id and not isFake) then
                    relicSources[source]=data
                    -- Intermediate relics have empty translated names; use their Japanese originals.
                    local guid=getMessageId:call(nil,"item_name_"..source)
                    relicSourceOption.list[source]=getMessage:call(nil,guid,japanese)
                end
            end
        end
    end
    if relicSources[config.RelicSource]==nil then
        config.RelicSource=nil
        for source in pairs(relicSources) do
            if config.RelicSource==nil or source<config.RelicSource then config.RelicSource=source end
        end
    end
    local data=relicSources[config.RelicSource]
    if data==nil then return end

    relicJobOption.list={}
    relicJobOption.tmp_List=nil
    local firstJob=nil
    for job=0,10 do
        local candidates=data:call("getJobDataList(app.Character.JobEnum)",job)
        if candidates~=nil and candidates:call("get_Count()")>0 then
            relicJobOption.list[job]=job==0 and "Default (no vocation)" or getJobName:call(nil,job)
            firstJob=firstJob or job
        end
    end
    if relicJobOption.list[config.RelicJob]==nil then config.RelicJob=firstJob end
    if firstJob==nil then return end
    relicSourceOption.hide=false
    relicJobOption.hide=false
end

local Gold=93 -- item 1G
local function OnChanged()
    if config.item==Gold then 
        _config[2].max=999999
    else 
        _config[2].max=99
    end
    RefreshRelicOptions()
end

--Should Add this to api
local inited=false
local font=nil
local function Init()
    relicItemId=nil
    OnChanged()
    if font==nil then
        --reload font everytime,in case the font is not right on first init
        font = myapi.LoadFontIfCJK("simhei.ttf",nil,nil)
    end
    if not inited then
        myapi.DrawIt(modname,configfile,_config,config,OnChanged,true,function() return font end)
        inited=true
    end
end

-- Skip selected item tutorials to avoid crashes.
local function BlockTutorial(args)
	local storage = thread.get_hook_storage()
	-- false means "keep it original", true means "Skip this"
	storage["skip"] = false
	-- 113 is Tome tutorial
	-- when tome is gained, requestTutorial will be called twice,id will be 113 and x(eg.115).The second call doesn't matter.
	local tutorialId=sdk.to_int64(args[3]) & 0xffffffff
	Log("Request tutorial "..tutorialId)
	if tutorialId == 113 or tutorialId == 194 or tutorialId == 218 or tutorialId == 212 or tutorialId == 203 or tutorialId == 208 or tutorialId == 220 or tutorialId == 221 or tutorialId == 231 then
		storage["skip"] = true
		return sdk.PreHookResult.SKIP_ORIGINAL
	end
end
local function BlockTutorialPost(retval)
	if thread.get_hook_storage()["skip"] then
		Log("Skip tutorial")
		return sdk.to_ptr(true)
	end
end

--delay init
local initFrameCt=0
re.on_frame(function()
    if initFrameCt<300 then
        initFrameCt=initFrameCt+1
        if initFrameCt==300 then
            Log("Delay Init")
            Init()
            sdk.hook(sdk.find_type_definition("app.OptionManager"):get_method("app.ISystemSaveData.loadSystemSaveData(app.SaveDataBase)"),nil,Init)
            sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),nil,Init)
            sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("requestTutorial"),BlockTutorial,BlockTutorialPost)
        end
    end
end)
local Wakestone=77
local WakestoneShards=78


local function AddItem(dest,index,remove)
    local im=sdk.get_managed_singleton("app.ItemManager")
    local player_man=sdk.get_managed_singleton("app.CharacterManager")
    local player=player_man:get_ManualPlayer()
    if im==nil or player==nil then return end
    local isRemove=(remove==true)

    --None Gather TreasureBox Talk DeadEnemy
    local type=sdk.find_type_definition("app.ItemManager.GetItemEventType"):get_field("None"):get_data()
    local option=sdk.find_type_definition("app.ItemDefine.GetItemOption"):get_field("Default"):get_data()
    option.IsNotice=true
    option.IsAddExtensionData=false
    option.IsHistory=false
    option.EventType=type
    local getItemMethod=im:get_type_definition():get_method("getItem(System.Int32, System.Int32, app.CharacterID, app.ItemDefine.GetItemOption)")

    local storageid=player:get_CharaID()
    if dest=="Pawn" then
        local pawns=sdk.get_managed_singleton("app.PawnManager"):get_PartyPawnList()
        if pawns:get_Count()<=index then return end
        local pawnchara=pawns[index]:get_CachedCharacter()    
        if pawnchara==nil then return end
        storageid=pawnchara:get_CharaID()
    elseif dest=="Storage" then
        storageid=65535
    end
    local deleteMethod=im:get_type_definition():get_method("deleteItem(System.Int32, System.Int32, app.CharacterID)")
    --wakestone shards->wakestone causes crash.Can't  fix it.
    -- so just remove shards and give wakestone
    if config.item == WakestoneShards and not isRemove then
        --for funcs has overload ,must use get_method
        local getNumMethod=im:get_type_definition():get_method("getHaveNum(System.Int32, app.CharacterID)")
        local ct=getNumMethod:call(im,WakestoneShards,storageid)
        local total_ct=math.floor(config.count)+ct
        local stone_ct=math.floor(total_ct/3)
        local left_ct=total_ct-stone_ct*3

        if left_ct >ct then
            Log("Add Shards "..tostring(left_ct-ct))
            getItemMethod:call(im,WakestoneShards,left_ct-ct,storageid,option)
        elseif left_ct<ct then
            Log("Reduce Shards "..tostring(ct-left_ct))
            deleteMethod:call(im,WakestoneShards,ct-left_ct,storageid)
        end
        if stone_ct>0 then
            getItemMethod:call(im,Wakestone,stone_ct,storageid,option)
        end
        Log("Modify WakeStoneShards "..ct.."/"..total_ct.."/"..left_ct)
    else
        if isRemove then
            deleteMethod:call(im,math.floor(config.item),math.floor(config.count),storageid)
            Log("Remove Item")
        else
            RefreshRelicOptions()
            if relicSelected then
                if relicSources[config.RelicSource]==nil or relicJobOption.list[config.RelicJob]==nil then
                    Log("Relic metadata is not ready. Select a valid source variant and vocation.")
                    return
                end
                option.IsAddExtensionData=true
                option.ExtensionValue=config.RelicJob
                -- Each relic needs its own source/job record in the game's metadata queue.
                for _=1,math.floor(config.count) do
                    getItemMethod:call(im,config.RelicSource,1,storageid,option)
                end
                Log(string.format("Get Item %d (source=%d, job=%d)",config.item,config.RelicSource,config.RelicJob))
            else
                getItemMethod:call(im,math.floor(config.item),math.floor(config.count),storageid,option)
                Log("Get Item")
            end
        end
    end        
end

onClickFunc=AddItem
onAddToFavList=function()
    if config.item==nil then return end
    local itemDict=sdk.get_managed_singleton("app.ItemManager"):get_ItemDataDict()
    local item=itemDict:get_Item(config.item)
    if item~=nil then
        if config.FavList~=nil then
            for _,v in pairs(config.FavList) do
                if v.index==config.item then
                    return
                end
            end
        end
        local favitem={
            index=config.item,
            name=config.item.." / "..item:get_Name()
        }
        config.FavList=config.FavList or {}
        config.FavList["item_"..config.item]=favitem
        favKeys=nil
    end
end

onRemoveFromFavList=function()
    if config.item==nil or config.FavList==nil then return end
    for k,v in pairs(config.FavList) do
        if v.index==config.item then
            config.FavList[k]=nil
            favKeys=nil
        end
    end
end

onFavListClick=function(para)
    if para[1]~=nil then config.item=para[1] end
end
