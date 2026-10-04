local addon, ns = ...
local M, UI, Options = ns.Model, ns.UI, ns.Options
local X = {version="0.2.0", formats={}}
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
local function context()
    local inside,kind=IsInInstance()
    if not safe(inside) or not safe(kind) then return "unknown" end
    return inside and kind or "none"
end
local function say(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffb38aefXPIsland:|r "..message)
end

function X:IsCapped()
    if GameRulesUtil and GameRulesUtil.CanShowExperienceBar then return not GameRulesUtil.CanShowExperienceBar() end
    return IsXPUserDisabled() or UnitLevel("player") >= math.min(GetMaxPlayerLevel(),GetMaxLevelForPlayerExpansion())
end

function X:CancelAutoCollapse()
    if self.autoCollapse then self.autoCollapse:Cancel();self.autoCollapse=nil end
end

function X:Toggle()
    if not self.session then return end
    self:CancelAutoCollapse()
    if self:IsCapped() then say("The island is hidden while XP is capped or disabled.");return end
    UI:SetExpanded(not UI.expanded)
end

function X:LevelUp()
    self:CancelAutoCollapse()
    if not self.profile.levelUp then return end
    UI:SetExpanded(true)
    self.autoCollapse=C_Timer.NewTimer(10,function()
        self.autoCollapse=nil;UI:SetExpanded(false)
    end)
end

function X:Clock()
    if not self.session then return end
    local now=GetTime()
    local connected=UnitIsConnected("player")
    if self.online and self.clockAt and safe(connected) and connected then
        local elapsed=now-self.clockAt
        if elapsed>=0 then self.session.seconds=self.session.seconds+elapsed end
    end
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
    if not self.tracker then return end
    self:Clock()
    local level,xp,cap=UnitLevel("player"),UnitXP("player"),UnitXPMax("player")
    local t=self.tracker
    if not M.Number(level) or not M.Number(xp) or not M.Number(cap) then return end
    -- XP and level notifications can precede each other's visible values.
    if self.levelPending and level<self.levelPending then return end
    self.levelPending=nil
    t:Sample(level,xp,cap,overrideContext or context(),GetTime())
    local rested=GetXPExhaustion()
    self.rested=M.Number(rested) and math.max(0,rested) or 0
    UI:Update()
end

function X:DeferSample()
    local location=context()
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

function X:Integration()
    local manager=StatusTrackingBarManager
    self.integrationMessage=nil
    if not manager then
        if self.profile.hideBlizzard then self.integrationMessage="Blizzard XP integration is waiting for the tracking bar." end
        return
    end
    local lite=EllesmereUI and EllesmereUI.Lite
    local eab=lite and lite.GetAddon and lite.GetAddon("EllesmereUIActionBars",true)
    local euiOwns=eab and eab.db and eab.db.profile and eab.db.profile.useBlizzardDataBars == false
    if self.profile.hideBlizzard and euiOwns then
        self.integrationMessage="Ellesmere manages data bars. Control its XP bar in Ellesmere; XPIsland leaves it alone."
    end
    local wanted=self.profile.hideBlizzard and not euiOwns
    if InCombatLockdown() then
        if wanted or self.barWrapper then self.integrationMessage="Blizzard XP visibility will update after combat." end
        return
    end
    if wanted and not self.barWrapper then
        local original=manager.CanShowBar
        if type(original)~="function" or not StatusTrackingBarInfo or not StatusTrackingBarInfo.BarsEnum then
            self.integrationMessage="Blizzard tracking API unavailable; existing bars are unchanged.";return
        end
        local experience=StatusTrackingBarInfo.BarsEnum.Experience
        local token={active=true}
        local wrapper=function(frame,index,...)
            if token.active and index==experience then return false end
            return original(frame,index,...)
        end
        self.barToken=token
        self.barOriginal,self.barWrapper=original,wrapper
        manager.CanShowBar=wrapper
        manager:UpdateBarsShown()
    elseif not wanted and self.barWrapper then
        self.barToken.active=false
        if manager.CanShowBar==self.barWrapper then
            manager.CanShowBar=self.barOriginal
        end
        if not euiOwns then manager:UpdateBarsShown() end
        -- If another addon chained our wrapper, its disabled branch delegates.
        self.barWrapper,self.barOriginal,self.barToken=nil,nil,nil
    elseif wanted and self.barWrapper and manager.CanShowBar~=self.barWrapper then
        self.integrationMessage="Another addon controls Blizzard tracking visibility; XPIsland will not overwrite it."
    end
end

function X:ApplyProfile()
    self:CancelAutoCollapse()
    UI:Layout();self:Integration()
end

function X:Initialize(reloading)
    local db,err=M.Database(XPIslandDB)
    if not db then say(err);return end
    XPIslandDB=db;self.db=db
    self.character=UnitGUID("player")
    self.characterName=(UnitName("player") or "Character").." - "..GetRealmName()
    if not self.character or not safe(self.character) then return end
    self.profileName=db.characters[self.character]
    if not db.profiles[self.profileName] then self.profileName="Shared" end
    self.profile=M.SelectProfile(db,self.character,self.profileName)
    self.session,self.resumed=M.Resume(XPIslandSession,self.character,GetServerTime(),reloading)
    self.tracker=M.NewTracker(self.session)
    self.tracker:Baseline(UnitLevel("player"),UnitXP("player"),UnitXPMax("player"))
    self.online=true;self.clockAt=GetTime()
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
    UI:Create(self);self:Sample();self:Integration()
    self.ticker=C_Timer.NewTicker(1,function()
        self:Clock();self.tracker:Expire(GetTime())
        if UI.expanded or self.profile.format=="eta" then UI:Update() end
    end)
end

events:SetScript("OnEvent",function(_,event,...)
    if event=="ADDON_LOADED" then
        if ...==addon then
            events:RegisterEvent("PLAYER_ENTERING_WORLD")
        elseif X.session then X:Integration() end
        return
    end
    if event=="PLAYER_ENTERING_WORLD" then
        local initial,reloading=...
        if not X.session then X:Initialize(reloading)
        else
            X.online=true;X.clockAt=GetTime()
            -- Gains during a loading/transition gap have no reliable location.
            X:Sample("unknown")
            X:Integration()
        end
        return
    end
    if not X.session then return end
    if event=="PLAYER_XP_UPDATE" then
        local unit=...
        if safe(unit) and unit=="player" then X:DeferSample() end
    elseif event=="PLAYER_LEVEL_UP" then
        local level=...
        if M.Number(level) then X.levelPending=level end
        X:DeferSample();X:LevelUp()
    elseif event=="QUEST_TURNED_IN" then
        local id,amount=...
        local key=safe(id) and M.Number(amount) and ("quest:"..tostring(id)..":"..tostring(amount)..":"..GetTime()) or nil
        X.tracker:Hint("quests",amount,context(),GetTime(),key)
        X:DeferSample()
    elseif event=="CHAT_MSG_COMBAT_XP_GAIN" then
        local text=...
        local lineID=select(11,...)
        local amount=M.ParseXP(text,X.formats)
        local id=M.Number(lineID) and lineID>0 and "chat:"..lineID or nil
        X.tracker:Hint("kills",amount,context(),GetTime(),id)
        X:DeferSample()
    elseif event=="PLAYER_LEAVING_WORLD" then
        X:Sample();X:Clock();X.online=false
    elseif event=="PLAYER_LOGOUT" then
        X:Snapshot(X.reloadIntent and "reload" or X.cleanIntent and "clean" or "departed")
        X.online=false
    elseif event=="PLAYER_CAMPING" or event=="PLAYER_QUITING" then X.cleanIntent=true
    elseif event=="LOGOUT_CANCEL" then X.cleanIntent=nil
    elseif event=="PLAYER_REGEN_ENABLED" then X:Integration();Options:Refresh()
    elseif event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" or event=="NOTCHED_DISPLAY_MODE_CHANGED" then
        C_Timer.After(0,function() UI:Layout();Options:Refresh() end)
    elseif event=="UPDATE_BINDINGS" then Options:Refresh()
    else X:Sample() end
end)

for _,event in ipairs({"ADDON_LOADED","PLAYER_XP_UPDATE","PLAYER_LEVEL_UP","UPDATE_EXHAUSTION","QUEST_TURNED_IN",
    "CHAT_MSG_COMBAT_XP_GAIN","PLAYER_LEAVING_WORLD","PLAYER_LOGOUT","PLAYER_CAMPING","PLAYER_QUITING","LOGOUT_CANCEL",
    "PLAYER_REGEN_ENABLED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED","NOTCHED_DISPLAY_MODE_CHANGED","UPDATE_BINDINGS",
    "PLAYER_MAX_LEVEL_UPDATE","ENABLE_XP_GAIN","DISABLE_XP_GAIN"}) do events:RegisterEvent(event) end

hooksecurefunc("Logout",function() X.cleanIntent=true end)
hooksecurefunc("Quit",function() X.cleanIntent=true end)
hooksecurefunc("CancelLogout",function() X.cleanIntent=nil end)
hooksecurefunc("ReloadUI",function() X.reloadIntent=true end)
if C_UI and C_UI.Reload then hooksecurefunc(C_UI,"Reload",function() X.reloadIntent=true end) end

SLASH_XPISLAND1="/xpisland"
SlashCmdList.XPISLAND=function(message)
    if not X.session then say("XPIsland is waiting for your character to enter the world.");return end
    if message:lower():match("^%s*reset%s*$") then
        X.session=M.NewSession(X.character,GetServerTime())
        X.tracker=M.NewTracker(X.session);X.clockAt=GetTime();X:Sample()
        say("Session reset.")
    else Options:Toggle(X) end
end
