-- Regression tests from the four actual 0.3 screenshots; fixtures remain offline.
local W=dofile('tests/wow_mock.lua');local ns=W.load()
local X,UI,O,M=ns.owner,ns.UI,ns.Options,ns.Model
local n=0
local function eq(a,b,why) n=n+1;assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,why) n=n+1;assert(math.abs(a-b)<.001,(why or 'near')..': '..a..' ~= '..b) end
local function hover() UI.frame.scripts.OnEnter();return W.tooltip.lines end
local function fresh()
 X.session=M.NewSession(X.character,GetServerTime());X.tracker.session=X.session
 X.tracker.xp=12345;X.tracker.cap=95000;X.profile.format='eta';UI:Layout()
end
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false)
eq(X.db.expandedOnce,false)
fresh();local lines=hover()
eq(lines[1][1],'No XP activity in this session yet.')
eq(lines[2][1],'12,345 / 95,000 (13.0%)');eq(#lines,3)
eq(UI.infinity:IsShown(),true);eq(UI.label:GetText(),'')
-- Automatic previews do not teach the interaction; actual clicks do.
X:LevelUp();W.advance(.3);eq(X.db.expandedOnce,false)
X:Toggle();eq(X.db.expandedOnce,false,'closing automatic preview is not deliberate expansion')
W.click(UI.frame);eq(X.db.expandedOnce,true)
X:Toggle();W.advance(.3);eq(#hover(),2)
SlashCmdList.XPISLAND('');M.Duplicate(X.db,'Shared','Independent');O:Switch('Independent')
eq(X.db.expandedOnce,true);eq(X.profile.expandedOnce,nil)
X.db.profiles.Shared=M.Copy(X.profile);O:Switch('Shared');eq(X.db.expandedOnce,true)
local saved=M.Copy(X.db);local restored=M.Database(saved)
eq(restored.expandedOnce,true,'reload database normalization preserves account-wide state')
M.SelectProfile(restored,'AnotherCharacter','Shared');eq(restored.expandedOnce,true)
eq(M.Database({expandedOnce='true'}).expandedOnce,false,'malformed state does not suppress onboarding')
-- Tooltip content is precise in all modes and no longer includes a tutorial.
for _,format in ipairs({'percent','fraction','left','leftPercent'}) do
 X.profile.format=format;UI:Layout();lines=hover();eq(#lines,1);eq(lines[1][1],'12,345 / 95,000 (13.0%)')
end
-- Resetting a session leaves the learned interaction intact.
SlashCmdList.XPISLAND('reset');eq(X.db.expandedOnce,true)
fresh();X.session.total=100;X.session.buckets.other=100;M.RateAward(X.session,100);UI:Update()
eq(UI.infinity:IsShown(),false);eq(UI.label:GetText(),'—')
eq(hover()[1][1],M.ETAMessages.warming)
UI.cells[3].scripts.OnEnter();eq(#W.tooltip.lines,2);eq(W.tooltip.lines[2][1],M.ETAMessages.warming)
X.session.seconds=60;UI:Update();eq(UI.infinity:IsShown(),false);eq(UI.label:GetText(),'13h 47m')
eq(hover()[1][1],'13 hours, 47 minutes at your current rate')
X.session.seconds=3660;UI:Update();eq(UI.infinity:IsShown(),true);eq(X.session.total,100)
eq(hover()[1][1],M.ETAMessages.idle)
X.session.incomplete=true;UI:Update();eq(UI.infinity:IsShown(),false);eq(UI.label:GetText(),'—')
eq(hover()[1][1],M.ETAMessages.unavailable)
-- Legacy rate history warmup is distinct even after many session hours.
fresh();X.session.total=100;X.session.seconds=7200;X.session.rate=nil;UI:Update()
eq(hover()[1][1],M.ETAMessages.warming)
fresh();UI.infinitySupported=false;UI:Update();eq(UI.infinity:IsShown(),false);eq(UI.label:GetText(),'n/a')
UI.infinitySupported=true;UI:Update();eq(UI.infinity:IsShown(),true);eq(UI.label:GetText(),'')
-- The shared dropdown factory replaces the actual Classic template's TOP
-- anchors. Every field stays centered, single-line and left of its arrow.
local longName=string.rep('Wideprofile-',4)
M.Duplicate(X.db,'Shared',longName);O:Switch(longName)
for _,font in ipairs({'Game tooltip','Arial','Friz Quadrata','Missing custom font'}) do
 for _,scale in ipairs({.5,1,1.5}) do
  X.profile.font=font;X.profile.scale=scale;X:ApplyProfile();O:Refresh()
  O.frame:SetScale(scale)
  for _,d in ipairs(O.dropdowns) do
   local dx,dy,dw,dh=d:Rect();local tx,ty,tw,th=d.Text:Rect();local ax=d.Arrow:Rect()
   eq(#d.Text.points,2);eq(d.Text.points[1][1],'LEFT');eq(d.Text.points[2][1],'RIGHT')
   near(ty+th/2,dy+dh/2,'dropdown vertical center');near(tx,dx+9*scale)
   near(tx+tw,ax-3*scale,'text stops before arrow');eq(d.Text.justifyV,'MIDDLE');eq(d.Text.wrap,false)
   eq(ty>=dy and ty+th<=dy+dh,true,'selected text box inside border')
  end
 end
end
W.choose(O.format,'leftPercent');eq(O.format.Text:GetText(),'XP Remaining (%)')
eq(O.active.Text:GetText(),longName,'long profile selection preserved')
-- Measured rows with equally inset visible text, including larger font metrics.
for _,size in ipairs({10,12,14,18}) do
 for _,placement in ipairs({'top','bottom'}) do
  for _,scale in ipairs({.5,1,1.5}) do
   X.profile.fontSize=size;X.profile.scale=scale;X.profile.placement=placement;UI:SetExpanded(true,true)
   local _,fy,_,fh=UI.frame:Rect();local _,hy,_,hh=UI.header:Rect()
   local _,ty,_,th=UI.cells[1].title:Rect();local _,vy=UI.cells[5].value:Rect()
   local drawerTop=placement=='bottom' and fy+fh or hy
   local drawerBottom=placement=='bottom' and hy+hh or fy
   near(drawerTop-(ty+th),vy-drawerBottom,'equal visual top and bottom padding')
   eq(UI.cells[1].title.justify,'CENTER');eq(UI.cells[8].value.justify,'CENTER')
   local _,cy,_,ch=UI.cells[5]:Rect();eq(vy>=cy,true,'value fits second row')
   eq(th>0 and ch+.001>=th+(size*1.25+3)*scale,true,'measured font block fits')
  end
 end
end
X.profile=M.Profile();X.db.profiles.Shared=X.profile;X.profileName='Shared';X.profile.placement='bottom';X:CancelAutoCollapse()
fresh();X.profile.placement='bottom';UI:SetExpanded(true,true);W.svg('dist/preview-padding-04.svg',UI.frame)
X.profile.format='eta';UI:SetExpanded(false,true);W.svg('dist/preview-infinity-04.svg',UI.frame)
O:Page(false);O.frame:Show();W.svg('dist/preview-settings-04.svg',O.frame)
O:Page(true);O.frame:Show();W.svg('dist/preview-profiles-04.svg',O.frame)
print('PASS: '..n..' polish assertions (onboarding, exact tooltips, ETA states, dropdown anchors, drawer padding)')
