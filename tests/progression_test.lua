local W=dofile('tests/wow_mock.lua')
local playerLevel=UnitLevel
function UnitLevel(unit) return unit=='pet' and (W.petLevel or 0) or playerLevel() end
function UnitExists(unit)
 if W.petExists~=nil then return W.petExists end
 return unit=='pet' and W.petGUID~=nil
end
function UnitGUID(unit) return unit=='pet' and W.petGUID or 'Player-1' end
function UnitName(unit) return unit=='pet' and (W.petName or 'Wolf') or 'Test' end
function GetPetExperience() return W.petXP,W.petCap end
function GetCurrentArenaSeason() return W.season or 1 end
Constants={CurrencyConsts={HONOR_CURRENCY_ID=1792}}
C_CurrencyInfo={GetCurrencyInfo=function(id) assert(id==1792);return W.honor~=nil and {quantity=W.honor} or nil end}
C_MajorFactions={GetMajorFactionProgressionInfo=function(id) assert(id==2800);return W.rank end,
 GetTotalReputationForRenownLevel=function(_,level) return level*1000 end}
-- Fail loudly if a guarded snapshot leaks into formatting or numeric operations.
-- This is a sentinel, not an emulation of the client's secret-value runtime.
local function secretUsed() error('restricted sentinel consumed') end
local secret=setmetatable({},{__tostring=secretUsed,__add=secretUsed,__lt=secretUsed,__le=secretUsed})
function issecretvalue(v) return rawequal(v,secret) end
local ns=W.load();local X,UI,O,M,P=ns.owner,ns.UI,ns.Options,ns.Model,ns.Progression
local n=0
local function eq(a,b,why) n=n+1;assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,why) n=n+1;assert(math.abs(a-b)<.001,(why or 'near')..': '..a..' ~= '..b) end
local function rank(level,xp,cap,week,max)
 return {renownLevel=level,renownReputationEarned=xp,renownLevelThreshold=cap,currentWeekProgressiveMaxLevel=week,maxLevel=max or 14}
end
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false)
eq(P.pet,nil);eq(P.rank,nil);eq(P.honor,nil);eq(X:Mode(),'xp')
eq(UI.inlineCells[1]:IsShown(),false);eq(UI.inlineCells[2].value:GetText(),'—')
-- Contextual pet swaps never keep previous identity or XP; other units ignored.
W.petGUID='Pet-A';W.petLevel=9;W.petXP=1200;W.petCap=2000
W.event('UNIT_PET','player');eq(P.pet.guid,'Pet-A');eq(UI.inlineCells[1].value:GetText(),'1.2K')
W.petGUID='Pet-B';W.petXP=0;W.event('UNIT_PET','target');eq(P.pet.guid,'Pet-A')
W.event('UNIT_PET','player');eq(P.pet.guid,'Pet-B');eq(P.pet.xp,0)
W.petXP=500;W.event('UNIT_PET_EXPERIENCE','player');eq(P.pet.xp,500)
-- Blizzard's Camelot consumer refreshes current pet XP regardless of payload.
-- The payload is only documented as UnitTokenVariant, not specifically player.
for i,unit in ipairs({'player','pet','target','party1',secret}) do
 W.petXP=600+i;W.event('UNIT_PET_EXPERIENCE',unit)
 eq(P.pet.xp,600+i,'pet XP event refreshes the current pet for any payload')
 eq(P.pet.guid,'Pet-B','payload does not select which pet is read')
end
W.petXP=700;W.event('UNIT_PET_EXPERIENCE')
eq(P.pet.xp,700,'missing event payload still refreshes pet XP');eq(P.pet.guid,'Pet-B')
W.petXP=800;W.event('UNIT_LEVEL','player');eq(P.pet.xp,700,'UNIT_LEVEL retains its pet filter')
W.petLevel=10;W.event('UNIT_LEVEL','pet');eq(P.pet.level,10)
W.petCap=0;W.event('UNIT_PET_EXPERIENCE','player');eq(P.pet,nil);eq(UI.inlineCells[1]:IsShown(),false)
W.petCap=2000;W.petXP=secret;W.event('UNIT_PET','player');eq(P.pet,nil)
W.petXP=1200;W.event('UNIT_PET','player');eq(P.pet.xp,1200)
for _,field in ipairs({'petExists','petGUID','petLevel','petCap'}) do
 local previous=W[field];W[field]=secret;W.event('UNIT_PET_EXPERIENCE')
 eq(P.pet,nil,'restricted pet field hides snapshot: '..field)
 W[field]=previous;W.event('UNIT_PET_EXPERIENCE');eq(P.pet.xp,1200,'snapshot recovers')
end
W.petName=secret;W.event('UNIT_PET_EXPERIENCE');eq(P.pet.name,nil,'restricted name omitted')
UI:ShowStatTooltip(UI.inlineCells[1],9);eq(W.tooltip.lines[2][1]:find('Pet · Level',1,true),1)
GameTooltip:Hide();W.petName=nil
W.petGUID=nil;W.event('UNIT_PET','player');eq(P.pet,nil)
-- Independent spendable balance and rank points; no fabricated currency earnings.
W.honor=0;W.rank=rank(3,600,1000,6)
W.event('CURRENCY_DISPLAY_UPDATE',1792);eq(P.honor,0);eq(P:RankText(),'600 / 1,000')
eq(P.rank.total,3600);eq(P.rank.ceiling,6000);eq(P.rank.left,400)
W.honor=1000;W.event('CURRENCY_DISPLAY_UPDATE',1792);eq(P.honor,1000)
W.honor=400;W.event('CURRENCY_DISPLAY_UPDATE',1792);eq(P.honor,400);eq(P.rank.xp,600,'spending leaves rank unchanged')
W.honor=secret;W.event('CURRENCY_DISPLAY_UPDATE',1792);eq(P.honor,nil)
W.rank=secret;W.event('UPDATE_FACTION');eq(P.rank,nil)
W.rank=rank(3,secret,1000,6);W.event('UPDATE_FACTION');eq(P.rank,nil)
W.rank=rank(3,600,1000,6);W.honor=400;W.event('UPDATE_FACTION')
for _,field in ipairs({'renownLevel','renownLevelThreshold','maxLevel'}) do
 local previous=W.rank[field];W.rank[field]=secret;W.event('UPDATE_FACTION')
 eq(P.rank,nil,'restricted rank field hides snapshot: '..field)
 W.rank[field]=previous;W.event('UPDATE_FACTION');eq(P.rank.level,3)
end
W.rank.currentWeekProgressiveMaxLevel=secret;W.event('UPDATE_FACTION')
eq(P.rank.ceiling,nil,'unreadable optional ceiling does not erase rank');eq(P.rank.xp,600)
W.rank.currentWeekProgressiveMaxLevel=6;W.event('UPDATE_FACTION')
-- Original hint clock, even between ticks; one delta can confirm five messages.
W.advance(.2)
for i=1,5 do W.event('CHAT_MSG_COMBAT_XP_GAIN','Wolf dies, you gain 20 experience.',nil,nil,nil,nil,nil,nil,nil,nil,nil,i) end
near(X.tracker.hints[1].observed,.2,'original event timestamp uses online clock')
W.xp=200;W.event('PLAYER_XP_UPDATE','player');W.advance(0)
eq(M.KillsToLevel(X.session,200,1000),40)
X.profile.format='kills';X:ApplyProfile();eq(UI.label:GetText(),'40 kills')
UI:ShowStatTooltip(UI.inlineCells[3],11);eq(W.tooltip.lines[2][1],M.KillMessages.ready)
-- Mature reference fixture, matching approved single inline row / exact header.
X.session.killHistory={version=1,buckets={[1]={index=0,xp=500,count=5}}}
W.xp=600;W.cap=3000;X.tracker:Baseline(10,600,3000)
W.petGUID='Pet-C';W.petXP=1200;W.petCap=2000;P:Refresh()
UI:SetExpanded(true,true);eq(UI.label:GetText(),'24 kills')
eq(UI.inlineCells[3].title:GetText(),'Kills to level:');eq(UI.inlineCells[3].value:GetText(),'24')
W.svg('dist/preview-progression-xp.svg',UI.frame)
-- Pair group stays centered and all labels/values have identical small text.
for _,fontSize in ipairs({10,12,14,18}) do
 for _,scale in ipairs({.5,1,1.5}) do
  for _,placement in ipairs({'top','bottom','custom'}) do
   for _,width in ipairs({800,1399,1920,3440}) do
    X.profile.fontSize=fontSize;X.profile.scale=scale;X.profile.placement=placement
    UIParent:SetSize(width,900);UI:SetExpanded(true,true)
    local gx,gy,gw,gh=UI.inlineGroup:Rect();local dx,dy,dw,dh=UI.details:Rect()
    near(gx+gw/2,dx+dw/2,'inline group centered')
    eq(gx>=dx and gx+gw<=dx+dw,true,'group horizontally inside drawer')
    eq(gy>=dy-.001 and gy+gh<=dy+dh+.001,true,'third row inside drawer')
    local size=UI.inlineCells[1].title.fontSize
    for _,c in ipairs(UI.inlineCells) do
     eq(c.title.fontSize,size);eq(c.value.fontSize,size)
     local x,y,w,h=c:Rect();eq(x>=gx-.001 and x+w<=gx+gw+.001,true,'pair inside group')
    end
   end
  end
 end
end
UIParent:SetSize(1920,1080);X.profile.fontSize=14;X.profile.scale=1;X.profile.placement='top'
-- Footer visibility recenters remaining pairs and preserves the old two rows.
X.profile.showPet=false;X:ApplyProfile();eq(UI.inlineCount,2)
X.profile.showRank=false;X:ApplyProfile();eq(UI.inlineCount,1)
X.profile.showKills=false;X:ApplyProfile();eq(UI.inlineCount,0)
X.profile.showPet=true;X.profile.showRank=true;X.profile.showKills=true;X:ApplyProfile()
-- True level cap vs disabled XP; opt-in automatic mode, explicit overrides.
SlashCmdList.XPISLAND('');O:Page('tracking')
eq(O.tracking:IsShown(),true);eq(O.options:IsShown(),false);eq(O.profiles:IsShown(),false)
W.svg('dist/preview-progression-settings.svg',O.frame)
W.capped=true;W.level=10;X.profile.pvpAtCap=true;X:ApplyProfile();eq(X:Mode(),'xp');eq(UI.frame:IsShown(),false)
W.level=60;W.cap=0;W.xp=0;X:Sample();eq(X:Mode(),'pvp');eq(UI.frame:IsShown(),true)
X:Toggle();W.advance(.3);eq(UI.expanded,true);eq(UI.cells[1].value:GetText(),'400')
eq(UI.cells[5]:IsShown(),false);eq(UI.inlineCells[3]:IsShown(),false)
W.choose(O.mode,'xp');eq(X.profile.pvpAtCap,false);eq(UI.frame:IsShown(),false)
W.choose(O.mode,'pvp');eq(UI.frame:IsShown(),true);eq(UI.expanded,false)
X:Toggle();W.advance(.3);eq(UI.expanded,true);eq(UI.label:GetText(),'PvP rank · 400 Honor')
W.choose(O.pvpFormat,'rankLeft');eq(UI.label:GetText(),'PvP · 400 RP left')
UI:ShowStatTooltip(UI.cells[1],1);eq(W.tooltip.lines[1][1],'Honor available')
-- Weekly ceiling vs seasonal max, valid zero and unavailable remain visible.
W.rank=rank(6,0,1000,6);W.event('MAJOR_FACTION_RENOWN_LEVEL_CHANGED',2800)
eq(P.rank.weekCapped,true);eq(UI.label:GetText(),'PvP · Rank cap reached')
W.rank=rank(14,0,0,14);W.event('UPDATE_FACTION');eq(P.rank.maximum,true);eq(UI.barFraction,1)
eq(UI.label:GetText(),'PvP · Maximum rank');eq(UI.frame:IsShown(),true)
W.rank=nil;W.honor=nil;W.event('UPDATE_FACTION');eq(UI.label:GetText(),'PvP · — RP left');eq(UI.barFraction,0)
eq(UI.frame:IsShown(),true);eq(UI.cells[1].value:GetText(),'—')
W.rank=rank(0,0,1000,6);W.honor=0;W.event('UPDATE_FACTION')
eq(UI.cells[1].value:GetText(),'0');eq(UI.cells[2].value:GetText(),'Unranked')
W.rank=rank(3,600,1000,6);W.honor=12450;W.event('UPDATE_FACTION');W.choose(O.pvpFormat,'honor')
O.frame:Hide();UI:SetExpanded(true,true);W.svg('dist/preview-progression-pvp.svg',UI.frame)
-- Season change refreshes existing snapshot without another timer.
W.rank=rank(0,0,1000,1);W.season=2;W.advance(1);eq(P.rank.level,0)
local timers=0;for _,timer in ipairs(W.timers) do if not timer.cancelled and timer.repeatEvery then timers=timers+1 end end
eq(timers,1);eq(UI.frame.scripts.OnUpdate,nil)
-- Mode changes dismiss pending tooltips/notices and combat never auto-reopens.
W.hover=UI.cells[1];UI.cells[1].scripts.OnEnter();W.choose(O.mode,'xp');eq(UI.tooltipTimer,nil)
eq(X.levelNotice,nil);eq(X.levelWindow,nil)
W.choose(O.mode,'pvp');X:Toggle();W.advance(.3);W.event('PLAYER_REGEN_DISABLED');eq(UI.expanded,false)
W.event('PLAYER_REGEN_ENABLED');eq(UI.expanded,false)
-- Mode changes clear header-owned tooltips, not only stat hover timers.
UI.frame.scripts.OnEnter();eq(W.tooltip.shown,true)
W.choose(O.mode,'xp');eq(W.tooltip.shown,false)
W.choose(O.mode,'pvp')
-- A visible pet tooltip cannot retain the previous pet name/identity.
W.petGUID='Pet-D';W.petXP=100;W.event('UNIT_PET','player');UI:SetExpanded(true,true)
W.hover=UI.inlineCells[1];UI.inlineCells[1].scripts.OnEnter();W.advance(.75);eq(W.tooltip.shown,true)
W.petGUID='Pet-E';W.event('UNIT_PET','player');eq(W.tooltip.shown,false)
-- An optional detail disappearing must invalidate even an already-dispatched hover.
W.hover=UI.inlineCells[1];UI.inlineCells[1].scripts.OnEnter();local stale=UI.tooltipTimer
X.profile.showPet=false;X:ApplyProfile();stale.callback()
eq(W.tooltip.shown,false);eq(UI.tooltipTimer,nil);eq(UI.inlineCells[1]:IsShown(),false)
X.profile.showPet=true;X:ApplyProfile()
-- World transition clears the pet; the accepted new baseline restores it even
-- when unit reads were not ready at the initial world-entry notification.
W.event('LOADING_SCREEN_ENABLED');eq(P.pet,nil)
W.petGUID=nil;W.event('PLAYER_ENTERING_WORLD',false,false)
W.petGUID='Pet-F';W.event('LOADING_SCREEN_DISABLED');W.advance(0);eq(P.pet.guid,'Pet-F')
-- Long PvP labels/values fit narrow panels at maximum font size, with the same
-- expanded geometry when opening upward. No per-animation text measurement.
W.rank=rank(3,600,1000,6);W.honor=999999999;P:Refresh()
for _,width in ipairs({800,1399,1920,3440}) do
 for _,size in ipairs({10,14,18}) do
  UIParent:SetSize(width,700);X.profile.fontSize=size;UI:SetExpanded(true,true)
  for i=1,4 do
   local c=UI.cells[i]
   eq(c.title:GetUnboundedStringWidth()*c.titleScale<=c:GetWidth()+.001,true,'PvP title fits')
   eq(c.value:GetUnboundedStringWidth()*c.valueScale<=c:GetWidth()+.001,true,'PvP value fits')
  end
 end
end
UIParent:SetSize(1920,1080);X.profile.fontSize=14;X:ApplyProfile()
-- Missing APIs fail closed without hiding an explicitly selected PvP mode.
C_CurrencyInfo=nil;C_MajorFactions=nil;P:PvP();UI:Update();eq(P.honor,nil);eq(P.rank,nil);eq(UI.frame:IsShown(),true)
GetPetExperience=nil;P:Pet();UI:Update();eq(P.pet,nil)
-- Additive saved settings preserve old choices and explicit false values.
local db=M.Database({version=2,profiles={Shared={format='eta',showPet=false,showRank=false,showKills=false,pvpAtCap=false}}})
eq(db.version,2);eq(db.profiles.Shared.format,'eta');eq(db.profiles.Shared.mode,'xp')
eq(db.profiles.Shared.showPet,false);eq(db.profiles.Shared.showRank,false);eq(db.profiles.Shared.showKills,false)
eq(M.Profile({mode='bogus',pvpFormat='bogus'}).mode,'xp');eq(M.Profile({mode='pvp',pvpFormat='rankLeft'}).pvpFormat,'rankLeft')
print('PASS: '..n..' progression assertions (pet identity, Honor/rank semantics, cap modes, inline geometry, lifecycle and settings)')
