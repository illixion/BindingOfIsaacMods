local ClassicTEve = RegisterMod("Classic Tainted Eve", 1)

function ClassicTEve:onEveryFrame(familiar)
    if (familiar.Variant == FamiliarVariant.BLOOD_BABY) then
        local clotData = familiar:GetData()
        if (clotData.prevHP == nil) then
            clotData.prevHP = familiar.HitPoints
        else
            local damageTaken = clotData.prevHP - familiar.HitPoints
            if (damageTaken > 0.19 and damageTaken < 0.21) then
                familiar.HitPoints = familiar.HitPoints + damageTaken
            elseif (damageTaken > 1.19 and damageTaken < 1.21) then
                familiar.HitPoints = familiar.HitPoints - 1.0
            else
                clotData.prevHP = familiar.HitPoints
            end
        end
    end
    
end

ClassicTEve:AddCallback(ModCallbacks.MC_POST_FAMILIAR_RENDER, ClassicTEve.onEveryFrame)
