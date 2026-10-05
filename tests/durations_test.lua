local n=0
local function eq(a,b,why) n=n+1;assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
local function boot()
 XPIslandDB=nil;XPIslandSession=nil;XPIslandPlayed=nil
 local W=dofile('tests/wow_mock.lua');local ns=W.load()
 W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false);W.advance(0)
 ns.Options:Create(ns.owner)
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
local function check(key) for _,b in ipairs(O.checks) do if b.key==key then return b end end end
local function toggle(key,value) local b=check(key);b:SetChecked(value);b.scripts.OnClick() end
local function close() W.hover=nil;O.frame:Hide();X:CancelAutoCollapse();UI:SetExpanded(false,true) end
local function showLevel(seconds)
 X.profile.levelUpDuration=seconds;X.lastLevelEvent=11;X:LevelUp();X:PlayedLevelComplete(10,3600)
end
-- Entry-point controls, default positions, discrete choices and disabled behavior.
for key,slider in pairs(O.durationSliders) do
 eq(slider.minimum,5);eq(slider.maximum,15);eq(slider.step,5);eq(slider.obeyStep,true)
 eq(slider:GetHeight()-slider.hitInsets[3]-slider.hitInsets[4]<28,true,'native hit rectangles cannot overlap neighboring rows')
 eq(slider.value,X.profile[key]);eq(slider.valueText:GetText(),X.profile[key]..' s')
 eq(check(slider.toggle).caption,slider.toggle=='levelUp' and 'Expand at level-up' or 'Auto-collapse')
 for _,v in ipairs({5,10,15}) do slider:SetValue(v);eq(X.profile[key],v);eq(slider.valueText:GetText(),v..' s') end
 slider:SetValue(11);eq(X.profile[key],10);eq(slider.value,10)
 toggle(slider.toggle,false);eq(slider:IsEnabled(),false);eq(slider.alpha,.35)
 slider:SetValue(5);eq(X.profile[key],10,'disabled input cannot change saved value')
 O:Refresh();eq(slider.value,10)
 toggle(slider.toggle,true);eq(slider:IsEnabled(),true);eq(slider.alpha,1);eq(slider.value,10)
end
-- Profiles duplicate/copy/switch and reload preserve duration settings.
X.profile.levelUpDuration=5;X.profile.autoCollapseDuration=10
M.Duplicate(X.db,'Shared','Copy');eq(X.db.profiles.Copy.levelUpDuration,5)
O:Switch('Copy');X.profile.levelUpDuration=15;X.profile.autoCollapseDuration=5
O:Switch('Shared');eq(O.durationSliders.levelUpDuration.value,5);eq(O.durationSliders.autoCollapseDuration.value,10)
O.copySource='Copy';O.copyButton.scripts.OnClick();O.copyButton.scripts.OnClick()
eq(X.profile.levelUpDuration,15);eq(X.profile.autoCollapseDuration,5)
local restored=M.Database(M.Copy(X.db));eq(restored.profiles.Shared.levelUpDuration,15);eq(restored.profiles.Shared.autoCollapseDuration,5)
-- Every manual timeout, including fresh intervals after hover/settings/drag.
for _,seconds in ipairs({5,10,15}) do
 close();X.profile.autoCollapse=true;X.profile.autoCollapseDuration=seconds;X:Toggle()
 eq(X.collapseDelay,seconds);W.advance(seconds-.01);eq(UI.expanded,true);W.advance(.02);eq(UI.expanded,false)
 X:Toggle();W.advance(1);W.hover=UI.frame;X:InteractionChanged();W.advance(20);eq(UI.expanded,true)
 W.hover=nil;X:InteractionChanged();W.advance(seconds-.01);eq(UI.expanded,true);W.advance(.02);eq(UI.expanded,false)
 X:Toggle();O.frame:Show();W.advance(20);eq(UI.expanded,true);O.frame:Hide()
 W.advance(seconds+.01);eq(UI.expanded,false)
 X:Toggle();UI.dragging=true;X:InteractionChanged();W.advance(20);eq(UI.expanded,true)
 UI.dragging=nil;X:InteractionChanged();W.advance(seconds+.01);eq(UI.expanded,false)
end
-- Level-up preview and authoritative header share the chosen level duration,
-- independent of manual auto-collapse setting. ETA and cell hover are unchanged.
for _,seconds in ipairs({5,10,15}) do
 close();X.profile.levelUp=true;X.profile.autoCollapse=false;showLevel(seconds)
 eq(X.collapseDelay,seconds);eq(X.collapseKind,'level');eq(UI.levelText:IsShown(),true)
 eq(UI.cells[3].title:GetText(),'Time to Level')
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
  close();X.profile.autoCollapse=true;X.profile.autoCollapseDuration=manualSeconds;showLevel(levelSeconds)
  X:ApplyProfile();eq(X.collapseKind,'level');eq(X.collapseDelay,levelSeconds)
  X:Toggle();X:Toggle();eq(X.collapseKind,'manual');eq(X.collapseDelay,manualSeconds)
 end
end
-- Reconfiguring active notices preserves elapsed display time; stale callbacks
-- cannot clear a replacement timer. Ordinary appearance changes do not reset it.
close();showLevel(15);W.hover=UI.frame;X:InteractionChanged();W.advance(3)
local notice=X.levelNotice;local stale=X.levelNoticeTimer
X.profile.levelUpDuration=10;X:ApplyProfile();eq(X.levelNotice,notice);eq(X.collapseDelay,10)
stale.callback();eq(X.levelNotice,notice,'cancelled timer identity guarded')
W.advance(2);X.profile.fontSize=18;X:ApplyProfile();W.advance(4.9);eq(X.levelNotice,notice)
W.advance(.2);eq(X.levelNotice,nil,'changing settings does not restart header clock')
close();showLevel(15);W.hover=UI.frame;W.advance(7);X.profile.levelUpDuration=5;X:ApplyProfile()
eq(X.levelNotice,nil,'shorter duration expires immediately if already elapsed');eq(UI.bar:IsShown(),true)
close();showLevel(5);W.hover=UI.frame;W.advance(2);X.profile.levelUpDuration=15;X:ApplyProfile()
W.advance(12.9);eq(X.levelNotice~=nil,true);W.advance(.2);eq(X.levelNotice,nil)
-- Replaced manual timeout callbacks cannot collapse the new interval.
close();X.profile.autoCollapse=true;X.profile.autoCollapseDuration=5;X:Toggle()
local oldCollapse=X.autoCollapse;W.advance(2);X.profile.autoCollapseDuration=15;X:ApplyProfile()
oldCollapse.callback();eq(UI.expanded,true);W.advance(14.9);eq(UI.expanded,true);W.advance(.2);eq(UI.expanded,false)
-- Toggle-off clears its owned timer/notice without changing retained value.
close();X.profile.autoCollapse=false;showLevel(15);toggle('levelUp',false);eq(X.levelNotice,nil);eq(X.levelWindow,nil);eq(X.autoCollapse,nil)
eq(X.profile.levelUpDuration,15);toggle('levelUp',true)
close();X.profile.autoCollapse=true;X:Toggle();toggle('autoCollapse',false);eq(X.autoCollapse,nil)
W.advance(20);eq(UI.expanded,true);toggle('autoCollapse',true)
-- Combat, cap, repeated level-ups, session reset, and exact 750ms tooltip dwell.
close();showLevel(5);local old=X.levelNoticeTimer;W.advance(2);showLevel(15);old.callback();eq(X.levelNotice~=nil,true)
SlashCmdList.XPISLAND('reset');eq(X.profile.levelUpDuration,15);eq(X.levelNotice~=nil,true)
W.combat=true;W.event('PLAYER_REGEN_DISABLED');eq(X.levelNotice,nil);eq(X.autoCollapse,nil);eq(UI.expanded,false)
W.combat=false;showLevel(5);W.capped=true;X:Sample();eq(X.levelNotice,nil);eq(UI.frame:IsShown(),false)
W.capped=false;X:Sample();UI:SetExpanded(true,true);W.hover=UI.cells[3];UI.cells[3].scripts.OnEnter()
W.advance(.749);eq(GameTooltip:IsShown(),false);W.advance(.002);eq(GameTooltip:IsShown(),true)
UI.cells[3].scripts.OnLeave();close()
-- Settings layout: labels, sliders and values stay separated within the same rows.
for _,font in ipairs({'Game tooltip','Arial','Friz Quadrata','Missing custom font'}) do
 for _,size in ipairs({10,14,18}) do
  for _,viewport in ipairs({{320,180},{900,600},{1728,1080}}) do
   UIParent:SetSize(unpack(viewport));X.profile.font=font;X.profile.fontSize=size;O.frame:Show();O:Refresh()
   for _,slider in pairs(O.durationSliders) do
    local b=check(slider.toggle);local bx,_,bw=b.text:Rect();local sx,_,sw=slider:Rect();local vx,_,vw=slider.valueText:Rect()
    local fx,_,fw=O.frame:Rect()
    eq(bx+bw<sx,true,'caption cannot overlap slider');eq(sx+sw<vx,true,'slider/value separation')
    local tx,_,tw=slider:GetThumbTexture():Rect();eq(tx>bx+bw and tx+tw<vx,true,'thumb clears label and value');eq(vx+vw<fx+fw,true,'value inside panel')
    eq(b.text:GetUnboundedStringWidth()<=b.text:GetWidth(),true,'caption fits selected font')
    eq(slider.valueText:GetUnboundedStringWidth()<=slider.valueText:GetWidth(),true,'seconds fit')
   end
  end
 end
end
UIParent:SetSize(1728,1080);X.profile=M.Profile();O:Refresh();W.svg('dist/preview-durations-052.svg',O.frame)
toggle('levelUp',false);toggle('autoCollapse',false);W.svg('dist/preview-durations-disabled-052.svg',O.frame)
print('PASS: '..n..' duration assertions (migration, sliders, profiles, deadlines, cleanup, hover and layout)')
