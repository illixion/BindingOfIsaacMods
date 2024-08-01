local mod = RegisterMod("Static Bag of Crafting", 1)

local runSeed = ""
local seedChanged = false

-- set initial seed
function mod:onGameStart()
    runSeed = Seeds.Seed2String(Game():GetSeeds():GetStartSeed())
end

-- when game ends, reset seed
function mod:onGameEnd()
    if seedChanged then
        Game():GetSeeds():SetStartSeed(runSeed)
        seedChanged = false
    end
end

-- if entering new room with fixed seed, reset seed and put down the bag
function mod:undoSetSeed()
    if seedChanged then
        Game():GetSeeds():SetStartSeed(runSeed)
        seedChanged = false
        for playerId=0,5 do
            if Isaac.GetPlayer(playerId):IsHoldingItem() then
                -- this is dumb, but there's no other way to put down an active item
                Isaac.GetPlayer(playerId):UseActiveItem(CollectibleType.COLLECTIBLE_MOMS_BRACELET, 4, ActiveSlot.SLOT_PRIMARY)
            end
        end
    end
end

-- fix seed when using the bag
function mod:preUseItem(collectible, rng, player)
    if collectible == CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING then
        -- reversed, callback is called before held status is updated
        if player:IsHoldingItem() then
            Game():GetSeeds():SetStartSeed(runSeed)
            seedChanged = false    
        else
            Game():GetSeeds():SetStartSeed("RCNA TDJN")
            seedChanged = true
        end
    end
end

-- needed due to preUseItem not being triggered when bag is used and automatically put away
function mod:postEffect(player)
    -- runSeed auto-fix for luamod
    if runSeed == "" then
        runSeed = Seeds.Seed2String(Game():GetSeeds():GetStartSeed())
    end

    -- check that the player has the bag of crafting
    if (
        player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) ~= CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING
        and player:GetActiveItem(ActiveSlot.SLOT_POCKET) ~= CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING
    ) then
        return
    end

    -- //BUG: won't work with multiple bags on the screen (coop)
    if (
        seedChanged
        and not player:IsHoldingItem()
    ) then
        -- player is not holding the bag, reset seed
        Game():GetSeeds():SetStartSeed(runSeed)
        seedChanged = false
    end
end

function mod:debug(message, args)
    if (string.find(message, "sboctest")) then
        local items = {
            "5.90.3",
            "5.90.3",
            "5.90.3",
            "5.90.3",
            "5.20.5",
            "5.20.5",
            "5.20.5",
            "5.20.5",

        }
        for i = 1, #items do
            Isaac.ExecuteCommand("spawn " .. items[i])
        end
        print("Tech X (or random static item) recipe pickups spawned")
    end
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameEnd)
mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, mod.preUseItem)
mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.postEffect)
mod:AddCallback(ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, mod.undoSetSeed)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.undoSetSeed)
mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, mod.debug)
