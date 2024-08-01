local autoUseActive = RegisterMod("Active Auto Use", 1)
local json = require("json")

local autoUseActiveStatus = {
    { holdTimer = 0, autoUseActive = false, collectibleId = nil, render = true },
    { holdTimer = 0, autoUseActive = false, collectibleId = nil, render = true },
    { holdTimer = 0, autoUseActive = false, collectibleId = nil, render = true },
    { holdTimer = 0, autoUseActive = false, collectibleId = nil, render = true },
    { holdTimer = 0, autoUseActive = false, collectibleId = nil, render = true },
}

local persistentData = {
    ignoreCharacterCheck = false,
    ignoreAllChecks = false,
}

local playerToTextCoords = {
    { x = 9, y = 26 },
    { x = 43, y = 28 },
    { x = 43, y = 34 },
    { x = 43, y = 40 },
    { x = 43, y = 46 },
}

local initialControllerOffset = nil
local SFX = SFXManager()

function autoUseActive:debug(message, args)
    if (string.find(message, "auadbg")) then
        print("[Auto Use Active] Fixing offset to " .. args)
        if (type(initialControllerOffset) == "nil") then
            initialControllerOffset = args
        end
    end
end

function autoUseActive:onRender()
    -- render the auto use active status
    for i, status in ipairs(autoUseActiveStatus) do
        if (status.render and status.autoUseActive) then
            if (i == 1) then
                Isaac.RenderScaledText("auto use", playerToTextCoords[i].x + (Options.HUDOffset * 20) + Game().ScreenShakeOffset.X, playerToTextCoords[i].y + (Options.HUDOffset * 12) + Game().ScreenShakeOffset.Y, 0.5, 0.5, 1, 0.5, 0, 0.8)
            else
                Isaac.RenderScaledText("P" .. i .. ": auto use", playerToTextCoords[i].x + (Options.HUDOffset * 20) + Game().ScreenShakeOffset.X, playerToTextCoords[i].y + (Options.HUDOffset * 12) + Game().ScreenShakeOffset.Y, 0.5, 0.5, 1, 0.5, 0, 0.3)
            end
        end
    end
end

function autoUseActive:postGameStart()
    if (autoUseActive:HasData()) then
        persistentData = json.decode(autoUseActive:LoadData())
    end

    -- Isaac provides no way to determine if the first player is using a keyboard or a controller
    -- so we need to determine this manually    
    local player = Isaac.GetPlayer(0)
    if (player.ControllerIndex == 0) then
        initialControllerOffset = 1
    else
        initialControllerOffset = 0
    end
end

function autoUseActive:postGameEnd()
    autoUseActiveStatus = {
        { holdTimer = 0, autoUseActive = false, collectibleId = nil, render = true },
        { holdTimer = 0, autoUseActive = false, collectibleId = nil, render = true },
        { holdTimer = 0, autoUseActive = false, collectibleId = nil, render = true },
        { holdTimer = 0, autoUseActive = false, collectibleId = nil, render = true },
        { holdTimer = 0, autoUseActive = false, collectibleId = nil, render = true },
    }
    initialControllerOffset = nil
end

function autoUseActive:onPlayerUpdate(player)
    local playerType = player:GetPlayerType()
    if (persistentData["ignoreAllChecks"] or persistentData["ignoreCharacterCheck"]) then
        playerType = 0
    end

    if (
        type(player.ControllerIndex) == "nil"
        or type(initialControllerOffset) == "nil"
        or playerType >= 41
        or playerType == 19
        or playerType == 20
    ) then return end

    -- do nothing if no active, active doesn't have a charge bar or another active was picked up
    -- also ignore items that you wouldn't want to auto use (breath of life and spin to win)
    local playerIndex = player.ControllerIndex + initialControllerOffset
    if (
        persistentData["ignoreAllChecks"]
        or (
            autoUseActiveStatus[playerIndex].collectibleId ~= nil
            and player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) ~= autoUseActiveStatus[playerIndex].collectibleId
            and player:GetActiveItem(ActiveSlot.SLOT_SECONDARY) ~= autoUseActiveStatus[playerIndex].collectibleId
        )
    ) then
        if (autoUseActiveStatus[playerIndex].autoUseActive) then
            autoUseActiveStatus[playerIndex].autoUseActive = false
            autoUseActiveStatus[playerIndex].holdTimer = 0
            autoUseActiveStatus[playerIndex].collectibleId = nil
        end
        return
    else
        if (
            player:GetActiveItem() == 0
            or (player:GetActiveCharge() == 0 and not player:NeedsCharge())
            or (
                autoUseActiveStatus[playerIndex].collectibleId ~= nil
                and player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) ~= autoUseActiveStatus[playerIndex].collectibleId
                and player:GetActiveItem(ActiveSlot.SLOT_SECONDARY) ~= autoUseActiveStatus[playerIndex].collectibleId
            )
            or player:GetActiveItem() == CollectibleType.COLLECTIBLE_BREATH_OF_LIFE
            or player:GetActiveItem() == CollectibleType.COLLECTIBLE_SPIN_TO_WIN
            or player:GetActiveItem() == CollectibleType.COLLECTIBLE_NOTCHED_AXE
            or player:GetActiveItem() == CollectibleType.COLLECTIBLE_ERASER
            or player:GetActiveItem() == CollectibleType.COLLECTIBLE_MOMS_BRACELET
            or player:GetActiveItem() == CollectibleType.COLLECTIBLE_RED_KEY
            or player:GetActiveItem() == CollectibleType.COLLECTIBLE_URN_OF_SOULS
            or player:GetActiveItem() == CollectibleType.COLLECTIBLE_ISAACS_TEARS
        ) then
            if (autoUseActiveStatus[playerIndex].autoUseActive) then
                autoUseActiveStatus[playerIndex].autoUseActive = false
                autoUseActiveStatus[playerIndex].holdTimer = 0
                autoUseActiveStatus[playerIndex].collectibleId = nil
            end
            return
        end
    end

    if (Input.IsActionPressed(ButtonAction.ACTION_ITEM, player.ControllerIndex)) then
        autoUseActiveStatus[playerIndex].holdTimer = autoUseActiveStatus[playerIndex].holdTimer + 1
    else
        autoUseActiveStatus[playerIndex].holdTimer = 0
    end

    if (autoUseActiveStatus[playerIndex].holdTimer == 30) then
        SFX:Play(SoundEffect.SOUND_UNLOCK00, 0.5, 2, false, 1.5)
        autoUseActiveStatus[playerIndex].autoUseActive = not autoUseActiveStatus[playerIndex].autoUseActive
        autoUseActiveStatus[playerIndex].collectibleId = player:GetActiveItem()
    end

    -- determine which slot the item is currently in
    local activeSlot = nil
    if (player:GetActiveItem(ActiveSlot.SLOT_PRIMARY) == autoUseActiveStatus[playerIndex].collectibleId) then
        activeSlot = ActiveSlot.SLOT_PRIMARY
        autoUseActiveStatus[playerIndex].render = true
    else
        activeSlot = ActiveSlot.SLOT_SECONDARY
        autoUseActiveStatus[playerIndex].render = false
    end

    if (autoUseActiveStatus[playerIndex].autoUseActive and not player:NeedsCharge(activeSlot)) then
        -- handle held items differently
        if (
            autoUseActiveStatus[playerIndex].collectibleId == CollectibleType.COLLECTIBLE_SHOOP_DA_WHOOP
            or autoUseActiveStatus[playerIndex].collectibleId == CollectibleType.COLLECTIBLE_BOBS_ROTTEN_HEAD
            or autoUseActiveStatus[playerIndex].collectibleId == CollectibleType.COLLECTIBLE_CANDLE
            or autoUseActiveStatus[playerIndex].collectibleId == CollectibleType.COLLECTIBLE_RED_CANDLE
            or autoUseActiveStatus[playerIndex].collectibleId == CollectibleType.COLLECTIBLE_BOOMERANG
            or autoUseActiveStatus[playerIndex].collectibleId == CollectibleType.COLLECTIBLE_HEAD_OF_KRAMPUS
            or autoUseActiveStatus[playerIndex].collectibleId == CollectibleType.COLLECTIBLE_FRIEND_BALL
        ) then
            if (not player:IsHoldingItem()) then
                player:UseActiveItem(autoUseActiveStatus[playerIndex].collectibleId, 4, activeSlot)
            end
            if (
                Input.IsActionPressed(ButtonAction.ACTION_ITEM, player.ControllerIndex)
                and autoUseActiveStatus[playerIndex].holdTimer == 1
            ) then
                autoUseActiveStatus[playerIndex].autoUseActive = false
            end
        else
            player:UseActiveItem(autoUseActiveStatus[playerIndex].collectibleId, 4, activeSlot)
            if (player:GetCollectibleNum(CollectibleType.COLLECTIBLE_CAR_BATTERY) == 1) then
                player:UseActiveItem(autoUseActiveStatus[playerIndex].collectibleId, 4, activeSlot)
            end        
            player:DischargeActiveItem(activeSlot)
        end
    end
end

-- Mod Config Menu Settings
if ModConfigMenu then
    local modSettings = "Auto Use Active"

    -- avoid duplicating settings
    ModConfigMenu.RemoveCategory(modSettings)

    ModConfigMenu.UpdateCategory(modSettings, {
		Info = {"Auto Use Active",}
	})

    ------ Title
    ModConfigMenu.AddText(modSettings, "Settings", function() return "Auto Use Active" end)
	ModConfigMenu.AddSpace(modSettings, "Settings")

    ------ Settings
    -- Custom characters
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return persistentData["ignoreCharacterCheck"]
			end,
			Display = function()
				local onOff = "No"
				if persistentData["ignoreCharacterCheck"] then
					onOff = "Yes"
				end
				return 'Custom characters: ' .. onOff
			end,
			OnChange = function(currentBool)
				persistentData["ignoreCharacterCheck"] = currentBool
                autoUseActive:SaveData(json.encode(persistentData))
			end,
			Info = {"Enable mod for custom characters."}
	})
    -- Ignore all checks
    ModConfigMenu.AddSetting(modSettings, "Settings", 
		{
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function()
				return persistentData["ignoreAllChecks"]
			end,
			Display = function()
				local onOff = "No"
				if persistentData["ignoreAllChecks"] then
					onOff = "Yes"
				end
				return 'Ignore all checks: ' .. onOff
			end,
			OnChange = function(currentBool)
				persistentData["ignoreAllChecks"] = currentBool
                autoUseActive:SaveData(json.encode(persistentData))
			end,
			Info = {"Do not check any activation conditions. Very likely to cause issues."}
	})
end

autoUseActive:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, autoUseActive.onPlayerUpdate)
autoUseActive:AddCallback(ModCallbacks.MC_POST_RENDER, autoUseActive.onRender)
autoUseActive:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, autoUseActive.postGameStart)
autoUseActive:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, autoUseActive.postGameEnd)
autoUseActive:AddCallback(ModCallbacks.MC_EXECUTE_CMD, autoUseActive.debug)
