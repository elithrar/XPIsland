local ns={};assert(loadfile('XPIsland/Model.lua'))('XPIsland',ns);local M=ns.Model
local n=0
local function near(a,b,msg) n=n+1;assert(a and math.abs(a-b)<1e-6,(msg or 'rate')..': '..tostring(a)..' ~= '..b) end
local function eq(a,b,msg) n=n+1;assert(a==b,(msg or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
local function sample(killRate,nonKillRate,age)
 local s=M.NewSession('rate',0)
 for minute=0,age/60-1 do
  s.seconds=minute*60
  local index=M.RateAward(s,(killRate+nonKillRate)/60)
  M.RateKill(s,index,killRate/60)
 end
 s.seconds=age
 return s
end
local s=sample(6000,0,3600);near(M.Estimate(s,0,10000),6000,'steady kill hour')
s=sample(6000,3000,3600);near(M.Estimate(s,0,10000),9000,'mixed hour')
local function step(old,new,expected)
 local s=sample(old,0,3600)
 for minute=1,60 do
  s.seconds=3600+(minute-1)*60
  local i=M.RateAward(s,new/60);M.RateKill(s,i,new/60);s.seconds=3600+minute*60
  if expected[minute] then near(M.Estimate(s,0,10000),expected[minute],'step '..old..' to '..new..' minute '..minute) end
 end
 return s
end
step(6000,12000,{[5]=7000,[10]=8000,[20]=10000,[60]=12000})
step(12000,6000,{[5]=11000,[10]=10000,[20]=8000,[60]=6000})
step(6000,0,{[5]=5000,[10]=4000,[20]=2000,[60]=0})
step(0,6000,{[5]=1000,[10]=2000,[20]=4000,[60]=6000})
s=sample(0,0,3600);M.RateAward(s,6000);near(M.Estimate(s,0,10000),6000,'quest burst gets hour denominator')
s=sample(6000,0,60);near(M.Estimate(s,0,10000),6000,'fresh minute')
s.seconds=59;eq(select(2,M.Estimate(s,0,10000)),nil,'ETA warmup')
s=sample(6000,0,3600);s.seconds=3630;near(M.Estimate(s,0,10000),5900,'prorated oldest buckets')
s.seconds=3659.9;local r1=M.Estimate(s,0,10000);s.seconds=3660;local r2=M.Estimate(s,0,10000)
eq(math.abs(r1-r2)<1,true,'expiry continuous across minute boundary')
s.seconds=7200;local rate,eta=M.Estimate(s,0,10000);eq(rate,0);eq(eta,nil,'zero rate no ETA')
s=sample(6000,0,3600);s.total=6000;s.buckets.kills=6000;s.savedAt=1000;s.reason='departed'
local restored=M.Resume(s,'rate',1300,false);near(M.Estimate(restored,0,10000),6000,'reconnect grace preserves online history')
local reload=M.Resume(s,'rate',9999,true);near(M.Estimate(reload,0,10000),6000,'reload preserves online history')
eq(M.Estimate(M.Resume(s,'rate',1301,false),0,10000),0,'expired grace resets history')
eq(M.Estimate(M.NewSession('rate',0),0,10000),0,'reset history')
-- An older saved session has totals but no reconstructable source timeline.
local legacy=M.Copy(s);legacy.rate=nil
local migrated=M.Resume(legacy,'rate',1200,false)
eq(migrated.total,6000);eq(migrated.rate.startedAt,3600);eq(select(2,M.Estimate(migrated,0,10000)),nil)
-- Dungeon kill classification is internally orthogonal to display categories.
local t=M.NewTracker(M.NewSession('rate',0));t.session.seconds=120
local index=2
t:Award(100,'party',1);t:Hint('kills',100,'party',1.1,'dungeon-kill')
eq(t.session.total,100);eq(t.session.buckets.dungeons,100);eq(t.session.buckets.kills,0)
eq(t.session.rate.buckets[index%61+1].killXP,100)
t:Hint('kills',100,'party',1.2,'dungeon-kill');eq(t.session.rate.buckets[3].killXP,100,'dedup rate correction')
t:Award(200,'party',2);t:Hint('quests',200,'party',2.1,'dungeon-quest')
eq(t.session.rate.buckets[3].totalXP,300);eq(t.session.rate.buckets[3].killXP,100,'quest does not get kill boost')
t:Award(50,'unknown',3);t:Hint('kills',50,'none',3.1,'unknown')
eq(t.session.rate.buckets[3].killXP,100,'unknown gain has no boost')
-- Reconciliation across a minute edge corrects the original award's slot.
t=M.NewTracker(M.NewSession('rate',0));t.session.seconds=59;t:Award(30,'none',1)
t.session.seconds=60;t:Hint('kills',30,'none',1.1,'edge')
eq(t.session.rate.buckets[1].killXP,30);eq(t.session.rate.buckets[2],nil)
-- Long running ring is fixed size, with no per-event history persisted.
s=M.NewSession('rate',0)
for minute=0,9999 do s.seconds=minute*60;local i=M.RateAward(s,100);M.RateKill(s,i,100) end
local slots=0;for _ in pairs(s.rate.buckets) do slots=slots+1 end
eq(slots,61);s.seconds=600000;near(M.Estimate(s,0,10000),6000)
local saved=M.Copy(s);saved.total=1000000;saved.buckets.kills=1000000
eq(M.ValidSession(saved,'rate'),true);saved.rate.buckets[62]={index=1,totalXP=1,killXP=1};eq(M.ValidSession(saved,'rate'),false,'reject oversized history')
s=sample(6000,0,3600);near(select(2,M.Estimate(s,60800,95000)),20520,'ETA uses unrounded effective rate')
eq(select(2,M.Estimate(s,1,100,true)),nil,'capped ETA')
s.rate.buckets[1].totalXP=1e300;s.rate.buckets[1].killXP=0
local hugeRate=M.Estimate(s,0,1e300);eq(M.Number(hugeRate),true,'huge finite rates remain finite')
eq(M.Duration(1e300),'999d+','huge duration bounded')
eq(M.Compact(1e300),'999M+','huge XP display bounded')
eq(M.Compact(math.huge),'—','invalid XP is not printed')
print('PASS: '..n..' rolling-rate assertions')
