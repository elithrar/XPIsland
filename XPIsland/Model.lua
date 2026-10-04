local _, ns = ...
local M = {}
ns.Model = M
local floor, min, max = math.floor, math.min, math.max

function M.Number(v)
    return not (issecretvalue and issecretvalue(v)) and type(v) == "number"
        and v == v and v ~= math.huge and v ~= -math.huge
end

function M.Copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = M.Copy(v) end
    return out
end

M.defaults = {
    format = "percent", scale = 1, font = "Game tooltip", fontSize = 14,
    fontCustomized = false, fontSizeCustomized = false, placement = "top",
    normal = {0.64, 0.35, 0.94}, rested = {0.24, 0.61, 1},
    locked = true, levelUp = true, hideBlizzard = false,
    autoCollapse = true, collapseCombat = true,
    position = {x = 0, y = -8},
}

function M.Profile(p)
    p = type(p) == "table" and p or {}
    local clean = M.Copy(M.defaults)
    if p.format == "percent" or p.format == "fraction" or p.format == "left" or p.format == "leftPercent" or p.format == "eta" then clean.format = p.format end
    if M.Number(p.scale) then clean.scale = max(0.5, min(1.5, p.scale)) end
    if M.Number(p.fontSize) then clean.fontSize = max(10, min(18, floor(p.fontSize))) end
    if type(p.font) == "string" and #p.font < 120 then clean.font = p.font end
    if p.placement == "bottom" or p.placement == "custom" then clean.placement = p.placement end
    for _, k in ipairs({"locked", "levelUp", "hideBlizzard", "autoCollapse", "collapseCombat", "fontCustomized", "fontSizeCustomized"}) do
        if type(p[k]) == "boolean" then clean[k] = p[k] end
    end
    for _, k in ipairs({"normal", "rested"}) do
        if type(p[k]) == "table" then
            for i = 1, 3 do if M.Number(p[k][i]) then clean[k][i] = max(0, min(1, p[k][i])) end end
        end
    end
    if type(p.position) == "table" then
        for _, k in ipairs({"x", "y"}) do
            if M.Number(p.position[k]) then clean.position[k] = max(-10000, min(10000, p.position[k])) end
        end
    end
    return clean
end

function M.Database(db)
    db = type(db) == "table" and db or {}
    -- Do not destructively downgrade a newer saved schema.
    if M.Number(db.version) and db.version > 2 then return nil, "Saved settings belong to a newer XPIsland version." end
    local legacy = not M.Number(db.version) or db.version < 2
    db.version = 2
    db.expandedOnce = db.expandedOnce == true -- account-wide onboarding, never copied with a profile
    db.profiles = type(db.profiles) == "table" and db.profiles or {}
    for name, p in pairs(db.profiles) do
        if type(name) ~= "string" then db.profiles[name] = nil else
            p = type(p) == "table" and p or {}
            if legacy then
                -- v1 did not record intent. Preserve non-default choices and any
                -- explicit markers; an unmarked old default follows the new one.
                if p.font == "Arial" and not p.fontCustomized then p.font = nil end
                if p.fontSize == 12 and not p.fontSizeCustomized then p.fontSize = nil end
                if not p.placement and type(p.position) == "table"
                    and ((p.position.x or 0) ~= 0 or (p.position.y or -8) ~= -8) then p.placement = "custom" end
            end
            db.profiles[name] = M.Profile(p)
        end
    end
    db.profiles.Shared = db.profiles.Shared or M.Profile()
    db.characters = type(db.characters) == "table" and db.characters or {}
    return db
end

function M.SelectProfile(db, character, name)
    if not db.profiles[name] then return nil end
    db.characters[character] = name
    return db.profiles[name]
end

function M.Duplicate(db, source, name)
    if type(name) ~= "string" then return nil, "Enter a profile name." end
    name = name:match("^%s*(.-)%s*$")
    if name == "" or #name > 48 then return nil, "Use a name of 1–48 characters." end
    if db.profiles[name] then return nil, "That profile already exists." end
    if not db.profiles[source] then return nil, "Choose an existing profile." end
    db.profiles[name] = M.Copy(db.profiles[source])
    return name
end

function M.Compact(n, precision)
    if not M.Number(n) then return "—" end
    n = max(0, n or 0)
    if n >= 999950000 then return "999M+" end
    local unit, suffix = 1, ""
    if n >= 999950 then unit,suffix = 1000000,"M"
    elseif n >= 1000 then unit,suffix = 1000,"K" end
    if unit == 1 then return tostring(floor(n+.5)) end
    local decimals=precision == 0 and 0 or 1
    local power=10^decimals
    local value=floor(n/unit*power+.5)/power
    if suffix == "K" and value >= 1000 then value,suffix=1,"M" end
    local result=string.format("%."..decimals.."f",value):gsub("%.0$","")
    return (result:gsub("%.",DECIMAL_SEPERATOR or "."))..suffix
end

function M.Label(format, xp, cap)
    if not cap or cap <= 0 then return "—" end
    xp = max(0, min(cap, xp))
    local left = cap - xp
    if format == "fraction" then return M.Compact(xp) .. " / " .. M.Compact(cap) .. " XP" end
    if format == "left" then return M.Compact(left) .. " XP left" end
    if format == "leftPercent" then return string.format("%s XP left (%d%%)", M.Compact(left), floor(left / cap*100+.5)) end
    return (string.format("%.1f%%", xp / cap*100):gsub("%.",DECIMAL_SEPERATOR or "."))
end

function M.Duration(seconds, long)
    if not M.Number(seconds) or seconds < 0 then return "—" end
    if seconds < 60 then return long and "Less than one minute" or "<1m" end
    local minutes = floor(seconds / 60 + 0.5)
    if minutes >= 999*1440 then return long and "999 days or more" or "999d+" end
    local function units(value,unit) return value.." "..unit..(value==1 and "" or "s") end
    if minutes >= 2880 then
        local days,hours=floor(minutes/1440),floor(minutes/60)%24
        return long and units(days,"day")..", "..units(hours,"hour") or string.format("%dd %dh",days,hours)
    end
    if minutes < 60 then return long and units(minutes,"minute") or minutes.."m" end
    local hours,remainder=floor(minutes/60),minutes%60
    return long and units(hours,"hour")..", "..units(remainder,"minute") or string.format("%dh %dm",hours,remainder)
end

-- Fixed-size rolling history in connected-session seconds. Classification can
-- arrive after an award; its kill correction updates the same minute bucket.
function M.RateHistory(session)
    if not session.rate then session.rate={version=1,startedAt=session.seconds,buckets={}} end
    return session.rate
end

function M.RateAward(session, amount)
    local history=M.RateHistory(session)
    local index=floor((session.seconds-history.startedAt)/60)
    local slot=index%61+1
    local bucket=history.buckets[slot]
    if not bucket or bucket.index~=index then
        bucket={index=index,totalXP=0,killXP=0};history.buckets[slot]=bucket
    end
    bucket.totalXP=bucket.totalXP+amount
    return index
end

function M.RateKill(session,index,amount)
    local bucket=session.rate.buckets[index%61+1]
    if bucket and bucket.index==index then bucket.killXP=min(bucket.totalXP,bucket.killXP+amount) end
end

function M.Estimate(session, xp, cap, capped)
    if capped or not cap or cap<=0 or not session then return end
    local history=M.RateHistory(session)
    local age=max(0,session.seconds-history.startedAt)
    local k20,k60,n60=0,0,0
    local function weight(index,window)
        local start=index*60
        if start>age then return 0 end
        return min(1,max(0,(start+60-max(0,age-window))/60))
    end
    for _,bucket in pairs(history.buckets) do
        local w60=weight(bucket.index,3600)
        k60=k60+bucket.killXP*w60
        n60=n60+(bucket.totalXP-bucket.killXP)*w60
        k20=k20+bucket.killXP*weight(bucket.index,1200)
    end
    local t20=min(1200,max(age,60))
    local t60=min(3600,max(age,60))
    local perSecond=n60/t60+.5*k60/t60+.5*k20/t20
    if not M.Number(perSecond) then return end
    local duration=perSecond>0 and age>=60 and max(0,cap-xp)/perSecond or nil
    if duration and not M.Number(duration) then duration=nil end
    return perSecond*3600,duration
end

-- A missing estimate has several distinct causes. Never infer session activity
-- from the rolling rate: earned XP remains earned after its rate window expires.
function M.ETAState(session, rate, duration)
    if not session then return "unavailable" end
    if session.rate and session.rate.recovery and session.seconds-session.rate.startedAt<60 then return "recovering" end
    if session.total == 0 then return "empty" end
    if duration then return "ready" end
    if session.rate and session.seconds-session.rate.startedAt < 60 then return "warming" end
    if rate == 0 then return "idle" end
    return "unavailable"
end

M.ETAMessages = {
    empty = "No XP activity in this session yet.",
    warming = "Collecting a full minute of XP history for an estimate.",
    idle = "No recent XP to estimate from. Earn XP to update your pace.",
    unavailable = "Waiting for XP information.",
    recovering = "Recalculating your leveling pace.",
}

function M.ExactXP(xp, cap)
    local number = BreakUpLargeNumbers or tostring
    return string.format("%s / %s (%s)", number(xp), number(cap), M.Label("percent",xp,cap))
end

-- Widths use usable UIParent units, independent of 3D render scale.
function M.Layout(usableWidth, scale)
    local collapsed, expanded = 360, 460
    if usableWidth >= 1400 then collapsed, expanded = 400, 520 end
    if usableWidth >= 2000 then collapsed, expanded = 440, 560 end
    -- Hard bounds: ultrawide displays never grow the island beyond this tier.
    local available = max(100, usableWidth - 24)
    local fit = min(scale, available / expanded)
    return collapsed, expanded, fit
end

-- All coordinates are in UIParent units: Blizzard already excludes the notch
-- in Shift UI mode. Reserve the expanded footprint even while collapsed, so
-- toggling never moves the bar to make room for its details.
function M.Placement(viewWidth, viewHeight, p, minimumHeader, detailHeight)
    local cw, ew, scale = M.Layout(viewWidth, p.scale)
    cw=max(cw,min(440,minimumHeader or cw))
    local barHeight, panelHeight = 34, 34+(detailHeight or 102)
    scale = min(scale, max(.01, (viewHeight-16)/panelHeight))
    local bh, ph = barHeight*scale, panelHeight*scale
    local xLimit = max(0,(viewWidth-ew*scale)/2-8)
    local x = p.placement == "custom" and max(-xLimit,min(xLimit,p.position.x)) or 0
    local y, up
    if p.placement == "bottom" then y,up = -viewHeight+8+bh,true
    elseif p.placement == "custom" then
        y = max(-viewHeight+8+bh,min(-8,p.position.y))
        local above,below = -y-8,viewHeight+y-bh-8
        up = above > below
        if up then y = min(y,-8-(ph-bh)) else y = max(y,-viewHeight+8+ph) end
    else y,up = -8,false end
    return {collapsed=cw,expanded=ew,scale=scale,barHeight=barHeight,panelHeight=panelHeight,x=x,y=y,up=up}
end

function M.NewSession(character, wall)
    return {version = 1, character = character, total = 0, seconds = 0,
        buckets = {kills = 0, quests = 0, dungeons = 0, other = 0},
        started = wall, savedAt = wall, reason = "active", incomplete = false,
        rate = {version=1,startedAt=0,buckets={}}}
end

function M.ValidSession(s, character)
    if type(s) ~= "table" or s.version ~= 1 or s.character ~= character or type(s.buckets) ~= "table" then return false end
    if not M.Number(s.total) or s.total < 0 or not M.Number(s.seconds) or s.seconds < 0 or not M.Number(s.savedAt) then return false end
    local sum = 0
    for _, k in ipairs({"kills", "quests", "dungeons", "other"}) do
        local n = s.buckets[k]
        if not M.Number(n) or n < 0 then return false end
        sum = sum + n
    end
    if sum~=s.total then return false end
    if s.rate~=nil then
        local r=s.rate
        if type(r)~="table" or r.version~=1 or not M.Number(r.startedAt) or r.startedAt<0 or r.startedAt>s.seconds or type(r.buckets)~="table" then return false end
        local count=0
        for slot,b in pairs(r.buckets) do
            count=count+1
            if count>61 or not M.Number(slot) or slot<1 or slot>61 or slot~=floor(slot)
                or type(b)~="table" or not M.Number(b.index) or b.index<0 or b.index~=floor(b.index) or b.index%61+1~=slot
                or b.index>floor((s.seconds-r.startedAt)/60) or not M.Number(b.totalXP) or not M.Number(b.killXP)
                or b.totalXP<0 or b.killXP<0 or b.killXP>b.totalXP then return false end
        end
    end
    return true
end

function M.Resume(saved, character, wall, reloading)
    if M.ValidSession(saved, character) then
        local age = wall - saved.savedAt
        local reloadOK = reloading and saved.reason ~= "clean"
        local reconnectOK = saved.reason == "departed" and age >= 0 and age <= 300
        if reloadOK or reconnectOK then
            local s = M.Copy(saved)
            s.reason, s.savedAt = "active", wall
            M.RateHistory(s)
            if s.incomplete then M.RestartRate(s) end
            return s, true
        end
    end
    return M.NewSession(character, wall), false
end

-- Preserve recorded counters; never guess XP across an unknown threshold or
-- correction. Only the rolling baseline needs to recover, once, not forever.
function M.RestartRate(session)
    session.rate={version=1,startedAt=session.seconds,buckets={},recovery=true}
    session.incomplete=false -- migrate the pre-0.4.1 permanent estimate veto
    session.partial=true
end

function M.NewTracker(session)
    if session.incomplete then M.RestartRate(session) end
    return setmetatable({session = session, awards = {}, hints = {}, seen = {}}, {__index = M})
end

function M:Baseline(level, xp, cap)
    self.level, self.xp, self.cap = level, xp, cap
end

function M:Sample(level, xp, cap, context, now, capped)
    if not M.Number(level) or not M.Number(xp) or not M.Number(cap)
        or level<1 or xp<0 or cap<0 or (cap==0 and not capped) or xp>cap then return nil,false end
    if not self.level then self:Baseline(level,xp,cap);return 0,true end
    local ordinary=level==self.level and cap==self.cap and xp>=self.xp
    if not ordinary then
        -- UnitLevel, UnitXP and UnitXPMax can change in different notifications.
        -- Keep the last valid baseline while a new level/cap or backward value
        -- settles. The owner's existing ticker retries; there is no new timer.
        local pending=self.pending
        if not pending or pending.level~=level or pending.cap~=cap then
            self.pending={level=level,cap=cap,since=now,context=context}
            return nil,false
        end
        if context~=pending.context then pending.context="unknown" end
        if now-pending.since<1 then return nil,false end
        context=pending.context
    elseif self.pending then
        -- A transient backward reading recovered: use the untouched baseline.
        if context~=self.pending.context then context="unknown" end
    end
    self.pending=nil
    local gain
    if level==self.level and xp>=self.xp then gain=xp-self.xp
    elseif level==self.level+1 and self.cap>0 then gain=self.cap-self.xp+xp
    else
        M.RestartRate(self.session)
        self.awards,self.hints={},{} -- old hints cannot classify a new baseline
    end
    self:Baseline(level,xp,cap)
    if gain and gain>0 then self:Award(gain,context,now) end
    return gain,true
end

function M:Award(amount, context, now)
    local s = self.session
    local dungeon = context == "party"
    local bucket = dungeon and "dungeons" or "other"
    s.total = s.total + amount
    s.buckets[bucket] = s.buckets[bucket] + amount
    local rateIndex=M.RateAward(s,amount)
    self.awards[#self.awards + 1] = {left = amount, context = context, time = now, dungeon = dungeon,rateIndex=rateIndex}
    self:Reconcile(now)
end

function M:Hint(bucket, amount, context, now, id)
    if not M.Number(amount) or amount <= 0 or (bucket ~= "kills" and bucket ~= "quests") then return end
    self:Expire(now)
    if id and self.seen[id] then return end
    if id then self.seen[id] = now end
    -- Source identity is orthogonal to display category: dungeon kills remain
    -- Dungeon XP but can contribute to the recent-kill rate weighting.
    if context == "unknown" then return end
    self.hints[#self.hints + 1] = {bucket = bucket, amount = amount, context = context, time = now}
    self:Reconcile(now)
end

function M:Expire(now)
    for _, list in ipairs({self.awards, self.hints}) do
        for i = #list, 1, -1 do if now - list[i].time > 2 then table.remove(list, i) end end
    end
    for id, t in pairs(self.seen) do if now - t > 3 then self.seen[id] = nil end end
end

function M:Reconcile(now)
    self:Expire(now)
    for i = #self.hints, 1, -1 do
        local h = self.hints[i]
        local available = 0
        for _, a in ipairs(self.awards) do
            if a.context == h.context then available = available + a.left end
        end
        if available >= h.amount then
            local left = h.amount
            for _, a in ipairs(self.awards) do
                if a.context == h.context then
                    local take = min(left, a.left)
                    a.left, left = a.left - take, left - take
                    if h.bucket=="kills" and take>0 then M.RateKill(self.session,a.rateIndex,take) end
                end
            end
            if h.context=="none" then
                self.session.buckets.other = self.session.buckets.other - h.amount
                self.session.buckets[h.bucket] = self.session.buckets[h.bucket] + h.amount
            end
            table.remove(self.hints, i)
        end
    end
end

-- Compile Blizzard's localized printf strings; the first numeric argument is XP.
function M.CompileXPFormat(format)
    if type(format) ~= "string" then return end
    local pattern, numeric, numericArgument, capture, i = "^", nil, nil, 0, 1
    while i <= #format do
        local c = format:sub(i, i)
        if c == "%" then
            if format:sub(i + 1, i + 1) == "%" then pattern = pattern .. "%%"; i = i + 2
            else
                local rest = format:sub(i)
                local token, argument, kind = rest:match("^(%%(%d+)%$([sd]))")
                if not token then token, kind = rest:match("^(%%([sd]))") end
                if not token then return end
                capture = capture + 1
                if kind == "d" then
                    argument=tonumber(argument) or capture
                    if not numericArgument or argument<numericArgument then numeric,numericArgument=capture,argument end
                    pattern = pattern .. "([%d%.,%s]+)"
                else pattern = pattern .. "(.-)" end
                i = i + #token
            end
        else
            pattern = pattern .. c:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            i = i + 1
        end
    end
    if numeric then return {pattern = pattern .. "$", numeric = numeric} end
end

function M.ParseXP(text, formats)
    if (issecretvalue and issecretvalue(text)) or type(text) ~= "string" then return end
    for _, f in ipairs(formats) do
        local captures = {text:match(f.pattern)}
        local value = captures[f.numeric]
        if value then return tonumber((value:gsub("[^%d]", ""))) end
    end
end
