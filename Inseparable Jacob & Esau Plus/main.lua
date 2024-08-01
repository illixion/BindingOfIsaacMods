local InseparableJEPlus = RegisterMod("Inseparable Jacob & Esau Plus", 1)
local json = require("json")

local IJEPSettings = {}
local defaultConfig = {
    configVersion = 2,
    tetherLength = 25,
    activationDistance = 50,
    teleportDistance = 60,
    pushForce = 0.2,
    alternativeBind = false,
    allowCustomCharacters = false,
    persistentTether = true,
}

local characters = {
    { characterEntities = {}, tetherStatus = false },
    { characterEntities = {}, tetherStatus = false },
    { characterEntities = {}, tetherStatus = false },
    { characterEntities = {}, tetherStatus = false },
    { characterEntities = {}, tetherStatus = false },
}
local printBabyWarning = false
local printedBabyWarning = false
local printLimitedCoopWarning = false
local printedLimitedCoopWarning = false

-- callbacks
function InseparableJEPlus:debug(message)
    if (string.find(message, "printcharacters")) then
        for k, v in pairs(characters) do
            local out = {}
            print("Player " .. k .. ", tether: " .. tostring(v.tetherStatus) .. ", ents: ")
            if (#v.characterEntities ~= 0) then
                for x, y in pairs(v.characterEntities) do
                    if (y == nil) then
                        table.insert(out, "[ignored]")
                    else
                        table.insert(out, y:GetName())
                    end
                end
                print(table.concat(out, ", "))
            end
        end
    end
end

-- stop when not in game
function InseparableJEPlus:postGameEnd()
    characters = {
        { characterEntities = {}, tetherStatus = false },
        { characterEntities = {}, tetherStatus = false },
        { characterEntities = {}, tetherStatus = false },
        { characterEntities = {}, tetherStatus = false },
        { characterEntities = {}, tetherStatus = false },
    }
end

-- callback for printing warnings
function InseparableJEPlus:onRender()
    if (printBabyWarning and not (printedBabyWarning)) then
        if (
            InseparableJEPlus:checkBindPressed(0)
            or InseparableJEPlus:checkBindPressed(1)
            or InseparableJEPlus:checkBindPressed(2)
            or InseparableJEPlus:checkBindPressed(3)
            or InseparableJEPlus:checkBindPressed(4)
        ) then
            printedBabyWarning = true
        end
        Isaac.RenderText("Inseparable J&E+", 50, 30, 0.9, 0, 0, 0.8)
        Isaac.RenderText("Co-op babies are not supported.", 50, 45, 0.9, 0, 0, 0.8)
        Isaac.RenderText("Press Drop to dismiss.", 50, 60, 0.9, 0, 0, 0.8)
        return
    end
    if (printLimitedCoopWarning and not (printedLimitedCoopWarning)) then
        if (
            InseparableJEPlus:checkBindPressed(0)
            or InseparableJEPlus:checkBindPressed(1)
            or InseparableJEPlus:checkBindPressed(2)
            or InseparableJEPlus:checkBindPressed(3)
            or InseparableJEPlus:checkBindPressed(4)
        ) then
            printedLimitedCoopWarning = true
        end
        Isaac.RenderText("Inseparable J&E+", 50, 30, 0.9, 0, 0, 0.8)
        Isaac.RenderText("This mod doesn't support >4 players in-game.", 50, 45, 0.9, 0, 0, 0.8)
        Isaac.RenderText("Press Drop to dismiss.", 50, 60, 0.9, 0, 0, 0.8)
    end
end

-- main function
function InseparableJEPlus:onEveryFrame(player)
    local amountOfPlayers = Isaac.CountEntities(nil, EntityType.ENTITY_PLAYER)

    if (amountOfPlayers == 1 and #characters[player.ControllerIndex + 1].characterEntities == 1) then
        return
    end

    -- hot reload fix
    if (IJEPSettings["configVersion"] == nil) then
        InseparableJEPlus:loadConfiguration()
    end

    -- maintain player lists for physics interactions
    if (amountOfPlayers ~= (#characters[player.ControllerIndex + 1].characterEntities)) then
        characters = {
            { characterEntities = {}, tetherStatus = false },
            { characterEntities = {}, tetherStatus = false },
            { characterEntities = {}, tetherStatus = false },
            { characterEntities = {}, tetherStatus = false },
            { characterEntities = {}, tetherStatus = false },
        }
        for i = 1, amountOfPlayers do
            local cPlayer = Isaac.GetPlayer(i - 1)

            -- future proofing
            if (cPlayer.ControllerIndex >= 5) then
                if (not (printLimitedCoopWarning)) then
                    printLimitedCoopWarning = true
                end
                return
            end

            -- stop if there's a coop baby in game
            -- needed due to a bug where the game gets confused who is playing on which controller
            if (cPlayer:GetBabySkin() ~= -1) then
                printBabyWarning = true
                return
            end

            -- disable mod for custom characters and all variants of The Forgotten
            if (
                (
                    cPlayer:GetPlayerType() >= 41
                    and not IJEPSettings["allowCustomCharacters"]
                )
                or cPlayer:GetPlayerType() == PlayerType.PLAYER_THEFORGOTTEN
                or cPlayer:GetPlayerType() == PlayerType.PLAYER_THESOUL
                or cPlayer:GetPlayerType() == PlayerType.PLAYER_THEFORGOTTEN_B
                or cPlayer:GetPlayerType() == PlayerType.PLAYER_THESOUL_B
            ) then
                table.insert(characters[cPlayer.ControllerIndex + 1].characterEntities, nil)
                return
            end

            table.insert(characters[cPlayer.ControllerIndex + 1].characterEntities, cPlayer)
        end
    end

    -- if drop button is pressed, disable tether
    if InseparableJEPlus:checkBindPressed(0) then
        characters[1].tetherStatus = false
    end
    if InseparableJEPlus:checkBindPressed(1) then
        characters[2].tetherStatus = false
    end
    if InseparableJEPlus:checkBindPressed(2) then
        characters[3].tetherStatus = false
    end
    if InseparableJEPlus:checkBindPressed(3) then
        characters[4].tetherStatus = false
    end
    if InseparableJEPlus:checkBindPressed(4) then
        characters[5].tetherStatus = false
    end

    for i, character in ipairs(characters) do
        for y, characterEntity in ipairs(character.characterEntities) do
            if (not (character.characterEntities[y - 1] == nil)) then
                InseparableJEPlus:handlePhysics(character.characterEntities[1], characterEntity, i - 1)
            end
        end
    end
end

-- physics functions
function InseparableJEPlus:handlePhysics(mainPlayer, subPlayer, controllerIndex)
    if (mainPlayer == nil or subPlayer == nil) then return end

    if (mainPlayer.Position:Distance(subPlayer.Position) < IJEPSettings["activationDistance"] and
        not characters[controllerIndex + 1].tetherStatus and
        not InseparableJEPlus:checkBindPressed(controllerIndex)) then
            characters[controllerIndex + 1].tetherStatus = true
    end

    -- do nothing if not tethered
    if (not (characters[controllerIndex + 1].tetherStatus)) then
        return
    end

    -- do nothing if within tether length
    if (mainPlayer.Position:Distance(subPlayer.Position) < IJEPSettings["tetherLength"]) then
        return
    end

    -- if characters are too far away, teleport them back
    if (mainPlayer.Position:Distance(subPlayer.Position) > IJEPSettings["teleportDistance"]) then
        -- if persistentTether is enabled, teleport both characters, otherwise untether
        if (IJEPSettings["persistentTether"]) then
            InseparableJEPlus:teleportToPlayer(mainPlayer, subPlayer)
        else
            characters[controllerIndex + 1].tetherStatus = false
        end
    else
        -- if tethered but not far away (stuck on something), smoothly return
        local mainPos = mainPlayer.Position
        local subPos = subPlayer.Position
        local distance = mainPos:Distance(subPos) - IJEPSettings["tetherLength"]
        if (distance > 0) then
            subPlayer.Velocity = subPlayer.Velocity + (mainPos - subPos):Normalized() * distance *
                                      IJEPSettings["pushForce"] * mainPlayer.MoveSpeed
        end
    end
end

function InseparableJEPlus:teleportToPlayer(destination, target)
    target.Position = destination.Position + (target.Position - destination.Position):Normalized() * 30
    target.Velocity = (destination.Position - target.Position):Normalized() * 3
end

function InseparableJEPlus:checkBindPressed(controllerIndex)
    if IJEPSettings["alternativeBind"] then
        if (
            Input.IsButtonPressed(ModConfigMenu.Config["Inseparable J&E +"]["keyboardBind"], controllerIndex)
            or Input.IsButtonPressed(ModConfigMenu.Config["Inseparable J&E +"]["controllerBind"], controllerIndex)
        ) then
            return true
        end

        if (
            Input.IsActionPressed(ButtonAction.ACTION_DROP, controllerIndex)
            and ModConfigMenu.Config["Inseparable J&E +"]["respectDropKey"]
        ) then
            return true
        end
    else
        return Input.IsActionPressed(ButtonAction.ACTION_DROP, controllerIndex)
    end
end

-- Mod Config Menu Settings
if ModConfigMenu then
    local modSettings = "Inseparable J&E +"

    -- avoid duplicating settings
    ModConfigMenu.RemoveCategory(modSettings)

    ModConfigMenu.UpdateCategory(modSettings, {
		Info = {"Inseparable Jacob & Esau Plus",}
	})

    ------ Title
    ModConfigMenu.AddText(modSettings, "Settings", function() return "Inseparable Jacob & Esau Plus" end)
	ModConfigMenu.AddSpace(modSettings, "Settings")

    ------ Settings

    -- Tether length
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return IJEPSettings["tetherLength"]
			end,
			Minimum = 0,
			Maximum = 50,
			Display = function()
				return "Tether length: " .. IJEPSettings["tetherLength"]
			end,
			OnChange = function(currentNum)
				IJEPSettings["tetherLength"] = currentNum
			end,
			Info = {"Tether length", "Default: 25"}
	})
    -- Activation distance
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return IJEPSettings["activationDistance"]
			end,
			Minimum = 0,
			Maximum = 100,
			Display = function()
				return "Activation distance: " .. IJEPSettings["activationDistance"]
			end,
			OnChange = function(currentNum)
				IJEPSettings["activationDistance"] = currentNum
			end,
			Info = {"Distance at which the tether is activated", "Default: 50"}
	})
    -- Teleport distance
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return IJEPSettings["teleportDistance"]
			end,
			Minimum = 0,
			Maximum = 120,
			Display = function()
				return "Teleport distance: " .. IJEPSettings["teleportDistance"]
			end,
			OnChange = function(currentNum)
				IJEPSettings["teleportDistance"] = currentNum
			end,
			Info = {"Teleport characters back together if they teleport further than this distance", "Default: 60"}
	})
    -- Push force
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function()
				return IJEPSettings["pushForce"] * 100
			end,
			Minimum = 1,
			Maximum = 40,
			Display = function()
				return "Push force: " .. IJEPSettings["pushForce"] * 100
			end,
			OnChange = function(currentNum)
				IJEPSettings["pushForce"] = currentNum / 100
			end,
			Info = {"Gravitational force between characters", "Default: 20"}
	})
    -- Persistent tether
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return IJEPSettings["persistentTether"]
			end,
			Display = function()
				local onOff = "No"
				if IJEPSettings["persistentTether"] then
					onOff = "Yes"
				end
				return 'Persistent tether: ' .. onOff
			end,
			OnChange = function(currentBool)
				IJEPSettings["persistentTether"] = currentBool
            end,
			Info = {"Tether never breaks, including when one of the characters teleports or flies away"}
	})
    -- Custom characters
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return IJEPSettings["allowCustomCharacters"]
			end,
			Display = function()
				local onOff = "No"
				if IJEPSettings["allowCustomCharacters"] then
					onOff = "Yes"
				end
				return 'Custom characters: ' .. onOff
			end,
			OnChange = function(currentBool)
				IJEPSettings["allowCustomCharacters"] = currentBool
            end,
			Info = {"Enable mod for custom characters"}
	})
    -- Alternative bind
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return IJEPSettings["alternativeBind"]
			end,
			Display = function()
				local onOff = "No"
				if IJEPSettings["alternativeBind"] then
					onOff = "Yes"
				end
				return 'Alternative binds: ' .. onOff
			end,
			OnChange = function(currentBool)
				IJEPSettings["alternativeBind"] = currentBool
                InseparableJEPlus:addKeybindOptions(currentBool)
            end,
			Info = {"Use custom buttons instead of the drop key.", "Note: this doesn't change the default drop key behavior"}
	})
end

function InseparableJEPlus:addKeybindOptions(addInsteadOfRemove)
    if ModConfigMenu then
        local modSettings = "Inseparable J&E +"
        if addInsteadOfRemove then
            -- Keyboard bind
            ModConfigMenu.AddKeyboardSetting(
                modSettings,
                "Settings",
                "keyboardBind",
                0,
                "Keyboard bind",
                true,
                "Determines which key should disable the tether",
                false
            )
            -- Controller bind
            ModConfigMenu.AddControllerSetting(
                modSettings,
                "Settings",
                "controllerBind",
                0,
                "Controller bind",
                true,
                "Determines which key should disable the tether",
                false
            )
            -- Respect drop key
            ModConfigMenu.AddBooleanSetting(
                modSettings,
                "Settings",
                "respectDropKey",
                true,
                "Respect drop key: ",
                {[true]="Yes",[false]="No"},
                "Pressing the drop key will also disable the tether",
                false
            )
        else
            ModConfigMenu.RemoveSetting(modSettings, "Settings", "keyboardBind")
            ModConfigMenu.RemoveSetting(modSettings, "Settings", "controllerBind")
            ModConfigMenu.RemoveSetting(modSettings, "Settings", "respectDropKey")
        end
    end
end

-- Mod Config Menu save/load
function InseparableJEPlus:onGameStart()
    InseparableJEPlus:loadConfiguration()
end

function InseparableJEPlus:loadConfiguration()
    if (InseparableJEPlus:HasData()) then
        IJEPSettings = json.decode(InseparableJEPlus:LoadData())
        InseparableJEPlus:addKeybindOptions(IJEPSettings["alternativeBind"])
    else
        IJEPSettings = defaultConfig
    end

    -- upgrade config if necessary
    if (IJEPSettings["configVersion"] == nil or IJEPSettings["configVersion"] ~= defaultConfig["configVersion"]) then
        print("[IJEP+] Upgrading config to v" .. defaultConfig["configVersion"])
        IJEPSettings["configVersion"] = defaultConfig["configVersion"]
        -- iterate over IJEPSettings and add missing keys
        for key, value in pairs(defaultConfig) do
            if (IJEPSettings[key] == nil) then
                IJEPSettings[key] = value
            end
        end
    end

    InseparableJEPlus:SaveData(json.encode(IJEPSettings))
end

function InseparableJEPlus:onGameEnd()
    InseparableJEPlus:SaveData(json.encode(IJEPSettings))
end

InseparableJEPlus:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, InseparableJEPlus.onEveryFrame)
InseparableJEPlus:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, InseparableJEPlus.postGameEnd)
InseparableJEPlus:AddCallback(ModCallbacks.MC_EXECUTE_CMD, InseparableJEPlus.debug)
InseparableJEPlus:AddCallback(ModCallbacks.MC_POST_RENDER, InseparableJEPlus.onRender)
InseparableJEPlus:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, InseparableJEPlus.onGameStart)
InseparableJEPlus:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, InseparableJEPlus.onGameEnd)
