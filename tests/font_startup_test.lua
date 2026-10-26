-- Exercise the actual TOC initialization with the native API's non-integer
-- height readback and Font:SetFont's void return. Values model uiUnit conversion;
-- they are not claimed to be captured from the user's client.
local W=dofile('tests/wow_mock.lua')
W.fontHeightReadback=function(size) return size==12 and 11.999999046326 or size end
local originalLoad=loadfile
if arg[1]=="--fail-paths" then
 W.fontFailures={[GameTooltipText:GetFont()]=true}
elseif arg[1] then
 function loadfile(path) return originalLoad(path=='XPIsland/UI.lua' and arg[1] or path) end
end
local ns=W.load();local X,UI,O=ns.owner,ns.UI,ns.Options
loadfile=originalLoad
W.event('ADDON_LOADED','XPIsland')
W.event('PLAYER_ENTERING_WORLD',true,false)
assert(UI.inlineGroup and UI.layout and #UI.cells==8,'startup completes all UI construction')
assert(X.ticker,'startup reaches timer registration')
SlashCmdList.XPISLAND_SND_XPISLAND('')
assert(O.frame:IsShown(),'slash command opens options after startup')
assert(O.panel._menuFont:GetFont(),'native shared menu Font is initialized')
UI:SetExpanded(true,true);W.advance(2)
for _,cell in ipairs(UI.cells) do assert(cell.title:GetFont() and cell.value:GetFont(),'stat fonts survive native readback') end

-- Both path attempts can fail (e.g. a changed/unavailable default). Inherit a
-- Blizzard Font object instead of throwing or leaving a bare FontString/font.
local gamePath=GameTooltipText:GetFont()
W.fontFailures={[gamePath]=true};ns.App.fonts:Refresh()
local fresh=UI.Text(UI.frame,12)
assert(fresh:GetFont()==gamePath,'new text inherits a usable native font')
assert(fresh.fontObject,'failed path assignment inherits a native font')
fresh:SetText('Recovery');UI.Measure(fresh)
ns.App.fonts:Refresh();O:Refresh()
assert(O.panel._menuFont:GetFont()==gamePath,'menu font inherits native fallback')
assert(O.frame:IsShown(),'options remain available after failed font loading')
W.fontFailures=nil;ns.App.fonts:Refresh();UI.ApplyFont(fresh,12)
assert(fresh:GetFont()==gamePath,'font application recovers')
print('PASS: TOC startup, options, uiUnit height readback, void Font setter and native fallback recovery')
