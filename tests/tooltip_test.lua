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
-- Existing event/ticker paths refresh the active tooltip without restarting dwell.
open();enter(1);W.advance(.3);local pending=UI.tooltipTimer
W.xp=W.xp+40;W.event('PLAYER_XP_UPDATE','player');W.advance(0)
shown(false,'XP update cannot skip dwell');eq(UI.tooltipTimer,pending)
W.advance(.451);shown(true)
eq(W.tooltip.lines[3][1],string.format('%d / %d XP remaining',W.cap-W.xp,W.cap))
W.xp=W.xp+25;W.event('PLAYER_XP_UPDATE','player');W.advance(0)
eq(W.tooltip.lines[3][1],string.format('%d / %d XP remaining',W.cap-W.xp,W.cap),'hovered XP changes immediately')
leave(1)
for i=5,8 do
 enter(i);W.advance(.751)
 local key=({'kills','quests','dungeons','other'})[i-4]
 X.session.buckets[key]=X.session.buckets[key]+17;X.session.total=X.session.total+17;UI:Update()
 eq(W.tooltip.lines[3][1],string.format('%d XP · %.1f%% of session',X.session.buckets[key],X.session.buckets[key]*100/X.session.total))
 leave(i)
end
enter(2);W.advance(.751)
local function sessionLine()
 eq(W.tooltip.lines[3][1],string.format('Session: %s XP · %s elapsed',BreakUpLargeNumbers(X.session.total),M.Duration(X.session.seconds)))
 eq(#W.tooltip.lines,3,'one concise session line')
end
sessionLine();W.advance(65);sessionLine()
W.xp=W.xp+30;W.event('PLAYER_XP_UPDATE','player');W.advance(0);sessionLine()
SlashCmdList.XPISLAND('reset');sessionLine();eq(X.session.total,0);eq(X.session.seconds,0)
leave(2)
-- ETA and kill estimates decay on the shared clock while the pointer stays still.
enter(3);W.advance(.751);local before=W.tooltip
W.advance(1);eq(W.tooltip~=before,true,'shared clock rebuilds hovered ETA')
X.session.seconds=60;X.clockAt=GetTime();M.RateAward(X.session,100);X.session.total=100
UI:Update();eq(W.tooltip.lines[2][1],'Based on your current XP/hour.')
X.session.seconds=3720;W.advance(1)
eq(W.tooltip.lines[2][1],M.ETAMessages.idle,'hovered ETA becomes idle after rate expiry')
leave(3)
X.profile.showKills=true;X:ApplyProfile();open()
local function inlineEnter(i)
 local c=UI.inlineCells[i];W.hover=c;c.scripts.OnEnter();W.advance(.751);return c
end
for i=1,5 do M.KillAward(X.session,100,X.session.seconds) end
local c=inlineEnter(3);shown(true);eq(W.tooltip.lines[1][1],'Kills to level')
eq(W.tooltip.lines[2][1],M.KillMessages.ready)
before=W.tooltip;W.advance(1);eq(W.tooltip~=before,true)
X.session.seconds=X.session.seconds+3661;W.advance(1)
eq(W.tooltip.lines[2][1],M.KillMessages.empty,'hovered kill estimate expires');c.scripts.OnLeave()
-- Real progression events refresh same-pet XP and PvP values. Pet replacement
-- still cancels the old hover rather than transferring its identity/delay.
local playerLevel,playerGUID,playerName=UnitLevel,UnitGUID,UnitName
local petXP=100
function UnitExists(unit) return unit=='pet' end
function UnitLevel(unit) return unit=='pet' and 9 or playerLevel(unit) end
function UnitGUID(unit) return unit=='pet' and 'Pet-A' or playerGUID(unit) end
function UnitName(unit) return unit=='pet' and 'Wolf' or playerName(unit) end
function GetPetExperience() return petXP,1000 end
W.event('UNIT_PET','player');open();c=inlineEnter(1)
petXP=250;W.event('UNIT_PET_EXPERIENCE')
eq(W.tooltip.lines[2][1],'Wolf · Level 9 · '..M.ExactXP(250,1000))
function UnitGUID(unit) return unit=='pet' and 'Pet-B' or playerGUID(unit) end
W.event('UNIT_PET','player');shown(false);eq(UI.tooltipCell,nil)
Constants={CurrencyConsts={HONOR_CURRENCY_ID=1792}}
local honor=125
C_CurrencyInfo={GetCurrencyInfo=function() return {quantity=honor} end}
local rank={renownLevel=2,renownReputationEarned=100,renownLevelThreshold=1000,maxLevel=14,currentWeekProgressiveMaxLevel=6}
C_MajorFactions=C_MajorFactions or {}
C_MajorFactions.GetMajorFactionProgressionInfo=function() return rank end
C_MajorFactions.GetTotalReputationForRenownLevel=function(_,level) return level*1000 end
W.event('UPDATE_FACTION');open();c=inlineEnter(2)
honor=70;rank.renownReputationEarned=350;W.event('CURRENCY_DISPLAY_UPDATE',1792)
eq(W.tooltip.lines[3][1],'Honor available: 70');eq(W.tooltip.lines[4][1],'Rank 2 · 350 / 1,000')
c.scripts.OnLeave();W.hover=nil
ns.Options:SetMode('pvp');open()
for i=1,4 do
 enter(i);W.advance(.751);honor=honor+1;W.event('CURRENCY_DISPLAY_UPDATE',1792)
 eq(W.tooltip.lines[3][1],'Honor available: '..honor,'PvP primary tooltip updates');leave(i)
end
UI:SetExpanded(false,true);W.hover=UI.indicator;UI.indicator.scripts.OnEnter()
honor=41;W.event('CURRENCY_DISPLAY_UPDATE',1792);eq(W.tooltip.lines[2][1],'Honor available: 41')
UI.indicator.scripts.OnLeave();W.hover=nil;ns.Options:SetMode('xp')
-- Collapsed bar and indicator retain immediate hover, refresh exact XP, and
-- never resurrect or overwrite a tooltip reclaimed/hidden by another system.
X.profile.format='percent';X:ApplyProfile();W.hover=UI.frame;UI.frame.scripts.OnEnter()
W.xp=W.xp+11;W.event('PLAYER_XP_UPDATE','player');W.advance(0)
eq(W.tooltip.lines[1][1],M.ExactXP(W.xp,W.cap))
before=W.tooltip;W.advance(1);eq(W.tooltip~=before,true,'collapsed default format uses existing ticker')
GameTooltip:SetOwner(UI.cells[1],'ANCHOR_BOTTOM');GameTooltip:AddLine('Foreign tooltip');GameTooltip:Show()
W.advance(1);eq(W.tooltip.lines[1][1],'Foreign tooltip')
UI.frame.scripts.OnLeave();shown(true,'bar leave respects foreign owner');GameTooltip:Hide()
W.hover=UI.frame;UI.frame.scripts.OnEnter();GameTooltip:Hide();W.advance(1);shown(false,'hidden tooltip stays hidden')
UI.frame.scripts.OnLeave();W.hover=nil
W.hover=UI.frame;UI.frame.scripts.OnEnter();UI.frame:Hide();shown(false,'root hide clears bar hover')
UI.frame:Show();W.hover=nil
UnitLevel,UnitGUID,UnitName=playerLevel,playerGUID,playerName
-- Rapid movement creates no retained UI objects or repeating work.
open();local objects=#W.objects
for i=1,1000 do enter((i-1)%8+1);W.advance(.001) end
leave(8);W.advance(3);shown(false);eq(#W.objects,objects)
eq(UI.tooltipTimer,nil);eq(UI.tooltipCell,nil);eq(UI.frame.scripts.OnUpdate,nil)
local live=0;for _,t in ipairs(W.timers) do if not t.cancelled then live=live+1 end end
eq(live,1,'only existing shared clock remains')
local paints=0;local showStat,showBar=UI.ShowStatTooltip,UI.ShowBarTooltip
function UI:ShowStatTooltip(...) paints=paints+1;return showStat(self,...) end
function UI:ShowBarTooltip(...) paints=paints+1;return showBar(self,...) end
W.advance(10);eq(paints,0,'inactive tooltips perform no formatting/repaint work')
enter(2);W.advance(.751);paints=0;W.advance(10)
eq(paints,10,'one repaint per shared clock tick while actively hovered')
leave(2);UI.ShowStatTooltip,UI.ShowBarTooltip=showStat,showBar
print('PASS: '..n..' stat tooltip assertions (750 ms dwell, all cells, switch/re-entry, stale callbacks, collapse/combat/hide/drag, bounded resources)')
