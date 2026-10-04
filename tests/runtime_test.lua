local W=dofile("tests/wow_mock.lua")
os.execute("mkdir -p dist")
local ns=W.load()
local X,UI,O=ns.owner,ns.UI,ns.Options
local n=0
local function eq(a,b,why) n=n+1;assert(a==b,(why or "assertion")..": "..tostring(a).." ~= "..tostring(b)) end
W.event("ADDON_LOADED","XPIsland")
W.event("PLAYER_ENTERING_WORLD",true,false)
eq(UI.frame:IsShown(),true,"login displays island")
eq(X.profileName,"Shared")
eq(UI.frame:GetWidth(),400,"mid viewport tier")
eq(#UI.segments,20)
eq(UI.label:GetText(),"10.0%")
W.xp=150;W.event("PLAYER_XP_UPDATE","player")
W.event("CHAT_MSG_COMBAT_XP_GAIN","Boar dies, you gain 50 experience.","","","","","",0,0,"",0,1)
W.advance(.1)
eq(X.session.total,50);eq(X.session.buckets.kills,50)
eq(#X.formats,2,"rested format included; unnamed gains excluded")
W.instance="party";W.xp=250
W.event("QUEST_TURNED_IN",5,100,0);W.event("PLAYER_XP_UPDATE","player");W.advance(.1)
eq(X.session.buckets.dungeons,100)
W.rested=500;W.event("UPDATE_EXHAUSTION")
eq(UI.segments[1].fill.body.color[3],1,"rested color")
W.click(UI.frame);eq(UI.expanded,true)
eq(UI.frame:GetWidth(),520);eq(UI.cells[4].value:GetText(),"500")
W.advance(61);eq(X.session.seconds>61,true,"connected timer")
eq(UI.cells[2].value:GetText()~="—",true,"rate after a minute")
W.event("PLAYER_LEAVING_WORLD")
local seconds=X.session.seconds
W.advance(200);eq(X.session.seconds,seconds,"loading/offline gap excluded")
W.event("PLAYER_ENTERING_WORLD",false,false);W.advance(1)
eq(X.session.seconds,seconds+1)
W.level=11;W.xp=25;W.cap=1200;W.event("PLAYER_LEVEL_UP",11);W.advance(.1)
eq(X.session.total,925,"runtime level rollover")
eq(UI.expanded,true,"level expansion")
W.advance(10);eq(UI.expanded,false,"ten-second collapse")
W.event("PLAYER_LEVEL_UP",11);W.click(UI.frame);local manual=UI.expanded
W.advance(20);eq(UI.expanded,manual,"manual interaction cancels timer")
X:LevelUp();W.advance(5);X:LevelUp();W.advance(5)
eq(UI.expanded,true,"replacement level-up timer restarts its full duration")
W.advance(5);eq(UI.expanded,false,"replacement timer expires after ten seconds")

SlashCmdList.XPISLAND("")
eq(O.frame:IsShown(),true,"slash opens options")
eq(#O.checks,3)
O.scaleEdit:SetText("125");O.scaleEdit.scripts.OnEnterPressed(O.scaleEdit)
eq(X.profile.scale,1.25,"numeric scale updates model")
eq(O.scale.value,125,"numeric scale updates slider")
O.scale:SetValue(75);eq(X.profile.scale,.75,"slider updates model")
eq(O.scaleEdit:GetText(),"75")
W.click(O.normal);W.colorInfo.swatchFunc();eq(X.profile.normal[1],.1)
W.colorInfo.cancelFunc();eq(X.profile.normal[1],.64,"cancel color restores prior value")
O:Page(true);eq(O.profiles:IsShown(),true);eq(O.options:IsShown(),false)
local name=ns.Model.Duplicate(X.db,"Shared","Solo")
O:Switch(name);eq(X.profileName,"Solo")
X.profile.scale=1.2;eq(X.db.profiles.Shared.scale,.75,"independent profile")
local session=X.session;O:Switch("Shared");eq(X.session,session,"profile switch preserves session")
X.db.profiles.Solo.normal[1]=.27;O.copySource="Solo"
W.click(O.copyButton);eq(X.profile.normal[1],.64,"copy requires confirmation")
W.click(O.copyButton);eq(X.profile.normal[1],.27,"confirmed copy applies source")
X.profile.normal[1]=.14;eq(X.db.profiles.Solo.normal[1],.27,"UI copy owns independent nested color data")
X.profile.normal[1]=.64
O:Page(false)

local original=StatusTrackingBarManager.CanShowBar
X.profile.hideBlizzard=true;X:ApplyProfile()
eq(StatusTrackingBarManager:CanShowBar(1),false,"XP filter")
eq(StatusTrackingBarManager:CanShowBar(2),true,"reputation preserved")
eq(StatusTrackingBarManager:CanShowBar(3),true,"honor preserved")
X.profile.hideBlizzard=false;X:ApplyProfile();eq(StatusTrackingBarManager.CanShowBar,original,"filter reversal")
W.combat=true;X.profile.hideBlizzard=true;X:ApplyProfile()
eq(StatusTrackingBarManager.CanShowBar,original,"defer stock UI changes in combat")
W.combat=false;W.event("PLAYER_REGEN_ENABLED");eq(StatusTrackingBarManager:CanShowBar(1),false)
W.combat=true;X.profile.hideBlizzard=false;X:ApplyProfile()
eq(StatusTrackingBarManager:CanShowBar(1),false,"disabling also waits for combat to end")
W.combat=false;W.event("PLAYER_REGEN_ENABLED");eq(StatusTrackingBarManager:CanShowBar(1),true)
X.profile.hideBlizzard=true;X:ApplyProfile()
EllesmereUI={Lite={GetAddon=function() return {db={profile={useBlizzardDataBars=false}}} end}}
X:Integration();eq(StatusTrackingBarManager.CanShowBar,original,"Ellesmere ownership wins")
EllesmereUI=nil;X.profile.hideBlizzard=false;X:ApplyProfile()

W.capped=true;W.event("PLAYER_MAX_LEVEL_UPDATE");eq(UI.frame:IsShown(),false,"hide at cap")
W.capped=false;W.event("PLAYER_MAX_LEVEL_UPDATE");eq(UI.frame:IsShown(),true)
W.event("PLAYER_CAMPING");W.event("LOGOUT_CANCEL");eq(X.cleanIntent,nil)
Logout();W.event("PLAYER_LOGOUT");eq(XPIslandSession.reason,"clean")
X.cleanIntent=nil;ReloadUI();W.event("PLAYER_LOGOUT");eq(XPIslandSession.reason,"reload")
X.reloadIntent=nil;W.event("PLAYER_LOGOUT");eq(XPIslandSession.reason,"departed")

for _,vw in ipairs({1024,1399,1400,1999,2000,3840}) do
    UIParent:SetWidth(vw)
    for _,scale in ipairs({.5,1,1.5}) do
        for _,format in ipairs({"percent","fraction","left","leftPercent"}) do
            X.profile.scale=scale;X.profile.format=format;X.profile.fontSize=18
            X.profile.position={x=9000,y=-9000};UI:SetExpanded(true)
            local x,y,w,h=UI.frame:Rect()
            eq(x>=0 and x+w<=vw,true,"horizontal clamping")
            eq(y>=0 and y+h<=UIParent:GetHeight(),true,"vertical clamping")
            eq(UI.segments[1].width>0,true,"long-label segment width")
        end
    end
end
UIParent:SetWidth(1728);X.profile.position={x=0,y=-8};X.profile.format="percent"
for _,rootScale in ipairs({.64,.8,1,1.2}) do
    UIParent:SetScale(rootScale);X.profile.scale=1.25;UI:SetExpanded(true)
    eq(UI.frame:GetEffectiveScale(),rootScale*1.25,"effective WoW and addon scale")
    eq(UI.frame:GetWidth(),520,"logical tier does not use render pixels")
end
UIParent:SetScale(1)

O.frame:Hide();X.profile.scale=1;X.profile.fontSize=14;X.profile.placement="top";X:ApplyProfile()
W.xp=7242;W.cap=8800;W.rested=0;X:Sample()
X.session.total=5800;X.session.seconds=3600;X.session.buckets={kills=1600,quests=3200,dungeons=900,other=100};X.session.incomplete=false
X.session.rate={version=1,startedAt=0,buckets={}}
for minute=0,59 do
    X.session.seconds=minute*60
    local index=ns.Model.RateAward(X.session,5800/60);ns.Model.RateKill(X.session,index,1600/60)
end
X.session.seconds=3600
UI:SetExpanded(false);W.svg("dist/preview-collapsed.svg",UI.frame)
UI:SetExpanded(true);W.svg("dist/preview-expanded.svg",UI.frame)
O.frame:Show();W.svg("dist/preview-options.svg",O.frame)
O:Page(true);W.svg("dist/preview-profiles.svg",O.frame)
print("PASS: "..n.." runtime/UI assertions; SVG previews use a mocked WoW UI")
