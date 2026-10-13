local hasApi, myapi = pcall(require, "_XYZApi/_XYZApi")
local config = {enabled=true}
local TAG = "[AutoAppraise] "
local ready, processing, failed = false, false, false
local api = {}
local needsAppraisal = false

local function stop(err)
    failed, config.enabled = true, false
    log.error(TAG .. "Stopped: " .. tostring(err))
    error(TAG .. "Stopped: " .. tostring(err), 0)
end
local function count(list) return list and list:call("get_Count()") or 0 end
local function get(dict, key)
    if dict and dict:call("ContainsKey", key) then return dict:call("get_Item", key) end
end
local function intBox()
    local box = ValueType.new(api.intType)
    box:set_field("m_value", 0)
    return box
end
local function withResults(am, action)
    local mutex = assert(am:get_field("LockResultDatasObject"), "Missing result lock")
    local taken = ValueType.new(api.boolType)
    taken:set_field("m_value", false)
    local ok, result = pcall(function()
        api.enter:call(nil, mutex, taken)
        assert(taken:get_field("m_value"), "Result lock was not acquired")
        return action(assert(am:get_field("ResultDatas"), "Missing result list"))
    end)
    -- Release on the same thread, including when the protected action throws.
    if taken:get_field("m_value") then api.exit:call(nil, mutex) end
    if not ok then error(result) end
    return result
end
local function readRelic(im, owner, id)
    local n = api.have:call(im, id, owner)
    if n <= 0 then return end
    local relic = {owner=owner, id=id, amount=n, source=id, job=0}
    if api.isFake:call(nil, id) then
        local info = im:get_field("AppraisalItemInfo")
        local perOwner = info and get(info:get_field("InfoDict"), owner)
        local queue = perOwner and get(perOwner, id)
        assert(queue and count(queue) == n, "Missing or incomplete relic metadata")
        -- Read only the head we will consume; no Lua snapshot or queue rotation.
        local packed = api.arrayItem:call(queue:call("ToArray()"), 0)
        if type(packed) ~= "number" then packed = packed:get_field("m_value") end
        assert(type(packed) == "number", "Invalid relic metadata")
        local source, job = intBox(), intBox()
        api.decode:call(nil, packed, source, job)
        relic.source, relic.job = source:get_field("m_value"), job:get_field("m_value")
        assert(relic.source > 0 and relic.job >= 0 and relic.job <= 10, "Invalid relic metadata")
        assert(api.fakeId:call(nil, relic.source) == id, "Relic metadata/display ID mismatch")
        relic.queue = queue
    end
    return relic
end
local function findRelic(im, owner)
    local storage = api.storageList:call(im, owner)
    for i = 0, count(storage) - 1 do
        local master = storage:call("get_Item", i)
        local param = master and master:get_field("_Param")
        local id = param and param:get_field("_ItemId")
        if id and (api.isFake:call(nil, id) or api.isAppraisal:call(nil, id)) then
            local ok, relic = pcall(readRelic, im, owner, id)
            if ok and relic then return relic end
            if not ok then log.error(TAG .. "Invalid relic item="..id..": "..tostring(relic)) end
        end
    end
end
local function idle(am)
    return not am:call("get_IsExecute()")
        and count(am:get_field("TempStorageDatas")) == 0
        and am:get_field("ComplatedHandler") == nil
end
local function prepareGrants(im, am, firstResult, owner, extension)
    local grants = withResults(am, function(results)
        assert(count(results) > firstResult, "Native appraisal returned no new items")
        local copied = {}
        for i = firstResult, count(results) - 1 do
            local result = results:call("get_Item", i)
            local id, amount = result:get_field("ItemId"), result:get_field("ItemCount")
            assert(id > 0 and amount > 0, "Invalid native appraisal result")
            local option = api.defaultOption:get_data()
            option.AbilityInternal = result:get_field("Ability")
            option.ExtensionValue = extension
            option.IsAddExtensionData = true
            option.IsHistory = true
            option.IsNotice = true
            copied[#copied + 1] = {id=id, amount=amount, owner=owner, option=option}
        end
        return copied
    end)
    -- Do not call ItemManager while holding the appraisal result lock.
    local reserved = {}
    for _, grant in ipairs(grants) do
        local param = assert(api.itemData:call(im, grant.id), "Missing result item data: " .. grant.id)
        -- Native applyItemImmediately converts Cash (64) and Rim (256) into
        -- currency. These results never increase their inventory item count.
        grant.currency = (api.attribute:call(param) & 0x140) ~= 0
        local space = api.capacity:call(im, grant.id, owner) - (reserved[grant.id] or 0)
        if space < grant.amount then return end
        reserved[grant.id] = (reserved[grant.id] or 0) + grant.amount
    end
    return grants
end

local function consumeRelic(im, relic)
    api.delete:call(im, relic.id, 1, relic.owner)
    assert(api.have:call(im, relic.id, relic.owner) == relic.amount - 1, "Relic consumption failed")
    if relic.queue then
        assert(count(relic.queue) == relic.amount - 1, "Native deletion did not consume exactly one metadata record")
    end
end

local function deliverGrants(im, grants)
    for _, grant in ipairs(grants) do
        api.acquire:call(im, grant.option.AbilityInternal)
        -- Wakestone shards can be consumed immediately by native auto-combination.
        local checkCount = not grant.currency and grant.id ~= 78
        local before = checkCount and api.have:call(im, grant.id, grant.owner)
        api.grant:call(im, grant.id, grant.amount, grant.owner, grant.option)
        if checkCount then
            local after = api.have:call(im, grant.id, grant.owner)
            assert(after == before + grant.amount, string.format(
                "Native result delivery mismatch item=%d amount=%d owner=%s before=%d after=%d",
                grant.id, grant.amount, tostring(grant.owner), before, after))
        end
    end
end

local function appraise(im, am, relic)
    local source, job = relic.source, relic.job
    if am:get_field("RandomUint") == 0 then return end
    local settings = am:get_field("ItemSettingDict")
    local fixed = am:get_field("FixedItemSettingDict")
    if not get(settings, source) and not get(fixed, source) then return end

    -- Prepare all by-reference arguments before any inventory mutation.
    local extension = intBox()
    api.setSource:call(nil, extension, source)
    extension = extension:get_field("m_value")
    local counterKey = source * 100 + job
    local counters = am:get_field("ExecuteIndexDict")
    local oldCounter = get(counters, counterKey)
    local random = assert(am:get_field("_Random"), "Missing appraisal RNG")
    local oldRandomState = random:call("get_StateID()")
    -- Native onUpdate appends results. Older entries must never be granted again.
    local resultBaseCount = withResults(am, count)
    local function removeOwnResults()
        withResults(am, function(results)
            assert(count(results) >= resultBaseCount, "Native result prefix changed")
            for i = count(results) - 1, resultBaseCount, -1 do
                results:call("RemoveAt(System.Int32)", i)
            end
        end)
    end
    local transaction = {committed=false, ownsManager=false}
    local function rollbackCalculation()
        if not transaction.ownsManager then return end
        am:call("cancelAppraisal()")
        removeOwnResults()
        if oldCounter == nil then counters:call("Remove", counterKey)
        else counters:call("set_Item", counterKey, oldCounter) end
        random:call("init(System.Guid)", oldRandomState)
        transaction.ownsManager = false
    end

    local ok, result = pcall(function()
        transaction.ownsManager = true
        api.add:call(am, source, job, relic.owner)
        assert(count(am:get_field("TempStorageDatas")) == 1, "Native order was not accepted")
        api.execute:call(am)
        -- One order, on the game update thread. The native update performs the
        -- actual RNG, first-appraisal guarantees, counter increment and cleanup.
        api.update:call(am)
        assert(not am:call("get_IsExecute()") and count(am:get_field("TempStorageDatas")) == 0,
            "Native single-item order did not finish in one update")
        local grants = prepareGrants(im, am, resultBaseCount, relic.owner, extension)
        if not grants then
            rollbackCalculation()
            return
        end

        transaction.committed = true
        consumeRelic(im, relic)
        deliverGrants(im, grants)
        removeOwnResults()
        transaction.ownsManager = false
        return true
    end)
    if not ok then
        local err = result
        if not transaction.committed then
            local restored, why = pcall(rollbackCalculation)
            if not restored then err=tostring(err).."; rollback failed: "..tostring(why) end
        else
            -- Never retry a partly committed order or clear unclaimed results.
            log.error(TAG .. "COMMIT INTERRUPTED source="..source.." owner="..relic.owner.."; native ResultDatas retained")
        end
        error(err)
    end
    return result
end

local function initialize()
    local bindings = {
        ["app.ItemManager"] = {
            have = "getHaveNum(System.Int32, app.CharacterID)",
            grant = "getItem(System.Int32, System.Int32, app.CharacterID, app.ItemDefine.GetItemOption)",
            delete = "deleteItem(System.Int32, System.Int32, app.CharacterID)",
            capacity = "getGetEnableNum(System.Int32, app.CharacterID)",
            acquire = "acquireEquipmentAbility(app.ItemDefine.EquipmentAbilityParam)",
            storageList = "getStorageMasterList(app.CharacterID)",
            itemData = "getItemData(System.Int32)",
        },
        ["app.ItemCommonParam"] = {
            attribute = "get_Attribute()",
        },
        ["System.Array"] = {
            arrayItem = "GetValue(System.Int32)",
        },
        ["app.ItemDefine"] = {
            fakeId = "getFakeItemId(System.Int32)",
            isFake = "isFakeAppraisalItemId(System.Int32)",
            setSource = "setSourceAppraisalItemIdToExtensionValue",
        },
        ["app.GUIAppraisalDefine"] = {
            isAppraisal = "isAppraisalItem(System.Int32)",
        },
        ["app.AppraisalItemInfoManager"] = {
            decode = "decode",
        },
        ["app.ItemAppraisalManager"] = {
            add = "addAppraisalItem(app.ItemIDEnum, app.Character.JobEnum, app.CharacterID)",
            execute = "executeAppraisal()",
            update = "onUpdate()",
        },
        ["System.Threading.Monitor"] = {
            enter = "Enter",
            exit = "Exit(System.Object)",
        },
    }
    for owner, signatures in pairs(bindings) do
        local td = assert(sdk.find_type_definition(owner), "Missing type: " .. owner)
        for key, signature in pairs(signatures) do
            api[key] = assert(td:get_method(signature), "Missing method: " .. owner .. "." .. signature)
        end
    end
    api.intType = sdk.find_type_definition("System.Int32")
    api.boolType = sdk.find_type_definition("System.Boolean")
    api.defaultOption = sdk.find_type_definition("app.ItemDefine.GetItemOption"):get_field("Default")
    assert(api.defaultOption and api.intType and api.boolType, "Missing value types")
    -- Only flag acquisition here; ground pickup writes its metadata later.
    local fn = sdk.find_type_definition("app.ItemManager"):get_method(
        "getItemNoLock(System.Int32, System.Int32, app.CharacterID, app.ItemDefine.GetItemOption, System.Int32, System.Int32)")
    sdk.hook(fn, function(args)
        if failed or not ready or not config.enabled or processing then return end
        local ok, err = pcall(function()
            local cm = sdk.get_managed_singleton("app.CharacterManager")
            local player = cm and cm:call("get_ManualPlayer()")
            if not player or (sdk.to_int64(args[5]) & 0xffffffff) ~= (player:call("get_CharaID()") & 0xffffffff) then return end
            local id = sdk.to_int64(args[3]) & 0xffffffff
            if sdk.to_int64(args[4]) > 0 and (api.isFake:call(nil, id) or api.isAppraisal:call(nil, id)) then
                needsAppraisal = true
            end
        end)
        if not ok then stop(err) end
    end, function(retval) return retval end)
    sdk.hook(sdk.find_type_definition("app.ItemAppraisalManager"):get_method("loadGameSaveData(app.SaveDataBase)"),
        function()
            needsAppraisal=false
        end, function(retval) return retval end)
    ready = true
end

local function updateAppraisal()
    if failed or processing then return end
    if ready and not needsAppraisal then return end
    if not ready and not config.enabled and not needsAppraisal then return end
    local ok, err = pcall(function()
        local im = sdk.get_managed_singleton("app.ItemManager")
        local am = sdk.get_managed_singleton("app.ItemAppraisalManager")
        local gm = sdk.get_managed_singleton("app.GuiManager")
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        local player = cm and cm:call("get_ManualPlayer()")
        if not im or not am or not gm or not player then return end
        if not ready then initialize() end
        if not needsAppraisal then return end
        local menu = gm:get_field("AppraisalMenu")
        if menu and not menu:call("get_IsEndGUI()") then return end
        if not idle(am) then return end
        local relic = findRelic(im, player:call("get_CharaID()") & 0xffffffff)
        needsAppraisal = false
        if not relic then return end
        processing = true
        needsAppraisal = appraise(im, am, relic) == true
    end)
    processing = false
    if not ok then stop(err) end
end

sdk.hook(
    sdk.find_type_definition("app.ItemManager"):get_method("onUpdate()"),
    nil,
    function(retval)
        updateAppraisal()
        return retval
    end
)

if not hasApi then return end

local controls = {
    {name="enabled", type="bool", label="Automatic appraisal", default=true},
    {name="appraiseAll", type="button", label="Appraise all relics now", onClick=function()
        if failed then return end
        needsAppraisal = true
    end},
    {type="author", version="1.2.1"},
}
local configfile = "AutoAppraise.json"
config = myapi.InitFromFile(controls, configfile, true)
myapi.DrawIt("AutoAppraise", configfile, controls, config, function()
    if failed then config.enabled = false end
end, true)
