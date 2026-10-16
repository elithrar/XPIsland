local addon, ns = ...
local M, UI, Options, P = ns.Model, ns.UI, ns.Options, ns.Progression
local X = {version="0.6.5", formats={}}
ns.owner=X
local interface=select(4,GetBuildInfo())
if not M.Number(interface) or interface < 16000 or interface >= 20000 then return end
XPIsland=X
BINDING_HEADER_XPISLAND="XPIsland"
BINDING_NAME_XPISLAND_TOGGLE="Expand / collapse XPIsland"

local events=CreateFrame("Frame")
local function safe(v)
    return not (issecretvalue and issecretvalue(v))
end
local RESTED_TREE, RESTED_NODE, LEGACY_FACTION = 1188, 110301, 2802

function X:ReadRestedRank()
    local previousConfig,previousRank=self.restedTraitConfig,self.restedTraitRank
    self.restedTraitConfig,self.restedTraitRank=nil,nil
    if not C_Traits or not C_Traits.GetConfigIDByTreeID or not C_Traits.GetNodeInfo
        or not C_Traits.ConfigHasStagedChanges then return end
    local config=C_Traits.GetConfigIDByTreeID(RESTED_TREE)
    if not safe(config) then return end
    if config==nil then
        -- Nil config alone is not zero ranks. Blizzard gates Legacy on this
        -- faction's renown; require consistent, readable locked-system data.
        if not C_MajorFactions or not C_MajorFactions.GetMajorFactionData
            or not C_MajorFactions.GetCurrentRenownLevel then return end
        local info=C_MajorFactions.GetMajorFactionData(LEGACY_FACTION)
        local renown=C_MajorFactions.GetCurrentRenownLevel(LEGACY_FACTION)
        if safe(info) and type(info)=="table" and safe(info.isUnlocked) and info.isUnlocked==false
            and M.Number(info.renownLevel) and info.renownLevel==0 and M.Number(renown) and renown==0 then return 0 end
        return
    end
    if not M.Number(config) or config<=0 or config~=math.floor(config) then return end
    local staged=C_Traits.ConfigHasStagedChanges(config)
    if not safe(staged) or type(staged)~="boolean" then return end
    -- A preview must not change capacity. Retain only this config's last
    -- confirmed rank; a first read during staged edits remains unavailable.
    if staged then
        if previousConfig==config then
            self.restedTraitConfig,self.restedTraitRank=config,previousRank
            return previousRank
        end
        return
    end
    local node=C_Traits.GetNodeInfo(config,RESTED_NODE)
    if not safe(node) or type(node)~="table" then return end
    local rank=node.activeRank
    if not M.Number(rank) or rank<0 or rank>M.restedCapacity.maxRank or rank~=math.floor(rank) then return end
    self.restedTraitConfig,self.restedTraitRank=config,rank
    return rank
end
local function context()
    local inside,kind=IsInInstance()
    if not safe(inside) or not safe(kind) then return "unknown" end
    return inside and kind or "none"
end
local function say(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffb38aefXPIsland:|r "..message)
end

-- Forever's experience eligibility, with guards before consuming API results.
-- nil means unavailable, distinct from both capped and still leveling.
function X:IsCapped()
    local capped=self:AtLevelCap()
    if capped==nil or capped then return capped end
    local disabled=IsXPUserDisabled()
    if not safe(disabled) or type(disabled)~="boolean" then return end
    if disabled then return true end
    local rule=Enum and Enum.GameRule and Enum.GameRule.ExperienceBarDisabled
    if not M.Number(rule) or not C_GameRules or not C_GameRules.IsGameRuleActive then return end
    disabled=C_GameRules.IsGameRuleActive(rule)
    if safe(disabled) and type(disabled)=="boolean" then return disabled end
end

function X:AtLevelCap()
    local level=UnitLevel("player")
    local maximum,expansion=GetMaxPlayerLevel(),GetMaxLevelForPlayerExpansion()
    if not M.Number(level) or level<1 or not M.Number(maximum) or maximum<1
        or not M.Number(expansion) or expansion<1 then return end
    return level>=math.min(maximum,expansion)
end

function X:Mode()
    return (self.profile.mode=="pvp" or (self.profile.pvpAtCap and self:AtLevelCap())) and "pvp" or "xp"
end

function X:CanShow()
    return self:Mode()=="pvp" or (self:IsCapped()==false and self.tracker and M.Number(self.tracker.cap) and self.tracker.cap>0)
end

function X:RefreshMode()
    local mode=self:Mode()
    if self.displayMode==mode then return end
    self.displayMode=mode
    if not UI.frame then return end
    Options:CloseIndicatorMenu()
    self:CancelAutoCollapse();self:ClearLevelNotice();self.levelWindow=nil
    UI:CancelStatTooltip();UI:ClearHighlights();UI:StopAnimation()
    GameTooltip:Hide()
    UI.expanded=false;UI.progress=0
    UI:Layout()
end

function X:CancelAutoCollapse(keepDelay)
    if self.autoCollapse then self.autoCollapse:Cancel();self.autoCollapse=nil end
    if not keepDelay then self.collapseDelay=nil;self.collapseKind=nil end
end

function X:IsInteracting()
    return UI.dragging or Options.indicatorMenu or (UI.frame and UI.frame:IsMouseOver())
        or (UI.indicator and UI.indicator:IsMouseOver()) or (Options.frame and Options.frame:IsShown())
end

-- One owned timer. Pointer events react immediately; the existing one-second
-- clock also reconciles crossing child frames and geometry moving under a cursor.
function X:InteractionChanged()
    if not self.collapseDelay then return end
    if not UI.expanded or not UI.frame:IsShown() then self:CancelAutoCollapse();return end
    if self:IsInteracting() then self:CancelAutoCollapse(true);return end
    if self.autoCollapse then return end
    local timer
    timer=C_Timer.NewTimer(self.collapseDelay,function()
        if self.autoCollapse~=timer then return end
        self.autoCollapse=nil
        if self:IsInteracting() then return end
        self.collapseDelay=nil;self.collapseKind=nil
        UI:SetExpanded(false)
    end)
    self.autoCollapse=timer
end

function X:ArmCollapse(delay,kind)
    self:CancelAutoCollapse()
    self.collapseDelay=delay;self.collapseKind=kind or "manual"
    self:InteractionChanged()
end

function X:Toggle()
    if not self.session then return end
    self:CancelAutoCollapse()
    if not self:CanShow() then say("XP unavailable, capped or disabled. Select Honor & PvP in Tracking settings.");return end
    if not UI.expanded then self.db.expandedOnce=true end
    UI:SetExpanded(not UI.expanded)
    if UI.expanded and self.profile.autoCollapse then self:ArmCollapse(self.profile.autoCollapseDuration) end
end

function X:ClearLevelNotice()
    if self.levelNoticeTimer then self.levelNoticeTimer:Cancel();self.levelNoticeTimer=nil end
    self.levelNotice=nil
end

-- Presentation watermark is separate from sampled XP and server played-time anchors.
function X:ObserveLevel(level)
    if not M.Number(level) or level<1 or level~=math.floor(level) then return false end
    if self.lastLevelEvent and level<=self.lastLevelEvent then return false end
    self.lastLevelEvent=level
    ns.Played:Invalidate();ns.Played:Sync()
    return true
end

function X:ObserveLevelSample(level)
    if not self.lastLevelEvent then self.lastLevelEvent=level end
    if self.playedSampleLevel and self.playedSampleLevel~=level then
        ns.Played:Invalidate();ns.Played:Sync()
    end
    self.playedSampleLevel=level
end

function X:PlayedLevelComplete(level,duration)
    if not self.levelWindow or self.levelWindow.level~=level+1 or GetTime()>=self.levelWindow.untilTime
        or not UI.expanded or not UI.frame:IsShown() or not self.profile.levelUp or self:IsCapped()~=false or self:Mode()~="xp"
        or (self.profile.collapseCombat and InCombatLockdown()) then return end
    self:ShowLevelDuration(level,duration,self.profile.levelUpDuration)
    self:ArmCollapse(self.profile.levelUpDuration,"level")
end

function X:ShowLevelDuration(level,duration,delay)
    self:ClearLevelNotice()
    if not M.Number(duration) or duration<=0 then return end
    local notice={seconds=duration,level=level,startedAt=GetTime()}
    self.levelNotice=notice
    self:ScheduleLevelNotice(delay or self.profile.levelUpDuration)
    UI:Update()
end

function X:ScheduleLevelNotice(delay)
    if self.levelNoticeTimer then self.levelNoticeTimer:Cancel();self.levelNoticeTimer=nil end
    local notice=self.levelNotice
    if not notice then return end
    local remaining=notice.startedAt+delay-GetTime()
    if remaining<=0 then self.levelNotice=nil;return end
    local timer
    timer=C_Timer.NewTimer(remaining,function()
        if self.levelNotice~=notice or self.levelNoticeTimer~=timer then return end
        self.levelNoticeTimer=nil;self.levelNotice=nil
        UI:Update()
    end)
    self.levelNoticeTimer=timer
end

function X:LevelUp()
    self:ClearLevelNotice()
    if not self.profile.levelUp or self:IsCapped()~=false or self:Mode()~="xp" or (self.profile.collapseCombat and InCombatLockdown()) then return end
    self:CancelAutoCollapse()
    UI:SetExpanded(true)
    self.levelWindow={level=self.lastLevelEvent,startedAt=GetTime(),untilTime=GetTime()+self.profile.levelUpDuration}
    self:ArmCollapse(self.profile.levelUpDuration,"level")
    local completed=ns.Played.completed
    if completed and GetTime()-completed.observed<=self.profile.levelUpDuration then self:PlayedLevelComplete(completed.level,completed.seconds) end
end

function X:Clock()
    if not self.session then return end
    local now=GetTime()
    local connected=self.connected
    -- Loading/travel is online play time. Unit APIs may be unavailable there,
    -- so keep the known connection state until the world is readable again.
    if self.inWorld and not self.loading and (not self.transition or self.connected==false) then
        local current=UnitIsConnected("player")
        if safe(current) and type(current)=="boolean" then connected=current end
    end
    if self.online and self.clockAt and self.connected~=false and connected~=false then
        local elapsed=now-self.clockAt
        if elapsed>=0 then
            self.session.seconds=self.session.seconds+elapsed
        end
    end
    if connected==false then
        self.transition=true
    end
    if connected~=self.connected then
        ns.Played:Invalidate()
        if connected then ns.Played:Sync() end
    end
    self.connected=connected
    self.clockAt=now
end

function X:Snapshot(reason)
    if not self.session then return end
    self:Clock()
    local saved=M.Copy(self.session)
    saved.savedAt=GetServerTime();saved.reason=reason
    XPIslandSession=saved
end

function X:Sample(overrideContext)
    if not self.tracker or not self.online or not self.inWorld or self.loading or self.connected==false then return end
    self:Clock()
    self:RefreshMode()
    if self.connected==false then return end
    local level,xp,cap=UnitLevel("player"),UnitXP("player"),UnitXPMax("player")
    local t=self.tracker
    if not M.Number(level) or not M.Number(xp) or not M.Number(cap) then return end
    -- XP and level notifications can precede each other's visible values.
    if self.levelPending and level<self.levelPending and GetTime()-(self.levelPendingAt or 0)<1 then return end
    self.levelPending,self.levelPendingAt=nil,nil
    local capped=self:IsCapped()
    if capped==nil then return end
    if capped and cap==0 and level==t.level then
        if self.transition then P:Refresh() end
        t.pending=nil;self.transition=nil;self.restedPending=nil;self.restedMaximum=nil;UI:Update();return
    end
    local oldLevel,oldXP,oldCap=t.level,t.xp,t.cap
    local wasTransition=self.transition
    local gain,accepted=t:Sample(level,xp,cap,overrideContext or (self.transition and "unknown") or context(),GetTime(),capped)
    if accepted then
        self.transition=nil
        self:ObserveLevelSample(level)
        if wasTransition then P:Refresh() end
    end
    local rested=GetXPExhaustion()
    local readable=safe(rested) and (rested==nil or (M.Number(rested) and rested>=0))
    self.rested=M.Number(rested) and math.max(0,rested) or 0
    local rank=self:ReadRestedRank()
    self.restedMaximum=readable and M.RestedMaximum(cap,rank) or nil
    self.restedPending=not capped and (not readable or rank==nil) or nil
    UI:Update()
    if accepted and oldLevel~=nil then
        if oldLevel~=level or oldCap~=cap or xp<oldXP then UI:ClearHighlights()
        elseif gain and gain>0 and not wasTransition then UI:HighlightSegments(oldXP,xp,cap) end
    end
end

function X:DeferSample()
    if not self.online or not self.inWorld or self.loading or self.connected==false then return end
    local location=self.transition and "unknown" or context()
    if self.samplePending then
        if self.sampleContext~=location then self.sampleContext="unknown" end
        return
    end
    self.sampleContext=location
    self.samplePending=true
    C_Timer.After(0,function()
        self.samplePending=nil
        if self.online then self:Sample(self.sampleContext) end
        self.sampleContext=nil
    end)
end

-- Hide the stock manager through frame APIs; never replace Blizzard's selector
-- or unregister its events. Native selection stays current while it is hidden.
function X:Integration()
    if not self.watchingEditMode and EventRegistry then
        self.watchingEditMode=true
        local function changed()
            if self.integrationPending then return end
            self.integrationPending=true
            C_Timer.After(0,function()
                self.integrationPending=nil
                self:Integration();Options:Refresh()
            end)
        end
        EventRegistry:RegisterCallback("EditMode.Enter",changed,self)
        EventRegistry:RegisterCallback("EditMode.Exit",changed,self)
    end
    self.integrationMessage=nil
    local manager=StatusTrackingBarManager
    if not manager then
        if self.profile.hideBlizzard then self.integrationMessage="Blizzard tracking bars unavailable." end
        return
    end
    local lite=EllesmereUI and EllesmereUI.Lite
    local eab=lite and lite.GetAddon and lite.GetAddon("EllesmereUIActionBars",true)
    local euiOwns=eab and eab.db and eab.db.profile and eab.db.profile.useBlizzardDataBars == false
    local editing=EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    if not safe(editing) then return end
    local wanted=self.profile.hideBlizzard and not euiOwns and not editing
    if InCombatLockdown() then
        if wanted or self.hiddenStockManager then self.integrationMessage="Blizzard tracking bar visibility updates after combat." end
        return
    end
    if euiOwns then
        -- Ellesmere has taken ownership; don't re-show its suppressed stock UI.
        self.hiddenStockManager=nil
        if self.profile.hideBlizzard then self.integrationMessage="Ellesmere controls tracking bars. Adjust them there." end
        return
    end
    local shown=manager:IsShown()
    if not safe(shown) or type(shown)~="boolean" then return end
    if wanted then
        -- A frame already hidden by someone else is not ours to restore.
        if shown then
            manager:Hide()
            self.hiddenStockManager=manager
        end
    elseif self.hiddenStockManager then
        if self.hiddenStockManager==manager and not shown then manager:Show() end
        self.hiddenStockManager=nil
    end
end

-- Every appearance entry point refreshes both sets of owned text. A late
-- per-object rejection can downgrade selected -> default -> inherited native;
-- replay after each downgrade to remeasure all earlier objects consistently.
function X:RefreshAppearance(retryFonts,preserveMotion,refreshControls)
    if self.refreshingAppearance then return end
    self.refreshingAppearance=true
    if retryFonts then UI.ResetFonts() end
    for _=1,3 do
        local revision=UI.fontRevision
        UI:LayoutContents(preserveMotion)
        if refreshControls then Options:RefreshControls() else Options:RefreshFonts() end
        if revision==UI.fontRevision then break end
    end
    self.refreshingAppearance=nil
end

function X:ApplyProfile()
    Options:CloseIndicatorMenu()
    self:RefreshMode()
    local kind=self.collapseKind
    self:CancelAutoCollapse()
    if not self.profile.levelUp then
        self.levelWindow=nil;self:ClearLevelNotice()
    else
        if self.levelWindow then self.levelWindow.untilTime=self.levelWindow.startedAt+self.profile.levelUpDuration end
        self:ScheduleLevelNotice(self.profile.levelUpDuration)
    end
    self:Integration();self:RefreshAppearance(true,false,true)
    if UI.expanded then
        if kind=="level" and self.profile.levelUp then self:ArmCollapse(self.profile.levelUpDuration,"level")
        elseif self.profile.autoCollapse then self:ArmCollapse(self.profile.autoCollapseDuration) end
    end
end

function X:WatchFonts()
    local lsm=LibStub and LibStub("LibSharedMedia-3.0",true)
    if not lsm or self.fontLibrary==lsm or not lsm.RegisterCallback then return end
    self.fontLibrary=lsm
    self.fontChanged=self.fontChanged or function(_,kind)
        if kind~="font" or not self.profile then return end
        self:RefreshAppearance(true,true,true)
    end
    lsm.RegisterCallback(self,"LibSharedMedia_Registered",self.fontChanged)
    lsm.RegisterCallback(self,"LibSharedMedia_SetGlobal",self.fontChanged)
    -- The library itself may have arrived after our initial fallback.
    self.fontChanged(nil,"font")
end

function X:Initialize(reloading)
    local db,err=M.Database(XPIslandDB)
    if not db then say(err);return end
    XPIslandDB=db;self.db=db
    local character=UnitGUID("player")
    if not safe(character) or type(character)~="string" then return end
    self.character=character
    local name,realm=UnitName("player"),GetRealmName()
    if not safe(name) or type(name)~="string" then name="Character" end
    if not safe(realm) or type(realm)~="string" then realm="Unknown realm" end
    self.characterName=name.." - "..realm
    self.profileName=db.characters[self.character]
    if not db.profiles[self.profileName] then self.profileName="Shared" end
    self.profile=M.SelectProfile(db,self.character,self.profileName)
    self.session,self.resumed=M.Resume(XPIslandSession,self.character,GetServerTime(),reloading)
    self.tracker=M.NewTracker(self.session)
    self.inWorld=true;self.online=true;self.connected=true;self.clockAt=GetTime();self.transition=true
    -- Never use a stale reload checkpoint as proof of a later crash's departure.
    XPIslandSession=M.Copy(self.session)
    for name,value in pairs(_G) do
        if type(name)=="string" and name:match("^COMBATLOG_XPGAIN")
            and (name:find("FIRSTPERSON",1,true) or name:find("EXHAUSTION",1,true))
            and not name:find("UNNAMED",1,true) and safe(value) then
            local f=M.CompileXPFormat(value)
            if f then self.formats[#self.formats+1]=f end
        end
    end
    ns.Played:Initialize(self,XPIslandPlayed)
    P:Refresh();self:RefreshMode()
    UI:Create(self);self:Sample();self:Integration()
    self:WatchFonts()
    self.ticker=C_Timer.NewTicker(1,function()
        self:Clock();self.tracker:Expire(GetTime())
        if self.online and (self.transition or self.tracker.pending or self.levelPending or self.restedPending) then self:Sample() end
        ns.Played:Pump()
        local changed=P:Pump()
        self:RefreshMode()
        self:InteractionChanged()
        if changed or UI.expanded or self.profile.format=="eta" or self.profile.format=="kills" then UI:Update() end
    end)
end

events:SetScript("OnEvent",function(_,event,...)
    if event=="ADDON_LOADED" then
        if ...==addon then
            events:RegisterEvent("PLAYER_ENTERING_WORLD")
        elseif X.session then X:Integration();X:WatchFonts() end
        return
    end
    if event=="LOADING_SCREEN_ENABLED" or event=="PLAYER_LEAVING_WORLD" then
        if event=="LOADING_SCREEN_ENABLED" then X.loading=true else X.inWorld=false end
        X:Clock();X.transition=true
        if X.session then ns.Played:Invalidate() end
        if UI.frame then UI:ClearHighlights() end
        P.pet=nil -- never show the previous pet identity while unit data unloads
        if X.tracker then X.tracker.pending=nil;X.tracker.awards={};X.tracker.hints={} end
        -- Do not sample here: unit values can already be unloading/reset.
        return
    elseif event=="LOADING_SCREEN_DISABLED" then
        X:Clock();X.loading=false
        if X.session and X.inWorld then X:DeferSample() end
        return
    end
    if event=="PLAYER_ENTERING_WORLD" then
        local initial,reloading=...
        if not X.session then X:Initialize(reloading)
        else
            X:Clock();X.inWorld=true;X.online=true;X.transition=true
            -- Wait through loading and coalesce entry-frame XP notifications.
            -- Any observed transition gain has no reliable source location.
            X:DeferSample();X:Integration()
        end
        P:Refresh();UI:Layout(true)
        return
    end
    if not X.session then return end
    if event=="UNIT_PET" or event=="UNIT_PET_EXPERIENCE" or event=="UNIT_LEVEL" then
        local unit=...
        -- Blizzard's pet XP bar treats this event as a refresh signal regardless of payload.
        if event=="UNIT_PET_EXPERIENCE" or (safe(unit) and
            ((event=="UNIT_LEVEL" and unit=="pet") or (event=="UNIT_PET" and unit=="player"))) then
            local previous=P.pet and P.pet.guid
            P:Pet()
            if previous~=(P.pet and P.pet.guid) then UI:CancelStatTooltip(UI.inlineCells[1]) end
            UI:Update()
        end
    elseif event=="UPDATE_FACTION" or event=="MAJOR_FACTION_RENOWN_LEVEL_CHANGED" or event=="CURRENCY_DISPLAY_UPDATE" then
        P:PvP();UI:Update()
        if event=="MAJOR_FACTION_RENOWN_LEVEL_CHANGED" then
            local faction=...
            if M.Number(faction) and faction==LEGACY_FACTION then X:DeferSample() end
        end
    elseif event=="UNIT_CONNECTION" then
        local unit,connected=...
        if safe(unit) and unit=="player" and safe(connected) and type(connected)=="boolean" then
            X:Clock()
            if X.connected~=connected then
                ns.Played:Invalidate()
                if connected then ns.Played:Sync() end
            end
            X.connected=connected;X.clockAt=GetTime()
            if connected then X:DeferSample() else X.transition=true end
        end
    elseif event=="TIME_PLAYED_MSG" then ns.Played:Response(...)
    elseif event=="PLAYER_XP_UPDATE" then
        local unit=...
        if safe(unit) and unit=="player" then X:DeferSample() end
    elseif event=="TRAIT_CONFIG_UPDATED" or event=="TRAIT_CONFIG_CREATED" or event=="TRAIT_CONFIG_LIST_UPDATED"
        or event=="MAJOR_FACTION_UNLOCKED" then X:DeferSample()
    elseif event=="TRAIT_NODE_CHANGED" or event=="TRAIT_NODE_CHANGED_PARTIAL" then
        local node=...
        if M.Number(node) and node==RESTED_NODE then X:DeferSample() end
    elseif event=="PLAYER_LEVEL_UP" then
        local level=...
        local changed=X:ObserveLevel(level)
        if M.Number(level) and level>(X.tracker.level or 0) and X.levelPending~=level then
            X.levelPending=level;X.levelPendingAt=GetTime()
        end
        X:DeferSample()
        if changed then UI:ClearHighlights();X:LevelUp() end
    elseif event=="QUEST_TURNED_IN" then
        if not X.online or not X.inWorld or X.loading or X.connected==false then return end
        local id,amount=...
        local key=safe(id) and M.Number(amount) and ("quest:"..tostring(id)..":"..tostring(amount)..":"..GetTime()) or nil
        X.tracker:Hint("quests",amount,context(),GetTime(),key)
        X:DeferSample()
    elseif event=="CHAT_MSG_COMBAT_XP_GAIN" then
        if not X.online or not X.inWorld or X.loading or X.connected==false then return end
        X:Clock() -- timestamp the original hint on the online clock, not the later reconciliation
        local text=...
        local lineID=select(11,...)
        local amount=M.ParseXP(text,X.formats)
        local id=M.Number(lineID) and lineID>0 and "chat:"..lineID or nil
        X.tracker:Hint("kills",amount,context(),GetTime(),id)
        X:DeferSample()
    elseif event=="PLAYER_LOGOUT" then
        X:Snapshot(X.reloadIntent and "reload" or X.cleanIntent and "clean" or "departed")
        X.online=false
    elseif event=="PLAYER_CAMPING" or event=="PLAYER_QUITING" then X.cleanIntent=true
    elseif event=="LOGOUT_CANCEL" then X.cleanIntent=nil
    elseif event=="PLAYER_REGEN_DISABLED" then
        Options:CloseIndicatorMenu()
        if X.profile.collapseCombat then X:CancelAutoCollapse();UI:SetExpanded(false) end
    elseif event=="PLAYER_REGEN_ENABLED" then X:Integration();Options:Refresh()
    elseif event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" or event=="NOTCHED_DISPLAY_MODE_CHANGED" then
        C_Timer.After(0,function() X:RefreshAppearance(false,false,true) end)
    elseif event=="UPDATE_BINDINGS" then Options:Refresh()
    else X:Sample() end
end)

for _,event in ipairs({"ADDON_LOADED","TIME_PLAYED_MSG","UNIT_CONNECTION","PLAYER_XP_UPDATE","PLAYER_LEVEL_UP","UPDATE_EXHAUSTION","QUEST_TURNED_IN",
    "UNIT_PET","UNIT_PET_EXPERIENCE","UNIT_LEVEL","UPDATE_FACTION","MAJOR_FACTION_RENOWN_LEVEL_CHANGED","CURRENCY_DISPLAY_UPDATE",
    "CHAT_MSG_COMBAT_XP_GAIN","LOADING_SCREEN_ENABLED","LOADING_SCREEN_DISABLED","PLAYER_LEAVING_WORLD","PLAYER_LOGOUT","PLAYER_CAMPING","PLAYER_QUITING","LOGOUT_CANCEL",
    "PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED","NOTCHED_DISPLAY_MODE_CHANGED","UPDATE_BINDINGS",
    "PLAYER_MAX_LEVEL_UPDATE","ENABLE_XP_GAIN","DISABLE_XP_GAIN","TRAIT_CONFIG_UPDATED","TRAIT_CONFIG_CREATED","TRAIT_CONFIG_LIST_UPDATED",
    "TRAIT_NODE_CHANGED","TRAIT_NODE_CHANGED_PARTIAL","MAJOR_FACTION_UNLOCKED"}) do events:RegisterEvent(event) end

hooksecurefunc("Logout",function() X.cleanIntent=true end)
hooksecurefunc("Quit",function() X.cleanIntent=true end)
hooksecurefunc("CancelLogout",function() X.cleanIntent=nil end)
hooksecurefunc("ReloadUI",function() X.reloadIntent=true end)
if C_UI and C_UI.Reload then hooksecurefunc(C_UI,"Reload",function() X.reloadIntent=true end) end

SLASH_XPISLAND1="/xpisland"
SlashCmdList.XPISLAND=function(message)
    if not X.session then say("Waiting for your character to enter the world.");return end
    if message:lower():match("^%s*reset%s*$") then
        X:Clock()
        UI:ClearHighlights()
        X.session=M.NewSession(X.character,GetServerTime())
        X.tracker=M.NewTracker(X.session);X.clockAt=GetTime();X:Sample()
        say("Session reset.")
    else Options:Toggle(X) end
end
