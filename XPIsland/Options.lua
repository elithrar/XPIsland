local _, ns = ...
local UI = ns.UI
local O = {}
ns.Options = O
local xpFormats={
    {value="percent",label="Percentage"},{value="fraction",label="Current / total XP"},
    {value="left",label="XP remaining"},{value="leftPercent",label="XP remaining (%)"},
    {value="eta",label="Time to level"},{value="kills",label="Kills to level"}
}
local pvpFormats={
    {value="honor",label="Honor available"},{value="rankLeft",label="Rank Points to next rank"}
}
local modes={{value="xp",label="Experience"},{value="pvp",label="Honor & PvP"}}

function O:SetMode(value)
    if value~="xp" and value~="pvp" then return end
    self:CloseIndicatorMenu()
    UI.owner:SettingsResult(ns.App:SetMany({mode=value,pvpAtCap=false}))
end

function O:IndicatorFormats(mode)
    if mode=="pvp" then return pvpFormats,"pvpFormat" end
    return xpFormats,"format"
end

function O:SetIndicatorFormat(mode,value)
    local entries,key=self:IndicatorFormats(mode)
    for _,entry in ipairs(entries) do
        if entry.value==value then
            self:CloseIndicatorMenu()
            UI.owner:SettingsResult(ns.App:Set(key,value))
            return
        end
    end
end

function O:CloseIndicatorMenu()
    local context=self.indicatorMenu
    if not context then return end
    self.indicatorMenu=nil
    context.menu:Close()
    UI.owner:InteractionChanged()
end

function O:OpenIndicatorMenu(region)
    local owner=UI.owner
    if InCombatLockdown() or UI.dragging or not region:IsVisible() then return end
    self:CloseIndicatorMenu()
    UI:CancelStatTooltip();GameTooltip:Hide()
    local mode,profile=owner:Mode(),owner.profile
    local entries,key=self:IndicatorFormats(mode)
    -- Native proxy frames are pooled; use per-opening ownership for callbacks.
    local context={}
    local function current()
        return not InCombatLockdown() and self.indicatorMenu==context and not UI.dragging
            and region:IsVisible() and owner.profile==profile and owner:Mode()==mode
    end
    local menu=MenuUtil.CreateContextMenu(region,function(_,root)
        for _,entry in ipairs(modes) do
            root:CreateRadio(entry.label,function(value) return owner:Mode()==value end,function(value)
                if current() then self:SetMode(value) end
            end,entry.value)
        end
        root:CreateDivider()
        for _,entry in ipairs(entries) do
            root:CreateRadio(entry.label,function(value) return profile[key]==value end,function(value)
                -- A queued click must not survive combat, dismissal or a profile/mode change.
                if not current() then return end
                self:SetIndicatorFormat(mode,value)
            end,entry.value)
        end
    end)
    if menu then
        context.menu=menu;self.indicatorMenu=context
        menu:SetClosedCallback(function()
            if self.indicatorMenu~=context then return end
            self.indicatorMenu=nil;owner:InteractionChanged()
        end)
        owner:InteractionChanged()
    end
end

-- The shell, standard controls, profiles, editors and font menus belong to SND.
-- The indicator's native context menu remains tied to the island's mode/lifetime.
function O:Configure(app)
    local function checked(ok,err) return ns.owner:SettingsResult(ok,err) end
    local function choice(key,label,entries) return {type='select',id=key,key=key,label=label,choices=entries} end
    local function check(key,label) return {type='checkbox',id=key,key=key,label=label} end
    local function duration(key,label,toggle)
        return {type='select',id=key,key=key,label=label,choices={{value=5,label='5 seconds'},{value=10,label='10 seconds'},{value=15,label='15 seconds'}},enabled=function(a)return a:Get(toggle)end}
    end
    self.panel=app:Options({title='XPIsland',width=640,height=540,pages={
        {id='appearance',label='Appearance',sections={{title='Appearance',controls={
            choice('theme','Theme',ns.Themes.Choices()),
            {type='font',id='font',key='font',label='Font'},
            {type='number',id='fontSize',key='fontSize',label='Font size (10–18)'},
            {type='slider',id='scale',key='scale',label='Island scale',step=.01,format='percent'},
            {type='color',id='normal',key='normal',label='Normal XP',preview=function(value) UI:PreviewColor('normal',value) end},
            {type='color',id='rested',key='rested',label='Rested XP',preview=function(value) UI:PreviewColor('rested',value) end},
        }}}},
        {id='behavior',label='Behavior',sections={{title='Behavior',controls={
            check('locked','Lock position'),check('levelUp','Expand at level-up'),duration('levelUpDuration','Level-up duration','levelUp'),
            check('autoCollapse','Auto-collapse'),duration('autoCollapseDuration','Auto-collapse duration','autoCollapse'),
            check('collapseCombat','Collapse on combat entry'),check('hideBlizzard','Hide Blizzard tracking bars'),
            {type='custom',id='integrationStatus',create=function(parent,a)
                local text=O.integrationText
                if not text then text=parent:CreateFontString(nil,'OVERLAY');O.integrationText=text end
                checked(a.fonts:Apply(text,'control'));checked(a.ui:Color(text,'muted'))
                text:SetPoint('TOPLEFT');text:SetJustifyH('LEFT');text:SetWordWrap(true)
                return {
                    Refresh=function() text:SetText((ns.owner.integrationMessage or 'Includes XP, reputation and Honor bars.')..'\nKey binding: '..(GetBindingKey('XPISLAND_TOGGLE') or 'unassigned'));text:Show() end,
                    Layout=function(_,width)text:SetWidth(width);return text:GetStringHeight()+8 end,
                    Hide=function()text:Hide()end,
                }
            end},
            {type='description',text='Auto-collapse waits while hovering, dragging or using settings.'},
            {type='button',id='binding',label='Key binding',action=function()Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID,'XPIsland')end},
            choice('placement','Placement',{{value='top',label='Top'},{value='bottom',label='Bottom'},{value='custom',label='Custom (dragged)'}}),
            {type='button',id='resetPosition',label='Reset to top',action=function()checked(app:SetMany({['position.x']=0,['position.y']=-8,placement='top'}))end},
            {type='button',id='expand',label='Expand/collapse',action=function()ns.owner:Toggle()end},
            {type='button',id='shared',label='Use shared profile',action=function()checked(app.profiles:Switch('Shared'))end},
            {type='button',id='character',label='Use character profile',action=function()
                local name=ns.owner.characterName
                if not name then return end
                for _,existing in ipairs(app.profiles:List())do if existing==name then checked(app.profiles:Switch(name));return end end
                checked(app.profiles:Duplicate(name))
            end},
        }}}},
        {id='tracking',label='Tracking',sections={{title='Tracking',controls={
            choice('mode','Track',modes),choice('format','Experience label',xpFormats),choice('pvpFormat','Honor label',pvpFormats),
            check('pvpAtCap','Track Honor at the level cap'),check('showPet','Show pet experience'),check('showRank','Show PvP rank'),check('showKills','Show kills to level'),
            {type='description',text='Estimates use recent confirmed kills. Rested XP and group rewards affect XP per kill. Hover over a stat for details.'},
        }}}},ns.SomethingNeedDoing.Pages.Profiles(),
    }})
end
function O:Refresh() if self.panel then return self.panel:Refresh() end end
function O:Switch(name) return ns.owner:SettingsResult(ns.App.profiles:Switch(name)) end
function O:Page(page) return ns.owner:SettingsResult(self.panel:SelectPage(page==true and 'profiles' or page==false and 'appearance' or page)) end
function O:Toggle(owner)
    self.owner=owner
    local ok,err=self.panel:Toggle();owner:SettingsResult(ok,err);self.frame=self.panel.frame
    if self.frame and not self.frameObserved then
        self.frameObserved=true
        local scope=ns.App:Scope('options-interaction')
        owner:SettingsResult(scope:HookScript(self.frame,'OnHide',function() self:CloseIndicatorMenu();owner:InteractionChanged() end))
        owner:SettingsResult(scope:HookScript(self.frame,'OnShow',function() owner:InteractionChanged() end))
    end
    owner:InteractionChanged()
end
