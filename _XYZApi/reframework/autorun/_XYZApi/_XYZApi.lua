local vecNames={
    ".x",
    ".y",
    ".z",
    ".w"
}

local function DrawIt(modname,configfile,_config,config,OnChange)
    configfile=configfile or (modname..".json")
    re.on_draw_ui(function()
        local changed=false
        local _changed=false
	    if imgui.tree_node(modname) then	
		    --imgui.same_line()
		    --imgui.text("*Right click on most options to reset them")		
		    imgui.begin_rect()
		
            for idx,para in ipairs (_config) do
                local key=para.name
                local title_postfix=""
                if para.needrestart==true then
                    title_postfix=" (Need Restart To Apply)"
                end

                if para.type=="int" then
        		    changed , config[key]= imgui.drag_int(key .. title_postfix, 
                                                            config[key] or para.default or para.min or 0,
                                                            para.step or 1 , para.min or 0, para.max)
                    _changed=changed or _changed
                elseif para.type=="intN" then
                    imgui.push_item_width(215)
                    for _k,_ in pairs (config[key]) do
                        local vname=vecNames[_k] or ".".._k
            		    changed , config[key][_k] = imgui.drag_int(key..vname .. title_postfix, 
                                                             config[key][_k] or para.default or para.min or 0,
                                                             para.step or 1 , para.min or 0, para.max)
                        _changed=changed or _changed
                        imgui.same_line()
                    end
                    imgui.pop_item_width()
                    imgui.new_line()
                elseif para.type=="font" or para.type=="string" then
        		    changed , config[key]= imgui.input_text(key .. title_postfix, config[key] or para.default)
                    _changed=changed or _changed
                elseif para.type=="bool" then
                    --don't use "config[key] or default"
                    if config[key] ~=nil then
            		    changed , config[key]= imgui.checkbox(key .. title_postfix, config[key])
                    else
            		    changed , config[key]= imgui.checkbox(key .. title_postfix, para.default)
                    end
                    _changed=changed or _changed
                elseif para.type=="float" then
        		    changed , config[key]= imgui.drag_float(key .. title_postfix, 
                                                            config[key] or para.default or para.min or 0,
                                                            para.step or 0.1 , para.min or 0, para.max)
                    _changed=changed or _changed
                elseif para.type=="rgba32" then
                    local value=config[key] or para.default or para.min or 0xffffffff
                    local a=(value & 0xff000000) >>24
                    local b=(value & 0x00ff0000) >>16
                    local g=(value & 0x0000ff00) >>8
                    local r=value & 0xff
                    imgui.push_item_width(80)
                    changed , r= imgui.drag_int(key..".R" .. title_postfix, r,1 , 0, 255)
                    _changed=changed or _changed
                    imgui.same_line()
                    changed , g= imgui.drag_int(key ..".G".. title_postfix, g,1 , 0, 255)
                    _changed=changed or _changed
                    imgui.same_line()
                    changed , b= imgui.drag_int(key ..".B".. title_postfix, b,1 , 0, 255)
                    _changed=changed or _changed
                    imgui.same_line()
                    changed , a= imgui.drag_int(key ..".A".. title_postfix, a,1 , 0, 255)
                    _changed=changed or _changed
                    imgui.pop_item_width()
                    config[key]=(a<<24)|(r)|(g<<8)|(b<<16)
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
    DrawIt=DrawIt
}
return _XYZApi