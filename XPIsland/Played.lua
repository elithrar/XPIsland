local _, ns = ...
local M = ns.Model
local P = {}
ns.Played = P
local function integer(n) return M.Number(n) and n>=0 and n==math.floor(n) end
local function anchor(a)
    return type(a)=="table" and integer(a.level) and a.level>0 and integer(a.start) and integer(a.total) and a.start<=a.total
end

function P:Initialize(owner, saved)
    self.owner=owner
    self.saved={version=1,character=owner.character}
    if type(saved)=="table" and saved.version==1 and saved.character==owner.character and anchor(saved.current) then
        self.saved.current={level=saved.current.level,start=saved.current.start,total=saved.current.total}
    end
    XPIslandPlayed=self.saved
    self.generation=0
    -- Observes calls without replacing the API. Overlap means chat stays visible.
    if type(RequestTimePlayed)=="function" then
        hooksecurefunc("RequestTimePlayed",function()
            if self.calling then return end
            self:Invalidate()
            self.uncertain=true
            self.externalOutstanding=(self.externalOutstanding or 0)+1
            self.externalDeadline=GetTime()+8
            self:Sync()
        end)
    end
    self:Sync()
end

function P:ReleaseQuiet()
    local token=self.quiet
    if not token then return end
    token.active=false
    for _,entry in ipairs(token.frames) do
        if entry.frame.customEventHandler==entry.wrapper then entry.frame.customEventHandler=entry.original end
    end
    self.quiet=nil
end

function P:Quiet()
    self:ReleaseQuiet()
    local token={active=true,frames={}}
    self.quiet=token
    local maxWindows=Constants and Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows or NUM_CHAT_WINDOWS or 0
    for i=1,maxWindows do
        local frame=_G["ChatFrame"..i]
        if frame and frame.IsEventRegistered and frame:IsEventRegistered("TIME_PLAYED_MSG") then
            local original=frame.customEventHandler
            local wrapper=function(f,event,...)
                local consumed=original and original(f,event,...)
                if consumed then return consumed end
                if event=="TIME_PLAYED_MSG" and token.active then return true end
                return consumed
            end
            token.frames[#token.frames+1]={frame=frame,original=original,wrapper=wrapper}
            frame.customEventHandler=wrapper
        end
    end
end

function P:Invalidate()
    self.generation=self.generation+1
    self:ReleaseQuiet()
    if self.flight then self.flight.invalid=true;self.uncertain=true end
    self.candidate=nil
end

function P:Sync()
    self.attempts=0;self.due=GetTime()+1;self.wanted=true
end

function P:Ready()
    local x=self.owner
    return x.online and x.inWorld and not x.loading and x.connected~=false and not x.levelPending
        and not x.transition and not x.tracker.pending and (x.lastLevelEvent or 0)<=x.tracker.level and UnitLevel("player")==x.tracker.level
end

function P:Pump()
    local now=GetTime()
    if self.flight and now>=self.flight.deadline then
        self:ReleaseQuiet();self.flight=nil;self.uncertain=true;self.quietUnsafe=true;self.candidate=nil;self.due=now+2
    end
    if (self.externalOutstanding or 0)>0 then
        if now<self.externalDeadline then return end
        self.externalOutstanding=0;self.uncertain=true;self.quietUnsafe=true
    end
    if self.flight or not self.wanted or self.attempts>=3 or now<(self.due or 0) or not self:Ready() then return end
    if type(RequestTimePlayed)~="function" then self.wanted=false;return end
    self.attempts=self.attempts+1
    self.flight={level=self.owner.tracker.level,generation=self.generation,deadline=now+8}
    if not self.quietUnsafe then self:Quiet() end
    self.calling=true
    local ok=pcall(RequestTimePlayed)
    self.calling=nil
    if not ok then self:ReleaseQuiet();self.flight=nil;self.wanted=false end
end

function P:Response(total, levelTime)
    local flight=self.flight
    if not flight then
        if (self.externalOutstanding or 0)>0 then
            self.externalOutstanding=self.externalOutstanding-1;self.due=GetTime()+2
        end
        return
    end
    self.flight=nil;self.due=GetTime()+2
    local token=self.quiet
    -- Keep ownership through this event's chat-frame dispatch, regardless of order.
    C_Timer.After(0,function() if self.quiet==token then self:ReleaseQuiet() end end)
    if flight.invalid or flight.generation~=self.generation or not self:Ready() or flight.level~=self.owner.tracker.level then
        self.uncertain=true;self:ReleaseQuiet();return
    end
    if not integer(total) or not integer(levelTime) or levelTime>total then self:ReleaseQuiet();return end
    local nextAnchor={level=flight.level,start=total-levelTime,total=total}
    local old=self.saved.current
    if old then
        if total<old.total or nextAnchor.level<old.level then self:ReleaseQuiet();return end
        if nextAnchor.level==old.level and nextAnchor.start~=old.start then self:ReleaseQuiet();return end
        if nextAnchor.level>old.level and (nextAnchor.start<old.total or nextAnchor.start<=old.start) then self:ReleaseQuiet();return end
    end
    if self.uncertain then
        local candidate=self.candidate
        if not candidate or candidate.level~=nextAnchor.level or candidate.start~=nextAnchor.start or total<candidate.total then
            self.candidate=nextAnchor;return
        end
    end
    self.saved.current=nextAnchor
    self.uncertain=nil;self.candidate=nil;self.wanted=false
    if old and nextAnchor.level==old.level+1 then
        self.completed={level=old.level,seconds=nextAnchor.start-old.start,observed=GetTime()}
        self.owner:PlayedLevelComplete(old.level,self.completed.seconds)
    end
end
