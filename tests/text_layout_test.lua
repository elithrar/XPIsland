-- Fractional raster rounding is deliberately adversarial: native advance
-- measurement may round down while clipping needs another physical pixel.
-- This models the defect boundary, not the WoW renderer.
local W=dofile('tests/wow_mock.lua')
W.pixelMetrics=true
local originalLoad=loadfile
if arg[1] then
    function loadfile(path) return originalLoad(path=='XPIsland/UI.lua' and arg[1] or path) end
end
local ns=W.load();local X,UI,P=ns.owner,ns.UI,ns.Progression
loadfile=originalLoad
local count=0
local function check(v,why) count=count+1;assert(v,why) end
local function near(a,b,why) check(math.abs(a-b)<.001,why) end
local function separated(cell)
    local _,ty,_,th=cell.title:Rect();local _,vy,_,vh=cell.value:Rect()
    local _,cy,_,ch=cell:Rect()
    check(ty-(vy+vh)>=3*cell:GetEffectiveScale()-.001,'fitted title/value retain the row gap')
    check(ty+th<=cy+ch+.001 and vy>=cy-.001,'fitted title/value remain in their row')
end
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false)
X.profile.autoCollapse=false;X.profile.fontSize=14;X.profile.scale=.85
P.rank={level=0,xp=0,cap=75000,left=75000,total=0,ceiling=75000}
UI:SetExpanded(true,true)
for _,c in ipairs(UI.inlineCells) do
    if c.active then
        check(not c.title:IsTruncated(),'85% inline title has physical clipping clearance')
        check(not c.value:IsTruncated(),'85% rank and kill values have physical clipping clearance')
    end
end
-- Same role font size and family, including a font-size change with footer off.
check(UI.inlineCells[2].title.fontSize==UI.cells[2].title.fontSize,'footer shares stat-title role')
-- Exact old-client screenshot cases: bottom drawer, 0 / 750 rank, and the
-- transition through 85/90/95/100%. These checks preserve full source strings
-- as well as their clipping boxes, so an ellipsis cannot count as a fix.
X.profile.placement='bottom';X.profile.showPet=false
X.profile.showRank=true;X.profile.showKills=true
P.rank={level=0,xp=0,cap=750,left=750,total=0,ceiling=750}
for _,scale in ipairs({.85,.9,.95,1,.85}) do
 X.profile.scale=scale
 for _,format in ipairs({'percent','eta'}) do
  X.profile.format=format;UI:SetExpanded(true,true)
  check(UI.layout.up,'screenshot drawer expands upward')
  check(UI.inlineCells[2].title:GetText()=='PvP rank:','full rank label survives scale changes')
  check(UI.inlineCells[2].value:GetText()=='0 / 750','full screenshot rank value survives scale changes')
  check(UI.inlineCells[3].title:GetText()=='Kills to level:','full kill label survives scale changes')
  for _,c in ipairs(UI.inlineCells) do
   if c.active then
    check(not c.title:IsTruncated(),'screenshot footer title has clipping clearance')
    check(not c.value:IsTruncated(),'screenshot footer value has clipping clearance')
   end
  end
  local ix,iy=UI.infinity:GetCenter();local lx,ly=UI.label:GetCenter()
  near(ix,lx,'bottom infinity shares numeric horizontal slot')
  near(iy,ly,'bottom infinity shares numeric vertical slot')
 end
end
X.profile.placement='top'
-- Named boundary cases replace a Cartesian product of independent inputs.
-- Keep the reported scales, scale/font extremes and cramped/ultrawide screens.
local cases={
 {"default",1,1,14,.52,1920,1080},
 {"reported 85%",.64,.85,14,.52,1920,1080},
 {"reported 90%",.8,.9,14,.7,1920,1080},
 {"reported 100%",.64,1,14,.7,1920,1080},
 {"smallest text",.64,.5,10,.42,800,600},
 {"short viewport",1.25,1.5,18,.7,800,220},
 {"wide text",1,.85,18,.7,800,600},
 {"ultrawide",1.25,1.5,18,.52,3440,1440},
 {"narrow text",.8,.75,14,.42,800,600},
 {"scaled parent",1.25,1.25,10,.7,1920,1080},
}
local headers={
 {"xp","percent"},{"xp","fraction"},{"xp","left"},
 {"xp","leftPercent"},{"xp","eta"},{"xp","kills"},
 {"pvp","honor"},{"pvp","rankLeft"},
}
P.pet={xp=123456,cap=500000,level=9,name='Wolf'}
P.rank={level=0,xp=0,cap=75000,left=75000,total=123456789,ceiling=987654321}
for _,case in ipairs(cases) do
 local name,rootScale,scale,size,shape,vw,vh=unpack(case)
 UIParent:SetScale(rootScale);UIParent:SetSize(vw,vh)
 X.profile.scale=scale;X.profile.fontSize=size
 W.fontWidths={['Fonts\\FRIZQT__.TTF']=shape}
 for _,o in ipairs(W.objects) do o.xpMeasureKey=nil end
 -- Cover all visibility combinations once at the tight wide-text boundary.
 -- Other cases retain all footer items, the largest geometry requirement.
 local masks=name=='wide text' and {0,1,2,3,4,5,6,7} or {7}
 X.profile.mode='xp'
 for _,mask in ipairs(masks) do
  X.profile.showPet=mask%2==1;X.profile.showRank=math.floor(mask/2)%2==1;X.profile.showKills=mask>=4
  UI:SetExpanded(true,true)
  for _,c in ipairs(UI.cells) do
   check(not c.title:IsTruncated(),name..': stat title fits')
   check(not c.value:IsTruncated(),name..': stat value fits')
   separated(c)
  end
  for _,c in ipairs(UI.inlineCells) do
   if c.active then
    check(not c.title:IsTruncated(),name..': footer title fits')
    check(not c.value:IsTruncated(),name..': footer value fits')
   end
  end
  local gx,_,gw=UI.inlineGroup:Rect();local dx,_,dw=UI.details:Rect()
  near(gx+gw/2,dx+dw/2,name..': footer group centered')
  check(gw<=dw+.001,name..': footer stays inside drawer')
 end
 for _,header in ipairs(headers) do
  X.profile.mode=header[1]
  if header[1]=='xp' then X.profile.format=header[2] else X.profile.pvpFormat=header[2] end
  UI:SetExpanded(true,true)
  check(not UI.label:IsTruncated(),name..': '..header[2]..' header fits')
  local ix,iy=UI.infinity:GetCenter();local lx,ly=UI.label:GetCenter()
  near(ix,lx,name..': infinity shares horizontal slot')
  near(iy,ly,name..': infinity shares vertical slot')
  for _,c in ipairs(UI.cells) do
   if c:IsShown() then
    check(not c.title:IsTruncated(),name..': XP/PvP title fits')
    check(not c.value:IsTruncated(),name..': XP/PvP value fits')
    separated(c)
   end
  end
 end
 X.profile.mode='xp';X.levelNotice={seconds=3600};UI:Layout()
 check(not UI.levelText:IsTruncated(),name..': level notice fits')
 X.levelNotice=nil;UI:Layout()
end
-- No font/measurement/symbol geometry work is introduced on animation frames.
UIParent:SetScale(1);UIParent:SetSize(1920,1080)
X.profile.scale=.85;X.profile.fontSize=14;X.profile.format='eta'
X.profile.showRank=true;X.profile.showKills=true;X.profile.showPet=false
UI:SetExpanded(false,true);UI:SetExpanded(true)
W.beginWork();while UI.animation do UI:Animate(1/60) end;local work=W.endWork()
for _,name in ipairs({'SetFont','GetUnboundedStringWidth','GetStringHeight'}) do
 check(not work[name],'no '..name..' work in animation')
end
W.svg('dist/preview-text-85.svg',UI.frame)
X.profile.scale=1;UI:SetExpanded(true,true);W.svg('dist/preview-text-100.svg',UI.frame)
X.profile.mode='pvp';UI:SetExpanded(true,true);W.svg('dist/preview-text-pvp.svg',UI.frame)
print('PASS: '..count..' fractional typography assertions (synthetic raster metrics)')
