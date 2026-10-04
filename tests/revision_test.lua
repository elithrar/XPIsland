local W=dofile('tests/wow_mock.lua')
local ns=W.load();local M,UI,O,X=ns.Model,ns.UI,ns.Options,ns.owner
local n=0
local function eq(a,b,why) n=n+1;assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,why) n=n+1;assert(math.abs(a-b)<.001,(why or 'near')..': '..a..' ~= '..b) end
local old={version=1,profiles={Shared={font='Arial',fontSize=12},Custom={font='Expressway',fontSize=16,position={x=100,y=-240}},Explicit={font='Arial',fontSize=12,fontCustomized=true,fontSizeCustomized=true}}}
local db=M.Database(old)
eq(db.profiles.Shared.font,'Game tooltip','migrate old default face');eq(db.profiles.Shared.fontSize,14)
eq(db.profiles.Custom.font,'Expressway');eq(db.profiles.Custom.fontSize,16);eq(db.profiles.Custom.placement,'custom')
eq(db.profiles.Custom.position.y,-240);eq(db.profiles.Explicit.font,'Arial');eq(db.profiles.Explicit.fontSize,12)
eq(M.Database(db).profiles.Explicit.font,'Arial','idempotent migration')
eq(M.Database({version=2,profiles={Shared={font='Arial',fontSize=12}}}).profiles.Shared.font,'Arial','v2 settings preserved')
for _,c in ipairs({{0,'0'},{999,'999'},{1000,'1K'},{6819,'6.8K'},{12900,'12.9K'},{60800,'60.8K'},{95000,'95K'},{999949,'999.9K'},{999950,'1M'},{1000000,'1M'},{1250000,'1.3M'}}) do eq(M.Compact(c[1]),c[2],'compact boundary') end
DECIMAL_SEPERATOR=',';eq(M.Compact(60800),'60,8K');eq(M.Label('percent',471,1000),'47,1%');DECIMAL_SEPERATOR=nil
eq(M.Label('fraction',60800,95000),'60.8K / 95K XP');eq(M.Label('leftPercent',60800,95000),'34.2K XP left (36%)')
for _,c in ipairs({{0,'<1m'},{59,'<1m'},{60,'1m'},{1560,'26m'},{3599,'1h 0m'},{6120,'1h 42m'},{172800,'2d 0h'},{1e12,'999d+'}}) do eq(M.Duration(c[1]),c[2]) end
eq(M.Duration(math.huge),'—');eq(M.Duration(nil),'—');eq(M.Duration(6120,true),'1 hour, 42 minutes')
local session=M.NewSession('Player-1',0);session.total=6000;session.buckets.other=6000;session.seconds=3600
M.RateAward(session,6000)
local rate,eta=M.Estimate(session,60800,95000,false);eq(rate,6000);eq(eta,20520)
local reloaded=M.Resume(session,'Player-1',9999,true);eq(select(2,M.Estimate(reloaded,60800,95000,false)),eta,'reload excludes wall gap')
session.reason='departed';session.savedAt=1000
local resumed=M.Resume(session,'Player-1',1299,false);eq(select(2,M.Estimate(resumed,60800,95000,false)),eta,'grace excludes wall gap')
eq(M.Estimate(session,1,100,true),nil);session.seconds=59;eq(select(2,M.Estimate(session,1,100,false)),nil)
session=M.NewSession('Player-1',0);session.seconds=60;eq(M.Estimate(session,1,100,false),0)
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false)
eq(UI.label.fontPath,'Fonts\\FRIZQT__.TTF','inherits tooltip font');eq(UI.label.fontSize,14)
GameTooltipTextLeft2={GetFont=function() return 'ActualTooltipFont.ttf',12,'' end};UI:Layout()
eq(UI.label.fontPath,'ActualTooltipFont.ttf','read actual tooltip line font')
X.profile.font='Arial';UI:Layout();eq(UI.label.fontPath,'Fonts\\ARIALN.TTF','explicit choice wins')
GameTooltipTextLeft2=nil;X.profile.font='Game tooltip';UI:Layout()
local originalTooltipFont=GameTooltipText:GetFont()
for i,name in ipairs({'Kill XP','Quest XP','Dungeon XP','Other XP'}) do eq(UI.cells[i+4].title:GetText(),name) end
UI.cells[5].scripts.OnEnter();eq(W.tooltip.anchor,'ANCHOR_BOTTOM');eq(W.tooltip.lines[1][1],'Outdoor kills','existing tooltip title unchanged')
eq(W.tooltip.lines[2][1],'Confirmed kill XP earned outside instances, including rested bonuses.')
eq(GameTooltipText:GetFont(),originalTooltipFont,'no tooltip font mutation')
SlashCmdList.XPISLAND('');eq(O.frame.template,'BackdropTemplate');eq(O.scale.template,'UISliderTemplate');eq(O.fontSize.template,'InputBoxTemplate')
W.click(O.checks[1]);eq(X.profile.locked,false,'native checkbox updates profile')
W.choose(O.font,'Arial');eq(X.profile.fontCustomized,true)
X.profile.font='Game tooltip';X.profile.fontSize=14
W.click(O.format);eq(#O.format.menuDescription.entries,5);eq(O.format.menuDescription.entries[2].label,'Current / Total XP');eq(O.format.menuDescription.entries[5].label,'Time to Next Level')
W.choose(O.format,'eta');eq(UI.infinity:IsShown(),true,'no-activity infinity symbol')
X.session.total=6000;X.session.buckets.other=6000;X.session.seconds=3600
W.xp=60800;W.cap=95000;X:Sample();W.advance(2.1);X.session.total=6000;X.session.buckets={kills=0,quests=0,dungeons=0,other=6000};X.session.rate={version=1,startedAt=0,buckets={}};M.RateAward(X.session,6000);UI:Update()
eq(UI.label:GetText(),UI.cells[3].value:GetText(),'same ETA in bar and cell')
UI.cells[3].scripts.OnEnter();eq(#W.tooltip.lines,4,'ETA context added without styling change')
eq(W.tooltip.lines[4][1],'6K XP/hour · 34200 XP remaining')
local previous=UI.label:GetText();W.event('PLAYER_LEAVING_WORLD');W.advance(120);eq(UI.label:GetText(),previous,'no offline ETA drift')
W.event('PLAYER_ENTERING_WORLD',false,false)
W.level=11;W.xp=10;W.cap=120000;X:Sample();W.advance(2.1);UI:Update()
eq(UI.label:GetText(),M.Duration(select(2,M.Estimate(X.session,10,120000,false))),'rollover estimate uses new level')
O.frame:Hide()
-- Full rectangle containment and stable bar across every supported layout tier.
for _,vw in ipairs({420,1024,1399,1400,1999,2000,3840}) do
 for _,vh in ipairs({220,768,1080}) do
  UIParent:SetSize(vw,vh)
  for _,scale in ipairs({.5,1,1.5}) do
   for _,placement in ipairs({'top','bottom','custom'}) do
    for _,position in ipairs({{x=0,y=-8},{x=-9000,y=-9000},{x=9000,y=-80},{x=100,y=-vh/2}}) do
     X.profile.scale=scale;X.profile.placement=placement;X.profile.position=position
     for _,format in ipairs({'percent','fraction','left','leftPercent','eta'}) do
      X.profile.format=format;X.profile.fontSize=18
      UI:SetExpanded(false,true);local bx,by,bw,bh=UI.header:Rect()
      UI:SetExpanded(true,true);local ax,ay,aw,ah=UI.header:Rect()
      near(ax+aw/2,bx+bw/2,'header center stable');near(ay,by,'bar Y stable');eq(aw>=bw,true,'header grows with island');near(ah,bh,'bar height stable')
      local x,y,w,h=UI.frame:Rect()
      eq(x>=-.001 and x+w<=vw+.001,true,'horizontal containment');eq(y>=-.001 and y+h<=vh+.001,true,'vertical containment')
      eq(UI.label:GetUnboundedStringWidth()<=UI.label:GetWidth(),true,'unclipped label')
      eq(UI.label.fontSize,18,'never shrink label text')
      eq(UI.segments[1].width*20+38>=139.9,true,'useful segmented bar')
      if placement=='top' then eq(UI.layout.up,false) elseif placement=='bottom' then eq(UI.layout.up,true) end
     end
    end
   end
  end
 end
end
UIParent:SetSize(1728,1080);X.profile.scale=1;X.profile.fontSize=14;X.profile.placement='custom'
X.profile.position={x=0,y=-50};UI:Layout();eq(UI.layout.up,false)
X.profile.position.y=-1000;UI:Layout();eq(UI.layout.up,true,'direction changes after moving')
-- UIParent's already shifted top is inherited, never offset a second time.
UIParent:SetHeight(1040);UI:SetExpanded(true,true);local _,y,_,h=UI.frame:Rect();eq(y+h<=1040,true,'uses reduced notch-safe viewport')
X.profile.placement='top';W.event('NOTCHED_DISPLAY_MODE_CHANGED');W.advance(.01)
near(UI.header:GetTop(),UIParent:GetTop()-8,'inherits shifted parent top')
for _,fraction in ipairs({0,.001,.025,.05,.471,.975,.999,1}) do
 X.tracker.xp=fraction*10000;X.tracker.cap=10000;UI:Update()
 local total=0
 for _,seg in ipairs(UI.segments) do total=total+seg.fill.visibleWidth/seg.width end
 near(total/20,fraction,'fractional fill conservation')
end
X.tracker.xp=100;X.tracker.cap=10000;UI:Update()
local first=UI.segments[1].fill
near(first.cap:GetWidth(),first.visibleWidth,'partial cap clips at exact XP boundary')
eq(first.cap.coords[2]<.5,true,'partial cap UV is cropped')
X.profile.placement='bottom';X.profile.format='leftPercent';X.profile.fontSize=18
X.tracker.xp=60800;X.tracker.cap=95000;UIParent:SetSize(1728,1080);UI:Layout()
W.svg('dist/preview-bottom.svg',UI.frame)
X.profile.placement='top';X.profile.fontSize=14;UI:Layout();W.svg('dist/preview-readable.svg',UI.frame)
print('PASS: '..n..' revision assertions (migration, typography, XP/ETA, pill clipping, placement)')
