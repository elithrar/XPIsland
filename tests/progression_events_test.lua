-- Synthetic locale strings exercise ingestion, not the client's translations.
local W=dofile('tests/wow_mock.lua')
COMBATLOG_XPGAIN_FIRSTPERSON_REVIEW='%3$d bonus : %1$s rapporte %2$d points.'
local ns=W.load();local X,M,UI=ns.owner,ns.Model,ns.UI
local n=0
local function eq(a,b,why) n=n+1;assert(a==b,(why or 'check')..': '..tostring(a)..' ~= '..tostring(b)) end
-- Failed initialization must neither render nor downgrade newer settings.
XPIslandDB={version=3}
W.event('ADDON_LOADED','XPIsland');W.event('PLAYER_ENTERING_WORLD',true,false)
eq(XPIslandDB.version,3);eq(X.session,nil);eq(UI.frame,nil)
-- A new client lifetime restores a repaired database; live globals are not a second settings owner.
XPIslandDB=nil;W=dofile('tests/wow_mock.lua');ns=W.load();X,M,UI=ns.owner,ns.Model,ns.UI
W.event('ADDON_LOADED','XPIsland')
local guid=UnitGUID;UnitGUID=function() return nil end
W.event('PLAYER_ENTERING_WORLD',false,false);eq(X.session,nil);eq(UI.frame,nil)
local secret={}
function issecretvalue(v) return rawequal(v,secret) end
UnitGUID=function() return secret end
W.event('PLAYER_ENTERING_WORLD',false,false);eq(X.session,nil,'restricted identity postpones initialization')
local name,realm=UnitName,GetRealmName
UnitGUID=guid;UnitName=function() return secret end;GetRealmName=function() return secret end
W.event('PLAYER_ENTERING_WORLD',false,false);eq(UI.frame:IsShown(),true)
UnitName,GetRealmName=name,realm;issecretvalue=nil
local function hint(text,id)
 -- lineID is argument 11; argument 12 is the sender GUID, not a kill identity.
 W.event('CHAT_MSG_COMBAT_XP_GAIN',text,'','','','','',0,0,'',0,id,'Player-Sender')
end
local function xp(amount)
 W.xp=W.xp+amount;W.event('PLAYER_XP_UPDATE','player');W.advance(.1)
end
-- Hint first, reward split across XP notifications, rested bonus already included.
hint('60 bonus : Sanglier rapporte 120 points.',901)
xp(40);eq(X.session.killHistory,nil,'partial reward cannot count a kill')
xp(80)
eq(X.session.killHistory.buckets[1].count,1);eq(X.session.killHistory.buckets[1].xp,120)
-- XP first, then a reordered localized hint from the same sender.
xp(180);hint('30 bonus : Loup rapporte 180 points.',902);W.advance(.1)
eq(X.session.killHistory.buckets[1].count,2,'distinct line IDs, same sender')
eq(X.session.killHistory.buckets[1].xp,300,'bonus not added twice')
eq(X.session.buckets.kills,300)
-- Replay after short attribution-cache expiry cannot steal a new unrelated gain.
W.advance(4);xp(120);hint('60 bonus : Sanglier rapporte 120 points.',901);W.advance(.1)
eq(X.session.killHistory.buckets[1].count,2);eq(X.session.buckets.other,120)
-- An absent line ID may classify observed XP but cannot supply a kill count.
xp(50);hint('0 bonus : Ours rapporte 50 points.');W.advance(.1)
eq(X.session.killHistory.buckets[1].count,2);eq(X.session.buckets.kills,350)
eq(X.session.total,470,'all observed XP retained exactly once')
eq(select(2,M.KillsToLevel(X.session,W.xp,W.cap)),'warming')
-- Mode changes preserve ongoing XP accounting.
W.set('mode','pvp');X:ApplyProfile()
eq(X.session.total,470,'mode and integration leave XP accounting alone')
print('PASS: '..n..' progression event assertions (initialization, synthetic locale ingestion, ordering, duplicates and mode changes)')
