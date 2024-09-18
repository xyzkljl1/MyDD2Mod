local modname="SkillDescription"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
    
    {name="removeOriginalText",type="bool",default=true},
    {name="specifyTransFile",type="string",default="",label="Force using this language(Need reset script)"},
}
--merge config file to default config
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
local config = {} 
for key,para in pairs(_config) do
    config[para.name]=para.default
end
config= recurse_def_settings(config, json.load_file(configfile) or {})

--Cache of expaned Item Description
local CustomSkillDescCache={}
local NormalSkillDescCache={}
local CustomSkillFormat={}
local NormalSkillFormat={} -- in translation file,normalskill include actions(like normal attack)
local SkillParameter={}
local SkillName2Id={}

local function Log(...)
    print(...)
    --log.info(modname..msg)
end

local function printEnum(enumName)
    local guiManager=sdk.get_managed_singleton("app.GuiManager")
    --local func=sdk.find_type_definition("app.GuiManager"):get_method("getCustomSkillName(app.HumanCustomSkillID, app.HumanCustomSkillLevelNo)")
    local func=sdk.find_type_definition("app.GuiManager"):get_method("getNormalSkillName(app.HumanNormalSkillID)")
    local messageManager=sdk.get_managed_singleton("app.MessageManager")
    local type=sdk.find_type_definition(enumName)
    local fields=type:get_fields()

    local ret=""
    for _,field in pairs(fields) do
        if field:get_data()~=nil and field:get_data()>0 then
            --local id=func:call(guiManager,field:get_data(), 1)
            local id=func:call(guiManager,field:get_data())
            local name=messageManager:getMessage(id)
            print(field:get_data(),id:ToString(),name)
            ret=ret..string.format("\"%d\":{\"name\":\"%s\",\"hintJP\":\"%s\",\"format\":\"\"},",field:get_data(),field:get_name(),name)
        end
    end
    log.info(ret)
    print(ret)
end
--printEnum("app.HumanCustomSkillID")
--printEnum("app.HumanNormalSkillID")
local function float2stringEX(v)
    if v-math.floor(v)<0.0001 then
        return string.format("%.1f",v)
    end
    return string.format("%.2f",v)
end


--[[
[0]="Japanese"
[1]="English",
[2]="French",
[3]="Italian",
[4]="German",
[5]="Spanish",
[6]="Russian",
[7]="Polish",
[8]="Dutch",
[9]="Portuguese",
[10]="PortugueseBr",
[11]="Korean",
[12]="TransitionalChinese",
[13]="SimplelifiedChinese",
[14]="Finnish",
[15]="Swedish",
[16]="Danish",
[17]="Norwegian",
[18]="Czech",
[19]="Hungarian",
[20]="Slovak",
[21]="Arabic",
[22]="Turkish",
[23]="Bulgarian",
[24]="Greek",
[25]="Romanian",
[26]="Thai",
[27]="Ukrainian",
[28]="Vietnamese",
[29]="Indonesian",
[30]="Fiction",
[31]="Hindi",
[32]="LatinAmericanSpanish",
[33]="Max",
[33]="Unknown",
]]--
local prevInitLanguage=""
local function Init()
    local om=sdk.get_managed_singleton("app.OptionManager")
    local lngID=sdk.find_type_definition("app.OptionID"):get_field("TextLanguage"):get_data()
    if not om._OptionItems:ContainsKey(lngID) then
        Log("OptionManager Not Ready,abort"..tostring(lngID))
        return        
    end
    local optionItem=om._OptionItems:get_Item(lngID)
    local lng=optionItem:get_FixedValueModel():get_StringValue()
    if lng==prevInitLanguage then
        Log("Ignore dup init")
        return
    end

    local filename=string.format("%s.%s.json",modname,lng)
    if config.specifyTransFile~="" then
        filename=string.format("%s.%s.json",modname,config.specifyTransFile)
    end
    Log("Try Load ",lng)
    local tmp=json.load_file(filename)
    if tmp==nil or tmp.CustomSkill==nil then
        filename=string.format("%s.English.json",modname)
        Log("Invalid File,Use English "..filename)
        tmp=json.load_file(filename)
    end
    if tmp~=nil and tmp.CustomSkill~=nil then
        CustomSkillFormat=tmp.CustomSkill
        NormalSkillFormat=tmp.NormalSkill
        Log("Load From",filename)
    end

    tmp=json.load_file(string.format("%s.Para.json",modname))
    if tmp~=nil then
        --预处理
        SkillParameter={}
        for job,l1 in pairs(tmp) do
            for _,l2 in pairs(l1) do
                for _,paras in pairs(l2) do
                    SkillParameter["{"..paras.Path.."}"] =float2stringEX(paras.ActionRate)
                    --record hint too,hint key could be dup.
                    paras.Hint="{"..string.sub(paras.Hint,0,string.len(paras.Hint)-1).."}"
                    if SkillParameter[paras.Hint]==nil then SkillParameter[paras.Hint]={} end
                    SkillParameter[paras.Hint][job] =float2stringEX(paras.ActionRate)
                    --用default表示该key下是否只有一个可选的值，如果只有一个，则default=该值的键，否则default="None"
                    if SkillParameter[paras.Hint].default ==nil then                        
                        SkillParameter[paras.Hint].default=job
                    else --不为空说明有重复key
                        SkillParameter[paras.Hint].default="None"
                    end
                end
            end
        end
        
    end

    prevInitLanguage=lng
    CustomSkillDescCache={}
    NormalSkillDescCache={}

    --Init SkillName2Id
    SkillName2Id={}
    local xxx={}

    local messageManager=sdk.get_managed_singleton("app.MessageManager")
    local type=sdk.find_type_definition("app.Character.JobEnum")
    local fields=type:get_fields()
    local guiManager=sdk.get_managed_singleton("app.GuiManager")
    for _,field in pairs(fields) do
        if field:get_data()~=nil and field:get_data()>0 then
            local job=field:get_data()
            local actions=guiManager:getNormalActionData(job)
            local iter=actions:GetEnumerator()
            iter:MoveNext()
            while iter:get_Current():get_Value()~=nil do
                local action=iter:get_Current():get_Value()
                local skillName= messageManager:getMessage(action._SkillName)
                SkillName2Id[skillName]={type="Action",id=string.format("Job%02d_%d",job,action._ActionID)}
                iter:MoveNext()
            end

            local actions=guiManager:getNormalSkillSets(job)
            local iter=actions:GetEnumerator()
            iter:MoveNext()
            while iter:get_Current():get_Value()~=nil do
                local action=iter:get_Current():get_Value()
                local skillName= messageManager:getMessage(action._SkillName)
                SkillName2Id[skillName]={type="Normal",id=action._SkillID}
                iter:MoveNext()
            end
                       
            local actions=guiManager:getCustomSkillSets(job)
            local iter=actions:GetEnumerator()
            iter:MoveNext()
            while iter:get_Current():get_Value()~=nil do
                local skills=iter:get_Current():get_Value()

                local iter2=skills:GetEnumerator()
                iter2:MoveNext()
                while iter2:get_Current():get_Value()~=nil do
                    local skill=iter2:get_Current():get_Value()
                    local skillName= messageManager:getMessage(skill._SkillName)
                    SkillName2Id[skillName]={type="Custom",id=skill._SkillID}
                    iter2:MoveNext()
                end
                iter:MoveNext()
            end
        end
    end
end

--Init
sdk.hook(sdk.find_type_definition("app.OptionManager"):get_method("app.ISystemSaveData.loadSystemSaveData(app.SaveDataBase)"),nil,Init)
sdk.hook(sdk.find_type_definition("app.GuiManager"):get_method("OnChangeSceneType"),nil,Init)
Init()

local function GetSkillDetail(player,id,isNormalSkill)
    local formatList=CustomSkillFormat
    if isNormalSkill then formatList=NormalSkillFormat end

    local format=formatList[tostring(id)]
    local ret=format.format
    for k,_ in ret:gmatch('{[^}]*}') do
        if SkillParameter[k]~=nil then
            if type(SkillParameter[k])=="table" then
                if SkillParameter[k].default~="None" then
                    ret=ret:gsub(k,SkillParameter[k][SkillParameter[k].default])
                elseif format.Job~=nil and SkillParameter[k][format.Job]~=nil then
                    ret=ret:gsub(k,SkillParameter[k][format.Job])
                else--has duplicate key and no specify job
                    ret=ret:gsub(k,"{Error}")
                end
            else
                ret=ret:gsub(k,SkillParameter[k])
            end
        end
    end
    return ret
end

local function GetOrAddSkillDesc(originalMessage,Id,isNormalSkill)
    local SkillDescCache=CustomSkillDescCache
    if isNormalSkill then
        SkillDescCache= NormalSkillDescCache
    end

    --if tmpStr~=nil then return tmpStr end
    if SkillDescCache[originalMessage] ==nil then
        Log("Add Skill Desc To Cache",originalMessage,Id)
        local player_man=sdk.get_managed_singleton("app.CharacterManager")
        local player=player_man:get_ManualPlayer()
        if player~=nil then
            local appendtext= GetSkillDetail(player,Id,isNormalSkill)
            local _, count = string.gsub(string.format("%s\n%s",originalMessage,appendtext), "\n", "")
            if config.removeOriginalText and count >=4 and appendtext~="" then
                SkillDescCache[originalMessage]=appendtext
            else
                SkillDescCache[originalMessage]=string.format("%s\n%s",originalMessage,appendtext)
            end
            Log(SkillDescCache[originalMessage])
        else
            return sdk.create_managed_string(originalMessage)
        end

    end
    return sdk.create_managed_string(SkillDescCache[originalMessage])
end

local messageManager=sdk.get_managed_singleton("app.MessageManager")
local tmpJobWindow=nil
--Job NormalSkill CustomSkill Ability other
local MainContentsInfoKindNormalSkill=sdk.find_type_definition("app.ui040101_00.MainContentsInfo.Kind"):get_field("NormalSkill"):get_data()
local MainContentsInfoKindCustomSkill=sdk.find_type_definition("app.ui040101_00.MainContentsInfo.Kind"):get_field("CustomSkill"):get_data()
local MainContentsInfoKindOther=sdk.find_type_definition("app.ui040101_00.MainContentsInfo.Kind"):get_field("Other"):get_data()


local function BeforeUpdateSkillInfo(args)
    local this=sdk.to_managed_object(args[2])
    tmpJobWindow=this
end
local function AfterUpdateCustomSkillInfo()
    if tmpJobWindow~=nil then
        local skillId=nil
        local cursor=tmpJobWindow._Main_ContentsListCtrl:get_SelectedInfo()
        if cursor.ContenstsType==MainContentsInfoKindCustomSkill then
            skillId=cursor.CustomSkill.Param._SkillID
        end
        --print("!!!",skillId,rindex,tmpJobWindow._Skill_EqList_SelectCursor)

        if skillId~=nil and skillId>0 then
            local originalMessage= messageManager:getMessage(tmpJobWindow._TxtCustomInfo:get_MessageId())
            tmpJobWindow._TxtCustomInfo:set_Message(GetOrAddSkillDesc(originalMessage,skillId))
            --print(skillId,cursor.Lv)
        end
        tmpJobWindow=nil
    end
end
local function AfterUpdateEquipCustomSkillInfo()
    if tmpJobWindow~=nil then
        local skillId=nil
        --cant get skill id?
        local index=tmpJobWindow._Skill_EqList_SelectCursor
        local skillname=tmpJobWindow._Skill_EqList[index].Name
        local skill=SkillName2Id[skillname]
        if skill~=nil and skill.type=="Custom" then
            local skillId=skill.id
            local originalMessage= messageManager:getMessage(tmpJobWindow._TxtCustomInfo:get_MessageId())
            tmpJobWindow._TxtCustomInfo:set_Message(GetOrAddSkillDesc(originalMessage,skillId))
        end
        tmpJobWindow=nil
    end
end
local function AfterUpdateNormalSkillInfo()
    if tmpJobWindow~=nil then
        local skillId=nil
        local cursor=tmpJobWindow._Main_ContentsListCtrl:get_SelectedInfo()
        if cursor.ContenstsType==MainContentsInfoKindNormalSkill then
            skillId=cursor.NormalSkill.SkillID
        end
        if skillId~=nil and skillId>0 then
            tmpJobWindow._TxtNormalInfo:set_Message(GetOrAddSkillDesc(tmpJobWindow._TxtNormalInfo:get_Message(),skillId,true))
        end
        tmpJobWindow=nil
    end
end

local tmpStatusWindow=nil
local tmpSkillInfo=nil
local function BeforeUpdateStatus(args)
    local this=sdk.to_managed_object(args[2])
    local skillInfo=sdk.to_managed_object(args[3])
    tmpStatusWindow=this
    tmpSkillInfo=skillInfo
end
local function AfterUpdateStatus()
    if tmpStatusWindow~=nil then
        local originalMessage= messageManager:getMessage(tmpStatusWindow.Movie.TxtDetail:get_MessageId())
        --DispType 1:customskill 2:normal 3:augment
        local nameText=messageManager:getMessage(tmpSkillInfo.NameId)
        if SkillName2Id[nameText]~=nil then
            local skillId=SkillName2Id[nameText].id
            local isNormalSkill=SkillName2Id[nameText].type~="Custom"
            tmpStatusWindow.Movie.TxtDetail:set_Message(GetOrAddSkillDesc(originalMessage,skillId,isNormalSkill))
            --not working
            --local size=tmpStatusWindow.Movie.Pnl:get_CaptureSize()
            --print(size.w)
            --print(size.h)
            --size.w=300
            --size.h=2000
            --tmpStatusWindow.Movie.Pnl:set_CaptureSize(size)
        end
        tmpStatusWindow=nil
        tmpSkillInfo=nil
    end
end

sdk.hook(sdk.find_type_definition("app.ui040101_00"):get_method("setupSkillInfoWindow"),BeforeUpdateSkillInfo,AfterUpdateCustomSkillInfo)--switch custom skill on left
sdk.hook(sdk.find_type_definition("app.ui040101_00"):get_method("setupCustomSkillMenuStatus"),BeforeUpdateSkillInfo,AfterUpdateEquipCustomSkillInfo)--switch custom skill on right
sdk.hook(sdk.find_type_definition("app.ui040101_00"):get_method("setupNormalSkillInfoWindow"),BeforeUpdateSkillInfo,AfterUpdateNormalSkillInfo)
sdk.hook(sdk.find_type_definition("app.ui060601_01"):get_method("setupSkillDetail(app.ui060601_01.SkillInfo)"),BeforeUpdateStatus,AfterUpdateStatus)


--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,function()  CustomSkillDescCache={} NormalSkillDescCache={} end) end

