-- Native menu compositor contract, font propagation, and failed-family recovery.
-- Font loading here is simulated; real client glyph/raster validation is separate.
local W=dofile("tests/wow_mock.lua")
local fonts={Expressway="Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF",
    ["Friz Quadrata TT"]="Fonts\\FRIZQT__.TTF",
    ["2002"]="Fonts\\2002.TTF",["2002 Bold"]="Fonts\\2002B.TTF",
    ["Missing font"]="Interface\\AddOns\\Missing\\font.ttf"}
local lsm={callbacks={},registrations=0}
function lsm:HashTable(kind) assert(kind=="font");return fonts end
function lsm:IsValid(kind,name) return kind=="font" and fonts[name]~=nil end
function lsm:Fetch(kind,name) assert(kind=="font");return fonts[self.override or name] end
function lsm.RegisterCallback(receiver,event,callback)
    lsm.callbacks[event]=callback;lsm.registrations=lsm.registrations+1
end
function LibStub(name,silent) assert(name=="LibSharedMedia-3.0" and silent);return lsm end
local ns=W.load()
local X,UI,O=ns.owner,ns.UI,ns.Options
local assertions=0
local function eq(a,b,why) assertions=assertions+1;assert(a==b,(why or "assertion")..": "..tostring(a).." ~= "..tostring(b)) end
W.event("ADDON_LOADED","XPIsland");W.event("PLAYER_ENTERING_WORLD",true,false)
W.event("UPDATE_BINDINGS");W.event("PLAYER_REGEN_ENABLED")
eq(O.frame,nil,"events before first options open preserve lazy construction")
SlashCmdList.XPISLAND("")
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
    for _,entry in ipairs(O.fontObjects) do
        eq(entry.object:GetFont(),expected,"options label/edit/control uses selected family")
    end
    eq(O.menuFont:GetFont(),expected,"shared menu Font uses selected family")
    for _,dropdown in ipairs(O.dropdowns) do
        dropdown:GenerateMenu()
        for _,entry in ipairs(dropdown.menuDescription.entries) do
            -- The real compositor forbids even INDEXING SetFont. Prior tests
            -- generated descriptions without running these native initializers.
            local selectedFont
            local guarded=setmetatable({SetFontObject=function(_,font) selectedFont=font end},
                {__index=function(_,key)
                    if key=="SetFont" then error("Use of function 'SetFont' is disallowed. (Index)") end
                    error("Unexpected compositor method: "..key)
                end})
            entry.initializer({fontString=guarded})
            eq(selectedFont,O.menuFont,"native rows use safe shared Font object")
            eq(selectedFont:GetFont(),expected,"native menu inherits selected family")
        end
    end
end
-- An explicit family must not follow another addon's global default override.
local originalStandard=STANDARD_TEXT_FONT
STANDARD_TEXT_FONT=fonts.Expressway
W.choose(O.font,"Friz Quadrata TT");allSurfaces(fonts["Friz Quadrata TT"])
W.choose(O.font,"Expressway")
W.choose(O.font,"Friz Quadrata");allSurfaces(fonts["Friz Quadrata TT"])
eq(X.profile.font,"Friz Quadrata","explicit built-in choice keeps its identity")
STANDARD_TEXT_FONT=originalStandard
-- Cached assignment metadata is not proof the native object kept its font:
-- global font passes and native controls can replace an object's current face.
W.choose(O.font,"Expressway")
UI.cells[1].title:SetFont(fonts["Friz Quadrata TT"],12,"")
O.menuFont:SetFont(fonts["Friz Quadrata TT"],18,"")
O.font.Text:SetFont(fonts["Friz Quadrata TT"],12,"")
X:ApplyProfile();allSurfaces(fonts.Expressway)
local _,menuSize=O.menuFont:GetFont()
eq(menuSize,12,"refresh repairs externally changed cached menu font size")
for _,scale in ipairs({.5,.85,.95,1,1.5}) do
    X.profile.scale=scale
    for _,name in ipairs({"Expressway","2002","2002 Bold","Arial","Game tooltip","Expressway"}) do
        W.choose(O.font,name)
        local expected=fonts[name] or (name=="Arial" and "Fonts\\ARIALN.TTF" or tooltipFont)
        UI:SetExpanded(true,true)
        allSurfaces(expected)
        eq(X.profile.font,name,"preserve selected preference")
        eq(X.profile.scale,scale,"font selection preserves scale")
        eq(O.profilesTab.text:GetText(),"Profiles","previously blank Profiles caption survives font selection")
        eq(O.rested.text:GetText(),"Rested XP","previously blank color caption survives font selection")
        eq(O.format.Text:GetText(),"Percentage","previously blank bar format survives menu regeneration")
        eq(O.font.Text:GetText(),name=="Game tooltip" and "Game Tooltip (default)" or name,"selected font remains visible")
        local fontCaption
        for _,entry in ipairs(O.fontObjects) do
            if entry.object:GetText()=="Font" then fontCaption=entry.object end
        end
        eq(fontCaption~=nil and fontCaption:IsVisible(),true,"Font caption remains visible")
    end
end
-- A valid LSM registration is not evidence the client loaded the font. A
-- failed family must not leave some objects on the previous Expressway face.
W.fontFailures= W.fontFailures or {}
W.fontFailures[fonts["Missing font"]]=true
W.choose(O.font,"Missing font")
allSurfaces(tooltipFont)
eq(X.profile.font,"Missing font","fallback does not destroy saved choice")
W.fontFailures[fonts["2002"]]=true
W.choose(O.font,"2002");allSurfaces(tooltipFont)
eq(X.profile.font,"2002","registered but unavailable 2002 retains preference")
W.fontFailures[fonts["2002"]]=nil
W.choose(O.font,"2002");allSurfaces(fonts["2002"])
W.choose(O.font,"Expressway");allSurfaces(fonts.Expressway)
W.fontFailures[fonts["2002 Bold"]]=true
W.choose(O.font,"2002 Bold");allSurfaces(tooltipFont)
eq(X.profile.font,"2002 Bold","failed screenshot family retains preference")
eq(O.font.Text:GetText(),"2002 Bold","failed family keeps a readable selection")
W.fontFailures[fonts["2002 Bold"]]=nil
W.choose(O.font,"Expressway");W.choose(O.font,"2002 Bold");allSurfaces(fonts["2002 Bold"])
-- A probe can succeed while a particular native object rejects the face.
-- Fail main, options and menu objects in turn, including a late native fallback.
for _,target in ipairs({UI.cells[1].title,O.font.Text,O.menuFont}) do
    W.choose(O.font,"Arial")
    local original=target.SetFont
    target.SetFont=function(self,path,...)
        if path==fonts.Expressway then return false end
        return original(self,path,...)
    end
    W.choose(O.font,"Expressway");allSurfaces(tooltipFont)
    eq(UI.layout.font,tooltipFont,"layout reflects common fallback after late rejection")
    eq(X.profile.font,"Expressway","object failure retains requested family")
    target.SetFont=original
    W.choose(O.font,"Expressway");allSurfaces(fonts.Expressway)
end
local originalMenuSetter=O.menuFont.SetFont
O.menuFont.SetFont=function() return false end
W.choose(O.font,"Arial")
allSurfaces((GameFontNormal or GameTooltipText):GetFont())
eq(UI.layout.font,(GameFontNormal or GameTooltipText):GetFont(),"native fallback also reflows island")
O.menuFont.SetFont=originalMenuSetter
W.choose(O.font,"Arial");allSurfaces("Fonts\\ARIALN.TTF")
-- A rejection discovered late in pass one can expose a second rejection in
-- pass two. Distinct families prove the bounded replay reaches native fallback.
local previousNormal=GameFontNormal
GameFontNormal=CreateFont("XPIslandTestNativeFallback")
GameFontNormal:SetFont("Fonts\\NativeFallback.TTF",15,"")
local title=UI.cells[1].title
local originalTitleSetter,originalOptionsSetter=title.SetFont,O.font.Text.SetFont
local originalLayout,passes=UI.LayoutContents,0
UI.LayoutContents=function(self,...) passes=passes+1;return originalLayout(self,...) end
title.SetFont=function(self,path,...)
    if path==tooltipFont then return false end
    return originalTitleSetter(self,path,...)
end
O.font.Text.SetFont=function(self,path,...)
    if path==fonts.Expressway then return false end
    return originalOptionsSetter(self,path,...)
end
X.profile.font="Expressway";X:ApplyProfile()
allSurfaces(GameFontNormal:GetFont())
eq(UI.layout.font,GameFontNormal:GetFont(),"late two-stage failure reflows final family")
eq(passes,3,"three passes settle selected, default and native fallback")
eq(X.refreshingAppearance,nil,"refresh guard clears after fallback replay")
title.SetFont=originalTitleSetter;O.font.Text.SetFont=originalOptionsSetter
UI.LayoutContents=originalLayout
W.choose(O.font,"Expressway");allSurfaces(fonts.Expressway)
GameFontNormal=previousNormal
-- Applying a profile is the shared refresh boundary, including hidden options.
O.frame:Hide()
X.profile.font="Expressway";X:ApplyProfile();allSurfaces(fonts.Expressway)
O.frame:Show();allSurfaces(fonts.Expressway)
-- Dynamic layout repairs font objects without clearing an in-progress action.
O.confirmCopy=true
O.menuFont:SetFont(tooltipFont,18,"")
UI:Layout(true);allSurfaces(fonts.Expressway)
eq(O.confirmCopy,true,"layout-only refresh preserves copy confirmation")
O.confirmCopy=nil
local menuRebuilds=0
for _,dropdown in ipairs(O.dropdowns) do
    local generate=dropdown.GenerateMenu
    dropdown.GenerateMenu=function(self,...)
        menuRebuilds=menuRebuilds+1;return generate(self,...)
    end
end
for _=1,10 do UI:Layout(true) end
eq(menuRebuilds,0,"unchanged model layout does not regenerate native menus")
-- Fonts from embedded/late-loaded SharedMedia providers become available
-- without reselecting a setting or leaving options on the old fallback face.
X.profile.font="Late font";X:ApplyProfile();O:Refresh();allSurfaces(tooltipFont)
fonts["Late font"]="Interface\\AddOns\\LateMedia\\font.ttf"
lsm.callbacks.LibSharedMedia_Registered("LibSharedMedia_Registered","font","Late font")
allSurfaces(fonts["Late font"])
lsm.override="2002"
lsm.callbacks.LibSharedMedia_SetGlobal("LibSharedMedia_SetGlobal","font","2002")
allSurfaces(fonts["2002"])
eq(X.profile.font,"Late font","global media override preserves selected preference")
lsm.override=nil
lsm.callbacks.LibSharedMedia_SetGlobal("LibSharedMedia_SetGlobal","font",nil)
allSurfaces(fonts["Late font"])
for _=1,3 do W.event("ADDON_LOADED","AnotherFontProvider") end
eq(lsm.registrations,2,"callbacks are registered once per library")
-- Every explicit single-line options allocation shares the same padded fit.
-- Exercise font advances and physical scale independently, including a native
-- dropdown's selected text after menu regeneration and both tabs' buttons.
W.pixelMetrics=true
local longName="A deliberately long shared profile and font name"
fonts[longName]=fonts["Late font"]
X.profile.font=longName;X.profileName=longName;X.db.profiles[longName]=X.profile
GetBindingKey=function() return "CTRL-SHIFT-ALT-NUMPADMULTIPLY" end
for _,rootScale in ipairs({.64,1,1.25}) do
    UIParent:SetScale(rootScale)
    for _,viewport in ipairs({{384,300},{800,600},{1920,1080}}) do
        UIParent:SetSize(unpack(viewport))
        for _,shape in ipairs({.42,.52,.7}) do
            W.fontWidths={[fonts["Late font"]]=shape}
            for _,entry in ipairs(O.fontObjects) do entry.object.xpMeasureKey=nil end
            O:Refresh()
            for _,entry in ipairs(O.fontObjects) do
                local text=entry.object
                if text.xpOptionsWidth then
                    eq(text:IsTruncated(),false,"bounded options text fits after font/scale change: "..text:GetText())
                    eq(math.abs(text:GetWidth()*text.scale-text.xpOptionsWidth)<.001,true,"text keeps control allocation")
                end
            end
        end
    end
end
W.fontWidths={[fonts["Late font"]]=.7}
O.copySource="Shared";O.confirmCopy=nil
W.click(O.copyButton)
eq(O.copyButton.text:IsTruncated(),false,"confirmation caption is fitted immediately")
-- Font objects are process-lived: refresh/reopen must not create one per row.
local menuFont=O.menuFont
for _=1,10 do O:Refresh();O:Toggle(X);O:Toggle(X) end
eq(O.menuFont,menuFont,"one menu font reused across updates")
eq(GameTooltipText:GetFont(),tooltipFont,"global tooltip font stays unchanged")
print("PASS: "..assertions.." font/menu assertions (simulated font loading)")
