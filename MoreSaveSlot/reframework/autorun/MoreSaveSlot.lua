local modName = "MoreSaveSlot"
local configFile = modName..".json"
local slotCount = 20
local customSlotBase = 100
-- Three native adventures use non-overlapping custom slots within 100-200.
local customSlotGroupStride = slotCount - 1
local nativeVisibleItemCount = 12
local saveDataManagerType = sdk.find_type_definition("app.SaveDataManager")
local savedConfig = json.load_file(configFile) or {}
-- Persist settings only. Legacy preview data is never used or written back.
local config = {
    saveSlot = savedConfig.saveSlot or 1,
    loadSlot = savedConfig.loadSlot or 1,
    nativeSlot = savedConfig.nativeSlot
}
savedConfig = nil
local lastNativeSlot = tonumber(config.nativeSlot) or 4
if lastNativeSlot < 4 or lastNativeSlot > 14 or (lastNativeSlot - 4) % 5 ~= 0 then
    lastNativeSlot = 4
end
local slotStatus = {}
local pendingSaveStatus
local nativePreviewChinese
local latestSlot
local nativeLabelsDirty = false

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
    return customSlotBase + math.floor(nativeSlot / 5) * customSlotGroupStride
        + uiSlot - 2
end

local function GetFileTimestamp(slotId)
    local manager = sdk.get_managed_singleton("app.SaveDataManager")
    if manager == nil then return nil end
    local ok, timestamp = pcall(function()
        local list = manager:call(
            "tempGetSaveFileDetailList(System.Int32, System.Int32)", slotId, 1)
        local entry = list and list:get_Item(0)
        if entry == nil or entry:call("get_IsEmptyData") then return nil end
        local detail = entry:call("get_SaveFileDetail")
        return detail and detail:call("get_LastUpdateTimeStamp") or nil
    end)
    return ok and timestamp or nil
end

local function SetNativeGroup(slotId)
    if slotId < 0 or slotId >= 15 then return end
    local nativeSlot = 4 + math.floor(slotId / 5) * 5
    if nativeSlot == lastNativeSlot and config.nativeSlot == nativeSlot then return end
    lastNativeSlot = nativeSlot
    config.nativeSlot = nativeSlot
    nativeLabelsDirty = true
    json.dump_file(configFile, config)
    Log("Selected native save group", math.floor(nativeSlot / 5) + 1)
end

local function DetectNativeGroup()
    if config.nativeSlot ~= nil then return end
    local latestTimestamp
    local latestNativeSlot
    for group = 0, 2 do
        for uiSlot = 2, slotCount do
            local storageSlot = customSlotBase + group * customSlotGroupStride + uiSlot - 2
            local timestamp = tonumber(tostring(GetFileTimestamp(storageSlot)))
            if timestamp ~= nil and (latestTimestamp == nil or timestamp > latestTimestamp) then
                latestTimestamp = timestamp
                latestNativeSlot = 4 + group * 5
            end
        end
    end
    if latestNativeSlot ~= nil then SetNativeGroup(latestNativeSlot) end
end

DetectNativeGroup()

local function QueueSaveStatus(uiSlot, storageSlot)
    pendingSaveStatus = {
        uiSlot = uiSlot,
        storageSlot = storageSlot,
        previousTimestamp = GetFileTimestamp(storageSlot)
    }
end

local function RedirectSlot(args, uiSlot, operation, trackAnyGroup)
    local nativeSlot = sdk.to_int64(args[3])
    if trackAnyGroup or IsManualSlot(nativeSlot) then SetNativeGroup(nativeSlot) end
    if not IsManualSlot(nativeSlot) then return end

    local targetSlot = GetSlotId(nativeSlot, uiSlot)
    if targetSlot ~= nativeSlot then
        args[3] = sdk.to_ptr(targetSlot)
        Log(operation, "manual slot", uiSlot, "storage slot", nativeSlot, "->", targetSlot)
    end
    return targetSlot
end

sdk.hook(saveDataManagerType:get_method("requestSave"), function(args)
    local targetSlot = RedirectSlot(args, config.saveSlot, "Save")
    if targetSlot ~= nil then QueueSaveStatus(config.saveSlot, targetSlot) end
end, nil)

sdk.hook(saveDataManagerType:get_method("requestLoad"), function(args)
    RedirectSlot(args, config.loadSlot, "Load", true)
end, nil)

local function FinalizePendingSaveStatus()
    if pendingSaveStatus == nil then return end
    local manager = sdk.get_managed_singleton("app.SaveDataManager")
    if manager == nil or manager:get_IsBusy() then return end

    local timestamp = GetFileTimestamp(pendingSaveStatus.storageSlot)
    if timestamp == nil or tostring(timestamp) == tostring(pendingSaveStatus.previousTimestamp) then return end
    slotStatus[pendingSaveStatus.uiSlot] = "Saved"
    latestSlot = pendingSaveStatus.uiSlot
    nativeLabelsDirty = true
    Log("Updated status for manual slot", pendingSaveStatus.uiSlot)
    pendingSaveStatus = nil
end

local function RefreshStatus()
    local manager = sdk.get_managed_singleton("app.SaveDataManager")
    if manager == nil or manager:get_IsBusy() then return false end
    latestSlot = nil

    local latestTimestamp
    for i = 1, slotCount do
        local storageSlot = GetSlotId(lastNativeSlot, i)
        local timestamp = tonumber(tostring(GetFileTimestamp(storageSlot)))
        slotStatus[i] = timestamp ~= nil and "Saved" or "Empty"
        if timestamp ~= nil and (latestTimestamp == nil or timestamp > latestTimestamp) then
            latestTimestamp = timestamp
            latestSlot = i
        end
    end
    return true
end

re.on_draw_ui(function()
    if not imgui.tree_node(modName) then return end

    local changed
    changed, config.saveSlot = imgui.combo("Store to", config.saveSlot, slotNames)
    if changed then json.dump_file(configFile, config) end

    changed, config.loadSlot = imgui.combo("Load from", config.loadSlot, slotNames)
    if changed then json.dump_file(configFile, config) end

    if imgui.button("Refresh slot status") then
        RefreshStatus()
        nativeLabelsDirty = true
    end
    for i = 1, slotCount do
        imgui.text(string.format("%02d  %s", i, slotStatus[i] or "Unknown"))
    end

    imgui.tree_pop()
end)

Log("Loaded. Store slot", config.saveSlot, "Load slot", config.loadSlot)
Log("Native previews use game summaries; extra-slot play time awaits a verified game API")

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
    local saved = slotStatus[slot] == "Saved"
    if IsChineseLanguage() then
        return string.format("%s %s  存档位 %02d  [%s]",
            slot == latestSlot and ">" or " ", nativeSaveCommandText,
            slot, saved and "已保存" or "空")
    end
    return string.format("%s Save and Continue  Slot %02d  [%s]",
        slot == latestSlot and ">" or " ", slot, saved and "Saved" or "Empty")
end

local function GetNativeSlotLabel()
    return latestSlot == 1 and "> "..nativeSaveCommandText or nativeSaveCommandText
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
    if root == nil then return nil end
    local child = root:call("get_Child")
    while child ~= nil do
        if tostring(child:call("get_Name")) == name then return child end
        local found = FindGuiObject(child, name)
        if found ~= nil then return found end
        child = child:call("get_Next")
    end
end

local function PreviewSlotForIndex(index)
    if index == 0 or index == 1 then return 1 end
    if index ~= nil and index >= 3 and index <= slotCount + 1 then return index - 1 end
end

local function GetCurrentListIndex(ctrl)
    local rows = ctrl and ctrl:call("get_ItemList")
    if rows ~= nil then
        for i = 0, rows:get_size() - 1 do
            local row = rows:get_element(i)
            if row:call("get_IsSelected") then
                return row:call("get_ListIndex")
            end
        end
    end
    return ctrl and ctrl:call("get_SelectedIndex")
end

local function BindNativePreview(gui)
    nativePreviewChinese = IsChineseLanguage()
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

local function RefreshNativeSaveListLabels()
    if not nativeLabelsDirty or nativeStyledCtrl == nil then return end
    local current = nativeStyledCtrl:call("get_InfoList")
    if current == nil or current:get_size() < slotCount + 2 then return end

    for i = 0, current:get_size() - 1 do
        local info = current:get_element(i)
        if i == 0 then
            SetNativeText(info, GetNativeSlotLabel())
        elseif i >= 3 and i <= slotCount + 1 then
            SetNativeText(info, GetSlotLabel(i - 1))
        end
    end

    nativeStyledCtrl:call("updateDisp()")
    nativeLabelsDirty = false
end

re.on_frame(function()
    FinalizePendingSaveStatus()
    if nativeStyledCtrl == nil then return end
    local ok, err = pcall(function()
        RefreshNativeSaveListLabels()
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
    if not ok then
        Log("Native Save menu update failed:", err)
        nativeStyledCtrl = nil
    end
end)

local function ExtendNativeSaveList(gui)
    local ctrl = gui and gui.SaveListCtrl
    local original = ctrl and ctrl:call("get_InfoList")
    if original == nil or original:get_size() < 3 then return end
    BindNativePreview(gui)
    local message = original:get_element(0):get_field("Msg")
    if message ~= nil then nativeSaveCommandText = tostring(message):gsub("^>%s*", "") end
    RefreshStatus()
    SetNativeText(original:get_element(0), GetNativeSlotLabel())

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
    nativeStyledCtrl = ctrl
    nativeLabelsDirty = false
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
local currentPreviewSlot
local previewTitleStrings = {}

local function StartPreviewUpdate(args)
    local gui = sdk.to_managed_object(args[2])
    nativePreviewChinese = IsChineseLanguage()
    currentPreviewSlot = gui and PreviewSlotForIndex(GetCurrentListIndex(gui.SaveListCtrl))
end

local function EndPreviewUpdate(retval)
    return retval
end

local function GetPreviewString(text)
    local value = previewTitleStrings[text]
    if value == nil then
        value = Retain(sdk.create_managed_string(text))
        previewTitleStrings[text] = value
    end
    return value
end

local function GetPreviewData(storageSlot)
    local manager = sdk.get_managed_singleton("app.SaveDataManager")
    local ok, data = pcall(function()
        local list = manager and manager:call(
            "tempGetSaveFileDetailList(System.Int32, System.Int32)", storageSlot, 1)
        local entry = list and list:get_Item(0)
        if entry == nil or entry:call("get_IsEmptyData") then return {empty = true} end

        local detail = entry:call("get_SaveFileDetail")
        local timestamp = tostring(detail:call("get_LastUpdateTimeStamp"))
        return {
            empty = false,
            timestamp = tonumber(timestamp)
        }
    end)
    if not ok then
        Log("Failed to read preview for storage slot", storageSlot, data)
        data = {empty = GetFileTimestamp(storageSlot) == nil}
    end
    return data
end

local function PadLike(value, sample)
    return string.format("%0"..#sample.."d", value)
end

local function FormatSaveTime(ticks, nativeValue)
    if ticks == nil then return "" end
    local time = os.date("!*t", math.floor(ticks / 10000000 - 62135596800))
    if time == nil then return "" end

    -- Reuse the native preview's numeric layout, separators and zero padding.
    local a, s1, b, s2, c, gap, h, s3, m, s4, sec =
        tostring(nativeValue or ""):match(
            "^(%d+)(%D)(%d+)(%D)(%d+)(%s+)(%d+)(%D)(%d+)(%D)(%d+)$")
    if a ~= nil then
        local first, second, third
        if tonumber(a) > 31 then
            first, second, third = time.year, time.month, time.day
        elseif tonumber(c) > 31 then
            first, second, third = time.month, time.day, time.year
        end
        if first ~= nil then
            return PadLike(first, a)..s1..PadLike(second, b)..s2..PadLike(third, c)
                ..gap..PadLike(time.hour, h)..s3..PadLike(time.min, m)
                ..s4..PadLike(time.sec, sec)
        end
    end
    return string.format("%d/%d/%d %d:%02d:%02d",
        time.year, time.month, time.day, time.hour, time.min, time.sec)
end

local function GetPreviewTitle(originalName, slot, storageSlot, empty)
    local fileName = string.format("data%03dSlot.bin", storageSlot)
    local name = nativePreviewChinese and "中途存档" or tostring(originalName or "Interim Save")
    name = name:gsub("%s+%([Ss]lot%d+ data%d+Slot%.bin%)%s*%[[^%]]+%]$", "")
        :gsub("%s+%([Ss]lot%d+ data%d+Slot%.bin%)$", "")
    return GetPreviewString(string.format("%s (Slot%d %s)%s", name, slot, fileName,
        empty and (nativePreviewChinese and " [空]" or " [Empty]") or ""))
end

for _, methodName in ipairs({"updateSaveDataInfo", "createSaveDataList"}) do
    sdk.hook(ui060804Type:get_method(methodName), StartPreviewUpdate, EndPreviewUpdate)
end

-- Change only the data consumed by the native renderer; do not call UI methods here.
local saveDataListItemType = sdk.find_type_definition("app.ui060804.SaveDataListItem")
local previewInfoStack = {}
sdk.hook(saveDataListItemType:get_method(
    "updateDisp(app.ui060804.SaveDataListInfo)"), function(args)
    local restore = {}
    previewInfoStack[#previewInfoStack + 1] = restore
    if currentPreviewSlot == nil then return end
    local info = sdk.to_managed_object(args[3])
    if info == nil or not info:get_field("IsChangeTarget") then return end

    restore.info = info
    restore.Name = info:get_field("Name")
    restore.SaveSlotIndex = info:get_field("SaveSlotIndex")
    restore.SaveTime = info:get_field("SaveTime")
    restore.PlayTime = info:get_field("PlayTime")
    restore.PlaceName = info:get_field("PlaceName")
    restore.IsEmpty = info:get_field("IsEmpty")

    if currentPreviewSlot == 1 then
        local storageSlot = tonumber(tostring(restore.SaveSlotIndex)) or lastNativeSlot
        if not IsManualSlot(storageSlot) then storageSlot = lastNativeSlot end
        -- Preserve the native PlayTime and PlaceName supplied by the game's summary.
        info:set_field("Name", GetPreviewTitle(
            restore.Name, currentPreviewSlot, storageSlot, restore.IsEmpty))
        return
    end

    local storageSlot = GetSlotId(lastNativeSlot, currentPreviewSlot)
    local data = GetPreviewData(storageSlot)
    -- No verified game-only reader exists for extra-slot time or location yet.
    info:set_field("PlayTime", GetPreviewString("--:--:--"))
    info:set_field("PlaceName", GetPreviewString(nativePreviewChinese and "未知" or "Unknown"))
    info:set_field("Name", GetPreviewTitle(
        info:get_field("Name"), currentPreviewSlot, storageSlot, data.empty))
    info:set_field("SaveSlotIndex", storageSlot)
    info:set_field("IsEmpty", data.empty)
    if not data.empty then
        info:set_field("SaveTime", GetPreviewString(
            FormatSaveTime(data.timestamp, restore.SaveTime)))
    end
end, function(retval)
    local restore = table.remove(previewInfoStack)
    if restore ~= nil and restore.info ~= nil then
        restore.info:set_field("Name", restore.Name)
        if restore.SaveSlotIndex ~= nil then
            restore.info:set_field("SaveSlotIndex", restore.SaveSlotIndex)
            restore.info:set_field("SaveTime", restore.SaveTime)
            restore.info:set_field("PlayTime", restore.PlayTime)
            restore.info:set_field("PlaceName", restore.PlaceName)
            restore.info:set_field("IsEmpty", restore.IsEmpty)
        end
    end
    return retval
end)

sdk.hook(ui060804Type:get_method("executeCommand"), function(args)
    local command = sdk.to_int64(args[3])
    local gui = sdk.to_managed_object(args[2])
    local ctrl = gui and gui.SaveListCtrl
    local index = GetCurrentListIndex(ctrl)

    if command ~= 1 then
        -- The menu is about to close; do not touch its controls during scene teardown.
        nativeStyledCtrl = nil
        currentPreviewSlot = nil
        nativeListLayouts = {}
    end

    if command ~= 1 and command ~= 2 then return end
    local slot = command == 1 and PreviewSlotForIndex(index) or 1
    if slot == nil then return end

    config.saveSlot = slot
    json.dump_file(configFile, config)
    Log("Selected native manual slot", slot)
end, nil)

sdk.hook(ui060804Type:get_method("onDestroy"), function()
    nativeStyledCtrl = nil
    currentPreviewSlot = nil
    nativeListLayouts = {}
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
