-- Native API call counts are a workload proxy, not in-game FPS measurements.
local W=dofile('tests/wow_mock.lua');local ns=W.load();local X,UI,M=ns.owner,ns.UI,ns.Model
local n=0
local function check(value,why) n=n+1;assert(value,why) end
local function near(a,b,why) check(math.abs(a-b)<.000001,why) end
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false)
X.profile.autoCollapse=false
local scans=0;local estimate=M.Estimate;M.Estimate=function(...) scans=scans+1;return estimate(...) end
local out=assert(io.open('dist/frame-work-results.txt','w'))
for _,fraction in ipairs({0,.001,.1,.475,1}) do
 X.tracker.xp=X.tracker.cap*fraction;UI:Update()
 for _,hz in ipairs({30,60,120}) do
  UI:SetExpanded(false,true);UI:SetExpanded(true);local objects=#W.objects;W.beginWork();scans=0
  local frames=0;local prev=0;local midpoint
  while UI.animation do
   UI:Animate(1/hz);frames=frames+1
   check(UI.progress>prev,'each delivered frame advances the shape');prev=UI.progress
   if frames==hz/10 then midpoint=UI.progress end
   local height=UI.layout.barHeight+(UI.layout.panelHeight-UI.layout.barHeight)*UI.progress
   near(UI.frame:GetHeight(),height,'geometry uses time-based progress')
   local alpha=math.max(0,math.min(1,(UI.progress-.35)/.65));alpha=alpha*alpha*(3-2*alpha)
   near(UI.details.alpha,alpha,'fade and geometry share progress')
  end
  local counts=W.endWork();local total=0;for _,v in pairs(counts) do total=total+v end
  check(total/frames<170,'bounded native operations per frame at every fill')
  for _,k in ipairs({'SetFont','SetText','GetUnboundedStringWidth','GetStringHeight','SetScale','ClearAllPoints','SetTexture','SetColorTexture','SetVertexColor','CreateTexture','CreateFontString'}) do
   check(not counts[k],'no static '..k..' work during animation')
  end
  check(scans==0,'no rate scans in animation');check(#W.objects==objects,'no object allocation')
  check(UI.progress==1 and not UI.frame.scripts.OnUpdate,'one exact endpoint, callback removed')
  check(frames==math.ceil(.22*hz),'duration follows elapsed time, not a fixed frame count')
  local t=.1/.22;near(midpoint,(1-(1+7*t)*math.exp(-7*t))/(1-8*math.exp(-7)),'same progress after 100ms at each cadence')
  out:write(string.format('%3d Hz | XP %5.1f%% | %2d frames | %4d UI calls | %.1f/frame | %d rate scans\n',hz,fraction*100,frames,total,total/frames,scans))
 end
end
-- Jitter, low FPS and a large missed-frame jump complete without replaying work.
for _,sequence in ipairs({{.006,.048,.004,.08,.01,.15},{.001,.5},{.1,.1,.1}}) do
 UI:SetExpanded(false,true);UI:SetExpanded(true)
 for _,dt in ipairs(sequence) do if UI.animation then UI:Animate(dt) end end
 check(UI.progress==1 and not UI.animation,'long/jitter frame sequence settles exactly')
end
UI:SetExpanded(false);UI:Animate(.04);local before=UI.progress
UI:SetExpanded(true);near(UI.progress,before,'interruption remains position-continuous')
UI:Animate(.5);check(UI.progress==1 and not UI.frame.scripts.OnUpdate,'interrupted long frame settles')
-- Model changes remain a separate update, including label-width remeasurement.
UI:SetExpanded(false);UI:Animate(.02);before=UI.progress;X.profile.format='fraction';X.tracker.cap=95000000;X.tracker.xp=65000000
UI:Update();near(UI.progress,before,'model update preserves in-flight position');UI:Animate(.5)
check(UI.progress==0 and not UI.animation,'model update preserves target')
UI:Update() -- one normal refresh accommodates the new settled cell width
W.beginWork();for i=1,60 do UI:Update() end;local idle=W.endWork()
check(not idle.SetFont and not idle.GetUnboundedStringWidth and not idle.SetText,'cache unchanged fonts, labels and measurements at rest')
out:write('No frames/textures allocated; no font/text/measurement/color/anchor-clear work or model rate scans in animation.\n')
out:close()
print('PASS: '..n..' frame-work assertions across 30/60/120 Hz, jitter, long frames, interruption and idle caching')
