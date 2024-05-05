local modname="GainItem"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local onClickFunc=nil
local onAddToFavList=nil
local onFavListClick=nil

local _config={
    {name="item",type="item",default=1},
    {name="count",type="int",default=1,min=1,max=99},
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
    {type="author"}
}

local myapi = require("_XYZApi/_XYZApi")
local config=myapi.InitFromFile(_config,configfile)

local function Log(msg)
    print(msg)
    log.info(modname..msg)
end

local Gold=93 -- item 1G
local function OnChanged()
    if config.item==Gold then 
        _config[2].max=999999
    else 
        _config[2].max=99
    end
end

--Should Add this to api
local inited=false
local font=nil
local function Init()
    if font==nil then
        --reload font everytime,in case the font is not right on first init
        font = myapi.LoadFontIfCJK("simhei.ttf",nil,nil)
    end
    if not inited then
        myapi.DrawIt(modname,configfile,_config,config,OnChanged,true,function() return font end)
        inited=true
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

    --Gather TreasureBox Talk DeadEnemy
    local type=sdk.find_type_definition("app.ItemManager.GetItemEventType"):get_field("TreasureBox"):get_data()
    local getItemMethod=im:get_type_definition():get_method("getItem(System.Int32, System.Int32, app.CharacterID, System.Boolean, System.Boolean, System.Boolean, app.ItemManager.GetItemEventType)")

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
            getItemMethod:call(im,WakestoneShards,left_ct-ct,storageid,true,false,false,1)
        elseif left_ct<ct then
            Log("Reduce Shards "..tostring(ct-left_ct))
            deleteMethod:call(im,WakestoneShards,ct-left_ct,storageid)
        end
        if stone_ct>0 then
            getItemMethod:call(im,Wakestone,stone_ct,storageid,true,false,false,1)        
        end
        Log("Modify WakeStoneShards "..ct.."/"..total_ct.."/"..left_ct)
    else
        if isRemove then
            deleteMethod:call(im,math.floor(config.item),math.floor(config.count),storageid)
            Log("Remove Item")
        else
            getItemMethod:call(im,math.floor(config.item),math.floor(config.count),storageid,true,false,false,1)
            Log("Get Item")
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
        table.insert(config.FavList,favitem)
    end
end

onRemoveFromFavList=function()
    if config.item==nil or config.FavList==nil then return end
    for k,v in pairs(config.FavList) do
        if v.index==config.item then
            config.FavList[k]=nil
        end
    end
end

onFavListClick=function(para)
    if para[1]~=nil then config.item=para[1] end
end