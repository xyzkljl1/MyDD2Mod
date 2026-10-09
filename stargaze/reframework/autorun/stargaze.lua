local myapi = require("_XYZApi/_XYZApi")
local TAG, OUTPUT = "[stargaze] ", "stargaze_predictions.txt"
local api, config, controls = {}, {}, {}
local ready, failed, requested = false, false, false
local overrideSeed

local function count(list) return list and list:call("get_Count()") or 0 end
local function signed(seed) return seed >= 2147483648 and seed - 4294967296 or seed end
-- Copy actual dictionary values, ignoring unused / removed entry slots.
local function dictionary(dict)
    assert(dict, "Missing dictionary")
    local values, seen = {}, 0
    local expected = count(dict)
    if expected == 0 then return values end
    local entries = assert(dict:get_field("_entries"), "Missing dictionary entries")
    assert(entries:get_size() <= 100000, "Unexpected dictionary size")
    for i = 0, entries:get_size() - 1 do
        local key = entries:get_element(i):get_field("key")
        if values[key] == nil and dict:call("ContainsKey", key) then
            values[key] = assert(dict:call("get_Item", key), "Missing dictionary value")
            seen = seen + 1
        end
    end
    assert(seen == expected, "Dictionary changed while copying")
    return values
end
local function fill(dict, values)
    dict:call("Clear()")
    for key, value in pairs(values) do dict:call("set_Item", key, value) end
end
local function create(td)
    local obj = assert(td:create_instance(), "Cannot create " .. td:get_full_name())
    obj:add_ref()
    assert(td:get_method(".ctor()"), "Missing constructor: " .. td:get_full_name()):call(obj)
    return obj
end

local function localized(text)
    assert(type(text) == "string" and text ~= "", "Missing localized text")
    -- Some item messages contain references to another message table.
    for _ = 1, 4 do
        local replaced
        text, replaced = text:gsub("<REF%s+([^<>%s]+)%s*>", function(name)
            return assert(api.message:call(nil, api.guid:call(nil, name)), "Missing referenced message: " .. name)
        end)
        if replaced == 0 then break end
    end
    assert(not text:find("<REF", 1, true), "Unresolved localized message reference")
    return text:gsub("<[^>]*>", "")
end

-- Keep names on one line and preserve the report's column separator.
local function clean(value)
    return tostring(value):gsub("[\r\n\t]+", " "):gsub("|", "／")
end
-- Display columns for monospaced text: CJK and fullwidth characters occupy two.
local function displayWidth(text)
    local width = 0
    for _, code in utf8.codes(text) do
        local wide = code >= 0x1100 and (code <= 0x115f or code == 0x2329 or code == 0x232a
            or (code >= 0x2e80 and code <= 0xa4cf and code ~= 0x303f)
            or (code >= 0xac00 and code <= 0xd7a3) or (code >= 0xf900 and code <= 0xfaff)
            or (code >= 0xfe10 and code <= 0xfe19) or (code >= 0xfe30 and code <= 0xfe6f)
            or (code >= 0xff00 and code <= 0xff60) or (code >= 0xffe0 and code <= 0xffe6)
            or (code >= 0x20000 and code <= 0x3fffd))
        width = width + (wide and 2 or 1)
    end
    return width
end
-- app.EquipmentAbilityBonus: native appraisal selects one bonus target.
local bonusSlots = {[1]=1, [2]=2, [4]=3, [8]=4}
local bonusElements = {[16]="FireElem", [32]="IceElem", [64]="ThunderElem", [128]="HolyElem"}
local weaponBonusLabels = {[256]="ATK", [512]="MagATK", [1024]="Knockdown",
    [2048]="SlashResist", [4096]="StrikeResist"}
local armorBonusLabels = {[256]="DEF", [512]="MagDEF", [1024]="KnockdownRes",
    [2048]="SlashResist", [4096]="StrikeResist"}
local abilityFields = {"Slot1", "Slot2", "Slot3", "Slot4", "IsAppraised",
    "PhysicalParameter", "MagicParameter", "BlowParameter", "WeightParameter"}

local function appendResults(rows, results, source, number, im, gm, names)
    assert(results, "Native prediction returned nil")
    results:add_ref()
    local length = api.arrayLength:call(results)
    assert(length > 0, "Native calculation returned no items for variant=" .. source)
    for i = 0, length - 1 do
        local result = api.arrayItem:call(results, i)
        local id, amount = result:get_field("ItemId"), result:get_field("ItemCount")
        assert(id > 0 and amount > 0, "Invalid native prediction result")
        if names.equipment[id] == nil then
            local param = assert(api.itemData:call(im, id), "Missing item data: " .. id)
            names.equipment[id] = api.isEquip:call(param) and param or false
        end
        local param = names.equipment[id]
        if param then
            local ability = assert(result:get_field("Ability"), "Missing result ability")
            local bonus = ability:get_field("Bonus")
            -- setParam accumulates: reset our private object before each result.
            api.copyEquip:call(names.stats, names.emptyStats)
            api.setEquip:call(names.stats, param, api.noEnhance:get_data(), ability)
            if bonus ~= 0 then
                -- Copy into private scratch storage; never edit a result.
                for _, field in ipairs(abilityFields) do
                    names.plainAbility:set_field(field, ability:get_field(field))
                end
                names.plainAbility:set_field("Bonus", 0)
                api.copyEquip:call(names.plainStats, names.emptyStats)
                api.setEquip:call(names.plainStats, param, api.noEnhance:get_data(), names.plainAbility)
            end
            local fields = {
                "    No." .. number,
                clean(localized(api.appraisedName:call(nil, id, ability, false, source))) .. "(" .. id .. ")",
            }
            local bonusSlot, bonusSkill = bonusSlots[bonus]
            local skills = {}
            for slot = 1, 4 do
                local skill = ability:get_field("Slot" .. slot)
                if skill ~= 0 then
                    if not names.skills[skill] then
                        local message = assert(api.skillName:call(gm, skill), "Missing skill message: " .. skill)
                        names.skills[skill] = clean(localized(message:call("getMessage()")))
                    end
                    skills[#skills + 1] = names.skills[skill] .. (slot == bonusSlot and "↑" or "")
                    if slot == bonusSlot then bonusSkill = skill end
                end
            end
            local category = param:get_field("_EquipCategory")
            local weapon, shield = category <= 1, category == 1
            local skillColumn = table.concat(skills, " / ")
            if not bonusSkill and bonus ~= 0 then
                local bonusLabel = bonusElements[bonus] or (weapon and weaponBonusLabels or armorBonusLabels)[bonus]
                skillColumn = skillColumn .. (#skills > 0 and " / " or "") .. (bonusLabel and (bonusLabel .. "↑")
                    or ("UnknownBonus(" .. tostring(bonus) .. ")"))
            end
            fields[#fields + 1] = skillColumn
            names.skillWidth = math.max(names.skillWidth or 0, displayWidth(skillColumn))
            local function stat(label, getter, randomField)
                local value = api[getter]:call(names.stats)
                local extra = bonus ~= 0 and (value - api[getter]:call(names.plainStats)) or 0
                local details = {}
                if randomField then details[#details + 1] = string.format("%+d", ability:get_field(randomField)) end
                if extra ~= 0 then details[#details + 1] = string.format("%+d", extra) end
                fields[#fields + 1] = label .. " " .. value
                    .. (#details > 0 and ("(" .. table.concat(details, ", ") .. ")") or "")
            end
            stat(weapon and "ATK" or "DEF",
                weapon and (shield and "shieldAttack" or "attack") or "defence", "PhysicalParameter")
            stat(weapon and "MagATK" or "MagDEF", weapon and "magicAttack" or "magicDefence", "MagicParameter")
            stat(weapon and "Knockdown" or "KnockdownRes",
                weapon and (shield and "shieldBlow" or "blow") or "blowResist", "BlowParameter")
            if bonus == 2048 then stat("SlashResist", "slashResist") end
            if bonus == 4096 then stat("StrikeResist", "strikeResist") end
            if bonusElements[bonus] then stat("ElementStore", "elementStore") end
            fields[#fields + 1] = string.format("Weight %.2f(%+.2f)",
                api.weight:call(names.stats), ability:get_field("WeightParameter") / 100)
            if amount ~= 1 then fields[#fields + 1] = "Count=" .. amount end
            rows[#rows + 1] = fields
        else
            if not names.items[id] then names.items[id] = clean(localized(api.itemName:call(nil, id))) end
            rows[#rows + 1] = "    No." .. number .. " | " .. names.items[id] .. "(" .. id .. ") | Count=" .. amount
        end
    end
end

local function exportResults(am, im, gm)
    local started = os.clock()
    local predictionCount = config.predictionCount
    local seed = am:get_field("RandomUint")
    local effective = config.enabled and assert(overrideSeed, "Enter a valid uint32 seed") or seed
    local calculationSeed = signed(effective)
    local normal = dictionary(am:get_field("ItemSettingDict"))
    local fixed = dictionary(am:get_field("FixedItemSettingDict"))
    local counters = dictionary(am:get_field("ExecuteIndexDict"))
    local shadow = create(api.managerType)
    assert(shadow ~= am and shadow:get_field("_Random") ~= am:get_field("_Random"), "Prediction RNG is not isolated")
    local shadowCounters = shadow:get_field("ExecuteIndexDict")
    assert(shadowCounters ~= am:get_field("ExecuteIndexDict"), "Prediction counters are not isolated")
    fill(shadowCounters, counters)
    -- Private RNG, counters, lists and locks; only immutable settings are shared.
    shadow:set_field("ItemSettingDict", am:get_field("ItemSettingDict"))
    shadow:set_field("AppraisalLevelSettingDict", am:get_field("AppraisalLevelSettingDict"))
    fill(shadow:get_field("RareEquipDict"), dictionary(am:get_field("RareEquipDict")))
    -- Match GainItem: only random variants and jobs with their own candidates.
    -- Fixed mappings are excluded even if also present in the normal table.
    local ids = {}
    for id in pairs(normal) do
        if not fixed[id] then ids[#ids + 1] = id end
    end
    table.sort(ids)
    assert(#ids > 0, "No appraisal settings loaded")
    local lines = {
        "Generated at (UTC)=" .. os.date("!%Y-%m-%dT%H:%M:%SZ") .. " | Seed=" .. effective,
        "",
    }
    local names, combinations = {skills={}, items={}, relics={}, equipment={}, jobs={[0]="None"},
        stats=create(api.equipType), plainStats=create(api.equipType), emptyStats=create(api.equipType),
        plainAbility=ValueType.new(api.abilityType)}, 0
    for _, source in ipairs(ids) do
        local display = api.fakeId:call(nil, source)
        if display <= 0 then display = source end
        local data = assert(normal[source]:get_field("data"), "Missing variant data")
        -- Discarded supplies use job 0 rather than enumerating job variants.
        for job = 0, (source == 654 or source == 655) and 0 or 10 do
            local candidates = data:call("getJobDataList(app.Character.JobEnum)", job)
            if count(candidates) == 0 then goto continue end
            local key, rows = source * 100 + job, {}
            for step = 1, predictionCount do
                -- -1 uses native first-appraisal rules and counter wraparound.
                local results = api.calculate:call(shadow, source, job, calculationSeed, -1)
                appendResults(rows, results, source, ((counters[key] or 0) + step - 1) % 2147483647 + 1, im, gm, names)
            end
            -- Each pair starts with the same live history, including other jobs.
            if counters[key] == nil then shadowCounters:call("Remove", key)
            else shadowCounters:call("set_Item", key, counters[key]) end
            if #rows > 0 then
                if not names.relics[display] then
                    names.relics[display] = clean(localized(api.itemName:call(nil, display))) .. "(" .. display .. ")"
                end
                combinations = combinations + 1
                if not names.jobs[job] then names.jobs[job] = clean(localized(api.jobName:call(nil, job))) end
                lines[#lines + 1] = names.relics[display] .. " | " .. names.jobs[job] .. " + " .. source
                    .. " | past = " .. (counters[key] or 0)
                for _, row in ipairs(rows) do lines[#lines + 1] = row end
                lines[#lines + 1] = ""
            end
            ::continue::
        end
    end
    assert(am == sdk.get_managed_singleton("app.ItemAppraisalManager")
        and seed == am:get_field("RandomUint"), "Game or seed settings changed during export")
    local current = dictionary(am:get_field("ExecuteIndexDict"))
    for key, value in pairs(counters) do assert(current[key] == value, "Appraisal history changed during export") end
    for key, value in pairs(current) do assert(counters[key] == value, "Appraisal history changed during export") end
    if combinations == 0 then lines[#lines + 1] = "当前预测中没有物品结果。" end
    -- Reduce the padding target by ten display columns without truncating skills.
    for i, line in ipairs(lines) do
        if type(line) == "table" then
            line[3] = line[3] .. string.rep(" ", math.max(0, names.skillWidth - 10 - displayWidth(line[3])))
            lines[i] = table.concat(line, " | ")
        end
    end
    local text = table.concat(lines, "\r\n") .. "\r\n"
    -- Write only after all calculations and live-history checks have succeeded.
    -- REFramework resolves io paths relative to reframework/data.
    local file, why = io.open(OUTPUT, "wb")
    assert(file, "Cannot open " .. OUTPUT .. ": " .. tostring(why))
    local ok, err = pcall(function() assert(file:write(text), "Cannot write " .. OUTPUT) end)
    local closed, closeError = file:close()
    if not ok then error(err) end
    assert(closed, "Cannot close " .. OUTPUT .. ": " .. tostring(closeError))
    log.info(TAG .. string.format("Exported %d appraisal combinations to %s in %.3f seconds",
        combinations, OUTPUT, os.clock() - started))
end

local function bind(owner, signature)
    return assert(assert(sdk.find_type_definition(owner), "Missing type: " .. owner):get_method(signature),
        "Missing method: " .. owner .. "." .. signature)
end
local function initialize()
    api.managerType = assert(sdk.find_type_definition("app.ItemAppraisalManager"), "Missing appraisal manager type")
    api.calculate = bind("app.ItemAppraisalManager", "getAppraisalItemResult(System.Int32, app.Character.JobEnum, System.Int32, System.Int32)")
    api.arrayLength = bind("System.Array", "get_Length()")
    api.arrayItem = bind("System.Array", "GetValue(System.Int32)")
    api.itemData = bind("app.ItemManager", "getItemData(System.Int32)")
    api.isEquip = bind("app.ItemCommonParam", "get_IsEquip()")
    api.equipType = assert(sdk.find_type_definition("app.EquipParam"), "Missing equipment parameter type")
    api.abilityType = assert(sdk.find_type_definition("app.ItemDefine.EquipmentAbilityParam"), "Missing equipment ability type")
    api.noEnhance = assert(sdk.find_type_definition("app.ItemDefine.EnhanceParam"):get_field("None"), "Missing default enhancement")
    api.setEquip = bind("app.EquipParam", "setParam(app.ItemCommonParam, app.ItemDefine.EnhanceParam, app.ItemDefine.EquipmentAbilityParam)")
    api.copyEquip = bind("app.EquipParam", "copyFrom(app.EquipParam)")
    for key, getter in pairs({attack="PhysicalAttack", magicAttack="MagicAttack", defence="PhysicalDefence",
        magicDefence="MagicDefence", blow="Blow", blowResist="BlowResistRate", shieldAttack="ShieldAttack",
        shieldBlow="ShieldBlow", weight="WeightF", slashResist="SlashDefenceRate",
        strikeResist="StrikeDefenceRate", elementStore="ElementStore"}) do
        api[key] = bind("app.EquipParam", "get_" .. getter .. "()")
    end
    api.jobName = bind("app.GUIBase", "getJobName(app.Character.JobEnum)")
    api.fakeId = bind("app.ItemDefine", "getFakeItemId(System.Int32)")
    api.itemName = bind("app.GUIBase", "getItemName(System.Int32)")
    api.appraisedName = bind("app.GUIBase", "convertAppraisedItemName(System.Int32, app.ItemDefine.EquipmentAbilityParam, System.Boolean, System.Int32)")
    api.skillName = bind("app.GuiManager", "getEquipmentAbilityNameMsgData(app.EquipmentAbilityID)")
    api.guid = bind("via.gui.message", "getGuidByName(System.String)")
    api.message = bind("app.MessageManager", "getMessage(System.Guid)")
    local load = bind("app.ItemAppraisalManager", "loadGameSaveData(app.SaveDataBase)")
    local scene = bind("app.GuiManager", "OnChangeSceneType")
    sdk.hook(api.calculate, function(args)
        -- Replace ONLY this call's seed argument, never the saved RandomUint.
        -- Shadow predictions carry their own frozen seed and are excluded.
        if sdk.to_managed_object(args[2]) ~= sdk.get_managed_singleton("app.ItemAppraisalManager") then return end
        if not failed and config.enabled and overrideSeed ~= nil then args[5] = sdk.to_ptr(signed(overrideSeed)) end
    end, function(retval) return retval end)
    sdk.hook(load, function()
        requested = false
    end, function(retval) return retval end)
    sdk.hook(scene, function()
        requested = false
    end, function(retval) return retval end)
    ready = true
end

local seedToggle = {name="enabled", type="bool", label="Override appraisal seed", default=false,
    tip="Changes only the seed passed into appraisal. The saved seed is never replaced. Appraised items and normal appraisal history still save normally."}
local seedControl = {name="seed", type="uint32", label="Seed", default=1, min=1, max=4294967295}
local predictionControl = {name="predictionCount", type="int", label="Prediction count", default=10, min=1, max=50,
    tip="Number of upcoming appraisals to predict for each relic and job combination."}
controls = {
    {name="Appraisal seed", type="mutualbox"},
    seedToggle,
    seedControl,
    {name="Export", type="mutualbox"},
    predictionControl,
    {name="export", type="button", label="Export Stargazing Results",
        tip="Runs continuously in one game update. Rendering waits until calculation and file writing finish.", onClick=function()
        if failed then return end
        requested=true
    end},
    {type="mutualboxend"},
    {type="author", version="1.0"},
}
local function normalizeConfig()
    local n = math.tointeger(tonumber(config.predictionCount)) or predictionControl.default
    config.predictionCount = math.max(predictionControl.min, math.min(predictionControl.max, n))
    -- Migrate the old string seed and clamp persisted values before the first draw.
    local seed = tonumber(config.seed) or seedControl.default
    if seed ~= seed then seed = seedControl.default end
    config.seed = math.floor(math.max(seedControl.min, math.min(seedControl.max, seed)))
    overrideSeed = config.seed
end
config = myapi.InitFromFile(controls, "stargaze.json", true)
normalizeConfig()
myapi.DrawIt("stargaze", "stargaze.json", controls, config, normalizeConfig, true)

re.on_application_entry("UpdateBehavior", function()
    if failed then return end
    local run = requested
    requested = false
    local ok, err = pcall(function()
        local am = sdk.get_managed_singleton("app.ItemAppraisalManager")
        local gm = sdk.get_managed_singleton("app.GuiManager")
        if not am or not gm then
            if run then log.error(TAG .. "Export unavailable: game managers are not ready") end
            return
        end
        if not ready then initialize() end
        local seed = am:get_field("RandomUint")
        seedToggle.label = "Override appraisal seed | Save seed: " .. tostring(seed)
            .. " | Effective: " .. tostring(config.enabled and (overrideSeed or "INVALID; using saved seed") or seed)
        if not run then return end
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        local im = sdk.get_managed_singleton("app.ItemManager")
        local menu = gm:get_field("AppraisalMenu")
        if not im or not cm or not cm:call("get_ManualPlayer()") or seed == 0
            or (menu and not menu:call("get_IsEndGUI()"))
            or am:call("get_IsExecute()") or count(am:get_field("TempStorageDatas")) > 0
            or am:get_field("ComplatedHandler") ~= nil or count(am:get_field("ItemSettingDict")) == 0 then
            log.error(TAG .. "Export unavailable: load a save and close the native appraisal menu, then try again")
            return
        end
        exportResults(am, im, gm)
    end)
    if not ok then
        log.error(TAG .. tostring(err))
        if not ready then
            failed=true
            config.enabled=false
            seedToggle.label="Unavailable: initialization failed (see REFramework log)"
        end
    end
end)
