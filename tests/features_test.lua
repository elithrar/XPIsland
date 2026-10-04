-- Four feature regression tests use actual addon callbacks under the WoW double.
local n=0
local function eq(a,b,why) n=n+1;assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,why) n=n+1;assert(math.abs(a-b)<.00001,(why or 'near')..': '..a..' ~= '..b) end
local function boot()
 XPIslandDB=nil;XPIslandSession=nil
 local W=dofile('tests/wow_mock.lua');local ns=W.load()
 W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false);W.advance(0)
 ns.owner.profile.autoCollapse=false
 return W,ns.owner,ns.UI,ns.Model
end
local W,X,UI,M=boot()
local function flashes()
 local count=0;for _ in pairs(UI.flashes) do count=count+1 end;return count
end
-- Completion pulses: exact thresholds, positive gains only, no repaint pulses.
eq(flashes(),0,'login does not pulse');eq(UI.flashDriver.scripts.OnUpdate,nil)
W.xp=149;X:Sample();eq(flashes(),0,'partial segment does not pulse')
W.xp=150;X:Sample();eq(flashes(),1);eq(UI.flashes[3],0)
near(UI.segments[3].flash.alpha,.18);W.advance(.1);local age=UI.flashes[3]
W.xp=151;X:Sample();near(UI.flashes[3],age,'within-segment gain does not restart pulse')
UI:Update();UI:PaintBar(true);near(UI.flashes[3],age,'repaint does not restart pulse')
W.advance(.151);eq(flashes(),0);eq(UI.flashDriver.scripts.OnUpdate,nil)
W.xp=365;X:Sample();eq(flashes(),4,'large gain completes four segments simultaneously')
for i=4,7 do eq(UI.flashes[i],0) end
UI:SetExpanded(true);W.advance(.05)
eq(flashes(),4,'drawer animation does not strand or restart highlights')
local width=UI.segments[7].width;near(UI.segments[7].flash.drawWidth,width)
W.advance(.3);eq(flashes(),0);eq(UI.flashDriver.scripts.OnUpdate,nil);eq(UI.frame.scripts.OnUpdate,nil)
W.rested=225;W.event('UPDATE_EXHAUSTION');eq(flashes(),0,'rested change does not pulse')
-- Repeated update/correction/load and rollover baselines cannot fake gains.
W.xp=400;X:Sample();eq(flashes(),1);UI.frame:Hide();eq(flashes(),0);eq(UI.flashDriver.scripts.OnUpdate,nil)
UI.frame:Show();W.xp=450;X:Sample();eq(flashes(),1);X:ApplyProfile();eq(flashes(),0)
W.xp=500;X:Sample();eq(flashes(),1);W.event('LOADING_SCREEN_ENABLED');eq(flashes(),0)
W.xp=550;W.advance(.3);W.event('LOADING_SCREEN_DISABLED');W.advance(.01);eq(flashes(),0,'loading restoration suppressed')
W.xp=0;X:Sample();W.xp=550;X:Sample();eq(flashes(),0,'transient XP zero restored without pulse')
W.xp=575;X:Sample();eq(flashes(),0)
W.level=11;W.xp=50;W.cap=1200;W.event('PLAYER_LEVEL_UP',11);W.advance(2.1)
eq(flashes(),0,'rollover never highlights the reset bar')
W.event('PLAYER_LEVEL_UP',11);eq(flashes(),0)
-- Ghost preview is behind opaque earned fill, bounded by the level and gaps.
W,X,UI,M=boot();W.xp=375;W.rested=225;X:Sample();UI:ClearHighlights()
near(UI.barFraction,.375);near(UI.restedFraction,.6)
near(UI.segments[8].fill.drawAmount,.5);near(UI.segments[8].preview.drawAmount,1)
near(UI.segments[12].preview.drawAmount,1);eq(UI.segments[13].preview:IsShown(),false)
for _,s in ipairs(UI.segments) do
 eq(s.track:GetFrameLevel()<s.preview:GetFrameLevel(),true)
 eq(s.preview:GetFrameLevel()<s.fill:GetFrameLevel(),true)
 near(s.preview.drawWidth or s.width,s.width)
end
near(UI.previewB,.18+(1-.18)*.28,'muted configurable rested color')
W.rested=2000;W.event('UPDATE_EXHAUSTION');near(UI.restedFraction,1)
eq(UI.cells[4].value:GetText(),M.Compact(2000),'numeric overflow is preserved')
near(UI.segments[20].preview.drawAmount,1)
X.profile.rested={.9,.2,.1};UI:Layout();near(UI.previewR,.14+(.9-.14)*.28)
near(UI.segments[1].fill.body.color[1],.9,'solid earned uses configured rested color')
W.rested=nil;W.event('UPDATE_EXHAUSTION');eq(UI.restedFraction,0);eq(UI.cells[4].value:GetText(),'—')
for _,s in ipairs(UI.segments) do eq(s.preview:IsShown(),false) end
near(UI.segments[1].fill.body.color[1],X.profile.normal[1])
W.rested=100;W.xp=0;X.tracker:Baseline(10,0,1000);X:Sample()
near(UI.restedFraction,.1);eq(UI.segments[1].fill:IsShown(),false);eq(UI.segments[1].preview:IsShown(),true)
W.rested=1;W.xp=999;X.tracker:Baseline(10,999,1000);X:Sample()
near(UI.segments[20].preview.drawAmount,1);near(UI.segments[20].fill.drawAmount,.98)
-- Source shares use one denominator and respond to delayed attribution.
W,X,UI,M=boot();UI:SetExpanded(true,true)
for i=5,8 do eq(UI.cells[i].shareFraction,0);eq(UI.cells[i].shareFill:IsShown(),false) end
W.xp=200;X:Sample();near(UI.cells[8].shareFraction,1)
X.tracker:Hint('kills',100,'none',GetTime(),'first');X:Sample()
near(UI.cells[5].shareFraction,1);near(UI.cells[8].shareFraction,0)
W.instance='party';W.xp=500;X:Sample();X.tracker:Hint('kills',300,'party',GetTime(),'second');X:Sample()
near(UI.cells[5].shareFraction,.25);near(UI.cells[7].shareFraction,.75);near(UI.cells[8].shareFraction,0)
local total=0;for i=5,8 do total=total+UI.cells[i].shareFraction end;near(total,1)
W.instance='none';W.xp=600;X:Sample();X.tracker:Hint('quests',100,'none',GetTime(),'third');X:Sample()
near(UI.cells[6].shareFraction,.2);near(UI.cells[7].shareFraction,.6)
-- Layout: all fills fit beneath measured values at every supported font/scale.
for _,font in ipairs({'Game tooltip','Arial','Friz Quadrata','Missing custom font'}) do
 for _,size in ipairs({10,12,14,18}) do
  for _,scale in ipairs({.5,1,1.5}) do
   for _,placement in ipairs({'top','bottom','custom'}) do
    for _,viewport in ipairs({{320,180},{900,600},{1728,1080},{2560,1440}}) do
     UIParent:SetSize(unpack(viewport));X.profile.font=font;X.profile.fontSize=size;X.profile.scale=scale;X.profile.placement=placement
     UI:SetExpanded(true,true)
     local dx,dy,dw,dh=UI.details:Rect();local actual=UI.frame:GetEffectiveScale()
     for i=5,8 do
      local c=UI.cells[i];local x,y,w,h=c.shareTrack:Rect();local _,vy=c.value:Rect()
      near(vy-y-h,3*actual,'three-pixel gap below value');near(h,2*actual,'thin share fill')
      eq(x>=dx and x+w<=dx+dw+.001,true,'horizontal bounds')
      eq(y>=dy-.001 and y+h<=dy+dh+.001,true,'clipped drawer bounds')
      local _,_,fw=c.shareFill:Rect();near(fw,math.max(.001*actual,w*c.shareFraction),'same denominator at every scale')
     end
    end
   end
  end
 end
end
SlashCmdList.XPISLAND('reset');for i=5,8 do eq(UI.cells[i].shareFraction,0) end
-- Whole-level duration: independent counter, loading included, no first partial.
W,X,UI,M=boot()
local function levelup(level)
 W.level=level;W.xp=25;W.cap=1000+100*(level-10);W.event('PLAYER_LEVEL_UP',level)
 W.advance(2.1)
end
W.advance(100);levelup(11);eq(X.levelNotice,nil,'initial partial level omitted');eq(X.levelTiming.complete,true)
local start=W.time-2.1
W.advance(20);SlashCmdList.XPISLAND('reset');eq(X.levelTiming.complete,true,'session reset preserves level observation')
local timing=X.levelTiming;X:ApplyProfile();eq(X.levelTiming,timing,'profile independent')
W.event('LOADING_SCREEN_ENABLED');W.event('PLAYER_LEAVING_WORLD');W.connected=false
W.advance(30);W.time=W.time+7;W.wall=W.wall+7 -- loading that blocks all rendering
W.connected=true;W.event('PLAYER_ENTERING_WORLD',false,false);W.event('LOADING_SCREEN_DISABLED');W.advance(.1)
W.advance(40);local expected=W.time-start
W.hover=UI.frame;levelup(12)
eq(UI.cells[3].title:GetText(),'Last level took');near(X.levelNotice.seconds,expected,'whole level includes travel and loading')
eq(UI.cells[3].value:GetText(),M.Duration(expected));eq(X.levelNotice.level,11)
local notice,timer=X.levelNotice,X.levelNoticeTimer
W.event('PLAYER_LEVEL_UP',12);eq(X.levelNotice,notice,'duplicate level notification does not restart message');eq(X.levelNoticeTimer,timer)
UI:ShowStatTooltip(UI.cells[3],3);eq(W.tooltip.lines[1][1],'Last level')
W.advance(8);eq(X.levelNotice,nil,'message expires even while hover keeps drawer open')
eq(UI.expanded,true);eq(UI.cells[3].title:GetText(),'Time to Level');eq(X.levelNoticeTimer,nil)
-- Repeated transitions, manual collapse and stale expiry callbacks.
W.advance(60);levelup(13);eq(X.levelNotice~=nil,true);local stale=X.levelNoticeTimer
UI:SetExpanded(false);eq(X.levelNotice,nil);eq(stale.cancelled,true);stale.callback();eq(X.levelNotice,nil)
W.advance(60);levelup(14);eq(X.levelNotice~=nil,true);local newest=X.levelNotice
stale.callback();eq(X.levelNotice,newest,'old expiry cannot erase newer duration')
W.combat=true;W.event('PLAYER_REGEN_DISABLED');eq(X.levelNotice,nil);eq(UI.expanded,false)
W.advance(60);levelup(15);eq(X.levelNotice,nil,'combat suppresses message');eq(X.levelTiming.complete,true)
W.combat=false;X.profile.levelUp=false;W.advance(60);levelup(16);eq(X.levelNotice,nil,'disabled preview suppresses message')
X.profile.levelUp=true;W.advance(60);levelup(17);eq(X.levelNotice~=nil,true,'timing continues with presentation disabled')
UI.frame:Hide();eq(X.levelNotice,nil);eq(X.levelNoticeTimer,nil)
-- Disconnect makes that entire level unknown; next complete level can recover.
W.connected=false;W.event('UNIT_CONNECTION','player',false);eq(X.levelTiming.complete,false)
W.advance(100);W.connected=true;W.event('UNIT_CONNECTION','player',true);W.advance(.1);levelup(18)
eq(X.levelNotice,nil);eq(X.levelTiming.complete,true);W.advance(60);levelup(19);eq(X.levelNotice~=nil,true)
-- Missing/skipped or contradictory boundaries omit results.
W.advance(60);levelup(21);eq(X.levelNotice,nil);eq(X.levelTiming.complete,false)
W.advance(60);levelup(22);eq(X.levelNotice,nil);eq(X.levelTiming.complete,true)
W.event('PLAYER_LEVEL_UP',20);eq(X.levelTiming.level,22,'stale backward event cannot move baseline');eq(X.levelTiming.complete,true,'old event does not invalidate current level')
W.advance(60);levelup(23);eq(X.levelNotice~=nil,true)
W.level=24;W.cap=2400;X:Sample();W.advance(2.1);eq(X.levelTiming.complete,false,'missing level event is not a whole-level boundary')
UI:SetExpanded(false);W.event('PLAYER_LEVEL_UP',24)
eq(UI.expanded,true,'late genuine event still expands');eq(X.levelTiming.complete,false,'late event cannot recover missing start time')
W.advance(60);levelup(25);eq(X.levelNotice,nil);eq(X.levelTiming.complete,true)
-- Reload does not restore a falsely complete duration, even with resumed XP.
W.advance(60);X:Snapshot('reload');local saved=XPIslandSession
local W2=dofile('tests/wow_mock.lua');W2.level=25;W2.xp=25;W2.cap=2500;local ns2=W2.load();local Y=ns2.owner
XPIslandSession=saved;W2.event('ADDON_LOADED','XPIsland');W2.event('PLAYER_ENTERING_WORLD',false,true)
eq(Y.resumed,true);eq(Y.levelTiming.complete,false);eq(Y.levelNotice,nil)
W2.advance(60);W2.level=26;W2.cap=2600;W2.event('PLAYER_LEVEL_UP',26);W2.advance(2.1);eq(Y.levelNotice,nil)
W2.advance(60);W2.level=27;W2.cap=0;W2.xp=0;W2.capped=true;W2.event('PLAYER_LEVEL_UP',27);W2.advance(2.1)
eq(Y.levelNotice,nil,'cap suppresses presentation');eq(ns2.UI.frame:IsShown(),false)
-- Highlight workload and cleanup at multiple render cadences; no repeated objects.
W,X,UI,M=boot();local objects=#W.objects
for _,hz in ipairs({30,60,120}) do
 UI:HighlightSegments(0,999,1000)
 W.beginWork()
 while UI.flashDriver.scripts.OnUpdate do UI:AnimateHighlights(1/hz) end
 local work=W.endWork()
 for _,key in ipairs({'SetPoint','SetWidth','SetSize','SetText','SetFont','SetTexture','SetColorTexture','SetVertexColor','CreateTexture','CreateFontString'}) do
  eq(work[key],nil,'highlight frames change opacity only')
 end
 eq(next(UI.flashes),nil);eq(UI.flashDriver.scripts.OnUpdate,nil)
end
for i=1,1000 do
 UI:HighlightSegments(0,200,1000);UI:AnimateHighlights(.04)
 if i%2==0 then UI:ClearHighlights() else UI:AnimateHighlights(1) end
end
eq(#W.objects,objects,'repeated pulses retain bounded objects');eq(next(UI.flashes),nil);eq(UI.flashDriver.scripts.OnUpdate,nil)
-- Label remeasurement must not bypass cell-3 tooltip cancellation on notice changes.
X.profile.format='fraction';UI:SetExpanded(true,true)
for _,visible in ipairs({false,true}) do
 W.hover=UI.cells[3];UI.cells[3].scripts.OnEnter();local pending=UI.tooltipTimer
 W.advance(visible and .751 or .1);eq(GameTooltip:IsShown(),visible)
 X.levelNotice={seconds=2160,level=10};X.tracker.cap=10000000;UI:Update()
 eq(UI.tooltipCell,nil);eq(GameTooltip:IsShown(),false);pending.callback();eq(GameTooltip:IsShown(),false)
 UI.cells[3].scripts.OnEnter();pending=UI.tooltipTimer;W.advance(visible and .751 or .1)
 eq(GameTooltip:IsShown(),visible)
 X.levelNotice=nil;X.tracker.cap=1000;UI:Update()
 eq(UI.tooltipCell,nil);eq(GameTooltip:IsShown(),false);pending.callback();eq(GameTooltip:IsShown(),false)
end
W.hover=nil
-- Exact requested phrase and measured wrapping at large fonts/narrow widths.
for _,font in ipairs({'Game tooltip','Arial','Friz Quadrata','Missing custom font'}) do
 for _,size in ipairs({10,14,18}) do
  for _,scale in ipairs({.5,1,1.5}) do
   for _,viewport in ipairs({{320,180},{900,600},{1728,1080}}) do
    UIParent:SetSize(unpack(viewport));X.profile.font=font;X.profile.fontSize=size;X.profile.scale=scale
    X.levelTiming={level=11,seconds=0,complete=true};UI:SetExpanded(true,true)
    for _,duration in ipairs({36*60,102*60}) do
     X:LevelUp(duration);UI:SetExpanded(true,true)
     local c=UI.cells[3];eq((c.title:GetText():gsub('\n',' ')),'Last level took')
     eq(c.value:GetText(),duration==2160 and '36m' or '1h 42m')
     eq(c.title:GetUnboundedStringWidth()<=c:GetWidth(),true,'whole phrase fits selected font')
     eq(c.value:GetUnboundedStringWidth()<=c:GetWidth(),true,'duration fits')
     local _,cy,_,ch=c:Rect();local _,ty,_,th=c.title:Rect();local _,vy,vw,vh=c.value:Rect()
     eq(vy>=cy-.001 and ty+th<=cy+ch+.001,true,'wrapped title and duration fit row')
     eq(vy+vh<=ty+.001,true,'title and duration never overlap')
     X:ClearLevelNotice();UI:Update();eq(c.title:GetText(),'Time to Level')
    end
   end
  end
 end
end
-- Actual renderer fixtures for visual inspection, explicitly offline.
UIParent:SetSize(1728,1080);X.profile=M.Profile();W.xp=375;W.rested=225;X:Sample();UI:ClearHighlights()
X.session.total=15000;X.session.buckets={kills=7500,quests=3000,dungeons=3750,other=750}
X.session.seconds=7200;M.RateAward(X.session,15000)
UI:SetExpanded(false,true);W.svg('dist/preview-rested-05.svg',UI.frame)
UI:SetExpanded(true,true);W.svg('dist/preview-sources-05.svg',UI.frame)
X.levelTiming={level=11,seconds=0,complete=true};X:LevelUp(6120);UI:SetExpanded(true,true)
W.svg('dist/preview-level-05.svg',UI.frame)
UI:HighlightSegments(300,350,1000);W.svg('dist/preview-highlight-05.svg',UI.frame)
UIParent:SetSize(1300,1080);X.profile.fontSize=18;X:LevelUp(2160);UI:SetExpanded(true,true)
W.svg('dist/preview-level-wrap-05.svg',UI.frame)
print('PASS: '..n..' feature assertions (segment highlights, rested preview, source shares, whole-level duration)')
