local _, ns = ...
local M, UI = ns.Model, ns.UI
local O = {}
ns.Options = O
local backdrop={bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=10,insets={left=2,right=2,top=2,bottom=2}}

-- Explicit single-line control allocations. Wrapping prose keeps its native
-- width; edit boxes keep native caret scrolling rather than scaling the widget.
local function bounded(text,width,height)
    text.xpOptionsWidth,text.xpOptionsHeight=width,height
    text:SetWordWrap(false)
end

local function fitBounded(text)
    if not text.xpOptionsWidth then return end
    text:SetScale(1)
    local width,height=UI.Measure(text)
    text.xpNaturalWidth=width
    local available=math.min(text.xpOptionsWidth,width*text.xpOptionsHeight/math.max(1,height))
    local scale=UI.FitText(text,available)
    text:SetSize(text.xpOptionsWidth/scale,text.xpOptionsHeight/scale)
    -- A local text scale also scales offsets. Preserve control-space insets.
    if text.xpOptionsAnchor then
        local a=text.xpOptionsAnchor
        UI.AnchorText(text,a[1],a[2],a[3],a[4],a[5])
    end
end

local function label(parent,text,x,y,size,gold)
    local t=UI.Text(parent,size or 12)
    t:SetPoint("TOPLEFT",x,y);t:SetText(text)
    if gold then t:SetTextColor(1,.82,.2) end
    O.fontObjects[#O.fontObjects+1]={object=t,size=size or 12}
    return t
end

local function button(parent,text,x,y,width,callback)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",x,y);b:SetSize(width,22)
    b:SetBackdrop(backdrop);b:SetBackdropColor(.06,.06,.065,.8);b:SetBackdropBorderColor(.45,.45,.45,.65)
    b.text=label(b,text,0,0)
    b.text:ClearAllPoints();b.text:SetPoint("CENTER")
    bounded(b.text,width-12,20)
    b:SetScript("OnEnter",function() b:SetBackdropBorderColor(.9,.8,.5,.9) end)
    b:SetScript("OnLeave",function() b:SetBackdropBorderColor(.45,.45,.45,.65) end)
    b:SetScript("OnClick",callback)
    return b
end

local function section(parent,text,x,y,width,height)
    local box=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    box:SetFrameLevel(parent:GetFrameLevel()-1)
    box:SetPoint("TOPLEFT",x,y-9);box:SetSize(width,height)
    box:SetBackdrop(backdrop);box:SetBackdropColor(.035,.035,.04,.35);box:SetBackdropBorderColor(.35,.35,.35,.5)
    label(parent,text,x+10,y,12,true)
    return box
end

local function edit(parent,x,y,width)
    local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
    e:SetPoint("TOPLEFT",x,y);e:SetSize(width,22)
    UI.ApplyFont(e,O.owner.profile,12);e:SetTextInsets(6,6,0,0)
    e:SetAutoFocus(false);e:SetMaxLetters(48)
    O.fontObjects[#O.fontObjects+1]={object=e,size=12}
    e:SetScript("OnEscapePressed",function(self) self:ClearFocus();O:Refresh() end)
    return e
end

-- Blizzard owns menu dismissal, keyboard navigation, scrolling and row pooling.
-- Selections use native radio rows, never buttons styled as dropdown entries.
function O:Dropdown(parent,x,y,width,entries,get,choose,placeholder)
    local d=CreateFrame("DropdownButton",nil,parent,"WowStyle1DropdownTemplate")
    d:SetPoint("TOPLEFT",x,y);d:SetSize(width,24)
    d:SetDefaultText(placeholder or "Choose…")
    -- The Classic template supplies TOP anchors for a 10px text box. Keep
    -- native art/arrow, but center our 12px font in the control's full height.
    d.Text:ClearAllPoints()
    d.Text:SetPoint("LEFT",d,"LEFT",9,0)
    d.Text.xpOptionsAnchor={"LEFT",d,"LEFT",9,0}
    bounded(d.Text,width-31,24)
    d.Text:SetHeight(24);d.Text:SetJustifyV("MIDDLE")
    d.Text:SetJustifyH("LEFT");d.Text:SetWordWrap(false);d.text=d.Text
    self.fontObjects[#self.fontObjects+1]={object=d.Text,size=12}
    d:SetupMenu(function(_,root)
        root:SetScrollMode(220)
        for _,entry in ipairs(entries()) do
            local row=root:CreateRadio(entry.label or entry.value,function(value) return get()==value end,function(value)
                choose(value);self:Refresh()
            end,entry.value)
            row:AddInitializer(function(b)
                -- Compositor-owned FontStrings forbid SetFont, including a
                -- method lookup. Share our own Font object through the native
                -- supported setter; never modify Blizzard's global fonts.
                b.fontString:SetFontObject(self.menuFont)
            end)
        end
    end)
    self.dropdowns[#self.dropdowns+1]=d
    return d
end

function O:CloseMenu()
    for _,d in ipairs(self.dropdowns or {}) do d:CloseMenu() end
end

function O:Check(parent,text,key,x,y)
    local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate")
    b:SetPoint("TOPLEFT",x-4,y);b:SetSize(24,24)
    b.key,b.caption=key,text;b.text=b.Text
    b.text:SetWidth(250);b.text:SetJustifyH("LEFT");b.text:SetTextColor(.93,.94,.97)
    bounded(b.text,250,24)
    b:SetHitRectInsets(0,-250,0,0)
    b:SetScript("OnClick",function()
        self.owner.profile[key]=b:GetChecked();self.owner:ApplyProfile()
    end)
    self.fontObjects[#self.fontObjects+1]={object=b.text,size=12}
    self.checks[#self.checks+1]=b
    return b
end

function O:Duration(parent,toggle,key,y)
    local check=self:Check(parent,toggle=="levelUp" and "Expand at level-up" or "Auto-collapse",toggle,328,y)
    check.text:SetWidth(134);check.text:SetWordWrap(false);check:SetHitRectInsets(0,-134,0,0)
    bounded(check.text,134,24)
    local slider=CreateFrame("Slider",nil,parent,"UISliderTemplate")
    slider:SetPoint("TOPLEFT",492,y-4);slider:SetSize(56,16)
    slider:SetHitRectInsets(0,0,-3,-3)
    slider:SetOrientation("HORIZONTAL");slider:SetMinMaxValues(5,15)
    slider:SetValueStep(5);slider:SetObeyStepOnDrag(true)
    slider:GetThumbTexture():SetSize(20,20)
    for i=0,2 do
        local tick=UI.Solid(slider,"BACKGROUND",.55,.55,.6,.7)
        tick:SetSize(1,3);tick:SetPoint("TOP",slider,"BOTTOMLEFT",i*28,0)
    end
    slider.valueText=label(parent,"",562,y-6,11)
    slider.valueText:SetWidth(34);slider.valueText:SetJustifyH("RIGHT")
    slider.valueText:ClearAllPoints();slider.valueText:SetPoint("TOPLEFT",parent,"TOPLEFT",562,y-6)
    slider.valueText.xpOptionsAnchor={"TOPLEFT",parent,"TOPLEFT",562,y-6}
    bounded(slider.valueText,34,18)
    slider.toggle=toggle
    slider:SetScript("OnValueChanged",function(_,value)
        if self.refreshing or not self.owner.profile[toggle] then return end
        local snapped=math.max(5,math.min(15,math.floor(value/5+.5)*5))
        if self.owner.profile[key]~=snapped then
            self.owner.profile[key]=snapped;self.owner:ApplyProfile()
        end
        self:Refresh()
    end)
    self.durationSliders[key]=slider
end

function O:Color(key)
    local p=self.owner.profile
    local original=M.Copy(p[key])
    ColorPickerFrame:SetupColorPickerAndShow({r=original[1],g=original[2],b=original[3],hasOpacity=false,
        swatchFunc=function()
            p[key]={ColorPickerFrame:GetColorRGB()};self.owner:ApplyProfile()
        end,
        cancelFunc=function() p[key]=original;self.owner:ApplyProfile() end})
end

function O:Create(owner)
    self.owner=owner;self.checks={};self.fontObjects={};self.dropdowns={};self.durationSliders={}
    self.menuFont=self.menuFont or CreateFont("XPIslandMenuFont")
    UI.ApplyFont(self.menuFont,owner.profile,12)
    local f=CreateFrame("Frame","XPIslandOptions",UIParent,"BackdropTemplate")
    self.frame=f
    f:SetSize(620,462);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG")
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=8,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    f:SetBackdropColor(.045,.045,.05,.94);f:SetBackdropBorderColor(.65,.65,.65,1)
    f:EnableMouse(true);f:SetClampedToScreen(true);f:SetMovable(true);f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function() f:StartMoving() end)
    f:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
    local content=CreateFrame("Frame",nil,f);content:SetAllPoints();self.content=content
    label(content,"XPIsland",20,-15,16,true)
    self.close=CreateFrame("Button",nil,content,"UIPanelCloseButton")
    self.close:SetSize(24,24);self.close:SetPoint("TOPRIGHT",-8,-8)
    self.close:SetScript("OnClick",function() f:Hide() end)
    self.optionsTab=button(content,"Options",20,-42,86,function() self:Page(false) end)
    self.profilesTab=button(content,"Profiles",110,-42,86,function() self:Page(true) end)
    self.trackingTab=button(content,"Tracking",200,-42,86,function() self:Page("tracking") end)
    for _,b in ipairs({self.optionsTab,self.profilesTab,self.trackingTab}) do
        b.activeLine=UI.Solid(b,"ARTWORK",1,.82,.2,.8)
        b.activeLine:SetPoint("BOTTOMLEFT",4,0);b.activeLine:SetPoint("BOTTOMRIGHT",-4,0);b.activeLine:SetHeight(1)
    end
    self.options=CreateFrame("Frame",nil,content);self.options:SetAllPoints()
    self.profiles=CreateFrame("Frame",nil,content);self.profiles:SetAllPoints()
    self.tracking=CreateFrame("Frame",nil,content);self.tracking:SetAllPoints()
    local page=self.options
    section(page,"Appearance",16,-80,288,278)
    section(page,"Behavior",316,-80,288,218)
    section(page,"Position",316,-320,288,105)
    label(page,"Bar label",28,-105)
    self.format=self:Dropdown(page,28,-125,260,function() return {
        {value="percent",label="Percentage"},{value="fraction",label="Current / Total XP"},
        {value="left",label="XP Remaining"},{value="leftPercent",label="XP Remaining (%)"},{value="eta",label="Time to Next Level"},
        {value="kills",label="Kills to level"}
    } end,function() return owner.profile.format end,function(v) owner.profile.format=v;owner:ApplyProfile() end)
    label(page,"Font",28,-163)
    self.font=self:Dropdown(page,28,-183,260,function()
        local names={Arial=true,["Friz Quadrata"]=true,["Game tooltip"]=true}
        local lsm=LibStub and LibStub("LibSharedMedia-3.0",true)
        if lsm then for name in pairs(lsm:HashTable("font")) do names[name]=true end end
        local list={};for name in pairs(names) do list[#list+1]={value=name,label=name=="Game tooltip" and "Game Tooltip (default)" or name} end
        table.sort(list,function(a,b) return a.value<b.value end);return list
    end,function() return owner.profile.font end,function(v)
        owner.profile.font=v;owner.profile.fontCustomized=v~="Game tooltip";owner:ApplyProfile()
    end)
    label(page,"Font size",28,-225)
    self.fontSize=edit(page,230,-219,58)
    self.fontSize:SetScript("OnEnterPressed",function(e)
        owner.profile.fontSize=math.floor(math.max(10,math.min(18,tonumber(e:GetText()) or owner.profile.fontSize)))
        owner.profile.fontSizeCustomized=true;e:ClearFocus();owner:ApplyProfile()
    end)
    label(page,"Island scale",28,-259)
    local slider=CreateFrame("Slider",nil,page,"UISliderTemplate")
    self.scale=slider;slider:SetPoint("TOPLEFT",28,-284);slider:SetSize(180,16)
    slider:SetOrientation("HORIZONTAL");slider:SetMinMaxValues(50,150);slider:SetValueStep(1);slider:SetObeyStepOnDrag(true)
    self.scaleEdit=edit(page,230,-279,58)
    slider:SetScript("OnValueChanged",function(_,v)
        if self.refreshing then return end
        owner.profile.scale=math.floor(v+.5)/100;self.scaleEdit:SetText(tostring(math.floor(v+.5)));owner:ApplyProfile()
    end)
    self.scaleEdit:SetScript("OnEnterPressed",function(e)
        owner.profile.scale=math.max(50,math.min(150,math.floor((tonumber(e:GetText()) or owner.profile.scale*100)+.5)))/100
        e:ClearFocus();owner:ApplyProfile()
    end)
    label(page,"50–150%",28,-306,11):SetTextColor(.65,.65,.68)
    for i,key in ipairs({"normal","rested"}) do
        local b=button(page,key=="normal" and "Normal XP" or "Rested XP",28+(i-1)*136,-334,124,function() self:Color(key) end)
        b.text:ClearAllPoints();b.text:SetPoint("LEFT",27,0)
        b.text.xpOptionsAnchor={"LEFT",b,"LEFT",27,0};bounded(b.text,90,20)
        b.swatch=UI.Solid(b,"ARTWORK",1,1,1);b.swatch:SetPoint("LEFT",7,0);b.swatch:SetSize(12,12)
        self[key]=b
    end
    self:Check(page,"Lock position","locked",328,-104)
    self:Duration(page,"levelUp","levelUpDuration",-132)
    self:Duration(page,"autoCollapse","autoCollapseDuration",-160)
    self:Check(page,"Collapse when combat starts","collapseCombat",328,-188)
    self:Check(page,"Hide Blizzard XP bar","hideBlizzard",328,-216)
    local hint=label(page,"Other addon bars keep their own controls.",328,-247,11)
    hint:SetWidth(260);hint:SetWordWrap(true);hint:SetTextColor(.7,.7,.72)
    self.binding=button(page,"",328,-273,260,function() Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID,"XPIsland") end)
    self.placement=self:Dropdown(page,328,-342,260,function() return {
        {value="top",label="Top"},{value="bottom",label="Bottom"},{value="custom",label="Custom (dragged)"}
    } end,function() return owner.profile.placement end,function(v) owner.profile.placement=v;owner:ApplyProfile() end)
    label(page,"Unlock and drag to set a custom position.",328,-377,11):SetTextColor(.7,.7,.72)
    button(page,"Reset to top",328,-401,124,function()
        owner.profile.position={x=0,y=-8};owner.profile.placement="top";owner:ApplyProfile()
    end)
    button(page,"Expand/collapse",464,-401,124,function() owner:Toggle() end)
    local timerHint=label(page,"Collapse waits while hovering, dragging, or using these settings.",28,-386,11)
    timerHint:SetWidth(260);timerHint:SetWordWrap(true);timerHint:SetTextColor(.7,.7,.72)
    self.status=label(content,"",20,-442,11);self.status:SetWidth(580);self.status:SetWordWrap(true);self.status:SetTextColor(.8,.8,.8)
    page=self.profiles
    section(page,"Profiles",16,-80,588,340)
    label(page,"Active profile",28,-108)
    self.active=self:Dropdown(page,28,-130,260,function() return self:ProfileEntries() end,function() return owner.profileName end,function(v) self:Switch(v) end)
    local info=label(page,"Shared profiles update every character using them. A character profile is an independent copy. Session statistics stay with your character.",328,-108)
    info:SetWidth(260);info:SetWordWrap(true)
    button(page,"Use shared",28,-172,124,function() self:Switch("Shared") end)
    button(page,"Use character",164,-172,124,function()
        local name=owner.characterName
        if not owner.db.profiles[name] then owner.db.profiles[name]=M.Copy(owner.profile) end
        self:Switch(name)
    end)
    label(page,"New profile name",28,-228)
    self.name=edit(page,28,-250,260)
    button(page,"Duplicate and use",328,-250,260,function()
        local name,err=M.Duplicate(owner.db,owner.profileName,self.name:GetText())
        if name then self:Switch(name);self.name:SetText("") else self.status:SetText(err) end
    end)
    label(page,"Copy settings from",28,-308)
    self.copy=self:Dropdown(page,28,-330,260,function() return self:ProfileEntries() end,function() return self.copySource end,function(v)
        self.copySource=v;self.confirmCopy=nil
    end,"Choose source…")
    self.copyButton=button(page,"Copy settings",328,-330,260,function()
        if not self.copySource then self.status:SetText("Choose a source profile first.");return end
        if not self.confirmCopy then self.confirmCopy=true;self.copyButton.text:SetText("Confirm overwrite");fitBounded(self.copyButton.text);return end
        owner.db.profiles[owner.profileName]=M.Copy(owner.db.profiles[self.copySource]);owner.profile=owner.db.profiles[owner.profileName]
        self.confirmCopy=nil;owner:ApplyProfile()
    end)
    label(page,"Copy replaces the active profile. Duplicate creates a separate profile.",28,-383,11):SetTextColor(.7,.7,.72)
    page=self.tracking
    section(page,"Primary bar",16,-80,288,340)
    section(page,"Expanded XP details",316,-80,288,340)
    label(page,"Mode",28,-105)
    self.mode=self:Dropdown(page,28,-125,260,function() return {
        {value="xp",label="Experience"},{value="pvp",label="Honor & PvP"}
    } end,function() return owner.profile.mode end,function(v)
        owner.profile.mode=v;owner.profile.pvpAtCap=false;owner:ApplyProfile()
    end)
    self:Check(page,"Switch to PvP at level cap","pvpAtCap",28,-163)
    label(page,"Honor & PvP bar label",28,-207)
    self.pvpFormat=self:Dropdown(page,28,-227,260,function() return {
        {value="honor",label="Honor available"},{value="rankLeft",label="Rank Points to next"}
    } end,function() return owner.profile.pvpFormat end,function(v) owner.profile.pvpFormat=v;owner:ApplyProfile() end)
    local modeHint=label(page,"PvP mode stays visible at max level. Its bar shows rank progress; Honor is a separate spendable balance. Selecting a mode turns off automatic switching.",28,-271,12)
    modeHint:SetWidth(260);modeHint:SetWordWrap(true)
    self:Check(page,"Pet XP when available","showPet",328,-105)
    self:Check(page,"PvP rank progress","showRank",328,-139)
    self:Check(page,"Estimated kills to level","showKills",328,-173)
    local killHint=label(page,"Kill estimates use up to one hour of confirmed outdoor and dungeon kills. The latest 20 minutes count twice. Rested and group rewards affect the estimate.",328,-221,12)
    killHint:SetWidth(260);killHint:SetWordWrap(true)
    local inlineHint=label(page,"Details appear together in one compact row. No extra expansion is needed.",328,-328,12)
    inlineHint:SetWidth(260);inlineHint:SetWordWrap(true)
    f:SetScript("OnHide",function() self:CloseMenu();self.confirmCopy=nil;owner:InteractionChanged() end)
    f:SetScript("OnShow",function() self:Refresh();owner:InteractionChanged() end)
    UISpecialFrames[#UISpecialFrames+1]="XPIslandOptions"
    self:Page(false);f:Hide()
end

function O:ProfileEntries()
    local entries={};for name in pairs(self.owner.db.profiles) do entries[#entries+1]={value=name} end
    table.sort(entries,function(a,b) return a.value<b.value end);return entries
end

function O:Switch(name)
    local owner=self.owner
    owner.profile=M.SelectProfile(owner.db,owner.character,name);owner.profileName=name;self.confirmCopy=nil
    owner:ApplyProfile()
end

function O:Page(profiles)
    self:CloseMenu();self.confirmCopy=nil
    self.profiles:SetShown(profiles==true);self.options:SetShown(not profiles);self.tracking:SetShown(profiles=="tracking")
    for _,entry in ipairs({{self.optionsTab,not profiles},{self.profilesTab,profiles==true},{self.trackingTab,profiles=="tracking"}}) do
        entry[1].activeLine:SetShown(entry[2]);entry[1].text:SetTextColor(1,entry[2] and 1 or .82,entry[2] and 1 or .2)
    end
    self:Refresh()
end

function O:Refresh()
    if not self.frame then return end
    self.owner:RefreshAppearance(false,true,true)
end

function O:RefreshFonts(regenerate)
    if not self.frame then return end
    local p=self.owner.profile
    local oldPath,oldSize,oldFlags=self.menuFont:GetFont()
    UI.ApplyFont(self.menuFont,p,12)
    for _,entry in ipairs(self.fontObjects) do UI.ApplyFont(entry.object,p,entry.size) end
    local path,size,flags=self.menuFont:GetFont()
    -- Model-driven island layout must not rebuild open native menus. Rebuild
    -- for controls/list changes or an actual change in the shared menu font.
    if regenerate or path~=oldPath or size~=oldSize or flags~=oldFlags then
        for _,d in ipairs(self.dropdowns) do d:GenerateMenu() end
    end
    for _,entry in ipairs(self.fontObjects) do fitBounded(entry.object) end
end

function O:RefreshControls()
    if not self.frame then return end
    self.refreshing=true;self.confirmCopy=nil
    local p=self.owner.profile
    self.frame:SetScale(math.max(.3,math.min(1,(UIParent:GetWidth()-24)/620,(UIParent:GetHeight()-24)/462)))
    self.fontSize:SetText(tostring(p.fontSize));self.scale:SetValue(p.scale*100);self.scaleEdit:SetText(tostring(math.floor(p.scale*100+.5)))
    for _,b in ipairs(self.checks) do b.text:SetText(b.caption);b:SetChecked(p[b.key]) end
    for key,slider in pairs(self.durationSliders) do
        slider:SetValue(p[key]);slider.valueText:SetText(p[key].." s")
        slider:SetEnabled(p[slider.toggle])
        slider:SetAlpha(p[slider.toggle] and 1 or .35)
        slider.valueText:SetAlpha(p[slider.toggle] and 1 or .35)
    end
    self.normal.swatch:SetColorTexture(unpack(p.normal));self.rested.swatch:SetColorTexture(unpack(p.rested))
    self.binding.text:SetText("Key binding: "..(GetBindingKey("XPISLAND_TOGGLE") or "unassigned"))
    self.copyButton.text:SetText("Copy settings");self.status:SetText(self.owner.integrationMessage or "")
    self:RefreshFonts(true)
    self.refreshing=nil
end

function O:Toggle(owner)
    if not self.frame then self:Create(owner) end
    self.frame:SetShown(not self.frame:IsShown())
end
