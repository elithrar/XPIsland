-- Accepted approximation and real event/tooltip integration. The observed pool
-- is not used to fit a universal cap; the base rule remains deliberately tunable.
local W=dofile('tests/wow_mock.lua')
local ns=W.load();local X,M,UI=ns.owner,ns.Model,ns.UI
local n=0
local function eq(a,b,why) n=n+1;assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
for rank,maximum in ipairs({1500,1560,1620,1680,1740,1800}) do
 rank=rank-1
 eq(M.RestedMaximum(1000,rank),maximum,'base plus rank bonus')
 eq(M.RestedText(maximum-1,maximum),'99.9% of max. rested XP')
 eq(M.RestedText(maximum,maximum),'Max','exact whole-XP boundary')
 eq(M.RestedText(maximum+1,maximum),'Max','pool above modeled capacity')
end
eq(M.RestedMaximum(21300,5),38340)
eq(M.RestedMaximum(209800,5),377640)
eq(M.RestedMaximum(1001,3),1681,'future fractional capacity rounds down explicitly')
for _,bad in ipairs({0,-1,math.huge,0/0,'1000',false}) do eq(M.RestedMaximum(bad,0),nil) end
for _,bad in ipairs({-1,6,.5,math.huge,0/0,'5',false}) do eq(M.RestedMaximum(1000,bad),nil) end
eq(M.RestedMaximum(1000,nil),nil);eq(M.RestedMaximum(nil,0),nil)
-- Replay Matt's 70425 / L19 Warrior snapshot without inventing a global ratio.
W.level=19;W.xp=19752;W.cap=21300;W.rested=8896;W.legacyRank=5
XPIslandDB={version=2,profiles={Shared={format='eta',autoCollapse=false,rested={.12,.74,.38}}}}
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false);W.advance(0)
eq(X.restedMaximum,38340,'accepted model, not fitted to reported-full observation')
eq(UI.showInfinity,true,'empty session ETA is independent of rested capacity')
W.hover=UI.frame;UI.frame.scripts.OnEnter()
eq(W.tooltip.lines[1][1],'No XP earned this session.')
eq(W.tooltip.lines[2][1],'19,752 / 21,300 (92.7%)')
UI.frame.scripts.OnLeave();UI:SetExpanded(true,true)
local function enter()
 W.hover=UI.cells[4];UI.cells[4].scripts.OnEnter();W.advance(.751)
end
local function line(text,maximum)
 eq(#W.tooltip.lines,3);eq(W.tooltip.lines[3][1],text)
 local color=maximum and {1,.1,.1} or X.profile.rested
 for i=1,3 do eq(W.tooltip.lines[3][i+1],color[i]) end
end
enter();line('23.2% of max. rested XP',false)
eq(W.tooltip.lines[3][1]:find('approx',1,true),nil,'no qualifying tooltip copy')
-- Every committed rank changes the denominator, including while hovered.
W.rested=1500;W.cap=1000;W.xp=100;W.event('PLAYER_XP_UPDATE','player');W.advance(2.1)
for rank,maximum in ipairs({1500,1560,1620,1680,1740,1800}) do
 W.legacyRank=rank-1;W.event('TRAIT_CONFIG_UPDATED',42);W.advance(0)
 eq(X.restedMaximum,maximum,'commit refreshes capacity')
end
W.legacyRank=3;W.rested=1680;W.event('TRAIT_CONFIG_UPDATED',42);W.advance(0);line('Max',true)
W.rested=1679.999;W.event('UPDATE_EXHAUSTION');line('99.9% of max. rested XP',false)
-- Staged ranks cannot replace confirmed ranks. A new config cannot borrow them.
W.legacyStaged=true;W.legacyRank=5;W.event('TRAIT_NODE_CHANGED',110301);W.advance(0)
eq(X.restedMaximum,1680,'same-config preview retains committed denominator')
W.legacyConfig=43;W.event('TRAIT_CONFIG_LIST_UPDATED');W.advance(0)
eq(X.restedMaximum,nil);eq(#W.tooltip.lines,2,'new staged config is unavailable')
W.legacyStaged=false;W.legacyRank=2;W.event('TRAIT_CONFIG_UPDATED',43);W.advance(0)
eq(X.restedMaximum,1620);line('Max',true)
-- An unreadable commit invalidates the previous confirmed rank. A subsequent
-- preview cannot resurrect that old denominator before a new confirmation.
W.legacyRank=3;W.event('TRAIT_CONFIG_UPDATED',43);W.advance(0);eq(X.restedMaximum,1680)
W.legacyRank=5;W.legacyNodeUnavailable=true;W.event('TRAIT_CONFIG_UPDATED',43);W.advance(0)
eq(X.restedMaximum,nil);eq(X.restedTraitRank,nil)
W.legacyNodeUnavailable=false;W.legacyStaged=true;W.event('TRAIT_NODE_CHANGED',110301);W.advance(0)
eq(X.restedMaximum,nil,'preview cannot revive rank from before an unreadable commit')
W.legacyStaged=false;W.event('TRAIT_CONFIG_UPDATED',43);W.advance(0);eq(X.restedMaximum,1800)
-- Unrelated node bursts do not schedule XP sampling.
W.event('TRAIT_NODE_CHANGED',123);eq(X.samplePending,nil)
-- Invalid/restricted pool and rank data cannot produce a false Max or zero line.
local secret=setmetatable({},{__lt=function() error('restricted comparison') end,__mul=function() error('restricted arithmetic') end})
issecretvalue=function(v) return rawequal(v,secret) end
for _,bad in ipairs({secret,-1,math.huge,0/0,'5',false}) do
 W.legacyRank=bad;W.event('TRAIT_CONFIG_UPDATED',43);W.advance(0)
 eq(X.restedMaximum,nil);eq(#W.tooltip.lines,2)
end
W.legacyRank=0
for _,bad in ipairs({secret,-1,math.huge,0/0,'750',false}) do
 W.rested=bad;W.event('UPDATE_EXHAUSTION');eq(X.restedMaximum,nil);eq(#W.tooltip.lines,2)
end
W.rested=750;W.legacyConfig=secret;W.event('TRAIT_CONFIG_LIST_UPDATED');W.advance(0)
eq(X.restedMaximum,nil)
W.legacyConfig=43;W.legacyStaged=secret;W.event('TRAIT_CONFIG_UPDATED',43);W.advance(0)
eq(X.restedMaximum,nil);W.legacyStaged=false;issecretvalue=nil
W.rested=nil;W.event('UPDATE_EXHAUSTION');line('0.0% of max. rested XP',false)
-- Nil config alone is unknown; consistently locked Legacy is zero bonus.
W.legacyConfig=false;W.event('TRAIT_CONFIG_LIST_UPDATED');W.advance(0);eq(X.restedMaximum,nil)
local faction={isUnlocked=false,renownLevel=0};local renown=0
C_MajorFactions={GetMajorFactionData=function(id) assert(id==2802);return faction end,
 GetCurrentRenownLevel=function(id) assert(id==2802);return renown end}
W.event('MAJOR_FACTION_RENOWN_LEVEL_CHANGED',2802,0);W.advance(0)
eq(X.restedMaximum,1500);line('0.0% of max. rested XP',false)
for _,case in ipairs({{false,1,0},{true,0,0},{false,0,1}}) do
 faction.isUnlocked,faction.renownLevel,renown=case[1],case[2],case[3]
 W.event('MAJOR_FACTION_UNLOCKED',2802);W.advance(0);eq(X.restedMaximum,nil,'conflicting locked state is unknown')
end
-- Late data recovers on the existing shared clock; no new recurring timer.
W.legacyConfig=44;W.legacyRank=5;W.legacyNodeUnavailable=true;W.event('TRAIT_CONFIG_CREATED',{});W.advance(0)
eq(X.restedMaximum,nil);eq(X.restedPending,true)
W.legacyNodeUnavailable=false;W.advance(1.01);eq(X.restedMaximum,1800);eq(X.restedPending,nil)
-- Character cap is not rested Max. Level transitions use the next requirement.
W.capped=true;W.event('UPDATE_EXHAUSTION');eq(GameTooltip:IsShown(),false)
UI:ShowStatTooltip(UI.cells[4],4);eq(#W.tooltip.lines,2)
W.capped=false;W.event('PLAYER_LEVEL_UP',20);UI:ShowStatTooltip(UI.cells[4],4);eq(#W.tooltip.lines,2)
W.level=20;W.xp=0;W.cap=23200;W.rested=20880;W.event('PLAYER_XP_UPDATE','player');W.advance(2.1)
eq(X.restedMaximum,41760);enter();line('50.0% of max. rested XP',false)
local live=0;for _,t in ipairs(W.timers) do if not t.cancelled and t.repeatEvery then live=live+1 end end
eq(live,1,'only the existing shared ticker')
-- Optional immutable API checks, used by both CI workflows.
if arg[1] then
 local functions,tables={},{ }
 APIDocumentation={AddDocumentationTable=function(_,doc)
  for _,f in ipairs(doc.Functions or {}) do functions[f.Name]=f end
  for _,t in ipairs(doc.Tables or {}) do tables[t.Name]=t end
 end}
 for _,name in ipairs({'SharedTraits','MajorFactions','LegacyConstants'}) do
  assert(loadfile(arg[1]..'/Blizzard_APIDocumentationGenerated/'..name..'Documentation.lua'))()
 end
 eq(functions.GetConfigIDByTreeID.MayReturnNothing,true)
 eq(functions.GetNodeInfo.MayReturnNothing,true)
 eq(functions.ConfigHasStagedChanges.Returns[1].Type,'bool')
 eq(functions.GetCurrentRenownLevel.Returns[1].Type,'number')
 eq(functions.GetMajorFactionData.Returns[1].Nilable,true)
 local function field(t,key)
  local data=assert(tables[t])
  for _,f in ipairs(data.Fields or data.Values) do if f.Name==key then return f end end
  error('missing field '..t..'.'..key)
 end
 eq(field('TraitNodeInfo','activeRank').Type,'number')
 eq(field('MajorFactionData','isUnlocked').Type,'bool')
 eq(field('MajorFactionData','renownLevel').Type,'number')
 eq(field('LegacyConsts','LEGACY_TREE_ADVENTURE_ID').Value,1188)
 eq(field('LegacyConsts','LEGACY_REWARD_TRACK_FACTION_ID').Value,2802)
 APIDocumentation=nil
end
print('PASS: '..n..' rested capacity assertions (accepted approximation, sample replay, committed ranks, restricted values, loading recovery, live colors and rollover)')
