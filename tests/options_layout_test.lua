-- Reproduce the migrated Behavior page's excessive scroll and mismatched chrome.
-- Geometry is executed Lua with a boundary fixture, not native rendering evidence.
local W=dofile('tests/wow_mock.lua');local ns=W.load()
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false)
local panel=W.open('behavior')
local function eq(a,b,why)assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b))end
local function aligned(key)
    local d=W.control(key,'behavior');local label=panel._texts['behavior:1:'..key..':label']
    assert(d:GetLeft()>=label:GetLeft()+label:GetWidth()+16-.001,'field must sit beside its label')
    assert(math.abs(d:GetTop()-label:GetTop())<10,'label and field share the row')
    eq(d.Background:IsShown(),false);eq(d.Arrow:IsShown(),false)
    eq(d.backdropColor[1],ns.Themes.Get(ns.owner.profile.theme).palette.surface[1])
end
for _,theme in ipairs({'modern','forever'})do
    W.set('theme',theme);aligned('levelUpDuration');aligned('autoCollapseDuration')
    eq(panel._maximum,0,'Behavior fits without scrolling at normal viewport')
    eq(panel.bar:IsShown(),false)
    eq(panel._pool['tab:behavior']._selected:IsShown(),true)
    eq(panel._pool['tab:appearance']._selected:IsShown(),false)
    eq(W.control('locked','behavior').template,'BackdropTemplate')
end
W.set('autoCollapse',false);eq(W.control('autoCollapseDuration','behavior'):IsEnabled(),false)
eq(W.control('autoCollapseDuration','behavior').alpha,.45)
W.set('autoCollapse',true);eq(W.control('autoCollapseDuration','behavior').alpha,1)
W.open('appearance');W.choose(W.control('placement','appearance'),'bottom');eq(ns.owner.profile.placement,'bottom')
W.click(W.control('resetPosition','appearance'));eq(ns.owner.profile.placement,'top')
W.open('profiles');W.click(W.control('character','profiles'));eq(ns.owner.profileName,ns.owner.characterName)
W.click(W.control('shared','profiles'));eq(ns.owner.profileName,'Shared')
-- Short viewports retain a visible thumb and reachable last action; switching
-- pages keeps separate offsets and active navigation, including on reopen.
UIParent:SetSize(900,300);W.open('behavior');assert(panel._maximum>0)
eq(panel.bar:IsShown(),true);assert(panel.bar._thumb:GetHeight()<=panel.bar:GetHeight())
panel.bar:SetValue(panel._maximum);eq(panel.scroll.scroll,panel._maximum)
local last=W.control('expand','behavior')
assert(last:GetBottom()>=panel.scroll:GetBottom()-.001 and last:GetTop()<=panel.scroll:GetTop()+.001,'last action is reachable after scrolling')
local offset=panel._maximum;W.open('appearance');W.open('behavior');eq(panel.scroll.scroll,offset)
local count=#W.objects;panel:Close();W.open('behavior');eq(#W.objects,count,'reopen reuses controls')
UIParent:SetSize(900,650);W.event('DISPLAY_SIZE_CHANGED');eq(panel._maximum,0);eq(panel.scroll.scroll,0)
W.set('theme','modern');W.svg('dist/options-behavior.svg',panel.frame)
-- Dispatch user-facing clicks with mouse/visibility gates, not only SelectPage.
for _,id in ipairs({'appearance','tracking','profiles','behavior','appearance'})do
    assert(W.inputClick(panel._pool['tab:'..id]),'tab accepts mouse input')
    eq(panel._page,id);eq(panel:IsShown(),true);eq(panel._pool['tab:'..id]._selected:IsShown(),true)
end
local font=W.control('font','appearance')
for _,key in ipairs({'normal','rested'})do
    local swatch=W.control(key,'appearance');local label=panel._texts['appearance:1:'..key..':label']
    assert(math.abs(swatch:GetLeft()-font:GetLeft())<.001,'color swatch shares field column')
    assert(swatch:GetLeft()>=label:GetLeft()+label:GetWidth()+15,'color label does not overlap its swatch')
    eq(swatch._swatch.color[1],ns.owner.profile[key][1]);eq(swatch.text:GetText(),'')
end
W.svg('dist/options-appearance.svg',panel.frame)
assert(W.inputClick(panel._pool.close));eq(panel:IsShown(),false)
assert(not W.inputClick(panel._pool['tab:behavior']));W.open('appearance')
assert(W.inputClick(panel._pool['tab:behavior']));eq(panel._page,'behavior')
print('PASS compact Behavior layout, theme chrome, active tabs, profile shortcuts, disabled state, scrolling and reuse')
