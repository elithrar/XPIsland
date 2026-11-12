-- Real event/settings/UI paths; no native renderer or secret-value engine.
local W=dofile('tests/wow_mock.lua')
local secret=setmetatable({},{__tostring=function()error('restricted value formatted')end})
function issecretvalue(v)return rawequal(v,secret)end
local watched,friend,friendAbsent,major,maximum,paragon,pending,earned,threshold
C_Reputation={
 GetWatchedFactionData=function()return watched end,
 IsFactionParagonForCurrentPlayer=function()return paragon or false end,
 IsMajorFaction=function()return major~=nil end,
 GetFactionParagonInfo=function()return earned,threshold,1,pending end,
}
C_GossipInfo={GetFriendshipReputation=function()
 if friendAbsent then return end
 return friend or {friendshipFactionID=0}
end}
C_MajorFactions={GetMajorFactionData=function()return major end,HasMaximumRenown=function()return maximum end}
for i,name in ipairs({'Hated','Hostile','Unfriendly','Neutral','Friendly','Honored','Revered','Exalted'})do _G['FACTION_STANDING_LABEL'..i]=name end
local ns=W.load();local X,UI,P,M=ns.owner,ns.UI,ns.Progression,ns.Model
local n=0
local function eq(a,b,why)n=n+1;assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b))end
local function near(a,b) n=n+1;assert(math.abs(a-b)<.0001)end
local function faction(id,name,reaction,low,high,value)
 return {factionID=id,name=name,reaction=reaction,currentReactionThreshold=low,nextReactionThreshold=high,currentStanding=value}
end
local function update()W.event('UPDATE_FACTION')end
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false)
W.open('tracking');W.choose(W.control('mode','tracking'),'reputation')
eq(X:Mode(),'reputation');eq(UI.frame:IsShown(),true);eq(UI.expanded,false)
eq(P.reputationState,'none');eq(UI.label:GetText(),'Rep · Select faction')
UI:ShowBarTooltip();assert(W.tooltip.lines[2][1]:find('Show as Experience Bar',1,true))
-- The native checkbox updates the watched faction and sends UPDATE_FACTION.
watched=faction(72,'Stormwind',5,3000,9000,4500);update()
eq(P.reputation.name,'Stormwind');eq(P.reputation.xp,1500);eq(P.reputation.cap,6000);eq(P.reputation.left,4500)
near(UI.barFraction,.25);eq(UI.label:GetText(),'Rep · 25.0%');eq(UI.restedFraction,0)
X:Toggle();W.advance(.3)
eq(UI.cells[1].value:GetText(),'Stormwind');eq(UI.cells[2].value:GetText(),'Friendly')
eq(UI.cells[3].value:GetText(),'1.5K / 6K');eq(UI.cells[4].value:GetText(),'4.5K')
eq(UI.cells[5]:IsShown(),false);eq(UI.inlineCells[2]:IsShown(),false);eq(UI.inlineCells[3]:IsShown(),false)
local totals=X.session.total
W.hover=UI.indicator;UI:ShowBarTooltip()
watched=faction(76,'Orgrimmar',3,-3000,0,-1500);update()
eq(P.reputation.id,76);near(UI.barFraction,.5);eq(UI.cells[2].value:GetText(),'Unfriendly')
assert(W.tooltip.lines[2][1]:find('Orgrimmar',1,true),'hover changes with watched faction')
eq(X.session.total,totals,'reputation never changes XP accounting')
watched.currentStanding=-2000;update();near(UI.barFraction,1/3)
watched.currentStanding=0;watched.currentReactionThreshold=0;watched.nextReactionThreshold=3000;watched.reaction=4;update()
eq(UI.label:GetText(),'Rep · 0.0%');eq(UI.cells[4].value:GetText(),'3K')
W.choose(W.control('reputationFormat','tracking'),'fraction');eq(UI.label:GetText(),'0 / 3K Rep')
W.choose(W.control('reputationFormat','tracking'),'left');eq(UI.label:GetText(),'3K Rep left')
W.xp=W.xp+100;W.event('PLAYER_XP_UPDATE','player');W.advance(0)
eq(X.session.total,totals+100,'XP gains still count while reputation is displayed')
eq(UI.label:GetText(),'3K Rep left','XP events do not replace the watched reputation')
-- Explicit reputation wins at player cap, even with the optional XP-to-PvP policy.
W.level=60;W.cap=0;W.set('pvpAtCap',true);X:Sample()
eq(X:Mode(),'reputation');eq(UI.frame:IsShown(),true)
watched=faction(72,'Stormwind',8,42000,42000,42000);update()
eq(UI.barFraction,1);eq(UI.label:GetText(),'Rep · Maximum');eq(UI.cells[4].value:GetText(),'—')
UI:ShowBarTooltip();eq(W.tooltip.lines[3][1],'Maximum reputation reached.')
-- Clearing the checkbox clears old data while keeping an actionable mode visible.
watched=nil;update();eq(P.reputation,nil);eq(P.reputationState,'none');eq(UI.barFraction,0);eq(UI.frame:IsShown(),true)
eq(UI.cells[1].value:GetText(),'Select faction')
watched={factionID=0};update();eq(P.reputationState,'none')
-- Missing and restricted fields must not retain the previous faction snapshot.
local good=faction(72,'Stormwind',5,3000,9000,4500)
for _,field in ipairs({'factionID','name','reaction','currentReactionThreshold','nextReactionThreshold','currentStanding'})do
 watched=M.Copy(good);update();watched[field]=secret;update();eq(P.reputation,nil,'restricted '..field)
 eq(P.reputationState,'unavailable');eq(UI.label:GetText(),'Rep · —');eq(UI.barFraction,0)
end
for _,bad in ipairs({0/0,math.huge,-math.huge,'123'})do
 watched=M.Copy(good);watched.currentStanding=bad;update();eq(P.reputation,nil)
end
watched=secret;update();eq(P.reputation,nil)
watched=M.Copy(good);watched.currentStanding=2999;update();eq(P.reputation,nil)
watched=M.Copy(good);watched.nextReactionThreshold=0;update();eq(P.reputation,nil)
watched=M.Copy(good);paragon=secret;update();eq(P.reputation,nil);paragon=false
-- The pinned friendship API may return nothing; ordinary faction data still
-- remains authoritative, as in the client's reputation panel type resolver.
watched=M.Copy(good);friendAbsent=true;update()
eq(P.reputationState,'ready','no friendship result does not discard ordinary reputation')
eq(P.reputation.xp,1500);near(UI.barFraction,.25)
friendAbsent=false;friend=secret;update();eq(P.reputation,nil,'restricted friendship is not absence');friend=nil
-- Special factions use their own progression rather than ordinary thresholds.
watched=M.Copy(good);major={renownLevel=3,renownLevelThreshold=1000,renownReputationEarned=600};maximum=false
W.event('MAJOR_FACTION_RENOWN_LEVEL_CHANGED',72)
near(UI.barFraction,.6);eq(P.reputation.standing,'Renown 3');eq(P.reputation.left,400)
major.renownLevelThreshold=0;major.renownReputationEarned=0;maximum=true;update();eq(UI.barFraction,1)
maximum=secret;update();eq(P.reputation,nil);major=nil;maximum=nil
friend={friendshipFactionID=72,reaction='Good friend',reactionThreshold=500,nextThreshold=1000,standing=750};update()
near(UI.barFraction,.5);eq(P.reputation.standing,'Good friend')
friend.nextThreshold=nil;update();eq(UI.barFraction,1)
friend.nextThreshold=secret;update();eq(P.reputation,nil);friend=nil
paragon=true;earned=12500;threshold=10000;pending=false;update();near(UI.barFraction,.25);eq(P.reputation.left,7500)
pending=true;update();eq(UI.barFraction,1);eq(UI.label:GetText(),'Rep · Reward ready');eq(P.reputation.left,0)
threshold=0;update();eq(P.reputation,nil)
threshold=secret;update();eq(P.reputation,nil)
paragon=false
-- Full names remain in hovers while cells retain their chosen text size.
watched=M.Copy(good);watched.name='Les défenseurs de la très ancienne cité de Stormwind';update()
ns.Options.panel:Close();UIParent:SetSize(800,600);W.set('fontSize',18);UI:SetExpanded(true,true)
eq(UI.cells[1].valueScale,1);assert(UI.cells[1].value:GetText():find('…',1,true))
UI:ShowStatTooltip(UI.cells[1],1);assert(W.tooltip.lines[2][1]:find(watched.name,1,true))
W.svg('dist/preview-reputation.svg',UI.frame)
local count=#W.objects
for i=1,100 do watched.currentStanding=4000+i;update()end
eq(#W.objects,count,'updates reuse UI objects');eq(UI.frame.scripts.OnUpdate,nil)
local timers=0;for _,timer in ipairs(W.timers)do if not timer.cancelled and timer.repeatEvery then timers=timers+1 end end
eq(timers,1,'existing ticker only')
-- World entry refreshes selection; profiles and reload preserve mode/format,
-- not the runtime faction (the client owns that character-specific choice).
watched=M.Copy(good);watched.name='Ironforge';W.event('PLAYER_ENTERING_WORLD',false,false);W.advance(0)
eq(P.reputation.name,'Ironforge')
local saved=M.Copy(XPIslandDB)
eq(M.Database(saved).profiles.Shared.mode,'reputation');eq(saved.profiles.Shared.reputationFormat,'left')
assert(ns.App.profiles:Duplicate('Rep copy'));eq(X.profile.mode,'reputation');eq(X.profile.reputationFormat,'left')
W.set('mode','xp');eq(UI.frame:IsShown(),false);ns.Options:Switch('Shared');eq(X:Mode(),'reputation');eq(UI.frame:IsShown(),true)
local W2=dofile('tests/wow_mock.lua');local ns2=W2.load()
W2.event('ADDON_LOADED','XPIsland');W2.event('PLAYER_ENTERING_WORLD',true,false)
eq(ns2.owner:Mode(),'reputation');eq(ns2.owner.profile.reputationFormat,'left');eq(ns2.Progression.reputation.name,'Ironforge')
eq(M.Profile({mode='bad',reputationFormat='bad'}).mode,'xp');eq(M.Profile({}).reputationFormat,'percent')
C_Reputation=nil;ns2.Progression:Reputation();ns2.UI:Update();eq(ns2.Progression.reputation,nil);eq(ns2.UI.frame:IsShown(),true)
if arg[1] then
 local functions,structs={},{}
 APIDocumentation={AddDocumentationTable=function(_,doc)
  for _,f in ipairs(doc.Functions or {})do functions[f.Name]=f end
  for _,t in ipairs(doc.Tables or {})do structs[t.Name]=t end
 end}
 for _,name in ipairs({'ReputationInfo','GossipInfo','MajorFactions'})do
  assert(loadfile(arg[1]..'/Blizzard_APIDocumentationGenerated/'..name..'Documentation.lua'))()
 end
 eq(functions.GetWatchedFactionData.Returns[1].Type,'FactionData');eq(functions.GetWatchedFactionData.Returns[1].Nilable,true)
 eq(functions.GetFriendshipReputation.MayReturnNothing,true)
 eq(functions.GetFactionParagonInfo.Returns[4].Name,'hasRewardPending')
 eq(functions.HasMaximumRenown.Returns[1].Type,'bool')
 local fields={};for _,f in ipairs(structs.FactionData.Fields)do fields[f.Name]=f.Type end
 for _,f in ipairs({'currentReactionThreshold','nextReactionThreshold','currentStanding','factionID'})do eq(fields[f],'number')end
 local file=assert(io.open(arg[1]..'/Blizzard_UIPanels_Game/Camelot/ReputationFrame.lua'));local source=file:read('*a');file:close()
 assert(source:find('C_Reputation.SetWatchedFactionByIndex(self:GetChecked() and C_Reputation.GetSelectedFaction() or 0)',1,true))
 assert(source:find('"UPDATE_FACTION"',1,true))
end
print('PASS: '..n..' watched reputation assertions (settings, events, thresholds, special factions, caps, reload and restricted data)')
