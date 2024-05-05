local modname="_XYZAPI"
local vecNames={
    ".x",
    ".y",
    ".z",
    ".w"
}
local vecNamesColor={
    ".R",
    ".G",
    ".B",
    ".A"
}

local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
local hk = prequire("Hotkeys/Hotkeys")
local itemNames=nil
local itemIds=nil
local itemIndex2itemId={}
local itemId2itemIndex={}

--local defaultCNFont=nil
local function Log(...)
    print(...)
    for k,v in ipairs{...} do
        log.info("["..modname.."]"..tostring(v))
    end
end

local function isDD2()
    return reframework.get_game_name()=="dd2"
end

local function setupHotKey(_config,config)
    if hk~=nil then
        local hotkeys={}
        for idx,para in pairs(_config) do
            if para.type=="hotkey" then   
                local key = para.name
                local actionName = para.actionName or key
                hotkeys[actionName]=config[key]
            end
        end
        hk.setup_hotkeys(hotkeys)
    end
end
local function recurse_def_settings(tbl, new_tbl)
	for key, value in pairs(new_tbl) do
		if type(tbl[key]) == type(value) then
		    if type(value) == "table" then
			    tbl[key] = recurse_def_settings(tbl[key], value)
            else
    		    tbl[key] = value
            end
        elseif type(value)~=nil and type(tbl[key])~=nil then
            -- for boolList default value
            tbl[key]=value
		end
	end
	return tbl
end

local function Enum2Map(typeName,from)
    from=from or 1
    local id2name={}
    local name2id={}
    local fields=sdk.find_type_definition(typeName):get_fields()
    for _,field in pairs(fields) do
        local value=field:get_data()
        if value~=nil and value >= from then
            id2name[value]=field:get_name()
            name2id[field:get_name()]=value
            --print(field:get_name(),value)
        end
    end
    return id2name,name2id
end

local function InitFromFile(_config,configfile,dontInitHotkey)
    --merge config file to default config
    local config = {} 
    for key,para in ipairs(_config) do
        if para.name~=nil then
            if type(para.default)=="table" then
                config[para.name]=DeepCopyTable(para.default)
            else
                config[para.name]=para.default
            end
        end
    end
    config= recurse_def_settings(config, json.load_file(configfile) or {})
    if dontInitHotkey~=true then
        setupHotKey(_config,config)
    end
    return config
end

local function DD2_InitItemId()
    if isDD2()==false then return end
    -- imgui.combo seems not to sort by number index when there are many items.Use continuous index to force it sort
    itemNames={}
    local id2Name={}
    itemIds={}
    local im=sdk.get_managed_singleton("app.ItemManager")
    local iter=im._ItemDataDict:GetEnumerator()
    --可以直接从app.ItemIDEnum取ID,但是里面有invalid物品
    iter:MoveNext()
    while iter:get_Current():get_Value()~=nil do
        local itemCommonParam=iter:get_Current():get_Value()
        local name=itemCommonParam:get_Name()
        if name ~="Invalid" and name~=nil then
            id2Name[itemCommonParam._Id]= string.format("%5d /%s",itemCommonParam._Id,itemCommonParam:get_Name())
            table.insert(itemIds,itemCommonParam._Id)
        end
        iter:MoveNext()
    end
    table.sort(itemIds)
--    print("{")
    for _,id in pairs(itemIds) do
        table.insert(itemNames,id2Name[id])
        itemIndex2itemId[#itemNames]=id
        itemId2itemIndex[id]=#itemNames
--        print(string.format("\"%d\":\"%s\",",id,id2Name[id]))
    end
--    print("}")
    Log("Init Item List")
end

if isDD2()==true then
    --dlc item is not in items at the first,need retry
    sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),nil,DD2_InitItemId)
    --get_Message return is decided by current language, so need to fetch item messages when option loaded
    sdk.hook(sdk.find_type_definition("app.OptionManager"):get_method("app.ISystemSaveData.loadSystemSaveData(app.SaveDataBase)"),
    nil,DD2_InitItemId)
end

function DeepCopyTable(t)
  local ret = { }
  for k,v in pairs(t) do ret[k] = v end
  return setmetatable(ret, getmetatable(t))
end

--Chinese font need pass CJK_GLYPH_RANGES as [ranges] when load and the lua file need to be unicode
local function DrawIt(modname,configfile,_config,config,OnChange,dontInitHotkey,font)
    configfile=configfile or (modname..".json")
    Log("CAll DrawIt")
    if dontInitHotkey~=true then
        setupHotKey(_config,config)
    end

    if itemNames==nil then
        DD2_InitItemId()
    end

    re.on_draw_ui(function()
        local changed=false--tmp
        local _changed=false--final

        local isFontChanged=false
        if font~=nil then
            if type(font)=="number" then
                imgui.push_font(font)
                isFontChanged=true
            elseif type(font)=="function" then
                local tmp=font()
                if tmp~=nil then
                    imgui.push_font(tmp)
                    isFontChanged=true
                end
            end
        end
        local triggeredButtons={}
	    if imgui.tree_node(modname) then
		    --imgui.same_line()
		    --imgui.text("*Right click on most options to reset them")
            local isInMutualBox=false
		    imgui.begin_rect()
            for _,para in ipairs (_config) do
                local key = para.name
                local actionName = para.actionName or key
                local title_postfix=""
                local pushed_item_width=false
                if para.needrestart==true or para.type=="fontsize" or para.type=="font" then
                    title_postfix=" (Need Restart To Apply)"
                elseif para.needreentry==true then
                    title_postfix=" (Need Return to Title to Apply)"
                end
                if para.widthscale~=nil then
                    imgui.push_item_width(imgui.calc_item_width()*para.widthscale)
                    pushed_item_width=true
                end

                local label=para.label or key

                if para.type=="int" then
        		    changed , config[key]= imgui.drag_int(label .. title_postfix, 
                                                            config[key] or para.default or para.min or 0,
                                                            para.step or 1 , para.min or 0, para.max or 100)
                    _changed=changed or _changed
                elseif para.type=="intPercent" then
        		    changed , config[key]= imgui.drag_int(label .. title_postfix, 
                                                            config[key] or para.default or para.min or 0,
                                                            para.step or 1 , para.min or 0, para.max or 100)
                    _changed=changed or _changed
                elseif para.type=="fontsize" then
                    changed , config[key]= imgui.drag_int(label .. title_postfix, 
                                                            config[key] or para.default or para.min or 30,
                                                            para.step or 1 , para.min or 1, para.max or 300)
                    _changed=changed or _changed
                elseif para.type=="intN" then
                    --Start From 1!
                    local width=para.width or 215
                    imgui.push_item_width(width)
                    for _k,_ in pairs (config[key]) do
                        local vname=vecNames[_k] or ".".._k
            		    changed , config[key][_k] = imgui.drag_int(key..vname .. title_postfix, 
                                                             config[key][_k] or para.default or para.min or 0,
                                                             para.step or 1 , para.min or 0, para.max or 100)
                        _changed=changed or _changed
                        imgui.same_line()
                    end
                    imgui.pop_item_width()
                    imgui.new_line()
                elseif para.type=="rgba4f" then -- float 4
                    --Start From 1!
                    local width=para.width or 130
                    imgui.push_item_width(width)
                    for _k,_ in pairs (config[key]) do
                        local vname=vecNamesColor[_k] or ".".._k
            		    changed , config[key][_k] = imgui.drag_float(label..vname .. title_postfix, 
                                                                config[key][_k] or para.default or para.min or 0,
                                                                para.step or 0.01 , para.min or 0.0, para.max or 1.0)
                        _changed=changed or _changed
                        imgui.same_line()
                    end
                    imgui.pop_item_width()
                    imgui.new_line()
                elseif para.type=="boolList" then
                	if imgui.tree_node(para.name..title_postfix) then
                        if para.tmp_list==nil and para.default~=nil then
                            para.tmp_list=DeepCopyTable(para.default)
                        end
                        if para.tmp_sortListKey==nil then
                            para.tmp_sortListKey={}
                            for _k,_ in pairs(para.tmp_list) do
                                table.insert(para.tmp_sortListKey,_k)
                            end
                            table.sort(para.tmp_sortListKey)
                        end

                        imgui.push_item_width(imgui.calc_item_width()*0.5)
                        local clicked=imgui.button("UncheckAll")
                        if clicked==true then
                            for _,_k in pairs(para.tmp_sortListKey) do
                                config[key][_k]=false
                            end
                            _changed=true
                        end
                        imgui.same_line()
                        clicked =imgui.button("CheckAll")
                        if clicked==true then 
                            config[key]=DeepCopyTable(para.tmp_list) 
                            _changed=true
                            end
                        imgui.pop_item_width()

                        local checked=false
                        for _,_k in pairs(para.tmp_sortListKey) do
                            local _v=para.tmp_list[_k]
                            changed, checked = imgui.checkbox(_k.." / ".._v, config[key][_k]~=false)
                            _changed=changed or _changed
                            if checked then config[key][_k]=_v
                            --nil won't be saved,has to be false
                            else config[key][_k]=false  end
                        end
                    end
                elseif para.type=="font" or para.type=="string" then
        		    changed , config[key]= imgui.input_text(label .. title_postfix, config[key] or para.default)
                    _changed=changed or _changed
                elseif para.type=="hotkey" then
                    if hk~=nil then
                		changed = hk.hotkey_setter(actionName, nil, nil, label); 
                        config[key]=hk.hotkeys[actionName]
                        _changed=changed or _changed
                    else
                        --this shouldn't happen,because if a mod need hotkey setting then itself will require hotkeys.lua
                        imgui.text("Can't Modify "..label.." because lack of _ScriptCore")
                    end
                elseif para.type=="bool" then
                    --don't use "config[key] or default"
                    if config[key] ~=nil then
            		    changed , config[key]= imgui.checkbox(label .. title_postfix, config[key])
                    else
            		    changed , config[key]= imgui.checkbox(label .. title_postfix, para.default)
                    end
                    _changed=changed or _changed
                elseif para.type=="float" then
        		    changed , config[key]= imgui.drag_float(label .. title_postfix, 
                                                            config[key] or para.default or para.min or 0,
                                                            para.step or 0.1 , para.min or 0, para.max)
                    _changed=changed or _changed
                elseif para.type=="floatN" then
                    --Start From 1!
                    local width=para.width or 215
                    imgui.push_item_width(width)
                    for _k,_ in pairs (config[key]) do
                        local vname=vecNames[_k] or ".".._k
            		    changed , config[key][_k] = imgui.drag_float(key..vname .. title_postfix, 
                                                             config[key][_k] or para.default or para.min or 0,
                                                             para.step or 0.1 , para.min or 0, para.max)
                        _changed=changed or _changed
                        imgui.same_line()
                    end
                    imgui.pop_item_width()
                    imgui.new_line()
                elseif para.type=="floatPercent" then
        		    changed , config[key]= imgui.drag_float(label .. title_postfix, 
                                                            config[key] or para.default or para.min or 0,
                                                            para.step or 0.5 , para.min or 0, para.max or 100)
                    _changed=changed or _changed
                elseif para.type=="rgba32" then
                    imgui.push_item_width(imgui.calc_item_width()*0.45)
                    changed,config[key]= imgui.color_picker(label .. title_postfix, config[key])
                    _changed=changed or _changed
                    imgui.pop_item_width()
                elseif para.type=="button" then
                    local clicked=imgui.button(label..title_postfix)
                    if clicked==true and para.onClick ~=nil then
                        --will only trigger once when pressed
                        triggeredButtons[key]={func=para.onClick,para=nil}
                        _changed=true
                    end
                elseif para.type=="item" then
                    if para.enableSearch==true or para.enableSearch==nil then
                        imgui.push_item_width(imgui.calc_item_width()*0.2)
                        --Two input_text with same label will share data 
                        changed, para.tmp_SearchText = imgui.input_text("<-searh "..key .."(not sup IME) ", para.tmp_SearchText)
                        imgui.pop_item_width()
                        imgui.same_line()

                        if changed then
                            para.tmp_Items={}
                            para.itemIndex2itemId={}
                            para.itemId2itemIndex={}
                            Log("OnSerachInItem")
                            if para.tmp_SearchText~="" then
                                local lower=para.tmp_SearchText:lower()
                                for k,id in pairs(itemIds) do
                                    if itemNames[k]:lower():find(lower) then
                                        table.insert(para.tmp_Items, itemNames[k])
                                        para.itemIndex2itemId[#para.tmp_Items]=id
                                        para.itemId2itemIndex[id]=#para.tmp_Items
                                    end
                                end
                            else
                                para.tmp_Items=itemNames
                                para.itemIndex2itemId=itemIndex2itemId
                                para.itemId2itemIndex=itemId2itemIndex
                            end
                        end
                    end
                    if para.tmp_Items==nil then
                        para.tmp_Items=itemNames
                        para.itemIndex2itemId=itemIndex2itemId
                        para.itemId2itemIndex=itemId2itemIndex                            
                    end

                    imgui.push_item_width(imgui.calc_item_width()*0.5)
                    changed, tmp_idx= imgui.combo(label .. title_postfix, para.itemId2itemIndex[config[key]] ,para.tmp_Items)
                    imgui.pop_item_width()
                    
                    --Log(config[key]," ",tmp_idx)
                    config[key]=para.itemIndex2itemId[tmp_idx] or 1
                    _changed=changed or _changed
                elseif para.type=="stringComboBox" then
                    if para.tmp_List==nil then
                        para.tmp_List={}
                        para.tmp_Index2Key={}
                        para.tmp_Key2Index={}
                        for k,v in pairs(para.list) do
                            local id=#para.tmp_List+1
                            local name=string.format("%s / %s",k,v)
                            para.tmp_List[id]=name
                            para.tmp_Index2Key[id]=k
                            para.tmp_Key2Index[k]=id
                        end
                    end

                    --imgui.push_item_width(imgui.calc_item_width()*0.5)
                    changed, tmp_idx= imgui.combo(label .. title_postfix, para.tmp_Key2Index[config[key]] ,para.tmp_List)
                    --imgui.pop_item_width()
                    
                    --Log(config[key]," ",tmp_idx)
                    config[key]=para.tmp_Index2Key[tmp_idx] or para.tmp_List[1]
                    _changed=changed or _changed
                elseif para.type=="sameline" then
                    imgui.same_line()
                elseif para.type=="mutualbox" then
                    if isInMutualBox then--end prev box
                        imgui.end_rect()
                        isInMutualBox=false
                    end
                    imgui.begin_rect()
                    imgui.text_colored(para.name,para.color or 0xff11aa33)
                    isInMutualBox=true
                elseif para.type=="mutualboxend" then
                    if isInMutualBox then
                        imgui.end_rect()
                        isInMutualBox=false
                    end
                elseif para.type=="buttonN" then                   
                    if #config[key]~=0 then
                        imgui.begin_rect()
                        imgui.text_colored(para.name..title_postfix,para.color or 0xff885533)
                        for _,buttonpara in pairs(config[key]) do
                            local clicked=imgui.button(buttonpara.name)
                            --use para.OnClick,because buttonparas need to be saved into configfile
                            if clicked==true and para.onClick ~=nil then
                                --will only trigger once when pressed
                                triggeredButtons[key]={func=para.onClick,para={buttonpara.index}}
                                _changed=true
                            end
                        end
                        imgui.end_rect()
                    end
                elseif para.type=="author" then
                    imgui.text_colored(para.name or "\tAuthor: xyzkljl1",para.color or 0xffffffff)
                end
                if para.sameline==true then
                    imgui.same_line()
                end

                if para.tip ~=nil and imgui.is_item_hovered() then
                    imgui.set_tooltip(para.tip)
                end

                if pushed_item_width then
                    imgui.pop_item_width()
                end
            end
            --Add an empty line to prevent the last setting ui's last line is not shown properly
            imgui.text()

            if isInMutualBox then--end prev box
                imgui.end_rect()
            end

		    imgui.tree_pop()
        end        
        if isFontChanged then
            imgui.pop_font()
        end

        --should call before on change?
        for key,func in pairs(triggeredButtons) do 
            func.func(func.para)
        end

        if _changed==true then
            json.dump_file(configfile, config)
            if OnChange~=nil then
                OnChange()
            end
        end
    end)
end

--Language is the stem-setting Language when launch, then changed to game-setting language
--need to check lng when app.OptionManager(saveConfigFile()/app.ISystemSaveData.loadSystemSaveData(app.SaveDataBase))
local function LoadFontIfCJK(fontname,fontsize,fontrange)
    if not isDD2() then return nil end
    local CJK_GLYPH_RANGES = {
        0x0020, 0x00FF, -- Basic Latin + Latin Supplement
        --0x0400, 0x04FF, -- Cyrillic
        0x2000, 0x206F, -- General Punctuation
        0x3000, 0x30FF, -- CJK Symbols and Punctuations, Hiragana, Katakana
        --0xFF00, 0xFFEF, -- Half-width characters
        0x4e00, 0x9FAF, -- CJK Ideograms
        0,
        }
    local font =nil
    --local gm=sdk.get_managed_singleton("app.GuiManager")
    --local lng=gm:get_CurrFontLanguage()
    --if lng==sdk.find_type_definition("via.Language"):get_field("TransitionalChinese"):get_data()
    --    or lng==sdk.find_type_definition("via.Language"):get_field("SimplelifiedChinese"):get_data()
    --    or lng==sdk.find_type_definition("via.Language"):get_field("Korean"):get_data()
    --    or lng==sdk.find_type_definition("via.Language"):get_field("Japanese"):get_data()
    --    then
    local om=sdk.get_managed_singleton("app.OptionManager")
    local optionID=sdk.find_type_definition("app.OptionID"):get_field("TextLanguage"):get_data()
    if optionID==nil then
        --for certain user,scripts are load too early that this func can't get optionID
        Log("Can't find optionID.Use Default Font")
        return font
    end
    local optionItem=om._OptionItems:get_Item(optionID)
    local lng=optionItem:get_FixedValueModel():get_StringValue()
    --these are capcom's typo
    if lng=="TransitionalChinese" or lng=="SimplelifiedChinese" or lng=="Korean" or lng=="Japanese"
        --or lng=="Russian" or lng == "Ukrainian" 
        then
        font=imgui.load_font(fontname or "simhei.ttf", fontsize or 14,fontrange or CJK_GLYPH_RANGES)
        Log("Load CN font")
    else
        Log("Use Default Font")
    end
    return font
end

_XYZApi={
    DrawIt=DrawIt,
    InitFromFile=InitFromFile,
    LoadFontIfCJK=LoadFontIfCJK,
    Enum2Map=Enum2Map
}
return _XYZApi