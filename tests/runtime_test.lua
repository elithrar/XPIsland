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
W.click(UI.frame);W.advance(.25);eq(UI.expanded,true)
eq(UI.frame:GetWidth(),520);eq(UI.cells[4].value:GetText(),"500")
W.advance(61);eq(X.session.seconds>=61,true,"connected timer")
eq(UI.cells[2].value:GetText()~="—",true,"rate after a minute")
W.event("PLAYER_LEAVING_WORLD")
local seconds=X.session.seconds
W.advance(200);X:Clock();eq(X.session.seconds,seconds+200,"loading is gameplay downtime")
W.event("PLAYER_ENTERING_WORLD",false,false);W.advance(1);X:Clock()
eq(X.session.seconds,seconds+201)
W.level=11;W.xp=25;W.cap=1200;W.event("PLAYER_LEVEL_UP",11);W.advance(2.1)
eq(X.session.total,925,"runtime level rollover")
eq(UI.expanded,true,"level expansion")
W.advance(10);eq(UI.expanded,false,"ten-second collapse")
X:LevelUp();W.click(UI.frame);local manual=UI.expanded
W.advance(20);eq(UI.expanded,manual,"manual interaction cancels timer")
X:LevelUp();W.advance(5);X:LevelUp();W.advance(5)
eq(UI.expanded,true,"replacement level-up timer restarts its full duration")
W.advance(5);eq(UI.expanded,false,"replacement timer expires after ten seconds")

SlashCmdList.XPISLAND_SND_XPISLAND("")
eq(O.panel:IsShown(),true,"slash opens shared options")
local app=ns.App
W.control('scale'):SetValue(1.25);eq(X.profile.scale,1.25,"slider commits settings")
local size=W.control('fontSize');size:SetText('16');size.scripts.OnEnterPressed(size)
eq(X.profile.fontSize,16,"number control commits settings")
W.control('scale'):SetValue(.75);eq(X.profile.scale,.75)
local function color(key) W.open('appearance');W.click(W.control(key));return W.colorInfo end
local preview=color('normal');preview.swatchFunc()
eq(X.profile.normal[1],.64,"preview never mutates settings")
eq(XPIslandDB.profiles.Shared.normal[1],.64,"preview never mutates SavedVariables")
eq(UI:ColorValue('normal')[1],.1,"preview repaints island")
preview.cancelFunc();eq(UI:ColorValue('normal')[1],.64,"cancel restores paint")
local stale=color('normal');stale.swatchFunc()
assert(app.profiles:Duplicate('Color target'))
eq(ColorPickerFrame:IsShown(),false,"profile switch closes picker")
stale.swatchFunc();stale.cancelFunc();eq(X.profile.normal[1],.64,"stale picker cannot edit replacement")
local accepted=color('normal');accepted.swatchFunc();ColorPickerFrame:Hide();accepted.swatchFunc();W.advance(0)
eq(X.profile.normal[1],.1,"Okay after native hide commits")
W.set('normal',{.6,.5,.4})
local cancelled=color('normal');cancelled.swatchFunc();ColorPickerFrame:Hide();cancelled.cancelFunc();W.advance(0)
eq(X.profile.normal[1],.6,"Cancel after native hide preserves original")
local replaced=color('rested');local newer=color('normal');W.advance(0)
replaced.swatchFunc();replaced.cancelFunc();eq(W.colorInfo,newer,"old picker cannot retire replacement")
newer.swatchFunc();O.panel:Close();eq(ColorPickerFrame:IsShown(),false,"close dismisses owned picker")
local foreignStale=color('rested');ColorPickerFrame:SetupColorPickerAndShow({extraInfo={foreign=true}})
O.panel:Close();foreignStale.swatchFunc();foreignStale.cancelFunc()
eq(ColorPickerFrame:IsShown(),true,"closing owned edit preserves foreign picker")
ColorPickerFrame:Hide();W.advance(0)
assert(app.profiles:Switch('Shared'));local copied=color('normal');copied.swatchFunc()
assert(app.profiles:CopyFrom('Color target'));eq(ColorPickerFrame:IsShown(),false,"copy cancels picker")
local copyValue=X.profile.normal[1];copied.swatchFunc();copied.cancelFunc();eq(X.profile.normal[1],copyValue)
W.set('normal',ns.Model.defaults.normal);color('normal').swatchFunc();O:Page(true)
eq(ColorPickerFrame:IsShown(),false,"page change cancels picker");eq(X.profile.normal[1],.64)
assert(app.profiles:Duplicate('Solo'));W.set('scale',1.2);eq(XPIslandDB.profiles.Shared.scale,.75,"profiles remain independent")
W.set('normal',{.27,.35,.94});local session=X.session;assert(app.profiles:Switch('Shared'));eq(X.session,session)
local panel=W.open('profiles');local pool=panel._pool
W.choose(pool['profile-copy'],'Solo');W.click(pool['profile-copy-button']);eq(X.profile.normal[1],.64,"copy requires confirmation")
W.click(pool['profile-confirm']);eq(X.profile.normal[1],.27,"confirmed copy applies source")
W.set('normal',{.14,.35,.94});eq(XPIslandDB.profiles.Solo.normal[1],.27,"copied colors do not alias")
W.set('normal',ns.Model.defaults.normal)
-- Theme changes share one app appearance owner; gameplay colors stay explicit.
W.open('appearance');W.choose(W.control('theme'),'forever')
eq(X.profile.theme,'forever');eq(O.frame.backdrop.edgeFile,'Interface\\DialogFrame\\UI-DialogBox-Border')
eq(UI.label.color[1],ns.SomethingNeedDoing.Themes.forever.colors.text[1])
W.choose(W.control('theme'),'modern');eq(X.profile.theme,'modern')
local escapeName
for _,name in ipairs(UISpecialFrames)do if _G[name]==O.frame then escapeName=name end end
eq(escapeName,'XPIsland_SND_Options','shared shell registers native Escape dismissal')
local escapeEdit=color('normal');escapeEdit.swatchFunc();_G[escapeName]:Hide()
eq(O.panel:IsShown(),false);eq(ColorPickerFrame:IsShown(),false,'native Escape hide cancels transient editor')
escapeEdit.swatchFunc();eq(X.profile.normal[1],.64,'dismissed picker cannot commit')

W.capped=true;W.event("PLAYER_MAX_LEVEL_UPDATE");eq(UI.frame:IsShown(),false,"hide at cap")
W.capped=false;W.event("PLAYER_MAX_LEVEL_UPDATE");eq(UI.frame:IsShown(),true)
W.event("PLAYER_CAMPING");W.event("LOGOUT_CANCEL");eq(X.cleanIntent,nil)


for _,vw in ipairs({1024,1399,1400,1999,2000,3840}) do
    UIParent:SetWidth(vw)
    for _,scale in ipairs({.5,1,1.5}) do
        for _,format in ipairs({"percent","fraction","left","leftPercent"}) do
            W.set('scale',scale);W.set('format',format);W.set('fontSize',18)
            W.set('position',{x=9000,y=-9000});UI:SetExpanded(true,true)
            local x,y,w,h=UI.frame:Rect()
            eq(x>=0 and x+w<=vw,true,"horizontal clamping")
            eq(y>=0 and y+h<=UIParent:GetHeight(),true,"vertical clamping")
            eq(UI.segments[1].width>0,true,"long-label segment width")
        end
    end
end
UIParent:SetWidth(1728);W.set('position',{x=0,y=-8});W.set('format',"percent")
for _,rootScale in ipairs({.64,.8,1,1.2}) do
    UIParent:SetScale(rootScale);W.set('scale',1.25);UI:SetExpanded(true,true)
    eq(UI.frame:GetEffectiveScale(),rootScale*1.25,"effective WoW and addon scale")
    eq(UI.frame:GetWidth(),520,"logical tier does not use render pixels")
end
UIParent:SetScale(1)

O.panel:Close();W.set('scale',1);W.set('fontSize',14);W.set('placement',"top");X:ApplyProfile()
W.xp=7242;W.cap=8800;W.rested=0;X:Sample()
X.session.total=5800;X.session.seconds=3600;X.session.buckets={kills=1600,quests=3200,dungeons=900,other=100};X.session.incomplete=false
X.session.rate={version=1,startedAt=0,buckets={}}
for minute=0,59 do
    X.session.seconds=minute*60
    local index=ns.Model.RateAward(X.session,5800/60);ns.Model.RateKill(X.session,index,1600/60)
end
X.session.seconds=3600
UI:SetExpanded(false,true);W.svg("dist/preview-collapsed.svg",UI.frame)
UI:SetExpanded(true,true);W.svg("dist/preview-expanded.svg",UI.frame)
W.open();W.svg("dist/preview-options.svg",O.frame)
O:Page(true);W.svg("dist/preview-profiles.svg",O.frame)
print("PASS: "..n.." runtime/UI assertions; SVG previews use a mocked WoW UI")

-- Each logout ends a native client lifetime: SND deliberately disposes its scopes.
-- Verify every checkpoint reason in a fresh lifetime, including scope cleanup.
for _,reason in ipairs({"clean","reload","departed"}) do
    local client=dofile("tests/wow_mock.lua");local fresh=client.load()
    client.event("ADDON_LOADED","XPIsland");client.event("PLAYER_ENTERING_WORLD",true,false)
    if reason=="clean" then Logout() elseif reason=="reload" then ReloadUI() end
    client.event("PLAYER_LOGOUT")
    eq(XPIslandSession.reason,reason)
    eq(fresh.App:IsReady(),false,"logout disposes scoped callbacks")
    eq(SlashCmdList.XPISLAND_SND_XPISLAND,nil,"logout removes owned slash command")
end

-- Protect the new ownership boundary: a legacy account database must round-trip
-- through SND without changing character choice, sharing nested values or leaking
-- transient edits into SavedVariables. Sessions are exercised independently above.
do
    XPIslandDB={version=1,expandedOnce=true,characters={['Player-1']='Existing'},profiles={
        Shared={font='Arial',fontSize=12},Existing={font='Arial',fontCustomized=true,fontSize=16,normal={.2,.3,.4}}}}
    local client=dofile('tests/wow_mock.lua');local fresh=client.load()
    client.event('ADDON_LOADED','XPIsland')
    eq(fresh.App.profiles:Capabilities().needsCharacter,true,'identity binding waits for world entry')
    client.event('PLAYER_ENTERING_WORLD',true,false)
    eq(fresh.owner.profileName,'Existing');eq(fresh.owner.profile.font,'Arial')
    eq(XPIslandDB.version,2);eq(XPIslandDB.profiles.Shared.font,'Game tooltip','legacy default migrates once')
    local prior=XPIslandDB
    eq(fresh.App:SetMany({scale=1.2,fontSize=99}),false,'invalid batch rejects all fields')
    eq(XPIslandDB,prior,'failed batch publishes no saved replacement');eq(fresh.owner.profile.scale,1)
    assert(fresh.App:SetMany({scale=1.2,fontSize=17}));eq(fresh.owner.profile.fontSize,17)
    local detached=fresh.App:Get('normal');detached[1]=.9
    eq(XPIslandDB.profiles.Existing.normal[1],.2,'reads cannot mutate the saved owner')
    assert(fresh.App.profiles:Duplicate('Independent'));assert(fresh.App:Set('normal',{.8,.7,.6}))
    eq(XPIslandDB.profiles.Existing.normal[1],.2,'profile copy has independent nested data')
    assert(fresh.App.profiles:Reset());eq(XPIslandDB.expandedOnce,true,'reset preserves account onboarding')
    eq(XPIslandDB.profiles.Independent.expandedOnce,nil,'onboarding is never copied into profile storage')
    client.open('behavior');client.click(client.control('character','behavior'))
    eq(fresh.owner.profileName,fresh.owner.characterName,'character shortcut uses profile command')
    eq(fresh.Options.integrationText:GetText():find('Key binding:',1,true)~=nil,true,'custom status preserves binding information')
    eq(XPIslandDB.characters[fresh.owner.character],fresh.owner.characterName)
    client.click(client.control('shared','behavior'));eq(fresh.owner.profileName,'Shared')
    assert(fresh.App:Set('locked',false));fresh.UI.frame.scripts.OnDragStart();fresh.UI.frame.scripts.OnDragStop()
    eq(fresh.owner.profile.placement,'custom');eq(XPIslandDB.profiles.Shared.position.x,fresh.owner.profile.position.x)
    eq(XPIslandDB.profiles.Shared.position.y,fresh.owner.profile.position.y,'drag commits both axes')
    -- Native drag-stop can arrive after a settings replacement, even on the same
    -- named profile. It must not publish coordinates from the previous gesture.
    for _,operation in ipairs({'switch','reset','copy'})do
        assert(fresh.App:SetMany({locked=false,['position.x']=25,['position.y']=-80,placement='custom'}))
        fresh.UI.frame.scripts.OnDragStart();eq(fresh.UI.dragging,true)
        if operation=='switch' then assert(fresh.App.profiles:Switch('Existing'))
        elseif operation=='reset' then assert(fresh.App.profiles:Reset())
        else assert(fresh.App.profiles:CopyFrom('Existing')) end
        eq(fresh.UI.dragging,nil,'settings replacement cancels native movement')
        local saved=fresh.App:Get('position.x');local savedY=fresh.App:Get('position.y')
        fresh.UI.frame.scripts.OnDragStop()
        eq(fresh.App:Get('position.x'),saved,'stale drag cannot write replacement profile')
        eq(fresh.App:Get('position.y'),savedY)
        assert(fresh.App.profiles:Switch('Shared'))
    end
end
print('PASS: settings adapter ownership, legacy restoration, atomic edits, character shortcuts and drag persistence')

-- Binding an already-selected Shared profile changes persistence context without
-- changing selector values. The first gesture after reload still owns a fresh token.
do
    local client=dofile('tests/wow_mock.lua')
    XPIslandDB={version=2,characters={['Player-1']='Shared'},profiles={Shared={locked=false}}}
    local fresh=client.load();client.event('ADDON_LOADED','XPIsland');client.event('PLAYER_ENTERING_WORLD',true,false)
    fresh.UI.frame.scripts.OnDragStart();fresh.UI.frame.scripts.OnDragStop()
    eq(fresh.owner.profile.placement,'custom','first saved-unlocked drag commits after identity-only binding')
end
