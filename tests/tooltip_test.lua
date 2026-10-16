-- Exercise real hover scripts and chronological timers, not only formatting.
local W=dofile('tests/wow_mock.lua');local ns=W.load()
local X,UI=ns.owner,ns.UI
local n=0
local function eq(a,b,why) n=n+1;assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
local function shown(value,why) eq(GameTooltip:IsShown(),value,why) end
local function enter(i) W.hover=UI.cells[i];UI.cells[i].scripts.OnEnter() end
local function leave(i) W.hover=nil;UI.cells[i].scripts.OnLeave() end
local function open() UI.frame:Show();UI:SetExpanded(true,true) end
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false);W.advance(0)
X.profile.autoCollapse=false
open()
local titles={'XP remaining','XP/hour','Time to level','Rested XP','Outdoor kills','Outdoor quests','Dungeons','Other'}
for i=1,8 do
 enter(i);shown(false,'every cell starts hidden')
 W.advance(.749);shown(false,'full 750 ms dwell required')
 W.advance(.002);shown(true);eq(W.tooltip.owner,UI.cells[i]);eq(W.tooltip.anchor,'ANCHOR_BOTTOM')
 eq(W.tooltip.lines[1][1],titles[i],'existing title');eq(W.tooltip.lines[1][2],1,'existing styling')
 eq(UI.tooltipTimer,nil,'one-shot handle released')
 leave(i);shown(false,'leave hides visible tooltip');eq(UI.tooltipCell,nil)
end
-- Rendering consumes the separately calculated capacity.
local M=ns.Model
for _,case in ipairs({
 {0,1500,'0.0% of max. rested XP',false},
 {1,1500,'0.1% of max. rested XP',false},
 {750,1500,'50.0% of max. rested XP',false},
 {1000,1500,'66.7% of max. rested XP',false},
 {1499,1500,'99.9% of max. rested XP',false},
 {1499.999,1500,'99.9% of max. rested XP',false},
 {1500,1500,'Max',true}, {1600,1500,'Max',true},
 {7900,31950,'24.7% of max. rested XP',false},
 {1500,3000,'50.0% of max. rested XP',false},
}) do
 local text,maximum=M.RestedText(case[1],case[2])
 eq(text,case[3]);eq(maximum,case[4])
end
eq(M.RestedText(nil,1500),'0.0% of max. rested XP','nil means no rested bonus')
for _,invalid in ipairs({0,-1,math.huge,-math.huge,0/0,'1000',false}) do
 eq(M.RestedText(750,invalid),nil,'invalid denominator is unavailable')
end
eq(M.RestedText(750,nil),nil,'missing effective capacity is unavailable')
for _,invalid in ipairs({-1,math.huge,-math.huge,0/0,'750',false}) do
 eq(M.RestedText(invalid,1000),nil,'invalid rested value is unavailable')
end
local secret=setmetatable({},{__lt=function() error('secret compared') end,__mul=function() error('secret multiplied') end})
issecretvalue=function(v) return rawequal(v,secret) end
eq(M.RestedText(secret,1000),nil);eq(M.RestedText(750,secret),nil);issecretvalue=nil
DECIMAL_SEPERATOR=',';eq(M.RestedText(750,1500),'50,0% of max. rested XP');DECIMAL_SEPERATOR=nil
-- Missing perk state temporarily leaves the original tooltip intact.
W.legacyNodeUnavailable=true;W.rested=1500;W.event('UPDATE_EXHAUSTION');enter(4);W.advance(.751)
eq(#W.tooltip.lines,2,'unknown capacity leaves existing tooltip intact');leave(4)
W.legacyNodeUnavailable=false;W.event('UPDATE_EXHAUSTION')
local originalColor=X.profile.rested
X.profile.rested={.12,.74,.38}
local function restedLine(text,maximum)
 eq(#W.tooltip.lines,3,'one secondary line like the source tooltips')
 eq(W.tooltip.lines[1][1],'Rested XP')
 eq(W.tooltip.lines[2][1],'Available rested XP, including XP beyond this level.')
 local line=W.tooltip.lines[3];eq(line[1],text)
 local color=maximum and {1,.1,.1} or X.profile.rested
 for i=1,3 do eq(line[i+1],color[i],'rested progress color') end
end
W.rested=750;W.event('UPDATE_EXHAUSTION');enter(4);W.advance(.751)
restedLine('50.0% of max. rested XP',false)
W.rested=1500;W.event('UPDATE_EXHAUSTION');restedLine('Max',true)
W.rested=1499;W.event('UPDATE_EXHAUSTION');restedLine('99.9% of max. rested XP',false)
W.rested=nil;W.event('UPDATE_EXHAUSTION');restedLine('0.0% of max. rested XP',false)
X.profile.rested={.9,.3,.7};UI:Update();restedLine('0.0% of max. rested XP',false)
-- A tooltip reclaimed by another UI must not be repainted by our updates.
GameTooltip:SetOwner(UI.frame,'ANCHOR_BOTTOM');GameTooltip:AddLine('Other owner');GameTooltip:Show()
W.rested=1500;W.event('UPDATE_EXHAUSTION');eq(W.tooltip.lines[1][1],'Other owner');eq(#W.tooltip.lines,1)
leave(4);GameTooltip:Hide()
local oldXP=W.xp
W.xp=999;W.rested=750;W.event('PLAYER_XP_UPDATE','player');W.advance(0)
enter(4);W.advance(.751);restedLine('50.0% of max. rested XP',false);leave(4)
-- Character level cap/disabled XP never supplies the rested maximum label.
W.capped=true;UI:ShowStatTooltip(UI.cells[4],4);eq(#W.tooltip.lines,2)
W.capped=false;W.level=60;UI:ShowStatTooltip(UI.cells[4],4);eq(#W.tooltip.lines,2)
W.level=10;W.xp=oldXP;W.rested=0;X.profile.rested=originalColor;X:Sample();W.advance(2.1);GameTooltip:Hide()
-- Rested XP can update before the tracker accepts the next level's requirement.
W.rested=1500;W.event('UPDATE_EXHAUSTION');enter(4);W.advance(.751);restedLine('Max',true)
W.level=11;W.xp=20;W.cap=2000;W.event('PLAYER_XP_UPDATE','player');W.advance(0)
eq(X.tracker.cap,1000,'old denominator waits for rollover confirmation')
eq(#W.tooltip.lines,2,'omit progress while the XP denominator is pending')
W.advance(2.1);eq(X.tracker.cap,2000);restedLine('50.0% of max. rested XP',false);leave(4)
W.event('PLAYER_LEVEL_UP',12);UI:ShowStatTooltip(UI.cells[4],4)
eq(#W.tooltip.lines,2,'omit progress when level event precedes unit data')
W.level=12;W.xp=0;W.cap=3000;W.event('PLAYER_XP_UPDATE','player');W.advance(2.1)
W.rested=0;W.event('UPDATE_EXHAUSTION');open()
-- Switch before either deadline; a delayed leave from A must not cancel B.
enter(1);local stale=UI.tooltipTimer;W.advance(.5)
enter(2);local current=UI.tooltipTimer;eq(stale.cancelled,true)
UI.cells[1].scripts.OnLeave();eq(UI.tooltipTimer,current,'late leave belongs to previous cell')
stale.callback();shown(false,'dispatched stale callback cannot show')
W.advance(.749);shown(false);W.advance(.002);shown(true);eq(W.tooltip.owner,UI.cells[2])
enter(3);shown(false,'visible tooltip immediately hidden on switch');W.advance(.751);shown(true)
-- Leave/re-enter same cell must use a new generation and a fresh 750 milliseconds.
leave(3);enter(3);stale=UI.tooltipTimer;W.advance(.7);leave(3);eq(stale.cancelled,true)
enter(3);stale.callback();shown(false);W.advance(.749);shown(false);W.advance(.002);shown(true)
-- Leaving the stat must not hide another system's subsequently claimed tooltip.
GameTooltip:SetOwner(UI.frame,'ANCHOR_BOTTOM');GameTooltip:AddLine('Other owner');GameTooltip:Show()
leave(3);shown(true,'only hide a tooltip owned by this stat');GameTooltip:Hide()
local actions={
 {'collapse',function() UI:SetExpanded(false) end},
 {'combat',function() W.combat=true;W.event('PLAYER_REGEN_DISABLED') end},
 {'root hide',function() UI.frame:Hide() end},
 {'cell hide',function() UI.cells[4]:Hide() end},
 {'profile/layout',function() UI:Layout() end},
 {'drag',function() X.profile.locked=false;UI.frame.scripts.OnDragStart() end},
}
for _,case in ipairs(actions) do
 for _,visible in ipairs({false,true}) do
  W.combat=false;open();UI.cells[4]:Show();enter(4);stale=UI.tooltipTimer
  W.advance(visible and .751 or .5);shown(visible)
  case[2]();shown(false,case[1]..' hides tooltip');eq(UI.tooltipTimer,nil,case[1]..' cancels pending handle')
  stale.callback();W.advance(3);shown(false,case[1]..' rejects stale callback')
  if UI.dragging then UI.frame.scripts.OnDragStop() end
 end
end
open();enter(5);W.hover=nil -- defensive check when a leave event is missed
W.advance(.751);shown(false);eq(UI.tooltipCell,nil)
-- Entry during expansion is ignored; no tooltip appears later by itself.
UI:SetExpanded(false,true);UI:SetExpanded(true);enter(1)
eq(UI.tooltipTimer,nil);W.advance(3);shown(false)
-- Collapsed hover remains immediate and keeps the exact XP line.
UI:SetExpanded(false,true);W.hover=UI.frame;UI.frame.scripts.OnEnter();shown(true)
eq(W.tooltip.owner,UI.frame);eq(W.tooltip.lines[1][1],ns.Model.ExactXP(W.xp,W.cap))
UI.frame.scripts.OnLeave();shown(false)
-- Rapid movement creates no retained UI objects or repeating work.
open();local objects=#W.objects
for i=1,1000 do enter((i-1)%8+1);W.advance(.001) end
leave(8);W.advance(3);shown(false);eq(#W.objects,objects)
eq(UI.tooltipTimer,nil);eq(UI.tooltipCell,nil);eq(UI.frame.scripts.OnUpdate,nil)
local live=0;for _,t in ipairs(W.timers) do if not t.cancelled then live=live+1 end end
eq(live,1,'only existing shared clock remains')
print('PASS: '..n..' stat tooltip assertions (750 ms dwell, all cells, switch/re-entry, stale callbacks, collapse/combat/hide/drag, bounded resources)')
