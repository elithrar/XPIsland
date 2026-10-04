local _, ns = ...
local M = ns.Model
local UI = {}
ns.UI = UI
local TRACK_COLOR={.14,.14,.18}
local MEDIA = "Interface\\AddOns\\XPIsland\\media\\rounded.tga"

function UI.Text(parent, size, r, g, b)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(UI.Font({font="Game tooltip"}), size, "")
    text:SetShadowColor(0,0,0,.8); text:SetShadowOffset(1,-1)
    text:SetTextColor(r or 0.93, g or 0.94, b or 0.97)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

function UI.Solid(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

function UI.Round(parent, color, inset)
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
        t:SetVertexColor(unpack(color)); t:SetPoint(s[1])
        corners[#corners+1] = t
    end
    local center = UI.Solid(holder, "BACKGROUND", unpack(color))
    local left = UI.Solid(holder, "BACKGROUND", unpack(color))
    local right = UI.Solid(holder, "BACKGROUND", unpack(color))
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

function UI.Font(profile)
    local tooltip = GameTooltipTextLeft2 or GameTooltipText
    local default = tooltip and tooltip:GetFont() or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    if profile.font == "Game tooltip" then return default end
    if profile.font == "Arial" then return "Fonts\\ARIALN.TTF" end
    if profile.font == "Friz Quadrata" then return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    return (lsm and lsm:IsValid("font", profile.font) and lsm:Fetch("font", profile.font)) or default
end

-- End caps use a fixed-radius circular texture, cropped (never compressed) at
-- the current XP boundary. Interior segments remain rectangular.
function UI.BarPiece(parent, layer, edge)
    local f=CreateFrame("Frame",nil,parent)
    f.edge=edge
    f.body=UI.Solid(f,layer,1,1,1)
    if edge then
        f.cap=f:CreateTexture(nil,layer)
        f.cap:SetTexture("Interface\\AddOns\\XPIsland\\media\\cap.tga")
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
        if self.cap then
            local offset=self.edge=="left" and 0 or width-radius
            local capWidth=math.max(0,math.min(radius,visible-offset))
            if self.capOffset~=offset then self.capOffset=offset;self.cap:SetPoint("LEFT",offset,0) end
            if self.capWidth~=capWidth or self.capRadius~=radius or self.capHeight~=height then
                self.capWidth,self.capRadius,self.capHeight=capWidth,radius,height
                self.cap:SetSize(math.max(.001,capWidth),height)
                local u=self.edge=="left" and 0 or .5
                self.cap:SetTexCoord(u,u+.5*capWidth/radius,0,1)
            end
            if self.capVisible~=(capWidth>0) then self.capVisible=capWidth>0;self.cap:SetShown(self.capVisible) end
        end
    end
    return f
end

local labels = {"XP Remaining", "XP/hour", "Time to Level", "Rested XP", "Kill XP", "Quest XP", "Dungeon XP", "Other XP"}
-- Retain functional stat explanations and Blizzard tooltip styling.
local tooltipLabels = {"XP remaining", "Session XP/hour", "Next level", "Rested XP", "Outdoor kills", "Outdoor quests", "Dungeons", "Other"}
local explanations = {
    "XP still needed / total required for this level.",
    "XP rate over up to the last hour, weighted towards recent kill XP.",
    "Estimated from your current XP/hour rate. Available after one minute with XP earned.",
    "Rested XP still available, including any amount extending into the next level.",
    "Confirmed kill XP earned outside instances, including rested bonuses.",
    "Confirmed quest rewards received outside instances. A dungeon quest turned in outdoors counts here.",
    "Every XP gain received inside a party dungeon. Includes kills, quests, exploration and bonuses, counted once.",
    "Exploration, raid/other-instance gains, and XP whose source could not be confirmed. Categories sum to session XP.",
}

-- A single cancellable timer belongs to the current stat target. The generation
-- also rejects callbacks already dispatched before a leave or same-cell re-entry.
function UI:CancelStatTooltip(cell)
    if cell and self.tooltipCell~=cell then return end
    local previous=self.tooltipCell
    self.tooltipGeneration=(self.tooltipGeneration or 0)+1
    if self.tooltipTimer then self.tooltipTimer:Cancel();self.tooltipTimer=nil end
    self.tooltipCell=nil
    if previous and GameTooltip:GetOwner()==previous then GameTooltip:Hide() end
end

function UI:BeginStatTooltip(cell,index)
    self:CancelStatTooltip()
    GameTooltip:Hide()
    if not self.expanded or self.progress~=1 or not cell:IsVisible() or self.dragging then return end
    self.tooltipCell=cell
    local generation=self.tooltipGeneration
    self.tooltipTimer=C_Timer.NewTimer(2,function()
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
    GameTooltip:AddLine(tooltipLabels[i], 1,1,1)
    if i~=3 then GameTooltip:AddLine(explanations[i], .75,.77,.82, true) end
    local s = owner.session
    if i >= 5 and s then
        local key = ({"kills","quests","dungeons","other"})[i-4]
        local amount = s.buckets[key]
        GameTooltip:AddLine(string.format("%d XP · %.1f%% of session", amount, s.total > 0 and amount*100/s.total or 0), .8,.65,1)
    elseif i == 3 and owner.tracker then
        local t=owner.tracker
        local rate,duration=M.Estimate(s,t.xp,t.cap,owner:IsCapped())
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

function UI:Create(owner)
    self.owner = owner
    local f = CreateFrame("Button", "XPIslandFrame", UIParent)
    self.frame = f
    self.progress=0
    self.animateStep=function(_,elapsed) self:Animate(elapsed) end
    -- Above ordinary action bars and panels, below DIALOG menus/system prompts
    -- and TOOLTIP. Children inherit the same strata and relative frame levels.
    f:SetFrameStrata("HIGH"); f:SetFrameLevel(100); f:SetClampedToScreen(true)
    f:SetMovable(true); f:RegisterForDrag("LeftButton")
    self.outer = UI.Round(f, {0.19,0.20,0.23,1}, 0)
    self.inner = UI.Round(f, {0.035,0.04,0.055,0.97}, 1)
    local content = CreateFrame("Frame", nil, f)
    self.content = content; content:SetAllPoints(); content:SetFrameLevel(f:GetFrameLevel()+2)
    self.header=CreateFrame("Frame",nil,content)
    self.label = UI.Text(self.header, 14)
    self.label:SetJustifyH("RIGHT")
    -- A bundled symbol avoids guessing arbitrary SharedMedia font coverage.
    -- If the client cannot load it, the label uses the ASCII fallback "n/a".
    self.infinity=self.header:CreateTexture(nil,"OVERLAY")
    self.infinitySupported=self.infinity:SetTexture("Interface\\AddOns\\XPIsland\\media\\infinity.tga")
    self.infinity:SetVertexColor(.93,.94,.97,1)
    self.infinity:SetPoint("RIGHT",self.header,"RIGHT",-14,0);self.infinity:Hide()
    self.segments = {}
    for i=1,20 do
        local edge=i==1 and "left" or i==20 and "right" or nil
        local track = UI.BarPiece(self.header, "ARTWORK", edge)
        local fill = UI.BarPiece(self.header, "OVERLAY", edge)
        fill:SetFrameLevel(track:GetFrameLevel()+1)
        fill:SetPoint("LEFT", track, "LEFT")
        self.segments[i] = {track=track, fill=fill}
    end
    self.divider = UI.Solid(content, "ARTWORK", .18,.18,.22)
    self.details=CreateFrame("Frame",nil,content)
    self.details:SetClipsChildren(true)
    self.cells = {}
    for i=1,8 do
        local cell = CreateFrame("Frame", nil, self.details)
        cell:EnableMouse(true)
        cell.title = UI.Text(cell, 12, .86,.79,.63)
        cell.value = UI.Text(cell, 14)
        cell.title:SetPoint("TOP"); cell.value:SetPoint("TOP",0,-18);cell.value:SetText("0")
        cell.title:SetJustifyH("CENTER");cell.value:SetJustifyH("CENTER")
        cell.title:SetText(labels[i])
        cell:SetScript("OnEnter", function()
            owner:InteractionChanged()
            self:BeginStatTooltip(cell,i)
        end)
        cell:SetScript("OnLeave", function() self:CancelStatTooltip(cell);owner:InteractionChanged() end)
        cell:SetScript("OnHide", function() self:CancelStatTooltip(cell) end)
        cell:SetScript("OnMouseUp", function(_,button) if button=="LeftButton" then owner:Toggle() end end)
        self.cells[i] = cell
    end
    f:SetScript("OnClick", function()
        if self.dragged then self.dragged = nil; return end
        owner:Toggle()
    end)
    f:SetScript("OnDragStart", function()
        if owner.profile.locked then return end
        self:CancelStatTooltip()
        self.dragged = true; self.dragging = true
        owner:InteractionChanged(); self:StopAnimation(); self:RenderGeometry(self.expanded and 1 or 0); f:StartMoving()
    end)
    f:SetScript("OnDragStop", function()
        if not self.dragging then return end
        self.dragging = nil; f:StopMovingOrSizing()
        local factor = f:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local x = select(1,f:GetCenter()) * factor - UIParent:GetWidth()/2
        local y = self.header:GetTop()*factor - UIParent:GetTop()
        owner.profile.position = {x=x, y=y}
        owner.profile.placement = "custom"
        self:Layout()
        owner:InteractionChanged()
    end)
    f:SetScript("OnEnter", function()
        self:CancelStatTooltip()
        owner:InteractionChanged()
        local t=owner.tracker
        if not t or not t.cap or t.cap<=0 then return end
        GameTooltip:SetOwner(f,"ANCHOR_BOTTOM")
        if owner.profile.format=="eta" then
            local rate,duration=M.Estimate(owner.session,t.xp,t.cap,owner:IsCapped())
            local state=M.ETAState(owner.session,rate,duration)
            GameTooltip:AddLine(state=="ready" and M.Duration(duration,true).." at your current rate" or M.ETAMessages[state],1,1,1,true)
        end
        GameTooltip:AddLine(M.ExactXP(t.xp,t.cap),1,1,1)
        if not owner.db.expandedOnce then
            GameTooltip:AddLine("Click to expand · /xpisland for settings",.8,.8,.85)
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide();owner:InteractionChanged() end)
    f:SetScript("OnHide",function()
        self:CancelStatTooltip()
        self:StopAnimation();owner:CancelAutoCollapse()
        self.expanded=false
        if self.layout then self:RenderGeometry(0) end
    end)
    self:Layout(); f:Hide()
end

function UI:BarLabel(rate,duration)
    local p,t=self.owner.profile,self.owner.tracker
    local text="—"
    local infinity=false
    if t and t.cap then
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
    if text==self.labelSource and p.fontSize==self.labelSize and self.font==self.labelFont then
        return self.label:GetText(),self.labelWidth
    end
    self.labelSource,self.labelSize,self.labelFont=text,p.fontSize,self.font
    self.label:SetText(text)
    local width=self.label:GetUnboundedStringWidth()+8
    if width>200 then
        text=text:gsub(" XP","");self.label:SetText(text)
        width=self.label:GetUnboundedStringWidth()+8
    end
    self.labelWidth=math.max(46,width)
    return text,self.labelWidth
end

function UI:Layout(preserveMotion)
    if not self.frame or self.dragging then return end
    if not preserveMotion then self:CancelStatTooltip() end
    local p,f=self.owner.profile,self.frame
    self.font=UI.Font(p)
    self.label:SetFont(self.font,p.fontSize,"")
    self.infinity:SetSize(p.fontSize*1.4,p.fontSize*.8)
    local titleHeight,valueHeight=0,0
    for _,c in ipairs(self.cells) do
        c.title:SetFont(self.font,math.max(12,math.min(14,p.fontSize-2)),"")
        c.value:SetFont(self.font,p.fontSize,"")
        titleHeight=math.max(titleHeight,c.title:GetStringHeight())
        valueHeight=math.max(valueHeight,c.value:GetStringHeight())
    end
    local cellHeight=math.max(36,titleHeight+3+valueHeight)
    local tracker=self.owner.tracker
    local rate,duration=M.Estimate(self.owner.session,tracker and tracker.xp,tracker and tracker.cap,self.owner:IsCapped())
    local _,labelWidth=self:BarLabel(rate,duration)
    local layout=M.Placement(UIParent:GetWidth(),UIParent:GetHeight(),p,labelWidth+180,24+cellHeight*2+6)
    layout.labelWidth=labelWidth;layout.font=self.font;layout.cellHeight=cellHeight
    self.layout=layout
    if not preserveMotion then self:StopAnimation();self.progress=self.expanded and 1 or 0 end
    f:SetScale(layout.scale);f:ClearAllPoints()
    self.outer:Radius(17);self.inner:Radius(16)
    self.label:ClearAllPoints();self.label:SetPoint("RIGHT",self.header,"RIGHT",-14,0)
    self.label:SetSize(labelWidth,p.fontSize+4)
    self.header:ClearAllPoints()
    local point=layout.up and "BOTTOM" or "TOP"
    self.header:SetPoint(point,self.content,point)
    self.header:SetHeight(layout.barHeight)
    self.details:ClearAllPoints();self.details:SetPoint("TOPLEFT",0,layout.up and -12 or -(layout.barHeight+12))
    self.divider:ClearAllPoints()
    self.divider:SetPoint(layout.up and "BOTTOMLEFT" or "TOPLEFT",14,layout.up and layout.barHeight+1 or -layout.barHeight)
    self.divider:SetHeight(1)
    for i,c in ipairs(self.cells) do
        c.title:SetHeight(titleHeight);c.value:SetHeight(valueHeight)
        -- Center the measured block within its row. Both outer drawer margins
        -- stay 12px; larger fonts get more height rather than a clipped last row.
        local inset=(cellHeight-titleHeight-3-valueHeight)/2
        c.title:SetPoint("TOP",0,-inset);c.value:SetPoint("TOP",0,-inset-titleHeight-3)
        c:SetHeight(cellHeight)
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
        local segWidth=(width-40-layout.labelWidth-38)/20
        for i,s in ipairs(self.segments) do
            s.track:SetPoint("LEFT",self.header,"LEFT",14+(i-1)*(segWidth+2),0)
            s.track:Draw(segWidth,10,1,TRACK_COLOR);s.width=segWidth
        end
        self:PaintBar(true)
        self.divider:SetWidth(width-28)
        self.details:SetSize(width,math.max(0,height-layout.barHeight-24))
        local cellWidth=(width-76)/4
        for i,c in ipairs(self.cells) do
            c:SetPoint("TOPLEFT",20+(i-1)%4*(cellWidth+12),-math.floor((i-1)/4)*(layout.cellHeight+6))
            c:SetWidth(cellWidth);c.title:SetWidth(cellWidth);c.value:SetWidth(cellWidth)
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
        for _,c in ipairs(self.cells) do c:EnableMouse(interactive) end
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
    GameTooltip:Hide()
    if self.expanded==expanded and self.animation and not instant then return end
    self.expanded=expanded
    if instant or not self.layout or not self.frame:IsShown() then self:Layout();return end
    self:StopAnimation()
    local target=expanded and 1 or 0
    if self.progress==target then self:RenderGeometry(target);return end
    self.animation={from=self.progress,to=target,elapsed=0,duration=math.max(.08,.22*math.abs(target-self.progress))}
    self:RenderGeometry(self.progress)
    self.frame:SetScript("OnUpdate",self.animateStep)
end

function UI:PaintBar(geometryChanged)
    local o,p=self.owner,self.owner.profile
    local t=o.tracker
    if not t or not t.cap then return end
    local fraction=t.cap>0 and math.min(1,math.max(0,t.xp/t.cap)) or 0
    local color=(o.rested or 0)>0 and p.rested or p.normal
    if geometryChanged or fraction~=self.barFraction or color[1]~=self.barR or color[2]~=self.barG or color[3]~=self.barB then
        for i,s in ipairs(self.segments) do
            local fill=math.min(1,math.max(0,fraction*20-(i-1)))
            s.fill:Draw(s.width,10,fill,color)
        end
        self.barFraction,self.barR,self.barG,self.barB=fraction,color[1],color[2],color[3]
    end
end

function UI:Update()
    if not self.frame then return end
    local o, p = self.owner, self.owner.profile
    local t = o.tracker
    if not t or not t.cap then return end
    local xp, cap, rested = t.xp, t.cap, o.rested or 0
    local rate,duration=M.Estimate(o.session,xp,cap,o:IsCapped())
    local text,labelWidth=self:BarLabel(rate,duration)
    if labelWidth~=self.layout.labelWidth or UI.Font(p)~=self.layout.font then self:Layout(true);return end
    self:PaintBar()
    local s=o.session
    local left=math.max(0,cap-xp)
    local values = {
        M.Compact(left).." / "..M.Compact(cap), rate and M.Compact(rate) or "—",
        M.Duration(duration), rested>0 and M.Compact(rested) or "—",
        M.Compact(s.buckets.kills), M.Compact(s.buckets.quests), M.Compact(s.buckets.dungeons), M.Compact(s.buckets.other),
    }
    for i,c in ipairs(self.cells) do
        if c.sourceValue~=values[i] or c.measuredFont~=self.font or c.measuredSize~=p.fontSize or (i==1 and c.measuredWidth~=c:GetWidth()) then
            c.sourceValue,c.measuredFont,c.measuredSize,c.measuredWidth=values[i],self.font,p.fontSize,c:GetWidth()
            c.value:SetText(values[i])
            if i==1 and c.value:GetUnboundedStringWidth()>c:GetWidth() then
                c.value:SetText(M.Compact(left,0).." / "..M.Compact(cap,0))
            end
        end
    end
    self.frame:SetShown(not o:IsCapped() and cap>0)
end
