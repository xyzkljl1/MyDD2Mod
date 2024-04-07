local modname="Unstoppable"
local configfile=modname..".json"
log.info("["..modname.."]".."Start")
--settings
local _config={
    {name="CanBeKnockedDownByBoss",type="bool",default=false},
    {name="HitbackEnemyInOneHit",type="bool",default=true},
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

local playerManager=sdk.get_managed_singleton("app.CharacterManager")
sdk.hook(
    --contains DOT
    sdk.find_type_definition("app.HitController"):get_method("updateDamageReaction(app.HitController.DamageInfo)"),
    function(args)
        local this=sdk.to_managed_object(args[2])
        local damageInfo=sdk.to_managed_object(args[3])
        local character=this:get_CachedCharacter()
        local isPlayer=character==playerManager:get_ManualPlayer()
        local isBoss=character:get_IsBoss()
        local AttackUserData=damageInfo["<AttackUserData>k__BackingField"]
        local isBossAttack=false
        if AttackUserData~=nil then
            local attackerGO=damageInfo["<AttackOwnerObject>k__BackingField"]
            local attackHit=damageInfo["<AttackHitController>k__BackingField"] or damageInfo["<AttackOwnerHitController>k__BackingField"]
            local attackChara=attackHit and attackHit:get_CachedCharacter()
            isBossAttack=attackChara and attackChara:get_IsBoss()
        end

        if isPlayer then
            if config.CanBeKnockedDownByBoss and isBossAttack then
            else
                damageInfo.CatchReactionType=0
                damageInfo.DamageReaction=0.0
                damageInfo.BlownReactionRate=0.0
                damageInfo.LeanReactionRate=0.0
            end
        elseif config.HitbackEnemyInOneHit then
            damageInfo.DamageReaction=100000.0
            damageInfo.BlownReactionRate=1000.0
            damageInfo.LeanReactionRate=1000.0
        end
    end,
    nil
)


--try load api and draw ui
local function prequire(...)
    local status, lib = pcall(require, ...)
    if(status) then return lib end
    return nil
end
local myapi = prequire("_XYZApi/_XYZApi")
if myapi~=nil then myapi.DrawIt(modname,configfile,_config,config,OnChanged) end
