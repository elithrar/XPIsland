local ns={}
assert(loadfile("XPIsland/Model.lua"))("XPIsland",ns)
local M=ns.Model
local count=0
local function equal(a,b,label)
    count=count+1
    assert(a==b,(label or "assertion")..": expected "..tostring(b)..", got "..tostring(a))
end
local function tracker()
    return M.NewTracker(M.NewSession("Player-1",1000))
end
local t=tracker()
t:Baseline(10,100,1000)
t:Sample(10,200,1000,"none",1)
t:Hint("kills",100,"none",1.1,"kill1")
equal(t.session.total,100,"kill total")
equal(t.session.buckets.kills,100,"post-award classification")
t:Hint("kills",100,"none",1.2,"kill1")
equal(t.session.total,100,"duplicate chat does not add XP")
equal(#t.hints,0,"duplicate chat ignored")
t:Hint("quests",200,"none",2,"q1")
t:Sample(10,400,1000,"none",2.1)
equal(t.session.buckets.quests,200,"pre-award classification")
t:Sample(10,450,1000,"none",3)
equal(t.session.buckets.other,50,"exploration residual")
t:Sample(10,650,1000,"party",4)
t:Hint("quests",200,"party",4.1,"dungeonq")
equal(t.session.buckets.dungeons,200,"dungeon overrides quests")
t:Sample(10,750,1000,"raid",5)
t:Hint("kills",100,"raid",5.1,"raidkill")
equal(t.session.buckets.other,150,"raid stays Other")
t:Sample(11,50,1200,"party",6)
equal(t.session.total,950,"rollover includes previous remainder")
equal(t.session.buckets.dungeons,500,"rollover attribution")
t:Sample(13,10,1400,"none",7)
equal(t.session.incomplete,true,"skipped thresholds invalidate estimates")
equal(t.session.total,950,"never invent missing level XP")
t:Sample(13,5,1400,"none",8)
equal(t.session.total,950,"negative corrections never become gain")

t=tracker();t:Baseline(1,0,100)
t:Hint("kills",25,"none",0,"before")
t:Sample(1,50,100,"party",.1)
equal(t.session.buckets.kills,0,"location boundary cannot steal dungeon XP")
equal(t.session.buckets.dungeons,50)
t:Sample(1,60,100,"none",3)
equal(t.session.buckets.other,10,"old source hints expire")
t:Hint("quests",50,"none",3.1)
equal(t.session.buckets.quests,0,"oversized hints cannot inflate attribution")
t:Expire(10)
equal(#t.hints,0)
equal(#t.awards,0)
t=tracker();t:Award(75,"unknown",1);t:Hint("kills",75,"none",1.1)
equal(t.session.buckets.other,75,"ambiguous location remains Other")
equal(t.session.buckets.kills,0,"outdoor hint cannot claim ambiguous location")

t=tracker();t:Award(90,"none",1)
t:Hint("kills",30,"none",1.1,"a");t:Hint("quests",50,"none",1.2,"b")
equal(t.session.buckets.kills,30,"coalesced gains")
equal(t.session.buckets.quests,50)
equal(t.session.buckets.other,10)
equal(M.ValidSession(t.session,"Player-1"),true,"bucket conservation")
for i=1,1000 do
    local amount=i%57+1
    t:Award(amount,i%3==0 and "party" or "none",i+2)
    t:Hint(i%2==0 and "kills" or "quests",amount,i%3==0 and "party" or "none",i+2.1,"event"..i)
    equal(M.ValidSession(t.session,"Player-1"),true,"conservation "..i)
end

local s=M.NewSession("Player-1",1000)
s.total=10;s.buckets.other=10;s.seconds=120;s.savedAt=2000;s.reason="departed"
local restored,resumed=M.Resume(s,"Player-1",2299,false)
equal(resumed,true,"299 seconds resumes")
equal(restored.seconds,120,"offline time excluded")
equal(select(2,M.Resume(s,"Player-1",2300,false)),true,"300 seconds resumes")
equal(select(2,M.Resume(s,"Player-1",2301,false)),false,"301 seconds resets")
equal(select(2,M.Resume(s,"Player-2",2001,false)),false,"different character")
s.reason="clean"
equal(select(2,M.Resume(s,"Player-1",2001,false)),false,"clean logout resets")
s.reason="reload"
equal(select(2,M.Resume(s,"Player-1",2600,true)),true,"reload preserves beyond grace")
equal(select(2,M.Resume(s,"Player-1",2001,false)),false,"stale reload checkpoint rejected")
s.reason="departed"
equal(select(2,M.Resume(s,"Player-1",1990,false)),false,"clock rollback fails safely")
s.buckets.other=-1
equal(select(2,M.Resume(s,"Player-1",2001,false)),false,"corrupt session rejected")

local db=M.Database({profiles={Bad={scale=99,fontSize=90,normal={-1,2,0},position={x=math.huge}}}})
equal(db.profiles.Bad.scale,1.5)
equal(db.profiles.Bad.fontSize,18)
equal(db.profiles.Bad.normal[1],0)
equal(db.profiles.Bad.position.x,0)
equal(M.Database({version=3}),nil,"future settings are not downgraded")
M.SelectProfile(db,"a","Shared");M.SelectProfile(db,"b","Shared")
db.profiles.Shared.scale=.9
equal(db.profiles[db.characters.b].scale,.9,"shared profile updates all selectors")
equal(M.Duplicate(db,"Shared","Personal"),"Personal")
db.profiles.Personal.normal[1]=0
equal(db.profiles.Shared.normal[1],.64,"duplicates deep-copy colors")
equal(M.Duplicate(db,"Shared","Personal"),nil,"duplicate name rejected")
equal(M.Duplicate(db,"Shared","   "),nil)
equal(M.Label("percent",25,100),"25.0%")
equal(M.Label("leftPercent",25,100),"75 XP left (75%)")
equal(M.Label("fraction",25,100),"25 / 100 XP")
equal(M.Label("left",25,100),"75 XP left")
equal(M.Label("percent",0,0),"—")
equal(M.Duration(3599),"1h 0m")
equal(M.Duration(math.huge),"—")
for _,case in ipairs({{1000,360,460},{1399,360,460},{1400,400,520},{1999,400,520},{2000,440,560},{6000,440,560}}) do
    local a,b=M.Layout(case[1],1)
    equal(a,case[2],"collapsed breakpoint")
    equal(b,case[3],"expanded breakpoint")
end
local _,width,scale=M.Layout(500,1.5)
equal(width*scale<=476,true,"narrow viewport fit")

local formats={assert(M.CompileXPFormat("%s dies, you gain %d experience. (%s %s bonus)")),assert(M.CompileXPFormat("You gain %d experience.")),assert(M.CompileXPFormat("%1$s stirbt. Ihr erhaltet %2$d Erfahrung."))}
equal(M.ParseXP("Boar 12 dies, you gain 120 experience. (+60 Rested bonus)",formats),120,"do not count rested twice")
equal(M.ParseXP("You gain 1,234 experience.",formats),1234,"group separators")
equal(M.ParseXP("Wolf stirbt. Ihr erhaltet 65 Erfahrung.",formats),65,"positional locale")
equal(M.ParseXP("Unrelated message 300",formats),nil)
equal(M.CompileXPFormat("bad %f format"),nil)
local reordered={assert(M.CompileXPFormat("Bonus %3$d: %1$s, %2$d XP"))}
equal(M.ParseXP("Bonus 30: Boar, 60 XP",reordered),60,"numeric argument order, not translation order")
issecretvalue=function(v) return v=="secret" end
equal(M.ParseXP("secret",formats),nil,"secret chat is not parsed")
equal(M.Number("secret"),false)
issecretvalue=nil
print("PASS: "..count.." model assertions")
