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

function P:Refresh()
    self:Pet();self:PvP()
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
