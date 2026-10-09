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
local shapes={.42,.52,.7} -- narrow, standard, wide advances
for _,rootScale in ipairs({.64,.8,1,1.25}) do
 UIParent:SetScale(rootScale)
 for _,scale in ipairs({.5,.75,.85,1,1.25,1.5}) do
  for _,size in ipairs({10,14,18}) do
   for _,shape in ipairs(shapes) do
    W.fontWidths={['Fonts\\FRIZQT__.TTF']=shape}
    -- Flush synthetic metric changes through a different family key.
    for _,o in ipairs(W.objects) do o.xpMeasureKey=nil end
    for _,viewport in ipairs({{800,220},{800,600},{1920,1080},{3440,1440}}) do
     UIParent:SetSize(unpack(viewport))
     X.profile.scale=scale;X.profile.fontSize=size
     for mask=0,7 do
      X.profile.showPet=mask%2==1;X.profile.showRank=math.floor(mask/2)%2==1;X.profile.showKills=mask>=4
      P.pet={xp=123456,cap=500000,level=9,name='Wolf'}
      P.rank={level=0,xp=0,cap=75000,left=75000,total=123456789,ceiling=987654321}
      UI:SetExpanded(true,true)
      for _,c in ipairs(UI.cells) do
       check(not c.title:IsTruncated(),'stat title fits at fractional effective scale')
       check(not c.value:IsTruncated(),'stat value fits at fractional effective scale')
       separated(c)
      end
      for _,c in ipairs(UI.inlineCells) do
       if c.active then
        check(not c.title:IsTruncated(),'all optional footer titles fit')
        check(not c.value:IsTruncated(),'all optional footer values fit')
       end
      end
      local gx,_,gw=UI.inlineGroup:Rect();local dx,_,dw=UI.details:Rect()
      near(gx+gw/2,dx+dw/2,'optional group centered')
      check(gw<=dw+.001,'full group stays inside drawer')
     end
     for _,mode in ipairs({'xp','pvp'}) do
      X.profile.mode=mode
      for _,format in ipairs({'percent','fraction','left','eta','kills'}) do
       X.profile.format=format;X.profile.pvpFormat='remaining'
       UI:SetExpanded(true,true)
       check(not UI.label:IsTruncated(),'header number/unavailable text fits shared slot')
       local ix,iy=UI.infinity:GetCenter();local lx,ly=UI.label:GetCenter()
       near(ix, lx,'infinity and number share horizontal slot center')
       near(iy, ly,'infinity and number share vertical slot center')
       for _,c in ipairs(UI.cells) do
        if c:IsShown() then
         check(not c.title:IsTruncated(),'XP/PvP title fits')
         check(not c.value:IsTruncated(),'XP/PvP numeric/cap/unavailable fits')
         separated(c)
        end
       end
      end
     end
     X.profile.mode='xp'
     X.levelNotice={seconds=3600};UI:Layout()
     check(not UI.levelText:IsTruncated(),'level-up notice has shared width and height clearance')
     X.levelNotice=nil;UI:Layout()
    end
   end
  end
 end
end
-- No font/measurement/symbol geometry work is introduced on animation frames.
UIParent:SetScale(1);UIParent:SetSize(1920,1080)
X.profile.scale=.85;X.profile.fontSize=14;X.profile.format='eta'
X.profile.showRank=true;X.profile.showKills=true;X.profile.showPet=false
UI:SetExpanded(false,true);UI:SetExpanded(true)
W.beginWork();while UI.animation do UI:Animate(1/60) end;local work=W.endWork()
for _,name in ipairs({'SetFont','GetUnboundedStringWidth','GetStringHeight','CreateLine','SetThickness','SetStartPoint','SetEndPoint'}) do
 check(not work[name],'no '..name..' work in animation')
end
W.svg('dist/preview-text-85.svg',UI.frame)
X.profile.scale=1;UI:SetExpanded(true,true);W.svg('dist/preview-text-100.svg',UI.frame)
X.profile.mode='pvp';UI:SetExpanded(true,true);W.svg('dist/preview-text-pvp.svg',UI.frame)
print('PASS: '..count..' fractional typography assertions (synthetic raster metrics)')
