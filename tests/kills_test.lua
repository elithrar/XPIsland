local ns={};assert(loadfile('XPIsland/Model.lua'))('XPIsland',ns);local M=ns.Model
local n=0
local function eq(a,b,msg) n=n+1;assert(a==b,(msg or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,msg) n=n+1;assert(a and math.abs(a-b)<1e-7,(msg or 'near')..': '..tostring(a)..' ~= '..tostring(b)) end
local function session() return M.NewSession('kills',0) end
local s=session()
eq(select(2,M.KillsToLevel(s,0,1000)), 'empty')
for i=1,4 do M.KillAward(s,100,0) end
eq(select(2,M.KillsToLevel(s,0,1000)), 'warming')
M.KillAward(s,100,0)
eq(M.KillsToLevel(s,0,950),10,'ceil fractional kill');eq(M.KillsToLevel(s,0,1000,true),nil)
eq(select(4,M.KillsToLevel(s,0,1000)),100)
-- Four older kills at 100 XP, six recent at 200: (400+2*1200)/(4+2*6)=175.
s=session();s.seconds=3600
for i=1,4 do M.KillAward(s,100,1200) end
for i=1,6 do M.KillAward(s,200,3000) end
local kills,state,count,mean=M.KillsToLevel(s,0,1750)
eq(kills,10);eq(state,'ready');eq(count,10);near(mean,175,'identical XP/count weights')
-- Recent boundary prorates numerator AND denominator; source is unchanged.
s.seconds=4230
near(select(4,M.KillsToLevel(s,0,1750)),2200/13,'half of recent bucket bonus')
s.seconds=6660
eq(select(2,M.KillsToLevel(s,0,1750)),'empty','all history expires')
-- Five kills at a partially expired boundary become a low sample, not bogus zero.
s=session();for i=1,5 do M.KillAward(s,100,0) end;s.seconds=3630
eq(select(2,M.KillsToLevel(s,0,1000)),'warming')
-- Split and coalesced award reconciliation: one count per message, not fragment.
local t=M.NewTracker(session());t.session.seconds=59.5
t:Hint('kills',100,'none',1,'chat:1')
t.session.seconds=60;t:Award(40,'none',1.1);eq(t.session.killHistory,nil)
t:Award(60,'none',1.2)
eq(t.session.killHistory.buckets[1].count,1);eq(t.session.killHistory.buckets[1].xp,100)
eq(t.session.killHistory.buckets[1].index,0,'original observation minute')
t:Award(300,'party',2)
t:Hint('kills',100,'party',2.1,'chat:2');t:Hint('kills',200,'party',2.2,'chat:3')
eq(t.session.killHistory.buckets[2].count,2);eq(t.session.killHistory.buckets[2].xp,300)
eq(t.session.buckets.dungeons,300);eq(t.session.buckets.kills,100)
-- Duplicate long after the existing short attribution cache expired cannot eat a new award.
t.session.seconds=600;t:Award(100,'none',10);t:Hint('kills',100,'none',10.1,'chat:1')
eq(t.session.buckets.other,100);eq(t.session.killHistory.buckets[11],nil)
-- Missing IDs, unmatched/expired hints and unknown contexts cannot create counts.
t:Hint('kills',100,'none',10.2);eq(t.session.killHistory.buckets[11],nil)
t:Hint('kills',900,'none',11,'chat:4');t:Expire(14);t:Award(900,'none',14)
eq(t.session.killHistory.buckets[11],nil)
t:Hint('kills',100,'unknown',14.1,'chat:5');eq(t.session.killHistory.buckets[11],nil)
-- Rested/group/dungeon transitions and normal level rollover retain already confirmed history.
t:Baseline(10,900,1000);t:Sample(11,50,1200,'party',15);t:Sample(11,50,1200,'party',16.1)
eq(t.session.killHistory.buckets[1].count,1)
t:Sample(11,40,1200,'none',17);t:Sample(11,40,1200,'none',18.1)
eq(t.session.killHistory.buckets[1].count,1,'correction keeps confirmed samples')
-- Restore aggregate history on the online clock; do not persist runtime chat IDs.
s=t.session;s.savedAt=1000;s.reason='reload'
local restored,resumed=M.Resume(s,'kills',10000,true)
eq(resumed,true);eq(restored.seconds,s.seconds);eq(restored.killHistory.buckets[1].count,1)
eq(M.NewTracker(restored).killSeenCount,0)
local bad=M.Copy(s);bad.killHistory.version=999
local healed=M.Resume(bad,'kills',10001,true)
eq(healed.total,s.total);eq(next(healed.killHistory.buckets),nil,'invalid extension does not destroy XP')
local old=M.Copy(s);old.killHistory=nil;eq(next(M.Resume(old,'kills',10001,true).killHistory.buckets),nil)
eq(M.Resume(s,'different',10001,true).killHistory,nil,'wrong character starts empty')
eq(session().killHistory,nil,'new session clears history')
for _,badValue in ipairs({0/0,math.huge,-1}) do
 local h={version=1,buckets={[1]={index=0,xp=badValue,count=5}}}
 eq(M.ValidKillHistory(h,100),false)
end
-- Bounded long-run data and full-window ID lifetime including partial minute tail.
t=M.NewTracker(session())
for i=1,8300 do t:Award(1,'party',i/10000);t:Hint('kills',1,'party',i/10000,'id:'..i) end
eq(t.killSeenCount,8192);eq(t.session.killHistory.buckets[1].count,8192)
t.session.seconds=3601;t:Expire(100);eq(t.killSeenCount,8192)
t.session.seconds=3720;t:Expire(101);eq(t.killSeenCount,0)
for minute=1,500 do t.session.seconds=minute*60;M.KillAward(t.session,100,t.session.seconds) end
local slots=0;for _ in pairs(t.session.killHistory.buckets) do slots=slots+1 end
eq(slots,61);eq(M.ValidKillHistory(t.session.killHistory,t.session.seconds),true)
print('PASS: '..n..' kill estimate assertions (weighting, timestamps, reconciliation, dedup, context, persistence and bounds)')
