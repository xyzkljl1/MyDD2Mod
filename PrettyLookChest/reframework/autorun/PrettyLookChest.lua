local modname="PrettyLookChest"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
local myapi = require("_XYZApi/_XYZApi")
--settings
local _config={
    {name="gimmickName",type="stringComboBox",label="ChestModel",default="Gm80_097",list={
            ["Gm80_001"]="Wooden",
            ["Gm80_096"]="Black",
            ["Gm80_097"]="Golden Red",
            ["Gm81_042"]="Sphinx",
            ["Gm80_211"]="Old Golden Red",
            --["Gm81_042_01"]="Super Big",--need key
            ["Gm80_001_10"]="Also Wooden",
            ["Gm80_096_10"]="Also Black",
            }
    },
}

local config=myapi.InitFromFile(_config,configfile)
local gimmickID2Name,gimmickName2ID=myapi.Enum2Map("app.GimmickID")
local woodChestID=gimmickName2ID["Gm80_001"]

sdk.hook(
    sdk.find_type_definition("app.GenerateSelector"):get_method("randomSelect")
,    function (args)
        local this=sdk.to_managed_object(args[2])
        local t=this["<Table>k__BackingField"]
        if t~=nil and t._GimmickSetInfo ~=nil then
            local tableRow=t._GimmickSetInfo._BasicRowDatas
            local ct=tableRow:get_Count()-1
            for i=0,ct do
                local rowData=tableRow[i]
                local id=rowData._GimmickID
                if id==woodChestID then
                    print("ReplaceWoodChest ",gimmickName2ID[config.gimmickName])
                    rowData._GimmickID=gimmickName2ID[config.gimmickName]
                end
            end
        end
end,nil
)

myapi.DrawIt(modname,configfile,_config,config,nil)