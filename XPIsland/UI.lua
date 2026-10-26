local _, ns = ...
local M, P = ns.Model, ns.Progression
local UI = {}
ns.UI = UI
local TRACK_COLOR=ns.Themes.Get().trackColor
local FLASH_COLOR={1,1,1}
local SOURCE_KEYS={"kills","quests","dungeons","other"}
local MEDIA = "Interface\\AddOns\\XPIsland\\media\\rounded.tga"

local function applyColor(object,role)
    local ok,err=ns.App.ui:Color(object,role)
    if not ok then ns.App.log:Warn(err.message,{code=err.code}) end
end

-- SND owns font resolution, fallback and late media callbacks. XPIsland keeps
-- its physical-pixel clipping allowance and animation-time measurement cache.
function UI.ApplyFont(text,size,flags)
    local ok,err=ns.App.fonts:Apply(text,'body',{size=size,flags=flags or ''})
    if not ok then ns.App.log:Warn(err.message,{code=err.code}) end
    return text:GetFont()
end

-- Native glyph advances and clipping boxes round independently at fractional
-- effective scales. Give every role symmetric physical-pixel breathing room,
-- and include effective scale in the cache rather than measuring at old scale.
function UI.Measure(text)
    local path,size,flags=text:GetFont()
    local scale=text:GetEffectiveScale()
    local key=tostring(path)..":"..size..":"..tostring(flags)..":"..scale..":"..(text:GetText() or "")
    if text.xpMeasureKey~=key then
        text.xpMeasureKey=key
        text.xpTextWidth=(math.ceil(text:GetUnboundedStringWidth()*scale)+4)/scale
        text.xpTextHeight=(math.ceil(text:GetStringHeight()*scale)+2)/scale
    end
    return text.xpTextWidth,text.xpTextHeight
end

function UI.FitText(text,available)
    -- Measure without a previous fit scale feeding back into its own result.
    local width=text.xpNaturalWidth
    local fit=math.min(1,available/math.max(1,width))
    text:SetScale(fit)
    text.xpFitScale=fit
    text:SetWidth(available/fit)
    return fit
end

-- Offsets passed to a scaled FontString are in that FontString's local units.
-- Keep the caller's inset in its parent's coordinate space when fitting text.
function UI.AnchorText(text,point,parent,relativePoint,x,y)
    local fit=text.xpFitScale or 1
    text:SetPoint(point,parent,relativePoint,(x or 0)/fit,(y or 0)/fit)
end

-- Expressway lacks U+221E. Use a packaged alpha mask with a matching shadow;
-- the line-based symbol remained blank on the target client.
function UI.Infinity(parent)
    local f=CreateFrame("Frame",nil,parent)
    local path="Interface\\AddOns\\XPIsland\\media\\infinity.tga"
    f.shadow=f:CreateTexture(nil,"ARTWORK")
    f.symbol=f:CreateTexture(nil,"OVERLAY")
    local shadowLoaded=f.shadow:SetTexture(path)
    local symbolLoaded=f.symbol:SetTexture(path)
    if shadowLoaded==false or symbolLoaded==false then return f,false end
    f.shadow:SetVertexColor(0,0,0,.8)
    applyColor(f.symbol,"text")
    f.shadow:SetPoint("CENTER",f,"CENTER",1,-1)
    f.symbol:SetAllPoints(f)
    f.shadow:Show();f.symbol:Show()
    function f:Layout(size)
        if self.symbolSize==size then return end
        self.symbolSize=size
        -- Keep the 128x64 mask's 2:1 aspect. Its stroke is .12 font units.
        local width,height=size*1.5,size*.75
        self:SetSize(width,height);self.shadow:SetSize(width,height)
    end
    return f,true
end

function UI.Text(parent, size, role)
    local text = parent:CreateFontString(nil, "OVERLAY")
    UI.ApplyFont(text,size)
    text:SetShadowColor(0,0,0,.8); text:SetShadowOffset(1,-1)
    applyColor(text,role or "text")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    return text
end

function UI.Solid(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

function UI.Round(parent, role, inset)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetFrameLevel(parent:GetFrameLevel()+((inset or 0)>0 and 1 or 0))
    holder:SetPoint("TOPLEFT", inset or 0, -(inset or 0))
    holder:SetPoint("BOTTOMRIGHT", -(inset or 0), inset or 0)
    local specs = {
        {"TOPLEFT",0,.25,0,.25}, {"TOPRIGHT",.75,1,0,.25},
        {"BOTTOMLEFT",0,.25,.75,1}, {"BOTTOMRIGHT",.75,1,.75,1},
    }
    local corners = {}
    for _, s in ipairs(specs) do
        local t = holder:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(MEDIA); t:SetTexCoord(s[2],s[3],s[4],s[5])
        applyColor(t,role); t:SetPoint(s[1])
        corners[#corners+1] = t
    end
    local center = UI.Solid(holder, "BACKGROUND", 1,1,1,1)
    local left = UI.Solid(holder, "BACKGROUND", 1,1,1,1)
    local right = UI.Solid(holder, "BACKGROUND", 1,1,1,1)
    for _,texture in ipairs({center,left,right}) do applyColor(texture,role) end
    function holder:Radius(radius)
        if self.radius==radius then return end
        self.radius=radius
        for _, c in ipairs(corners) do c:SetSize(radius, radius) end
        center:ClearAllPoints(); center:SetPoint("TOPLEFT", radius, 0); center:SetPoint("BOTTOMRIGHT", -radius, 0)
        left:ClearAllPoints(); left:SetPoint("TOPLEFT", 0, -radius); left:SetPoint("BOTTOMLEFT", 0, radius); left:SetWidth(radius)
        right:ClearAllPoints(); right:SetPoint("TOPRIGHT", 0, -radius); right:SetPoint("BOTTOMRIGHT", 0, radius); right:SetWidth(radius)
    end
    holder:Radius(14)
    return holder
end

-- One nine-slice image owns both rim and translucent center. Adjacent slices
-- share UV boundaries, avoiding holes between separately rounded layers.
function UI.Chrome(parent,texture,radius)
    local f=CreateFrame("Frame",nil,parent);f:SetAllPoints()
    f.pieces={}
    local uv={0,.25,.75,1}
    for row=1,3 do for col=1,3 do
        local t=f:CreateTexture(nil,"BACKGROUND")
        t:SetTexture(texture)
        t:SetTexCoord(uv[col],uv[col+1],uv[row],uv[row+1])
        if row==2 and col==2 then
            t:SetPoint("TOPLEFT",radius,-radius);t:SetPoint("BOTTOMRIGHT",-radius,radius)
        elseif row==2 then
            local side=col==1 and "LEFT" or "RIGHT"
            t:SetWidth(radius);t:SetPoint("TOP"..side,0,-radius);t:SetPoint("BOTTOM"..side,0,radius)
        elseif col==2 then
            local side=row==1 and "TOP" or "BOTTOM"
            t:SetHeight(radius);t:SetPoint(side.."LEFT",radius,0);t:SetPoint(side.."RIGHT",-radius,0)
        else
            t:SetSize(radius,radius)
            t:SetPoint((row==1 and "TOP" or "BOTTOM")..(col==1 and "LEFT" or "RIGHT"))
        end
        f.pieces[#f.pieces+1]=t
    end end
    f:Hide();return f
end

function UI.Font()
    return UI.label and UI.label:GetFont() or GameTooltipText:GetFont()
end

function UI:PreviewColor(key,value)
    self.previewColors=self.previewColors or {};self.previewColors[key]=value
    if self.frame then self:Update() end
end
function UI:ColorValue(key)
    return self.previewColors and self.previewColors[key] or self.owner.profile[key]
end

-- End caps use a fixed-radius circular texture, cropped (never compressed) at
-- the current XP boundary. Interior segments remain rectangular.
function UI.BarPiece(parent, layer, edge)
    local f=CreateFrame("Frame",nil,parent)
    f.edge=edge
    f.body=UI.Solid(f,layer,1,1,1)
    if edge then
        f.cap=f:CreateTexture(nil,layer)
    end
    f.shading=f:CreateTexture(nil,layer,nil,1)
    f.shading:SetAllPoints(f.body);f.shading:Hide()
    if f.cap then
        f.capShading=f:CreateTexture(nil,layer,nil,1)
        f.capShading:SetAllPoints(f.cap);f.capShading:Hide()
    end
    -- Properties are cached separately: geometry changes every animation frame,
    -- but color, UVs, visibility and most anchors usually do not.
    f.body:SetPoint("LEFT",edge=="left" and 5 or 0,0)
    if f.cap then f.cap:SetPoint("LEFT",0,0) end
    function f:Draw(width,height,amount,color)
        local visible=width*amount
        self.visibleWidth=visible
        if self.visible~=(visible>0) then self.visible=visible>0;self:SetShown(self.visible) end
        if not self.visible then return end
        local geometry=self.drawWidth~=width or self.drawHeight~=height or self.drawAmount~=amount
        if color[1]~=self.r or color[2]~=self.g or color[3]~=self.b then
            self.body:SetColorTexture(color[1],color[2],color[3],1)
            if self.cap then self.cap:SetVertexColor(color[1],color[2],color[3],1) end
            self.r,self.g,self.b=color[1],color[2],color[3]
        end
        if not geometry then return end
        self.drawWidth,self.drawHeight,self.drawAmount=width,height,amount
        self:SetSize(width,height)
        local radius=math.min(height/2,width)
        local start=self.edge=="left" and radius or 0
        local finish=self.edge=="right" and width-radius or width
        local bodyWidth=math.max(0,math.min(visible,finish)-start)
        if self.bodyStart~=start then self.bodyStart=start;self.body:SetPoint("LEFT",start,0) end
        if self.bodyWidth~=bodyWidth or self.bodyHeight~=height then
            self.bodyWidth,self.bodyHeight=bodyWidth,height
            self.body:SetSize(math.max(.001,bodyWidth),height)
        end
        if self.bodyVisible~=(bodyWidth>0) then self.bodyVisible=bodyWidth>0;self.body:SetShown(self.bodyVisible) end
        local shadeVisible=self.shaded and self.bodyVisible or false
        if self.shadingVisible~=shadeVisible then self.shadingVisible=shadeVisible;self.shading:SetShown(shadeVisible) end
        if self.cap then
            local offset=self.edge=="left" and 0 or width-radius
            local capWidth=math.max(0,math.min(radius,visible-offset))
            if self.capOffset~=offset then self.capOffset=offset;self.cap:SetPoint("LEFT",offset,0) end
            if self.capWidth~=capWidth or self.capRadius~=radius or self.capHeight~=height then
                self.capWidth,self.capRadius,self.capHeight=capWidth,radius,height
                self.cap:SetSize(math.max(.001,capWidth),height)
                local u=self.edge=="left" and 0 or .5
                self.cap:SetTexCoord(u,u+.5*capWidth/radius,0,1)
                if self.capShading then self.capShading:SetTexCoord(u,u+.5*capWidth/radius,0,1) end
            end
            if self.capVisible~=(capWidth>0) then self.capVisible=capWidth>0;self.cap:SetShown(self.capVisible) end
            local capShadeVisible=self.shaded and self.capVisible or false
            if self.capShadingVisible~=capShadeVisible then self.capShadingVisible=capShadeVisible;self.capShading:SetShown(capShadeVisible) end
        end
    end
    return f
end

-- A fixed outline belongs to the whole segment, never to the moving XP edge.
-- Anchors follow track geometry without per-frame border updates.
function UI.SegmentBorder(parent,track,level)
    local f=CreateFrame("Frame",nil,parent);f:SetAllPoints(track);f:SetFrameLevel(level)
    f.top=UI.Solid(f,"OVERLAY",1,1,1);f.bottom=UI.Solid(f,"OVERLAY",1,1,1)
    f.left=UI.Solid(f,"OVERLAY",1,1,1);f.right=UI.Solid(f,"OVERLAY",1,1,1)
    f.top:SetPoint("TOPLEFT");f.top:SetPoint("TOPRIGHT")
    f.bottom:SetPoint("BOTTOMLEFT");f.bottom:SetPoint("BOTTOMRIGHT")
    function f:Apply(style)
        self:SetShown(style~=nil)
        if not style then return end
        self.top:SetHeight(style.size);self.bottom:SetHeight(style.size)
        self.top:SetColorTexture(unpack(style.top));self.bottom:SetColorTexture(unpack(style.bottom))
        for _,side in ipairs({"left","right"}) do
            local t=self[side];local anchor=side=="left" and "LEFT" or "RIGHT"
            t:SetWidth(style.size);t:SetPoint("TOP"..anchor,0,-style.size);t:SetPoint("BOTTOM"..anchor,0,style.size)
            t:SetColorTexture(unpack(style.side))
        end
    end
    f:Hide();return f
end

local labels = {"XP remaining", "XP/hour", "Time to level", "Rested XP", "Kill XP", "Quest XP", "Dungeon XP", "Other XP"}
local pvpLabels={"Honor available","PvP rank","Rank Points left","Current rank cap"}
-- Retain functional stat explanations and Blizzard tooltip styling.
local tooltipLabels = {"XP remaining", "XP/hour", "Time to level", "Rested XP", "Outdoor kills", "Outdoor quests", "Dungeons", "Other"}
local explanations = {
    "XP needed / total required for this level.",
    "XP/hour over up to one hour. Weighted towards recent kill XP.",
    "Based on your current XP/hour.",
    "Available rested XP, including XP beyond this level.",
    "Confirmed kill XP outside instances, including rested bonuses.",
    "Confirmed quest XP received outside instances, including dungeon quests turned in outdoors.",
    "All XP gained inside party dungeons, counted once.",
    "Outdoor exploration, raids, other instances and unconfirmed XP sources.",
}

-- A single cancellable timer belongs to the current stat target. The generation
-- also rejects callbacks already dispatched before a leave or same-cell re-entry.
function UI:CancelStatTooltip(cell)
    if cell and self.tooltipCell~=cell then return end
    if not cell and self.barTooltip then
        self.barTooltip=nil
        if GameTooltip:GetOwner()==self.frame then GameTooltip:Hide() end
    end
    local previous=self.tooltipCell
    self.tooltipGeneration=(self.tooltipGeneration or 0)+1
    if self.tooltipTimer then self.tooltipTimer:Cancel();self.tooltipTimer=nil end
    self.tooltipCell,self.tooltipIndex=nil,nil
    if previous and GameTooltip:GetOwner()==previous then GameTooltip:Hide() end
end

function UI:BeginStatTooltip(cell,index)
    self:CancelStatTooltip()
    GameTooltip:Hide()
    if not self.expanded or self.progress~=1 or not cell:IsVisible() or self.dragging then return end
    self.tooltipCell,self.tooltipIndex=cell,index
    local generation=self.tooltipGeneration
    self.tooltipTimer=C_Timer.NewTimer(.75,function()
        if self.tooltipGeneration~=generation or self.tooltipCell~=cell then return end
        self.tooltipTimer=nil
        if not self.expanded or self.progress~=1 or self.dragging
            or not self.frame:IsVisible() or not cell:IsVisible() or not cell:IsMouseOver() then
            self:CancelStatTooltip(cell)
            return
        end
        self:ShowStatTooltip(cell,index)
    end)
end

function UI:ShowStatTooltip(cell,i)
    local owner=self.owner
    GameTooltip:SetOwner(cell, "ANCHOR_BOTTOM")
    if i>=9 then
        if i==9 then
            GameTooltip:AddLine("Pet XP",1,1,1)
            local pet=P.pet
            if pet then GameTooltip:AddLine((pet.name or "Pet").." · Level "..pet.level.." · "..M.ExactXP(pet.xp,pet.cap),.8,.65,1,true) end
        elseif i==10 then
            GameTooltip:AddLine("PvP rank",1,1,1)
            GameTooltip:AddLine("Rank Points / next rank requirement. Honor is a separate currency.",.75,.77,.82,true)
            self:AddPvPTooltip()
        else
            GameTooltip:AddLine("Kills to level",1,1,1)
            self:AddKillTooltip()
        end
        GameTooltip:Show();return
    elseif owner:Mode()=="pvp" then
        GameTooltip:AddLine(pvpLabels[i] or "PvP progression",1,1,1)
        GameTooltip:AddLine(i==1 and "Spendable Honor balance. Spending Honor does not lower rank."
            or i==4 and "Season Rank Points / current cumulative cap."
            or "Rank Points determine PvP rank. Honor is a separate currency.",.75,.77,.82,true)
        self:AddPvPTooltip();GameTooltip:Show();return
    end
    GameTooltip:AddLine(tooltipLabels[i], 1,1,1)
    if i~=3 then GameTooltip:AddLine(explanations[i], .75,.77,.82, true) end
    local s = owner.session
    if i >= 5 and s then
        local key = SOURCE_KEYS[i-4]
        local amount = s.buckets[key]
        GameTooltip:AddLine(string.format("%d XP · %.1f%% of session", amount, s.total > 0 and amount*100/s.total or 0), .8,.65,1)
    elseif i == 2 and s then
        GameTooltip:AddLine(string.format("Session: %s XP · %s elapsed",BreakUpLargeNumbers(s.total),M.Duration(s.seconds)),.8,.65,1)
    elseif i == 4 and owner.tracker and not owner.tracker.pending and not owner.levelPending
        and not owner.transition and owner:IsCapped()==false then
        local text,maximum=M.RestedText(owner.rested,owner.restedMaximum)
        if text then
            if maximum then GameTooltip:AddLine(text,1,.1,.1)
            else GameTooltip:AddLine(text,unpack(self:ColorValue("rested"))) end
        end
    elseif i == 3 and owner.tracker then
        local t=owner.tracker
        local rate,duration=M.Estimate(s,t.xp,t.cap,owner:IsCapped()~=false)
        local state=M.ETAState(s,rate,duration)
        GameTooltip:AddLine(state=="ready" and explanations[i] or M.ETAMessages[state],.75,.77,.82,true)
        if duration then
            GameTooltip:AddLine(M.Duration(duration,true).." at your current rate",.8,.65,1)
            GameTooltip:AddLine(string.format("%s XP/hour · %d XP remaining",M.Compact(rate),math.max(0,t.cap-t.xp)),.75,.77,.82,true)

        end
    elseif i == 1 and owner.tracker and owner.tracker.cap then
        GameTooltip:AddLine(string.format("%d / %d XP remaining", math.max(0,owner.tracker.cap-owner.tracker.xp), owner.tracker.cap), .8,.65,1)
    end
    if i>=5 and s and s.partial then GameTooltip:AddLine("Totals include recorded XP only.",.75,.77,.82,true) end
    GameTooltip:Show()
end

function UI:ShowBarTooltip()
    local owner,f=self.owner,self.frame
    local t=owner.tracker
    if owner:Mode()=="pvp" then
        GameTooltip:SetOwner(f,"ANCHOR_BOTTOM");GameTooltip:AddLine("Honor & PvP · rank progression",1,1,1)
        self:AddPvPTooltip();GameTooltip:Show();self.barTooltip=true;return
    end
    if not t or not t.cap or t.cap<=0 then return end
    GameTooltip:SetOwner(f,"ANCHOR_BOTTOM")
    if owner.profile.format=="eta" then
        local rate,duration=M.Estimate(owner.session,t.xp,t.cap,owner:IsCapped()~=false)
        local state=M.ETAState(owner.session,rate,duration)
        GameTooltip:AddLine(state=="ready" and M.Duration(duration,true).." at your current rate" or M.ETAMessages[state],1,1,1,true)
    elseif owner.profile.format=="kills" then
        self:AddKillTooltip()
    end
    GameTooltip:AddLine(M.ExactXP(t.xp,t.cap),1,1,1)
    if not owner.profile.expandedOnce then
        GameTooltip:AddLine("Click to expand · /xpisland for settings",.8,.8,.85)
    end
    GameTooltip:Show();self.barTooltip=true
end

-- Repaint only an already visible, owned hover. Events and the shared clock
-- reach this path; pending dwell timers never acquire the tooltip early.
function UI:RefreshTooltip()
    local cell=self.tooltipCell
    if cell then
        if not self.expanded or self.progress~=1 or self.dragging or not cell:IsVisible() or not cell:IsMouseOver() then
            self:CancelStatTooltip(cell)
        elseif not self.tooltipTimer and self.tooltipIndex and GameTooltip:IsShown() and GameTooltip:GetOwner()==cell then
            self:ShowStatTooltip(cell,self.tooltipIndex)
        end
    elseif self.barTooltip and GameTooltip:IsShown() and GameTooltip:GetOwner()==self.frame then
        if not self.dragging and self.frame:IsVisible() and (self.frame:IsMouseOver() or self.indicator:IsMouseOver()) then
            self:ShowBarTooltip()
        else
            self.barTooltip=nil;GameTooltip:Hide()
        end
    end
end

function UI:AddKillTooltip()
    local o,t=self.owner,self.owner.tracker
    local kills,state,count,mean=M.KillsToLevel(o.session,t and t.xp,t and t.cap,o:IsCapped()~=false)
    GameTooltip:AddLine(M.KillMessages[state],.75,.77,.82,true)
    if kills then GameTooltip:AddLine("About "..M.Compact(kills).." kills · "..M.Compact(mean).." XP/kill",.8,.65,1,true) end
    if count and count>0 then GameTooltip:AddLine(M.Compact(count).." recent confirmed kills",.75,.77,.82,true) end
end

function UI:AddPvPTooltip()
    local r=P.rank
    GameTooltip:AddLine("Honor available: "..M.Compact(P.honor),.8,.65,1)
    if not r then GameTooltip:AddLine("PvP rank unavailable.",.75,.77,.82,true);return end
    GameTooltip:AddLine((r.level==0 and "Unranked" or "Rank "..r.level).." · "..P:RankText(),.8,.65,1,true)
    if r.maximum then GameTooltip:AddLine("Maximum seasonal rank reached.",.75,.77,.82,true)
    elseif r.weekCapped then GameTooltip:AddLine("Current rank cap reached.",.75,.77,.82,true) end
    if r.ceiling then GameTooltip:AddLine("Season Rank Points: "..M.Compact(r.total).." / "..M.Compact(r.ceiling).." current cap",.75,.77,.82,true) end
end

-- All footer labels and values share one small font size. Measure only when
-- text/font changes, then center the complete group rather than three cards.
function UI:RefreshInline()
    local o,p=self.owner,self.owner.profile
    local xp=o:Mode()=="xp"
    local t=o.tracker
    local kills=M.KillsToLevel(o.session,t and t.xp,t and t.cap,o:IsCapped()~=false)
    local values={P.pet and M.Compact(P.pet.xp) or "—",P:RankText(),M.Compact(kills)}
    local visible={p.showPet and P.pet~=nil,p.showRank and xp,p.showKills and xp}
    local size=math.max(12,math.min(14,p.fontSize-2))
    local font=UI.Font()
    local signature=font..":"..size..":"..o:Mode()..":"..self.frame:GetEffectiveScale()
    for i=1,3 do signature=signature..":"..tostring(visible[i])..":"..values[i] end
    if self.inlineSignature==signature then return false end
    self.inlineSignature=signature
    self.inlineWidth,self.inlineHeight,self.inlineCount=0,0,0
    for i,c in ipairs(self.inlineCells) do
        c.active=visible[i];c:SetShown(c.active)
        UI.ApplyFont(c.title,size);UI.ApplyFont(c.value,size);c.value:SetText(values[i])
        local titleWidth,titleHeight=UI.Measure(c.title)
        local valueWidth,valueHeight=UI.Measure(c.value)
        c.titleWidth=titleWidth
        c.pairWidth=titleWidth+4+valueWidth
        c.pairHeight=math.max(titleHeight,valueHeight)
        if c.active then
            self.inlineCount=self.inlineCount+1
            self.inlineWidth=self.inlineWidth+c.pairWidth+(self.inlineCount>1 and 18 or 0)
            self.inlineHeight=math.max(self.inlineHeight,c.pairHeight)
        end
    end
    self.cellsInteractive=nil
    return true
end

-- A drag belongs to the settings revision at pointer-down. Profile switches,
-- copies, resets and other settings edits cancel it before a delayed stop event.
function UI:CancelDrag()
    if not self.dragging then return end
    self.dragging=nil;self.dragRevision=nil
    self.frame:StopMovingOrSizing()
end

function UI:Create(owner)
    self.constructing=true
    self.owner = owner
    local f = CreateFrame("Button", "XPIslandFrame", UIParent)
    self.frame = f
    self.progress=0
    self.animateStep=function(_,elapsed) self:Animate(elapsed) end
    -- Above ordinary action bars and panels, below DIALOG menus/system prompts
    -- and TOOLTIP. Children inherit the same strata and relative frame levels.
    f:SetFrameStrata("HIGH"); f:SetFrameLevel(100); f:SetClampedToScreen(true)
    f:SetMovable(true); f:RegisterForDrag("LeftButton")
    self.outer = UI.Round(f, "border", 0)
    self.inner = UI.Round(f, "surface", 1)
    self.chromeFrames={}
    for _,theme in ipairs(ns.Themes.definitions) do
        if theme.chromeTexture then self.chromeFrames[theme.id]=UI.Chrome(f,theme.chromeTexture,theme.chromeRadius) end
    end
    local content = CreateFrame("Frame", nil, f)
    self.content = content; content:SetAllPoints(); content:SetFrameLevel(f:GetFrameLevel()+2)
    self.header=CreateFrame("Frame",nil,content)
    self.flashDriver=CreateFrame("Frame",nil,self.header)
    self.flashStep=function(_,elapsed) self:AnimateHighlights(elapsed) end
    self.flashes={}
    self.restedColor={}
    self.bar=CreateFrame("Frame",nil,self.header);self.bar:SetAllPoints()
    self.levelText=UI.Text(self.header,14)
    self.levelText:SetPoint("CENTER",self.header,"CENTER");self.levelText:Hide()
    self.label = UI.Text(self.bar, 14)
    self.label:SetJustifyH("CENTER")
    self.infinity,self.infinitySupported=UI.Infinity(self.bar)
    self.infinity:Hide()
    self.indicator=CreateFrame("Button",nil,self.bar)
    self.indicator:RegisterForClicks("LeftButtonUp","RightButtonUp")
    self.indicator:RegisterForDrag("LeftButton")
    self.bar:SetScript("OnHide",function() ns.Options:CloseIndicatorMenu() end)
    self.segments = {}
    for i=1,20 do
        local edge=i==1 and "left" or i==20 and "right" or nil
        local track = UI.BarPiece(self.bar, "ARTWORK", edge)
        local preview=UI.BarPiece(self.bar,"ARTWORK",edge)
        preview:SetFrameLevel(track:GetFrameLevel()+1);preview:SetPoint("LEFT",track,"LEFT")
        local fill = UI.BarPiece(self.bar, "OVERLAY", edge)
        fill:SetFrameLevel(track:GetFrameLevel()+2);fill:SetPoint("LEFT",track,"LEFT")
        local flash=UI.BarPiece(self.bar,"OVERLAY",edge)
        flash:SetFrameLevel(track:GetFrameLevel()+3);flash:SetPoint("LEFT",track,"LEFT");flash:Hide()
        local border=UI.SegmentBorder(self.bar,track,flash:GetFrameLevel()+1)
        self.segments[i] = {track=track,preview=preview,fill=fill,flash=flash,border=border}
    end
    self.divider = UI.Solid(content, "ARTWORK", 1,1,1)
    self.details=CreateFrame("Frame",nil,content)
    self.details:SetClipsChildren(true)
    self.cells = {}
    for i=1,8 do
        local cell = CreateFrame("Frame", nil, self.details)
        cell:EnableMouse(true)
        cell.title = UI.Text(cell, 12, "accent")
        cell.value = UI.Text(cell, 14)
        cell.title:SetPoint("TOP"); cell.value:SetPoint("TOP",0,-18);cell.value:SetText("0")
        cell.title:SetJustifyH("CENTER");cell.value:SetJustifyH("CENTER")
        cell.title:SetText(labels[i])
        if i>=5 then
            cell.shareTrack=UI.Solid(cell,"ARTWORK",unpack(TRACK_COLOR))
            cell.shareTrack:SetPoint("TOP",cell.value,"BOTTOM",0,-3)
            cell.shareFill=UI.Solid(cell,"OVERLAY",.46,.41,.58)
            cell.shareFill:SetPoint("LEFT",cell.shareTrack,"LEFT");cell.shareFill:Hide()
        end
        cell:SetScript("OnEnter", function()
            owner:InteractionChanged()
            self:BeginStatTooltip(cell,i)
        end)
        cell:SetScript("OnLeave", function() self:CancelStatTooltip(cell);owner:InteractionChanged() end)
        cell:SetScript("OnHide", function() self:CancelStatTooltip(cell) end)
        cell:SetScript("OnMouseUp", function(_,button) if button=="LeftButton" then owner:Toggle() end end)
        self.cells[i] = cell
    end
    self.inlineGroup=CreateFrame("Frame",nil,self.details)
    self.inlineCells={}
    for i,title in ipairs({"Pet XP:","PvP rank:","Kills to level:"}) do
        local c=CreateFrame("Frame",nil,self.inlineGroup)
        c.title=UI.Text(c,12,"accent");c.title:SetText(title)
        c.value=UI.Text(c,12)
        c.title:SetJustifyH("LEFT");c.value:SetJustifyH("LEFT")
        c:SetScript("OnEnter",function() owner:InteractionChanged();self:BeginStatTooltip(c,i+8) end)
        c:SetScript("OnLeave",function() self:CancelStatTooltip(c);owner:InteractionChanged() end)
        c:SetScript("OnHide",function() self:CancelStatTooltip(c) end)
        c:SetScript("OnMouseUp",function(_,button) if button=="LeftButton" then owner:Toggle() end end)
        self.inlineCells[i]=c
    end
    f:SetScript("OnClick", function()
        if self.dragged then self.dragged = nil; return end
        owner:Toggle()
    end)
    f:SetScript("OnDragStart", function()
        if owner.profile.locked then return end
        ns.Options:CloseIndicatorMenu()
        self:CancelStatTooltip();self:ClearHighlights()
        self.dragged = true; self.dragging = true;self.dragRevision=owner.settingsRevision
        owner:InteractionChanged(); self:StopAnimation(); self:RenderGeometry(self.expanded and 1 or 0); f:StartMoving()
    end)
    f:SetScript("OnDragStop", function()
        if not self.dragging then return end
        local revision=self.dragRevision
        self.dragging = nil;self.dragRevision=nil; f:StopMovingOrSizing()
        local factor = f:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local x = select(1,f:GetCenter()) * factor - UIParent:GetWidth()/2
        local y = self.header:GetTop()*factor - UIParent:GetTop()
        local ok,err=ns.App:SetMany({["position.x"]=math.max(-10000,math.min(10000,x)),["position.y"]=math.max(-10000,math.min(10000,y)),placement="custom"},revision)
        if not ok then owner:SettingsResult(ok,err);self:Layout() end
        owner:InteractionChanged()
    end)
    f:SetScript("OnEnter", function()
        self:CancelStatTooltip()
        owner:InteractionChanged()
        if not self.dragging then self:ShowBarTooltip() end
    end)
    f:SetScript("OnLeave", function()
        self.barTooltip=nil
        if GameTooltip:GetOwner()==f then GameTooltip:Hide() end
        owner:InteractionChanged()
    end)
    f:SetScript("OnHide",function()
        ns.Options:CloseIndicatorMenu()
        self:CancelStatTooltip();self:ClearHighlights()
        owner.levelWindow=nil
        owner:ClearLevelNotice()
        self:StopAnimation();owner:CancelAutoCollapse()
        self.expanded=false
        if self.layout then self:RenderGeometry(0) end
    end)
    -- Only this measured right-hand slot accepts a context click. Preserve the
    -- island's existing left click, drag and tooltip behavior over the label.
    self.indicator:SetScript("OnClick",function(_,button)
        if button=="RightButton" then ns.Options:OpenIndicatorMenu(self.indicator)
        elseif button=="LeftButton" then f:GetScript("OnClick")(f,button) end
    end)
    for _,event in ipairs({"OnDragStart","OnDragStop","OnEnter","OnLeave"}) do
        self.indicator:SetScript(event,f:GetScript(event))
    end
    self.constructing=nil;self:Layout(); f:Hide()
end

function UI:BarLabel(rate,duration)
    local p,t=self.owner.profile,self.owner.tracker
    local text="—"
    local infinity=false
    if self.owner:Mode()=="pvp" then
        text=P:Label(p.pvpFormat)
    elseif p.format=="kills" then
        local kills=M.KillsToLevel(self.owner.session,t and t.xp,t and t.cap,self.owner:IsCapped()~=false)
        text=M.Compact(kills).." kills"
    elseif t and t.cap then
        if p.format=="eta" then
            local state=M.ETAState(self.owner.session,rate,duration)
            infinity=state=="empty" or state=="idle"
            text=infinity and (self.infinitySupported and "" or "n/a") or M.Duration(duration)
        else text=M.Label(p.format,t.xp,t.cap) end
    end
    if self.showInfinity~=(infinity and self.infinitySupported) then
        self.showInfinity=infinity and self.infinitySupported
        self.infinity:SetShown(self.showInfinity)
    end
    if text==self.labelSource and p.fontSize==self.labelSize and self.font==self.labelFont and self.frame:GetEffectiveScale()==self.labelScale then
        return self.label:GetText(),self.labelWidth
    end
    self.labelSource,self.labelSize,self.labelFont=text,p.fontSize,self.font
    self.labelScale=self.frame:GetEffectiveScale()
    self.label:SetText(text)
    local width=UI.Measure(self.label)
    if width>200 then
        text=text:gsub(" XP","");self.label:SetText(text)
        width=UI.Measure(self.label)
    end
    self.labelWidth=math.max(46,width,self.infinityWidth or 0)
    return text,self.labelWidth
end

function UI:Layout(preserveMotion)
    if not self.frame or self.dragging then return end
    self.owner:RefreshAppearance(preserveMotion)
end

function UI:ApplyTheme()
    local theme=ns.Themes.Get(self.owner.profile.theme)
    if self.appliedTheme==theme.id then return end
    self.appliedTheme=theme.id
    self.trackColor=theme.trackColor
    self.outer:SetShown(not theme.chromeTexture);self.inner:SetShown(not theme.chromeTexture)
    for id,chrome in pairs(self.chromeFrames) do chrome:SetShown(id==theme.id) end
    self.chrome=self.chromeFrames[theme.id]
    if not theme.chromeTexture then
        self.outer:Radius(theme.outerRadius);self.inner:Radius(theme.innerRadius)
    end
    self.headerInset=theme.headerInset
    self.labelGap=theme.labelGap
    self.segmentHeight=theme.segmentHeight
    self.segmentGap=theme.segmentGap
    self.divider:SetColorTexture(unpack(theme.dividerColor))
    for _,cell in ipairs(self.cells) do
        if cell.shareTrack then cell.shareTrack:SetColorTexture(unpack(self.trackColor)) end
    end
    for _,segment in ipairs(self.segments) do
        segment.track:SetAlpha(theme.trackAlpha)
        segment.border:Apply(theme.segmentBorder)
        for _,part in ipairs({segment.track,segment.preview,segment.fill,segment.flash}) do
            part.drawWidth=nil
            if part.cap then part.cap:SetTexture(theme.capTexture) end
        end
        segment.fill.shaded=theme.shadingAlpha>0
        segment.fill.shadingVisible=nil;segment.fill.capShadingVisible=nil
        segment.fill.shading:SetTexture(theme.shadingTexture)
        segment.fill.shading:SetShown(theme.shadingAlpha>0)
        segment.fill.shading:SetAlpha(theme.shadingAlpha)
        if segment.fill.capShading then
            segment.fill.capShading:SetTexture(theme.capShadingTexture)
            segment.fill.capShading:SetShown(theme.shadingAlpha>0)
            segment.fill.capShading:SetAlpha(theme.shadingAlpha)
        end
    end
end

function UI:LayoutContents(preserveMotion)
    if not self.frame or self.dragging then return end
    if not preserveMotion then self:CancelStatTooltip();self:ClearHighlights() end
    local p,f=self.owner.profile,self.frame
    self.font=UI.Font()
    -- Install the parent scale before measuring; stale 100% metrics must not
    -- size the 85% boxes. Reset only the optional footer's content-fit scale.
    local _,_,scale=M.Layout(UIParent:GetWidth(),p.scale)
    UI.ApplyFont(self.label,p.fontSize)
    UI.ApplyFont(self.levelText,p.fontSize)
    self.levelTextSource=nil
    if self.infinity.Layout then self.infinity:Layout(p.fontSize) end
    self.infinityWidth=p.fontSize*1.4+4
    local titleHeight,valueHeight,cellHeight,rowsHeight,labelWidth,layout
    local xp=self.owner:Mode()=="xp"
    local tracker=self.owner.tracker
    local rate,duration=M.Estimate(self.owner.session,tracker and tracker.xp,tracker and tracker.cap,self.owner:IsCapped()~=false)
    -- A short viewport can also lower scale. Resolve that feedback here before
    -- Update, not by recursively restarting layout at the old requested scale.
    local placementProfile=setmetatable({},{__index=p})
    for pass=1,8 do
        f:SetScale(scale);self.inlineGroup:SetScale(1)
        self.labelSource=nil
        titleHeight,valueHeight=0,0
        for _,c in ipairs(self.cells) do
            c.fitKey=nil
            c.title:SetScale(1);c.value:SetScale(1)
            UI.ApplyFont(c.title,math.max(12,math.min(14,p.fontSize-2)))
            UI.ApplyFont(c.value,p.fontSize)
            local _,th=UI.Measure(c.title);local _,vh=UI.Measure(c.value)
            titleHeight=math.max(titleHeight,th)
            valueHeight=math.max(valueHeight,vh)
        end
        cellHeight=math.max(36,titleHeight+3+valueHeight)
        self.inlineSignature=nil;self:RefreshInline()
        rowsHeight=xp and cellHeight*2+6+5 or cellHeight
        local footerHeight=self.inlineCount>0 and 10+self.inlineHeight or 0
        _,labelWidth=self:BarLabel(rate,duration)
        placementProfile.scale=scale
        layout=M.Placement(UIParent:GetWidth(),UIParent:GetHeight(),placementProfile,labelWidth+180,24+rowsHeight+footerHeight)
        if layout.scale>=scale-.000001 then break end
        -- One percent of headroom absorbs the next physical-pixel rounding
        -- boundary; it applies only when the viewport already forces a fit.
        scale=math.max(.01,layout.scale*.99)
    end
    layout.inlineY=rowsHeight+10
    layout.labelWidth=labelWidth;layout.font=self.font;layout.cellHeight=cellHeight
    self.layout=layout
    if not preserveMotion then self:StopAnimation();self.progress=self.expanded and 1 or 0 end
    f:SetScale(layout.scale);f:ClearAllPoints()
    self:ApplyTheme()
    self.label:ClearAllPoints();self.label:SetPoint("RIGHT",self.header,"RIGHT",-self.headerInset,0)
    self.label:SetSize(labelWidth,layout.barHeight)
    self.indicator:ClearAllPoints();self.indicator:SetPoint("RIGHT",self.header,"RIGHT",-self.headerInset,0)
    self.indicator:SetSize(labelWidth,layout.barHeight)
    -- Empty FontStrings need not provide drawable bounds. Keep the symbol in
    -- the numeric slot without anchoring it to the label we clear for infinity.
    self.infinity:ClearAllPoints();self.infinity:SetPoint("CENTER",self.header,"RIGHT",-self.headerInset-labelWidth/2,0)
    self.header:ClearAllPoints()
    local point=layout.up and "BOTTOM" or "TOP"
    self.header:SetPoint(point,self.content,point)
    self.header:SetHeight(layout.barHeight)
    self.details:ClearAllPoints();self.details:SetPoint("TOPLEFT",0,layout.up and -12 or -(layout.barHeight+12))
    self.divider:ClearAllPoints()
    self.divider:SetPoint(layout.up and "BOTTOMLEFT" or "TOPLEFT",14,layout.up and layout.barHeight+1 or -layout.barHeight)
    self.divider:SetHeight(1)
    for i,c in ipairs(self.cells) do
        c:SetShown(xp or i<=4)
        c.title:SetHeight(titleHeight);c.value:SetHeight(valueHeight)
        -- Center the measured block within its row. Both outer drawer margins
        -- stay 12px; larger fonts get more height rather than a clipped last row.
        local inset=(cellHeight-titleHeight-3-valueHeight)/2
        c.titleInset,c.valueInset=inset,inset+titleHeight+3
        c.title:SetPoint("TOP",0,-inset);c.value:SetPoint("TOP",0,-inset-titleHeight-3)
        c:SetHeight(cellHeight+(i>=5 and 5 or 0))
    end
    local inlineScale=math.min(1,(layout.expanded-40)/math.max(1,self.inlineWidth))
    self.inlineGroup:SetScale(inlineScale)
    self.inlineGroup:SetSize(math.max(1,self.inlineWidth),self.inlineHeight)
    self.inlineGroup:ClearAllPoints();self.inlineGroup:SetPoint("TOP",self.details,"TOP",0,-layout.inlineY/inlineScale)
    local inlineX=0
    for _,c in ipairs(self.inlineCells) do
        if c.active then
            c:SetPoint("TOPLEFT",inlineX,0);c:SetSize(c.pairWidth,c.pairHeight)
            c.title:SetPoint("LEFT",0,0);c.title:SetSize(c.titleWidth,c.pairHeight);c.title:SetJustifyH("CENTER")
            c.value:SetPoint("LEFT",c.titleWidth+4,0);c.value:SetSize(c.pairWidth-c.titleWidth-4,c.pairHeight);c.value:SetJustifyH("CENTER")
            inlineX=inlineX+c.pairWidth+18
        end
    end
    self.geometryWidth=nil -- invalidate dimensions only when layout changes
    self:RenderGeometry(self.progress)
    self:Update()
end

-- Only changing geometry/opacity reaches the client on each animation frame.
-- Fonts, colors, measurements, rates, textures and static anchors live outside it.
function UI:RenderGeometry(progress)
    local layout,f=self.layout,self.frame
    self.progress=progress
    local width=layout.collapsed+(layout.expanded-layout.collapsed)*progress
    local height=layout.barHeight+(layout.panelHeight-layout.barHeight)*progress
    if width~=self.geometryWidth or height~=self.geometryHeight then
        self.geometryWidth,self.geometryHeight=width,height
        f:SetSize(width,height)
        local y=layout.y+(layout.up and (height-layout.barHeight)*layout.scale or 0)
        -- SetPoint replaces this same anchor; avoid clearing the entire graph.
        f:SetPoint("TOP",UIParent,"TOP",layout.x/layout.scale,y/layout.scale)
        self.header:SetWidth(width)
        local inset=self.headerInset or 14
        local gap=self.labelGap
        local segmentGap=self.segmentGap
        local segWidth=(width-2*inset-gap-layout.labelWidth-19*segmentGap)/20
        for i,s in ipairs(self.segments) do
            s.track:SetPoint("LEFT",self.header,"LEFT",inset+(i-1)*(segWidth+segmentGap),0)
            s.track:Draw(segWidth,self.segmentHeight,1,self.trackColor or TRACK_COLOR);s.width=segWidth
        end
        self:PaintBar(true)
        self.divider:SetWidth(width-28)
        self.details:SetSize(width,math.max(0,height-layout.barHeight-24))
        local cellWidth=(width-76)/4
        for i,c in ipairs(self.cells) do
            c:SetPoint("TOPLEFT",20+(i-1)%4*(cellWidth+12),-math.floor((i-1)/4)*(layout.cellHeight+6))
            c:SetWidth(cellWidth);c.title:SetWidth(cellWidth/(c.titleScale or 1));c.value:SetWidth(cellWidth/(c.valueScale or 1))
            if c.shareTrack then
                c.shareWidth=math.min(64,cellWidth*.65)
                c.shareTrack:SetSize(c.shareWidth,2)
                c.shareFill:SetSize(math.max(.001,c.shareWidth*(c.shareFraction or 0)),2)
            end
        end
    end
    local opacity=math.max(0,math.min(1,(progress-.35)/.65))
    opacity=opacity*opacity*(3-2*opacity)
    if opacity~=self.detailOpacity then
        self.detailOpacity=opacity;self.divider:SetAlpha(opacity);self.details:SetAlpha(opacity)
    end
    if self.detailsVisible~=(progress>0) then
        self.detailsVisible=progress>0;self.divider:SetShown(self.detailsVisible);self.details:SetShown(self.detailsVisible)
    end
    local interactive=progress==1 and self.expanded or false
    if self.cellsInteractive~=interactive then
        self.cellsInteractive=interactive
        for _,c in ipairs(self.cells) do c:EnableMouse(interactive and c:IsShown()) end
        for _,c in ipairs(self.inlineCells) do c:EnableMouse(interactive and c.active) end
    end
end

function UI:StopAnimation()
    self.animation=nil
    if self.frame then self.frame:SetScript("OnUpdate",nil) end
end

function UI:Animate(elapsed)
    local a=self.animation
    if not a then return end
    a.elapsed=math.min(a.duration,a.elapsed+elapsed)
    local t=a.elapsed/a.duration
    -- A short, normalized critically damped spring: no overshoot outside the
    -- clamped viewport, and a continuous position when interrupted/reversed.
    local eased=(1-(1+7*t)*math.exp(-7*t))/(1-8*math.exp(-7))
    self:RenderGeometry(t>=1 and a.to or a.from+(a.to-a.from)*eased)
    if t>=1 then self:StopAnimation() end
end

function UI:SetExpanded(expanded, instant)
    self:CancelStatTooltip()
    expanded=not not expanded
    if not expanded then self.owner.levelWindow=nil;self.owner:ClearLevelNotice() end
    GameTooltip:Hide()
    if self.expanded==expanded and self.animation and not instant then return end
    self.expanded=expanded
    self:Update()
    if instant or not self.layout or not self.frame:IsShown() then self:Layout();return end
    self:StopAnimation()
    local target=expanded and 1 or 0
    if self.progress==target then self:RenderGeometry(target);return end
    self.animation={from=self.progress,to=target,elapsed=0,duration=math.max(.08,.22*math.abs(target-self.progress))}
    self:RenderGeometry(self.progress)
    self.frame:SetScript("OnUpdate",self.animateStep)
end

function UI:ClearHighlights()
    for i in pairs(self.flashes or {}) do
        self.segments[i].flash:Hide();self.flashes[i]=nil
    end
    if self.flashDriver then self.flashDriver:SetScript("OnUpdate",nil) end
end

function UI:HighlightSegments(before,after,cap)
    if self.owner:Mode()~="xp" then return end
    if self.owner.levelNotice or not self.frame:IsVisible() or self.dragging or cap<=0 or after<=before then return end
    local first=math.floor(before*20/cap)+1
    local last=math.min(20,math.floor(after*20/cap))
    if last<first then return end
    for i=first,last do
        local s=self.segments[i]
        self.flashes[i]=0;s.flash:Draw(s.width,self.segmentHeight,1,FLASH_COLOR)
        s.flash:SetAlpha(.18);s.flash:Show()
    end
    self.flashDriver:SetScript("OnUpdate",self.flashStep)
end

function UI:AnimateHighlights(elapsed)
    for i,age in pairs(self.flashes) do
        age=age+elapsed
        if age>=.25 then self.segments[i].flash:Hide();self.flashes[i]=nil
        else self.flashes[i]=age;self.segments[i].flash:SetAlpha(.18*(1-age/.25)^2) end
    end
    if not next(self.flashes) then self.flashDriver:SetScript("OnUpdate",nil) end
end

function UI:PaintBar(geometryChanged)
    local o,p=self.owner,self.owner.profile
    local notice=o.levelNotice
    if notice~=self.headerNotice then
        self.headerNotice=notice
        self.headerNoticeText=notice and ("Last level took "..M.Duration(notice.seconds)) or nil
    end
    local text=self.headerNoticeText
    if text~=self.levelTextSource then
        self.levelTextSource=text
        self.levelText:SetText(text or "")
        self.levelText:SetScale(1)
        local width,height=UI.Measure(self.levelText)
        self.levelTextWidth=width
        self.levelText:SetSize(width,height)
    end
    self.levelText:SetShown(notice~=nil);self.bar:SetShown(notice==nil)
    if notice then
        self.levelText:SetScale(math.min(1,(self.header:GetWidth()-28)/math.max(1,self.levelTextWidth)))
        self:ClearHighlights()
    end
    local t=o.tracker
    local rank=o:Mode()=="pvp" and P.rank
    local cap,xp=t and t.cap or 0,t and t.xp or 0
    if o:Mode()=="pvp" then cap=rank and rank.cap or 0;xp=rank and rank.xp or 0 end
    local fraction=rank and rank.maximum and 1 or cap>0 and math.min(1,math.max(0,xp/cap)) or 0
    local color=(o.rested or 0)>0 and self:ColorValue("rested") or self:ColorValue("normal")
    local preview=cap>0 and math.min(1,(xp+math.max(0,o.rested or 0))/cap) or 0
    if o:Mode()=="pvp" then preview=0;color=self:ColorValue("normal") end
    if preview<=fraction then preview=0 end
    local previewColor=self.restedColor
    local trackColor=self.trackColor or TRACK_COLOR
    for i=1,3 do previewColor[i]=trackColor[i]+(self:ColorValue("rested")[i]-trackColor[i])*.28 end
    if geometryChanged or fraction~=self.barFraction or preview~=self.restedFraction or previewColor[1]~=self.previewR
        or previewColor[2]~=self.previewG or previewColor[3]~=self.previewB then
        for i,s in ipairs(self.segments) do
            local amount=fraction*20>=i and 0 or math.min(1,math.max(0,preview*20-(i-1)))
            s.preview:Draw(s.width,self.segmentHeight,amount,previewColor)
        end
        self.restedFraction,self.previewR,self.previewG,self.previewB=preview,unpack(previewColor)
    end
    if geometryChanged then
        for i in pairs(self.flashes) do self.segments[i].flash:Draw(self.segments[i].width,self.segmentHeight,1,FLASH_COLOR) end
    end
    if geometryChanged or fraction~=self.barFraction or color[1]~=self.barR or color[2]~=self.barG or color[3]~=self.barB then
        for i,s in ipairs(self.segments) do
            local fill=math.min(1,math.max(0,fraction*20-(i-1)))
            s.fill:Draw(s.width,self.segmentHeight,fill,color)
        end
        self.barFraction,self.barR,self.barG,self.barB=fraction,color[1],color[2],color[3]
    end
end

function UI:Update()
    if not self.frame then return end
    local o, p = self.owner, self.owner.profile
    local t = o.tracker
    if self:RefreshInline() then self:Layout(true);return end
    if o:Mode()=="xp" and (not t or not t.cap) then return end
    local xp, cap, rested = t and t.xp or 0, t and t.cap or 0, o.rested or 0
    local rate,duration=M.Estimate(o.session,xp,cap,o:IsCapped()~=false)
    local text,labelWidth=self:BarLabel(rate,duration)
    if labelWidth~=self.layout.labelWidth or UI.Font()~=self.layout.font then self:Layout(true);return end
    self:PaintBar()
    local s=o.session
    local left=math.max(0,cap-xp)
    local values = {
        M.Compact(left).." / "..M.Compact(cap), rate and M.Compact(rate) or "—",
        M.Duration(duration), rested>0 and M.Compact(rested) or "—",
        M.Compact(s.buckets.kills), M.Compact(s.buckets.quests), M.Compact(s.buckets.dungeons), M.Compact(s.buckets.other),
    }
    local pvp=o:Mode()=="pvp"
    if pvp then
        local r=P.rank
        values[1]=M.Compact(P.honor)
        values[2]=r and (r.level==0 and "Unranked" or tostring(r.level)) or "—"
        values[3]=r and (r.maximum and "Maximum rank" or r.weekCapped and "Cap reached" or M.Compact(r.left)) or "—"
        values[4]=r and r.ceiling and M.Compact(r.total).." / "..M.Compact(r.ceiling) or "—"
    end
    for i,c in ipairs(self.cells) do
        local title=pvp and pvpLabels[i] or labels[i]
        if c.titleSource~=title then c.titleSource=title;c.title:SetText(title or "") end
        if i>=5 then
            local share=s.total>0 and s.buckets[SOURCE_KEYS[i-4]]/s.total or 0
            share=math.max(0,math.min(1,share))
            if c.shareFraction~=share then
                c.shareFraction=share;c.shareFill:SetWidth(math.max(.001,c.shareWidth*share));c.shareFill:SetShown(share>0)
            end
        end
        if c.sourceValue~=values[i] or c.measuredFont~=self.font or c.measuredSize~=p.fontSize or ((i==1 or pvp) and c.measuredWidth~=c:GetWidth()) then
            c.sourceValue,c.measuredFont,c.measuredSize,c.measuredWidth=values[i],self.font,p.fontSize,c:GetWidth()
            c.value:SetText(values[i])
            if i==1 and not pvp and c.value:GetUnboundedStringWidth()>c:GetWidth() then
                c.value:SetText(M.Compact(left,0).." / "..M.Compact(cap,0))
            end
        end
        local fitKey=tostring(pvp)..":"..tostring(title)..":"..values[i]..":"..self.font..":"..p.fontSize..":"..self.layout.expanded..":"..self.frame:GetEffectiveScale()
        if c.fitKey~=fitKey then
            c.fitKey=fitKey
            local width=(self.layout.expanded-76)/4
            c.title:SetScale(1);c.value:SetScale(1)
            c.title.xpNaturalWidth=UI.Measure(c.title);c.value.xpNaturalWidth=UI.Measure(c.value)
            c.titleScale=UI.FitText(c.title,width);c.valueScale=UI.FitText(c.value,width)
            c.title:SetWidth(c:GetWidth()/c.titleScale);c.value:SetWidth(c:GetWidth()/c.valueScale)
            -- Each role retains its row slot even when long content fits at a
            -- smaller scale. Otherwise the TOP offset shrinks with the value,
            -- pulling it upward into its title and disturbing row baselines.
            UI.AnchorText(c.title,"TOP",c,"TOP",0,-c.titleInset-c.title:GetHeight()*(1-c.titleScale)/2)
            UI.AnchorText(c.value,"TOP",c,"TOP",0,-c.valueInset-c.value:GetHeight()*(1-c.valueScale)/2)
        end
    end
    self.frame:SetShown(o:CanShow())
    self:RefreshTooltip()
end
