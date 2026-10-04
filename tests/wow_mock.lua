-- Strict, deterministic WoW UI/event double. This is not an in-game renderer.
local W={objects={},time=0,wall=1000,timers={},level=10,xp=100,cap=1000,rested=0,instance="none",capped=false,combat=false}
local methods={}
local mt={__index=function(_,key) return methods[key] end}
local function object(kind,name,parent)
    local o=setmetatable({kind=kind,name=name,parent=parent,scripts={},points={},shown=true,scale=1,alpha=1,frameLevel=parent and parent.frameLevel+1 or 0,width=0,height=0},mt)
    W.objects[#W.objects+1]=o
    o.order=#W.objects
    if name then _G[name]=o end
    return o
end
function CreateFrame(kind,name,parent,template)
    local o=object(kind,name,parent);o.template=template
    if template=="UIPanelButtonTemplate" then
        o.fontString=o:CreateFontString(nil,"OVERLAY");o.fontString:SetPoint("CENTER");o.fontString:SetFont("Fonts\\FRIZQT__.TTF",14,"")
    elseif template=="BasicFrameTemplateWithInset" then
        o.TitleText=o:CreateFontString(nil,"OVERLAY");o.TitleText:SetPoint("TOP",0,-4)
        o.CloseButton=CreateFrame("Button",nil,o,"UIPanelButtonTemplate")
        o.CloseButton:SetSize(24,24);o.CloseButton:SetPoint("TOPRIGHT",0,0);o.CloseButton:SetText("×")
        o.CloseButton:SetScript("OnClick",function() o:Hide() end)
    elseif template=="UICheckButtonTemplate" then
        o.Text=o:CreateFontString(nil,"OVERLAY");o.Text:SetPoint("LEFT",o,"RIGHT",-2,0)
    elseif template=="UISliderTemplate" then o:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal") end
    return o
end
function methods:CreateTexture(name,layer) local t=object("Texture",name,self);t.layer=layer;return t end
function methods:CreateFontString(name,layer) local t=object("FontString",name,self);t.layer=layer;return t end
function methods:SetSize(w,h) assert(w>=0 and h>=0);self.width,self.height=w,h end
function methods:SetWidth(w) assert(w>=0);self.width=w end
function methods:SetHeight(h) assert(h>=0);self.height=h end
function methods:SetScale(s) assert(s>0);self.scale=s end
function methods:GetEffectiveScale() return self.scale*(self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetPoint(point,a,b,c,d)
    local relative,relativePoint,x,y
    if type(a)=="table" then relative=a;relativePoint=b or point;x=c or 0;y=d or 0
    else relative=self.parent;relativePoint=point;x=a or 0;y=b or 0 end
    self.points[#self.points+1]={point,relative,relativePoint,x,y}
end
function methods:ClearAllPoints() self.points={};self.all=nil end
function methods:SetAllPoints(other) self.all=other or self.parent end
local axes={TOPLEFT={0,1},TOP={.5,1},TOPRIGHT={1,1},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,0},BOTTOM={.5,0},BOTTOMRIGHT={1,0}}
function methods:Rect()
    if self==UIParent then return 0,0,self.width*self.scale,self.height*self.scale end
    if self.all then return self.all:Rect() end
    local scale=self:GetEffectiveScale()
    local width,height=self.width*scale,self.height*scale
    if self.kind=="FontString" then
        if width==0 then width=self:GetStringWidth()*scale end
        if height==0 then height=(self.fontSize or 12)*1.25*scale end
    end
    local x,y=0,0
    local anchors={}
    for _,p in ipairs(self.points) do
        local rx,ry,rw,rh=p[2]:Rect();local rp=axes[p[3]]
        anchors[#anchors+1]={axes[p[1]][1],axes[p[1]][2],rx+rw*rp[1]+p[4]*scale,ry+rh*rp[2]+p[5]*scale}
    end
    if #anchors>=2 then
        local a,b=anchors[1],anchors[2]
        if a[1]~=b[1] then width=(b[3]-a[3])/(b[1]-a[1]) end
        if a[2]~=b[2] then height=(b[4]-a[4])/(b[2]-a[2]) end
    end
    if anchors[1] then x=anchors[1][3]-anchors[1][1]*width;y=anchors[1][4]-anchors[1][2]*height end
    return x,y,width,height
end
function methods:GetWidth() local _,_,w=self:Rect();return w/self:GetEffectiveScale() end
function methods:GetHeight() local _,_,_,h=self:Rect();return h/self:GetEffectiveScale() end
function methods:GetSize() return self:GetWidth(),self:GetHeight() end
function methods:GetCenter() local x,y,w,h=self:Rect();local s=self:GetEffectiveScale();return (x+w/2)/s,(y+h/2)/s end
function methods:GetTop() local _,y,_,h=self:Rect();return (y+h)/self:GetEffectiveScale() end
function methods:SetFrameLevel(n) self.frameLevel=n end
function methods:GetFrameLevel() return self.frameLevel end
function methods:SetFrameStrata(s) self.strata=s end
function methods:SetScript(event,f) self.scripts[event]=f end
function methods:RegisterEvent(e) self.events=self.events or {};self.events[e]=true end
function methods:RegisterUnitEvent(e) self:RegisterEvent(e) end
function methods:UnregisterAllEvents() self.events={} end
function methods:Show() local changed=not self.shown;self.shown=true;if changed and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() local changed=self.shown;self.shown=false;if changed and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetTexture(t) self.texture=t end
function methods:SetColorTexture(r,g,b,a) self.color={r,g,b,a or 1} end
function methods:SetVertexColor(r,g,b,a) self.tint={r,g,b,a or 1} end
function methods:SetTexCoord(...) self.coords={...} end
function methods:SetFont(path,size,flags) self.fontPath,self.fontSize,self.fontFlags=path,size,flags;return true end
function methods:SetText(text) self.text=tostring(text);if self.fontString then self.fontString:SetText(text) end end
function methods:GetText() return self.text or "" end
function methods:SetTextColor(r,g,b,a) self.color={r,g,b,a or 1} end
function methods:GetStringWidth() return #(self.text or "")*(self.fontSize or 12)*.52 end
methods.GetUnboundedStringWidth=methods.GetStringWidth
function methods:GetFont() return self.fontPath,self.fontSize,self.fontFlags end
function methods:SetShadowColor() end
function methods:SetShadowOffset() end
function methods:GetFontString() return self.fontString end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:SetHitRectInsets() end
function methods:SetJustifyH(v) self.justify=v end
function methods:SetWordWrap(v) self.wrap=v end
function methods:EnableMouse(v) self.mouse=v end
function methods:EnableMouseWheel(v) self.wheel=v end
function methods:SetMovable(v) self.movable=v end
function methods:SetClampedToScreen(v) self.clamped=v end
function methods:RegisterForDrag() end
function methods:StartMoving() self.moving=true end
function methods:StopMovingOrSizing() self.moving=false end
function methods:SetAutoFocus(v) self.autoFocus=v end
function methods:SetMaxLetters(v) self.maxLetters=v end
function methods:SetTextInsets() end
function methods:ClearFocus() end
function methods:SetBackdrop() end
function methods:SetBackdropColor() end
function methods:SetBackdropBorderColor() end
function methods:SetOrientation() end
function methods:SetMinMaxValues(a,b) self.minimum,self.maximum=a,b end
function methods:SetValueStep(v) self.step=v end
function methods:SetObeyStepOnDrag() end
function methods:SetThumbTexture(t) self.thumb=self:CreateTexture(nil,"OVERLAY");self.thumb:SetTexture(t) end
function methods:GetThumbTexture() return self.thumb end
function methods:SetValue(v)
    self.value=v
    if self.thumb then self.thumb:ClearAllPoints();self.thumb:SetPoint("CENTER",self,"LEFT",(v-self.minimum)/(self.maximum-self.minimum)*self.width,0) end
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end
end

UIParent=object("Frame","UIParent");UIParent:SetSize(1728,1080)
UISpecialFrames={};SlashCmdList={}
GameTooltipText={GetFont=function() return "Fonts\\FRIZQT__.TTF",12,"" end}
GameTooltip={SetOwner=function(_,owner,anchor) W.tooltip={owner=owner,anchor=anchor,lines={}} end,
AddLine=function(_,...) W.tooltip.lines[#W.tooltip.lines+1]={...} end,Show=function() end,Hide=function() end}
DEFAULT_CHAT_FRAME={AddMessage=function(_,msg) W.lastMessage=msg end}
Settings={KEYBINDINGS_CATEGORY_ID=7,OpenToCategory=function(...) W.settingsOpened={...} end}
ColorPickerFrame={SetupColorPickerAndShow=function(_,info) W.colorInfo=info end,GetColorRGB=function() return .1,.2,.3 end}
function GetBuildInfo() return "1.60.1","70205","Oct 3 2026",16001 end
function GetTime() return W.time end
function GetServerTime() return W.wall end
function UnitLevel() return W.level end
function UnitXP() return W.xp end
function UnitXPMax() return W.cap end
function GetXPExhaustion() return W.rested end
function UnitGUID() return "Player-1" end
function UnitName() return "Test" end
function GetRealmName() return "Realm" end
function UnitIsConnected() return true end
function IsInInstance() return W.instance~="none",W.instance end
function IsXPUserDisabled() return false end
function GetMaxPlayerLevel() return 60 end
function GetMaxLevelForPlayerExpansion() return 60 end
function InCombatLockdown() return W.combat end
function GetBindingKey() return nil end
GameRulesUtil={CanShowExperienceBar=function() return not W.capped end}
function Logout() end
function Quit() end
function CancelLogout() end
function ReloadUI() end
C_UI={Reload=function() end}
function hooksecurefunc(a,b,c)
    local t,key,callback
    if type(a)=="table" then t,key,callback=a,b,c else t,key,callback=_G,a,b end
    local original=t[key];assert(type(original)=="function",key)
    t[key]=function(...) local r={original(...)};callback(...);return unpack(r) end
end
local function timer(delay,callback,repeatEvery)
    local t={at=W.time+delay,callback=callback,repeatEvery=repeatEvery,Cancel=function(self) self.cancelled=true end}
    W.timers[#W.timers+1]=t;return t
end
C_Timer={After=function(delay,f) return timer(delay,f) end,NewTimer=function(delay,f) return timer(delay,f) end,NewTicker=function(delay,f) return timer(delay,f,delay) end}
function W.advance(seconds)
    W.time=W.time+seconds;W.wall=W.wall+seconds
    local timers=W.timers;W.timers={}
    for _,t in ipairs(timers) do
        if not t.cancelled then
            if t.at<=W.time then t.callback();if t.repeatEvery then t.at=W.time+t.repeatEvery;W.timers[#W.timers+1]=t end
            else W.timers[#W.timers+1]=t end
        end
    end
end
function W.event(event,...)
    for _,o in ipairs(W.objects) do
        if o.events and o.events[event] and o.scripts.OnEvent then o.scripts.OnEvent(o,event,...) end
    end
end
function W.click(button) if button.kind=="CheckButton" then button.checked=not button.checked end;button.scripts.OnClick(button,"LeftButton") end
StatusTrackingBarInfo={BarsEnum={Experience=1,Reputation=2,Honor=3}}
StatusTrackingBarManager={CanShowBar=function() return true end,UpdateBarsShown=function() W.barUpdates=(W.barUpdates or 0)+1 end}
COMBATLOG_XPGAIN_FIRSTPERSON="%s dies, you gain %d experience."
COMBATLOG_XPGAIN_EXHAUSTION1="%s dies, you gain %d experience. (%s exp %s bonus)"
COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED="You gain %d experience."

function W.load()
    local ns={}
    for _,name in ipairs({"Model","UI","Options","Core"}) do assert(loadfile("XPIsland/"..name..".lua"))("XPIsland",ns) end
    return ns
end

function W.svg(path,root)
    local function xml(s) return (tostring(s):gsub("&","&amp;"):gsub("<","&lt;"):gsub('"','&quot;')) end
    local function color(c) return string.format("rgb(%d,%d,%d)",c[1]*255,c[2]*255,c[3]*255) end
    local f=assert(io.open(path,"w"));local rw,rh=UIParent:GetSize()
    f:write(string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><rect width="100%%" height="100%%" fill="#242831"/>',rw,rh))
    local ordered={}
    for _,o in ipairs(W.objects) do
        local p=o;local include=not root
        while p do if p==root then include=true end;p=p.parent end
        if include and o:IsVisible() and (o.kind=="Texture" or o.kind=="FontString" or o.kind=="EditBox" or o.template) then ordered[#ordered+1]=o end
    end
    local layers={BACKGROUND=0,ARTWORK=1,OVERLAY=2}
    table.sort(ordered,function(a,b)
        local al=a.kind=="EditBox" and a.frameLevel*10+2 or a.parent.frameLevel*10+(layers[a.layer] or 0)
        local bl=b.kind=="EditBox" and b.frameLevel*10+2 or b.parent.frameLevel*10+(layers[b.layer] or 0)
        if al==bl then return a.order<b.order end
        return al<bl
    end)
    for i,o in ipairs(ordered) do
        local x,y,w,h=o:Rect();y=rh-y-h
        local c=o.color or o.tint or {1,1,1,1}
        if o.template and o.kind~="EditBox" then
            -- Layout-only stand-ins: Blizzard's native art is not bundled here.
            local fill=o.template=="UIPanelButtonTemplate" and "#681a16" or "#211e19"
            local stroke=o.template=="UIPanelButtonTemplate" and "#9c8258" or "#756753"
            f:write(string.format('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" rx="3" fill="%s" stroke="%s" stroke-width="2"/>',x,y,w,h,fill,stroke))
            if o.kind=="CheckButton" and o.checked then
                f:write(string.format('<text x="%.2f" y="%.2f" fill="#ffd100" font-size="22">✓</text>',x+4,y+22))
            end
        elseif o.kind=="FontString" or o.kind=="EditBox" then
            if o.kind=="EditBox" then f:write(string.format('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="#10100f" stroke="#817457"/>',x,y,w,h)) end
            local s=o.fontSize*o:GetEffectiveScale()
            if o.kind=="EditBox" then x=x+8;y=y+(h-s)/2 end
            local anchor=o.justify=="RIGHT" and "end" or "start"
            local lines={o.text or ""}
            if o.wrap and w>0 then
                lines={};local line=""
                for word in (o.text or ""):gmatch("%S+") do
                    if #line>0 and (#line+#word+1)*s*.52>w then lines[#lines+1]=line;line=word
                    else line=line=="" and word or line.." "..word end
                end
                lines[#lines+1]=line
            end
            for li,line in ipairs(lines) do
                f:write(string.format('<text x="%.2f" y="%.2f" font-family="Georgia" font-size="%.2f" fill="%s" text-anchor="%s">%s</text>',o.justify=="RIGHT" and x+w or x,y+s+(li-1)*s*1.2,s,color(c),anchor,xml(line)))
            end
        elseif o.texture and o.texture:find("cap.tga",1,true) then
            local co=o.coords
            f:write(string.format('<defs><clipPath id="cap%d"><rect x="%f" y="%f" width="%f" height="%f"/></clipPath></defs><circle cx="%f" cy="%f" r="%f" fill="%s" clip-path="url(#cap%d)"/>',i,x,y,w,h,x+h*(.5-co[1]),y+h/2,h/2,color(c),i))
        elseif o.texture and o.coords then
            local co=o.coords
            local corner=co[1]==0 and (co[3]==0 and "tl" or "bl") or (co[3]==0 and "tr" or "br")
            local d
            if corner=="tl" then d=string.format("M %f %f Q %f %f %f %f L %f %f Z",x,y+h,x,y,x+w,y,x+w,y+h)
            elseif corner=="tr" then d=string.format("M %f %f Q %f %f %f %f L %f %f Z",x,y,x+w,y,x+w,y+h,x,y+h)
            elseif corner=="bl" then d=string.format("M %f %f Q %f %f %f %f L %f %f Z",x,y,x,y+h,x+w,y+h,x+w,y)
            else d=string.format("M %f %f Q %f %f %f %f L %f %f Z",x+w,y,x+w,y+h,x,y+h,x,y) end
            f:write(string.format('<path d="%s" fill="%s" opacity="%f"/>',d,color(c),c[4]))
        else f:write(string.format('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" opacity="%.2f"/>',x,y,w,h,color(c),c[4])) end
    end
    f:write('<text x="24" y="1056" font-family="Arial" font-size="14" fill="#aaa">OFFLINE LAYOUT FIXTURE — substitute font and native-control outlines; not an in-game screenshot</text></svg>');f:close()
end
return W
