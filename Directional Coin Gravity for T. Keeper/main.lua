local directionalCoins = RegisterMod("Directional Coin Gravity for T. Keeper", 1)
local json = require("json")

local persistentSettings = {
    balancedMode = true,
}

-- callback functions
function directionalCoins:postEffect(player)
    -- if not tainted keeper, return
    if (player:GetPlayerType() ~= PlayerType.PLAYER_KEEPER_B) then
        return
    end

    -- if full health, return
    if (persistentSettings["balancedMode"] and (player:GetHearts() == player:GetHeartLimit())) then
        return
    end

    -- scan room for coins
    for i, entity in ipairs(Isaac.GetRoomEntities()) do
        if (entity.Type == 5 and entity.Variant == 20) then
            -- only change velocity for the first couple of frames to prevent magnet effect
            local coinData = entity:GetData()
            if (coinData.framesHandled == nil) then
                coinData.framesHandled = 0
            elseif (coinData.framesHandled <= 10) then
                coinData.framesHandled = coinData.framesHandled + 1
            else
                return
            end

            directionalCoins:handlePhysics(entity, player)
        end
    end
end

function directionalCoins:onGameStart()
    if (directionalCoins:HasData()) then
        persistentSettings = json.decode(directionalCoins:LoadData())
    end
end

-- physics function
function directionalCoins:handlePhysics(entity, player)
    -- get player position
    local x = Isaac.GetPlayer(0).Position.X
    local y = Isaac.GetPlayer(0).Position.Y
    local playerPosition = Vector(x, y)

    -- get direction to player
    local directionToPlayer = playerPosition - entity.Position
    directionToPlayer:Normalize()

    -- get distance to player
    local distanceToPlayer = entity.Position:Distance(playerPosition)

    -- calculate new velocity
    local newVelocity = entity.Velocity + directionToPlayer * distanceToPlayer
    newVelocity:Normalize()
    newVelocity = newVelocity * entity.Velocity:Length()

    -- set new velocity
    entity.Velocity = newVelocity
end

-- Mod Config Menu Settings
if ModConfigMenu then
    local modSettings = "Directional Coin Gravity"

    -- avoid duplicating settings
    ModConfigMenu.RemoveCategory(modSettings)

    ModConfigMenu.UpdateCategory(modSettings, {
		Info = {"Directional Coin Gravity",}
	})

    ------ Title
    ModConfigMenu.AddText(modSettings, "Settings", function() return "Directional Coin Gravity" end)
	ModConfigMenu.AddSpace(modSettings, "Settings")

    ------ Settings
    -- Current status
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return persistentSettings["balancedMode"]
			end,
			Display = function()
				local onOff = "No"
				if persistentSettings["balancedMode"] then
					onOff = "Yes"
				end
				return 'Balanced mode: ' .. onOff
			end,
			OnChange = function(currentBool)
				persistentSettings["balancedMode"] = currentBool
                directionalCoins:SaveData(json.encode(persistentSettings))
			end,
			Info = {"Attempt to balance the mod by only affecting coins when the player is hurt."}
	})
end

-- callback registrations
directionalCoins:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, directionalCoins.postEffect)
directionalCoins:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, directionalCoins.onGameStart)
