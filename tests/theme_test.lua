local W=dofile("tests/wow_mock.lua")
local ns=W.load()
local X,UI,O,M=ns.owner,ns.UI,ns.Options,ns.Model
assert(M.Profile().theme=="modern")
assert(M.Profile({theme="unknown"}).theme=="modern")
assert(M.Profile({theme="forever"}).theme=="forever")
-- Test-only themes exercise both renderers without edits to Model, Options or UI.
local T=ns.Themes
local bronze=M.Copy(T.Get("forever"))
bronze.id,bronze.label="test-bronze","Test bronze"
bronze.headerHeight,bronze.segmentHeight,bronze.headerInset,bronze.labelGap=38,12,16,16
bronze.chromeRadius=8;bronze.trackAlpha=.6;bronze.trackColor={.1,.3,.2}
local round=M.Copy(T.Get("modern"))
round.id,round.label="test-round","Test round"
round.headerHeight,round.segmentHeight,round.headerInset,round.labelGap=40,16,18,14
round.outerRadius,round.innerRadius=10,9;round.outerColor={.2,.4,.3,1}
T.definitions[#T.definitions+1]=bronze;T.definitions[#T.definitions+1]=round
for _,value in ipairs({false,42,{},"missing"}) do assert(M.Profile({theme=value}).theme==T.default) end
W.event("ADDON_LOADED","XPIsland");W.event("PLAYER_ENTERING_WORLD",true,false)
O:Toggle(X)
local font=X.profile.font
local normal=M.Copy(X.profile.normal)
W.choose(O.theme,"forever")
assert(X.profile.theme=="forever")
assert(UI.chrome:IsShown() and not UI.outer:IsShown() and not UI.inner:IsShown())
assert(#UI.chrome.pieces==9)
assert(UI.layout.barHeight==28 and UI.segmentHeight==14)
assert(UI.segments[1].fill.cap:IsShown())
assert(UI.segments[1].fill.cap.texture:find("soft%-cap.tga"))
assert(UI.trackColor[1]>.2,"empty segments remain readable")
assert(UI.segments[1].fill.shading:IsShown())
for _,index in ipairs({1,20}) do
 local part=UI.segments[index].fill
 assert(part.capShading:IsShown() and part.capShading.alpha==part.shading.alpha)
 for _,amount in ipairs({.02,.5,1}) do
  part:Draw(18,14,amount,normal)
  for i=1,4 do assert(part.capShading.coords[i]==part.cap.coords[i],"cap gradient uses the same crop, including partial fills") end
  assert(part.shading:IsShown()==part.body:IsShown(),"body shading must follow partial-fill visibility")
  assert(part.capShading:IsShown()==part.cap:IsShown(),"cap shading must follow partial-fill visibility")
 end
end
UI:PaintBar(true)

assert(X.profile.font==font)
for i=1,3 do assert(X.profile.normal[i]==normal[i]) end
W.click(UI.frame);W.advance(.4)
local count=#W.objects
W.advance(2)
assert(#W.objects==count,"theme must not allocate during animation or idle")
local profile=M.Profile(X.profile)
assert(profile.theme=="forever")
assert(M.Duplicate(X.db,X.profileName,"Forever copy"))
O:Switch("Forever copy");assert(X.profile.theme=="forever")
O:Switch("Shared");assert(X.profile.theme=="forever")
W.choose(O.theme,"modern")
assert(UI.outer.radius==17 and UI.inner.radius==16)
assert(not UI.chromeFrames.forever:IsShown() and UI.outer:IsShown() and UI.inner:IsShown())
assert(UI.layout.barHeight==34 and UI.segmentHeight==10)
assert(not UI.segments[1].fill.shading:IsShown())
assert(not UI.segments[1].fill.capShading:IsShown() and not UI.segments[20].fill.capShading:IsShown())
assert(UI.outer.radius==17)
assert(UI.segments[1].fill.cap:IsShown())
W.choose(O.theme,"forever")
W.click(UI.frame);W.advance(.4)
X.profile.scale=.5;X:ApplyProfile();assert(UI.chrome:IsShown())
X.profile.scale=1.5;X:ApplyProfile();assert(UI.chrome:IsShown())
X.profile.mode="pvp";X:ApplyProfile()
assert(UI.chrome:IsShown())
print("PASS: theme defaults, validation, native selector, color/font preservation, persistence, geometry and PvP")

local themeIDs={"modern","test-bronze","forever","test-round"}
local originalFont,originalSize=X.profile.font,X.profile.fontSize
local originalNormal,originalRested=M.Copy(X.profile.normal),M.Copy(X.profile.rested)
local objects=#W.objects
for i=1,1200 do
 local id=themeIDs[(i-1)%#themeIDs+1];local theme=T.Get(id)
 W.choose(O.theme,id)
 assert(X.profile.theme==id and UI.appliedTheme==id)
 local copy=M.Profile(X.profile);assert(copy.theme==id)
 X.profile.scale=({.5,.85,1,1.5})[math.floor(i/4)%4+1]
 X.profile.fontSize=({10,14,18})[math.floor(i/16)%3+1]
 X.profile.placement=({"top","bottom","custom"})[math.floor(i/48)%3+1]
 local viewport=({{1920,1080},{800,600},{320,200}})[math.floor(i/144)%3+1]
 UIParent:SetSize(viewport[1],viewport[2])
 X.profile.mode=i%3==0 and "pvp" or "xp"
 X:ApplyProfile()
 assert(UI.layout.barHeight==theme.headerHeight and UI.segmentHeight==theme.segmentHeight)
 assert(UI.headerInset==theme.headerInset and UI.labelGap==theme.labelGap)
 assert(UI.outer:IsShown()==(not theme.chromeTexture))
 for themeID,chrome in pairs(UI.chromeFrames) do assert(chrome:IsShown()==(themeID==id)) end
 if not theme.chromeTexture then assert(UI.outer.radius==theme.outerRadius) end
 UI:SetExpanded(true);UI:Animate(.04);UI:SetExpanded(false);UI:Animate(.5)
 for _,segment in ipairs(UI.segments) do
  assert(segment.width>0,"theme produced negative segment width")
  assert(segment.track.drawHeight==theme.segmentHeight)
  assert(segment.track.alpha==theme.trackAlpha)
 end
 assert(#W.objects==objects,"switching themes allocated UI objects")
 assert(X.profile.font==originalFont)
 for channel=1,3 do
  assert(X.profile.normal[channel]==originalNormal[channel] and X.profile.rested[channel]==originalRested[channel])
 end
end
X.profile.fontSize=originalSize
-- Saved-data restoration and profile copying must recognize a new theme.
W.choose(O.theme,"test-bronze")
assert(M.Duplicate(X.db,X.profileName,"Third theme copy"))
O:Switch("Third theme copy");assert(X.profile.theme=="test-bronze")
X.profile.theme="removed-theme";X:ApplyProfile()
assert(UI.appliedTheme==T.default and UI.layout.barHeight==T.Get().headerHeight)
print("PASS: 1,200 four-theme switches, both renderers, profile validation/copy, scale/font/placement/mode and interrupted motion")
