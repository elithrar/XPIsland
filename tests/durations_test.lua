local n=0
local function eq(a,b,why) n=n+1;assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
local function boot()
 XPIslandDB=nil;XPIslandSession=nil;XPIslandPlayed=nil
 local W=dofile('tests/wow_mock.lua');local ns=W.load()
 W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false);W.advance(0)
 W.open('behavior')
 return W,ns.owner,ns.UI,ns.Options,ns.Model
end
local W,X,UI,O,M=boot()
eq(X.profile.levelUpDuration,10);eq(X.profile.autoCollapseDuration,15)
for _,version in ipairs({1,2}) do
 local db=M.Database({version=version,profiles={Shared={levelUp=false,autoCollapse=false,position={x=21,y=-82}},Other={levelUpDuration=5,autoCollapseDuration=10}}})
 eq(db.profiles.Shared.levelUpDuration,10);eq(db.profiles.Shared.autoCollapseDuration,15)
 eq(db.profiles.Shared.levelUp,false);eq(db.profiles.Shared.autoCollapse,false)
 eq(db.profiles.Shared.position.x,21);eq(db.profiles.Shared.position.y,-82)
 eq(db.profiles.Other.levelUpDuration,5);eq(db.profiles.Other.autoCollapseDuration,10)
end
for _,bad in ipairs({0,7,20,'10',math.huge,0/0,false,{}}) do
 local p=M.Profile({levelUpDuration=bad,autoCollapseDuration=bad})
 eq(p.levelUpDuration,10);eq(p.autoCollapseDuration,15)
end
local function check(key) return W.control(key,'behavior') end
local function toggle(key,value) local b=check(key);b:SetChecked(value);b.scripts.OnClick(b) end
local function close() W.hover=nil;O.panel:Close();X:CancelAutoCollapse();UI:SetExpanded(false,true) end
local function showLevel(seconds)
 W.set('levelUpDuration',seconds);X.lastLevelEvent=11;X:LevelUp();X:PlayedLevelComplete(10,3600)
end
-- Native choices preserve discrete durations and enabled state. The old custom
-- sliders are replaced by SND select controls, without weakening timer semantics.
for _,entry in ipairs({{'levelUpDuration','levelUp'},{'autoCollapseDuration','autoCollapse'}})do
 local key,toggleKey=unpack(entry);local control=W.control(key,'behavior')
 for _,seconds in ipairs({5,10,15})do W.choose(control,seconds);eq(X.profile[key],seconds)end
 toggle(toggleKey,false);eq(control:IsEnabled(),false)
 eq(W.ns.App:Set(key,11),false,'non-discrete duration is rejected')
 toggle(toggleKey,true);eq(control:IsEnabled(),true)
end
-- Profile commands preserve duration settings and do not alias saved profiles.
W.patch({levelUpDuration=5,autoCollapseDuration=10});assert(W.ns.App.profiles:Duplicate('Copy'))
eq(XPIslandDB.profiles.Copy.levelUpDuration,5)
W.patch({levelUpDuration=15,autoCollapseDuration=5});O:Switch('Shared')
eq(X.profile.levelUpDuration,5);eq(X.profile.autoCollapseDuration,10)
local panel=W.open('profiles');W.choose(panel._pool['profile-copy'],'Copy')
W.click(panel._pool['profile-copy-button']);W.click(panel._pool['profile-confirm'])
eq(X.profile.levelUpDuration,15);eq(X.profile.autoCollapseDuration,5)
local restored=M.Database(M.Copy(XPIslandDB));eq(restored.profiles.Shared.levelUpDuration,15);eq(restored.profiles.Shared.autoCollapseDuration,5)
-- Every manual timeout, including fresh intervals after hover/settings/drag.
for _,seconds in ipairs({5,10,15}) do
 close();W.set('autoCollapse',true);W.set('autoCollapseDuration',seconds);X:Toggle()
 eq(X.collapseDelay,seconds);W.advance(seconds-.01);eq(UI.expanded,true);W.advance(.02);eq(UI.expanded,false)
 X:Toggle();W.advance(1);W.hover=UI.frame;X:InteractionChanged();W.advance(20);eq(UI.expanded,true)
 W.hover=nil;X:InteractionChanged();W.advance(seconds-.01);eq(UI.expanded,true);W.advance(.02);eq(UI.expanded,false)
 X:Toggle();W.open();W.advance(20);eq(UI.expanded,true);O.panel:Close()
 W.advance(seconds+.01);eq(UI.expanded,false)
 X:Toggle();UI.dragging=true;X:InteractionChanged();W.advance(20);eq(UI.expanded,true)
 UI.dragging=nil;X:InteractionChanged();W.advance(seconds+.01);eq(UI.expanded,false)
end
-- Level-up preview and authoritative header share the chosen level duration,
-- independent of manual auto-collapse setting. ETA and cell hover are unchanged.
for _,seconds in ipairs({5,10,15}) do
 close();W.set('levelUp',true);W.set('autoCollapse',false);showLevel(seconds)
 eq(X.collapseDelay,seconds);eq(X.collapseKind,'level');eq(UI.levelText:IsShown(),true)
 eq(UI.cells[3].title:GetText(),'Time to level')
 W.hover=UI.frame;X:InteractionChanged()
 W.advance(seconds-.01);eq(X.levelNotice~=nil,true);W.advance(.02)
 eq(X.levelNotice,nil);eq(UI.bar:IsShown(),true);eq(UI.expanded,true,'hover delays collapse, not header expiry')
 W.hover=nil;X:InteractionChanged();W.advance(seconds+.01);eq(UI.expanded,false)
 close();showLevel(seconds);W.advance(seconds+.01);eq(UI.expanded,false);eq(X.levelNotice,nil)
 close();X.lastLevelEvent=12;X:LevelUp();W.advance(seconds-.1);X:PlayedLevelComplete(11,7200)
 W.advance(seconds-.01);eq(UI.levelText:IsShown(),true,'late authoritative arrival gets selected duration')
 W.advance(.02);eq(X.levelNotice,nil);eq(UI.expanded,false)
end
-- Different values for the two enabled controls never exchange timer ownership.
for _,levelSeconds in ipairs({5,10,15}) do
 for _,manualSeconds in ipairs({5,10,15}) do
  close();W.set('autoCollapse',true);W.set('autoCollapseDuration',manualSeconds);showLevel(levelSeconds)
  X:ApplyProfile();eq(X.collapseKind,'level');eq(X.collapseDelay,levelSeconds)
  X:Toggle();X:Toggle();eq(X.collapseKind,'manual');eq(X.collapseDelay,manualSeconds)
 end
end
-- Reconfiguring active notices preserves elapsed display time; stale callbacks
-- cannot clear a replacement timer. Ordinary appearance changes do not reset it.
close();showLevel(15);W.hover=UI.frame;X:InteractionChanged();W.advance(3)
local notice=X.levelNotice;local stale=X.levelNoticeTimer
W.set('levelUpDuration',10);X:ApplyProfile();eq(X.levelNotice,notice);eq(X.collapseDelay,10)
stale.callback();eq(X.levelNotice,notice,'cancelled timer identity guarded')
W.advance(2);W.set('fontSize',18);X:ApplyProfile();W.advance(4.9);eq(X.levelNotice,notice)
W.advance(.2);eq(X.levelNotice,nil,'changing settings does not restart header clock')
close();showLevel(15);W.hover=UI.frame;W.advance(7);W.set('levelUpDuration',5);X:ApplyProfile()
eq(X.levelNotice,nil,'shorter duration expires immediately if already elapsed');eq(UI.bar:IsShown(),true)
close();showLevel(5);W.hover=UI.frame;W.advance(2);W.set('levelUpDuration',15);X:ApplyProfile()
W.advance(12.9);eq(X.levelNotice~=nil,true);W.advance(.2);eq(X.levelNotice,nil)
-- Replaced manual timeout callbacks cannot collapse the new interval.
close();W.set('autoCollapse',true);W.set('autoCollapseDuration',5);X:Toggle()
local oldCollapse=X.autoCollapse;W.advance(2);W.set('autoCollapseDuration',15);X:ApplyProfile()
oldCollapse.callback();eq(UI.expanded,true);W.advance(14.9);eq(UI.expanded,true);W.advance(.2);eq(UI.expanded,false)
-- Toggle-off clears its owned timer/notice without changing retained value.
close();W.set('autoCollapse',false);showLevel(15);toggle('levelUp',false);eq(X.levelNotice,nil);eq(X.levelWindow,nil);eq(X.autoCollapse,nil)
eq(X.profile.levelUpDuration,15);toggle('levelUp',true)
close();W.set('autoCollapse',true);X:Toggle();toggle('autoCollapse',false);eq(X.autoCollapse,nil)
W.advance(20);eq(UI.expanded,true);toggle('autoCollapse',true)
-- Combat, cap, repeated level-ups, session reset, and exact 750ms tooltip dwell.
close();showLevel(5);local old=X.levelNoticeTimer;W.advance(2);showLevel(15);old.callback();eq(X.levelNotice~=nil,true)
SlashCmdList.XPISLAND_SND_XPISLAND('reset');eq(X.profile.levelUpDuration,15);eq(X.levelNotice~=nil,true)
W.combat=true;W.event('PLAYER_REGEN_DISABLED');eq(X.levelNotice,nil);eq(X.autoCollapse,nil);eq(UI.expanded,false)
W.combat=false;showLevel(5);W.capped=true;X:Sample();eq(X.levelNotice,nil);eq(UI.frame:IsShown(),false)
W.capped=false;X:Sample();UI:SetExpanded(true,true);W.hover=UI.cells[3];UI.cells[3].scripts.OnEnter()
W.advance(.749);eq(GameTooltip:IsShown(),false);W.advance(.002);eq(GameTooltip:IsShown(),true)
UI.cells[3].scripts.OnLeave();close()
-- Shared scrolling options remain contained at small viewports with long text.
for _,font in ipairs({'Game tooltip','Arial','Friz Quadrata','Missing custom font'}) do
 for _,size in ipairs({10,14,18}) do
  for _,viewport in ipairs({{320,180},{900,600},{1728,1080}}) do
   UIParent:SetSize(unpack(viewport));W.patch({font=font,fontSize=size});W.open('behavior');O:Refresh()
   local x,y,w,h=O.frame:Rect()
   eq(x>=0 and x+w<=viewport[1],true,'options fit viewport width')
   eq(y>=0 and y+h<=viewport[2],true,'options fit viewport height')
   for _,key in ipairs({'levelUpDuration','autoCollapseDuration'})do
    local control=W.control(key,'behavior')
    eq(control.Text:GetText(),X.profile[key]..' seconds','selected duration remains visible')
   end
  end
 end
end
UIParent:SetSize(1728,1080);assert(W.ns.App.profiles:Reset());W.open('behavior');W.svg('dist/preview-durations-052.svg',O.frame)
toggle('levelUp',false);toggle('autoCollapse',false);W.svg('dist/preview-durations-disabled-052.svg',O.frame)
print('PASS: '..n..' duration assertions (migration, controls, profiles, deadlines, cleanup, hover and layout)')
