local _, ns = ...
local media="Interface\\AddOns\\XPIsland\\media\\"
local T={default="modern", definitions={}}
ns.Themes=T
-- Ordered, complete definitions. Add themes here; IDs are persisted in profiles.
-- Definitions are static after addon loading. User fonts/colors remain separate.
T.definitions={
    {id="modern",label="Modern",headerHeight=34,headerInset=14,labelGap=12,segmentHeight=10,
     outerRadius=17,innerRadius=16,outerColor={.19,.20,.23,1},innerColor={.035,.04,.055,.97},
     trackColor={.14,.14,.18},trackAlpha=1,dividerColor={.18,.18,.22,1},
     titleColor={.86,.79,.63},valueColor={.93,.94,.97},capTexture=media.."cap.tga",shadingAlpha=0},
    {id="forever",label="Forever",headerHeight=28,headerInset=10,labelGap=8,segmentHeight=14,
     chromeTexture=media.."forever-chrome.tga",chromeRadius=6,
     trackColor={.32,.32,.30},trackAlpha=.85,dividerColor={.32,.25,.14,1},
     titleColor={.83,.72,.49},valueColor={.94,.90,.80},capTexture=media.."soft-cap.tga",
     shadingTexture=media.."theme-shading.tga",capShadingTexture=media.."soft-cap-shading.tga",shadingAlpha=.55},
}
function T.Get(id)
    for _,theme in ipairs(T.definitions) do if theme.id==id then return theme end end
    for _,theme in ipairs(T.definitions) do if theme.id==T.default then return theme end end
end
function T.Choices()
    local choices={}
    for _,theme in ipairs(T.definitions) do choices[#choices+1]={value=theme.id,label=theme.label} end
    return choices
end
