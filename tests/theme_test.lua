local W=dofile('tests/wow_mock.lua')

-- Register extra definitions before Core declares SND settings and appearance.
-- The real TOC still determines module order; only the test fixtures are added.
local function loadWithThemes(runtime)
 local ns={}
 for line in io.lines('XPIsland/XPIsland.toc') do
  if line:match('%.lua$') then
   if line=='Core.lua' then
    local T,M=ns.Themes,ns.Model
    local bronze=M.Copy(T.Get('forever'))
    bronze.id,bronze.label='test-bronze','Test bronze'
    bronze.headerHeight,bronze.segmentHeight,bronze.headerInset,bronze.labelGap=38,12,16,16
    bronze.chromeRadius=8;bronze.trackAlpha=.6;bronze.trackColor={.1,.3,.2}
    bronze.palette.accent={.75,.35,.15,1};bronze.palette.text={.95,.85,.65,1}
    local round=M.Copy(T.Get('modern'))
    round.id,round.label='test-round','Test round'
    round.headerHeight,round.segmentHeight,round.headerInset,round.labelGap=40,16,18,14
    round.outerRadius,round.innerRadius=10,9
    round.palette.border={.2,.4,.3,1};round.palette.surface={.03,.1,.07,.98}
    round.palette.accent={.4,.8,.5,1};round.palette.text={.8,.95,.85,1}
    T.definitions[#T.definitions+1]=bronze;T.definitions[#T.definitions+1]=round
   end
   assert(loadfile('XPIsland/'..line))('XPIsland',ns)
  end
 end
 runtime.ns=ns
 return ns
end

local ns=loadWithThemes(W)
local X,UI,O,M,T=ns.owner,ns.UI,ns.Options,ns.Model,ns.Themes
local n=0
local function eq(a,b,why) n=n+1;assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,why) n=n+1;assert(math.abs(a-b)<.000001,(why or 'near')..': '..a..' ~= '..b) end
local function color(actual,expected,why)
 for channel=1,4 do near(actual[channel] or 1,expected[channel] or 1,why) end
end
local function choose(id)
 W.open('appearance');W.choose(W.control('theme','appearance'),id)
end
local function palette(theme)
 color(UI.label.color,theme.palette.text,'header uses the SND text role')
 for _,cell in ipairs(UI.cells) do
  color(cell.title.color,theme.palette.accent,'title uses the SND accent role')
  color(cell.value.color,theme.palette.text,'value uses the SND text role')
 end
 color(O.frame.backdropColor,theme.palette.surface,'options use the same theme surface')
 color(UI.divider.color,theme.dividerColor,'island divider keeps its own theme color')
end

eq(M.Profile().theme,'modern')
eq(M.Profile({theme='forever'}).theme,'forever')
for _,value in ipairs({false,42,{},'missing'}) do
 eq(M.Profile({theme=value}).theme,T.default,'malformed saved theme falls back')
end
for _,id in ipairs({'modern','forever','test-bronze','test-round'}) do
 eq(M.Profile({theme=id}).theme,id,'registered theme survives validation')
end
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false)
W.open('appearance')
local choices=W.control('theme','appearance').menuDescription.entries
eq(#choices,4,'all definitions reach the native selector')
for i,theme in ipairs(T.definitions) do
 eq(choices[i].value,theme.id,'selector preserves definition order')
 eq(choices[i].label,theme.label,'selector uses the definition label')
end
for _,value in ipairs({false,42,{},'missing'}) do
 local ok=ns.App:Set('theme',value)
 eq(ok,false,'settings reject invalid theme IDs')
 eq(X.profile.theme,T.default,'rejected theme preserves active choice')
 eq(XPIslandDB.profiles.Shared.theme,T.default,'rejected theme preserves saved choice')
end
W.patch({font='Arial',normal={.7,.4,.2},rested={.2,.6,.9}})
local font=X.profile.font
local normal=M.Copy(X.profile.normal)
choose('forever')
eq(X.profile.theme,'forever');eq(XPIslandDB.profiles.Shared.theme,'forever')
assert(UI.chrome:IsShown() and not UI.outer:IsShown() and not UI.inner:IsShown())
eq(#UI.chrome.pieces,9)
eq(UI.layout.barHeight,28);eq(UI.segmentHeight,10)
assert(UI.segments[1].fill.cap:IsShown())
assert(UI.segments[1].fill.cap.texture:find('soft%-cap.tga'))
assert(UI.trackColor[1]>.2,'empty segments remain readable')
assert(UI.segments[1].fill.shading:IsShown())
for _,index in ipairs({1,20}) do
 local part=UI.segments[index].fill
 assert(part.capShading:IsShown() and part.capShading.alpha==part.shading.alpha)
 for _,amount in ipairs({.02,.5,1}) do
  part:Draw(18,UI.segmentHeight,amount,normal)
  for i=1,4 do eq(part.capShading.coords[i],part.cap.coords[i],'cap gradient follows partial-fill crop') end
  eq(part.shading:IsShown(),part.body:IsShown(),'body shading follows partial-fill visibility')
  eq(part.capShading:IsShown(),part.cap:IsShown(),'cap shading follows partial-fill visibility')
 end
end
UI:PaintBar(true)
eq(X.profile.font,font)
color(X.profile.normal,normal,'theme preserves chosen XP color')
palette(T.Get('forever'))
W.click(UI.frame);W.advance(.4)
local count=#W.objects
W.advance(2)
eq(#W.objects,count,'theme never allocates during animation or idle')
eq(M.Profile(X.profile).theme,'forever')
assert(ns.App.profiles:Duplicate('Forever copy'))
eq(X.profileName,'Forever copy');eq(X.profile.theme,'forever')
assert(ns.App.profiles:Switch('Shared'));eq(X.profile.theme,'forever')
choose('modern')
eq(UI.outer.radius,17);eq(UI.inner.radius,16)
assert(not UI.chromeFrames.forever:IsShown() and UI.outer:IsShown() and UI.inner:IsShown())
eq(UI.layout.barHeight,34);eq(UI.segmentHeight,10)
assert(not UI.segments[1].fill.shading:IsShown())
assert(not UI.segments[1].fill.capShading:IsShown() and not UI.segments[20].fill.capShading:IsShown())
assert(UI.segments[1].fill.cap:IsShown())
palette(T.Get('modern'))
choose('forever')
W.click(UI.frame);W.advance(.4)
W.set('scale',.5);assert(UI.chrome:IsShown())
W.set('scale',1.5);assert(UI.chrome:IsShown())
W.set('mode','pvp');assert(UI.chrome:IsShown())

-- Repainting theme artwork cannot clear a transient color. A real settings
-- transaction retires the native picker, restoring its opening color instead.
for _,id in ipairs({'modern','forever','test-bronze','test-round'}) do
 choose(id)
 W.click(W.control('normal','appearance'))
 local edit=W.colorInfo;edit.swatchFunc()
 color(UI:ColorValue('normal'),{.1,.2,.3},'native picker previews gameplay color')
 UI.appliedTheme=nil;UI:Layout(true)
 color(UI:ColorValue('normal'),{.1,.2,.3},'theme reapplication retains active preview')
 color(X.profile.normal,normal,'theme repaint leaves profile color untouched')
 color(XPIslandDB.profiles[X.profileName].normal,normal,'theme repaint leaves saved color untouched')
 choose(id=='modern' and 'forever' or 'modern')
 eq(ColorPickerFrame:IsShown(),false,'theme choice dismisses stale native picker')
 color(UI:ColorValue('normal'),normal,'theme choice restores the saved gameplay color')
 edit.swatchFunc();edit.cancelFunc()
 color(X.profile.normal,normal,'stale picker cannot edit selected theme profile')
end
print('PASS: theme defaults, validation, native selector, shared palette, previews, color/font preservation, persistence and PvP')

local themeIDs={'modern','test-bronze','forever','test-round'}
local originalFont,originalSize=X.profile.font,X.profile.fontSize
local originalNormal,originalRested=M.Copy(X.profile.normal),M.Copy(X.profile.rested)
local objects=#W.objects
for i=1,1200 do
 local id=themeIDs[(i-1)%#themeIDs+1];local theme=T.Get(id)
 choose(id)
 eq(X.profile.theme,id);eq(UI.appliedTheme,id)
 eq(M.Profile(X.profile).theme,id)
 W.patch({scale=({.5,.85,1,1.5})[math.floor(i/4)%4+1],
  fontSize=({10,14,18})[math.floor(i/16)%3+1],
  placement=({'top','bottom','custom'})[math.floor(i/48)%3+1],mode=i%3==0 and 'pvp' or 'xp'})
 local viewport=({{1920,1080},{800,600},{320,200}})[math.floor(i/144)%3+1]
 UIParent:SetSize(viewport[1],viewport[2]);UI:Layout(true)
 eq(UI.layout.barHeight,theme.headerHeight);eq(UI.segmentHeight,theme.segmentHeight)
 eq(UI.headerInset,theme.headerInset);eq(UI.labelGap,theme.labelGap)
 eq(UI.outer:IsShown(),not theme.chromeTexture)
 for themeID,chrome in pairs(UI.chromeFrames) do eq(chrome:IsShown(),themeID==id) end
 if not theme.chromeTexture then eq(UI.outer.radius,theme.outerRadius) end
 palette(theme)
 UI:SetExpanded(true);UI:Animate(.04);UI:SetExpanded(false);UI:Animate(.5)
 for _,segment in ipairs(UI.segments) do
  assert(segment.width>0,'theme produced nonpositive segment width')
  eq(segment.track.drawHeight,theme.segmentHeight)
  eq(segment.track.alpha,theme.trackAlpha)
  eq(segment.border:IsShown(),theme.segmentBorder~=nil)
  assert(segment.border:GetFrameLevel()>segment.flash:GetFrameLevel())
  near(segment.border:GetWidth(),segment.track:GetWidth())
  near(segment.border:GetHeight(),theme.segmentHeight)
 end
 eq(#W.objects,objects,'switching themes allocates no UI objects')
 eq(X.profile.font,originalFont)
 color(X.profile.normal,originalNormal,'theme preserves chosen normal color')
 color(X.profile.rested,originalRested,'theme preserves chosen rested color')
end
-- A border stays on the full segment while the XP edge moves through it.
choose('forever')
for _,amount in ipairs({0,.02,.5,.99,1}) do
 local segment=UI.segments[10]
 segment.fill:Draw(segment.width,UI.segmentHeight,amount,X.profile.normal)
 assert(segment.border:IsShown())
 near(segment.border:GetWidth(),segment.width)
end
for index=2,20 do
 local left=UI.segments[index-1].track;local right=UI.segments[index].track
 local lx,_,lw=left:Rect();local rx=right:Rect()
 near((rx-lx-lw)/UI.frame:GetEffectiveScale(),3,'Forever spacing')
end
eq(T.Get('forever').segmentHeight,T.Get('modern').segmentHeight)
eq(T.Get('modern').segmentGap,2);eq(T.Get('modern').segmentBorder,nil)
W.set('fontSize',originalSize)
-- Profile commands and saved-data restoration recognize additional theme IDs.
choose('test-bronze')
assert(ns.App.profiles:Duplicate('Third theme copy'))
eq(X.profile.theme,'test-bronze')
assert(ns.App.profiles:Switch('Shared'));choose('modern')
assert(ns.App.profiles:CopyFrom('Third theme copy'));eq(X.profile.theme,'test-bronze')
local restored=M.Database(M.Copy(XPIslandDB))
eq(M.SelectProfile(restored,X.character,X.profileName).theme,'test-bronze','database restores selected theme')
local removed=M.Copy(XPIslandDB);removed.profiles[X.profileName].theme='removed-theme'
eq(M.Database(removed).profiles[X.profileName].theme,T.default,'removed saved theme falls back')
local W2=dofile('tests/wow_mock.lua');local ns2=loadWithThemes(W2)
W2.event('ADDON_LOADED','XPIsland');W2.event('PLAYER_ENTERING_WORLD',true,false)
eq(ns2.owner.profile.theme,'test-bronze','fresh initialization restores additional theme')
eq(ns2.UI.appliedTheme,'test-bronze','fresh initialization applies restored artwork')
W2.open('appearance')
eq(W2.control('theme','appearance').Text:GetText(),'Test bronze','fresh selector restores caption')
print('PASS: '..n..' assertions including 1,200 four-theme switches, both renderers, profile validation/copy/reload, scale/font/placement/mode and interrupted motion')
