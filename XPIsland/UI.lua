local _, ns = ...
local M = ns.Model
local UI = {}
ns.UI = UI
local MEDIA = "Interface\\AddOns\\XPIsland\\media\\rounded.tga"

function UI.Text(parent, size, r, g, b)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\ARIALN.TTF", size, "")
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
    if profile.font == "Arial" then return "Fonts\\ARIALN.TTF" end
    if profile.font == "Friz Quadrata" then return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    return (lsm and lsm:IsValid("font", profile.font) and lsm:Fetch("font", profile.font)) or "Fonts\\ARIALN.TTF"
end

local labels = {"XP remaining", "Session XP/hour", "Next level", "Rested XP", "Outdoor kills", "Outdoor quests", "Dungeons", "Other"}
local explanations = {
    "XP still needed / total required for this level.",
    "All session XP divided by connected gameplay time. Idle time counts; reload and reconnect gaps do not.",
    "Estimated from the session XP/hour rate. Available after one minute with XP earned.",
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
    f:SetFrameStrata("MEDIUM"); f:SetClampedToScreen(true)
    f:SetMovable(true); f:RegisterForDrag("LeftButton")
    self.outer = UI.Round(f, {0.19,0.20,0.23,1}, 0)
    self.inner = UI.Round(f, {0.035,0.04,0.055,0.97}, 1)
    local content = CreateFrame("Frame", nil, f)
    self.content = content; content:SetAllPoints(); content:SetFrameLevel(f:GetFrameLevel()+2)
    self.label = UI.Text(content, 12)
    self.label:SetJustifyH("RIGHT")
    self.segments = {}
    for i=1,20 do
        local track = UI.Solid(content, "ARTWORK", .14,.14,.18)
        local fill = UI.Solid(content, "OVERLAY", .64,.35,.94)
        fill:SetPoint("LEFT", track, "LEFT")
        self.segments[i] = {track=track, fill=fill}
    end
    self.divider = UI.Solid(content, "ARTWORK", .18,.18,.22)
    self.cells = {}
    for i=1,8 do
        local cell = CreateFrame("Frame", nil, content)
        cell:EnableMouse(true)
        cell.title = UI.Text(cell, 10, .56,.58,.65)
        cell.value = UI.Text(cell, 13)
        cell.title:SetPoint("TOPLEFT"); cell.value:SetPoint("TOPLEFT",0,-15)
        cell.title:SetText(labels[i])
        cell:SetScript("OnEnter", function()
            GameTooltip:SetOwner(cell, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(labels[i], 1,1,1)
            GameTooltip:AddLine(explanations[i], .75,.77,.82, true)
            local s = owner.session
            if i >= 5 and s then
                local key = ({"kills","quests","dungeons","other"})[i-4]
                local amount = s.buckets[key]
                GameTooltip:AddLine(string.format("%d XP · %.1f%% of session", amount, s.total > 0 and amount*100/s.total or 0), .8,.65,1)
            elseif i == 1 and owner.tracker and owner.tracker.cap then
                GameTooltip:AddLine(string.format("%d / %d XP remaining", math.max(0,owner.tracker.cap-owner.tracker.xp), owner.tracker.cap), .8,.65,1)
            end
            if s and s.incomplete then GameTooltip:AddLine("Session contains a gap; rate and ETA are unavailable.",1,.65,.25,true) end
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
        owner:CancelAutoCollapse(); f:StartMoving()
    end)
    f:SetScript("OnDragStop", function()
        if not self.dragging then return end
        self.dragging = nil; f:StopMovingOrSizing()
        local factor = f:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local x = select(1,f:GetCenter()) * factor - UIParent:GetWidth()/2
        local y = f:GetTop()*factor - UIParent:GetTop()
        owner.profile.position = {x=x, y=y}
        self:Layout()
    end)
    f:SetScript("OnEnter", function()
        if self.expanded then return end
        GameTooltip:SetOwner(f,"ANCHOR_BOTTOM")
        GameTooltip:AddLine("XPIsland", .8,.65,1)
        GameTooltip:AddLine("Click to expand · /xpisland for settings",.8,.8,.85)
        if not owner.profile.locked then GameTooltip:AddLine("Unlocked: drag to move",.8,.8,.85) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self:Layout(); f:Hide()
end

function UI:Layout()
    if not self.frame or self.dragging then return end
    local p, f = self.owner.profile, self.frame
    local cw, ew, scale = M.Layout(UIParent:GetWidth(), p.scale)
    local width, height = self.expanded and ew or cw, self.expanded and 124 or 30
    scale = math.min(scale, math.max(.1,(UIParent:GetHeight()-24)/height))
    f:SetScale(scale); f:SetSize(width,height)
    self.outer:Radius(self.expanded and 17 or 15)
    self.inner:Radius(self.expanded and 16 or 14)
    local xLimit = math.max(0,(UIParent:GetWidth()-width*scale)/2-8)
    local x = math.max(-xLimit,math.min(xLimit,p.position.x))
    local y = math.max(-UIParent:GetHeight()+height*scale+8, math.min(-8,p.position.y))
    f:ClearAllPoints(); f:SetPoint("TOP", UIParent,"TOP",x/scale,y/scale)
    local font = UI.Font(p)
    self.label:SetFont(font,p.fontSize,"")
    self.label:SetText(({percent="100.0%",fraction="999.9k / 999.9k",left="999.9k left",leftPercent="999.9k left (100.0%)"})[p.format])
    local labelWidth = math.max(46,self.label:GetStringWidth()+3)
    self.label:ClearAllPoints(); self.label:SetPoint("TOPRIGHT",-14,-(30-p.fontSize)/2+1)
    self.label:SetSize(labelWidth,p.fontSize+3)
    local barWidth = width-28-labelWidth-12
    local gap = 2
    local segWidth = (barWidth-19*gap)/20
    for i,s in ipairs(self.segments) do
        s.track:ClearAllPoints(); s.track:SetPoint("TOPLEFT",14+(i-1)*(segWidth+gap),-11)
        s.track:SetSize(segWidth,8); s.fill:SetHeight(8)
        s.width=segWidth
    end
    self.divider:ClearAllPoints(); self.divider:SetPoint("TOPLEFT",14,-33); self.divider:SetSize(width-28,1)
    self.divider:SetShown(self.expanded or false)
    local cellWidth=(width-32)/4
    for i,c in ipairs(self.cells) do
        local col=(i-1)%4; local row=math.floor((i-1)/4)
        c:ClearAllPoints(); c:SetPoint("TOPLEFT",16+col*cellWidth,-43-row*39)
        c:SetSize(cellWidth-9,32)
        c.title:SetFont(font,math.max(10,math.min(12,p.fontSize-2)),"")
        c.value:SetFont(font,p.fontSize,"")
        c.title:SetWidth(cellWidth-9); c.value:SetWidth(cellWidth-9)
        c:SetShown(self.expanded or false)
    end
    self:Update()
end

function UI:SetExpanded(expanded)
    self.expanded = expanded
    GameTooltip:Hide()
    self:Layout()
end

function UI:Update()
    if not self.frame then return end
    local o, p = self.owner, self.owner.profile
    local t = o.tracker
    if not t or not t.cap then return end
    local xp, cap, rested = t.xp, t.cap, o.rested or 0
    local fraction=cap>0 and math.min(1,math.max(0,xp/cap)) or 0
    local color=rested>0 and p.rested or p.normal
    for i,s in ipairs(self.segments) do
        local fill=math.min(1,math.max(0,fraction*20-(i-1)))
        s.fill:SetColorTexture(color[1],color[2],color[3],1)
        s.fill:SetWidth(math.max(.01,s.width*fill)); s.fill:SetShown(fill>0)
    end
    self.label:SetText(M.Label(p.format,xp,cap))
    local s=o.session
    local left=math.max(0,cap-xp)
    local rate = not s.incomplete and s.seconds >= 60 and s.total > 0 and s.total*3600/s.seconds or nil
    local values = {
        M.Compact(left).." / "..M.Compact(cap), rate and M.Compact(rate) or "—",
        rate and M.Duration(left/rate*3600) or "—", rested>0 and M.Compact(rested) or "—",
        M.Compact(s.buckets.kills), M.Compact(s.buckets.quests), M.Compact(s.buckets.dungeons), M.Compact(s.buckets.other),
    }
    for i,c in ipairs(self.cells) do
        c.value:SetText(values[i])
        local size=p.fontSize
        c.value:SetFont(UI.Font(p),size,"")
        while size>10 and c.value:GetStringWidth()>c:GetWidth() do
            size=size-1;c.value:SetFont(UI.Font(p),size,"")
        end
    end
    self.frame:SetShown(not o:IsCapped() and cap>0)
end
