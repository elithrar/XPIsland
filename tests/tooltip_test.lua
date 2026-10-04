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
local titles={'XP remaining','Session XP/hour','Next level','Rested XP','Outdoor kills','Outdoor quests','Dungeons','Other'}
for i=1,8 do
 enter(i);shown(false,'every cell starts hidden')
 W.advance(1.99);shown(false,'full two-second dwell required')
 W.advance(.011);shown(true);eq(W.tooltip.owner,UI.cells[i]);eq(W.tooltip.anchor,'ANCHOR_BOTTOM')
 eq(W.tooltip.lines[1][1],titles[i],'existing title');eq(W.tooltip.lines[1][2],1,'existing styling')
 eq(UI.tooltipTimer,nil,'one-shot handle released')
 leave(i);shown(false,'leave hides visible tooltip');eq(UI.tooltipCell,nil)
end
-- Switch before either deadline; a delayed leave from A must not cancel B.
enter(1);local stale=UI.tooltipTimer;W.advance(1.5)
enter(2);local current=UI.tooltipTimer;eq(stale.cancelled,true)
UI.cells[1].scripts.OnLeave();eq(UI.tooltipTimer,current,'late leave belongs to previous cell')
stale.callback();shown(false,'dispatched stale callback cannot show')
W.advance(1.99);shown(false);W.advance(.011);shown(true);eq(W.tooltip.owner,UI.cells[2])
enter(3);shown(false,'visible tooltip immediately hidden on switch');W.advance(2);shown(true)
-- Leave/re-enter same cell must use a new generation and a fresh two seconds.
leave(3);enter(3);stale=UI.tooltipTimer;W.advance(1.8);leave(3);eq(stale.cancelled,true)
enter(3);stale.callback();shown(false);W.advance(1.99);shown(false);W.advance(.011);shown(true)
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
  W.advance(visible and 2 or 1);shown(visible)
  case[2]();shown(false,case[1]..' hides tooltip');eq(UI.tooltipTimer,nil,case[1]..' cancels pending handle')
  stale.callback();W.advance(3);shown(false,case[1]..' rejects stale callback')
  if UI.dragging then UI.frame.scripts.OnDragStop() end
 end
end
open();enter(5);W.hover=nil -- defensive check when a leave event is missed
W.advance(2);shown(false);eq(UI.tooltipCell,nil)
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
print('PASS: '..n..' stat tooltip assertions (two-second dwell, all cells, switch/re-entry, stale callbacks, collapse/combat/hide/drag, bounded resources)')
