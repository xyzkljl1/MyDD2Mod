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
local itemIndex2itemId={}
local itemId2itemIndex={}

--local defaultCNFont=nil

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
		end
	end
	return tbl
end

local function InitFromFile(_config,configfile,dontInitHotkey)
    --merge config file to default config
    local config = {} 
    for key,para in ipairs(_config) do
        config[para.name]=para.default
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
    local ids={}
    local im=sdk.get_managed_singleton("app.ItemManager")
    local iter=im._ItemDataDict:GetEnumerator()
    iter:MoveNext()
    while iter:get_Current():get_Value()~=nil do
        local itemCommonParam=iter:get_Current():get_Value()
        local name=itemCommonParam:get_Name()
        if name ~="Invalid" and name~=nil then
            id2Name[itemCommonParam._Id]=string.format("%5d /%s",itemCommonParam._Id,itemCommonParam:get_Name())
            table.insert(ids,itemCommonParam._Id)
        end
        iter:MoveNext()
    end
    table.sort(ids)
    for _,id in pairs(ids) do
        table.insert(itemNames,id2Name[id])
        itemIndex2itemId[#itemNames]=id
        itemId2itemIndex[id]=#itemNames
    end
end

if isDD2()==true then
    --dlc item is not in items at the first,need retry
    sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),nil,DD2_InitItemId)
    --get_Message return is decided by current language, so need to fetch item messages when option loaded
    sdk.hook(sdk.find_type_definition("app.OptionManager"):get_method("app.ISystemSaveData.loadSystemSaveData(app.SaveDataBase)"),
    nil,DD2_InitItemId)
end


--Chinese font need pass CJK_GLYPH_RANGES as [ranges] when load and the lua file need to be unicode
local function DrawIt(modname,configfile,_config,config,OnChange,dontInitHotkey,font)
    configfile=configfile or (modname..".json")

    if dontInitHotkey~=true then
        setupHotKey(_config,config)
    end

    if itemNames==nil then
        DD2_InitItemId()
    end

    re.on_draw_ui(function()
        local changed=false
        local _changed=false
        if font~=nil then
            imgui.push_font(font)
        end
        local triggeredButtons={}
	    if imgui.tree_node(modname) then
		    --imgui.same_line()
		    --imgui.text("*Right click on most options to reset them")		
		    imgui.begin_rect()
            for _,para in ipairs (_config) do
                local key = para.name
                local actionName = para.actionName or key
                local title_postfix=""
                if para.needrestart==true or para.type=="fontsize" or para.type=="font" then
                    title_postfix=" (Need Restart To Apply)"
                elseif para.needreentry==true then
                    title_postfix=" (Need Return to Title to Apply)"
                end
                local label=para.label or key

                if para.type=="int" then
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
                    local width=para.width or 215
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
                elseif para.type=="rgba32" then
                    imgui.push_item_width(imgui.calc_item_width()*0.6)
                    changed,config[key]= imgui.color_picker(label .. title_postfix, config[key])
                    _changed=changed or _changed
                    imgui.pop_item_width()
                elseif para.type=="button" then
                    clicked=imgui.button(label..title_postfix)
                    if clicked==true and para.onClick ~=nil then
                        --will only trigger once when pressed
                        triggeredButtons[key]=para.onClick
                        --should mark to true?
                        changed=true
                    end
                elseif para.type=="item" then
                    changed, tmp_idx= imgui.combo(label .. title_postfix, itemId2itemIndex[config[key]] ,itemNames)
                    config[key]=itemIndex2itemId[tmp_idx]
                    _changed=changed or _changed
                end

                if para.tip ~=nil and imgui.is_item_hovered() then
                    imgui.set_tooltip(para.tip)
                end
            end
		    imgui.tree_pop()
        end        
        if font~=nil then
            imgui.pop_font(font)
        end

        --should call before on change?
        for key,func in pairs(triggeredButtons) do 
            func()
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
    local optionItem=om._OptionItems:get_Item(sdk.find_type_definition("app.OptionID"):get_field("TextLanguage"):get_data())
    local lng=optionItem:get_FixedValueModel():get_StringValue()
    --SimplelifiedChinese is capcom's typo
    if lng=="TransitionalChinese" or lng=="SimplelifiedChinese" or lng=="Korean" or lng=="Japanese"
        --or lng=="Russian" or lng == "Ukrainian" 
        then
        font=imgui.load_font(fontname or "simhei.ttf", fontsize or 14,fontrange or CJK_GLYPH_RANGES)
        print("Load CN font")
    else
        print("Use Default Font")
    end
    return font
end


_XYZApi={
    DrawIt=DrawIt,
    InitFromFile=InitFromFile,
    LoadFontIfCJK=LoadFontIfCJK
}
return _XYZApi