-- Frame ownership and protected visibility, optionally checked against Blizzard's
-- exported Forever 1.60.1.70338 source (943764493e6b16d63ded3ab304150d1f05e58b57).
local W=dofile("tests/wow_mock.lua")
local selectBar=StatusTrackingBarManager.CanShowBar
if arg[1] then
    local functions={}
    APIDocumentation={AddDocumentationTable=function(_,doc)
        for _,enum in ipairs(doc.Tables or {}) do
            if enum.Type=="Enumeration" then
                Enum[enum.Name]={}
                for _,field in ipairs(enum.Fields) do Enum[enum.Name][field.Name]=field.EnumValue end
            end
        end
        for _,f in ipairs(doc.Functions or {}) do functions[f.Name]=f end
    end}
    for _,name in ipairs({"SecretAspectConstants","ForbiddenAspectConstants","SimpleFrameAPI"}) do
        assert(loadfile(arg[1].."/Blizzard_APIDocumentationGenerated/"..name.."Documentation.lua"))()
    end
    for _,name in ipairs({"Show","Hide"}) do
        local f=assert(functions[name])
        assert(#f.Arguments==0 and not f.Returns and f.IsProtectedFunction)
    end
    local f=assert(functions.IsShown)
    assert(#f.Arguments==0 and #f.Returns==1 and f.Returns[1].Type=="bool")
    assert(f.SecretReturnsForAspect[1]==Enum.SecretAspect.Shown)
    function CreateFromMixins(...)
        local out={}
        for _,mixin in ipairs({...}) do for key,value in pairs(mixin) do out[key]=value end end
        return out
    end
    assert(loadfile(arg[1].."/Blizzard_StatusTrackingBar/Shared/StatusTrackingManager.lua"))()
    assert(loadfile(arg[1].."/Blizzard_StatusTrackingBar/Mainline/StatusTrackingManagerOverrides.lua"))()
    C_Reputation={GetWatchedFactionData=function() return {name="Stormwind"} end}
    function IsWatchingHonorAsXP() return true end
    selectBar=StatusTrackingManagerMixin.CanShowBar
end
local function forbidden() error("XPIsland changed a stock callback, layout or event subscription") end
local shown=true
local methods={CanShowBar=selectBar,UpdateBarsShown=forbidden,SetParent=forbidden,
    RegisterEvent=forbidden,RegisterUnitEvent=forbidden,UnregisterEvent=forbidden,
    UnregisterAllEvents=forbidden,RegisterAllEvents=forbidden,
    IsShown=function(_,...) assert(select('#',...)==0);return shown end,
    Hide=function(_,...) assert(select('#',...)==0 and not W.combat);shown=false end,
    Show=function(_,...) assert(select('#',...)==0 and not W.combat);shown=true end}
-- Trap even temporary callback writes. Frame visibility is held outside Lua fields.
StatusTrackingBarManager=setmetatable({},{__index=methods,__newindex=forbidden})
local manager=StatusTrackingBarManager
local callbacks={}
EventRegistry={RegisterCallback=function(_,event,callback,owner)
    assert(not callbacks[event]);callbacks[event]=function() callback(owner) end
end}
EditModeManagerFrame={IsEditModeActive=function() return W.editing end}
XPIslandDB={version=2,profiles={Shared={hideBlizzard=true,scale=1.25,showPet=false}}}
local ns=W.load();local X=ns.owner
W.event("ADDON_LOADED","XPIsland");W.event("PLAYER_ENTERING_WORLD",true,false)
assert(not shown and X.hiddenStockManager==manager)
assert(X.profile.hideBlizzard and X.profile.scale==1.25 and X.profile.showPet==false)
-- Native eligibility is unchanged even while the whole manager is hidden.
assert(manager:CanShowBar(1) and manager:CanShowBar(2) and manager:CanShowBar(3))
W.combat=true;W.set('hideBlizzard',false);X:ApplyProfile()
assert(not shown,"restoration waits for combat to end")
W.combat=false;W.event("PLAYER_REGEN_ENABLED");assert(shown and not X.hiddenStockManager)
W.combat=true;W.set('hideBlizzard',true);X:ApplyProfile();assert(shown)
W.combat=false;W.event("PLAYER_REGEN_ENABLED");assert(not shown)
-- Edit Mode reconciliation is deferred out of the native callback stack.
W.editing=true;callbacks["EditMode.Enter"]();assert(not shown);W.advance(0);assert(shown)
W.editing=false;callbacks["EditMode.Exit"]();assert(shown);W.advance(0);assert(not shown)
-- Hand ownership to Ellesmere without revealing its hidden stock UI.
local eab={db={profile={useBlizzardDataBars=false}}}
EllesmereUI={Lite={GetAddon=function() return eab end}}
W.event("ADDON_LOADED","EllesmereUIActionBars")
assert(not shown and not X.hiddenStockManager)
W.set('hideBlizzard',false);X:ApplyProfile();assert(not shown)
EllesmereUI=nil;W.set('hideBlizzard',true);X:ApplyProfile()
W.set('hideBlizzard',false);X:ApplyProfile()
assert(not shown,"a frame already hidden by another owner stays hidden")
-- Restricted IsShown results must not turn into an ownership claim or mutation.
local secret={};function issecretvalue(v) return rawequal(v,secret) end
shown=secret;W.set('hideBlizzard',true);X:ApplyProfile()
assert(rawequal(shown,secret) and not X.hiddenStockManager)
shown=true;issecretvalue=nil;X:ApplyProfile();assert(not shown)
W.set('hideBlizzard',false);X:ApplyProfile();assert(shown)
StatusTrackingBarManager=nil;X:ApplyProfile()
print("PASS: stock frame ownership, combat/Edit Mode deferral, restricted visibility and native eligibility"..(arg[1] and " against pinned Blizzard contracts" or ""))
