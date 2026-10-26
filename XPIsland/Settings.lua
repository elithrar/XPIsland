local _, ns = ...
local M = ns.Model
-- SND owns publication. This adapter owns XPIsland's existing v2 account schema,
-- per-character selection and account-wide onboarding flag; sessions stay separate.
function ns.ConfigureSettings(app)
    local fields={}
    for key,value in pairs(M.defaults) do
        if type(value)=='boolean' then fields[key]={type='boolean',default=value} end
    end
    local function field(key,kind,extra)
        extra=extra or {};extra.type=kind;extra.default=M.Copy(M.defaults[key]);fields[key]=extra
    end
    field('font','font',{maxLength=119});field('fontSize','integer',{min=10,max=18})
    field('scale','number',{min=.5,max=1.5})
    field('format','enum',{values={'percent','fraction','left','leftPercent','eta','kills'}})
    field('mode','enum',{values={'xp','pvp'}});field('pvpFormat','enum',{values={'honor','rankLeft'}})
    field('placement','enum',{values={'top','bottom','custom'}})
    field('theme','enum',{values={'modern','forever'}})
    for _,key in ipairs({'normal','rested'}) do field(key,'color') end
    for _,key in ipairs({'levelUpDuration','autoCollapseDuration'}) do field(key,'enum',{values={5,10,15}}) end
    for _,key in ipairs({'x','y'}) do fields['position.'..key]={type='number',default=M.defaults.position[key],min=-10000,max=10000} end
    fields.expandedOnce={type='boolean',default=false}
    local function result(db,identity,readOnly)
        local active=identity and db.characters[identity] or 'Shared'
        if not db.profiles[active] then active='Shared' end
        local values=M.Copy(db.profiles[active]);values.expandedOnce=db.expandedOnce
        local names={};for name in pairs(db.profiles)do names[#names+1]=name end;table.sort(names)
        return {state={database=db,identity=identity,values=values,activeProfile=active,
            readOnly=readOnly==true or not identity,needsCharacter=not identity and not readOnly,
            profiles={names=names,operations={switch=true,duplicate=true,copy=true,reset=true,bind=not readOnly}}},
            saved=not readOnly and identity and {XPIslandDB=db} or nil}
    end
    local function write(db,active,path,value)
        if path=='expandedOnce' then db.expandedOnce=value
        elseif path:sub(1,9)=='position.' then db.profiles[active].position[path:sub(10)]=value
        else db.profiles[active][path]=M.Copy(value) end
        if path=='mode' then db.profiles[active].pvpAtCap=false end
        if path=='font' then db.profiles[active].fontCustomized=value~='Game tooltip' end
        if path=='fontSize' then db.profiles[active].fontSizeCustomized=true end
    end
    local adapter={}
    function adapter:Restore(saved)
        local db=M.Database(saved.XPIslandDB)
        if not db then return true,result(M.Database(nil),nil,true) end
        return true,result(db,nil,false)
    end
    function adapter:Prepare(state,operation)
        local db,identity=state.database,state.identity
        local kind,name=operation.kind,operation.name
        if kind=='bind' then
            identity=operation.identity
            if type(identity)~='string' or identity=='' then return false,{code='invalid',message='Character identity must be a nonempty string.'} end
            if not db.profiles[db.characters[identity]] then db.characters[identity]='Shared' end
        elseif kind=='set' then write(db,state.activeProfile,operation.path,operation.value)
        elseif kind=='patch' then for path,value in pairs(operation.values) do write(db,state.activeProfile,path,value) end
            if operation.values.pvpAtCap~=nil then db.profiles[state.activeProfile].pvpAtCap=operation.values.pvpAtCap end
        elseif kind=='switch' or kind=='copy' then
            if not db.profiles[name] then return false,{code='notFound',message='Choose an existing profile.'} end
            if kind=='switch' then db.characters[identity]=name else db.profiles[state.activeProfile]=M.Copy(db.profiles[name]) end
        elseif kind=='duplicate' then
            local created,err=M.Duplicate(db,state.activeProfile,name)
            if not created then return false,{code='invalid',message=err} end
            db.characters[identity]=created
        elseif kind=='reset' then db.profiles[state.activeProfile]=M.Profile()
        else return false,{code='unsupported',message='Unsupported profile operation.'} end
        return true,result(db,identity,false)
    end
    app:Settings({savedVariables={'XPIslandDB'},fields=fields,adapter=adapter})
    app:Appearance({themes={modern=ns.SomethingNeedDoing.Themes.modern,forever=ns.SomethingNeedDoing.Themes.forever},defaultTheme='modern'})
end
