-- Authoritative counter protocol and real Core integration; no simulated elapsed
-- counter is used to derive level durations.
local n=0
local function eq(a,b,why) n=n+1;assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
local function boot(saved,chatFirst)
 XPIslandDB=nil;XPIslandSession=nil;XPIslandPlayed=saved;NUM_CHAT_WINDOWS=0;ChatFrame1=nil
 local W=dofile('tests/wow_mock.lua')
 local function chat()
  NUM_CHAT_WINDOWS=1
  local f=CreateFrame('Frame','ChatFrame1');f:RegisterEvent('TIME_PLAYED_MSG');f.messages=0;f.calls=0
  f.customEventHandler=function(self,event) self.calls=self.calls+1;if event=='CONSUMED' then return 'original' end end
  f.original=f.customEventHandler
  f:SetScript('OnEvent',function(self,event,...)
   if self.customEventHandler and self.customEventHandler(self,event,...) then return end
   if event=='TIME_PLAYED_MSG' then self.messages=self.messages+1 end
  end)
  return f
 end
 local f=chatFirst and chat()
 local ns=W.load()
 if not f then f=chat() end
 W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false);W.advance(0)
 return W,ns.owner,ns.Played,ns.UI,f
end
local function reply(W,total,level) W.event('TIME_PLAYED_MSG',total,level);W.advance(0) end
local function levelup(W,level)
 W.level=level;W.cap=1000+level*100;W.xp=0
 W.event('PLAYER_LEVEL_UP',level);W.advance(3)
end
for _,first in ipairs({true,false}) do
 local W,X,P,UI,f=boot(nil,first)
 W.advance(1);eq(W.playedRequests,1);eq(f.customEventHandler(f,'CONSUMED'),'original')
 reply(W,10000,2000);eq(f.messages,0,'automatic response quiet in either event order');eq(f.customEventHandler,f.original)
 eq(XPIslandPlayed.current.start,8000);eq(X.levelTiming,nil,'no per-level elapsed clock')
 W.advance(120);eq(W.playedRequests,1,'no polling')
 SlashCmdList.XPISLAND('reset');eq(XPIslandPlayed.current.start,8000,'session reset independent')
 X:ApplyProfile();eq(XPIslandPlayed.current.start,8000)
 levelup(W,11);reply(W,11200,200)
 eq(X.levelNotice.seconds,3000,'duration uses server difference, not wall/elapsed time')
 eq(X.levelNotice.level,10);eq(UI.cells[3].title:GetText(),'Time to Level');eq(UI.levelText:GetText(),'Last level took 50m');eq(UI.bar:IsShown(),false)
 local timer=X.levelNoticeTimer;W.event('PLAYER_LEVEL_UP',11);eq(X.levelNoticeTimer,timer,'duplicate level event')
 UI:SetExpanded(false);UI:SetExpanded(true);eq(X.levelNotice,nil,'dismissed notice stays dismissed');eq(UI.bar:IsShown(),true)
 W.advance(20);eq(X.levelNotice,nil);eq(P.saved.current.start,11000)
 RequestTimePlayed();reply(W,11300,300);eq(f.messages,1,'manual played remains visible')
end
-- Saved state is a minimal per-character authoritative anchor, including old saves.
local W,X,P,UI,f=boot();W.advance(1);reply(W,10000,2000)
local saved=XPIslandPlayed
W,X,P,UI,f=boot(saved);W.advance(1);reply(W,15000,7000)
eq(P.saved.current.start,8000,'reload/login same server level start');eq(X.levelNotice,nil)
W.connected=false;W.event('UNIT_CONNECTION','player',false);W.advance(90000)
W.connected=true;W.event('UNIT_CONNECTION','player',true);W.advance(2)
reply(W,15100,7100);eq(P.saved.current.start,8000,'offline gap does not change anchor')
levelup(W,11);reply(W,15500,100);eq(X.levelNotice.seconds,7400,'AFK/online time follows game counters')
for _,old in ipairs({{}, {version=99}, {version=1,character='wrong',current={level=10,start=8000,total=10000}}, {version=1,character=X.character,current={level=10,start=0/0,total=10000}}}) do
 W,X,P=boot(old);eq(P.saved.current,nil,'invalid or old saved state');W.advance(1);reply(W,100,10);eq(P.saved.current.start,90)
end
-- Disconnect during a request: discard/drain that reply, corroborate new anchor.
W,X,P=boot();W.advance(1)
W.connected=false;W.event('UNIT_CONNECTION','player',false)
W.connected=true;W.event('UNIT_CONNECTION','player',true);W.advance(0)
reply(W,10000,2000);eq(P.saved.current,nil)
W.advance(2);reply(W,10100,2100);eq(P.saved.current,nil,'first uncertain reply cannot establish baseline')
W.advance(2);reply(W,10200,2200);eq(P.saved.current.start,8000)
-- Rollover race with initial request outstanding and a delayed old-level reply.
W,X,P=boot();W.advance(1);levelup(W,11)
eq(W.playedRequests,1,'do not overlap invalidated request')
reply(W,10000,2000);eq(P.saved.current,nil)
W.advance(2);reply(W,11000,100);eq(P.saved.current,nil)
W.advance(2);reply(W,11002,102);eq(P.saved.current.start,10900);eq(X.levelNotice,nil,'missing previous anchor not invented')
-- A duplicate old-level response cannot become a new-level anchor.
W,X,P=boot();W.advance(1);reply(W,10000,2000);levelup(W,11)
reply(W,10000,2000);eq(P.saved.current.level,10);eq(X.levelNotice,nil)
W.advance(2);reply(W,10500,100);eq(X.levelNotice.seconds,2400)
-- A post-level snapshot may precede the delayed level event itself.
W,X,P,UI=boot();W.advance(1);reply(W,10000,2000)
W.level=11;W.cap=2100;W.xp=0;W.event('PLAYER_XP_UPDATE','player');W.advance(3)
reply(W,11000,100);eq(X.levelNotice,nil)
W.event('PLAYER_LEVEL_UP',11);eq(X.levelNotice.seconds,2900,'late event uses already received authoritative result')
-- An early event must not issue a request against still-old UnitLevel data.
W,X,P=boot();W.advance(1);reply(W,10000,2000)
W.event('PLAYER_LEVEL_UP',11);W.advance(4);eq(W.playedRequests,1)
W.level=11;W.cap=2100;W.xp=0;W.event('PLAYER_XP_UPDATE','player');W.advance(3)
reply(W,11000,100);eq(X.levelNotice.seconds,2900)
-- Missing replies stop after three attempts. A timed-out first reply needs corroboration.
W,X,P,UI,f=boot();W.advance(100);eq(W.playedRequests,3);eq(P.flight,nil);eq(f.customEventHandler,f.original)
reply(W,10000,2000);eq(P.saved.current,nil,'unsolicited stale response ignored')
W,X,P=boot();W.advance(11);eq(W.playedRequests,2)
reply(W,10000,2000);eq(P.saved.current,nil);W.advance(2);reply(W,10002,2002);eq(P.saved.current.start,8000)
-- Integer precision permits a level boundary at the last snapshot total.
W,X,P=boot();W.advance(1);reply(W,1100,100);levelup(W,11);reply(W,1105,5)
eq(X.levelNotice.seconds,100)
-- Duplicate connection notifications do not create new request bursts.
W,X,P=boot();W.advance(1);reply(W,10000,2000)
for i=1,20 do W.event('UNIT_CONNECTION','player',true);W.advance(1) end
eq(W.playedRequests,1)
-- API errors cannot strand ownership or misclassify future manual calls.
W,X,P,UI,f=boot();RequestTimePlayed=function() error('API unavailable') end
W.advance(1);eq(P.calling,nil);eq(P.flight,nil);eq(P.wanted,false);eq(f.customEventHandler,f.original)
-- Counter corruption, regression, conflicting starts, and skipped levels.
W,X,P=boot();W.advance(1);reply(W,10000,2000)
for _,v in ipairs({{9999,1999},{11000,2999},{-1,0},{1,2},{0/0,0},{math.huge,0},{10.5,0}}) do
 P:Sync();W.advance(2);reply(W,v[1],v[2]);eq(P.saved.current.start,8000);eq(P.saved.current.total,10000)
end
levelup(W,12);reply(W,12000,100);eq(P.saved.current.level,12);eq(X.levelNotice,nil,'skipped level cannot invent previous duration')
-- External calls fail open, keep other addons' handlers, and require resynchronization.
W,X,P,UI,f=boot();W.advance(1);local wrapper=f.customEventHandler
local other=function(frame,event,...) return wrapper(frame,event,...) end
f.customEventHandler=other
RequestTimePlayed();eq(f.customEventHandler,other,'never overwrite later handler owner')
reply(W,10000,2000);eq(f.messages,1);eq(P.saved.current,nil)
reply(W,10000,2000);eq(f.messages,2,'drain both overlapping responses')
eq(wrapper(f,'TIME_PLAYED_MSG',10000,2000),nil,'retained wrapper deactivated')
W.advance(2);reply(W,10002,2002);eq(P.saved.current,nil)
W.advance(2);reply(W,10004,2004);eq(P.saved.current.start,8000)
-- A manual request before our first request is also an outstanding owner.
W,X,P,UI,f=boot();RequestTimePlayed();W.advance(2)
eq(W.playedRequests,1,'wait for manual reply before automatic request')
reply(W,10000,2000);eq(f.messages,1)
W.advance(2);reply(W,10002,2002);eq(P.saved.current,nil)
W.advance(2);reply(W,10004,2004);eq(P.saved.current.start,8000);eq(f.messages,1,'normally drained manual request adds no chat spam')
-- Even a manual request that times out must not make its late reply quiet.
W,X,P,UI,f=boot();RequestTimePlayed();W.advance(9)
reply(W,10000,2000);eq(f.messages,1);eq(P.saved.current,nil)
-- Late authoritative replies update anchors but never reopen/restart a dismissed popup.
W,X,P,UI=boot();W.advance(1);reply(W,10000,2000);levelup(W,11)
UI:SetExpanded(false);UI:SetExpanded(true);reply(W,11000,100)
eq(X.levelNotice,nil);eq(P.saved.current.start,10900)
-- Full ten seconds in the header; ETA keeps its own live model value.
W,X,P,UI=boot();W.advance(1);reply(W,10000,2000);levelup(W,11);reply(W,11000,100)
local rate,eta
local M={};assert(loadfile('XPIsland/Model.lua'))('XPIsland',M)
rate,eta=M.Model.Estimate(X.session,X.tracker.xp,X.tracker.cap,X:IsCapped())
eq(UI.cells[3].value:GetText(),M.Model.Duration(eta));eq(UI.cells[3].title:GetText(),'Time to Level')
W.hover=UI.frame;W.advance(9.9);eq(UI.levelText:IsShown(),true)
W.advance(.2);eq(UI.levelText:IsShown(),false);eq(UI.bar:IsShown(),true);eq(UI.expanded,true)
levelup(W,12);reply(W,12000,100);local stale=X.levelNoticeTimer
levelup(W,13);reply(W,13000,100);local current=X.levelNotice
stale.callback();eq(X.levelNotice,current,'stale expiry cannot clear newer header notice')
W.combat=true;W.event('PLAYER_REGEN_DISABLED');eq(X.levelNotice,nil);eq(UI.bar:IsShown(),true)
-- Timer cleanup and disabled/combat/capped presentation retain server tracking.
for _,mode in ipairs({'disabled','combat','capped'}) do
 W,X,P,UI=boot();W.advance(1);reply(W,10000,2000)
 if mode=='disabled' then X.profile.levelUp=false elseif mode=='combat' then W.combat=true else W.capped=true end
 levelup(W,11);reply(W,11000,100);eq(X.levelNotice,nil,mode);eq(P.saved.current.start,10900)
end
-- Header animation does not allocate or remeasure text on every frame.
W,X,P,UI=boot();W.advance(1);reply(W,10000,2000);levelup(W,11);reply(W,11000,100)
local objects=#W.objects
W.beginWork()
for i=1,60 do UI:RenderGeometry(i/60) end
local work=W.endWork()
for _,key in ipairs({'SetFont','SetText','GetUnboundedStringWidth','CreateTexture','CreateFontString'}) do
 eq(work[key],nil,'header animation avoids repeated '..key)
end
eq(#W.objects,objects)
print('PASS: '..n..' authoritative played-time assertions (durability, races, bounded requests, chat ownership, UI)')
