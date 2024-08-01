local antiCrash = RegisterMod("AntiCrash", 1)
local json = require("json")

local VERSION = "1.17"

local showActivity = 0
local printWarning = 0
local printIncompatible = false
local printedIncompatible = false
local printIncompatibleReason = ""
local temporaryDisable = false
local debugMode = false
local showCount = false

-- Safe mode vars
-- TODO: unfinished, needs UI and more testing
-- local frameTime = 0
-- local frameCount = 0
-- local prevFrameTime = Isaac.GetTime()
-- local safeModeDisabled = false
-- local safeModeActivated = false

-- built-in entity caps:
-- tears: 512
-- bombs: 64
-- lasers: 128
-- projectiles: 512
-- effects: 1024, but also cause crashes

-- effect cap is per effect type, not global
-- tear limit only applies to the tear detonator
-- laser limit helps with super broken builds where lasers spawn too many additional effects
-- high: normal, low: SUPER mode
local entityLimits = nil
local highEntityLimits = {
    [EntityType.ENTITY_EFFECT] = 50,
    [EntityType.ENTITY_TEAR] = 128,
    [EntityType.ENTITY_LASER] = 40,
}
local lowEntityLimits = {
    [EntityType.ENTITY_EFFECT] = 0,
    [EntityType.ENTITY_TEAR] = 64,
    [EntityType.ENTITY_LASER] = 20,
}

-- these effects are unimportant, and as such, they won't spawn at all when AC is active
-- if this causes issues with your mod, let me know
local deletableEffects = {
    [EffectVariant.BOMB_EXPLOSION] = true,
    [EffectVariant.BLOOD_EXPLOSION] = true,
    [EffectVariant.BLOOD_DROP] = true,
    [EffectVariant.BLOOD_SPLAT] = true,
    [EffectVariant.BOMB_CRATER] = true,
    [EffectVariant.WATER_SPLASH] = true,
    [EffectVariant.POOF01] = true,
    [EffectVariant.BULLET_POOF] = true,
    [EffectVariant.TEAR_POOF_A] = true,
    [EffectVariant.TEAR_POOF_B] = true,
    [EffectVariant.CHAIN_LIGHTNING] = true,
    [EffectVariant.TEAR_POOF_SMALL] = true,
    [EffectVariant.TEAR_POOF_VERYSMALL] = true,
    [EffectVariant.LIGHT] = true,
    [EffectVariant.FALLING_EMBER] = true,
    [EffectVariant.DUST_CLOUD] = true,
    [EffectVariant.LASER_IMPACT] = true,
}

local persistentData = {}
local defaultConfig = {
    configVersion = 2,
    enabled = false,
    lastSeed = nil,
    exitedCleanly = true,
    disabledForSeed = false,
    saferTearDetonator = true,
    improveModCompatibility = false,
    superMode = false,
}

local itemCount = 0

function antiCrash:log(message)
    return Isaac.DebugString("[AntiCrash] " .. message)
end

-- callback for printing warnings
function antiCrash:onRender()
    -- hot reload fixes
    if (persistentData["configVersion"] == nil) then
        antiCrash:log("missing config, reloading")
        antiCrash:loadConfiguration()
    end    
    if entityLimits == nil then
        if (not persistentData["improveModCompatibility"]) then
            entityLimits = lowEntityLimits
        else
            entityLimits = highEntityLimits
        end
    end

    -- Safe mode (TODO unfinished)
    -- local currentTime = Isaac.GetTime()
    -- frameCount = frameCount + 1
    -- if (frameCount % 5 == 0) then
    --     frameTime = currentTime - prevFrameTime
    --     if (
    --         frameTime > 1000
    --         and Game():IsPaused() == false
    --     ) then
    --         antiCrash:log("slowdown detected, frame time was " .. frameTime)
    --         safeModeActivated = true
    --     end
    -- else
    --     prevFrameTime = currentTime
    -- end

    -- Safe mode UI
    -- if (safeModeActivated) then
    --     Isaac.RenderText("[ AntiCrash ]", 50, 30, 0.6, 0.10, 0.10, 0.9)
    --     Isaac.RenderText("Safe mode prompt text", 50, 45, 1, 1, 1, 0.9)
    --     Isaac.RenderText("Allan please add details", 50, 60, 0.5, 0.5, 0.5, 0.9)
    -- end

    -- UI
    if (not temporaryDisable and persistentData["enabled"]) then
        Isaac.RenderText("\007", 2, 260, 0.54, 0.37, 0.97, 0.6)
    end
    
    if (showActivity > 0) then
        Isaac.RenderText("\007", 2, 260, 0.6, 0.10, 0.10, showActivity / 100)
        showActivity = showActivity - 2
    end
    if (printWarning > 0) then
        Isaac.RenderText("[ AntiCrash ]", 50, 30, 0.6, 0.10, 0.10, 0.9)
        Isaac.RenderText("Game crash detected, mod is now active", 50, 45, 1, 1, 1, 0.9)
        Isaac.RenderText("Press Drop to keep disabled", 50, 60, 0.5, 0.5, 0.5, 0.9)
        printWarning = printWarning - 1
        if (
            persistentData["enabled"]
            and printWarning > 0
            and (
                Input.IsActionPressed(ButtonAction.ACTION_DROP, 0)
                or Input.IsActionPressed(ButtonAction.ACTION_DROP, 1)
                or Input.IsActionPressed(ButtonAction.ACTION_DROP, 2)
                or Input.IsActionPressed(ButtonAction.ACTION_DROP, 3)
                or Input.IsActionPressed(ButtonAction.ACTION_DROP, 4)
            )    
        ) then
            printWarning = 0
            persistentData["enabled"] = false
        end
    end
    if (printIncompatible and not (printedIncompatible)) then
        Isaac.RenderText("[ AntiCrash ]", 50, 30, 0.6, 0.10, 0.10, 0.9)
        Isaac.RenderText("Your build is known to cause crashes", 50, 45, 1, 1, 1, 0.9)
        Isaac.RenderText(printIncompatibleReason, 50, 60, 0.5, 0.5, 0.5, 0.9)
        Isaac.RenderText("Press Drop to dismiss.", 50, 75, 1, 1, 1, 0.9)
        if (
            Input.IsActionPressed(ButtonAction.ACTION_DROP, 0)
            or Input.IsActionPressed(ButtonAction.ACTION_DROP, 1)
            or Input.IsActionPressed(ButtonAction.ACTION_DROP, 2)
            or Input.IsActionPressed(ButtonAction.ACTION_DROP, 3)
            or Input.IsActionPressed(ButtonAction.ACTION_DROP, 4)
        ) then
            printedIncompatible = true
        end
    end
    if (showCount) then
        Isaac.RenderScaledText("[AntiCrash] Debug", 3, 235, 0.5, 0.5, 0.6, 0.1, 0.1, 1)
        -- Isaac.RenderScaledText("Frame time: " .. frameTime .. "ms", 3, 240, 0.5, 0.5, 1, 1, 1, 0.7)
        Isaac.RenderScaledText("Tears: " .. Isaac.CountEntities(nil, EntityType.ENTITY_TEAR) .. " (TD limit: " .. entityLimits[EntityType.ENTITY_TEAR] .. ")", 3, 245, 0.5, 0.5, 1, 1, 1, 0.7)
        Isaac.RenderScaledText("Lasers: " .. Isaac.CountEntities(nil, EntityType.ENTITY_LASER) .. " (limit: " .. entityLimits[EntityType.ENTITY_LASER] .. ")", 3, 250, 0.5, 0.5, 1, 1, 1, 0.7)
        Isaac.RenderScaledText("Effects: " .. Isaac.CountEntities(nil, EntityType.ENTITY_EFFECT) .. " (limit: " .. entityLimits[EntityType.ENTITY_EFFECT] .. ")", 3, 255, 0.5, 0.5, 1, 1, 1, 0.7)
    end
end

function antiCrash:debug(message, args)
    if (string.find(message, "acdebug")) then
        if (not debugMode) then
            print("Enabling debug mode")
            debugMode = true
        else
            print("Disabling debug mode")
            debugMode = false
        end
    elseif (string.find(message, "acshow")) then
        if (not showCount) then
            print("Enabling show count")
            showCount = true
        else
            print("Disabling show count")
            showCount = false
    end
    elseif (string.find(message, "acdisable")) then
        print("Disabling entity removal for current seed")
        antiCrash:log("State changed via console: false")
        persistentData["enabled"] = false
        persistentData["disabledForSeed"] = true
        antiCrash:SaveData(json.encode(persistentData))
    elseif (string.find(message, "acenable")) then
        print("Enabling entity removal")
        antiCrash:log("State changed via console: true")
        persistentData["enabled"] = true
        persistentData["disabledForSeed"] = false
        antiCrash:SaveData(json.encode(persistentData))
    elseif (string.find(message, "aclimit")) then
        local newLimit = tonumber(args)
        if (newLimit) then
            print("Setting entity limit to " .. newLimit)
            antiCrash:log("Setting entity limit to " .. newLimit)
            entityLimits[EntityType.ENTITY_EFFECT] = newLimit
        end
    elseif (string.find(message, "actest")) then
        print("This will stress your CPU, get ready...")
        antiCrash:log("Giving a stress-test item set")
        persistentData["enabled"] = true
        local items = {
            CollectibleType.COLLECTIBLE_ROCK_BOTTOM,
            CollectibleType.COLLECTIBLE_TRISAGION,
            CollectibleType.COLLECTIBLE_CRICKETS_BODY,
            CollectibleType.COLLECTIBLE_SOY_MILK,
            CollectibleType.COLLECTIBLE_ALMOND_MILK,
            CollectibleType.COLLECTIBLE_PARASITE,
            CollectibleType.COLLECTIBLE_MUTANT_SPIDER,
            CollectibleType.COLLECTIBLE_THE_WIZ,
            CollectibleType.COLLECTIBLE_INNER_EYE,
            CollectibleType.COLLECTIBLE_SAD_BOMBS,
            CollectibleType.COLLECTIBLE_BRIMSTONE,
            CollectibleType.COLLECTIBLE_BRIMSTONE,
            CollectibleType.COLLECTIBLE_DR_FETUS,
            CollectibleType.COLLECTIBLE_BRIMSTONE_BOMBS,
            CollectibleType.COLLECTIBLE_PYROMANIAC,
        }
        for i = 1, #items do
            Isaac.GetPlayer(0):AddCollectible(items[i], false)
        end
    end
end

function antiCrash:onEntityCreation(entityType, variant, _, _, _, _, seed)
    if (
        temporaryDisable
        or not persistentData["enabled"]
        or entityLimits[entityType] == nil
    ) then
        return
    end

    -- prevent certain effects from spawning
    if (
        entityType == EntityType.ENTITY_EFFECT
        and deletableEffects[variant]
        and not persistentData["improveModCompatibility"]
    ) then
        if (debugMode) then
            antiCrash:log("preventing spawn of 1000." .. variant)
        end
        return { EntityType.ENTITY_EFFECT, nil, 0, seed }
    end

    -- only remove tears when tear detonator is used
    if (entityType == EntityType.ENTITY_TEAR) then
        return nil
    end

    local currentCount = Isaac.CountEntities(nil, entityType, variant)

    if (currentCount < entityLimits[entityType]) then
        return nil
    else
        antiCrash:cleanUpEnts(currentCount, entityType, variant)
    end
end

function antiCrash:cleanUpEnts(currentCount, entityType, variant)
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if (entity.Type == entityType and entity.Variant == variant) then
            -- if effect, ensure it's in the list of deletable effects
            if (
                entityType == EntityType.ENTITY_EFFECT
                and not deletableEffects[variant]
            ) then
                return nil
            end
            
            showActivity = 100

            if (debugMode) then
                antiCrash:log("removing " .. entityType .. "." .. variant)
            end
            entity:Remove()
            currentCount = currentCount - 1
            if (currentCount < entityLimits[entityType]) then
                return nil
            end
        end
    end
end

-- incompatible item check
function antiCrash:postEffectUpdate(player)
    local currentItemCount = player:GetCollectibleCount()
    if (currentItemCount ~= itemCount) then
        itemCount = currentEntCount

        -- C Section + tear mimic familiar + freeze effect + melee = crash
        if (
            player:GetCollectibleNum(CollectibleType.COLLECTIBLE_C_SECTION) == 1
            and (
                player:GetCollectibleNum(CollectibleType.COLLECTIBLE_INCUBUS) == 1
                or player:GetCollectibleNum(CollectibleType.COLLECTIBLE_TWISTED_PAIR) == 1
            )
            and (
                player:GetCollectibleNum(CollectibleType.COLLECTIBLE_PLAYDOUGH_COOKIE) == 1
                or player:GetCollectibleNum(CollectibleType.COLLECTIBLE_URANUS) == 1
                or player:HasTrinket(TrinketType.TRINKET_ICE_CUBE)
            )
            and (
                player:GetCollectibleNum(CollectibleType.COLLECTIBLE_SPIRIT_SWORD) == 1
                or player:GetPlayerType() == PlayerType.PLAYER_THEFORGOTTEN
                or player:GetPlayerType() == PlayerType.PLAYER_THEFORGOTTEN_B
            )
        ) then
            printIncompatible = true
            printIncompatibleReason = "(C Section + freeze + tear mimic familiar + melee)"
            antiCrash:log("Player has an buggy item set (C Section + freeze + tear mimic familiar + melee)")
        end
    end
end

-- tear detonator is a special case as it multiplies entities too quickly
function antiCrash:preItemUse(collectible)
    if (persistentData["saferTearDetonator"] and collectible == CollectibleType.COLLECTIBLE_TEAR_DETONATOR) then
        local tearCount = Isaac.CountEntities(nil, EntityType.ENTITY_TEAR)
        if (tearCount > entityLimits[EntityType.ENTITY_TEAR]) then
            antiCrash:cleanUpEnts(tearCount, EntityType.ENTITY_TEAR, nil)
        end
    end
end

function antiCrash:loadConfiguration()
    if (antiCrash:HasData()) then
        persistentData = json.decode(antiCrash:LoadData())
    else
        persistentData = defaultConfig
    end

    antiCrash:log("ver. " .. VERSION .. " | config: " .. json.encode(persistentData))

    -- upgrade config if necessary
    if (persistentData["configVersion"] == nil or persistentData["configVersion"] ~= defaultConfig["configVersion"]) then
        antiCrash:log("Upgrading config to v" .. defaultConfig["configVersion"])
        persistentData["configVersion"] = defaultConfig["configVersion"]
        -- iterate over persistentData and add missing keys
        for key, value in pairs(defaultConfig) do
            if (persistentData[key] == nil) then
                persistentData[key] = value
            end
        end
    end

    antiCrash:SaveData(json.encode(persistentData))
end

-- crash detection functions
-- necessary as the performance hit is noticeable in normal gameplay
function antiCrash:onGameStart()
    antiCrash:loadConfiguration()

    if (not persistentData["enabled"] and not persistentData["exitedCleanly"]) then
        antiCrash:log("Did not exit cleanly, activating")
        printWarning = 650
        persistentData["enabled"] = true
    end

    local currentSeed = Game():GetSeeds():GetStartSeed()
    if (currentSeed ~= persistentData["lastSeed"]) then
        antiCrash:log("Seed changed, ensuring mod is disabled")
        persistentData["enabled"] = false
        printWarning = 0
        persistentData["lastSeed"] = currentSeed
        persistentData["disabledForSeed"] = false
    else
        if (persistentData["disabledForSeed"]) then
            antiCrash:log("Ignoring crash due to disabledForSeed")
            persistentData["enabled"] = false
            printWarning = 0
        end
    end

    persistentData["exitedCleanly"] = false

    antiCrash:SaveData(json.encode(persistentData))

    -- detect mod compat mode
    if (not persistentData["improveModCompatibility"]) then
        entityLimits = lowEntityLimits
    else
        entityLimits = highEntityLimits
    end
end

function antiCrash:onGameEnd()
    persistentData["exitedCleanly"] = true
    antiCrash:SaveData(json.encode(persistentData))
end

function antiCrash:onRoomChange()
    printWarning = 0

    -- disable in alt floor chase sequence due to unexplainable random crashing
    local roomName = Game():GetLevel():GetCurrentRoomDesc().Data.Name
    if (
        string.find(roomName, "Mineshaft")
        or roomName == "Knife Piece Room"
    ) then
        temporaryDisable = true
    else
        temporaryDisable = false
    end
end

-- Mod Config Menu Settings
if ModConfigMenu then
    local modSettings = "AntiCrash"

    -- avoid duplicating settings
    ModConfigMenu.RemoveCategory(modSettings)

    ModConfigMenu.UpdateCategory(modSettings, {
		Info = {"AntiCrash",}
	})

    ------ Title
    ModConfigMenu.AddText(modSettings, "Settings", function() return "AntiCrash" end)
	ModConfigMenu.AddSpace(modSettings, "Settings")

    ------ Settings
    -- Current status
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return persistentData["enabled"]
			end,
			Display = function()
				local onOff = "No"
				if persistentData["enabled"] then
					onOff = "Yes"
				end
				return 'Active: ' .. onOff
			end,
			OnChange = function(currentBool)
				antiCrash:log("State changed via mod menu: " .. tostring(currentBool))
                persistentData["enabled"] = currentBool
			end,
			Info = {"Choose whether AntiCrash should be enabled right now."}
	})
    -- Disable for current run
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return persistentData["disabledForSeed"]
			end,
			Display = function()
				local onOff = "No"
				if persistentData["disabledForSeed"] then
					onOff = "Yes"
				end
				return 'Disable for current run: ' .. onOff
			end,
			OnChange = function(currentBool)
                antiCrash:log("disabledForSeed changed to " .. tostring(currentBool))
				persistentData["disabledForSeed"] = currentBool
                antiCrash:SaveData(json.encode(persistentData))
			end,
			Info = {"Disable crash detection for current run."}
	})
    -- Safer tear detonator
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return persistentData["saferTearDetonator"]
			end,
			Display = function()
				local onOff = "Disabled"
				if persistentData["saferTearDetonator"] then
					onOff = "Enabled"
				end
				return 'Safer tear detonator: ' .. onOff
			end,
			OnChange = function(currentBool)
                antiCrash:log("saferTearDetonator changed to " .. tostring(currentBool))
				persistentData["saferTearDetonator"] = currentBool
                antiCrash:SaveData(json.encode(persistentData))
			end,
			Info = {"Limit how many tears Tear Detonator can spawn, making it safer with broken builds. Always active."}
	})
    -- Mod compatibility
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return persistentData["improveModCompatibility"]
			end,
			Display = function()
				local onOff = "No"
				if persistentData["improveModCompatibility"] then
					onOff = "Yes"
				end
				return 'Improve mod compatibility: ' .. onOff
			end,
			OnChange = function(currentBool)
                antiCrash:log("improveModCompatibility changed to " .. tostring(currentBool))
				persistentData["improveModCompatibility"] = currentBool
                antiCrash:SaveData(json.encode(persistentData))
                if currentBool then
                    entityLimits = highEntityLimits
                else
                    entityLimits = lowEntityLimits
                end
			end,
			Info = {"Disable optimizations to improve mod compatibility. Lowers performance."}
	})
    -- Mod compatibility
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return debugMode
			end,
			Display = function()
				local onOff = "No"
				if debugMode then
					onOff = "Yes"
				end
				return 'Debug mode: ' .. onOff
			end,
			OnChange = function(currentBool)
                antiCrash:log("debugMode changed to " .. tostring(currentBool))
				debugMode = currentBool
                showCount = currentBool
			end,
			Info = {"Enable verbose logging and additional on-screen info. Turns off after a game restart."}
	})
end

antiCrash:AddCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, antiCrash.onEntityCreation)
antiCrash:AddCallback(ModCallbacks.MC_POST_RENDER, antiCrash.onRender)
antiCrash:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, antiCrash.preItemUse)
antiCrash:AddCallback(ModCallbacks.MC_EXECUTE_CMD, antiCrash.debug)
antiCrash:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, antiCrash.postEffectUpdate)

antiCrash:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, antiCrash.onGameStart)
antiCrash:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, antiCrash.onGameEnd)
antiCrash:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, antiCrash.onRoomChange)
