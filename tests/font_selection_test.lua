-- CallbackHandler accepts method names and multiple owners for each event.
local function registerMedia(callbacks, owner, event, callback)
    local previous = callbacks[event]
    callbacks[event] = function(...)
        if previous then previous(...) end
        if type(callback)=="string" then owner[callback](owner, ...) else callback(...) end
    end
end
-- Native menu compositor contract, font propagation, and failed-family recovery.
-- Font loading here is simulated; real client glyph/raster validation is separate.
local W=dofile("tests/wow_mock.lua")
local fonts={Expressway="Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF",
    ["Friz Quadrata TT"]="Fonts\\FRIZQT__.TTF",
    ["2002"]="Fonts\\2002.TTF",["2002 Bold"]="Fonts\\2002B.TTF",
    ["Missing font"]="Interface\\AddOns\\Missing\\font.ttf"}
local lsm={callbacks={},registrations=0}
function lsm:List(kind) local out={};for name in pairs(fonts)do out[#out+1]=name end;return out end
function lsm:HashTable(kind) assert(kind=="font");return fonts end
function lsm:IsValid(kind,name) return kind=="font" and fonts[name]~=nil end
function lsm:Fetch(kind,name) assert(kind=="font");return fonts[self.override or name] end
function lsm.RegisterCallback(receiver,event,callback)
    registerMedia(lsm.callbacks,receiver,event,callback);lsm.registrations=lsm.registrations+1
end
function LibStub(name,silent) assert(name=="LibSharedMedia-3.0" and silent);return lsm end
local ns=W.load()
local X,UI,O=ns.owner,ns.UI,ns.Options
local assertions=0
local function eq(a,b,why) assertions=assertions+1;assert(a==b,(why or "assertion")..": "..tostring(a).." ~= "..tostring(b)) end
W.event("ADDON_LOADED","XPIsland");W.event("PLAYER_ENTERING_WORLD",true,false)
W.event("UPDATE_BINDINGS");W.event("PLAYER_REGEN_ENABLED")
eq(O.frame,nil,"events before first options open preserve lazy construction")
SlashCmdList.XPISLAND_SND_XPISLAND("")
local tooltipFont=GameTooltipText:GetFont()
local function islandChild(o)
    while o do if o==UI.frame then return true end;o=o.parent end
    return false
end
local function allSurfaces(expected)
    for _,o in ipairs(W.objects) do
        if o.kind=="FontString" and islandChild(o) then
            eq(o:GetFont(),expected,"island font family propagates to every title/value")
        end
    end
    for _,text in pairs(O.panel._texts) do eq(text:GetFont(),expected,'shared options text uses selected family') end
    for _,menu in pairs(O.panel._menus) do eq(menu.Text:GetFont(),expected,'selected menu text uses selected family') end
    for _,control in pairs(O.panel._pool)do if control.kind=='EditBox' then eq(control:GetFont(),expected,'edit box uses selected family')end end
    if O.integrationText then eq(O.integrationText:GetFont(),expected,'consumer status component follows shared fonts')end
    eq(O.panel._menuFont:GetFont(),expected,"shared menu Font uses selected family")
end
-- Protect the actual compositor restriction, font propagation and downgrade
-- recovery; these are native boundaries shared by XPIsland and the SND shell.
for _,page in ipairs({'appearance','behavior','tracking','profiles'})do W.open(page) end
W.open('appearance')
for _,dropdown in pairs(O.panel._menus) do
 dropdown:GenerateMenu()
 for _,entry in ipairs(dropdown.menuDescription.entries) do
  local selectedFont
  local guarded=setmetatable({SetFontObject=function(_,font)selectedFont=font end},{__index=function(_,key)error('Forbidden compositor lookup: '..key)end})
  entry.initializer({fontString=guarded});eq(selectedFont,O.panel._menuFont,'native rows use a shared Font object')
 end
end
local function choose(name) W.open('appearance');W.choose(W.control('font'),name) end
for _,name in ipairs({'Expressway','2002','2002 Bold','Arial','Friz Quadrata','Game tooltip'})do
 choose(name);allSurfaces(fonts[name] or (name=='Arial' and 'Fonts\\ARIALN.TTF' or tooltipFont))
 eq(X.profile.font,name);eq(W.control('font').Text:GetText(),name,'selected caption remains visible')
 eq(O.panel._pool['tab:profiles'].text:GetText(),'Profiles')
end
-- Repair a native/global font pass without changing the user's preference.
choose('Expressway');UI.cells[1].title:SetFont(tooltipFont,12,'');O.panel._menuFont:SetFont(tooltipFont,18,'')
ns.App.fonts:Refresh();allSurfaces(fonts.Expressway)
local _,menuSize=O.panel._menuFont:GetFont();eq(menuSize,13,'shared menu role size repaired')
W.fontFailures={[fonts['2002']]=true};choose('2002');allSurfaces(tooltipFont)
eq(X.profile.font,'2002','fallback preserves preference')
W.fontFailures=nil;lsm.callbacks.LibSharedMedia_Registered('LibSharedMedia_Registered','font','2002');allSurfaces(fonts['2002'])
for _,target in ipairs({UI.cells[1].title,W.control('font').Text,O.panel._menuFont})do
 choose('Arial');local original=target.SetFont
 target.SetFont=function(self,path,...)if path==fonts.Expressway then return false end;return original(self,path,...)end
 choose('Expressway');allSurfaces(tooltipFont);eq(UI.layout.font,tooltipFont,'layout remeasures shared fallback')
 target.SetFont=original;lsm.callbacks.LibSharedMedia_Registered('LibSharedMedia_Registered','font','Expressway');allSurfaces(fonts.Expressway)
end
local original=O.panel._menuFont.SetFont;O.panel._menuFont.SetFont=function()return false end
choose('Arial');allSurfaces(GameFontNormal:GetFont());eq(UI.layout.font,GameFontNormal:GetFont(),'native fallback reflows island')
O.panel._menuFont.SetFont=original;lsm.callbacks.LibSharedMedia_Registered('LibSharedMedia_Registered','font','Arial');allSurfaces('Fonts\\ARIALN.TTF')
-- A fallback discovered during a layout (without a settings transaction) must
-- remeasure earlier text immediately, not leave stale geometry until the ticker.
choose('Expressway');local title=UI.cells[1].title;local setter=title.SetFont
setter(title,tooltipFont,12,'')
title.SetFont=function(self,path,...)if path==fonts.Expressway then return false end;return setter(self,path,...)end
UI:Layout(true);allSurfaces(tooltipFont);eq(UI.layout.font,tooltipFont,'late layout rejection settles geometry immediately')
title.SetFont=setter;ns.App.fonts:Refresh();allSurfaces(fonts.Expressway)
-- Late providers and global media changes refresh hidden as well as visible text.
O.panel:Close();W.set('font','Late font');allSurfaces(tooltipFont)
fonts['Late font']='Interface\\AddOns\\LateMedia\\font.ttf'
lsm.callbacks.LibSharedMedia_Registered('LibSharedMedia_Registered','font','Late font');allSurfaces(fonts['Late font'])
lsm.override='2002';lsm.callbacks.LibSharedMedia_SetGlobal('LibSharedMedia_SetGlobal','font','2002');allSurfaces(fonts['2002']);eq(X.profile.font,'Late font')
lsm.override=nil;lsm.callbacks.LibSharedMedia_SetGlobal('LibSharedMedia_SetGlobal','font',nil);allSurfaces(fonts['Late font'])
for _=1,3 do W.event('ADDON_LOADED','OtherMedia') end
eq(lsm.registrations,2,'one SND owner for each media event; no consumer media subscription')
W.open('appearance')
local rebuilds=0
for _,menu in pairs(O.panel._menus)do local generate=menu.GenerateMenu;menu.GenerateMenu=function(self,...)rebuilds=rebuilds+1;return generate(self,...)end end
for _=1,10 do UI:Layout(true)end
eq(rebuilds,0,'gameplay layout never rebuilds native option menus')
local font=W.control('font');W.click(font);local before=rebuilds
lsm.callbacks.LibSharedMedia_Registered('LibSharedMedia_Registered','font','Late font')
eq(rebuilds,before,'media change does not rebuild a menu under input')
font:CloseMenu();W.advance(.01);eq(rebuilds>before,true,'refresh resumes after native menu release')
local longName='A deliberately long shared profile and font name';fonts[longName]=fonts['Late font']
W.set('font',longName);assert(ns.App.profiles:Duplicate(longName))
for _,viewport in ipairs({{384,300},{800,600},{1920,1080}})do
 UIParent:SetSize(unpack(viewport));W.open('appearance');O:Refresh()
 local control=W.control('font');eq(control._fullCaption,longName,'full identity retained for tooltip')
 eq(control.Text:GetUnboundedStringWidth()<=control.Text:GetWidth(),true,'selected text fits its allocation')
 eq(control.Text.justify,'CENTER','selected caption is centered')
end
W.open('profiles');eq(O.panel._pool['profile-select']._fullCaption,longName)
local menuFont=O.panel._menuFont
for _=1,10 do O.panel:Close();W.open();O:Refresh() end
eq(O.panel._menuFont,menuFont,'menu font reused across refresh/reopen')
eq(GameTooltipText:GetFont(),tooltipFont,'global tooltip font never mutated')
-- These real consumer actions were wider than the shared fixed buttons. Keep
-- their complete captions legible after font/settings refresh, including physical
-- pixel rounding; checking only dropdowns misses this independent clipping risk.
local priorWidths,priorPixels=W.fontWidths,W.pixelMetrics
W.pixelMetrics=true
local function fitsButton(button,caption)
 local text=button.text
 eq(text:GetText(),caption,'action caption is never shortened')
 eq(text:IsTruncated(),false,'complete action caption fits its text allocation')
 local x,y,w,h=button:Rect();local tx,ty,tw,th=text:Rect();local scale=button:GetEffectiveScale()
 eq(tx>=x+6*scale-.001 and tx+tw<=x+w-6*scale+.001,true,'caption stays inside horizontal button padding')
 eq(ty>=y+3*scale-.001 and ty+th<=y+h-3*scale+.001,true,'caption stays inside vertical button padding')
 local natural=text:GetUnboundedStringWidth()*text:GetEffectiveScale()
 eq(natural<=w-12*scale+.001,true,'rendered glyph width fits button interior')
end
UIParent:SetSize(384,300);UIParent:SetScale(.64)
local characterButton,confirmButton
for _,advance in ipairs({.52,.8})do
 W.fontWidths={[fonts.Expressway]=advance}
 for _,size in ipairs({10,18})do
  W.patch({font='Expressway',fontSize=size})
  W.open('behavior');local character=W.control('character','behavior')
  fitsButton(character,'Use character profile')
  if characterButton then eq(character,characterButton,'appearance refresh reuses character action')end
  characterButton=character
  local panel=W.open('profiles')
  W.click(panel._pool['profile-reset'])
  local confirm=panel._pool['profile-confirm'];fitsButton(confirm,'Confirm replacement')
  if confirmButton then eq(confirm,confirmButton,'confirmation reuses its button')end
  confirmButton=confirm
  W.click(panel._pool['profile-cancel'])
 end
end
W.fontWidths,W.pixelMetrics=priorWidths,priorPixels
UIParent:SetSize(1920,1080);UIParent:SetScale(1)
print('PASS: '..assertions..' font/menu assertions (simulated native loading and compositor)')
