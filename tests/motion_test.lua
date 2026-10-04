-- Entry-point tests for the 0.3 motion, menu and collapse contracts.
local W=dofile('tests/wow_mock.lua');local ns=W.load()
local X,UI,O,M=ns.owner,ns.UI,ns.Options,ns.Model
local n=0
local function eq(a,b,why) n=n+1;assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,why) n=n+1;assert(math.abs(a-b)<.001,(why or 'near')..': '..a..' ~= '..b) end
local function settle() W.advance(.3) end
local function timers() local n=0;for _,t in ipairs(W.timers) do if not t.cancelled then n=n+1 end end;return n end
local function close() X:CancelAutoCollapse();UI:SetExpanded(false,true);W.hover=nil end
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false)
eq(X.profile.autoCollapse,true);eq(X.profile.collapseCombat,true)
local db=M.Database({version=2,profiles={Shared={autoCollapse=false,collapseCombat=false},Old={}}})
eq(db.profiles.Shared.autoCollapse,false);eq(db.profiles.Shared.collapseCombat,false)
eq(db.profiles.Old.autoCollapse,true);eq(db.profiles.Old.collapseCombat,true)
eq(UI.frame:GetFrameStrata(),'HIGH');eq(UI.frame:GetFrameLevel(),100)
eq(UI.cells[1]:GetFrameStrata(),'HIGH');eq(UI.details.clipsChildren,true)
eq(UI.frame.scripts.OnUpdate,nil,'idle has no frame callback')
-- Real click/keybind owner entry point. Visibility survives every collapse.
X:Toggle();eq(UI.expanded,true);eq(timers(),2,'one clock plus one collapse timer')
W.advance(14.9);eq(UI.expanded,true);W.advance(.1);eq(UI.expanded,false);settle()
eq(UI.progress,0);eq(UI.frame:IsShown(),true);eq(UI.frame.scripts.OnUpdate,nil)
-- Hover suspension and a fresh full interval after leaving.
X:Toggle();W.advance(10);W.hover=UI.frame;UI.frame.scripts.OnEnter()
eq(timers(),1,'hover cancels deadline');W.advance(30);eq(UI.expanded,true)
W.hover=nil;UI.frame.scripts.OnLeave();W.advance(14.9);eq(UI.expanded,true);W.advance(.1);eq(UI.expanded,false)
-- A timer also checks interaction at its deadline if a hover event was missed.
X:Toggle();W.hover=UI.frame;W.advance(15);eq(UI.expanded,true);eq(timers(),1)
W.hover=nil;W.advance(1);eq(timers(),2);W.advance(15);eq(UI.expanded,false)
-- Settings hold the panel open. Profile changes replace the old policy/deadline.
X:Toggle();SlashCmdList.XPISLAND('');eq(timers(),1);W.advance(30);eq(UI.expanded,true)
eq(O.frame.template,'BackdropTemplate');eq(#O.dropdowns,5)
for _,d in ipairs(O.dropdowns) do eq(d.template,'WowStyle1DropdownTemplate') end
W.choose(O.format,'leftPercent');eq(X.profile.format,'leftPercent')
W.choose(O.placement,'bottom');eq(X.profile.placement,'bottom');eq(UI.layout.up,true)
M.Duplicate(X.db,'Shared','No timeout');X.db.profiles['No timeout'].autoCollapse=false
O:Switch('No timeout');O.frame:Hide();W.advance(30);eq(UI.expanded,true);eq(timers(),1)
O:Switch('Shared');eq(timers(),2);W.advance(15);eq(UI.expanded,false)
-- Manual close, repeat level-up, disabled level preview, combat, no auto-reopen.
X:Toggle();W.advance(2);X:Toggle();eq(timers(),1);W.advance(20);eq(UI.expanded,false)
X:LevelUp();W.advance(8);X:LevelUp();W.advance(9.9);eq(UI.expanded,true);W.advance(.1);eq(UI.expanded,false)
X.profile.levelUp=false;X:Toggle();W.advance(5);X:LevelUp();W.advance(10);eq(UI.expanded,false,'disabled preview preserves manual timeout')
X.profile.levelUp=true;X:LevelUp();W.advance(.05);W.combat=true;W.event('PLAYER_REGEN_DISABLED')
eq(UI.expanded,false);eq(X.collapseDelay,nil);settle();eq(UI.frame.scripts.OnUpdate,nil)
X:LevelUp();eq(UI.expanded,false,'no automatic level-up opening in combat')
W.combat=false;W.event('PLAYER_REGEN_ENABLED');eq(UI.expanded,false,'combat end never reopens')
X.profile.collapseCombat=false;X:Toggle();W.combat=true;W.event('PLAYER_REGEN_DISABLED');eq(UI.expanded,true)
W.combat=false;X.profile.collapseCombat=true;close()
-- Drag suspends the same deadline and saves placement without animation drift.
X.profile.locked=false;X:Toggle();W.advance(.05);UI.frame.scripts.OnDragStart()
eq(UI.progress,1);eq(UI.animation,nil);eq(timers(),1)
W.advance(30);eq(UI.expanded,true);UI.frame.scripts.OnDragStop();eq(X.profile.placement,'custom')
eq(timers(),2);W.advance(15);eq(UI.expanded,false)
-- Hide at cap cancels all transient work, and returning starts collapsed.
X:Toggle();W.advance(.05);W.capped=true;X:Sample()
eq(UI.frame:IsShown(),false);eq(UI.expanded,false);eq(UI.animation,nil);eq(timers(),1)
W.capped=false;X:Sample();eq(UI.frame:IsShown(),true);eq(UI.progress,0)
-- No duplicate ETA warmup copy. No tooltip font mutation.
X.session=M.NewSession(X.character,GetServerTime());X.tracker.session=X.session;UI:Update()
UI.cells[3].scripts.OnEnter();eq(#W.tooltip.lines,2);eq(W.tooltip.lines[1][1],'Next level')
-- Every animated frame stays within the reserved footprint, keeps the bar's
-- vertical position, stretches segments and pins the measured label to the right.
X.profile.autoCollapse=false
for _,placement in ipairs({'top','bottom','custom'}) do
 for _,scale in ipairs({.5,1,1.5}) do
  close();X.profile.placement=placement;X.profile.position={x=150,y=-850};X.profile.scale=scale
  X.profile.format='leftPercent';X.profile.fontSize=18;UI:Layout()
  local hx,hy,hw,hh=UI.header:Rect();local prevWidth=UI.frame:GetWidth()
  X:Toggle()
  for i=1,24 do
   W.advance(.01)
   local x,y,w,h=UI.frame:Rect();local ax,ay,aw,ah=UI.header:Rect()
   near(ay,hy,'header Y stable');near(ax+aw/2,hx+hw/2,'header center stable')
   near(aw,w,'header fills island');eq(w>=prevWidth*scale-.001,true,'monotonic expansion');prevWidth=UI.frame:GetWidth()
   eq(x>=0 and x+w<=UIParent:GetWidth()+.001,true,'horizontal bounds');eq(y>=0 and y+h<=UIParent:GetHeight()+.001,true,'vertical bounds')
   local lx,ly,lw=UI.label:Rect();near(lx+lw,x+w-14*scale,'right label inset')
   local barEnd=select(1,UI.segments[20].track:Rect())+UI.segments[20].width*scale
   near(lx-barEnd,12*scale,'measured label clearance')
   eq(UI.details.alpha>=0 and UI.details.alpha<=1,true,'content opacity bounds')
   eq(UI.cells[1].mouse,UI.progress==1,'no moving tooltip hit regions')
  end
  eq(UI.animation,nil);eq(UI.frame.scripts.OnUpdate,nil);near(UI.details.alpha,1)
  local left=select(1,UI.cells[1]:Rect());local last=select(1,UI.cells[4]:Rect());local cellWidth=select(3,UI.cells[4]:Rect())
  local fx,_,fw=UI.frame:Rect();near(left-fx,fx+fw-last-cellWidth,'equal grid margins')
  for _,cell in ipairs(UI.cells) do eq(cell.title.justify,'CENTER');eq(cell.value.justify,'CENTER') end
  for i=1,20 do
   X:Toggle();W.advance(.017);local before=UI.progress
   X:Toggle();near(UI.progress,before,'reversal never snaps position');W.advance(.013)
  end
  settle();eq(UI.progress,1);eq(UI.animation,nil)
  X:Toggle();W.advance(.08);local before=UI.progress
  X.tracker.xp=12345678;X.tracker.cap=95000000;UI:Update()
  near(UI.progress,before,'label remeasure preserves transition position');eq(UI.animation~=nil,true)
  settle();eq(UI.progress,0);eq(UI.frame.scripts.OnUpdate,nil)
 end
end
-- Repeated interactive transitions/profile switches own a constant frame set.
local objects=#W.objects
for i=1,2000 do
 X.profile.autoCollapse=true;X:Toggle();W.advance(.013)
 W.hover=UI.frame;X:InteractionChanged();W.hover=nil;X:InteractionChanged()
 O:Switch(i%2==0 and 'Shared' or 'No timeout')
 W.event('PLAYER_REGEN_DISABLED');W.advance(.25)
 eq(timers(),1);eq(UI.frame.scripts.OnUpdate,nil)
end
eq(#W.objects,objects);eq(#O.fontObjects,43)
-- Fresh layout fixtures, including a partially expanded clipped/faded frame.
X.profile=M.Profile();X.db.profiles.Shared=X.profile;X.profileName='Shared';X:CancelAutoCollapse()
X.tracker.xp=60800;X.tracker.cap=95000;X.rested=12000;UI:SetExpanded(false,true)
UI:SetExpanded(true);W.advance(.055);W.svg('dist/preview-transition.svg',UI.frame);settle()
W.svg('dist/preview-centered.svg',UI.frame)
O:Page(false);O.frame:Show();W.svg('dist/preview-settings-03.svg',O.frame)
O:Page(true);W.svg('dist/preview-profiles-03.svg',O.frame);O.frame:Hide();X:CancelAutoCollapse()
print('PASS: '..n..' motion/timer/menu assertions; 2,000 interrupted interaction cycles')
