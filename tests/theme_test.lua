local W=dofile("tests/wow_mock.lua")
local ns=W.load()
local X,UI,O,M=ns.owner,ns.UI,ns.Options,ns.Model
assert(M.Profile().theme=="modern")
assert(M.Profile({theme="unknown"}).theme=="modern")
assert(M.Profile({theme="forever"}).theme=="forever")
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
assert(not UI.chrome:IsShown() and UI.outer:IsShown() and UI.inner:IsShown())
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
