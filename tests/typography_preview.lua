-- Optional real-font advance fixture. Metrics are supplied by render_typography.py.
local W=dofile('tests/wow_mock.lua')
W.fontAdvances=dofile(arg[1]);W.pixelMetrics=true
UIParent:SetSize(900,220)
local ns=W.load();local X,UI,P=ns.owner,ns.UI,ns.Progression
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false)
X.profile.fontSize=14;X.profile.scale=tonumber(arg[2]);X.profile.autoCollapse=false
X.profile.showPet=false;X.profile.showRank=true;X.profile.showKills=true
P.rank={level=0,xp=0,cap=75000,left=75000,total=0,ceiling=75000}
X.rested=8700;X.tracker.xp=11400;X.tracker.cap=14400
X.profile.format=arg[3];UI:SetExpanded(true,true)
if arg[3]=='pvp' then X.profile.mode='pvp';UI:SetExpanded(true,true) end
W.svg(arg[4],UI.frame)
for _,c in ipairs(UI.inlineCells) do
 if c.active then assert(not c.title:IsTruncated() and not c.value:IsTruncated(),'real font advance footer clipping') end
end
