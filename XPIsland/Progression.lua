local _,ns=...
local M=ns.Model
local P={}
ns.Progression=P

local function readable(v)
    return not (issecretvalue and issecretvalue(v))
end
local function record(v)
    return readable(v) and type(v)=="table"
end
local function nonnegative(v)
    return M.Number(v) and v>=0
end

-- These are live snapshots, not SavedVariables and never XP transactions.
function P:Pet()
    self.pet=nil
    if not UnitExists or not GetPetExperience then return end
    local exists=UnitExists("pet")
    if not readable(exists) or not exists then return end
    local guid,level=UnitGUID("pet"),UnitLevel("pet")
    local xp,cap=GetPetExperience()
    if not readable(guid) or type(guid)~="string" or not nonnegative(xp)
        or not M.Number(cap) or cap<=0 or xp>cap or not M.Number(level) or level<1 then return end
    local name=UnitName("pet")
    self.pet={guid=guid,level=level,xp=xp,cap=cap,name=readable(name) and name or nil}
end

function P:PvP()
    self.honor,self.rank=nil,nil
    local currency=Constants and Constants.CurrencyConsts and Constants.CurrencyConsts.HONOR_CURRENCY_ID
    if M.Number(currency) and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info=C_CurrencyInfo.GetCurrencyInfo(currency)
        if record(info) and nonnegative(info.quantity) then self.honor=info.quantity end
    end
    if not C_MajorFactions or not C_MajorFactions.GetMajorFactionProgressionInfo then return end
    local info=C_MajorFactions.GetMajorFactionProgressionInfo(2800)
    if not record(info) or not nonnegative(info.renownLevel) or not nonnegative(info.renownReputationEarned)
        or not nonnegative(info.renownLevelThreshold) or not nonnegative(info.maxLevel)
        or info.renownLevel~=math.floor(info.renownLevel) or info.maxLevel<info.renownLevel then return end
    local r={level=info.renownLevel,xp=info.renownReputationEarned,cap=info.renownLevelThreshold,
        maximum=info.maxLevel>0 and info.renownLevel>=info.maxLevel}
    if not r.maximum and (r.cap<=0 or r.xp>r.cap) then return end
    r.left=r.maximum and 0 or math.max(0,r.cap-r.xp)
    local week=info.currentWeekProgressiveMaxLevel
    if nonnegative(week) and week==math.floor(week) and C_MajorFactions.GetTotalReputationForRenownLevel then
        local base=C_MajorFactions.GetTotalReputationForRenownLevel(2800,r.level)
        local ceiling=C_MajorFactions.GetTotalReputationForRenownLevel(2800,week)
        if nonnegative(base) and M.Number(ceiling) and ceiling>0 then
            r.total,r.ceiling=base+r.xp,ceiling
            r.weekCapped=r.total>=ceiling
        end
    end
    self.rank=r
end

local function text(v)
    return readable(v) and type(v)=="string" and v~=""
end
local function boolean(v)
    return readable(v) and type(v)=="boolean"
end

-- Follow the client's watched faction; never set it or enumerate/expand its list.
-- Thresholds are absolute standings (including negative hostile reputations).
function P:Reputation()
    self.reputation,self.reputationState=nil,"unavailable"
    if not C_Reputation or not C_Reputation.GetWatchedFactionData then return end
    local info=C_Reputation.GetWatchedFactionData()
    if not readable(info) then return end
    if info==nil then self.reputationState="none";return end
    if not record(info) or not M.Number(info.factionID) then return end
    if info.factionID==0 then self.reputationState="none";return end
    if info.factionID<0 or info.factionID~=math.floor(info.factionID) or not text(info.name) then return end
    if not C_Reputation.IsFactionParagonForCurrentPlayer or not C_Reputation.IsMajorFaction then return end
    local id=info.factionID
    local paragon,major=C_Reputation.IsFactionParagonForCurrentPlayer(id),C_Reputation.IsMajorFaction(id)
    if not boolean(paragon) or not boolean(major) then return end
    local r={id=id,name=info.name}
    local low,high,value=info.currentReactionThreshold,info.nextReactionThreshold,info.currentStanding
    if paragon then
        if not C_Reputation.GetFactionParagonInfo then return end
        local earned,threshold,_,pending=C_Reputation.GetFactionParagonInfo(id)
        if not nonnegative(earned) or not M.Number(threshold) or threshold<=0 or not boolean(pending) then return end
        low,high,value=0,threshold,earned%threshold
        r.rewardPending=pending;r.standing="Paragon"
        if pending then value=value+threshold end
    elseif major then
        if not C_MajorFactions or not C_MajorFactions.GetMajorFactionData or not C_MajorFactions.HasMaximumRenown then return end
        local data=C_MajorFactions.GetMajorFactionData(id)
        local maximum=C_MajorFactions.HasMaximumRenown(id)
        if not record(data) or not boolean(maximum) or not nonnegative(data.renownLevel)
            or data.renownLevel~=math.floor(data.renownLevel) then return end
        low,high,value=0,data.renownLevelThreshold,data.renownReputationEarned
        r.maximum=maximum;r.standing="Renown "..data.renownLevel
    else
        if not C_GossipInfo or not C_GossipInfo.GetFriendshipReputation then return end
        local friend=C_GossipInfo.GetFriendshipReputation(id)
        if not readable(friend) then return end
        -- No friendship result is valid for an ordinary faction. Restricted or
        -- malformed results are different: do not guess their progression type.
        if friend~=nil and (not record(friend) or not nonnegative(friend.friendshipFactionID)) then return end
        if friend and friend.friendshipFactionID>0 then
            if not readable(friend.nextThreshold) or not text(friend.reaction) then return end
            low,high,value=friend.reactionThreshold,friend.nextThreshold,friend.standing
            r.maximum=high==nil;r.standing=friend.reaction
            if r.maximum then low,high,value=0,0,0 end
        else
            local reaction=info.reaction
            if not M.Number(reaction) or reaction~=math.floor(reaction) or reaction<1 or reaction>8 then return end
            r.maximum=reaction==8
            local label=_G["FACTION_STANDING_LABEL"..reaction]
            r.standing=text(label) and label or "Standing "..reaction
        end
    end
    if not M.Number(low) or not M.Number(high) or not M.Number(value) or high<low or value<low then return end
    r.xp,r.cap=value-low,high-low
    if not M.Number(r.xp) or not M.Number(r.cap) then return end
    if not r.maximum and (r.cap<=0 or (r.xp>r.cap and not r.rewardPending)) then return end
    r.left=(r.maximum or r.rewardPending) and 0 or math.max(0,r.cap-r.xp)
    self.reputation,self.reputationState=r,"ready"
end

function P:ReputationLabel(format)
    local r=self.reputation
    if not r then return self.reputationState=="none" and "Select faction" or "Reputation · —" end
    local value
    if r.maximum then value="Maximum"
    elseif r.rewardPending then value="Reward ready"
    elseif format=="fraction" then value=M.Compact(r.xp).." / "..M.Compact(r.cap)
    elseif format=="left" then value=M.Compact(r.left).." left"
    else value=string.format("%.1f%%",r.xp*100/r.cap) end
    return r.name.." · "..value,value
end

function P:Refresh()
    self:Pet();self:PvP();self:Reputation()
end

function P:Pump()
    local season=GetCurrentArenaSeason and GetCurrentArenaSeason()
    if M.Number(season) and season~=self.season then
        self.season=season;self:PvP();return true
    end
end

function P:RankText()
    local r=self.rank
    if not r then return "—" end
    if r.maximum then return "Maximum rank" end
    local function number(n)
        if n<1000000 and BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
        return M.Compact(n)
    end
    return number(r.xp).." / "..number(r.cap)
end

function P:Label(format)
    local r=self.rank
    if format=="rankLeft" then
        if not r then return "PvP · — RP left" end
        if r.maximum then return "PvP · Maximum rank" end
        if r.weekCapped then return "PvP · Rank cap reached" end
        return "PvP · "..M.Compact(r.left).." RP left"
    end
    return "PvP rank · "..M.Compact(self.honor).." Honor"
end
