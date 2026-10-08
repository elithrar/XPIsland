-- Lua-owned resource checks; this cannot measure WoW's native allocator/GPU.
if jit then jit.off();jit.flush() end -- isolate retained Lua data from JIT trace allocation
local W=dofile('tests/wow_mock.lua');local ns=W.load()
local X,UI,O,M=ns.owner,ns.UI,ns.Options,ns.Model
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false)
SlashCmdList.XPISLAND('');W.click(O.format);O:CloseMenu();O.frame:Hide()
M.Duplicate(X.db,'Shared','Stress')
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function activeTimers() local n=0;for _,t in ipairs(W.timers) do if not t.cancelled then n=n+1 end end;return n end
local objects,fonts,eventFrames,events=#W.objects,#O.fontObjects,0,0
for _,o in ipairs(W.objects) do
 assert(not o.scripts.OnUpdate,'No per-frame update script')
 if o.events then eventFrames=eventFrames+1;events=events+count(o.events) end
end
assert(eventFrames==1);assert(activeTimers()==1)
local function cycle(i)
 O:Toggle(X);W.click(O.format);O:CloseMenu();O:Page(i%2==0);O:Switch(i%2==0 and 'Shared' or 'Stress');O.frame:Hide()
 UI:SetExpanded(i%2==0)
 X:LevelUp();X:CancelAutoCollapse();W.advance(.01)
 W.event('PLAYER_ENTERING_WORLD',false,false);W.advance(0) -- drain the coalesced entry read
end
for i=1,100 do cycle(i) end
collectgarbage('collect');local before=collectgarbage('count')
local started=os.clock()
for i=1,3000 do cycle(i) end
collectgarbage('collect');local after=collectgarbage('count')
assert(#W.objects==objects,'Repeated UI operations created additional objects')
assert(#O.fontObjects==fonts,'Font registry grew')
assert(activeTimers()==1,'More than one live ticker after canceled level timers')
assert(count(X.db.profiles)==2,'Profiles grew without explicit creation')
assert(count(X.db.characters)==1,'Character selectors grew')
local eventsAfter=0
for _,o in ipairs(W.objects) do eventsAfter=eventsAfter+count(o.events or {}) end
assert(eventsAfter==events,'Event registrations grew')
print(string.format('First window retained delta %.2f KiB',after-before))
for i=1,3000 do cycle(i) end
collectgarbage('collect');local steady=collectgarbage('count')
print(string.format('Second window retained delta %.2f KiB',steady-after))
assert(steady-after<128,'Unexpected steady-state retained Lua memory growth')
-- Expiring event windows under a high-rate stream: 20 awards + hints/sec.
local t=M.NewTracker(M.NewSession('stress',0));local peakAwards,peakHints,peakSeen=0,0,0
for i=1,100000 do
 local now=i/20;t.session.seconds=now
 t:Award(10,'none',now);t:Hint('kills',10,'none',now,'event'..i)
 if i%200==0 then
  peakAwards=math.max(peakAwards,#t.awards);peakHints=math.max(peakHints,#t.hints);peakSeen=math.max(peakSeen,count(t.seen))
  assert(M.ValidSession(t.session,'stress'))
 end
end
assert(peakAwards<=41 and peakHints==0 and peakSeen<=61,'Queues exceed their expiry windows')
t:Expire(6000);assert(#t.awards==0 and #t.hints==0 and next(t.seen)==nil,'Expired records retained')
assert(t.session.total==1000000 and t.session.buckets.kills==1000000)
assert(count(t.session)==11,'Session history unexpectedly accumulates')
assert(count(t.session.killHistory.buckets)<=61 and t.killSeenCount<=8192,'Kill history/dedup is bounded')
t.session.seconds=10000;t:Expire(10000)
assert(next(t.killSeen)==nil and t.killSeenCount==0,'Old kill IDs expire')
X:CancelAutoCollapse();UI:SetExpanded(true,true);local draws=0
for _,s in ipairs(UI.segments) do local original=s.fill.Draw;s.fill.Draw=function(self,...) draws=draws+1;return original(self,...) end end
for i=1,600 do W.advance(1) end
assert(draws==0,'Idle bar geometry redrawn')
W.xp=W.xp+1;X:Sample();assert(draws==20,'XP changes still redraw')
local f=assert(io.open('dist/performance-results.txt','w'))
local result=string.format('PASS: 6,000 UI/profile/timer cycles; objects %d -> %d; font entries %d -> %d; event registrations %d -> %d; live timers %d; first/second-window retained Lua deltas %.2f/%.2f KiB after GC (JIT disabled for memory measurement).\n100,000 XP awards + hints; peak awards/hints/dedup %d/%d/%d; queues empty after expiry; total conserved.\n600 idle simulated seconds: 0 segment redraws; one XP change: 20 redraws. CPU %.3f sec (LuaJIT interpreter/mock, not in-game profiling).\n',objects,#W.objects,fonts,#O.fontObjects,events,eventsAfter,activeTimers(),after-before,steady-after,peakAwards,peakHints,peakSeen,os.clock()-started)
f:write(result);f:close();print(result)
