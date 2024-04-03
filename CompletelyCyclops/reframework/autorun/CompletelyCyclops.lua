local cyclops={}
for _,field in pairs(sdk.find_type_definition("app.CharacterID"):get_fields()) do
    local value=field:get_data()
    if value~=nil and value >0 and field:get_name():find("ch250000_")~=nil then
        table.insert(cyclops,value)
        --print(value,field:get_name())
    end
end
sdk.hook(
    sdk.find_type_definition("app.GenerateSelector"):get_method("randomSelect")
,    function (args)
        local this=sdk.to_managed_object(args[2])
        local t=this["<Table>k__BackingField"]
        if t~=nil and t._EnemySetInfo ~=nil then
            local tableRow=t._EnemySetInfo._BasicRowDatas
            local ct=tableRow:get_Count()-1
            for i=0,ct do
                local rowData=tableRow[i]
                if rowData._CharaID~=nil then
                    rowData._CharaID = cyclops[math.random(1,#cyclops)]
                    print("Cyclops!",rowData._CharaID)
                end
            end
        end
end,nil
)

