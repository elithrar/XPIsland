-- Loading is gameplay downtime, not a session boundary. Reproduce 0.4.0's
-- false permanent flag without interacting with the client or SavedVariables.
local W=dofile('tests/wow_mock.lua');local ns=W.load()
local X,UI,M=ns.owner,ns.UI,ns.Model
local n=0
local function eq(a,b,why) n=n+1;assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,why) n=n+1;assert(math.abs(a-b)<.00001,(why or 'near')..': '..a..' ~= '..b) end
local function chat(amount,id)
 W.event('CHAT_MSG_COMBAT_XP_GAIN','Boar dies, you gain '..amount..' experience.','','','','','',0,0,'',0,id)
end
local function fresh()
 W.level=10;W.xp=100;W.cap=1000;W.instance='none';W.connected=true
 X.loading=false;X.inWorld=true;X.online=true;X.connected=true;X.transition=nil;X.levelPending=nil
 SlashCmdList.XPISLAND('reset');X.profile.format='eta';UI:Layout()
end
local function valid()
 eq(M.ValidSession(X.session,X.character),true,'conservation and bounded rate history')
 eq(X.session.incomplete,false,'never permanently disable estimates')
end
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false)
fresh()
W.xp=200;W.event('PLAYER_XP_UPDATE','player');chat(100,1);W.advance(.1)
eq(X.session.total,100);eq(X.session.buckets.kills,100)
W.advance(60);X:Clock();local rateBefore=M.Estimate(X.session,200,1000)
local before=X.session.seconds
-- XP may already be zero when LEAVING arrives. No final unit read here.
W.xp=0;W.connected=false;W.event('PLAYER_LEAVING_WORLD');W.event('LOADING_SCREEN_ENABLED')
W.cap=0;W.level=0;W.connected=false -- inaccessible unit data is not a disconnect event
W.event('UPDATE_EXHAUSTION');W.event('PLAYER_XP_UPDATE','player');W.advance(20)
-- Also exercise a renderer-blocking load with no ticker callbacks.
W.time=W.time+10;W.wall=W.wall+10
W.level=10;W.xp=200;W.cap=1000;W.connected=true
W.event('PLAYER_ENTERING_WORLD',false,false)
eq(X.online,true);eq(X.session.total,100);near(X.session.seconds,before+30,'all loading downtime included')
W.event('LOADING_SCREEN_DISABLED');W.advance(.1)
eq(X.session.total,100,'restored XP is not a new award');eq(X.session.partial,nil)
local rateAfter,duration=M.Estimate(X.session,200,1000)
eq(rateAfter<rateBefore,true,'travel reduces effective rate');eq(duration~=nil,true,'ETA survives travel')
UI:ShowStatTooltip(UI.cells[3],3);eq(W.tooltip.lines[2][1]:find('gap',1,true),nil)
W.xp=250;W.event('PLAYER_XP_UPDATE','player');chat(50,2);W.advance(.1)
eq(X.session.total,150);eq(X.session.buckets.kills,150);valid()
-- Loading disabled before ENTERING_WORLD, dungeon transition gains kept Other.
W.event('LOADING_SCREEN_ENABLED');W.event('PLAYER_LEAVING_WORLD');before=X.session.seconds
W.advance(12);W.instance='party';W.xp=280;W.event('LOADING_SCREEN_DISABLED')
eq(X.inWorld,false);eq(X.session.total,150)
W.event('PLAYER_ENTERING_WORLD',false,false);W.advance(.1);X:Clock()
near(X.session.seconds,before+12.1);eq(X.session.total,180);eq(X.session.buckets.other,30)
W.xp=330;chat(50,3);W.event('PLAYER_XP_UPDATE','player');W.advance(.1)
eq(X.session.total,230);eq(X.session.buckets.dungeons,50);eq(X.session.buckets.kills,150);valid()
-- Coalesced XP read queued just before leaving: no double counting or stale hint.
W.xp=350;chat(20,4);W.event('PLAYER_XP_UPDATE','player');W.event('PLAYER_LEAVING_WORLD')
W.xp=0;W.advance(2);W.instance='none';W.xp=350;W.event('PLAYER_ENTERING_WORLD',false,false);W.advance(.1)
eq(X.session.total,250);eq(X.session.buckets.other,50);eq(X.session.buckets.dungeons,50);valid()
-- Unavailable values never replace the known baseline.
local level,xp,cap=W.level,W.xp,W.cap
W.xp=nil;X:Sample();eq(X.tracker.xp,xp)
W.xp=xp;W.cap=nil;X:Sample();eq(X.tracker.cap,cap)
W.cap=cap;W.level=nil;X:Sample();eq(X.tracker.level,level);W.level=level
-- A short read glitch while otherwise in-world must not change the baseline.
W.xp=0;X:Sample();eq(X.tracker.xp,350);eq(X.session.total,250)
W.advance(.2);W.xp=350;X:Sample();eq(X.tracker.pending,nil);eq(X.session.total,250);eq(X.session.partial,nil)
-- Explicit connection loss is different from loading and excludes that interval.
W.connected=false;W.event('UNIT_CONNECTION','player',false);before=X.session.seconds
W.advance(30);W.connected=true;W.event('UNIT_CONNECTION','player',true);W.advance(.1);X:Clock()
near(X.session.seconds,before+.1,'actual offline interval excluded');valid()
-- XP rolls over before UnitLevel / LEVEL_UP: hold the old baseline.
fresh();W.xp=900;X:Sample();local total=X.session.total
W.xp=25;W.event('PLAYER_XP_UPDATE','player');W.advance(.1)
eq(X.tracker.xp,900);eq(X.session.total,total)
W.level=11;W.cap=1200;W.event('PLAYER_LEVEL_UP',11);W.advance(2.1)
eq(X.session.total,total+125);eq(X.tracker.xp,25);eq(X.session.partial,nil);valid()
-- Level changes first with stale XP/cap, then the complete new tuple arrives.
fresh();W.xp=900;X:Sample();total=X.session.total
W.level=11;W.event('PLAYER_LEVEL_UP',11);W.advance(.1)
eq(X.session.total,total,'do not award from mixed old/new level values')
W.xp=25;W.cap=1200;W.event('PLAYER_XP_UPDATE','player');W.advance(2.1)
eq(X.session.total,total+125);eq(X.session.partial,nil);valid()
-- A level notification can precede every visible unit value; retry even when
-- no second XP event arrives, and never leave a stale event veto behind.
fresh();W.xp=900;X:Sample();total=X.session.total
W.event('PLAYER_LEVEL_UP',11);W.advance(.1);eq(X.session.total,total)
W.level=11;W.xp=25;W.cap=1200;W.advance(2.1)
eq(X.session.total,total+125);eq(X.levelPending,nil);valid()
-- Unknown intermediate thresholds: preserve totals, restart only pace baseline.
W.level=13;W.xp=10;W.cap=1800;W.event('PLAYER_LEVEL_UP',13);W.advance(2.1)
eq(X.session.total,total+125);eq(X.session.partial,true);eq(X.session.rate.recovery,true)
eq(M.ETAState(X.session,M.Estimate(X.session,10,1800)),'recovering')
UI:ShowStatTooltip(UI.cells[3],3);eq(W.tooltip.lines[2][1],'Recalculating your leveling pace.')
W.xp=60;W.event('PLAYER_XP_UPDATE','player');chat(50,6);W.advance(.1)
eq(X.session.total,total+175);W.advance(60)
local rate,eta=M.Estimate(X.session,60,1800);eq(rate>0,true);eq(eta~=nil,true)
eq(M.ETAState(X.session,rate,eta),'ready');valid()
-- A persistent genuine correction stabilizes, skips unknown XP, then recovers.
W.xp=20;X:Sample();total=X.session.total;W.advance(2.1)
eq(X.tracker.xp,20);eq(X.session.total,total)
W.xp=70;X:Sample();eq(X.session.total,total+50);W.advance(60)
eq(select(2,M.Estimate(X.session,70,1800))~=nil,true);valid()
-- Effective level cap still records the known last-level remainder once.
fresh();W.xp=900;X:Sample();total=X.session.total
W.level=11;W.xp=0;W.cap=0;W.capped=true;W.event('PLAYER_LEVEL_UP',11);W.advance(2.1)
eq(X.session.total,total+100);eq(X.tracker.pending,nil);eq(UI.frame:IsShown(),false)
W.advance(3);eq(X.session.total,total+100,'cap is not counted twice');W.capped=false
-- 0.3 and 0.4 share this session schema. Reload migration never clears counters.
for _,oldVersion in ipairs({'0.3.0','0.4.0'}) do
 local s=M.NewSession('saved',0);s.seconds=471;s.total=250;s.buckets.kills=250
 M.RateAward(s,250);s.incomplete=true;s.reason='reload';s.savedAt=1000
 local restored,resumed=M.Resume(s,'saved',2000,true)
 eq(resumed,true,oldVersion..' reload resumes');eq(restored.total,250);eq(restored.buckets.kills,250)
 eq(restored.seconds,471,'reload wall time excluded');eq(restored.incomplete,false);eq(restored.rate.startedAt,471)
 local t=M.NewTracker(restored);t:Sample(10,200,1000,'none',0);t:Sample(10,250,1000,'none',1)
 restored.seconds=531;eq(select(2,M.Estimate(restored,250,1000))~=nil,true,'old flag self-heals')
 local rateHistory=restored.rate;M.NewTracker(restored);eq(restored.rate,rateHistory,'migration runs only once')
end
-- Repeated travel retains the session and owned UI objects.
local saved=X.session;local objects=#W.objects
for i=1,100 do
 W.event('LOADING_SCREEN_ENABLED');W.event('PLAYER_LEAVING_WORLD');W.advance(.1)
 W.event('PLAYER_ENTERING_WORLD',false,false);W.event('LOADING_SCREEN_DISABLED');W.advance(.1)
end
eq(X.session,saved,'travel never replaces the session');eq(#W.objects,objects,'travel allocates no UI objects');valid()
-- Startup ordering and unavailable initial values cannot create a false award.
XPIslandDB=nil;XPIslandSession=nil
local W2=dofile('tests/wow_mock.lua');local ns2=W2.load();local Y=ns2.owner
W2.event('LOADING_SCREEN_ENABLED');W2.event('ADDON_LOADED','XPIsland')
W2.level=0;W2.xp=0;W2.cap=0;W2.event('PLAYER_ENTERING_WORLD',true,false)
eq(Y.tracker.level,nil);W2.advance(5)
W2.level=10;W2.xp=200;W2.cap=1000;W2.event('LOADING_SCREEN_DISABLED');W2.advance(.1)
eq(Y.tracker.xp,200);eq(Y.session.total,0);eq(Y.session.incomplete,false)
eq(ns2.UI.frame:IsShown(),true)
print('PASS: '
..n..' recovery assertions (hearth/loading time, source boundaries, delayed rollover, correction, legacy migration)')
