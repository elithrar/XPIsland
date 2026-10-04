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
    format = "percent", scale = 1, font = "Arial", fontSize = 12,
    normal = {0.64, 0.35, 0.94}, rested = {0.24, 0.61, 1},
    locked = true, levelUp = true, hideBlizzard = false,
    position = {x = 0, y = -8},
}

function M.Profile(p)
    p = type(p) == "table" and p or {}
    local clean = M.Copy(M.defaults)
    if p.format == "percent" or p.format == "fraction" or p.format == "left" or p.format == "leftPercent" then clean.format = p.format end
    if M.Number(p.scale) then clean.scale = max(0.5, min(1.5, p.scale)) end
    if M.Number(p.fontSize) then clean.fontSize = max(10, min(18, floor(p.fontSize))) end
    if type(p.font) == "string" and #p.font < 120 then clean.font = p.font end
    for _, k in ipairs({"locked", "levelUp", "hideBlizzard"}) do
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
    if M.Number(db.version) and db.version > 1 then return nil, "Saved settings belong to a newer XPIsland version." end
    db.version = 1
    db.profiles = type(db.profiles) == "table" and db.profiles or {}
    for name, p in pairs(db.profiles) do
        if type(name) ~= "string" then db.profiles[name] = nil else db.profiles[name] = M.Profile(p) end
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

function M.Compact(n)
    n = max(0, n or 0)
    if n >= 1000000 then return string.format("%.2fm", n / 1000000) end
    if n >= 10000 then return string.format("%.1fk", n / 1000) end
    return tostring(floor(n + 0.5))
end

function M.Label(format, xp, cap)
    if not cap or cap <= 0 then return "—" end
    xp = max(0, min(cap, xp))
    local left = cap - xp
    if format == "fraction" then return M.Compact(xp) .. " / " .. M.Compact(cap) end
    if format == "left" then return M.Compact(left) .. " left" end
    if format == "leftPercent" then return string.format("%s left (%.1f%%)", M.Compact(left), 100 * left / cap) end
    return string.format("%.1f%%", 100 * xp / cap)
end

function M.Duration(seconds)
    if not M.Number(seconds) or seconds < 0 then return "—" end
    if seconds < 60 then return "<1 min" end
    local minutes = floor(seconds / 60 + 0.5)
    if minutes < 60 then return minutes .. " min" end
    return string.format("%dh %02dm", floor(minutes / 60), minutes % 60)
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

function M.NewSession(character, wall)
    return {version = 1, character = character, total = 0, seconds = 0,
        buckets = {kills = 0, quests = 0, dungeons = 0, other = 0},
        started = wall, savedAt = wall, reason = "active", incomplete = false}
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
    return sum == s.total
end

function M.Resume(saved, character, wall, reloading)
    if M.ValidSession(saved, character) then
        local age = wall - saved.savedAt
        local reloadOK = reloading and saved.reason ~= "clean"
        local reconnectOK = saved.reason == "departed" and age >= 0 and age <= 300
        if reloadOK or reconnectOK then
            local s = M.Copy(saved)
            s.reason, s.savedAt = "active", wall
            return s, true
        end
    end
    return M.NewSession(character, wall), false
end

function M.NewTracker(session)
    return setmetatable({session = session, awards = {}, hints = {}, seen = {}}, {__index = M})
end

function M:Baseline(level, xp, cap)
    self.level, self.xp, self.cap = level, xp, cap
end

function M:Sample(level, xp, cap, context, now)
    if not M.Number(level) or not M.Number(xp) or not M.Number(cap) or level < 1 or xp < 0 or cap < 0 then return end
    if not self.level then self:Baseline(level, xp, cap); return end
    local gain
    if level == self.level then
        gain = xp - self.xp
    elseif level == self.level + 1 and self.cap > 0 then
        gain = self.cap - self.xp + xp
    else
        self.session.incomplete = true
    end
    if gain and gain < 0 then self.session.incomplete = true; gain = nil end
    self:Baseline(level, xp, cap)
    if gain and gain > 0 then self:Award(gain, context, now) end
    return gain
end

function M:Award(amount, context, now)
    local s = self.session
    local dungeon = context == "party"
    local bucket = dungeon and "dungeons" or "other"
    s.total = s.total + amount
    s.buckets[bucket] = s.buckets[bucket] + amount
    self.awards[#self.awards + 1] = {left = amount, context = context, time = now, dungeon = dungeon}
    self:Reconcile(now)
end

function M:Hint(bucket, amount, context, now, id)
    if not M.Number(amount) or amount <= 0 or (bucket ~= "kills" and bucket ~= "quests") then return end
    self:Expire(now)
    if id and self.seen[id] then return end
    if id then self.seen[id] = now end
    -- Dungeon awards are already classified, and raids are deliberately Other.
    if context ~= "none" then return end
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
            if not a.dungeon and a.context == h.context then available = available + a.left end
        end
        if available >= h.amount then
            local left = h.amount
            for _, a in ipairs(self.awards) do
                if not a.dungeon and a.context == h.context then
                    local take = min(left, a.left)
                    a.left, left = a.left - take, left - take
                end
            end
            self.session.buckets.other = self.session.buckets.other - h.amount
            self.session.buckets[h.bucket] = self.session.buckets[h.bucket] + h.amount
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
