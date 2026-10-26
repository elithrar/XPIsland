-- Real addon entry points; optional pinned Forever MenuUtil execution. No game renderer/taint engine.
local W=dofile('tests/wow_mock.lua')
local n=0
local function eq(a,b,why) n=n+1;assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,why) n=n+1;assert(math.abs(a-b)<.001,(why or 'near')..': '..a..' ~= '..b) end
local menuManager={opens=0}
function menuManager:OpenContextMenu(owner,root)
    assert(not W.combat,'native context creation in combat')
    if self.current then self.current:Close() end
    local menu=W.poolMenus and self.pooled or {}
    menu=menu or {};self.pooled=menu
    menu.owner,menu.root,menu.open,menu.closed=owner,root,true,nil
    function menu:SetClosedCallback(callback) self.closed=callback end
    function menu:Close()
        if not self.open then return end
        self.open=false
        if menuManager.current==self then menuManager.current=nil end
        if self.closed then self.closed(self) end
    end
    self.current=menu;self.opens=self.opens+1
    return menu
end
local function rootDescription()
    local root={entries={}}
    function root:Insert(entry) self.entries[#self.entries+1]=entry;return entry end
    function root:CreateRadio(text,selected,choose,value)
        return self:Insert({label=text,isSelected=selected,select=choose,value=value})
    end
    function root:CreateDivider() return self:Insert({divider=true}) end
    return root
end
MenuUtil={CreateContextMenu=function(owner,generator)
    local root=rootDescription();generator(owner,root)
    return menuManager:OpenContextMenu(owner,root)
end}
if arg[1] then
    -- Execute Blizzard's unchanged utility and Classic variant. Description and
    -- menu-manager doubles stop at the native rendering boundary.
    MenuStyle2Mixin={}
    MenuVariants={}
    assert(loadfile(arg[1]..'/Blizzard_Menu/Vanilla/MenuVariants.lua'))()
    eq(MenuVariants.GetDefaultContextMenuMixin(),MenuStyle2Mixin,'native context style')
    MenuTemplates=setmetatable({}, {__index=function() return function() end end})
    function MenuTemplates.CreateRadio(text,selected,choose,value)
        return {label=text,isSelected=selected,select=choose,value=value}
    end
    function MenuTemplates.CreateDivider() return {divider=true} end
    Menu={CreateRootMenuDescription=function(mixin)
        eq(mixin,MenuStyle2Mixin,'native default context mixin')
        return rootDescription()
    end,PopulateDescription=function(generator,owner,root,...) generator(owner,root,...) end,
    GetManager=function() return menuManager end}
    function securecallfunction(fn,...) return fn(...) end
    SOUNDKIT={IG_MAINMENU_OPTION_CHECKBOX_ON=1}
    function PlaySound() end
    assert(loadfile(arg[1]..'/Blizzard_Menu/MenuUtil.lua'))()
    local functions={}
    APIDocumentation={AddDocumentationTable=function(_,doc)
        for _,enum in ipairs(doc.Tables or {}) do
            if enum.Type=='Enumeration' then
                Enum[enum.Name]={}
                for _,field in ipairs(enum.Fields) do Enum[enum.Name][field.Name]=field.EnumValue end
            end
        end
        for _,f in ipairs(doc.Functions or {}) do functions[f.Name]=f end
    end}
    for _,name in ipairs({'SecretAspectConstants','ForbiddenAspectConstants','SimpleFrameAPI','SimpleButtonAPI','SimpleScriptRegionAPI'}) do
        assert(loadfile(arg[1]..'/Blizzard_APIDocumentationGenerated/'..name..'Documentation.lua'))()
    end
    eq(functions.RegisterForClicks.Arguments[1].Type,'ClickButton')
    eq(functions.RegisterForDrag.Arguments[1].Type,'MouseButton')
    eq(functions.GetScript.Returns[1].Type,'LuaFunctionReference')
    local file=assert(io.open(arg[1]..'/Blizzard_Menu/Menu.lua'));local source=file:read('*a');file:close()
    eq(source:find('function MenuProxyMixin:Close()',1,true)~=nil,true,'proxy supports owned close')
    eq(source:find('"SetClosedCallback"',1,true)~=nil,true,'proxy exports native closed callback')
end
local ns=W.load()
local X,UI,O,M=ns.owner,ns.UI,ns.Options,ns.Model
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false)
local target=UI.indicator
local function open()
    W.click(target,'RightButton')
    return assert(menuManager.current,'menu failed to open')
end
local function entry(menu,value)
    for _,row in ipairs(menu.root.entries) do if row.value==value then return row end end
    error('missing mode '..value)
end
local function choose(menu,value) entry(menu,value).select(value) end
eq(O.frame,nil,'quick menu does not create the options window')
local menu=open()
eq(menu.owner,target,'native owner is the indicator')
eq(#menu.root.entries,9)
eq(entry(menu,'xp').label,'Experience');eq(entry(menu,'pvp').label,'Honor & PvP')
eq(entry(menu,'xp').isSelected('xp'),true);eq(menu.root.entries[3].divider,true)
eq(entry(menu,'percent').isSelected('percent'),true,'saved current mode marked')
eq(UI.expanded,false,'right click does not expand')
local opens=menuManager.opens
W.click(UI.frame,'RightButton');eq(menuManager.opens,opens,'outer bar does not accept right clicks')
eq(UI.bar.scripts.OnMouseUp,nil);eq(UI.bar.scripts.OnClick,nil,'no whole-bar context handler')
eq(UI.frame.clickButtons,nil,'outer click registration unchanged')
eq(target.dragButtons[1],'LeftButton')

-- Compare every menu entry with the settings dropdown, then exercise every setter.
W.open()
for _,mode in ipairs({'xp','pvp'}) do
    W.set('mode',mode);X:ApplyProfile()
    local dropdown=mode=='xp' and W.control('format','tracking') or W.control('pvpFormat','tracking')
    local key=mode=='xp' and 'format' or 'pvpFormat'
    for _,row in ipairs(dropdown.menuDescription.entries) do
        menu=open()
        eq(#menu.root.entries,#dropdown.menuDescription.entries+3,'mode choices plus same label options')
        eq(entry(menu,row.value).label,row.label,'same user-facing label')
        choose(menu,row.value)
        eq(X.profile[key],row.value,'active profile updated')
        eq(XPIslandDB.profiles[X.profileName][key],row.value,'saved variables updated')
        eq(dropdown.Text:GetText(),row.label,'created settings synchronize immediately')
        eq(O.indicatorMenu,nil,'selection closes owned popup')
        menu=open();eq(entry(menu,row.value).isSelected(row.value),true,'reopened selection marked');menu:Close()
    end
end
W.set('mode','xp');X:ApplyProfile();O.panel:Close()
menu=open();choose(menu,'left');eq(UI.label:GetText(),M.Label('left',X.tracker.xp,X.tracker.cap),'label updates immediately')
W.open();eq(W.control('format','tracking').Text:GetText(),'XP remaining','settings reopened after quick change');O.panel:Close()
local restored=M.Database(M.Copy(XPIslandDB))
eq(M.SelectProfile(restored,X.character,X.profileName).format,'left','database reload preserves choice')
assert(ns.App.profiles:Duplicate('Other'))
menu=open();choose(menu,'fraction');eq(XPIslandDB.profiles.Other.format,'fraction');eq(XPIslandDB.profiles.Shared.format,'left','other profiles preserved')
menu=open();local stale=entry(menu,'eta');O:Switch('Shared');stale.select('eta')
eq(X.profile.format,'left','stale callback cannot change switched profile')

-- Auto-switching resolves choices from the displayed bar, without changing mode policy.
W.set('pvpAtCap',true);W.level=60;X:RefreshMode();UI:Update()
menu=open();eq(#menu.root.entries,5,'automatic PvP gets PvP choices');choose(menu,'rankLeft')
eq(X.profile.pvpAtCap,true);eq(X.profile.mode,'xp');eq(X.profile.pvpFormat,'rankLeft')
W.level=10;X:RefreshMode();UI:Update()
menu=open();stale=entry(menu,'eta');W.set('mode','pvp');X:ApplyProfile();stale.select('eta')
eq(X.profile.format,'left','stale callback cannot change previous bar mode')
W.set('mode','xp');X:ApplyProfile()

-- Manual mode selection shares settings semantics, including choosing the
-- displayed automatic mode. XP disabled below cap must not force PvP.
W.level=60;W.set('pvpAtCap',true);X:ApplyProfile()
menu=open();eq(entry(menu,'pvp').isSelected('pvp'),true)
choose(menu,'pvp');eq(X.profile.mode,'pvp');eq(X.profile.pvpAtCap,false)
W.open('tracking');eq(W.control('mode','tracking').Text:GetText(),'Honor & PvP');O.panel:Close();eq(UI.expanded,false)
local totals=X.session.total;local xpFormat=X.profile.format;local pvpFormat=X.profile.pvpFormat
menu=open();stale=entry(menu,'pvp');choose(menu,'xp')
eq(X.profile.mode,'xp');eq(X.profile.pvpAtCap,false);eq(UI.frame:IsShown(),false,'XP at cap hides normally')
stale.select('pvp');eq(X.profile.mode,'xp','dismissed mode callback is stale')
W.level=10;W.capped=true;W.set('pvpAtCap',true);X:ApplyProfile();eq(X:Mode(),'xp')
W.capped=false;X:ApplyProfile();menu=open();choose(menu,'pvp')
eq(X.session.total,totals,'switching retains XP');eq(X.profile.format,xpFormat);eq(X.profile.pvpFormat,pvpFormat)
eq(XPIslandDB.profiles[X.profileName].mode,'pvp','mode persists in active profile')
local modeRestore=M.Database(M.Copy(XPIslandDB))
eq(M.SelectProfile(modeRestore,X.character,X.profileName).mode,'pvp')
menu=open();stale=entry(menu,'xp');W.combat=true;stale.select('xp');eq(X.profile.mode,'pvp')
W.event('PLAYER_REGEN_DISABLED');W.combat=false;W.event('PLAYER_REGEN_ENABLED');stale.select('xp')
eq(X.profile.mode,'pvp','combat-dismissed mode choice stays stale')
menu=open();choose(menu,'xp');W.open('tracking');eq(W.control('mode','tracking').Text:GetText(),'Experience');O.panel:Close()

-- Native menu frame proxies are pooled. Old closures must not gain ownership
-- when the exact same proxy is reused for a later menu on the same profile.
W.poolMenus=true
menu=open();stale=entry(menu,'eta');local staleClose=menu.closed;menu:Close()
local reopened=open();eq(reopened,menu,'pooled native proxy reused')
stale.select('eta');eq(X.profile.format,'left','pooled old row cannot change new menu')
staleClose();eq(O.indicatorMenu~=nil,true,'pooled old close callback cannot dismiss new ownership')
reopened:Close();W.poolMenus=false

-- Combat opening, queued callbacks before event delivery, entry while open, and no reopening.
for _,collapse in ipairs({true,false}) do
    W.set('collapseCombat',collapse);UI:SetExpanded(true,true);X:ArmCollapse(15)
    menu=open();stale=entry(menu,'eta')
    W.combat=true;stale.select('eta');eq(X.profile.format,'left','callback gates combat before event')
    opens=menuManager.opens;W.click(target,'RightButton');eq(menuManager.opens,opens,'combat never opens')
    W.event('PLAYER_REGEN_DISABLED');eq(menu.open,false);eq(O.indicatorMenu,nil,'combat entry dismisses regardless of collapse policy')
    W.combat=false;W.event('PLAYER_REGEN_ENABLED');stale.select('eta')
    eq(X.profile.format,'left','dismissed callback stays stale after combat')
    eq(menuManager.current,nil,'combat end never reopens')
end

-- Label slot remains isolated through fonts, scales, placements, formats and motion.
W.set('autoCollapse',false)
for _,placement in ipairs({'top','bottom','custom'}) do
 for _,scale in ipairs({.5,1,1.5}) do
  for _,format in ipairs({'percent','fraction','leftPercent','eta','kills'}) do
   W.set('placement',placement);W.set('scale',scale);W.set('format',format);W.set('fontSize',18);X:ApplyProfile()
   UI:SetExpanded(false,true);UI:SetExpanded(true)
   for step=1,4 do
    W.advance(.06)
    local tx,ty,tw,th=target:Rect();local lx,ly,lw,lh=UI.label:Rect()
    near(tx,lx,'target starts at label');near(ty,ly);near(tw,lw);near(th,lh)
    local bx,_,bw=UI.segments[20].track:Rect()
    eq(tx>bx+bw,true,'hit target never reaches XP cells')
   end
  end
 end
end
W.set('format','eta');X.session=M.NewSession(X.character,GetServerTime());X.tracker.session=X.session;X:ApplyProfile()
eq(UI.showInfinity,true,'empty ETA renders the infinity placeholder')
menu=open();eq(entry(menu,'eta').isSelected('eta'),true,'infinity remains clickable');menu:Close()

-- Existing click/drag/hover behavior, locked drag, timer suspension and owned cleanup.
UI:SetExpanded(false,true);W.click(target);eq(UI.expanded,true,'indicator left click preserves toggle');W.advance(.3)
W.set('locked',true);target.scripts.OnDragStart(target);eq(UI.dragging,nil,'locked label drag stays locked')
W.set('locked',false);menu=open();target.scripts.OnDragStart(target)
eq(menu.open,false,'drag closes popup');eq(UI.dragging,true);eq(UI.frame.moving,true)
opens=menuManager.opens;W.click(target,'RightButton');eq(menuManager.opens,opens,'no menu while moving')
target.scripts.OnDragStop(target);eq(UI.dragging,nil);eq(X.profile.placement,'custom');eq(UI.frame.moving,false)
W.click(target);eq(UI.expanded,true,'post-drag synthetic click suppressed')
W.hover=target;target.scripts.OnEnter(target);eq(W.tooltip.shown,true,'label hover preserves tooltip')
W.hover=nil;target.scripts.OnLeave(target)
W.set('autoCollapse',true);X:ApplyProfile();UI:SetExpanded(true,true);X:ArmCollapse(15)
menu=open();W.advance(30);eq(UI.expanded,true,'popup interaction holds expanded island')
menu:Close();W.advance(14.9);eq(UI.expanded,true);W.advance(.1);eq(UI.expanded,false,'dismissal arms a fresh interval')
menu=open();UI.bar:Hide();eq(O.indicatorMenu,nil,'level notice hiding bar closes popup')
UI.bar:Show();menu=open();UI.frame:Hide();eq(O.indicatorMenu,nil,'island hide closes popup');UI.frame:Show()
local objects=#W.objects
for i=1,100 do menu=open();menu:Close() end
eq(#W.objects,objects,'reopening adds no addon-owned UI objects')
menu=open();choose(menu,'leftPercent')
menu=open();choose(menu,'pvp')
local W2=dofile('tests/wow_mock.lua');local ns2=W2.load()
W2.event('ADDON_LOADED','XPIsland');W2.event('PLAYER_ENTERING_WORLD',true,false)
eq(ns2.owner.profile.format,'leftPercent','fresh addon initialization restores saved selection')
eq(ns2.owner.profile.mode,'pvp','fresh initialization restores manual mode')
eq(ns2.owner.profile.pvpAtCap,false,'manual mode retains disabled auto-switch policy')
W2.open('tracking')
eq(W2.control('format','tracking').Text:GetText(),'XP remaining (%)','fresh settings reflect restored selection')
print('PASS: '..n..' indicator menu assertions'..(arg[1] and '; pinned Forever MenuUtil executed' or ''))
