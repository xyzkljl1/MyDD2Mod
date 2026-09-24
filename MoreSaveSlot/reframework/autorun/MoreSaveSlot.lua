local modName = "MoreSaveSlot"
local configFile = modName..".json"
local slotCount = 20
local customSlotBase = 100
-- Keep the existing 1-9 slot file IDs stable when adding more UI slots.
local customSlotStride = 9
local nativeVisibleItemCount = 12
local saveDataManagerType = sdk.find_type_definition("app.SaveDataManager")
local config = json.load_file(configFile) or {saveSlot = 1, loadSlot = 1}
local lastNativeSlot = 4
local slotStatus = {}

config.saveSlot = math.max(1, math.min(slotCount, config.saveSlot or 1))
config.loadSlot = math.max(1, math.min(slotCount, config.loadSlot or 1))

local slotNames = {}
for i = 1, slotCount do slotNames[i] = "Manual Save "..i end

local function Log(...)
    local values = {...}
    for i = 1, #values do values[i] = tostring(values[i]) end
    log.info("[MoreSaveSlot] "..table.concat(values, " "))
end

-- SaveSlotType contains five entries per adventure: Auto, Manual, Back, Clear and AddAuto.
-- The current manual "Save and Continue" operation uses AddAuto (4, 9, 14...).
local function IsManualSlot(slotId)
    return slotId >= 4 and (slotId - 4) % 5 == 0
end

local function GetSlotId(nativeSlot, uiSlot)
    if uiSlot == 1 then return nativeSlot end
    return customSlotBase + nativeSlot * customSlotStride + uiSlot - 2
end

local function RedirectSlot(args, uiSlot, operation)
    local nativeSlot = sdk.to_int64(args[3])
    if not IsManualSlot(nativeSlot) then return end

    lastNativeSlot = nativeSlot
    local targetSlot = GetSlotId(nativeSlot, uiSlot)
    if targetSlot ~= nativeSlot then
        args[3] = sdk.to_ptr(targetSlot)
        Log(operation, "manual slot", uiSlot, "storage slot", nativeSlot, "->", targetSlot)
    end
end

sdk.hook(saveDataManagerType:get_method("requestSave"), function(args)
    RedirectSlot(args, config.saveSlot, "Save")
end, nil)

sdk.hook(saveDataManagerType:get_method("requestLoad"), function(args)
    RedirectSlot(args, config.loadSlot, "Load")
end, nil)

local function RefreshStatus()
    local manager = sdk.get_managed_singleton("app.SaveDataManager")
    if manager == nil or manager:get_IsBusy() then return end

    for i = 1, slotCount do
        local storageSlot = GetSlotId(lastNativeSlot, i)
        slotStatus[i] = manager:isExistSaveData(storageSlot) and "Saved" or "Empty"
    end
end

re.on_draw_ui(function()
    if not imgui.tree_node(modName) then return end

    local changed
    changed, config.saveSlot = imgui.combo("Store to", config.saveSlot, slotNames)
    if changed then json.dump_file(configFile, config) end

    changed, config.loadSlot = imgui.combo("Load from", config.loadSlot, slotNames)
    if changed then json.dump_file(configFile, config) end

    if imgui.button("Refresh slot status") then RefreshStatus() end
    for i = 1, slotCount do
        imgui.text(string.format("%02d  %s", i, slotStatus[i] or "Unknown"))
    end

    imgui.tree_pop()
end)

Log("Loaded. Store slot", config.saveSlot, "Load slot", config.loadSlot)

-- Add native slot selectors to the game's Save menu without replacing its commands.
local nativeRefs = {}
local nativeListLayouts = {}
local nativeStyledCtrl
local nativeSaveCommandText = "Save and Continue"
local nativeListScale = 1.0
local nativeFontScale = 1.0

local function Retain(object)
    object:add_ref()
    nativeRefs[#nativeRefs + 1] = object
    return object
end

local function SetNativeText(info, text)
    info:set_field("Msg", Retain(sdk.create_managed_string(text)))
end

local function IsChineseLanguage()
    local ok, language = pcall(function()
        local manager = sdk.get_managed_singleton("app.OptionManager")
        local optionId = sdk.find_type_definition("app.OptionID")
            :get_field("TextLanguage"):get_data()
        if manager == nil or manager._OptionItems == nil
                or not manager._OptionItems:ContainsKey(optionId) then return nil end
        return manager._OptionItems:get_Item(optionId)
            :get_FixedValueModel():get_StringValue()
    end)
    return ok and (language == "SimplelifiedChinese"
        or language == "TransitionalChinese")
end

local function GetSlotLabel(slot)
    local manager = sdk.get_managed_singleton("app.SaveDataManager")
    local saved = false
    if manager ~= nil then
        local ok, exists = pcall(function() return manager:isExistSaveData(GetSlotId(lastNativeSlot, slot)) end)
        saved = ok and exists
    end
    if IsChineseLanguage() then
        return string.format("%s %s  存档位 %02d  [%s]",
            slot == config.saveSlot and ">" or " ", nativeSaveCommandText,
            slot, saved and "已保存" or "空")
    end
    return string.format("%s Save and Continue  Slot %02d  [%s]",
        slot == config.saveSlot and ">" or " ", slot, saved and "Saved" or "Empty")
end

local function NewValue(typeName, fields)
    local value = ValueType.new(sdk.find_type_definition(typeName))
    for name, data in pairs(fields) do value:set_field(name, data) end
    return value
end

local function ExpandNativeSaveList(ctrl, count)
    local fsl = ctrl:call("get_FSL")
    local instances = fsl and fsl:call("get_ItemInstTbl")
    local visibleCount = instances and instances:get_size() or 0
    if visibleCount == 0 or visibleCount >= count then return false end

    local key = tostring(ctrl:get_address())
    local layout = nativeListLayouts[key]
    if layout == nil then
        local area = ctrl:call("get_ScrollAreaSize")
        local cursor = ctrl:call("get_FixedCursorOffset")
        local itemSize = fsl:call("get_ItemSize")
        local itemOffset = fsl:call("get_ItemOffset")
        layout = {
            areaW = area:get_field("w"), areaH = area:get_field("h"),
            cursorX = cursor:get_field("x"), cursorY = cursor:get_field("y"),
            itemW = itemSize:get_field("w"), itemH = itemSize:get_field("h"),
            offsetX = itemOffset.x, offsetY = itemOffset.y, offsetZ = itemOffset.z
        }
        nativeListLayouts[key] = layout
    end
    local newArea = NewValue("via.Size", {
        w = layout.areaW,
        h = layout.areaH * count / visibleCount * nativeListScale
    })
    fsl:call("set_ItemSize(via.Size)", NewValue("via.Size", {
        w = layout.itemW,
        h = layout.itemH * nativeListScale
    }))
    fsl:call("set_ItemOffset(via.vec3)", Vector3f.new(
        layout.offsetX, layout.offsetY * nativeListScale, layout.offsetZ))
    local desc = Retain(sdk.create_instance("via.gui.FSLInitializerDesc", true))
    desc:call("set_ScrollAreaSize(via.Size)", newArea)
    desc:call("set_FixedCursorOffset(via.Point)", NewValue("via.Point", {
        x = layout.cursorX, y = layout.cursorY
    }))
    fsl:call("init(via.gui.FSLInitializerDesc)", desc)
    ctrl:call("set_ScrollAreaSize(via.Size)", newArea)
    return true
end

local function StyleNativeSaveItems(ctrl, compact)
    local instances = ctrl:call("get_FSL"):call("get_ItemInstTbl")
    local rows = ctrl:call("get_ItemList")
    local firstScale = instances:get_element(0):call("get_Scale")
    local fontSize
    if compact or firstScale.x < 0.99 then
        local baseFontSize = rows:get_element(0):get_field("TxtLabel"):call("get_FontSize")
        fontSize = NewValue("via.Size", {
            w = baseFontSize:get_field("w") * nativeFontScale,
            h = baseFontSize:get_field("h") * nativeFontScale
        })
    end
    for i = 0, instances:get_size() - 1 do
        local item = instances:get_element(i)
        local scale = item:call("get_Scale")
        item:call("set_Scale(via.vec3)", Vector3f.new(
            1, 1, scale.z))
        if fontSize ~= nil then
            local text = rows:get_element(i):get_field("TxtLabel")
            text:call("set_FontSize(via.Size)", fontSize)
        end
    end
end

local function FindGuiObject(root, name)
    local child = root:call("get_Child")
    while child ~= nil do
        if tostring(child:call("get_Name")) == name then return child end
        local found = FindGuiObject(child, name)
        if found ~= nil then return found end
        child = child:call("get_Next")
    end
end

local function SetGuiObjectsVisible(root, names, visible)
    local child = root:call("get_Child")
    while child ~= nil do
        if names[tostring(child:call("get_Name"))] then
            child:call("set_Visible", visible)
        end
        SetGuiObjectsVisible(child, names, visible)
        child = child:call("get_Next")
    end
end

local function ResizeNativeSaveGrid(gui, ctrl)
    local savePanel = FindGuiObject(gui.PnlMode, "PNL_SaveLoad")
    if savePanel == nil then error("PNL_SaveLoad not found") end
    local template = FindGuiObject(savePanel, "mat_Line01")
    if template == nil then error("mat_Line01 not found") end
    local lineNames = {}
    for _, name in ipairs({"mat_Line00_v", "mat_Line00_v1", "mat_Line00",
            "mat_Line01", "mat_Line02", "mat_Line03"}) do
        lineNames[name] = true
    end
    SetGuiObjectsVisible(savePanel, lineNames, false)

    local rows = ctrl:call("get_ItemList")
    local rowOffset = ctrl:call("get_FSL"):call("get_ItemOffset").y
    for i = 0, rows:get_size() - 1 do
        local row = rows:get_element(i)
        local line = row:get_field("MatBorderUnderLine")
        local linePosition = line:call("get_Position")
        line:call("copyProperties(via.gui.PlayObject)", template)
        line:call("set_Position(via.vec3)", linePosition)
        line:call("set_Visible", true)

        local border = row:get_field("PnlBorderLineCtrl")
        local borderPosition = border:call("get_Position")
        border:call("set_Position(via.vec3)", Vector3f.new(
            borderPosition.x, rowOffset, borderPosition.z))
    end
    nativeStyledCtrl = ctrl
end

re.on_frame(function()
    if nativeStyledCtrl == nil then return end
    local ok = pcall(function()
        local rows = nativeStyledCtrl:call("get_ItemList")
        local rowOffset = nativeStyledCtrl:call("get_FSL"):call("get_ItemOffset").y
        for i = 0, rows:get_size() - 1 do
            local row = rows:get_element(i)
            local border = row:get_field("PnlBorderLineCtrl")
            local position = border:call("get_Position")
            border:call("set_Position(via.vec3)", Vector3f.new(
                position.x, rowOffset, position.z))
            row:get_field("MatBorderUnderLine"):call("set_Visible", true)
        end
    end)
    if not ok then nativeStyledCtrl = nil end
end)

local function ExtendNativeSaveList(gui)
    local ctrl = gui and gui.SaveListCtrl
    local original = ctrl and ctrl:call("get_InfoList")
    if original == nil or original:get_size() < 3 then return end
    if IsChineseLanguage() then
        local message = original:get_element(0):get_field("Msg")
        if message ~= nil then nativeSaveCommandText = tostring(message) end
    end

    local compact = false
    local ok, result = pcall(ExpandNativeSaveList, ctrl, nativeVisibleItemCount)
    if ok then compact = result else Log("Failed to expand native Save menu:", result) end

    local list = Retain(ctrl:call("newInfoList"))
    for i = 0, 2 do list:call("Add", original:get_element(i)) end

    for slot = 2, slotCount do
        local info = Retain(sdk.create_instance("app.ui060804.SaveListInfo", true))
        info:call(".ctor()")
        info:set_field("IsEnable", true)
        info:set_field("IsCanSelect", true)
        info:set_field("IsVisibleBorder", true)
        info:set_field("Command", 1)
        SetNativeText(info, GetSlotLabel(slot))
        list:call("Add", info)
    end

    ctrl:call("makeList", list, 0)
    local scaleOk, scaleError = pcall(StyleNativeSaveItems, ctrl, compact)
    if not scaleOk then Log("Failed to style native Save menu:", scaleError) end
    if compact then
        local gridOk, gridError = pcall(ResizeNativeSaveGrid, gui, ctrl)
        if not gridOk then Log("Failed to resize native Save menu grid:", gridError) end
        Log("Native Save menu instances", ctrl:call("get_ItemList"):get_size(),
            ctrl:call("get_FSL"):call("get_ItemInstTbl"):get_size())
    end
end

local ui060804Type = sdk.find_type_definition("app.ui060804")
local creatingSaveMenu
sdk.hook(ui060804Type:get_method("executeCommand"), function(args)
    if sdk.to_int64(args[3]) ~= 1 then return end

    local gui = sdk.to_managed_object(args[2])
    local ctrl = gui and gui.SaveListCtrl
    local index = ctrl and ctrl:call("get_SelectedIndex")
    local slot = index and index >= 3 and index <= slotCount + 1
        and index - 1 or nil
    if slot == nil then return end

    config.saveSlot = slot
    json.dump_file(configFile, config)
    Log("Selected native manual slot", slot)
end, nil)

sdk.hook(ui060804Type:get_method("createSaveList"), function(args)
    creatingSaveMenu = sdk.to_managed_object(args[2])
end, function(retval)
    local gui = creatingSaveMenu
    creatingSaveMenu = nil
    local ok, err = pcall(ExtendNativeSaveList, gui)
    if not ok then Log("Failed to extend native Save menu:", err) end
    return retval
end)
