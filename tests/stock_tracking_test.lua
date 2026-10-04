-- Exercise the actual reviewed Blizzard selection algorithm when its pinned source is available.
local W=dofile("tests/wow_mock.lua")
function CreateFromMixins(...)
    local out={}
    for _,mixin in ipairs({...}) do for key,value in pairs(mixin) do out[key]=value end end
    return out
end
local root=arg[1] or "/tmp/xpisland-forever-source/Interface/AddOns/Blizzard_StatusTrackingBar/"
local source=assert(loadfile(root.."Shared/StatusTrackingManager.lua"),"Provide the pinned Blizzard source path")
source()
assert(loadfile(root.."Mainline/StatusTrackingManagerOverrides.lua"))()
function tContains(t,v) for _,item in pairs(t) do if item==v then return true end end;return false end
StatusTrackingBarInfo={BarsEnum={None=0,Experience=1,Reputation=2,Honor=3},BarPriorities={[1]=0,[2]=2,[3]=3}}
C_Reputation={GetWatchedFactionData=function() return {name="Stormwind"} end}
function IsWatchingHonorAsXP() return false end
C_PvP={IsActiveBattlefield=function() return false end}
function IsInActiveWorldPVP() return false end
local function container()
    return {IsAnimating=function() return false end,SetShownBar=function(self,index) self.index=index end,SubscribeToOnFinishedAnimating=function() end}
end
StatusTrackingBarManager=setmetatable({barContainers={container(),container()},shownBarIndices={},UpdateBarVisuals=function() end},{__index=StatusTrackingManagerMixin})
local ns=W.load();local X=ns.owner
X.profile={hideBlizzard=false}
StatusTrackingBarManager:UpdateBarsShown()
assert(StatusTrackingBarManager.shownBarIndices[1]==2)
assert(StatusTrackingBarManager.shownBarIndices[2]==1)
X.profile.hideBlizzard=true;X:Integration()
assert(#StatusTrackingBarManager.shownBarIndices==1)
assert(StatusTrackingBarManager.shownBarIndices[1]==2)
X.profile.hideBlizzard=false;X:Integration()
assert(StatusTrackingBarManager.shownBarIndices[2]==1)
-- A later addon owns the method. Disabling XPIsland must leave its wrapper intact.
X.profile.hideBlizzard=true;X:Integration()
local ours=StatusTrackingBarManager.CanShowBar
local theirs=function(self,index) return ours(self,index) end
StatusTrackingBarManager.CanShowBar=theirs
X.profile.hideBlizzard=false;X:Integration()
assert(StatusTrackingBarManager.CanShowBar==theirs)
assert(StatusTrackingBarManager:CanShowBar(1)==true)
assert(StatusTrackingBarManager.shownBarIndices[2]==1,"restore visible XP immediately through the current owner's policy")
print("PASS: 8 assertions against Blizzard's pinned tracking selection source; no live taint claim")
