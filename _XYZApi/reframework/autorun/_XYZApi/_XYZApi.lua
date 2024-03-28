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

local function InitFromFile(_config,configfilename,dontInitHotkey)
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

local function DrawIt(modname,configfile,_config,config,OnChange,dontInitHotkey)
    configfile=configfile or (modname..".json")

    if dontInitHotkey~=true then
        setupHotKey(_config,config)
    end

    re.on_draw_ui(function()
        local changed=false
        local _changed=false
	    if imgui.tree_node(modname) then	
		    --imgui.same_line()
		    --imgui.text("*Right click on most options to reset them")		
		    imgui.begin_rect()
		
            for idx,para in ipairs (_config) do
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
                    local value=config[key] or para.default or para.min or 0xffffffff
                    local a=(value & 0xff000000) >>24
                    local b=(value & 0x00ff0000) >>16
                    local g=(value & 0x0000ff00) >>8
                    local r=value & 0xff
                    local width=para.width or 80
                    imgui.push_item_width(width)
                    changed , r= imgui.drag_int(label..".R" .. title_postfix, r,1 , 0, 255)
                    _changed=changed or _changed
                    imgui.same_line()
                    changed , g= imgui.drag_int(label ..".G".. title_postfix, g,1 , 0, 255)
                    _changed=changed or _changed
                    imgui.same_line()
                    changed , b= imgui.drag_int(label ..".B".. title_postfix, b,1 , 0, 255)
                    _changed=changed or _changed
                    imgui.same_line()
                    changed , a= imgui.drag_int(label ..".A".. title_postfix, a,1 , 0, 255)
                    _changed=changed or _changed
                    imgui.pop_item_width()
                    config[key]=(a<<24)|(r)|(g<<8)|(b<<16)
                end

                if para.tip ~=nil and imgui.is_item_hovered() then
                    imgui.set_tooltip(para.tip)
                end
            end
		    imgui.tree_pop()
        end
        if _changed==true then
            json.dump_file(configfile, config)
            if OnChange~=nil then
                OnChange()
            end
        end
    end)
end


_XYZApi={
    DrawIt=DrawIt,
    InitFromFile=InitFromFile
}
return _XYZApi