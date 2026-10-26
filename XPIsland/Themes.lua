local _, ns = ...
local media="Interface\\AddOns\\XPIsland\\media\\"
local T={default="modern", definitions={}}
ns.Themes=T
-- Ordered, complete definitions. Add themes here; IDs are persisted in profiles.
-- Definitions are static after addon loading. User fonts/colors remain separate.
T.definitions={
    {id="modern",label="Modern",headerHeight=34,headerInset=14,labelGap=12,segmentHeight=10,segmentGap=2,
     outerRadius=17,innerRadius=16,optionsBorder="thin",
     palette={surface={.035,.04,.055,.97},border={.19,.20,.23,1},accent={.86,.79,.63,1},text={.93,.94,.97,1},muted={.65,.65,.68,1}},
     trackColor={.14,.14,.18},trackAlpha=1,dividerColor={.18,.18,.22,1},
     capTexture=media.."cap.tga",shadingAlpha=0},
    {id="forever",label="Forever",headerHeight=28,headerInset=10,labelGap=8,segmentHeight=10,segmentGap=3,
     segmentBorder={size=1,top={.57,.44,.25,1},bottom={.24,.17,.09,1},side={.39,.28,.15,1}},
     chromeTexture=media.."forever-chrome.tga",chromeRadius=6,
     optionsBorder="dialog",
     palette={surface={.08,.065,.045,.97},border={.57,.44,.25,1},accent={.83,.72,.49,1},text={.94,.90,.80,1},muted={.7,.65,.55,1}},
     trackColor={.24,.23,.21},trackAlpha=.85,dividerColor={.32,.25,.14,1},
     capTexture=media.."soft-cap.tga",
     shadingTexture=media.."theme-shading.tga",capShadingTexture=media.."soft-cap-shading.tga",shadingAlpha=.3},
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
