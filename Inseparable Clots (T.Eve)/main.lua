local inseparableClots = RegisterMod("Inseparable Clots (T.Eve)", 1)
local json = require("json")

-- variables
local ICSettings = {
    ["tetherLength"] = 1.7,
    ["teleportDistance"] = 0.4,
    ["pushForce"] = 0.2,
    ["disableTEve"] = false,
}
local playerId = nil

-- callbacks
function inseparableClots:postGameEnd()
    playerId = nil
end

function inseparableClots:postPlayerInit(player)
    local numPlayers = Game():GetNumPlayers()

    if (numPlayers == 1) then
        if (
            ICSettings["disableTEve"]
            and player:GetPlayerType() == 26
        ) then
            return
        end
        
        playerId = 0
        return
    end

    for i = 0, numPlayers do
        local iplayer = Isaac.GetPlayer(i)

        if (
            not ICSettings["disableTEve"]
            and iplayer:GetPlayerType() == 26
        ) then
            playerId = i
        end
    end
end


-- main functions
function inseparableClots:onUpdate()
    if (
        Input.IsActionPressed(ButtonAction.ACTION_DROP, 0)
        or Input.IsActionPressed(ButtonAction.ACTION_DROP, 1)
        or Input.IsActionPressed(ButtonAction.ACTION_DROP, 2)
        or Input.IsActionPressed(ButtonAction.ACTION_DROP, 3)
        or Input.IsActionPressed(ButtonAction.ACTION_DROP, 4)
        or type(playerId) == "nil"
    ) then
        return
    end

    -- calculate length of tether
    local familiarCount = Isaac.CountEntities(nil, EntityType.ENTITY_FAMILIAR)
    if (familiarCount < 15) then
        familiarCount = 15
    end
    local tetherLength = familiarCount * ICSettings["tetherLength"]
    local teleportDistance = tetherLength + (tetherLength * ICSettings["teleportDistance"])

    for i, entity in ipairs(Isaac.GetRoomEntities()) do
        if (
            entity.Type == 3 and
            entity.Variant == 238
        ) then
            inseparableClots:handlePhysics(Isaac.GetPlayer(playerId), entity, tetherLength, teleportDistance)
        end
    end
end

function inseparableClots:handlePhysics(player, clot, tetherLength, teleportDistance)
    if (type(playerId) == "nil") then return end

    -- do nothing if within tether length
    if (player.Position:Distance(clot.Position) < tetherLength) then
        return
    end

    -- if characters are too far away, teleport them back
    if (player.Position:Distance(clot.Position) > teleportDistance) then
        inseparableClots:teleportToPlayer(player, clot)
    else
        -- if tethered but not far away (stuck on something), smoothly return
        local mainPos = player.Position
        local subPos = clot.Position
        local distance = mainPos:Distance(subPos) - tetherLength
        if (distance > 0) then
            clot.Velocity = clot.Velocity + (mainPos - subPos):Normalized() * distance *
                                      ICSettings["pushForce"] * player.MoveSpeed
        end
    end
end

function inseparableClots:teleportToPlayer(destination, target)
    target.Position = destination.Position + (target.Position - destination.Position):Normalized() * 30
    target.Velocity = (destination.Position - target.Position):Normalized() * 3
end


-- Mod Config Menu Settings
if ModConfigMenu then
    local modSettings = "Inseparable Clots"

    -- avoid duplicating settings
    ModConfigMenu.RemoveCategory(modSettings)

    ModConfigMenu.UpdateCategory(modSettings, {
		Info = {"Inseparable Clots",}
	})

    ------ Title
    ModConfigMenu.AddText(modSettings, "Settings", function() return "Inseparable Clots" end)
	ModConfigMenu.AddSpace(modSettings, "Settings")

    ------ Settings

    -- Disable for Tainted Eve
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return ICSettings["disableTEve"]
			end,
			Display = function()
				local onOff = "No"
				if ICSettings["disableTEve"] then
					onOff = "Yes"
				end
				return 'Disable for Tainted Eve: ' .. onOff
			end,
			OnChange = function(currentBool)
				ICSettings["disableTEve"] = currentBool
                if (currentBool) then
                    playerId = nil
                else
                    playerId = 0
                end

                inseparableClots:SaveData(json.encode(ICSettings))
            end,
			Info = {"Disable tetheting when playing Tainted Eve."}
	})
    -- Tether length
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return ICSettings["tetherLength"]
			end,
			Minimum = 0,
			Maximum = 50,
			Display = function()
				return "Tether length: " .. ICSettings["tetherLength"]
			end,
			OnChange = function(currentNum)
				ICSettings["tetherLength"] = currentNum
                inseparableClots:SaveData(json.encode(ICSettings))
			end,
			Info = {"Tether length", "Default: 25"}
	})
    -- Teleport distance
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return ICSettings["teleportDistance"]
			end,
			Minimum = 0,
			Maximum = 120,
			Display = function()
				return "Teleport distance: " .. ICSettings["teleportDistance"]
			end,
			OnChange = function(currentNum)
				ICSettings["teleportDistance"] = currentNum
                inseparableClots:SaveData(json.encode(ICSettings))
			end,
			Info = {"Teleport characters back together if they teleport further than this distance", "Default: 60"}
	})
    -- Push force
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return ICSettings["pushForce"] * 100
			end,
			Minimum = 1,
			Maximum = 40,
			Display = function()
				return "Push force: " .. ICSettings["pushForce"] * 100
			end,
			OnChange = function(currentNum)
				ICSettings["pushForce"] = currentNum / 100
                inseparableClots:SaveData(json.encode(ICSettings))
			end,
			Info = {"Gravitational force between characters", "Default: 20"}
	})
end

-- Mod Config Menu save/load
function inseparableClots:onGameStart()
    if (inseparableClots:HasData()) then
        ICSettings = json.decode(inseparableClots:LoadData())
    else
        inseparableClots:SaveData(json.encode(ICSettings))
    end
end


inseparableClots:AddCallback(ModCallbacks.MC_POST_UPDATE, inseparableClots.onUpdate)
inseparableClots:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, inseparableClots.postGameEnd)
inseparableClots:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, inseparableClots.postPlayerInit)
inseparableClots:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, inseparableClots.onGameStart)
