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
    function f:Draw(width,height,amount,color)
        self:SetSize(width,height)
        local visible=width*amount
        self:SetShown(visible>0)
        self.body:SetColorTexture(color[1],color[2],color[3],1)
        local radius=math.min(height/2,width)
        local start=self.edge=="left" and radius or 0
        local finish=self.edge=="right" and width-radius or width
        local bodyWidth=math.max(0,math.min(visible,finish)-start)
        self.body:ClearAllPoints();self.body:SetPoint("LEFT",start,0)
        self.body:SetSize(math.max(.001,bodyWidth),height);self.body:SetShown(bodyWidth>0)
        if self.cap then
            local offset=self.edge=="left" and 0 or width-radius
            local capWidth=math.max(0,math.min(radius,visible-offset))
            self.cap:ClearAllPoints();self.cap:SetPoint("LEFT",offset,0)
            self.cap:SetSize(math.max(.001,capWidth),height)
            local u=self.edge=="left" and 0 or .5
            self.cap:SetTexCoord(u,u+.5*capWidth/radius,0,1)
            self.cap:SetVertexColor(color[1],color[2],color[3],1)
            self.cap:SetShown(capWidth>0)
        end
        self.visibleWidth=visible
    end
    return f
end

local labels = {"XP Remaining", "XP/hour", "Time to Level", "Rested XP", "Kill XP", "Quest XP", "Dungeon XP", "Other XP"}
-- Keep the approved tooltip wording and presentation intact.
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
        cell.title:SetPoint("TOP"); cell.value:SetPoint("TOP",0,-18)
        cell.title:SetJustifyH("CENTER");cell.value:SetJustifyH("CENTER")
        cell.title:SetText(labels[i])
        cell:SetScript("OnEnter", function()
            owner:InteractionChanged()
            GameTooltip:SetOwner(cell, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(tooltipLabels[i], 1,1,1)
            GameTooltip:AddLine(explanations[i], .75,.77,.82, true)
            local s = owner.session
            if i >= 5 and s then
                local key = ({"kills","quests","dungeons","other"})[i-4]
                local amount = s.buckets[key]
                GameTooltip:AddLine(string.format("%d XP · %.1f%% of session", amount, s.total > 0 and amount*100/s.total or 0), .8,.65,1)
            elseif i == 3 and owner.tracker then
                local t=owner.tracker
                local rate,duration=M.Estimate(s,t.xp,t.cap,owner:IsCapped())
                if duration then
                    GameTooltip:AddLine(M.Duration(duration,true).." at your current rate",.8,.65,1)
                    GameTooltip:AddLine(string.format("%s XP/hour · %d XP remaining",M.Compact(rate),math.max(0,t.cap-t.xp)),.75,.77,.82,true)

                end
            elseif i == 1 and owner.tracker and owner.tracker.cap then
                GameTooltip:AddLine(string.format("%d / %d XP remaining", math.max(0,owner.tracker.cap-owner.tracker.xp), owner.tracker.cap), .8,.65,1)
            end
            if s and s.incomplete then GameTooltip:AddLine("Session contains a gap; rate and ETA are unavailable.",1,.65,.25,true) end
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function() GameTooltip:Hide();owner:InteractionChanged() end)
        cell:SetScript("OnMouseUp", function(_,button) if button=="LeftButton" then owner:Toggle() end end)
        self.cells[i] = cell
    end
    f:SetScript("OnClick", function()
        if self.dragged then self.dragged = nil; return end
        owner:Toggle()
    end)
    f:SetScript("OnDragStart", function()
        if owner.profile.locked then return end
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
        owner:InteractionChanged()
        if self.expanded then return end
        GameTooltip:SetOwner(f,"ANCHOR_BOTTOM")
        GameTooltip:AddLine("XPIsland", .8,.65,1)
        GameTooltip:AddLine("Click to expand · /xpisland for settings",.8,.8,.85)
        if not owner.profile.locked then GameTooltip:AddLine("Unlocked: drag to move",.8,.8,.85) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide();owner:InteractionChanged() end)
    f:SetScript("OnHide",function()
        self:StopAnimation();owner:CancelAutoCollapse()
        self.expanded=false
        if self.layout then self:RenderGeometry(0) end
    end)
    self:Layout(); f:Hide()
end

function UI:BarLabel(duration)
    local p,t=self.owner.profile,self.owner.tracker
    local text="—"
    if t and t.cap then
        if p.format=="eta" then
            text=M.Duration(duration)
        else text=M.Label(p.format,t.xp,t.cap) end
    end
    self.label:SetFont(UI.Font(p),p.fontSize,"")
    self.label:SetText(text)
    local width=self.label:GetUnboundedStringWidth()+8
    -- Drop the redundant unit before giving up bar space. Settings name the XP
    -- format; the remaining-XP word and percentage denominator stay explicit.
    if width>200 then
        text=text:gsub(" XP","");self.label:SetText(text)
        width=self.label:GetUnboundedStringWidth()+8
    end
    return text,math.max(46,width)
end

function UI:Layout(preserveMotion)
    if not self.frame or self.dragging then return end
    local p, f = self.owner.profile, self.frame
    local tracker=self.owner.tracker
    local _,duration=M.Estimate(self.owner.session,tracker and tracker.xp,tracker and tracker.cap,self.owner:IsCapped())
    local text,labelWidth=self:BarLabel(duration)
    local layout=M.Placement(UIParent:GetWidth(),UIParent:GetHeight(),p,labelWidth+180)
    layout.labelWidth=labelWidth;layout.font=UI.Font(p)
    self.layout=layout
    if not preserveMotion then
        self:StopAnimation()
        self.progress=self.expanded and 1 or 0
    end
    local font=UI.Font(p)
    self.label:ClearAllPoints();self.label:SetPoint("RIGHT",self.header,"RIGHT",-14,0)
    self.label:SetSize(labelWidth,p.fontSize+4)
    for _,c in ipairs(self.cells) do
        c.title:SetFont(font,math.max(12,math.min(14,p.fontSize-2)),"")
        c.value:SetFont(font,p.fontSize,"")
    end
    self:RenderGeometry(self.progress)
    self:Update()
end

-- Geometry only: the short transition does not recalculate fonts, rates or XP
-- attribution. All frames/textures are reused, and OnUpdate is removed at rest.
function UI:RenderGeometry(progress)
    local layout,f=self.layout,self.frame
    self.progress=progress
    local width=layout.collapsed+(layout.expanded-layout.collapsed)*progress
    local height=layout.barHeight+(layout.panelHeight-layout.barHeight)*progress
    local scale=layout.scale
    f:SetScale(scale);f:SetSize(width,height)
    self.outer:Radius(17);self.inner:Radius(16)
    local y=layout.y+(layout.up and (height-layout.barHeight)*scale or 0)
    f:ClearAllPoints();f:SetPoint("TOP",UIParent,"TOP",layout.x/scale,y/scale)
    self.header:ClearAllPoints();self.header:SetSize(width,layout.barHeight)
    local point=layout.up and "BOTTOM" or "TOP"
    self.header:SetPoint(point,self.content,point)
    local barWidth=width-40-layout.labelWidth
    local gap=2
    local segWidth=(barWidth-19*gap)/20
    for i,s in ipairs(self.segments) do
        s.track:ClearAllPoints();s.track:SetPoint("LEFT",self.header,"LEFT",14+(i-1)*(segWidth+gap),0)
        s.track:Draw(segWidth,10,1,TRACK_COLOR);s.width=segWidth
    end
    self.barFraction=nil;self:PaintBar()
    self.divider:ClearAllPoints()
    self.divider:SetPoint("TOPLEFT",14,layout.up and -(height-layout.barHeight-1) or -layout.barHeight)
    self.divider:SetSize(width-28,1)
    local opacity=math.max(0,math.min(1,(progress-.35)/.65))
    opacity=opacity*opacity*(3-2*opacity)
    self.divider:SetShown(progress>0);self.divider:SetAlpha(opacity)
    self.details:ClearAllPoints()
    self.details:SetPoint("TOPLEFT",0,layout.up and -12 or -46)
    self.details:SetSize(width,math.max(0,height-layout.barHeight-24))
    self.details:SetAlpha(opacity);self.details:SetShown(progress>0)
    local margin,gap=20,12
    local cellWidth=(width-2*margin-3*gap)/4
    for i,c in ipairs(self.cells) do
        local col=(i-1)%4;local row=math.floor((i-1)/4)
        c:ClearAllPoints();c:SetPoint("TOPLEFT",margin+col*(cellWidth+gap),-row*44)
        c:SetSize(cellWidth,37);c.title:SetWidth(cellWidth);c.value:SetWidth(cellWidth)
        c:EnableMouse(progress==1 and self.expanded or false)
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
    self:RenderGeometry(a.from+(a.to-a.from)*eased)
    if t>=1 then
        self:StopAnimation();self:RenderGeometry(a.to);self:Update()
    end
end

function UI:SetExpanded(expanded, instant)
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

function UI:PaintBar()
    local o,p=self.owner,self.owner.profile
    local t=o.tracker
    if not t or not t.cap then return end
    local fraction=t.cap>0 and math.min(1,math.max(0,t.xp/t.cap)) or 0
    local color=(o.rested or 0)>0 and p.rested or p.normal
    if fraction~=self.barFraction or color[1]~=self.barR or color[2]~=self.barG or color[3]~=self.barB then
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
    local text,labelWidth=self:BarLabel(duration)
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
        c.value:SetText(values[i])
        local size=p.fontSize
        c.value:SetFont(UI.Font(p),size,"")
        if i==1 and c.value:GetUnboundedStringWidth()>c:GetWidth() then
            c.value:SetText(M.Compact(left,0).." / "..M.Compact(cap,0))
        end
    end
    self.frame:SetShown(not o:IsCapped() and cap>0)
end
