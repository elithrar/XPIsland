local _, ns = ...
local M, UI = ns.Model, ns.UI
local O = {}
ns.Options = O

local function button(parent, text, x, y, width, callback)
    local b = CreateFrame("Button",nil,parent)
    b:SetPoint("TOPLEFT",x,y); b:SetSize(width or 240,28)
    local bg=UI.Solid(b,"BACKGROUND",.13,.14,.18); bg:SetAllPoints()
    b.text=UI.Text(b,12); b.text:SetPoint("LEFT",10,0); b.text:SetWidth((width or 240)-20); b.text:SetText(text)
    O.fontObjects[#O.fontObjects+1]={object=b.text,size=12}
    b:SetScript("OnEnter",function() bg:SetColorTexture(.21,.18,.29,1) end)
    b:SetScript("OnLeave",function() bg:SetColorTexture(.13,.14,.18,1) end)
    b:SetScript("OnClick",callback)
    return b
end

local function label(parent,text,x,y,size)
    local t=UI.Text(parent,size or 11,.65,.67,.73)
    t:SetPoint("TOPLEFT",x,y); t:SetText(text)
    O.fontObjects[#O.fontObjects+1]={object=t,size=size or 11}
    return t
end

local function edit(parent,x,y,width)
    local e=CreateFrame("EditBox",nil,parent)
    e:SetPoint("TOPLEFT",x,y); e:SetSize(width,28)
    local bg=UI.Solid(e,"BACKGROUND",.10,.11,.15);bg:SetAllPoints()
    e:SetFont("Fonts\\ARIALN.TTF",12,""); e:SetTextInsets(8,8,0,0)
    e:SetAutoFocus(false);e:SetMaxLetters(48)
    O.fontObjects[#O.fontObjects+1]={object=e,size=12}
    e:SetScript("OnEscapePressed",function(self) self:ClearFocus(); O:Refresh() end)
    return e
end

function O:CloseMenu()
    if self.menu then self.menu:Hide() end
end

function O:Dropdown(anchor, entries, selected)
    self:CloseMenu()
    if not self.menu then
        local menu=CreateFrame("Frame",nil,self.frame,"BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG");menu:EnableMouse(true);menu:EnableMouseWheel(true)
        menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        menu:SetBackdropColor(.07,.08,.11,1);menu:SetBackdropBorderColor(.3,.25,.4,1)
        menu.rows={}
        for i=1,10 do
            local row=button(menu,"",4,-4-(i-1)*26,232,function()
                local item=self.menu.entries[self.menu.offset+i]
                self:CloseMenu();if item then selected(item) end
            end)
            row:SetHeight(25);menu.rows[i]=row
        end
        menu:SetScript("OnMouseWheel",function(_,delta)
            menu.offset=math.max(0,math.min(math.max(0,#menu.entries-10),menu.offset-delta));self:MenuRows()
        end)
        self.menu=menu
    end
    self.menu.entries,self.menu.offset,self.menu.choose=entries,0,selected
    for i,row in ipairs(self.menu.rows) do
        row:SetScript("OnClick",function()
            local entry=self.menu.entries[self.menu.offset+i]
            local choose=self.menu.choose
            self:CloseMenu();if entry then choose(entry) end
        end)
    end
    self.menu:ClearAllPoints();self.menu:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-2)
    self.menu:SetClampedToScreen(true)
    self.menu:SetSize(240,math.min(10,#entries)*26+8)
    self:MenuRows();self.menu:Show()
end

function O:MenuRows()
    for i,row in ipairs(self.menu.rows) do
        local entry=self.menu.entries[self.menu.offset+i]
        row:SetShown(entry~=nil)
        if entry then row.text:SetText(entry.label or entry.value) end
    end
end

function O:Check(parent,text,key,x,y)
    local b=button(parent,"",x,y,280,function()
        self.owner.profile[key]=not self.owner.profile[key]
        self.owner:ApplyProfile();self:Refresh()
    end)
    b.key,b.caption=key,text
    local border=UI.Solid(b,"ARTWORK",.42,.38,.5);border:SetSize(12,12);border:SetPoint("LEFT",10,0)
    local well=UI.Solid(b,"ARTWORK",.07,.08,.11);well:SetSize(10,10);well:SetPoint("CENTER",border,"CENTER")
    b.checkFill=UI.Solid(b,"OVERLAY",.68,.46,.97);b.checkFill:SetSize(6,6);b.checkFill:SetPoint("CENTER",border,"CENTER")
    b.text:ClearAllPoints();b.text:SetPoint("LEFT",32,0);b.text:SetWidth(238)
    self.checks[#self.checks+1]=b
    return b
end

function O:Color(key,anchor)
    local p=self.owner.profile
    local original=M.Copy(p[key])
    ColorPickerFrame:SetupColorPickerAndShow({r=original[1],g=original[2],b=original[3],hasOpacity=false,
        swatchFunc=function()
            p[key]={ColorPickerFrame:GetColorRGB()};self.owner:ApplyProfile();self:Refresh()
        end,
        cancelFunc=function()
            p[key]=original;self.owner:ApplyProfile();self:Refresh()
        end})
end

function O:Create(owner)
    self.owner=owner;self.checks={};self.fontObjects={}
    local f=CreateFrame("Frame","XPIslandOptions",UIParent)
    self.frame=f
    f:SetSize(644,520);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG")
    f:EnableMouse(true); f:SetClampedToScreen(true);f:SetMovable(true);f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function() f:StartMoving() end)
    f:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
    UI.Round(f,{.21,.21,.26,1},0);UI.Round(f,{.055,.06,.08,1},1)
    local content=CreateFrame("Frame",nil,f);content:SetAllPoints();content:SetFrameLevel(f:GetFrameLevel()+3)
    self.content=content
    label(content,"XPIsland",24,-20,21):SetTextColor(.82,.70,1)
    label(content,"Experience, quietly in view.",24,-48,11)
    button(content,"×",596,-18,28,function() f:Hide() end)
    self.optionsTab=button(content,"Options",24,-77,112,function() self:Page(false) end)
    self.profilesTab=button(content,"Profiles",144,-77,112,function() self:Page(true) end)
    self.options=CreateFrame("Frame",nil,content);self.options:SetAllPoints()
    self.profiles=CreateFrame("Frame",nil,content);self.profiles:SetAllPoints()
    local page=self.options
    label(page,"DISPLAY",24,-124)
    self.format=button(page,"",24,-146,280,function(b)
        self:Dropdown(b,{{value="percent",label="Percentage"},{value="fraction",label="X / Y"},{value="left",label="X left"},{value="leftPercent",label="X left (remaining %)"}},function(e)
            owner.profile.format=e.value;owner:ApplyProfile();self:Refresh()
        end)
    end)
    label(page,"Typeface",24,-188)
    self.font=button(page,"",24,-207,280,function(b)
        local names={Arial=true,["Friz Quadrata"]=true}
        local lsm=LibStub and LibStub("LibSharedMedia-3.0",true)
        if lsm then for name in pairs(lsm:HashTable("font")) do names[name]=true end end
        local list={};for name in pairs(names) do list[#list+1]={value=name} end
        table.sort(list,function(a,b) return a.value<b.value end)
        self:Dropdown(b,list,function(e) owner.profile.font=e.value;owner:ApplyProfile();self:Refresh() end)
    end)
    label(page,"Font size",24,-249)
    self.fontSize=edit(page,238,-241,66)
    self.fontSize:SetScript("OnEnterPressed",function(e)
        owner.profile.fontSize=math.floor(math.max(10,math.min(18,tonumber(e:GetText()) or owner.profile.fontSize)))
        e:ClearFocus();owner:ApplyProfile();self:Refresh()
    end)
    label(page,"Island scale",24,-293)
    local slider=CreateFrame("Slider",nil,page)
    self.scale=slider;slider:SetPoint("TOPLEFT",24,-321);slider:SetSize(192,16)
    slider:SetOrientation("HORIZONTAL");slider:SetMinMaxValues(50,150);slider:SetValueStep(1);slider:SetObeyStepOnDrag(true)
    local track=UI.Solid(slider,"BACKGROUND",.22,.20,.29);track:SetPoint("LEFT");track:SetPoint("RIGHT");track:SetHeight(3)
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8");slider:GetThumbTexture():SetSize(10,16);slider:GetThumbTexture():SetVertexColor(.7,.5,1)
    self.scaleEdit=edit(page,238,-313,66)
    slider:SetScript("OnValueChanged",function(_,value)
        if self.refreshing then return end
        owner.profile.scale=math.floor(value+.5)/100
        self.scaleEdit:SetText(tostring(math.floor(value+.5)));owner:ApplyProfile()
    end)
    self.scaleEdit:SetScript("OnEnterPressed",function(e)
        owner.profile.scale=math.max(50,math.min(150,math.floor((tonumber(e:GetText()) or owner.profile.scale*100)+.5)))/100
        e:ClearFocus();owner:ApplyProfile();self:Refresh()
    end)
    label(page,"50–150% · width is capped on large screens",24,-352,10)
    self.normal=button(page,"Normal XP",24,-382,132,function(b) self:Color("normal",b) end)
    self.rested=button(page,"Rested XP",172,-382,132,function(b) self:Color("rested",b) end)
    label(page,"BEHAVIOR",340,-124)
    self:Check(page,"Lock position","locked",340,-146)
    self:Check(page,"Expand on level-up (10 seconds)","levelUp",340,-184)
    self:Check(page,"Hide Blizzard XP bar","hideBlizzard",340,-222)
    local hint=label(page,"Affects Blizzard XP only. Reputation and other addons keep their own controls.",340,-260,10)
    hint:SetWidth(280);hint:SetWordWrap(true)
    self.binding=button(page,"",340,-309,280,function()
        Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID,"XPIsland")
    end)
    button(page,"Reset position",340,-347,280,function()
        owner.profile.position={x=0,y=-8};owner:ApplyProfile()
    end)
    button(page,"Toggle island",340,-385,280,function() owner:Toggle() end)
    self.status=label(content,"",24,-453,11);self.status:SetWidth(596);self.status:SetWordWrap(true)
    page=self.profiles
    label(page,"ACTIVE PROFILE",24,-126)
    self.active=button(page,"",24,-148,280,function(b)
        self:Dropdown(b,self:ProfileEntries(),function(e) self:Switch(e.value) end)
    end)
    local info=label(page,"Shared profiles update every character using them. A character profile is an independent copy. Session statistics never travel with a profile.",340,-126,12)
    info:SetWidth(280);info:SetWordWrap(true)
    button(page,"Use Shared",24,-190,132,function() self:Switch("Shared") end)
    button(page,"Per-character",172,-190,132,function()
        local name=owner.characterName
        if not owner.db.profiles[name] then owner.db.profiles[name]=M.Copy(owner.profile) end
        self:Switch(name)
    end)
    label(page,"Duplicate active profile as",24,-249)
    self.name=edit(page,24,-271,280)
    button(page,"Duplicate & switch",340,-271,280,function()
        local name,err=M.Duplicate(owner.db,owner.profileName,self.name:GetText())
        if name then self:Switch(name);self.name:SetText("") else self.status:SetText(err) end
    end)
    label(page,"Copy settings into the active profile",24,-326)
    self.copy=button(page,"Choose source…",24,-348,280,function(b)
        self:Dropdown(b,self:ProfileEntries(),function(e)
            self.copySource=e.value;self.copy.text:SetText(e.value)
            self.confirmCopy=nil;self.copyButton.text:SetText("Copy settings")
        end)
    end)
    self.copyButton=button(page,"Copy settings",340,-348,280,function()
        if not self.copySource then self.status:SetText("Choose a source profile first.");return end
        if not self.confirmCopy then
            self.confirmCopy=true;self.copyButton.text:SetText("Confirm overwrite");return
        end
        owner.db.profiles[owner.profileName]=M.Copy(owner.db.profiles[self.copySource])
        owner.profile=owner.db.profiles[owner.profileName]
        self.confirmCopy=nil;owner:ApplyProfile();self:Refresh()
    end)
    f:SetScript("OnHide",function() self:CloseMenu();self.confirmCopy=nil end)
    f:SetScript("OnShow",function() self:Refresh() end)
    UISpecialFrames[#UISpecialFrames+1]="XPIslandOptions"
    self:Page(false);f:Hide()
end

function O:ProfileEntries()
    local entries={}
    for name in pairs(self.owner.db.profiles) do entries[#entries+1]={value=name} end
    table.sort(entries,function(a,b) return a.value<b.value end)
    return entries
end

function O:Switch(name)
    local owner=self.owner
    owner.profile=M.SelectProfile(owner.db,owner.character,name)
    owner.profileName=name;self.confirmCopy=nil
    owner:ApplyProfile();self:Refresh()
end

function O:Page(profiles)
    self:CloseMenu();self.confirmCopy=nil
    self.profiles:SetShown(profiles);self.options:SetShown(not profiles)
    self.optionsTab.text:SetTextColor(profiles and .65 or .82,profiles and .67 or .70,profiles and .73 or 1)
    self.profilesTab.text:SetTextColor(profiles and .82 or .65,profiles and .70 or .67,profiles and 1 or .73)
    self:Refresh()
end

function O:Refresh()
    if not self.frame then return end
    self.refreshing=true
    self.confirmCopy=nil
    local p=self.owner.profile
    self.format.text:SetText(({percent="Percentage",fraction="X / Y",left="X left",leftPercent="X left (remaining %)"})[p.format])
    self.font.text:SetText(p.font);self.fontSize:SetText(tostring(p.fontSize))
    self.scale:SetValue(p.scale*100);self.scaleEdit:SetText(tostring(math.floor(p.scale*100+.5)))
    for _,b in ipairs(self.checks) do b.text:SetText(b.caption);b.checkFill:SetShown(p[b.key]) end
    for _,entry in ipairs(self.fontObjects) do entry.object:SetFont(UI.Font(p),entry.size,"") end
    self.normal.text:SetTextColor(unpack(p.normal));self.rested.text:SetTextColor(unpack(p.rested))
    self.binding.text:SetText("Keybind: "..(GetBindingKey("XPISLAND_TOGGLE") or "unassigned").."  ›")
    self.active.text:SetText(self.owner.profileName)
    self.copyButton.text:SetText("Copy settings")
    self.status:SetText(self.owner.integrationMessage or "Forever only · five-minute reconnect grace · /reload preserves sessions")
    local availableScale=math.min(1,(UIParent:GetWidth()-24)/644,(UIParent:GetHeight()-24)/520)
    self.frame:SetScale(math.max(.3,availableScale))
    self.refreshing=nil
end

function O:Toggle(owner)
    if not self.frame then self:Create(owner) end
    self.frame:SetShown(not self.frame:IsShown())
end
